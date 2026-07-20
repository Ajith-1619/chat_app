<?php
declare(strict_types=1);
require_once __DIR__ . '/_bootstrap.php';

try {
    $admin = flow_admin_require();
    $pdo = flow_admin_db();
} catch (Throwable $e) {
    flow_admin_json(['status' => false, 'error' => $e->getMessage()], 500);
}

$adminEmpId = (int)($admin['emp_id'] ?? 0);
$method = strtoupper((string)($_SERVER['REQUEST_METHOD'] ?? 'GET'));
$action = strtolower(trim((string)($_GET['action'] ?? $_POST['action'] ?? 'overview')));
$search = trim((string)($_GET['q'] ?? $_POST['q'] ?? ''));

function admin_first_existing_column(PDO $pdo, string $table, array $columns): string
{
    foreach ($columns as $column) {
        if (flow_admin_column_exists($pdo, $table, $column)) return $column;
    }
    return '';
}

function admin_employee_source(PDO $employeePdo): ?array
{
    $candidates = ['employee', 'tbl_employee', 'employees', 'employee_master', 'staff_master', 'users'];
    foreach ($candidates as $table) {
        if (!flow_admin_table_exists($employeePdo, $table)) continue;
        $id = admin_first_existing_column($employeePdo, $table, ['emp_id', 'employee_id', 'id', 'user_id']);
        $name = admin_first_existing_column($employeePdo, $table, ['name', 'emp_name', 'employee_name', 'full_name', 'username']);
        if ($id !== '' && $name !== '') return ['table' => $table, 'id' => $id, 'name' => $name];
    }
    $rows = flow_admin_rows($employeePdo, "SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = DATABASE() ORDER BY TABLE_NAME ASC LIMIT 200");
    foreach ($rows as $row) {
        $table = (string)($row['TABLE_NAME'] ?? '');
        if ($table === '') continue;
        $id = admin_first_existing_column($employeePdo, $table, ['emp_id', 'employee_id', 'id', 'user_id']);
        $name = admin_first_existing_column($employeePdo, $table, ['name', 'emp_name', 'employee_name', 'full_name', 'username']);
        if ($id !== '' && $name !== '') return ['table' => $table, 'id' => $id, 'name' => $name];
    }
    return null;
}

function admin_sql_expr(string $column, string $alias): string
{
    return $column === '' ? "'' AS {$alias}" : "`{$column}` AS {$alias}";
}
function admin_quote_identifier(string $identifier): string
{
    return '`' . str_replace('`', '``', $identifier) . '`';
}

function admin_location_address_expr(PDO $pdo, string $table): string
{
    $direct = admin_first_existing_column($pdo, $table, ['address', 'formatted_address', 'formattedAddress', 'location_address', 'locationAddress', 'place_name', 'place', 'placeName', 'last_address', 'current_address', 'geo_address', 'login_address', 'login_location', 'login_location_address', 'current_location_address', 'user_address', 'map_address', 'short_address', 'location', 'address_line', 'full_address']);
    if ($direct !== '') return admin_sql_expr($direct, 'address');

    $parts = [];
    foreach (['area', 'locality', 'street', 'city', 'district', 'state', 'country', 'pincode', 'postal_code'] as $column) {
        if (flow_admin_column_exists($pdo, $table, $column)) $parts[] = admin_quote_identifier($column);
    }
    return $parts ? 'CONCAT_WS(\', \', ' . implode(', ', $parts) . ') AS address' : "'' AS address";
}

function admin_reverse_geocode_address(float $lat, float $lng): string
{
    if ($lat == 0.0 || $lng == 0.0) return '';
    $url = 'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=' . rawurlencode((string)$lat) . '&lon=' . rawurlencode((string)$lng) . '&zoom=18&addressdetails=0';
    $context = stream_context_create([
        'http' => [
            'timeout' => 2,
            'header' => "User-Agent: FlowMasterAdmin/1.0\r\nAccept: application/json\r\n",
        ],
    ]);
    try {
        $raw = @file_get_contents($url, false, $context);
        if (!is_string($raw) || $raw === '') return '';
        $data = json_decode($raw, true);
        return is_array($data) ? trim((string)($data['display_name'] ?? '')) : '';
    } catch (Throwable) {
        return '';
    }
}

function admin_location_address_fallback(int $empId, mixed $lat, mixed $lng): string
{
    $latValue = (float)$lat;
    $lngValue = (float)$lng;
    try {
        $jid = flow_admin_jid($empId);
        $rows = flow_admin_rows(flow_admin_db(),
            "SELECT location_address AS address
             FROM xmpp_messages
             WHERE from_jid = :jid AND location_address IS NOT NULL AND location_address <> ''
             ORDER BY ABS(COALESCE(latitude, 0) - :lat) + ABS(COALESCE(longitude, 0) - :lng), created_at DESC
             LIMIT 1",
            [':jid' => $jid, ':lat' => $latValue, ':lng' => $lngValue]
        );
        $address = trim((string)($rows[0]['address'] ?? ''));
        if ($address !== '') return $address;
    } catch (Throwable) {
        // Fall back to reverse geocoding below.
    }
    return admin_reverse_geocode_address($latValue, $lngValue);
}
function admin_employee_count(): int
{
    try {
        $employeePdo = flow_admin_employee_db();
        $source = admin_employee_source($employeePdo);
        if (!$source) return 0;
        return flow_admin_count($employeePdo, '`' . $source['table'] . '`');
    } catch (Throwable $e) {
        error_log('admin employee count failed: ' . $e->getMessage());
        return 0;
    }
}
function admin_group_type_condition(string $kind): string
{
    return $kind === 'channel'
        ? "LOWER(COALESCE(group_type, '')) = 'channel'"
        : "LOWER(COALESCE(group_type, '')) <> 'channel'";
}

function admin_overview(PDO $pdo): array
{
    return [
        'status' => true,
        'metrics' => [
            'users' => flow_admin_count($pdo, 'xmpp_users'),
            'online' => flow_admin_count($pdo, 'xmpp_user_presence', 'last_seen_at >= DATE_SUB(NOW(), INTERVAL 60 SECOND)'),
            'groups' => flow_admin_count($pdo, 'xmpp_groups', admin_group_type_condition('group') . " AND COALESCE(is_archived, 0) = 0"),
            'channels' => flow_admin_count($pdo, 'xmpp_groups', admin_group_type_condition('channel') . " AND COALESCE(is_archived, 0) = 0"),
            'messages_today' => flow_admin_count($pdo, 'xmpp_messages', 'created_at >= CURDATE() AND deleted_at IS NULL'),
            'files_today' => flow_admin_count($pdo, 'xmpp_messages', "created_at >= CURDATE() AND file_url IS NOT NULL AND file_url <> '' AND deleted_at IS NULL"),
            'failed_push' => flow_admin_count($pdo, 'xmpp_push_queue', "status = 'failed'"),
            'draft_releases' => flow_admin_count($pdo, 'xmpp_release_builds', "LOWER(COALESCE(status, '')) IN ('draft','development')"),
        ],

        'diagnostics' => flow_admin_rows($pdo,
            "SELECT category, operation, status, ROUND(AVG(duration_ms), 2) AS avg_ms, MAX(duration_ms) AS max_ms, COUNT(*) AS samples
             FROM xmpp_diagnostics
             WHERE created_at >= DATE_SUB(NOW(), INTERVAL 24 HOUR)
             GROUP BY category, operation, status
             ORDER BY avg_ms DESC LIMIT 12"),
    ];
}

function admin_users(PDO $pdo, string $search): array
{
    if (!flow_admin_table_exists($pdo, 'xmpp_users')) return ['status' => true, 'rows' => []];
    $rows = flow_admin_rows($pdo,
        "SELECT emp_id, jid AS username, xmpp_password AS password, status, avatar_url, created_at, updated_at, 'view_user' AS admin_action
         FROM xmpp_users ORDER BY emp_id ASC LIMIT 2000");
    $profiles = [];
    try {
        $employeePdo = flow_admin_employee_db();
        $source = admin_employee_source($employeePdo);
        if ($source) {
            $table = $source['table'];
            $idCol = $source['id'];
            $nameCol = $source['name'];
            $designationCol = admin_first_existing_column($employeePdo, $table, ['designation', 'desig', 'role', 'job_title', 'position']);
            $profileRows = flow_admin_rows($employeePdo, 'SELECT ' . implode(', ', [
                admin_sql_expr($idCol, 'emp_id'),
                admin_sql_expr($nameCol, 'name'),
                admin_sql_expr($designationCol, 'designation'),
                admin_sql_expr(admin_first_existing_column($employeePdo, $table, ['emp_type']), 'emp_type'),
            ]) . " FROM `{$table}` LIMIT 2000");
            foreach ($profileRows as $profile) {
                $profiles[(int)($profile['emp_id'] ?? 0)] = $profile;
            }
        }
    } catch (Throwable $e) {
        error_log('admin user profile join failed: ' . $e->getMessage());
    }

    $employeeTypeOverrides = admin_employee_type_overrides($pdo);
    $presence = [];
    foreach (flow_admin_rows($pdo, 'SELECT emp_id, last_seen_at FROM xmpp_user_presence') as $row) {
        $presence[(int)$row['emp_id']] = (string)$row['last_seen_at'];
    }
    foreach ($rows as &$row) {
        $empId = (int)($row['emp_id'] ?? 0);
        $profile = $profiles[$empId] ?? [];
        $row = [
            'emp_id' => $empId,
            'name' => (string)($profile['name'] ?? ''),
            'designation' => (string)($profile['designation'] ?? ''),
            'employee_type' => admin_employee_type_label($profile['emp_type'] ?? '', (string)($employeeTypeOverrides[$empId]['employee_type'] ?? '')),
            'username' => (string)($row['username'] ?? flow_admin_jid($empId)),
            'password' => (string)($row['password'] ?? ''),
            'status' => (string)($row['status'] ?? ''),
            'last_seen_at' => $presence[$empId] ?? '',
            'admin_action' => 'view_user',
        ];
    }
    unset($row);
    if ($search !== '') {
        $needle = mb_strtolower($search);
        $rows = array_values(array_filter($rows, static function (array $row) use ($needle): bool {
            foreach (['emp_id', 'name', 'designation', 'username', 'password', 'status', 'last_seen_at'] as $key) {
                if (str_contains(mb_strtolower((string)($row[$key] ?? '')), $needle)) return true;
            }
            return false;
        }));
    }
    return ['status' => true, 'rows' => array_slice($rows, 0, 300)];
}

function admin_user_detail(PDO $pdo): array
{
    $empId = (int)($_GET['id'] ?? $_POST['id'] ?? 0);
    if ($empId <= 0) return ['status' => false, 'error' => 'Valid employee id is required.'];

    $user = flow_admin_rows($pdo,
        'SELECT emp_id, jid AS username, xmpp_password AS password, status, avatar_url, created_at, updated_at FROM xmpp_users WHERE emp_id = :emp_id LIMIT 1',
        [':emp_id' => $empId]
    )[0] ?? ['emp_id' => $empId, 'username' => flow_admin_jid($empId)];

    $profile = [];
    try {
        $employeePdo = flow_admin_employee_db();
        $source = admin_employee_source($employeePdo);
        if ($source) {
            $table = $source['table'];
            $idCol = $source['id'];
            $columns = flow_admin_rows($employeePdo, 'SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = :table_name', [':table_name' => $table]);
            $select = [];
            foreach ($columns as $column) {
                $name = (string)($column['COLUMN_NAME'] ?? '');
                if ($name !== '') $select[] = '`' . $name . '`';
            }
            if ($select) {
                $profile = flow_admin_rows($employeePdo, 'SELECT ' . implode(', ', $select) . " FROM `{$table}` WHERE `{$idCol}` = :emp_id LIMIT 1", [':emp_id' => $empId])[0] ?? [];
            }
        }
    } catch (Throwable $e) {
        error_log('admin user detail profile failed: ' . $e->getMessage());
    }

    $jid = (string)($user['username'] ?? flow_admin_jid($empId));
    $filters = admin_user_message_filters($empId, $jid);
    $sentWhere = $filters['sent_where'];
    $receivedWhere = $filters['received_where'];
    $messageWhere = "({$sentWhere} OR {$receivedWhere})";
    $messageParams = $filters['params'];
    $messages = [
        'total' => admin_count_query($pdo, "SELECT COUNT(DISTINCT id) FROM xmpp_messages WHERE {$messageWhere} AND deleted_at IS NULL", $messageParams),
        'sent' => admin_count_query($pdo, "SELECT COUNT(*) FROM xmpp_messages WHERE {$sentWhere} AND deleted_at IS NULL", $messageParams),
        'received' => admin_count_query($pdo, "SELECT COUNT(*) FROM xmpp_messages WHERE {$receivedWhere} AND deleted_at IS NULL", $messageParams),
    ];

    $fileCondition = admin_file_condition($pdo);
    $files = [
        'count' => admin_count_query($pdo, "SELECT COUNT(DISTINCT id) FROM xmpp_messages WHERE {$messageWhere} AND {$fileCondition} AND deleted_at IS NULL", $messageParams),
        'sent_count' => admin_count_query($pdo, "SELECT COUNT(*) FROM xmpp_messages WHERE {$sentWhere} AND {$fileCondition} AND deleted_at IS NULL", $messageParams),
        'received_count' => admin_count_query($pdo, "SELECT COUNT(*) FROM xmpp_messages WHERE {$receivedWhere} AND {$fileCondition} AND deleted_at IS NULL", $messageParams),
        'storage_bytes' => 0,
        'storage_label' => '0 B',
    ];
    if (flow_admin_table_exists($pdo, 'xmpp_messages') && flow_admin_column_exists($pdo, 'xmpp_messages', 'file_size')) {
        $files['storage_bytes'] = admin_sum_query($pdo, "SELECT COALESCE(SUM(CAST(file_size AS UNSIGNED)), 0) FROM xmpp_messages WHERE {$sentWhere} AND {$fileCondition} AND deleted_at IS NULL", $messageParams);
        $files['storage_label'] = admin_format_bytes($files['storage_bytes']);
    }
    $files['quota'] = admin_user_storage_limit($pdo, $empId, (int)$files['storage_bytes']);

    $presence = flow_admin_rows($pdo, 'SELECT * FROM xmpp_user_presence WHERE emp_id = :emp_id LIMIT 1', [':emp_id' => $empId])[0] ?? [];
    $memberships = admin_user_group_memberships($pdo, $empId);
    $employeeTypeOverrides = admin_employee_type_overrides($pdo);
    $employeeType = admin_employee_type_label($profile['emp_type'] ?? '', (string)($employeeTypeOverrides[$empId]['employee_type'] ?? ''));

    return [
        'status' => true,
        'user' => $user,
        'profile' => $profile,
        'messages' => $messages,
        'files' => $files,
        'presence' => $presence,
        'location' => admin_user_last_location($pdo, $empId),
        'location_timeline' => admin_user_location_timeline($pdo, $empId),
        'systems' => admin_user_active_systems($pdo, $empId),
        'memberships' => $memberships,
        'attendance' => admin_user_attendance($empId),
        'employee_type' => ['value' => $employeeType, 'source_emp_type' => $profile['emp_type'] ?? null, 'updated_at' => $employeeTypeOverrides[$empId]['updated_at'] ?? null],
        'ai_access' => admin_ai_access_summary($pdo, $empId, $employeeType),
    ];
}

function admin_candidate_activity_tables(PDO $pdo, array $keywords, array $preferred = []): array
{
    $tables = $preferred;
    $clauses = [];
    foreach ($keywords as $keyword) {
        $safe = str_replace("'", "''", strtolower($keyword));
        $clauses[] = "LOWER(TABLE_NAME) LIKE '%{$safe}%'";
    }
    if ($clauses) {
        $rows = flow_admin_rows($pdo, 'SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = DATABASE() AND (' . implode(' OR ', $clauses) . ') ORDER BY TABLE_NAME ASC LIMIT 250');
        foreach ($rows as $row) {
            $table = (string)($row['TABLE_NAME'] ?? '');
            if ($table !== '') $tables[] = $table;
        }
    }
    return array_values(array_unique($tables));
}

function admin_seconds_label(int $seconds): string
{
    $seconds = max(0, $seconds);
    return sprintf('%02d:%02d:%02d', intdiv($seconds, 3600), intdiv($seconds % 3600, 60), $seconds % 60);
}

function admin_datetime_value(?string $value): ?DateTimeImmutable
{
    $value = trim((string)$value);
    if ($value === '' || $value === '0000-00-00' || $value === '0000-00-00 00:00:00') return null;
    try { return new DateTimeImmutable($value, new DateTimeZone('Asia/Kolkata')); } catch (Throwable) { return null; }
}

function admin_duration_seconds(mixed $value): int
{
    $value = trim((string)$value);
    if ($value === '') return 0;
    if (is_numeric($value)) {
        $number = (float)$value;
        return $number > 24 ? (int)round($number) : (int)round($number * 3600);
    }
    if (preg_match('/^(\d{1,3}):(\d{1,2})(?::(\d{1,2}))?$/', $value, $m)) {
        return ((int)$m[1] * 3600) + ((int)$m[2] * 60) + (int)($m[3] ?? 0);
    }
    return 0;
}

function admin_attendance_from_table(PDO $pdo, string $table, int $empId): array
{
    $id = admin_first_existing_column($pdo, $table, ['emp_id', 'employee_id', 'user_id', 'staff_id', 'member_emp_id', 'employeeId', 'userId']);
    if ($id === '') return [];
    $in = admin_first_existing_column($pdo, $table, ['punch_in_time', 'in_time', 'check_in_time', 'login_time', 'login_at', 'logged_in_at', 'start_time', 'signin_time', 'sign_in_time', 'date_created', 'created_at', 'created_on', 'punch_in', 'punchin', 'check_in', 'checkin']);
    $out = admin_first_existing_column($pdo, $table, ['punch_out_time', 'out_time', 'check_out_time', 'logout_time', 'logout_at', 'logged_out_at', 'end_time', 'signout_time', 'sign_out_time', 'punch_out', 'punchout', 'check_out', 'checkout']);
    $date = admin_first_existing_column($pdo, $table, ['attendance_date', 'punch_date', 'work_date', 'date', 'login_date', 'log_date', 'date_created', 'created_at', 'created_on', 'updated_at', 'updated_on', $in]);
    if ($date === '') return [];
    $status = admin_first_existing_column($pdo, $table, ['status', 'attendance_status', 'day_status', 'leave_status', 'type', 'entry_type']);
    $duration = admin_first_existing_column($pdo, $table, ['login_seconds', 'worked_seconds', 'duration_seconds', 'login_duration', 'work_duration', 'duration', 'login_hours', 'working_hours', 'total_hours']);
    $select = [admin_sql_expr($date, 'work_date'), admin_sql_expr($in, 'punch_in'), admin_sql_expr($out, 'punch_out'), admin_sql_expr($status, 'status'), admin_sql_expr($duration, 'duration')];
    $tableSql = admin_quote_identifier($table);
    $idSql = admin_quote_identifier($id);
    $dateSql = admin_quote_identifier($date);
    try {
        $now = new DateTimeImmutable('now', new DateTimeZone('Asia/Kolkata'));
    } catch (Throwable) {
        $now = new DateTimeImmutable();
    }
    $todayRows = flow_admin_rows($pdo, 'SELECT ' . implode(', ', $select) . " FROM {$tableSql} WHERE {$idSql} = :emp_id AND {$dateSql} >= CURDATE() AND {$dateSql} < DATE_ADD(CURDATE(), INTERVAL 1 DAY) ORDER BY {$dateSql} DESC LIMIT 20", [':emp_id' => $empId]);
    $monthRows = flow_admin_rows($pdo, 'SELECT ' . implode(', ', $select) . " FROM {$tableSql} WHERE {$idSql} = :emp_id AND {$dateSql} >= DATE_FORMAT(CURDATE(), '%Y-%m-01') AND {$dateSql} < DATE_ADD(LAST_DAY(CURDATE()), INTERVAL 1 DAY) ORDER BY {$dateSql} ASC LIMIT 370", [':emp_id' => $empId]);
    if (!$todayRows && !$monthRows) return [];

    $today = $todayRows[0] ?? [];
    $todayInValue = (string)(($today['punch_in'] ?? '') !== '' ? $today['punch_in'] : ($today['work_date'] ?? ''));
    $todayIn = admin_datetime_value($todayInValue);
    $todayOut = admin_datetime_value((string)($today['punch_out'] ?? ''));
    $todaySeconds = admin_duration_seconds($today['duration'] ?? '');
    if ($todaySeconds === 0 && $todayIn) $todaySeconds = max(0, ($todayOut ?: $now)->getTimestamp() - $todayIn->getTimestamp());

    $days = [];
    $leaveDays = [];
    $weekoffDays = [];
    $monthSeconds = 0;
    foreach ($monthRows as $row) {
        $rowDate = admin_datetime_value((string)($row['work_date'] ?? ''));
        if (!$rowDate) continue;
        $key = $rowDate->format('Y-m-d');
        $rowInValue = (string)(($row['punch_in'] ?? '') !== '' ? $row['punch_in'] : ($row['work_date'] ?? ''));
        $rowIn = admin_datetime_value($rowInValue);
        $rowOut = admin_datetime_value((string)($row['punch_out'] ?? ''));
        $rowSeconds = admin_duration_seconds($row['duration'] ?? '');
        if ($rowSeconds === 0 && $rowIn && $rowOut) $rowSeconds = max(0, $rowOut->getTimestamp() - $rowIn->getTimestamp());
        if ($rowSeconds === 0 && $rowIn && !$rowOut && $key === $now->format('Y-m-d')) $rowSeconds = max(0, $now->getTimestamp() - $rowIn->getTimestamp());
        if ($rowIn) $days[$key] = true;
        $monthSeconds += $rowSeconds;
        $rowStatus = strtolower((string)($row['status'] ?? ''));
        if (str_contains($rowStatus, 'leave') || str_contains($rowStatus, 'absent')) $leaveDays[$key] = ['date' => $key, 'status' => (string)$row['status']];
        if (str_contains($rowStatus, 'week') || str_contains($rowStatus, 'off') || str_contains($rowStatus, 'holiday')) $weekoffDays[$key] = ['date' => $key, 'status' => (string)$row['status']];
    }

    return [
        'source' => $table,
        'today' => [
            'status' => $todayRows ? (($todayOut || !$todayIn) ? 'Punched out' : 'Punched in') : 'Not punched in',
            'punch_in' => $todayIn ? $todayIn->format('Y-m-d H:i:s') : '',
            'punch_out' => $todayOut ? $todayOut->format('Y-m-d H:i:s') : '',
            'is_open' => (bool)($todayIn && !$todayOut),
            'login_seconds' => $todaySeconds,
            'login_label' => admin_seconds_label($todaySeconds),
        ],
        'month' => [
            'punch_days' => count($days),
            'login_seconds' => $monthSeconds,
            'login_label' => admin_seconds_label($monthSeconds),
            'leave_days' => array_values($leaveDays),
            'weekoff_days' => array_values($weekoffDays),
        ],
    ];
}

function admin_user_attendance(int $empId): array
{
    $fallback = [
        'source' => 'attendance schema not mapped',
        'today' => ['status' => 'Not available', 'punch_in' => '', 'punch_out' => '', 'is_open' => false, 'login_seconds' => 0, 'login_label' => '00:00:00'],
        'month' => ['punch_days' => 0, 'login_seconds' => 0, 'login_label' => '00:00:00', 'leave_days' => [], 'weekoff_days' => []],
    ];
    $seen = [];
    foreach ([
        'employee' => static fn() => flow_admin_employee_db(),
        'task' => static fn() => flow_admin_task_db(),
        'chat' => static fn() => flow_admin_db(),
    ] as $label => $connector) {
        try {
            $sourcePdo = $connector();
            $dbName = (string)$sourcePdo->query('SELECT DATABASE()')->fetchColumn();
            if ($dbName !== '' && isset($seen[$dbName])) continue;
            if ($dbName !== '') $seen[$dbName] = true;
            $tables = admin_candidate_activity_tables(
                $sourcePdo,
                ['punch', 'attendance', 'login', 'logout', 'tracking'],
                ['punch', 'punch_log', 'attendance', 'attendance_log', 'employee_attendance', 'tbl_attendance', 'login_tracking', 'logout_tracking']
            );
            foreach ($tables as $table) {
                $data = admin_attendance_from_table($sourcePdo, $table, $empId);
                if ($data) {
                    $data['source'] = $label . ':' . (string)($data['source'] ?? $table);
                    return $data;
                }
            }
        } catch (Throwable $e) {
            error_log('admin user attendance lookup failed: ' . $e->getMessage());
        }
    }
    return $fallback;
}
function admin_user_group_memberships(PDO $pdo, int $empId): array
{
    if (!flow_admin_table_exists($pdo, 'xmpp_group_members') || !flow_admin_table_exists($pdo, 'xmpp_groups')) {
        return ['groups' => 0, 'channels' => 0, 'total' => 0, 'rows' => []];
    }

    $memberGroupCol = admin_first_existing_column($pdo, 'xmpp_group_members', ['group_id', 'room_id', 'xmpp_group_id']);
    $memberEmpCol = admin_first_existing_column($pdo, 'xmpp_group_members', ['emp_id', 'employee_id', 'user_id', 'member_emp_id']);
    $memberRoleCol = admin_first_existing_column($pdo, 'xmpp_group_members', ['role', 'member_role', 'access_role']);
    $joinedCol = admin_first_existing_column($pdo, 'xmpp_group_members', ['joined_at', 'created_at', 'added_at']);
    if ($memberGroupCol === '' || $memberEmpCol === '') {
        return ['groups' => 0, 'channels' => 0, 'total' => 0, 'rows' => []];
    }

    $rows = flow_admin_rows($pdo, 'SELECT ' . implode(', ', [
        'g.id AS id',
        'g.room_name AS room_name',
        'g.group_type AS group_type',
        'g.channel_kind AS channel_kind',
        'g.is_archived AS is_archived',
        admin_sql_expr($memberRoleCol, 'role'),
        admin_sql_expr($joinedCol, 'joined_at'),
    ]) . " FROM xmpp_group_members gm INNER JOIN xmpp_groups g ON g.id = gm.`{$memberGroupCol}` WHERE gm.`{$memberEmpCol}` = :emp_id ORDER BY g.is_archived ASC, g.room_name ASC LIMIT 500", [':emp_id' => $empId]);

    $groups = 0;
    $channels = 0;
    foreach ($rows as &$row) {
        $isChannel = strtolower((string)($row['group_type'] ?? '')) === 'channel';
        $row['kind'] = $isChannel ? 'channel' : 'group';
        if ($isChannel) $channels++; else $groups++;
    }
    unset($row);

    return ['groups' => $groups, 'channels' => $channels, 'total' => count($rows), 'rows' => $rows];
}

function admin_format_bytes(int $bytes): string
{
    $units = ['B', 'KB', 'MB', 'GB', 'TB'];
    $size = max(0, $bytes);
    $index = 0;
    while ($size >= 1024 && $index < count($units) - 1) {
        $size /= 1024;
        $index++;
    }
    return ($index === 0 ? (string)(int)$size : number_format($size, 2)) . ' ' . $units[$index];
}

function admin_params_for_sql(array $params, string $sql): array
{
    $filtered = [];
    foreach ($params as $key => $value) {
        $name = ltrim((string)$key, ':');
        if ($name !== '' && preg_match('/:' . preg_quote($name, '/') . '\b/', $sql)) {
            $filtered[$key] = $value;
        }
    }
    return $filtered;
}
function admin_count_query(PDO $pdo, string $sql, array $params = []): int
{
    try {
        $stmt = $pdo->prepare($sql);
                $stmt->execute(admin_params_for_sql($params, $sql));
        return (int)$stmt->fetchColumn();
    } catch (Throwable $e) {
        error_log('flow admin count query failed: ' . $e->getMessage());
        return 0;
    }
}

function admin_sum_query(PDO $pdo, string $sql, array $params = []): int
{
    try {
        $stmt = $pdo->prepare($sql);
                $stmt->execute(admin_params_for_sql($params, $sql));
        return (int)$stmt->fetchColumn();
    } catch (Throwable $e) {
        error_log('flow admin sum query failed: ' . $e->getMessage());
        return 0;
    }
}

function admin_user_message_filters(int $empId, string $jid): array
{
    return [
        'sent_where' => '(from_jid = :sent_jid OR from_jid LIKE :sent_emp_like)',
        'received_where' => '(to_jid = :recv_jid OR to_jid LIKE :recv_emp_like)',
        'params' => [
            ':sent_jid' => $jid,
            ':sent_emp_like' => (string)$empId . '@%',
            ':recv_jid' => $jid,
            ':recv_emp_like' => (string)$empId . '@%',
        ],
    ];
}

function admin_file_condition(PDO $pdo): string
{
    $parts = [];
    foreach (['file_url', 'file_name', 'file_path', 'attachment_url', 'attachment_path', 'media_url', 'media_path'] as $column) {
        if (flow_admin_column_exists($pdo, 'xmpp_messages', $column)) {
            $col = admin_quote_identifier($column);
            $parts[] = "({$col} IS NOT NULL AND CAST({$col} AS CHAR) <> '')";
        }
    }
    return $parts ? '(' . implode(' OR ', $parts) . ')' : '0=1';
}

function admin_ensure_user_storage_limit_table(PDO $pdo): void
{
    $pdo->exec("CREATE TABLE IF NOT EXISTS flow_admin_user_storage_limits (
        emp_id INT NOT NULL PRIMARY KEY,
        limit_bytes BIGINT UNSIGNED NULL,
        updated_by_emp_id INT NULL,
        updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
}

function admin_user_storage_limit(PDO $pdo, int $empId, int $usedBytes): array
{
    admin_ensure_user_storage_limit_table($pdo);
    $row = flow_admin_rows($pdo, 'SELECT limit_bytes, updated_by_emp_id, updated_at FROM flow_admin_user_storage_limits WHERE emp_id = :emp_id LIMIT 1', [':emp_id' => $empId])[0] ?? [];
    $limitBytes = isset($row['limit_bytes']) && $row['limit_bytes'] !== null && $row['limit_bytes'] !== '' ? (int)$row['limit_bytes'] : 0;
    $remaining = $limitBytes > 0 ? max(0, $limitBytes - $usedBytes) : 0;
    return [
        'limit_bytes' => $limitBytes,
        'limit_mb' => $limitBytes > 0 ? round($limitBytes / 1048576, 2) : '',
        'limit_label' => $limitBytes > 0 ? admin_format_bytes($limitBytes) : 'Unlimited',
        'used_percent' => $limitBytes > 0 ? min(999, round(($usedBytes / max(1, $limitBytes)) * 100, 1)) : 0,
        'remaining_bytes' => $remaining,
        'remaining_label' => $limitBytes > 0 ? admin_format_bytes($remaining) : 'Unlimited',
        'is_over_limit' => $limitBytes > 0 && $usedBytes > $limitBytes,
        'updated_by_emp_id' => $row['updated_by_emp_id'] ?? null,
        'updated_at' => $row['updated_at'] ?? null,
    ];
}

function admin_update_user_storage_limit(PDO $pdo, int $adminEmpId, int $empId, mixed $limitMb): array
{
    admin_ensure_user_storage_limit_table($pdo);
    $raw = trim((string)$limitMb);
    $limitBytes = null;
    if ($raw !== '') {
        if (!is_numeric($raw) || (float)$raw < 0) return ['status' => false, 'error' => 'Storage limit must be a positive MB value or blank for unlimited.'];
        $limitBytes = (int)round((float)$raw * 1048576);
    }
    $stmt = $pdo->prepare('INSERT INTO flow_admin_user_storage_limits (emp_id, limit_bytes, updated_by_emp_id, updated_at) VALUES (:emp_id, :limit_bytes, :admin_emp_id, NOW()) ON DUPLICATE KEY UPDATE limit_bytes = VALUES(limit_bytes), updated_by_emp_id = VALUES(updated_by_emp_id), updated_at = NOW()');
    $stmt->execute([':emp_id' => $empId, ':limit_bytes' => $limitBytes, ':admin_emp_id' => $adminEmpId]);
    flow_admin_audit($adminEmpId, 'update_user_storage_limit', 'flow_admin_user_storage_limits', (string)$empId, ['limit_mb' => $raw === '' ? 'unlimited' : $raw]);
    return ['status' => true, 'message' => 'User storage limit updated.'];
}
function admin_ensure_employee_type_table(PDO $pdo): void
{
    $pdo->exec("CREATE TABLE IF NOT EXISTS flow_admin_employee_types (
        emp_id INT NOT NULL PRIMARY KEY,
        employee_type VARCHAR(8) NOT NULL,
        updated_by_emp_id INT NULL,
        updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
}

function admin_employee_type_label(mixed $empType, ?string $override = null): string
{
    $override = strtoupper(trim((string)$override));
    if (in_array($override, ['A', 'B', 'C1', 'C2'], true)) return $override;
    $raw = trim((string)$empType);
    if ($raw === '1') return 'B';
    if ($raw === '0') return 'C1';
    if (in_array(strtoupper($raw), ['A', 'B', 'C1', 'C2'], true)) return strtoupper($raw);
    return $raw !== '' ? $raw : 'C1';
}

function admin_employee_type_overrides(PDO $pdo): array
{
    admin_ensure_employee_type_table($pdo);
    $rows = flow_admin_rows($pdo, 'SELECT emp_id, employee_type, updated_by_emp_id, updated_at FROM flow_admin_employee_types');
    $out = [];
    foreach ($rows as $row) $out[(int)($row['emp_id'] ?? 0)] = $row;
    return $out;
}

function admin_update_employee_type(PDO $pdo, int $adminEmpId, int $empId, string $employeeType): array
{
    $employeeType = strtoupper(trim($employeeType));
    if (!in_array($employeeType, ['A', 'B', 'C1', 'C2'], true)) return ['status' => false, 'error' => 'Employee type must be A, B, C1, or C2.'];
    admin_ensure_employee_type_table($pdo);
    $stmt = $pdo->prepare('INSERT INTO flow_admin_employee_types (emp_id, employee_type, updated_by_emp_id, updated_at) VALUES (:emp_id, :employee_type, :admin_emp_id, NOW()) ON DUPLICATE KEY UPDATE employee_type = VALUES(employee_type), updated_by_emp_id = VALUES(updated_by_emp_id), updated_at = NOW()');
    $stmt->execute([':emp_id' => $empId, ':employee_type' => $employeeType, ':admin_emp_id' => $adminEmpId]);
    flow_admin_audit($adminEmpId, 'update_employee_type', 'flow_admin_employee_types', (string)$empId, ['employee_type' => $employeeType]);
    return ['status' => true, 'message' => 'Employee type updated.'];
}
function admin_candidate_location_tables(PDO $pdo): array
{
    return [
        'punch',
        'punch_log',
        'logout_tracking',
        'login_tracking',
        'user_login_tracking',
        'employee_login_tracking',
        'xmpp_user_locations',
        'xmpp_location_history',
        'xmpp_user_presence',
        'user_locations',
        'employee_locations',
        'location_history',
        'locations',
        'live_locations',
        'current_locations',
        'gps_locations',
        'geo_locations',
        'user_location_logs',
        'employee_location_logs',
    ];
}
function admin_location_sort_value(array $row): int
{
    $date = admin_datetime_value((string)($row['updated_at'] ?? ''));
    return $date ? $date->getTimestamp() : 0;
}

function admin_user_last_location_from_pdo(PDO $pdo, int $empId, string $sourceLabel): array
{
    $best = [];
    foreach (admin_candidate_location_tables($pdo) as $table) {
        if (!flow_admin_table_exists($pdo, $table)) continue;
        $id = admin_first_existing_column($pdo, $table, ['emp_id', 'employee_id', 'user_id', 'member_emp_id', 'staff_id', 'employeeId', 'userId']);
        $lat = admin_first_existing_column($pdo, $table, ['latitude', 'lat', 'current_latitude', 'last_latitude', 'gps_latitude', 'location_lat', 'lat_value']);
        $lng = admin_first_existing_column($pdo, $table, ['longitude', 'lng', 'lon', 'long', 'current_longitude', 'last_longitude', 'gps_longitude', 'location_lng', 'location_long', 'lng_value']);
        if ($id === '' || $lat === '' || $lng === '') continue;

        $addressExpr = admin_location_address_expr($pdo, $table);
        $updated = admin_first_existing_column($pdo, $table, ['updated_at', 'date_created', 'created_at', 'updated_on', 'created_on', 'captured_at', 'last_seen_at', 'tracked_at', 'recorded_at', 'timestamp', 'time', 'date_time', 'datetime', 'login_time', 'login_at', 'login_date', 'login_datetime', 'login_date_time', 'logged_at', 'logged_in_at', 'last_login', 'last_login_at', 'inserted_at', 'entry_time', 'entry_date', 'log_time', 'log_datetime', 'modified_at', 'modified_on']);
        $tableSql = admin_quote_identifier($table);
        $idSql = admin_quote_identifier($id);
        $latSql = admin_quote_identifier($lat);
        $lngSql = admin_quote_identifier($lng);
        $order = $updated !== '' ? admin_quote_identifier($updated) . ' DESC' : $idSql . ' DESC';
        $rows = flow_admin_rows($pdo, 'SELECT ' . implode(', ', [
            admin_sql_expr($lat, 'lat'),
            admin_sql_expr($lng, 'lng'),
            $addressExpr,
            admin_sql_expr($updated, 'updated_at'),
        ]) . " FROM {$tableSql}
             WHERE {$idSql} = :emp_id
               AND {$latSql} IS NOT NULL AND {$lngSql} IS NOT NULL
               AND CAST({$latSql} AS CHAR) <> '' AND CAST({$lngSql} AS CHAR) <> ''
               AND CAST({$latSql} AS CHAR) <> '0' AND CAST({$lngSql} AS CHAR) <> '0'
             ORDER BY {$order} LIMIT 1", [':emp_id' => $empId]);
        if (!$rows) continue;
        $row = $rows[0] + ['source' => $sourceLabel . ':' . $table];
        if (!$best || admin_location_sort_value($row) > admin_location_sort_value($best)) {
            $best = $row;
        }
    }
    if ($best && trim((string)($best['address'] ?? '')) === '') {
        $best['address'] = admin_location_address_fallback($empId, $best['lat'] ?? 0, $best['lng'] ?? 0);
    }
    return $best;
}

function admin_user_last_location(PDO $pdo, int $empId): array
{
    $seen = [];
    $best = [];
    foreach ([
        'chat' => static fn() => $pdo,
        'employee' => static fn() => flow_admin_employee_db(),
        'task' => static fn() => flow_admin_task_db(),
    ] as $label => $connector) {
        try {
            $sourcePdo = $connector();
            $dbName = (string)$sourcePdo->query('SELECT DATABASE()')->fetchColumn();
            if ($dbName !== '' && isset($seen[$dbName])) continue;
            if ($dbName !== '') $seen[$dbName] = true;
            $location = admin_user_last_location_from_pdo($sourcePdo, $empId, $label);
            if ($location && (!$best || admin_location_sort_value($location) > admin_location_sort_value($best))) $best = $location;
        } catch (Throwable $e) {
            error_log('admin user location lookup failed: ' . $e->getMessage());
        }
    }
    return $best;
}

function admin_user_location_timeline_from_pdo(PDO $pdo, int $empId, string $sourceLabel): array
{
    $items = [];
    foreach (admin_candidate_location_tables($pdo) as $table) {
        if (!flow_admin_table_exists($pdo, $table)) continue;
        $id = admin_first_existing_column($pdo, $table, ['emp_id', 'employee_id', 'user_id', 'member_emp_id', 'staff_id', 'employeeId', 'userId']);
        $lat = admin_first_existing_column($pdo, $table, ['latitude', 'lat', 'current_latitude', 'last_latitude', 'gps_latitude', 'location_lat', 'lat_value']);
        $lng = admin_first_existing_column($pdo, $table, ['longitude', 'lng', 'lon', 'long', 'current_longitude', 'last_longitude', 'gps_longitude', 'location_lng', 'location_long', 'lng_value']);
        $updated = admin_first_existing_column($pdo, $table, ['updated_at', 'date_created', 'created_at', 'updated_on', 'created_on', 'captured_at', 'last_seen_at', 'tracked_at', 'recorded_at', 'timestamp', 'time', 'date_time', 'datetime', 'login_time', 'login_at', 'login_date', 'login_datetime', 'login_date_time', 'logged_at', 'logged_in_at', 'last_login', 'last_login_at', 'inserted_at', 'entry_time', 'entry_date', 'log_time', 'log_datetime', 'modified_at', 'modified_on']);
        if ($id === '' || $lat === '' || $lng === '' || $updated === '') continue;
        $tableSql = admin_quote_identifier($table);
        $idSql = admin_quote_identifier($id);
        $latSql = admin_quote_identifier($lat);
        $lngSql = admin_quote_identifier($lng);
        $updatedSql = admin_quote_identifier($updated);
        $addressExpr = admin_location_address_expr($pdo, $table);
        $rows = flow_admin_rows($pdo, 'SELECT ' . implode(', ', [
            admin_sql_expr($lat, 'lat'),
            admin_sql_expr($lng, 'lng'),
            $addressExpr,
            admin_sql_expr($updated, 'updated_at'),
        ]) . " FROM {$tableSql}
             WHERE {$idSql} = :emp_id
               AND {$updatedSql} >= CURDATE() AND {$updatedSql} < DATE_ADD(CURDATE(), INTERVAL 1 DAY)
               AND {$latSql} IS NOT NULL AND {$lngSql} IS NOT NULL
               AND CAST({$latSql} AS CHAR) <> '' AND CAST({$lngSql} AS CHAR) <> ''
               AND CAST({$latSql} AS CHAR) <> '0' AND CAST({$lngSql} AS CHAR) <> '0'
             ORDER BY {$updatedSql} ASC LIMIT 200", [':emp_id' => $empId]);
        foreach ($rows as $row) {
            $row['source'] = $sourceLabel . ':' . $table;
            $items[] = $row;
        }
    }
    usort($items, static fn(array $a, array $b): int => admin_location_sort_value($a) <=> admin_location_sort_value($b));
    return array_slice($items, 0, 300);
}

function admin_user_location_timeline(PDO $pdo, int $empId): array
{
    $seen = [];
    $items = [];
    foreach ([
        'chat' => static fn() => $pdo,
        'employee' => static fn() => flow_admin_employee_db(),
        'task' => static fn() => flow_admin_task_db(),
    ] as $label => $connector) {
        try {
            $sourcePdo = $connector();
            $dbName = (string)$sourcePdo->query('SELECT DATABASE()')->fetchColumn();
            if ($dbName !== '' && isset($seen[$dbName])) continue;
            if ($dbName !== '') $seen[$dbName] = true;
            $items = array_merge($items, admin_user_location_timeline_from_pdo($sourcePdo, $empId, $label));
        } catch (Throwable $e) {
            error_log('admin user timeline lookup failed: ' . $e->getMessage());
        }
    }
    usort($items, static fn(array $a, array $b): int => admin_location_sort_value($a) <=> admin_location_sort_value($b));
    return array_slice($items, 0, 300);
}

function admin_user_active_systems(PDO $pdo, int $empId): array
{
    foreach (['xmpp_user_devices', 'xmpp_devices', 'user_devices', 'device_sessions', 'xmpp_sessions'] as $table) {
        if (!flow_admin_table_exists($pdo, $table)) continue;
        $id = admin_first_existing_column($pdo, $table, ['emp_id', 'employee_id', 'user_id']);
        if ($id === '') continue;
        $device = admin_first_existing_column($pdo, $table, ['device_name', 'device', 'device_model', 'model', 'platform', 'system_name', 'os']);
        $platform = admin_first_existing_column($pdo, $table, ['platform', 'os', 'device_os']);
        $app = admin_first_existing_column($pdo, $table, ['app_version', 'version', 'build_number']);
        $ip = admin_first_existing_column($pdo, $table, ['ip_address', 'ip', 'last_ip']);
        $agent = admin_first_existing_column($pdo, $table, ['user_agent', 'agent', 'browser']);
        $updated = admin_first_existing_column($pdo, $table, ['last_seen_at', 'last_activity_at', 'updated_at', 'created_at']);
        $active = admin_first_existing_column($pdo, $table, ['is_active', 'active', 'online']);
        $where = "`{$id}` = :emp_id";
        if ($active !== '') $where .= " AND COALESCE(`{$active}`, 0) IN (1, '1', 'true', 'online')";
        $order = $updated !== '' ? "`{$updated}` DESC" : "`{$id}` DESC";
        $rows = flow_admin_rows($pdo, 'SELECT ' . implode(', ', [admin_sql_expr($device, 'device'), admin_sql_expr($platform, 'platform'), admin_sql_expr($app, 'app_version'), admin_sql_expr($ip, 'ip_address'), admin_sql_expr($agent, 'user_agent'), admin_sql_expr($updated, 'last_seen_at')]) . " FROM `{$table}` WHERE {$where} ORDER BY {$order} LIMIT 10", [':emp_id' => $empId]);
        foreach ($rows as &$row) $row['source'] = $table;
        unset($row);
        if ($rows) return $rows;
    }
    if (flow_admin_table_exists($pdo, 'xmpp_user_presence')) {
        $rows = flow_admin_rows($pdo, 'SELECT updated_at AS app_version, last_seen_at FROM xmpp_user_presence WHERE emp_id = :emp_id LIMIT 1', [':emp_id' => $empId]);
        foreach ($rows as &$row) {
            $row['device'] = 'Presence session';
            $row['platform'] = 'chat';
            $row['ip_address'] = '';
            $row['user_agent'] = '';
            $row['source'] = 'xmpp_user_presence';
        }
        unset($row);
        return $rows;
    }
    return [];
}function admin_groups_or_channels(PDO $pdo, string $search, string $kind): array
{
    $where = admin_group_type_condition($kind);
    if (flow_admin_column_exists($pdo, 'xmpp_groups', 'deleted_at')) {
        $where .= ' AND deleted_at IS NULL';
    }
    $rows = flow_admin_rows($pdo,
        "SELECT g.id, g.room_name, g.group_type, g.channel_kind, g.is_archived,
                COUNT(gm.emp_id) AS members, g.created_at,
                'update_group' AS admin_action
         FROM xmpp_groups g
         LEFT JOIN xmpp_group_members gm ON gm.group_id = g.id
         WHERE {$where}
         GROUP BY g.id
         ORDER BY g.is_archived ASC, g.created_at DESC LIMIT 500");

    if ($search !== '') {
        $needle = mb_strtolower($search);
        $rows = array_values(array_filter($rows, static function (array $row) use ($needle): bool {
            foreach (['id', 'room_name', 'group_type', 'channel_kind', 'is_archived', 'members', 'created_at'] as $key) {
                if (str_contains(mb_strtolower((string)($row[$key] ?? '')), $needle)) return true;
            }
            return false;
        }));
    }

    return ['status' => true, 'rows' => array_slice($rows, 0, 120)];
}
function admin_wakeup_interval_options(): array
{
    return [
        ['minutes' => 60, 'label' => '1 hour'],
        ['minutes' => 180, 'label' => '3 hours'],
        ['minutes' => 360, 'label' => '6 hours'],
        ['minutes' => 720, 'label' => '12 hours'],
        ['minutes' => 1440, 'label' => '1 day'],
        ['minutes' => 4320, 'label' => '3 days'],
        ['minutes' => 10080, 'label' => '7 days'],
        ['minutes' => 20160, 'label' => '14 days'],
        ['minutes' => 43200, 'label' => '30 days'],
    ];
}

function admin_wakeup_interval_label(int $minutes): string
{
    foreach (admin_wakeup_interval_options() as $option) {
        if ((int)$option['minutes'] === $minutes) return (string)$option['label'];
    }
    if ($minutes >= 1440 && $minutes % 1440 === 0) return (int)($minutes / 1440) . ' days';
    if ($minutes >= 60 && $minutes % 60 === 0) return (int)($minutes / 60) . ' hours';
    return $minutes . ' minutes';
}

function admin_channel_type_options(PDO $pdo): array
{
    $fallback = [
        ['key' => 'incident', 'name' => 'Incident'],
        ['key' => 'action', 'name' => 'Action'],
        ['key' => 'operational', 'name' => 'Operational'],
        ['key' => 'project', 'name' => 'Project'],
        ['key' => 'announcement', 'name' => 'Announcement'],
    ];
    if (!flow_admin_table_exists($pdo, 'xmpp_channel_definitions')) return $fallback;
    $rows = flow_admin_rows($pdo, 'SELECT type_key AS `key`, name FROM xmpp_channel_definitions ORDER BY FIELD(type_key, \'incident\', \'action\', \'operational\', \'project\', \'announcement\'), name ASC');
    return $rows ?: $fallback;
}

function admin_group_wakeup_summary(PDO $pdo, array $group, string $roomJid): array
{
    $enabled = (int)($group['wakeup_enabled'] ?? 0) === 1;
    $interval = max(60, (int)($group['wakeup_interval_minutes'] ?? 1440));
    $lastActivity = (string)($group['created_at'] ?? '');
    if ($roomJid !== '' && flow_admin_table_exists($pdo, 'xmpp_messages')) {
        $rows = flow_admin_rows($pdo, 'SELECT MAX(created_at) AS last_activity_at FROM xmpp_messages WHERE to_jid = :room_jid AND deleted_at IS NULL', [':room_jid' => $roomJid]);
        $lastActivity = (string)($rows[0]['last_activity_at'] ?? $lastActivity);
    }
    $lastSent = (string)($group['wakeup_last_sent_at'] ?? '');
    $nextAt = '';
    if ($enabled) {
        $candidates = [];
        if ($lastActivity !== '') $candidates[] = strtotime($lastActivity) + ($interval * 60);
        if ($lastSent !== '') $candidates[] = strtotime($lastSent) + (max(15, (int)floor($interval / 4)) * 60);
        $nextTs = $candidates ? max($candidates) : time() + ($interval * 60);
        $nextAt = date('Y-m-d H:i:s', $nextTs);
    }
    return [
        'enabled' => $enabled,
        'interval_minutes' => $interval,
        'interval_label' => admin_wakeup_interval_label($interval),
        'last_activity_at' => $lastActivity,
        'last_sent_at' => $lastSent,
        'next_wakeup_at' => $nextAt,
        'next_wakeup_label' => $nextAt !== '' ? date('d/m/Y h:i A', strtotime($nextAt)) : '',
        'updated_at' => (string)($group['wakeup_updated_at'] ?? ''),
        'updated_by_emp_id' => (string)($group['wakeup_updated_by_emp_id'] ?? ''),
        'options' => admin_wakeup_interval_options(),
    ];
}

function admin_employee_picker(PDO $pdo, string $search): array
{
    try {
        $employeePdo = flow_admin_employee_db();
        $source = admin_employee_source($employeePdo);
        if (!$source) return ['status' => true, 'rows' => []];
        $table = $source['table'];
        $idCol = $source['id'];
        $nameCol = $source['name'];
        $designationCol = admin_first_existing_column($employeePdo, $table, ['designation', 'desig', 'role', 'job_title', 'position']);
        $mobileCol = admin_first_existing_column($employeePdo, $table, ['mobile_no', 'mobile', 'phone', 'contact_no']);
        $where = '1=1';
        $params = [];
        if ($search !== '') {
            $where = "CAST(`{$idCol}` AS CHAR) LIKE :q OR `{$nameCol}` LIKE :q";
            if ($designationCol !== '') $where .= " OR `{$designationCol}` LIKE :q";
            if ($mobileCol !== '') $where .= " OR `{$mobileCol}` LIKE :q";
            $params[':q'] = '%' . $search . '%';
        }
        $rows = flow_admin_rows($employeePdo, 'SELECT ' . implode(', ', [
            admin_sql_expr($idCol, 'emp_id'),
            admin_sql_expr($nameCol, 'name'),
            admin_sql_expr($designationCol, 'designation'),
            admin_sql_expr($mobileCol, 'mobile'),
        ]) . " FROM `{$table}` WHERE {$where} ORDER BY `{$nameCol}` ASC LIMIT 80", $params);
        foreach ($rows as &$row) {
            $empId = (int)($row['emp_id'] ?? 0);
            $row['jid'] = $empId > 0 ? flow_admin_jid($empId) : '';
        }
        unset($row);
        return ['status' => true, 'rows' => $rows];
    } catch (Throwable $e) {
        error_log('admin employee picker failed: ' . $e->getMessage());
        return ['status' => false, 'error' => 'Unable to load employee list.'];
    }
}

function admin_group_detail(PDO $pdo): array
{
    $groupId = (int)($_GET['id'] ?? $_POST['id'] ?? 0);
    if ($groupId <= 0) return ['status' => false, 'error' => 'Valid group id is required.'];

    $group = flow_admin_rows($pdo, 'SELECT * FROM xmpp_groups WHERE id = :id LIMIT 1', [':id' => $groupId])[0] ?? [];
    if (!$group) return ['status' => false, 'error' => 'Group/channel not found.'];

    $roomJid = (string)($group['room_jid'] ?? '');
    $messageWhere = '1=0';
    $messageParams = [];
    if ($roomJid !== '') {
        $messageWhere = '(to_jid = :room_jid OR from_jid = :room_jid)';
        $messageParams[':room_jid'] = $roomJid;
    }

    $memberGroupCol = admin_first_existing_column($pdo, 'xmpp_group_members', ['group_id', 'room_id', 'xmpp_group_id']);
    $memberEmpCol = admin_first_existing_column($pdo, 'xmpp_group_members', ['emp_id', 'employee_id', 'user_id', 'member_emp_id']);
    $memberRoleCol = admin_first_existing_column($pdo, 'xmpp_group_members', ['role', 'member_role', 'access_role']);
    $memberWhere = $memberGroupCol !== '' ? "`{$memberGroupCol}` = :group_id" : '1=0';
    $memberParams = [':group_id' => $groupId];
    $roleExpr = $memberRoleCol !== '' ? "LOWER(COALESCE(`{$memberRoleCol}`, 'member'))" : "'member'";

    $stats = [
        'members' => flow_admin_count($pdo, 'xmpp_group_members', $memberWhere, $memberParams),
        'owners' => flow_admin_count($pdo, 'xmpp_group_members', $memberWhere . " AND {$roleExpr} = 'owner'", $memberParams),
        'admins' => flow_admin_count($pdo, 'xmpp_group_members', $memberWhere . " AND {$roleExpr} = 'admin'", $memberParams),
        'messages' => flow_admin_count($pdo, 'xmpp_messages', $messageWhere . ' AND deleted_at IS NULL', $messageParams),
        'files' => flow_admin_count($pdo, 'xmpp_messages', $messageWhere . " AND file_url IS NOT NULL AND file_url <> '' AND deleted_at IS NULL", $messageParams),
        'images' => flow_admin_count($pdo, 'xmpp_messages', $messageWhere . " AND file_url IS NOT NULL AND file_url <> '' AND deleted_at IS NULL AND (LOWER(COALESCE(file_type, '')) LIKE 'image%' OR LOWER(COALESCE(file_name, '')) REGEXP '\\.(jpg|jpeg|png|gif|webp)$')", $messageParams),
        'storage_bytes' => 0,
        'storage_label' => '0 B',
    ];

    try {
        if (flow_admin_table_exists($pdo, 'xmpp_messages') && flow_admin_column_exists($pdo, 'xmpp_messages', 'file_size')) {
            $stmt = $pdo->prepare("SELECT COALESCE(SUM(CAST(file_size AS UNSIGNED)), 0) FROM xmpp_messages WHERE {$messageWhere} AND file_url IS NOT NULL AND file_url <> '' AND deleted_at IS NULL");
            $stmt->execute($messageParams);
            $stats['storage_bytes'] = (int)$stmt->fetchColumn();
            $stats['storage_label'] = admin_format_bytes($stats['storage_bytes']);
        }
    } catch (Throwable $e) {
        error_log('admin group detail storage failed: ' . $e->getMessage());
    }

    $members = [];
    if ($memberGroupCol !== '' && $memberEmpCol !== '') {
        $joinedCol = admin_first_existing_column($pdo, 'xmpp_group_members', ['joined_at', 'created_at', 'added_at']);
        $mutedCol = admin_first_existing_column($pdo, 'xmpp_group_members', ['muted_until', 'mute_until']);
        $readCol = admin_first_existing_column($pdo, 'xmpp_group_members', ['last_read_message_id', 'last_read_id']);
        $order = "FIELD({$roleExpr}, 'owner', 'admin', 'member'), `{$memberEmpCol}` ASC";
        $members = flow_admin_rows($pdo,
            'SELECT ' . implode(', ', [
                admin_sql_expr($memberGroupCol, 'group_id'),
                admin_sql_expr($memberEmpCol, 'emp_id'),
                admin_sql_expr($memberRoleCol, 'role'),
                admin_sql_expr($joinedCol, 'joined_at'),
                admin_sql_expr($mutedCol, 'muted_until'),
                admin_sql_expr($readCol, 'last_read_message_id'),
            ]) . " FROM xmpp_group_members WHERE {$memberWhere} ORDER BY {$order} LIMIT 500",
            $memberParams
        );
    }

    $profiles = [];
    try {
        $employeePdo = flow_admin_employee_db();
        $source = admin_employee_source($employeePdo);
        if ($source && $members) {
            $ids = array_values(array_unique(array_map(static fn($row) => (int)($row['emp_id'] ?? 0), $members)));
            $ids = array_filter($ids, static fn($id) => $id > 0);
            if ($ids) {
                $placeholders = implode(',', array_fill(0, count($ids), '?'));
                $table = $source['table'];
                $idCol = $source['id'];
                $nameCol = $source['name'];
                $designationCol = admin_first_existing_column($employeePdo, $table, ['designation', 'desig', 'role', 'job_title', 'position']);
                $profileRows = flow_admin_rows($employeePdo, 'SELECT ' . implode(', ', [
                    admin_sql_expr($idCol, 'emp_id'),
                    admin_sql_expr($nameCol, 'name'),
                    admin_sql_expr($designationCol, 'designation'),
                ]) . " FROM `{$table}` WHERE `{$idCol}` IN ({$placeholders})", $ids);
                foreach ($profileRows as $profile) $profiles[(int)($profile['emp_id'] ?? 0)] = $profile;
            }
        }
    } catch (Throwable $e) {
        error_log('admin group detail profile failed: ' . $e->getMessage());
    }

    foreach ($members as &$member) {
        $empId = (int)($member['emp_id'] ?? 0);
        $profile = $profiles[$empId] ?? [];
        $member['name'] = (string)($profile['name'] ?? 'Employee ' . $empId);
        $member['designation'] = (string)($profile['designation'] ?? '');
        $member['jid'] = flow_admin_jid($empId);
    }
    unset($member);

    return [
        'status' => true,
        'group' => $group,
        'stats' => $stats,
        'members' => $members,
        'external_members' => admin_group_external_members($pdo, $groupId),
        'wakeup' => admin_group_wakeup_summary($pdo, $group, $roomJid),
        'channel_types' => admin_channel_type_options($pdo),
    ];
}
function admin_ensure_column_safe(PDO $pdo, string $table, string $column, string $definition): void
{
    if (flow_admin_column_exists($pdo, $table, $column)) return;
    try {
        $pdo->exec("ALTER TABLE `{$table}` ADD COLUMN `{$column}` {$definition}");
    } catch (Throwable $e) {
        error_log("admin ensure column {$table}.{$column} failed: " . $e->getMessage());
    }
}

function admin_ensure_ai_tables(PDO $pdo): void
{
    $pdo->exec("CREATE TABLE IF NOT EXISTS flow_admin_ai_providers (
        id INT AUTO_INCREMENT PRIMARY KEY,
        provider_name VARCHAR(120) NOT NULL,
        api_type VARCHAR(80) NOT NULL,
        model_name VARCHAR(160) NULL,
        api_endpoint VARCHAR(500) NULL,
        api_key TEXT NULL,
        status TINYINT NOT NULL DEFAULT 1,
        notes TEXT NULL,
        created_by_emp_id INT NULL,
        updated_by_emp_id INT NULL,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    admin_ensure_column_safe($pdo, 'flow_admin_ai_providers', 'provider_name', 'VARCHAR(120) NOT NULL DEFAULT \'\'');
    admin_ensure_column_safe($pdo, 'flow_admin_ai_providers', 'api_type', 'VARCHAR(80) NOT NULL DEFAULT \'custom\'');
    admin_ensure_column_safe($pdo, 'flow_admin_ai_providers', 'model_name', 'VARCHAR(160) NULL');
    admin_ensure_column_safe($pdo, 'flow_admin_ai_providers', 'api_endpoint', 'VARCHAR(500) NULL');
    admin_ensure_column_safe($pdo, 'flow_admin_ai_providers', 'api_key', 'TEXT NULL');
    admin_ensure_column_safe($pdo, 'flow_admin_ai_providers', 'status', 'TINYINT NOT NULL DEFAULT 1');
    admin_ensure_column_safe($pdo, 'flow_admin_ai_providers', 'notes', 'TEXT NULL');
    admin_ensure_column_safe($pdo, 'flow_admin_ai_providers', 'created_by_emp_id', 'INT NULL');
    admin_ensure_column_safe($pdo, 'flow_admin_ai_providers', 'updated_by_emp_id', 'INT NULL');
    admin_ensure_column_safe($pdo, 'flow_admin_ai_providers', 'created_at', 'DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP');
    admin_ensure_column_safe($pdo, 'flow_admin_ai_providers', 'updated_at', 'DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP');

    $pdo->exec("CREATE TABLE IF NOT EXISTS flow_admin_ai_type_rules (
        employee_type VARCHAR(8) NOT NULL PRIMARY KEY,
        access_mode VARCHAR(20) NOT NULL DEFAULT 'none',
        provider_ids TEXT NULL,
        daily_token_limit INT NOT NULL DEFAULT 0,
        daily_search_limit INT NOT NULL DEFAULT 0,
        updated_by_emp_id INT NULL,
        updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    admin_ensure_column_safe($pdo, 'flow_admin_ai_type_rules', 'access_mode', 'VARCHAR(20) NOT NULL DEFAULT \'none\'');
    admin_ensure_column_safe($pdo, 'flow_admin_ai_type_rules', 'provider_ids', 'TEXT NULL');
    admin_ensure_column_safe($pdo, 'flow_admin_ai_type_rules', 'daily_token_limit', 'INT NOT NULL DEFAULT 0');
    admin_ensure_column_safe($pdo, 'flow_admin_ai_type_rules', 'daily_search_limit', 'INT NOT NULL DEFAULT 0');
    admin_ensure_column_safe($pdo, 'flow_admin_ai_type_rules', 'updated_by_emp_id', 'INT NULL');
    admin_ensure_column_safe($pdo, 'flow_admin_ai_type_rules', 'updated_at', 'DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP');

    $pdo->exec("CREATE TABLE IF NOT EXISTS flow_admin_ai_user_access (
        emp_id INT NOT NULL PRIMARY KEY,
        employee_type_override VARCHAR(8) NULL,
        provider_ids TEXT NULL,
        daily_token_limit INT NULL,
        daily_search_limit INT NULL,
        enabled TINYINT NOT NULL DEFAULT 1,
        updated_by_emp_id INT NULL,
        updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    admin_ensure_column_safe($pdo, 'flow_admin_ai_user_access', 'employee_type_override', 'VARCHAR(8) NULL');
    admin_ensure_column_safe($pdo, 'flow_admin_ai_user_access', 'provider_ids', 'TEXT NULL');
    admin_ensure_column_safe($pdo, 'flow_admin_ai_user_access', 'daily_token_limit', 'INT NULL');
    admin_ensure_column_safe($pdo, 'flow_admin_ai_user_access', 'daily_search_limit', 'INT NULL');
    admin_ensure_column_safe($pdo, 'flow_admin_ai_user_access', 'enabled', 'TINYINT NOT NULL DEFAULT 1');
    admin_ensure_column_safe($pdo, 'flow_admin_ai_user_access', 'updated_by_emp_id', 'INT NULL');
    admin_ensure_column_safe($pdo, 'flow_admin_ai_user_access', 'updated_at', 'DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP');
}

function admin_mask_secret(?string $value): string
{
    $value = (string)$value;
    if ($value === '') return '';
    $len = strlen($value);
    if ($len <= 8) return str_repeat('*', $len);
    return substr($value, 0, 4) . str_repeat('*', max(4, $len - 8)) . substr($value, -4);
}

function admin_csv_ids(mixed $value): array
{
    if (is_array($value)) return array_values(array_filter(array_map('intval', $value), static fn(int $id): bool => $id > 0));
    return array_values(array_filter(array_map('intval', preg_split('/\s*,\s*/', trim((string)$value))), static fn(int $id): bool => $id > 0));
}

function admin_ai_provider_map(PDO $pdo): array
{
    admin_ensure_ai_tables($pdo);
    $rows = flow_admin_rows($pdo, 'SELECT id, provider_name, api_type, model_name, status FROM flow_admin_ai_providers ORDER BY provider_name ASC, id ASC');
    $map = [];
    foreach ($rows as $row) $map[(int)($row['id'] ?? 0)] = $row;
    return $map;
}

function admin_ai_type_rules(PDO $pdo): array
{
    admin_ensure_ai_tables($pdo);
    $rows = flow_admin_rows($pdo, 'SELECT * FROM flow_admin_ai_type_rules');
    $rules = [];
    foreach (['A', 'B', 'C1', 'C2'] as $type) {
        $rules[$type] = [
            'employee_type' => $type,
            'access_mode' => $type === 'A' ? 'multiple' : ($type === 'B' ? 'single' : 'none'),
            'provider_ids' => '',
            'daily_token_limit' => 0,
            'daily_search_limit' => 0,
            'updated_at' => null,
        ];
    }
    foreach ($rows as $row) {
        $type = strtoupper((string)($row['employee_type'] ?? ''));
        if (isset($rules[$type])) $rules[$type] = array_merge($rules[$type], $row);
    }
    return $rules;
}

function admin_ai_access_summary(PDO $pdo, int $empId, string $employeeType): array
{
    admin_ensure_ai_tables($pdo);
    $providers = admin_ai_provider_map($pdo);
    $rules = admin_ai_type_rules($pdo);
    $user = flow_admin_rows($pdo, 'SELECT * FROM flow_admin_ai_user_access WHERE emp_id = :emp_id LIMIT 1', [':emp_id' => $empId])[0] ?? [];
    $effectiveType = strtoupper(trim((string)($user['employee_type_override'] ?? ''))) ?: $employeeType;
    if (!isset($rules[$effectiveType])) $effectiveType = $employeeType ?: 'C1';
    $rule = $rules[$effectiveType] ?? ['access_mode' => 'none', 'provider_ids' => '', 'daily_token_limit' => 0, 'daily_search_limit' => 0];
    $providerIds = admin_csv_ids(($user['provider_ids'] ?? '') !== '' ? $user['provider_ids'] : ($rule['provider_ids'] ?? ''));
    if (($user['provider_ids'] ?? '') === '' && ($rule['access_mode'] ?? 'none') === 'single' && count($providerIds) > 1) $providerIds = array_slice($providerIds, 0, 1);
    $assigned = [];
    foreach ($providerIds as $providerId) {
        if (isset($providers[$providerId])) $assigned[] = $providers[$providerId];
    }
    return [
        'employee_type' => $effectiveType,
        'access_mode' => $rule['access_mode'] ?? 'none',
        'providers' => $assigned,
        'available_providers' => array_values($providers),
        'provider_ids' => implode(',', $providerIds),
        'daily_token_limit' => ($user['daily_token_limit'] ?? null) !== null && $user['daily_token_limit'] !== '' ? (int)$user['daily_token_limit'] : (int)($rule['daily_token_limit'] ?? 0),
        'daily_search_limit' => ($user['daily_search_limit'] ?? null) !== null && $user['daily_search_limit'] !== '' ? (int)$user['daily_search_limit'] : (int)($rule['daily_search_limit'] ?? 0),
        'enabled' => !isset($user['enabled']) || (int)$user['enabled'] === 1,
        'updated_at' => $user['updated_at'] ?? ($rule['updated_at'] ?? null),
    ];
}

function admin_ai_access(PDO $pdo, string $search = ''): array
{
    admin_ensure_ai_tables($pdo);
    $providers = flow_admin_rows($pdo, 'SELECT id, provider_name, api_type, model_name, api_endpoint, api_key, status, notes, updated_at FROM flow_admin_ai_providers ORDER BY status DESC, provider_name ASC, id ASC');
    foreach ($providers as &$provider) {
        $provider['api_key_masked'] = admin_mask_secret((string)($provider['api_key'] ?? ''));
        unset($provider['api_key']);
    }
    unset($provider);
    $rules = array_values(admin_ai_type_rules($pdo));
    return ['status' => true, 'providers' => $providers, 'rules' => $rules, 'users' => admin_ai_users($pdo, $search ?? '')];
}


function admin_ai_users(PDO $pdo, string $search = ''): array
{
    admin_ensure_ai_tables($pdo);
    $assignedRows = flow_admin_rows($pdo, "SELECT emp_id, employee_type_override, provider_ids, daily_token_limit, daily_search_limit, enabled, updated_at FROM flow_admin_ai_user_access WHERE provider_ids IS NOT NULL AND provider_ids <> '' ORDER BY updated_at DESC, emp_id ASC LIMIT 500");
    if (!$assignedRows) return [];

    $providers = admin_ai_provider_map($pdo);
    $users = admin_users($pdo, '')['rows'] ?? [];
    $userMap = [];
    foreach ($users as $user) {
        $userMap[(int)($user['emp_id'] ?? 0)] = $user;
    }

    $needle = $search !== '' ? mb_strtolower($search) : '';
    $rows = [];
    foreach ($assignedRows as $access) {
        $empId = (int)($access['emp_id'] ?? 0);
        if ($empId <= 0) continue;
        $user = $userMap[$empId] ?? ['emp_id' => $empId, 'name' => '', 'designation' => '', 'employee_type' => 'C1'];
        $providerIds = admin_csv_ids($access['provider_ids'] ?? '');
        if (!$providerIds || (isset($access['enabled']) && (int)$access['enabled'] !== 1)) continue;
        $providerNames = [];
        foreach ($providerIds as $providerId) {
            if (isset($providers[$providerId])) {
                $providerNames[] = trim((string)($providers[$providerId]['provider_name'] ?? $providerId));
            }
        }
        $row = [
            'emp_id' => $empId,
            'name' => (string)($user['name'] ?? ''),
            'designation' => (string)($user['designation'] ?? ''),
            'employee_type' => strtoupper(trim((string)($access['employee_type_override'] ?? ''))) ?: (string)($user['employee_type'] ?? 'C1'),
            'access_mode' => count($providerIds) > 1 ? 'multiple' : 'single',
            'ai_keys' => implode(', ', array_filter($providerNames)),
            'provider_ids' => implode(',', $providerIds),
            'daily_token_limit' => (int)($access['daily_token_limit'] ?? 0),
            'daily_search_limit' => (int)($access['daily_search_limit'] ?? 0),
            'enabled' => true,
            'updated_at' => (string)($access['updated_at'] ?? ''),
        ];
        if ($needle !== '') {
            $haystack = mb_strtolower(implode(' ', [$row['emp_id'], $row['name'], $row['designation'], $row['employee_type'], $row['ai_keys']]));
            if (!str_contains($haystack, $needle)) continue;
        }
        $rows[] = $row;
    }
    return $rows;
}
function admin_save_ai_provider(PDO $pdo, int $adminEmpId): array
{
    admin_ensure_ai_tables($pdo);
    $id = (int)($_POST['id'] ?? 0);
    $name = trim((string)($_POST['provider_name'] ?? ''));
    $apiType = trim((string)($_POST['api_type'] ?? ''));
    $model = trim((string)($_POST['model_name'] ?? ''));
    $endpoint = trim((string)($_POST['api_endpoint'] ?? ''));
    $key = (string)($_POST['api_key'] ?? '');
    $status = (int)($_POST['status'] ?? 1) === 1 ? 1 : 0;
    $notes = trim((string)($_POST['notes'] ?? ''));
    if ($name === '' || $apiType === '') return ['status' => false, 'error' => 'AI provider name and API type are required.'];
    if ($id > 0) {
        $sets = ['provider_name = :name', 'api_type = :api_type', 'model_name = :model', 'api_endpoint = :endpoint', 'status = :status', 'notes = :notes', 'updated_by_emp_id = :admin_emp_id'];
        $params = [':name' => $name, ':api_type' => $apiType, ':model' => $model, ':endpoint' => $endpoint, ':status' => $status, ':notes' => $notes, ':admin_emp_id' => $adminEmpId, ':id' => $id];
        if ($key !== '') { $sets[] = 'api_key = :api_key'; $params[':api_key'] = $key; }
        $stmt = $pdo->prepare('UPDATE flow_admin_ai_providers SET ' . implode(', ', $sets) . ' WHERE id = :id');
        $stmt->execute($params);
    } else {
        $stmt = $pdo->prepare('INSERT INTO flow_admin_ai_providers (provider_name, api_type, model_name, api_endpoint, api_key, status, notes, created_by_emp_id, updated_by_emp_id) VALUES (:name, :api_type, :model, :endpoint, :api_key, :status, :notes, :created_by_emp_id, :updated_by_emp_id)');
        $stmt->execute([':name' => $name, ':api_type' => $apiType, ':model' => $model, ':endpoint' => $endpoint, ':api_key' => $key, ':status' => $status, ':notes' => $notes, ':created_by_emp_id' => $adminEmpId, ':updated_by_emp_id' => $adminEmpId]);
        $id = (int)$pdo->lastInsertId();
    }
    flow_admin_audit($adminEmpId, 'save_ai_provider', 'flow_admin_ai_providers', (string)$id, ['provider_name' => $name, 'api_type' => $apiType, 'api_key_saved' => $key !== '']);
    return ['status' => true, 'message' => 'AI provider saved.'];
}

function admin_save_ai_type_rule(PDO $pdo, int $adminEmpId): array
{
    admin_ensure_ai_tables($pdo);
    $type = strtoupper(trim((string)($_POST['employee_type'] ?? '')));
    if (!in_array($type, ['A', 'B', 'C1', 'C2'], true)) return ['status' => false, 'error' => 'Employee type must be A, B, C1, or C2.'];
    $mode = trim((string)($_POST['access_mode'] ?? 'none'));
    if (!in_array($mode, ['none', 'single', 'multiple'], true)) $mode = 'none';
    $providerIds = admin_csv_ids($_POST['provider_ids'] ?? '');
    if ($mode === 'single' && count($providerIds) > 1) $providerIds = array_slice($providerIds, 0, 1);
    $tokenLimit = max(0, (int)($_POST['daily_token_limit'] ?? 0));
    $searchLimit = max(0, (int)($_POST['daily_search_limit'] ?? 0));
    $stmt = $pdo->prepare('INSERT INTO flow_admin_ai_type_rules (employee_type, access_mode, provider_ids, daily_token_limit, daily_search_limit, updated_by_emp_id, updated_at) VALUES (:employee_type, :access_mode, :provider_ids, :token_limit, :search_limit, :admin_emp_id, NOW()) ON DUPLICATE KEY UPDATE access_mode = VALUES(access_mode), provider_ids = VALUES(provider_ids), daily_token_limit = VALUES(daily_token_limit), daily_search_limit = VALUES(daily_search_limit), updated_by_emp_id = VALUES(updated_by_emp_id), updated_at = NOW()');
    $stmt->execute([':employee_type' => $type, ':access_mode' => $mode, ':provider_ids' => implode(',', $providerIds), ':token_limit' => $tokenLimit, ':search_limit' => $searchLimit, ':admin_emp_id' => $adminEmpId]);
    flow_admin_audit($adminEmpId, 'save_ai_type_rule', 'flow_admin_ai_type_rules', $type, ['access_mode' => $mode, 'provider_ids' => $providerIds, 'token_limit' => $tokenLimit, 'search_limit' => $searchLimit]);
    return ['status' => true, 'message' => 'AI access rule saved.'];
}

function admin_save_ai_user_access(PDO $pdo, int $adminEmpId): array
{
    admin_ensure_ai_tables($pdo);
    $empId = (int)($_POST['emp_id'] ?? $_POST['id'] ?? 0);
    if ($empId <= 0) return ['status' => false, 'error' => 'Valid employee ID is required.'];
    $type = strtoupper(trim((string)($_POST['employee_type_override'] ?? '')));
    if ($type !== '' && !in_array($type, ['A', 'B', 'C1', 'C2'], true)) return ['status' => false, 'error' => 'Employee type must be A, B, C1, or C2.'];
    $mode = trim((string)($_POST['access_mode'] ?? ''));
    if ($mode !== '' && !in_array($mode, ['none', 'single', 'multiple'], true)) $mode = '';
    $providerIds = admin_csv_ids($_POST['provider_ids'] ?? '');
    if ($mode === 'single' && count($providerIds) > 1) $providerIds = array_slice($providerIds, 0, 1);
    $tokenLimit = ($_POST['daily_token_limit'] ?? '') === '' ? null : max(0, (int)$_POST['daily_token_limit']);
    $searchLimit = ($_POST['daily_search_limit'] ?? '') === '' ? null : max(0, (int)$_POST['daily_search_limit']);
    $enabled = (int)($_POST['enabled'] ?? 1) === 1 ? 1 : 0;
    $stmt = $pdo->prepare('INSERT INTO flow_admin_ai_user_access (emp_id, employee_type_override, provider_ids, daily_token_limit, daily_search_limit, enabled, updated_by_emp_id, updated_at) VALUES (:emp_id, :employee_type, :provider_ids, :token_limit, :search_limit, :enabled, :admin_emp_id, NOW()) ON DUPLICATE KEY UPDATE employee_type_override = VALUES(employee_type_override), provider_ids = VALUES(provider_ids), daily_token_limit = VALUES(daily_token_limit), daily_search_limit = VALUES(daily_search_limit), enabled = VALUES(enabled), updated_by_emp_id = VALUES(updated_by_emp_id), updated_at = NOW()');
    $stmt->execute([':emp_id' => $empId, ':employee_type' => $type !== '' ? $type : null, ':provider_ids' => implode(',', $providerIds), ':token_limit' => $tokenLimit, ':search_limit' => $searchLimit, ':enabled' => $enabled, ':admin_emp_id' => $adminEmpId]);
    flow_admin_audit($adminEmpId, 'save_ai_user_access', 'flow_admin_ai_user_access', (string)$empId, ['employee_type' => $type, 'access_mode' => $mode, 'provider_ids' => $providerIds, 'token_limit' => $tokenLimit, 'search_limit' => $searchLimit, 'enabled' => $enabled]);
    return ['status' => true, 'message' => 'User AI access saved.'];
}
function admin_messages(PDO $pdo, string $search): array
{
    $where = '1=1';
    $params = [];
    if ($search !== '') {
        $where .= ' AND (body LIKE :q OR file_name LIKE :q OR from_jid LIKE :q OR to_jid LIKE :q)';
        $params[':q'] = '%' . $search . '%';
    }
    return ['status' => true, 'rows' => flow_admin_rows($pdo,
        "SELECT id, from_jid, to_jid, LEFT(body, 260) AS body, file_name, file_type, file_size,
                message_type, status, deleted_at, created_at,
                CASE WHEN deleted_at IS NULL THEN 'delete_message' ELSE 'restore_message' END AS admin_action
         FROM xmpp_messages WHERE {$where} ORDER BY id DESC LIMIT 120", $params)];
}

function admin_attachments(PDO $pdo, string $search): array
{
    $where = "file_url IS NOT NULL AND file_url <> ''";
    $params = [];
    if ($search !== '') {
        $where .= ' AND (file_name LIKE :q OR file_type LIKE :q OR from_jid LIKE :q OR to_jid LIKE :q)';
        $params[':q'] = '%' . $search . '%';
    }
    return ['status' => true, 'rows' => flow_admin_rows($pdo,
        "SELECT id, from_jid, to_jid, file_name, file_type, file_size, file_restricted, deleted_at, created_at,
                CASE WHEN deleted_at IS NULL THEN 'delete_message' ELSE 'restore_message' END AS admin_action
         FROM xmpp_messages WHERE {$where} ORDER BY id DESC LIMIT 120", $params)];
}

function admin_location(PDO $pdo): array
{
    return ['status' => true, 'rows' => flow_admin_rows($pdo,
        "SELECT lv.emp_id, lv.enabled, lv.updated_by_emp_id, lv.updated_at, p.last_seen_at
         FROM xmpp_location_visibility lv
         LEFT JOIN xmpp_user_presence p ON p.emp_id = lv.emp_id
         ORDER BY lv.enabled DESC, lv.emp_id ASC LIMIT 200")];
}

function admin_tasks(string $search): array
{
    $taskPdo = flow_admin_task_db();
    if (!flow_admin_table_exists($taskPdo, 'task_master')) return ['status' => true, 'rows' => []];
    $where = '1=1';
    $params = [];
    if ($search !== '') {
        $where .= ' AND (title LIKE :q OR description LIKE :q OR CAST(emp_id AS CHAR) LIKE :q OR CAST(created_by AS CHAR) LIKE :q OR task_followers LIKE :q)';
        $params[':q'] = '%' . $search . '%';
    }
    return ['status' => true, 'rows' => flow_admin_rows($taskPdo,
        "SELECT id, title, priority, emp_id, task_followers, task_groups, task_type, deadline, status, created_by, created_at
         FROM task_master WHERE {$where} ORDER BY id DESC LIMIT 120", $params)];
}

function admin_notifications(PDO $pdo, string $search): array
{
    if (!flow_admin_table_exists($pdo, 'xmpp_push_queue')) return ['status' => true, 'rows' => []];
    $where = '1=1';
    $params = [];
    if ($search !== '') {
        $where .= ' AND (title LIKE :q OR body LIKE :q OR status LIKE :q OR CAST(emp_id AS CHAR) LIKE :q)';
        $params[':q'] = '%' . $search . '%';
    }
    return ['status' => true, 'rows' => flow_admin_rows($pdo,
        "SELECT id, emp_id, title, LEFT(body, 180) AS body, status, attempts, last_error, created_at, 'retry_notification' AS admin_action
         FROM xmpp_push_queue WHERE {$where} ORDER BY id DESC LIMIT 120", $params)];
}

function admin_releases(PDO $pdo): array
{
    if (!flow_admin_table_exists($pdo, 'xmpp_release_builds')) return ['status' => true, 'rows' => []];
    return ['status' => true, 'rows' => flow_admin_rows($pdo,
        "SELECT id, platform, version, build_number, status, stage, rollout_percent, force_update, artifact_url, created_at,
                CASE WHEN LOWER(status) IN ('draft','development') THEN 'approve_release' ELSE 'rollback_release' END AS admin_action
         FROM xmpp_release_builds ORDER BY id DESC LIMIT 100")];
}

function admin_simple(PDO $pdo, string $table, string $order = 'id DESC'): array
{
    if (!flow_admin_table_exists($pdo, $table)) return ['status' => true, 'rows' => []];
    return ['status' => true, 'rows' => flow_admin_rows($pdo, "SELECT * FROM {$table} ORDER BY {$order} LIMIT 120")];
}

function admin_ensure_external_tables(PDO $pdo): void
{
    $pdo->exec("CREATE TABLE IF NOT EXISTS external_contacts (
        id INT AUTO_INCREMENT PRIMARY KEY,
        display_name VARCHAR(160) NOT NULL,
        email VARCHAR(190) NULL,
        phone VARCHAR(40) NULL,
        whatsapp_number VARCHAR(40) NULL,
        telegram_username VARCHAR(120) NULL,
        telegram_chat_id VARCHAR(120) NULL,
        status TINYINT NOT NULL DEFAULT 1,
        created_by_emp_id INT NULL,
        updated_by_emp_id INT NULL,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX idx_external_contacts_name (display_name),
        INDEX idx_external_contacts_status (status)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    admin_ensure_column_safe($pdo, 'external_contacts', 'display_name', 'VARCHAR(160) NOT NULL DEFAULT \'\'');
    admin_ensure_column_safe($pdo, 'external_contacts', 'email', 'VARCHAR(190) NULL');
    admin_ensure_column_safe($pdo, 'external_contacts', 'phone', 'VARCHAR(40) NULL');
    admin_ensure_column_safe($pdo, 'external_contacts', 'whatsapp_number', 'VARCHAR(40) NULL');
    admin_ensure_column_safe($pdo, 'external_contacts', 'telegram_username', 'VARCHAR(120) NULL');
    admin_ensure_column_safe($pdo, 'external_contacts', 'telegram_chat_id', 'VARCHAR(120) NULL');
    admin_ensure_column_safe($pdo, 'external_contacts', 'status', 'TINYINT NOT NULL DEFAULT 1');
    admin_ensure_column_safe($pdo, 'external_contacts', 'created_by_emp_id', 'INT NULL');
    admin_ensure_column_safe($pdo, 'external_contacts', 'updated_by_emp_id', 'INT NULL');
    admin_ensure_column_safe($pdo, 'external_contacts', 'created_at', 'DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP');
    admin_ensure_column_safe($pdo, 'external_contacts', 'updated_at', 'DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP');

    $pdo->exec("CREATE TABLE IF NOT EXISTS xmpp_group_external_members (
        id INT AUTO_INCREMENT PRIMARY KEY,
        group_id INT NOT NULL,
        external_contact_id INT NOT NULL,
        delivery_channels VARCHAR(160) NOT NULL DEFAULT '',
        mention_token VARCHAR(180) NOT NULL DEFAULT '',
        status TINYINT NOT NULL DEFAULT 1,
        added_by_emp_id INT NULL,
        added_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        removed_at DATETIME NULL,
        UNIQUE KEY uq_group_external_contact (group_id, external_contact_id),
        INDEX idx_group_external_group (group_id, status),
        INDEX idx_group_external_contact (external_contact_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    admin_ensure_column_safe($pdo, 'xmpp_group_external_members', 'delivery_channels', 'VARCHAR(160) NOT NULL DEFAULT \'\'');
    admin_ensure_column_safe($pdo, 'xmpp_group_external_members', 'mention_token', 'VARCHAR(180) NOT NULL DEFAULT \'\'');
    admin_ensure_column_safe($pdo, 'xmpp_group_external_members', 'status', 'TINYINT NOT NULL DEFAULT 1');
    admin_ensure_column_safe($pdo, 'xmpp_group_external_members', 'removed_at', 'DATETIME NULL');

    $pdo->exec("CREATE TABLE IF NOT EXISTS external_user_requests (
        id BIGINT AUTO_INCREMENT PRIMARY KEY,
        group_id INT NOT NULL,
        requested_by_emp_id INT NOT NULL,
        display_name VARCHAR(160) NOT NULL,
        email VARCHAR(190) NULL,
        phone VARCHAR(40) NULL,
        whatsapp_number VARCHAR(40) NULL,
        telegram_username VARCHAR(120) NULL,
        delivery_channels VARCHAR(160) NOT NULL DEFAULT '',
        mention_token VARCHAR(180) NOT NULL DEFAULT '',
        reason TEXT NULL,
        status VARCHAR(24) NOT NULL DEFAULT 'pending',
        reviewed_by_emp_id INT NULL,
        reviewed_at DATETIME NULL,
        review_note TEXT NULL,
        external_contact_id INT NULL,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX idx_external_user_requests_status (status, created_at),
        INDEX idx_external_user_requests_group (group_id, status),
        INDEX idx_external_user_requests_requested_by (requested_by_emp_id, created_at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");
    admin_ensure_column_safe($pdo, 'external_user_requests', 'delivery_channels', 'VARCHAR(160) NOT NULL DEFAULT \'\'');
    admin_ensure_column_safe($pdo, 'external_user_requests', 'mention_token', 'VARCHAR(180) NOT NULL DEFAULT \'\'');
    admin_ensure_column_safe($pdo, 'external_user_requests', 'reason', 'TEXT NULL');
    admin_ensure_column_safe($pdo, 'external_user_requests', 'review_note', 'TEXT NULL');
    admin_ensure_column_safe($pdo, 'external_user_requests', 'external_contact_id', 'INT NULL');

    $pdo->exec("CREATE TABLE IF NOT EXISTS xmpp_external_delivery_queue (
        id BIGINT AUTO_INCREMENT PRIMARY KEY,
        group_id INT NOT NULL,
        external_contact_id INT NOT NULL,
        message_id BIGINT NULL,
        event_type VARCHAR(40) NOT NULL DEFAULT 'mention',
        channel VARCHAR(24) NOT NULL,
        destination VARCHAR(190) NOT NULL,
        subject VARCHAR(255) NULL,
        body TEXT NOT NULL,
        status VARCHAR(24) NOT NULL DEFAULT 'queued',
        attempts INT NOT NULL DEFAULT 0,
        last_error TEXT NULL,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        sent_at DATETIME NULL,
        INDEX idx_external_delivery_status (status, created_at),
        INDEX idx_external_delivery_message (message_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
}

function admin_external_token(string $name): string
{
    $token = preg_replace('/[^A-Za-z0-9_]+/', '', str_replace(' ', '_', trim($name))) ?: 'external';
    return '@' . $token;
}

function admin_group_external_members(PDO $pdo, int $groupId): array
{
    admin_ensure_external_tables($pdo);
    return flow_admin_rows($pdo, "SELECT gm.id AS membership_id, gm.group_id, gm.external_contact_id, gm.delivery_channels, gm.mention_token, gm.status, gm.added_at, c.display_name, c.email, c.phone, c.whatsapp_number, c.telegram_username, c.telegram_chat_id
        FROM xmpp_group_external_members gm
        INNER JOIN external_contacts c ON c.id = gm.external_contact_id
        WHERE gm.group_id = :group_id AND gm.status = 1
        ORDER BY c.display_name ASC", [':group_id' => $groupId]);
}

function admin_external_destination(array $contact, string $channel): string
{
    return match ($channel) {
        'email' => trim((string)($contact['email'] ?? '')),
        'whatsapp' => trim((string)($contact['whatsapp_number'] ?? $contact['phone'] ?? '')),
        'telegram' => trim((string)($contact['telegram_chat_id'] ?? $contact['telegram_username'] ?? '')),
        'sms' => trim((string)($contact['phone'] ?? '')),
        default => '',
    };
}

function admin_queue_external_delivery(PDO $pdo, int $groupId, int $contactId, ?int $messageId, string $eventType, array $channels, string $subject, string $body): void
{
    admin_ensure_external_tables($pdo);
    $contact = flow_admin_rows($pdo, 'SELECT * FROM external_contacts WHERE id = :id LIMIT 1', [':id' => $contactId])[0] ?? [];
    if (!$contact) return;
    $stmt = $pdo->prepare('INSERT INTO xmpp_external_delivery_queue (group_id, external_contact_id, message_id, event_type, channel, destination, subject, body, status) VALUES (:group_id, :contact_id, :message_id, :event_type, :channel, :destination, :subject, :body, :status)');
    foreach ($channels as $channel) {
        $channel = strtolower(trim((string)$channel));
        if (!in_array($channel, ['email', 'whatsapp', 'telegram', 'sms'], true)) continue;
        $destination = admin_external_destination($contact, $channel);
        if ($destination === '') continue;
        $stmt->execute([':group_id' => $groupId, ':contact_id' => $contactId, ':message_id' => $messageId, ':event_type' => $eventType, ':channel' => $channel, ':destination' => $destination, ':subject' => $subject, ':body' => $body, ':status' => 'queued']);
    }
}

function admin_external_requests(PDO $pdo, string $search): array
{
    admin_ensure_external_tables($pdo);
    $where = '1=1';
    $params = [];
    if ($search !== '') {
        $where .= ' AND (r.display_name LIKE :q OR r.email LIKE :q OR r.phone LIKE :q OR r.whatsapp_number LIKE :q OR r.telegram_username LIKE :q OR g.room_name LIKE :q)';
        $params[':q'] = '%' . $search . '%';
    }
    $rows = flow_admin_rows($pdo, "SELECT r.id, r.group_id, r.requested_by_emp_id, r.display_name, r.email, r.phone, r.whatsapp_number, r.telegram_username, r.delivery_channels, r.mention_token, r.reason, r.status, r.reviewed_by_emp_id, r.reviewed_at, r.review_note, r.external_contact_id, r.created_at, g.room_name, g.room_jid, g.group_type, g.channel_kind
        FROM external_user_requests r
        LEFT JOIN xmpp_groups g ON g.id = r.group_id
        WHERE {$where}
        ORDER BY CASE r.status WHEN 'pending' THEN 0 WHEN 'approved' THEN 1 ELSE 2 END, r.created_at DESC
        LIMIT 300", $params);
    return ['status' => true, 'rows' => $rows];
}

function admin_approve_external_request(PDO $pdo, int $adminEmpId): array
{
    admin_ensure_external_tables($pdo);
    $requestId = (int)($_POST['request_id'] ?? $_POST['id'] ?? 0);
    if ($requestId <= 0) return ['status' => false, 'error' => 'Request is required.'];
    $request = flow_admin_rows($pdo, 'SELECT * FROM external_user_requests WHERE id = :id LIMIT 1', [':id' => $requestId])[0] ?? [];
    if (!$request) return ['status' => false, 'error' => 'Request not found.'];
    if ((string)($request['status'] ?? '') !== 'pending') return ['status' => false, 'error' => 'Request already reviewed.'];

    $_POST['group_id'] = (string)$request['group_id'];
    $_POST['display_name'] = (string)$request['display_name'];
    $_POST['email'] = (string)($request['email'] ?? '');
    $_POST['phone'] = (string)($request['phone'] ?? '');
    $_POST['whatsapp_number'] = (string)($request['whatsapp_number'] ?? '');
    $_POST['telegram_username'] = (string)($request['telegram_username'] ?? '');
    $_POST['delivery_channels'] = (string)$request['delivery_channels'];
    $added = admin_add_external_member($pdo, $adminEmpId);
    if (($added['status'] ?? false) !== true) return $added;
    $contactId = (int)($added['external_contact_id'] ?? 0);
    $stmt = $pdo->prepare("UPDATE external_user_requests SET status = 'approved', reviewed_by_emp_id = :admin, reviewed_at = NOW(), review_note = :note, external_contact_id = :contact_id WHERE id = :id");
    $stmt->execute([':admin' => $adminEmpId, ':note' => trim((string)($_POST['review_note'] ?? '')), ':contact_id' => $contactId > 0 ? $contactId : null, ':id' => $requestId]);
    flow_admin_audit($adminEmpId, 'approve_external_request', 'external_user_requests', (string)$requestId, ['external_contact_id' => $contactId]);
    return ['status' => true, 'request_id' => $requestId, 'external_contact_id' => $contactId];
}

function admin_reject_external_request(PDO $pdo, int $adminEmpId): array
{
    admin_ensure_external_tables($pdo);
    $requestId = (int)($_POST['request_id'] ?? $_POST['id'] ?? 0);
    if ($requestId <= 0) return ['status' => false, 'error' => 'Request is required.'];
    $stmt = $pdo->prepare("UPDATE external_user_requests SET status = 'rejected', reviewed_by_emp_id = :admin, reviewed_at = NOW(), review_note = :note WHERE id = :id AND status = 'pending'");
    $stmt->execute([':admin' => $adminEmpId, ':note' => trim((string)($_POST['review_note'] ?? '')), ':id' => $requestId]);
    flow_admin_audit($adminEmpId, 'reject_external_request', 'external_user_requests', (string)$requestId, []);
    return ['status' => true, 'request_id' => $requestId];
}

function admin_add_external_member(PDO $pdo, int $adminEmpId): array
{
    admin_ensure_external_tables($pdo);
    $groupId = (int)($_POST['group_id'] ?? 0);
    $name = trim((string)($_POST['display_name'] ?? ''));
    $email = trim((string)($_POST['email'] ?? ''));
    $phone = trim((string)($_POST['phone'] ?? ''));
    $whatsapp = trim((string)($_POST['whatsapp_number'] ?? $phone));
    $telegram = trim((string)($_POST['telegram_username'] ?? ''));
    $channels = array_values(array_filter(array_map('trim', explode(',', strtolower((string)($_POST['delivery_channels'] ?? ''))))));
    $channels = array_values(array_intersect($channels, ['email', 'whatsapp', 'telegram', 'sms']));
    if ($groupId <= 0 || $name === '' || !$channels) return ['status' => false, 'error' => 'Group, external name and at least one delivery channel are required.'];
    $group = flow_admin_rows($pdo, 'SELECT id, room_jid, room_name FROM xmpp_groups WHERE id = :id LIMIT 1', [':id' => $groupId])[0] ?? [];
    if (!$group) return ['status' => false, 'error' => 'Group/channel not found.'];
    $contactId = (int)($_POST['external_contact_id'] ?? 0);
    if ($contactId > 0) {
        $stmt = $pdo->prepare('UPDATE external_contacts SET display_name = :name, email = :email, phone = :phone, whatsapp_number = :whatsapp, telegram_username = :telegram, status = 1, updated_by_emp_id = :admin_emp_id WHERE id = :id');
        $stmt->execute([':name' => $name, ':email' => $email ?: null, ':phone' => $phone ?: null, ':whatsapp' => $whatsapp ?: null, ':telegram' => $telegram ?: null, ':admin_emp_id' => $adminEmpId, ':id' => $contactId]);
    } else {
        $stmt = $pdo->prepare('INSERT INTO external_contacts (display_name, email, phone, whatsapp_number, telegram_username, status, created_by_emp_id, updated_by_emp_id) VALUES (:name, :email, :phone, :whatsapp, :telegram, 1, :created_by_emp_id, :updated_by_emp_id)');
        $stmt->execute([':name' => $name, ':email' => $email ?: null, ':phone' => $phone ?: null, ':whatsapp' => $whatsapp ?: null, ':telegram' => $telegram ?: null, ':created_by_emp_id' => $adminEmpId, ':updated_by_emp_id' => $adminEmpId]);
        $contactId = (int)$pdo->lastInsertId();
    }
    $token = admin_external_token($name);
    $stmt = $pdo->prepare('INSERT INTO xmpp_group_external_members (group_id, external_contact_id, delivery_channels, mention_token, status, added_by_emp_id, added_at, removed_at) VALUES (:group_id, :contact_id, :channels, :token, 1, :admin_emp_id, NOW(), NULL) ON DUPLICATE KEY UPDATE delivery_channels = VALUES(delivery_channels), mention_token = VALUES(mention_token), status = 1, added_by_emp_id = VALUES(added_by_emp_id), removed_at = NULL');
    $stmt->execute([':group_id' => $groupId, ':contact_id' => $contactId, ':channels' => implode(',', $channels), ':token' => $token, ':admin_emp_id' => $adminEmpId]);

    $welcome = $name . ' was added as an external contact. Mention ' . $token . ' to send selected group/channel messages through ' . implode(', ', $channels) . '.';
    $msg = $pdo->prepare('INSERT INTO xmpp_messages (from_jid, to_jid, body, message_type, status, source_device, source_name) VALUES (:from_jid, :to_jid, :body, :message_type, :status, :source_device, :source_name)');
    $msg->execute([':from_jid' => 'system@chat.skylinkonline.net', ':to_jid' => (string)$group['room_jid'], ':body' => $welcome, ':message_type' => 'groupchat', ':status' => 'sent', ':source_device' => 'system', ':source_name' => 'External contact welcome']);
    $messageId = (int)$pdo->lastInsertId();
    admin_queue_external_delivery($pdo, $groupId, $contactId, $messageId, 'welcome', $channels, 'Welcome to ' . (string)$group['room_name'], $welcome);
    flow_admin_audit($adminEmpId, 'add_external_member', 'xmpp_group_external_members', $groupId . ':' . $contactId, ['channels' => $channels, 'mention_token' => $token]);
    return ['status' => true, 'message' => 'External user added. Welcome delivery queued.', 'mention_token' => $token];
}

function admin_remove_external_member(PDO $pdo, int $adminEmpId): array
{
    admin_ensure_external_tables($pdo);
    $groupId = (int)($_POST['group_id'] ?? 0);
    $contactId = (int)($_POST['external_contact_id'] ?? 0);
    if ($groupId <= 0 || $contactId <= 0) return ['status' => false, 'error' => 'Group and external contact are required.'];
    $stmt = $pdo->prepare('UPDATE xmpp_group_external_members SET status = 0, removed_at = NOW() WHERE group_id = :group_id AND external_contact_id = :contact_id');
    $stmt->execute([':group_id' => $groupId, ':contact_id' => $contactId]);
    flow_admin_audit($adminEmpId, 'remove_external_member', 'xmpp_group_external_members', $groupId . ':' . $contactId, []);
    return ['status' => true, 'message' => 'External user removed.'];
}
function admin_add_group_member(PDO $pdo, int $adminEmpId): array
{
    $groupId = (int)($_POST['group_id'] ?? 0);
    $empId = (int)($_POST['emp_id'] ?? 0);
    $role = strtolower(trim((string)($_POST['role'] ?? 'member')));
    $showHistory = (int)($_POST['show_history'] ?? 0) === 1;
    if ($groupId <= 0 || $empId <= 0 || !in_array($role, ['owner', 'admin', 'member'], true)) {
        return ['status' => false, 'error' => 'Group, employee and role are required.'];
    }
    $group = flow_admin_rows($pdo, 'SELECT id, room_jid, room_name FROM xmpp_groups WHERE id = :id LIMIT 1', [':id' => $groupId])[0] ?? [];
    if (!$group) return ['status' => false, 'error' => 'Group/channel not found.'];

    $memberGroupCol = admin_first_existing_column($pdo, 'xmpp_group_members', ['group_id', 'room_id', 'xmpp_group_id']);
    $memberEmpCol = admin_first_existing_column($pdo, 'xmpp_group_members', ['emp_id', 'employee_id', 'user_id', 'member_emp_id']);
    $memberRoleCol = admin_first_existing_column($pdo, 'xmpp_group_members', ['role', 'member_role', 'access_role']);
    if ($memberGroupCol === '' || $memberEmpCol === '') return ['status' => false, 'error' => 'Group member schema is not mapped.'];

    $columns = [$memberGroupCol, $memberEmpCol];
    $values = [':group_id', ':emp_id'];
    $params = [':group_id' => $groupId, ':emp_id' => $empId];
    $updates = [];
    if ($memberRoleCol !== '') {
        $columns[] = $memberRoleCol;
        $values[] = ':role';
        $params[':role'] = $role;
        $updates[] = "`{$memberRoleCol}` = VALUES(`{$memberRoleCol}`)";
    }
    $historyCol = admin_first_existing_column($pdo, 'xmpp_group_members', ['history_visible_from']);
    if ($historyCol !== '') {
        $columns[] = $historyCol;
        $values[] = ':history_visible_from';
        $params[':history_visible_from'] = $showHistory ? null : date('Y-m-d H:i:s');
        $updates[] = "`{$historyCol}` = VALUES(`{$historyCol}`)";
    }
    $joinedCol = admin_first_existing_column($pdo, 'xmpp_group_members', ['joined_at', 'created_at', 'added_at']);
    if ($joinedCol !== '') $updates[] = "`{$joinedCol}` = COALESCE(`{$joinedCol}`, NOW())";
    if (!$updates) $updates[] = "`{$memberEmpCol}` = VALUES(`{$memberEmpCol}`)";

    $sql = 'INSERT INTO xmpp_group_members (`' . implode('`, `', $columns) . '`) VALUES (' . implode(', ', $values) . ') ON DUPLICATE KEY UPDATE ' . implode(', ', $updates);
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);

    if (flow_admin_table_exists($pdo, 'xmpp_group_reads') && (string)($group['room_jid'] ?? '') !== '') {
        try {
            $read = $pdo->prepare('INSERT INTO xmpp_group_reads (group_id, emp_id, last_read_message_id, read_at) SELECT :group_id, :emp_id, COALESCE(MAX(id), 0), NOW() FROM xmpp_messages WHERE to_jid = :room_jid ON DUPLICATE KEY UPDATE last_read_message_id = VALUES(last_read_message_id), read_at = NOW()');
            $read->execute([':group_id' => $groupId, ':emp_id' => $empId, ':room_jid' => (string)$group['room_jid']]);
        } catch (Throwable $e) {
            error_log('admin add member read marker failed: ' . $e->getMessage());
        }
    }

    $xmppStatus = 'not_synced';
    try {
        $room = explode('@', (string)($group['room_jid'] ?? ''), 2)[0];
        if ($room !== '') {
            flow_admin_ejabberd_request('set_room_affiliation', [
                'name' => $room,
                'service' => (string)flow_admin_config('muc_domain', FLOW_ADMIN_MUC_DOMAIN_DEFAULT),
                'jid' => flow_admin_jid($empId),
                'affiliation' => $role === 'owner' ? 'owner' : ($role === 'admin' ? 'admin' : 'member'),
            ]);
            $xmppStatus = 'synced';
        }
    } catch (Throwable $e) {
        $xmppStatus = 'failed: ' . $e->getMessage();
        error_log('admin add member xmpp sync failed: ' . $e->getMessage());
    }

    flow_admin_audit($adminEmpId, 'add_member', 'xmpp_group_members', $groupId . ':' . $empId, [
        'role' => $role,
        'show_history' => $showHistory,
        'xmpp' => $xmppStatus,
    ]);
    return ['status' => true, 'message' => 'Member added.', 'xmpp' => $xmppStatus];
}

function admin_delete_group_channel(PDO $pdo, int $adminEmpId, int $groupId): array
{
    if ($groupId <= 0) return ['status' => false, 'error' => 'Valid group/channel id is required.'];
    $group = flow_admin_rows($pdo, 'SELECT id, room_jid, room_name FROM xmpp_groups WHERE id = :id LIMIT 1', [':id' => $groupId])[0] ?? [];
    if (!$group) return ['status' => false, 'error' => 'Group/channel not found.'];

    if (!flow_admin_column_exists($pdo, 'xmpp_groups', 'deleted_at')) {
        try { $pdo->exec('ALTER TABLE xmpp_groups ADD COLUMN deleted_at DATETIME NULL'); } catch (Throwable $e) { error_log('admin add deleted_at failed: ' . $e->getMessage()); }
    }
    $sets = [];
    if (flow_admin_column_exists($pdo, 'xmpp_groups', 'deleted_at')) $sets[] = 'deleted_at = NOW()';
    if (flow_admin_column_exists($pdo, 'xmpp_groups', 'is_archived')) $sets[] = 'is_archived = 1';
    if (flow_admin_column_exists($pdo, 'xmpp_groups', 'archived_at')) $sets[] = 'archived_at = NOW()';
    if (!$sets) return ['status' => false, 'error' => 'Group delete fields are not available.'];
    $stmt = $pdo->prepare('UPDATE xmpp_groups SET ' . implode(', ', $sets) . ' WHERE id = :id');
    $stmt->execute([':id' => $groupId]);

    flow_admin_audit($adminEmpId, 'delete_group_channel', 'xmpp_groups', (string)$groupId, [
        'room_name' => (string)($group['room_name'] ?? ''),
        'room_jid' => (string)($group['room_jid'] ?? ''),
        'mode' => 'soft_delete_archive',
    ]);
    return ['status' => true, 'message' => 'Group/channel deleted from active lists.'];
}
function admin_post_action(PDO $pdo, int $adminEmpId, string $action): array
{
    flow_admin_require_csrf();
    $id = (int)($_POST['id'] ?? 0);
    if ($id <= 0 && !in_array($action, ['set_member_role', 'add_member', 'remove_member', 'add_external_member', 'remove_external_member', 'approve_external_request', 'reject_external_request', 'save_ai_provider', 'save_ai_type_rule', 'save_ai_user_access'], true)) {
        return ['status' => false, 'error' => 'Valid id is required.'];
    }

    switch ($action) {
        case 'archive_channel':
        case 'unarchive_channel':
            $archived = $action === 'archive_channel' ? 1 : 0;
            $stmt = $pdo->prepare('UPDATE xmpp_groups SET is_archived = :archived, archived_at = IF(:archived = 1, NOW(), NULL) WHERE id = :id');
            $stmt->execute([':archived' => $archived, ':id' => $id]);
            flow_admin_audit($adminEmpId, $action, 'xmpp_groups', (string)$id, ['is_archived' => $archived]);
            return ['status' => true, 'message' => $archived ? 'Channel archived.' : 'Channel unarchived.'];

        case 'delete_message':
        case 'restore_message':
            $deleted = $action === 'delete_message';
            $stmt = $pdo->prepare('UPDATE xmpp_messages SET deleted_at = ' . ($deleted ? 'NOW()' : 'NULL') . ' WHERE id = :id');
            $stmt->execute([':id' => $id]);
            flow_admin_audit($adminEmpId, $action, 'xmpp_messages', (string)$id, []);
            return ['status' => true, 'message' => $deleted ? 'Message hidden.' : 'Message restored.'];

        case 'retry_notification':
            $stmt = $pdo->prepare("UPDATE xmpp_push_queue SET status = 'pending', last_error = NULL WHERE id = :id");
            $stmt->execute([':id' => $id]);
            flow_admin_audit($adminEmpId, $action, 'xmpp_push_queue', (string)$id, []);
            return ['status' => true, 'message' => 'Notification queued for retry.'];

        case 'approve_release':
            $sets = ["status = 'ProductionApproved'"];
            if (flow_admin_column_exists($pdo, 'xmpp_release_builds', 'stage')) $sets[] = "stage = 'Production'";
            if (flow_admin_column_exists($pdo, 'xmpp_release_builds', 'approved_by_emp_id')) $sets[] = 'approved_by_emp_id = ' . $adminEmpId;
            if (flow_admin_column_exists($pdo, 'xmpp_release_builds', 'approved_at')) $sets[] = 'approved_at = NOW()';
            $stmt = $pdo->prepare('UPDATE xmpp_release_builds SET ' . implode(', ', $sets) . ' WHERE id = :id');
            $stmt->execute([':id' => $id]);
            flow_admin_audit($adminEmpId, $action, 'xmpp_release_builds', (string)$id, []);
            return ['status' => true, 'message' => 'Release approved for production.'];

        case 'rollback_release':
            $stmt = $pdo->prepare("UPDATE xmpp_release_builds SET status = 'RolledBack' WHERE id = :id");
            $stmt->execute([':id' => $id]);
            flow_admin_audit($adminEmpId, $action, 'xmpp_release_builds', (string)$id, []);
            return ['status' => true, 'message' => 'Release marked as rolled back.'];

        case 'update_user_password':
            $newPassword = (string)($_POST['password'] ?? '');
            if ($newPassword === '') return ['status' => false, 'error' => 'New password is required.'];
            $stmt = $pdo->prepare('UPDATE xmpp_users SET xmpp_password = :password, updated_at = NOW() WHERE emp_id = :id');
            $stmt->execute([':password' => $newPassword, ':id' => $id]);
            try {
                $user = (string)$id;
                flow_admin_ejabberd_request('change_password', [
                    'user' => $user,
                    'host' => (string)flow_admin_config('chat_domain', FLOW_ADMIN_CHAT_DOMAIN_DEFAULT),
                    'newpass' => $newPassword,
                ]);
            } catch (Throwable $e) {
                error_log('admin ejabberd password sync failed: ' . $e->getMessage());
            }
            flow_admin_audit($adminEmpId, $action, 'xmpp_users', (string)$id, ['password_updated' => true]);
            return ['status' => true, 'message' => 'User password updated.'];

        case 'update_user_storage_limit':
            if ($id <= 0) return ['status' => false, 'error' => 'Valid employee id is required.'];
            return admin_update_user_storage_limit($pdo, $adminEmpId, $id, $_POST['storage_limit_mb'] ?? '');
        case 'update_employee_type':
            if ($id <= 0) return ['status' => false, 'error' => 'Valid employee id is required.'];
            return admin_update_employee_type($pdo, $adminEmpId, $id, (string)($_POST['employee_type'] ?? ''));

        case 'save_ai_provider':
            return admin_save_ai_provider($pdo, $adminEmpId);

        case 'save_ai_type_rule':
            return admin_save_ai_type_rule($pdo, $adminEmpId);

        case 'save_ai_user_access':
            return admin_save_ai_user_access($pdo, $adminEmpId);

        case 'add_member':
            return admin_add_group_member($pdo, $adminEmpId);

        case 'add_external_member':
            return admin_add_external_member($pdo, $adminEmpId);

        case 'remove_external_member':
            return admin_remove_external_member($pdo, $adminEmpId);

        case 'approve_external_request':
            return admin_approve_external_request($pdo, $adminEmpId);

        case 'reject_external_request':
            return admin_reject_external_request($pdo, $adminEmpId);

        case 'delete_group_channel':
            return admin_delete_group_channel($pdo, $adminEmpId, $id);

        case 'update_group':
            $roomName = trim((string)($_POST['room_name'] ?? ''));
            $channelKind = trim((string)($_POST['channel_kind'] ?? ''));
            $wakeupEnabled = (int)($_POST['wakeup_enabled'] ?? 0) === 1 ? 1 : 0;
            $wakeupInterval = max(60, (int)($_POST['wakeup_interval_minutes'] ?? 1440));
            $allowedWakeupIntervals = array_map(static fn($row) => (int)$row['minutes'], admin_wakeup_interval_options());
            if (!in_array($wakeupInterval, $allowedWakeupIntervals, true)) $wakeupInterval = 1440;
            $isArchived = (int)($_POST['is_archived'] ?? 0) === 1 ? 1 : 0;
            if ($roomName === '') return ['status' => false, 'error' => 'Group/channel name is required.'];
            $sets = ['room_name = :room_name'];
            $params = [':room_name' => $roomName, ':id' => $id];
            if (flow_admin_column_exists($pdo, 'xmpp_groups', 'channel_kind')) {
                $sets[] = 'channel_kind = :channel_kind';
                $params[':channel_kind'] = $channelKind;
            }
            if (flow_admin_column_exists($pdo, 'xmpp_groups', 'wakeup_enabled')) {
                $sets[] = 'wakeup_enabled = :wakeup_enabled';
                $params[':wakeup_enabled'] = $wakeupEnabled;
            }
            if (flow_admin_column_exists($pdo, 'xmpp_groups', 'wakeup_interval_minutes')) {
                $sets[] = 'wakeup_interval_minutes = :wakeup_interval_minutes';
                $params[':wakeup_interval_minutes'] = $wakeupInterval;
            }
            if (flow_admin_column_exists($pdo, 'xmpp_groups', 'wakeup_updated_by_emp_id')) {
                $sets[] = 'wakeup_updated_by_emp_id = :wakeup_updated_by_emp_id';
                $params[':wakeup_updated_by_emp_id'] = $adminEmpId;
            }
            if (flow_admin_column_exists($pdo, 'xmpp_groups', 'wakeup_updated_at')) {
                $sets[] = 'wakeup_updated_at = NOW()';
            }
            if (flow_admin_column_exists($pdo, 'xmpp_groups', 'is_archived')) {
                $sets[] = 'is_archived = :is_archived';
                $params[':is_archived'] = $isArchived;
            }
            $stmt = $pdo->prepare('UPDATE xmpp_groups SET ' . implode(', ', $sets) . ' WHERE id = :id');
            $stmt->execute($params);
            flow_admin_audit($adminEmpId, $action, 'xmpp_groups', (string)$id, [
                'room_name' => $roomName,
                'channel_kind' => $channelKind,
                'wakeup_enabled' => $wakeupEnabled,
                'wakeup_interval_minutes' => $wakeupInterval,
                'is_archived' => $isArchived,
            ]);
            return ['status' => true, 'message' => 'Group/channel updated.'];
        case 'set_user_status':
            $status = (int)($_POST['status'] ?? 0) === 1 ? 1 : 0;
            $stmt = $pdo->prepare('UPDATE xmpp_users SET status = :status WHERE emp_id = :id');
            $stmt->execute([':status' => $status, ':id' => $id]);
            flow_admin_audit($adminEmpId, $action, 'xmpp_users', (string)$id, ['status' => $status]);
            return ['status' => true, 'message' => $status ? 'User enabled.' : 'User disabled.'];

        case 'set_member_role':
            $groupId = (int)($_POST['group_id'] ?? 0);
            $empId = (int)($_POST['emp_id'] ?? 0);
            $role = strtolower(trim((string)($_POST['role'] ?? 'member')));
            if ($groupId <= 0 || $empId <= 0 || !in_array($role, ['owner', 'admin', 'member'], true)) {
                return ['status' => false, 'error' => 'Group, employee and role are required.'];
            }
            $stmt = $pdo->prepare('UPDATE xmpp_group_members SET role = :role WHERE group_id = :group_id AND emp_id = :emp_id');
            $stmt->execute([':role' => $role, ':group_id' => $groupId, ':emp_id' => $empId]);
            flow_admin_audit($adminEmpId, $action, 'xmpp_group_members', $groupId . ':' . $empId, ['role' => $role]);
            return ['status' => true, 'message' => 'Member role updated.'];

        case 'remove_member':
            $groupId = (int)($_POST['group_id'] ?? 0);
            $empId = (int)($_POST['emp_id'] ?? 0);
            if ($groupId <= 0 || $empId <= 0) return ['status' => false, 'error' => 'Group and employee are required.'];
            $stmt = $pdo->prepare('DELETE FROM xmpp_group_members WHERE group_id = :group_id AND emp_id = :emp_id');
            $stmt->execute([':group_id' => $groupId, ':emp_id' => $empId]);
            flow_admin_audit($adminEmpId, $action, 'xmpp_group_members', $groupId . ':' . $empId, []);
            return ['status' => true, 'message' => 'Member removed.'];
    }

    return ['status' => false, 'error' => 'Unknown admin action.'];
}

try {
    if ($method === 'POST') {
        $payload = admin_post_action($pdo, $adminEmpId, $action);
        flow_admin_json($payload, ($payload['status'] ?? false) ? 200 : 422);
    }

    $payload = match ($action) {
        'overview' => admin_overview($pdo),
        'users' => admin_users($pdo, $search),
        'user_detail' => admin_user_detail($pdo),
        'groups' => admin_groups_or_channels($pdo, $search, 'group'),
        'group_detail' => admin_group_detail($pdo),
        'employee_picker' => admin_employee_picker($pdo, $search),
        'channels' => admin_groups_or_channels($pdo, $search, 'channel'),
        'external_requests' => admin_external_requests($pdo, $search),
        'messages' => admin_messages($pdo, $search),
        'attachments' => admin_attachments($pdo, $search),
        'location' => admin_location($pdo),
        'ai_access' => admin_ai_access($pdo, $search),
        'notifications' => admin_notifications($pdo, $search),
        'releases' => admin_releases($pdo),
        'diagnostics' => admin_simple($pdo, 'xmpp_diagnostics', 'created_at DESC'),
        'audit' => admin_simple($pdo, 'flow_admin_audit_log', 'created_at DESC'),
        'tasks' => admin_tasks($search),
        default => ['status' => false, 'error' => 'Unknown admin action.'],
    };
    $payload['admin'] = $admin;
    flow_admin_json($payload, ($payload['status'] ?? false) ? 200 : 404);
} catch (Throwable $e) {
    error_log('flow admin API failed: ' . $e->getMessage());
    flow_admin_audit($adminEmpId, 'api_error', 'admin_api', $action, ['error' => $e->getMessage()], 'failed');
    flow_admin_json(['status' => false, 'error' => $e->getMessage()], 500);
}

