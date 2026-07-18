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
            ]) . " FROM `{$table}` LIMIT 2000");
            foreach ($profileRows as $profile) {
                $profiles[(int)($profile['emp_id'] ?? 0)] = $profile;
            }
        }
    } catch (Throwable $e) {
        error_log('admin user profile join failed: ' . $e->getMessage());
    }

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
    $messageWhere = '(from_jid = :jid OR to_jid = :jid OR from_jid LIKE :emp_like OR to_jid LIKE :emp_like)';
    $messageParams = [':jid' => $jid, ':emp_like' => (string)$empId . '@%'];
    $messages = [
        'total' => flow_admin_count($pdo, 'xmpp_messages', $messageWhere . ' AND deleted_at IS NULL', $messageParams),
        'sent' => flow_admin_count($pdo, 'xmpp_messages', '(from_jid = :jid OR from_jid LIKE :emp_like) AND deleted_at IS NULL', $messageParams),
        'received' => flow_admin_count($pdo, 'xmpp_messages', '(to_jid = :jid OR to_jid LIKE :emp_like) AND deleted_at IS NULL', $messageParams),
    ];

    $files = [
        'count' => flow_admin_count($pdo, 'xmpp_messages', $messageWhere . " AND file_url IS NOT NULL AND file_url <> '' AND deleted_at IS NULL", $messageParams),
        'storage_bytes' => 0,
        'storage_label' => '0 B',
    ];
    try {
        if (flow_admin_table_exists($pdo, 'xmpp_messages') && flow_admin_column_exists($pdo, 'xmpp_messages', 'file_size')) {
            $stmt = $pdo->prepare("SELECT COALESCE(SUM(CAST(file_size AS UNSIGNED)), 0) FROM xmpp_messages WHERE {$messageWhere} AND file_url IS NOT NULL AND file_url <> '' AND deleted_at IS NULL");
            $stmt->execute($messageParams);
            $files['storage_bytes'] = (int)$stmt->fetchColumn();
            $files['storage_label'] = admin_format_bytes($files['storage_bytes']);
        }
    } catch (Throwable $e) {
        error_log('admin user detail storage failed: ' . $e->getMessage());
    }

    $presence = flow_admin_rows($pdo, 'SELECT * FROM xmpp_user_presence WHERE emp_id = :emp_id LIMIT 1', [':emp_id' => $empId])[0] ?? [];
    $memberships = admin_user_group_memberships($pdo, $empId);

    return [
        'status' => true,
        'user' => $user,
        'profile' => $profile,
        'messages' => $messages,
        'files' => $files,
        'presence' => $presence,
        'location' => admin_user_last_location($pdo, $empId),
        'systems' => admin_user_active_systems($pdo, $empId),
        'memberships' => $memberships,
    ];
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

function admin_user_last_location(PDO $pdo, int $empId): array
{
    foreach (['xmpp_user_locations', 'xmpp_location_history', 'user_locations', 'employee_locations', 'location_history'] as $table) {
        if (!flow_admin_table_exists($pdo, $table)) continue;
        $id = admin_first_existing_column($pdo, $table, ['emp_id', 'employee_id', 'user_id']);
        $lat = admin_first_existing_column($pdo, $table, ['latitude', 'lat']);
        $lng = admin_first_existing_column($pdo, $table, ['longitude', 'lng', 'lon']);
        if ($id === '' || $lat === '' || $lng === '') continue;
        $address = admin_first_existing_column($pdo, $table, ['address', 'formatted_address', 'location_address', 'place_name']);
        $updated = admin_first_existing_column($pdo, $table, ['updated_at', 'created_at', 'captured_at', 'last_seen_at']);
        $order = $updated !== '' ? "`{$updated}` DESC" : "`{$id}` DESC";
        $rows = flow_admin_rows($pdo, 'SELECT ' . implode(', ', [admin_sql_expr($lat, 'lat'), admin_sql_expr($lng, 'lng'), admin_sql_expr($address, 'address'), admin_sql_expr($updated, 'updated_at')]) . " FROM `{$table}` WHERE `{$id}` = :emp_id ORDER BY {$order} LIMIT 1", [':emp_id' => $empId]);
        if ($rows) return $rows[0] + ['source' => $table];
    }
    return [];
}

function admin_user_active_systems(PDO $pdo, int $empId): array
{
    foreach (['xmpp_user_devices', 'xmpp_devices', 'user_devices', 'device_sessions', 'xmpp_sessions'] as $table) {
        if (!flow_admin_table_exists($pdo, $table)) continue;
        $id = admin_first_existing_column($pdo, $table, ['emp_id', 'employee_id', 'user_id']);
        if ($id === '') continue;
        $device = admin_first_existing_column($pdo, $table, ['device_name', 'device', 'platform', 'system_name', 'os']);
        $app = admin_first_existing_column($pdo, $table, ['app_version', 'version', 'build_number']);
        $ip = admin_first_existing_column($pdo, $table, ['ip_address', 'ip', 'last_ip']);
        $updated = admin_first_existing_column($pdo, $table, ['last_seen_at', 'updated_at', 'created_at']);
        $active = admin_first_existing_column($pdo, $table, ['is_active', 'active', 'online']);
        $where = "`{$id}` = :emp_id";
        if ($active !== '') $where .= " AND COALESCE(`{$active}`, 0) IN (1, '1', 'true', 'online')";
        $order = $updated !== '' ? "`{$updated}` DESC" : "`{$id}` DESC";
        return flow_admin_rows($pdo, 'SELECT ' . implode(', ', [admin_sql_expr($device, 'device'), admin_sql_expr($app, 'app_version'), admin_sql_expr($ip, 'ip_address'), admin_sql_expr($updated, 'last_seen_at')]) . " FROM `{$table}` WHERE {$where} ORDER BY {$order} LIMIT 10", [':emp_id' => $empId]);
    }
    return [];
}
function admin_groups_or_channels(PDO $pdo, string $search, string $kind): array
{
    $where = admin_group_type_condition($kind);
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
    ];
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

function admin_post_action(PDO $pdo, int $adminEmpId, string $action): array
{
    flow_admin_require_csrf();
    $id = (int)($_POST['id'] ?? 0);
    if ($id <= 0 && !in_array($action, ['set_member_role', 'remove_member'], true)) {
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

        case 'update_group':
            $roomName = trim((string)($_POST['room_name'] ?? ''));
            $channelKind = trim((string)($_POST['channel_kind'] ?? ''));
            $wakeupEnabled = (int)($_POST['wakeup_enabled'] ?? 0) === 1 ? 1 : 0;
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
        'channels' => admin_groups_or_channels($pdo, $search, 'channel'),
        'messages' => admin_messages($pdo, $search),
        'attachments' => admin_attachments($pdo, $search),
        'location' => admin_location($pdo),
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
