<?php

declare(strict_types=1);

require_once __DIR__ . '/bootstrap.php';
require_once __DIR__ . '/SystemNotification.php';

$session = chat_require_user();
$empId = (int)$session['emp_id'];
$pdo = chat_db();
chat_ensure_schema($pdo);

function myhub_task_db(): PDO
{
    if (function_exists('getTaskDB')) {
        try {
            return getTaskDB();
        } catch (Throwable $e) {
            error_log('MyHub task DB fallback: ' . $e->getMessage());
        }
    }
    return chat_db();
}

function myhub_employee_db(): PDO
{
    if (function_exists('getEmployeeDB')) {
        try {
            return getEmployeeDB();
        } catch (Throwable $e) {
            error_log('MyHub employee DB fallback: ' . $e->getMessage());
        }
    }
    return chat_db();
}

function myhub_leave_db(): PDO
{
    static $leavePdo = null;
    if ($leavePdo instanceof PDO) {
        return $leavePdo;
    }
    foreach ([myhub_employee_db(), myhub_task_db(), chat_db()] as $candidate) {
        try {
            if (myhub_first_table($candidate, ['track_leave_request']) !== '') {
                $leavePdo = $candidate;
                return $leavePdo;
            }
        } catch (Throwable $e) {
            error_log('MyHub leave DB probe failed: ' . $e->getMessage());
        }
    }
    $leavePdo = myhub_employee_db();
    return $leavePdo;
}

function myhub_first_column(array $columns, array $candidates): string
{
    foreach ($candidates as $candidate) {
        if (isset($columns[$candidate])) return $candidate;
    }
    return '';
}

function myhub_first_table(PDO $pdo, array $tables): string
{
    $stmt = $pdo->prepare(
        'SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = :table_name LIMIT 1'
    );
    foreach ($tables as $table) {
        $stmt->execute([':table_name' => $table]);
        if ($stmt->fetchColumn()) return $table;
    }
    return '';
}

function myhub_columns(PDO $pdo, string $table, ?string $schema = null): array
{
    $stmt = $pdo->prepare(
        'SELECT COLUMN_NAME
         FROM INFORMATION_SCHEMA.COLUMNS
         WHERE TABLE_SCHEMA = COALESCE(:schema_name, DATABASE())
           AND TABLE_NAME = :table_name'
    );
    $stmt->execute([':schema_name' => $schema, ':table_name' => $table]);
    return array_fill_keys(array_map('strtolower', $stmt->fetchAll(PDO::FETCH_COLUMN) ?: []), true);
}

function myhub_phone_column(array $columns): string
{
    return myhub_first_column($columns, ['mobile', 'mobile_no', 'contact_no', 'contact_number', 'phone', 'phone_number', 'official_mobile', 'personal_mobile']);
}

function myhub_people(PDO $employeePdo, array $empIds): array
{
    $empIds = array_values(array_unique(array_filter(array_map('intval', $empIds), static fn(int $id): bool => $id > 0)));
    if (!$empIds) return [];
    $table = myhub_first_table($employeePdo, ['employee', 'employees', 'users', 'tbl_employee']);
    if ($table === '') {
        return array_map(static fn(int $id): array => ['emp_id' => $id, 'name' => (string)$id, 'designation' => ''], $empIds);
    }
    $columns = myhub_columns($employeePdo, $table);
    $idCol = myhub_first_column($columns, ['emp_id', 'employee_id', 'user_id', 'id']);
    $nameCol = myhub_first_column($columns, ['name', 'employee_name', 'emp_name', 'full_name', 'username']);
    $designationCol = myhub_first_column($columns, ['designation', 'role', 'position', 'department', 'emp_type']);
    if ($idCol === '' || $nameCol === '') {
        return array_map(static fn(int $id): array => ['emp_id' => $id, 'name' => (string)$id, 'designation' => ''], $empIds);
    }
    $designationSql = $designationCol !== '' ? "COALESCE(NULLIF(`{$designationCol}`, ''), '')" : "''";
    $placeholders = implode(', ', array_fill(0, count($empIds), '?'));
    $stmt = $employeePdo->prepare(
        "SELECT `{$idCol}` AS emp_id, `{$nameCol}` AS name, {$designationSql} AS designation
         FROM `{$table}`
         WHERE `{$idCol}` IN ({$placeholders})"
    );
    $stmt->execute($empIds);
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC) ?: [];
    $mapped = [];
    foreach ($rows as $row) {
        $mapped[(int)$row['emp_id']] = [
            'emp_id' => (int)$row['emp_id'],
            'name' => (string)($row['name'] ?? $row['emp_id']),
            'designation' => (string)($row['designation'] ?? ''),
        ];
    }
    $result = [];
    foreach ($empIds as $id) {
        $result[] = $mapped[$id] ?? ['emp_id' => $id, 'name' => (string)$id, 'designation' => ''];
    }
    return $result;
}

function myhub_parse_emp_ids(string $value): array
{
    $parts = preg_split('/\s*,\s*/', trim($value)) ?: [];
    return array_values(array_unique(array_filter(array_map('intval', $parts), static fn(int $id): bool => $id > 0)));
}
function myhub_people_label(array $people): string
{
    if (!$people) return 'None';
    $labels = [];
    foreach ($people as $person) {
        $name = trim((string)($person['name'] ?? ''));
        $id = (int)($person['emp_id'] ?? 0);
        $labels[] = $name !== '' && $id > 0 ? "{$name} ({$id})" : ($name !== '' ? $name : (string)$id);
    }
    return implode(', ', array_values(array_filter($labels)));
}

function myhub_task_notification_body(
    string $heading,
    int $taskId,
    string $title,
    string $description,
    array $creator,
    array $assignees,
    array $followers,
    string $priority,
    string $vertical,
    string $updateText = '',
    array $updatedBy = []
): string {
    $lines = [
        $heading,
        'Task ID: ' . $taskId,
        'Title: ' . $title,
        'Description: ' . ($description !== '' ? $description : '-'),
        'Created by: ' . myhub_people_label($creator ? [$creator] : []),
        'Assignees: ' . myhub_people_label($assignees),
        'Followers: ' . myhub_people_label($followers),
        'Vertical: ' . ($vertical !== '' ? $vertical : '-'),
        'Priority: ' . ($priority !== '' ? ucfirst($priority) : '-'),
    ];
    if ($updatedBy) $lines[] = 'Updated by: ' . myhub_people_label([$updatedBy]);
    if ($updateText !== '') $lines[] = 'Update: ' . $updateText;
    return mb_substr(implode("\n", $lines), 0, 3900);
}

function myhub_notify_task_participants(
    int $taskId,
    string $eventType,
    string $body,
    int $creatorId,
    array $assigneeIds,
    array $followerIds,
    string $referenceSuffix
): void {
    $recipients = array_values(array_unique(array_filter(array_merge([$creatorId], $assigneeIds, $followerIds), static fn(int $id): bool => $id > 0)));
    foreach ($recipients as $recipientId) {
        try {
            chat_send_system_notification(
                $recipientId,
                $body,
                $eventType,
                $eventType . '-' . $taskId . '-' . $recipientId . '-' . $referenceSuffix
            );
        } catch (Throwable $e) {
            error_log('Task system notification skipped: ' . $e->getMessage());
        }
    }
}


function myhub_activity_username(int $empId): string
{
    return 'Sky-' . $empId;
}

function myhub_ensure_activity_table(PDO $pdo): void
{
    $pdo->exec("CREATE TABLE IF NOT EXISTS activity_log (
        id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
        username VARCHAR(128) NOT NULL,
        activity_date DATE NOT NULL,
        activity_desc TEXT NOT NULL,
        start_time TIME NOT NULL,
        end_time TIME NOT NULL,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        ip_address VARCHAR(45) NULL,
        file_path VARCHAR(200) NULL,
        activity_log_type VARCHAR(200) NULL,
        INDEX idx_activity_user_date (username, activity_date),
        INDEX idx_activity_created (created_at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
}

function myhub_activity_upload_files(int $empId): string
{
    if (empty($_FILES)) return '';
    $files = [];
    foreach ($_FILES as $input) {
        if (!is_array($input)) continue;
        if (is_array($input['name'] ?? null)) {
            $count = count($input['name']);
            for ($i = 0; $i < $count; $i++) {
                $files[] = [
                    'name' => $input['name'][$i] ?? '',
                    'tmp_name' => $input['tmp_name'][$i] ?? '',
                    'error' => $input['error'][$i] ?? UPLOAD_ERR_NO_FILE,
                    'size' => $input['size'][$i] ?? 0,
                ];
            }
        } else {
            $files[] = $input;
        }
    }
    $stored = [];
    $root = dirname(__DIR__);
    $relativeDir = 'uploads/a';
    $targetDir = $root . DIRECTORY_SEPARATOR . str_replace('/', DIRECTORY_SEPARATOR, $relativeDir);
    if (!is_dir($targetDir) && !mkdir($targetDir, 0775, true) && !is_dir($targetDir)) {
        chat_json(['status' => false, 'error' => 'Activity upload directory is unavailable.'], 500);
    }
    foreach ($files as $file) {
        $error = (int)($file['error'] ?? UPLOAD_ERR_NO_FILE);
        if ($error === UPLOAD_ERR_NO_FILE) continue;
        if ($error !== UPLOAD_ERR_OK) {
            chat_json(['status' => false, 'error' => 'Activity file upload failed with code ' . $error], 422);
        }
        $size = (int)($file['size'] ?? 0);
        if ($size <= 0) continue;
        $original = trim((string)($file['name'] ?? 'file'));
        $safeName = preg_replace('/[^A-Za-z0-9._-]+/', '_', basename($original)) ?: 'file';
        $ext = strtolower(pathinfo($safeName, PATHINFO_EXTENSION));
        $storedName = date('Ymd_His') . '_' . bin2hex(random_bytes(5)) . ($ext !== '' ? '.' . $ext : '');
        $target = $targetDir . DIRECTORY_SEPARATOR . $storedName;
        if (!move_uploaded_file((string)($file['tmp_name'] ?? ''), $target)) {
            chat_json(['status' => false, 'error' => 'Unable to save activity file.'], 500);
        }
        $stored[] = $relativeDir . '/' . $storedName;
    }
    return mb_substr(implode(',', $stored), 0, 200);
}

function myhub_activity_logs(int $empId): never
{
    $chatPdo = chat_db();
    myhub_ensure_activity_table($chatPdo);
    $username = myhub_activity_username($empId);
    $stmt = $chatPdo->prepare(
        "SELECT id, username, activity_date, activity_desc, start_time, end_time, created_at, updated_at, ip_address, file_path, activity_log_type
         FROM activity_log
         WHERE LOWER(username) = LOWER(:username)
           AND activity_date >= DATE_FORMAT(CURDATE(), '%Y-%m-01')
           AND activity_date < DATE_ADD(DATE_FORMAT(CURDATE(), '%Y-%m-01'), INTERVAL 1 MONTH)
         ORDER BY activity_date DESC, start_time DESC, id DESC
         LIMIT 200"
    );
    $stmt->execute([':username' => $username]);
    chat_json([
        'status' => true,
        'username' => $username,
        'logs' => $stmt->fetchAll(PDO::FETCH_ASSOC) ?: [],
    ]);
}

function myhub_create_activity(int $empId): never
{
    $type = trim((string)($_POST['activity_log_type'] ?? $_POST['log_type'] ?? 'Task Update'));
    $description = trim((string)($_POST['activity_desc'] ?? $_POST['description'] ?? ''));
    $start = trim((string)($_POST['start_time'] ?? $_POST['from'] ?? ''));
    $end = trim((string)($_POST['end_time'] ?? $_POST['to'] ?? ''));
    $date = trim((string)($_POST['activity_date'] ?? date('Y-m-d')));
    if ($description === '') chat_json(['status' => false, 'error' => 'Activity description is required.'], 422);
    if (!preg_match('/^\d{2}:\d{2}(:\d{2})?$/', $start) || !preg_match('/^\d{2}:\d{2}(:\d{2})?$/', $end)) {
        chat_json(['status' => false, 'error' => 'From and To time are required.'], 422);
    }
    if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $date)) $date = date('Y-m-d');
    if (strlen($start) === 5) $start .= ':00';
    if (strlen($end) === 5) $end .= ':00';
    $filePath = myhub_activity_upload_files($empId);
    $chatPdo = chat_db();
    myhub_ensure_activity_table($chatPdo);
    $stmt = $chatPdo->prepare(
        'INSERT INTO activity_log (username, activity_date, activity_desc, start_time, end_time, ip_address, file_path, activity_log_type)
         VALUES (:username, :activity_date, :activity_desc, :start_time, :end_time, :ip_address, :file_path, :activity_log_type)'
    );
    $stmt->execute([
        ':username' => myhub_activity_username($empId),
        ':activity_date' => $date,
        ':activity_desc' => $description,
        ':start_time' => $start,
        ':end_time' => $end,
        ':ip_address' => mb_substr((string)($_SERVER['REMOTE_ADDR'] ?? ''), 0, 45),
        ':file_path' => $filePath !== '' ? $filePath : null,
        ':activity_log_type' => mb_substr($type !== '' ? $type : 'Task Update', 0, 200),
    ]);
    chat_json([
        'status' => true,
        'message' => 'Activity saved.',
        'activity_id' => (int)$chatPdo->lastInsertId(),
    ]);
}
function myhub_directory(PDO $pdo): never
{
    $query = trim((string)($_GET['q'] ?? ''));
    $table = myhub_first_table($pdo, ['employee', 'employees', 'users', 'tbl_employee']);
    if ($table === '') {
        chat_json(['status' => true, 'employees' => [], 'warning' => 'Employee table is unavailable.']);
    }
    $columns = myhub_columns($pdo, $table);
    $idCol = myhub_first_column($columns, ['emp_id', 'employee_id', 'user_id', 'id']);
    $nameCol = myhub_first_column($columns, ['name', 'employee_name', 'emp_name', 'full_name', 'username']);
    if ($idCol === '' || $nameCol === '') {
        chat_json(['status' => true, 'employees' => [], 'warning' => 'Employee columns are unavailable.']);
    }
    $designationCol = myhub_first_column($columns, ['designation', 'role', 'position', 'department', 'emp_type']);
    $phoneCol = myhub_phone_column($columns);
    $designationSql = $designationCol !== '' ? "COALESCE(NULLIF(`{$designationCol}`, ''), '')" : "''";
    $phoneSql = $phoneCol !== '' ? "COALESCE(NULLIF(`{$phoneCol}`, ''), '')" : "''";
    $whereParts = [];
    $params = [];
    if (isset($columns['status'])) {
        $whereParts[] = "(`status` = 1 OR `status` = '1' OR LOWER(CAST(`status` AS CHAR)) IN ('active','working'))";
    }
    if ($query !== '') {
        $searchParts = ["CAST(`{$idCol}` AS CHAR) LIKE :q", "`{$nameCol}` LIKE :q"];
        if ($designationCol !== '') $searchParts[] = "`{$designationCol}` LIKE :q";
        if ($phoneCol !== '') $searchParts[] = "`{$phoneCol}` LIKE :q";
        $whereParts[] = '(' . implode(' OR ', $searchParts) . ')';
        $params[':q'] = '%' . $query . '%';
    }
    $where = $whereParts ? ('WHERE ' . implode(' AND ', $whereParts)) : '';
    $stmt = $pdo->prepare(
        "SELECT `{$idCol}` AS emp_id, `{$nameCol}` AS name, {$designationSql} AS designation, {$phoneSql} AS contact_number
         FROM `{$table}`
         {$where}
         ORDER BY `{$nameCol}` ASC
         LIMIT 500"
    );
    $stmt->execute($params);
    chat_json(['status' => true, 'employees' => $stmt->fetchAll(PDO::FETCH_ASSOC) ?: []]);
}
function myhub_horizon_allowed(int $empId): bool
{
    return $empId > 0;
}
function myhub_horizon_super_admin(int $empId): bool
{
    return in_array($empId, [116, 232, 302, 428, 553], true);
}

function myhub_horizon_visible_emp_ids(PDO $employeePdo, int $viewerEmpId): array
{
    if (myhub_horizon_super_admin($viewerEmpId)) return [];
    $visible = [$viewerEmpId];
    try {
        $table = myhub_first_table($employeePdo, ['employee', 'employees', 'users', 'tbl_employee']);
        if ($table === '') return $visible;
        $columns = myhub_columns($employeePdo, $table);
        $idCol = myhub_first_column($columns, ['emp_id', 'employee_id', 'user_id', 'id']);
        $reportingCol = myhub_first_column($columns, ['reporting_to', 'reporting_emp_id', 'manager_emp_id', 'manager_id', 'reports_to']);
        if ($idCol === '' || $reportingCol === '') return $visible;
        $stmt = $employeePdo->prepare("SELECT `{$idCol}` AS emp_id FROM `{$table}` WHERE CAST(`{$reportingCol}` AS CHAR) = :viewer_emp_id");
        $stmt->execute([':viewer_emp_id' => (string)$viewerEmpId]);
        foreach (($stmt->fetchAll(PDO::FETCH_COLUMN) ?: []) as $empId) {
            $id = (int)$empId;
            if ($id > 0) $visible[] = $id;
        }
    } catch (Throwable $e) {
        error_log('MyHub Horizon reporting scope failed: ' . $e->getMessage());
    }
    return array_values(array_unique($visible));
}

function myhub_horizon_can_view_emp(PDO $employeePdo, int $viewerEmpId, int $targetEmpId): bool
{
    if (myhub_horizon_super_admin($viewerEmpId)) return true;
    return in_array($targetEmpId, myhub_horizon_visible_emp_ids($employeePdo, $viewerEmpId), true);
}

function myhub_horizon_duration(int $seconds): string
{
    if ($seconds <= 0) return '00h 00m';
    return sprintf('%02dh %02dm', intdiv($seconds, 3600), intdiv($seconds % 3600, 60));
}

function myhub_horizon_ts(array $row, string $epochCol, string $dateCol): int
{
    $epoch = (int)($row[$epochCol] ?? 0);
    if ($epoch > 1) return $epoch;
    $raw = trim((string)($row[$dateCol] ?? ''));
    return $raw !== '' ? (strtotime($raw) ?: 0) : 0;
}

function myhub_horizon_today_punch_rows(PDO $pdo): array
{
    $sources = [$pdo];
    try {
        $taskPdo = myhub_task_db();
        if ($taskPdo !== $pdo) $sources[] = $taskPdo;
    } catch (Throwable $ignored) {
    }
    foreach ($sources as $sourcePdo) {
        try {
            $table = myhub_first_table($sourcePdo, ['punch', 'attendance', 'employee_punch', 'tbl_punch']);
            if ($table === '') continue;
            $columns = myhub_columns($sourcePdo, $table);
            $empCol = myhub_first_column($columns, ['emp_id', 'employee_id', 'user_id']);
            $shiftCol = myhub_first_column($columns, ['shift_id', 'shift', 'id']);
            $inEpochCol = myhub_first_column($columns, ['punch_in', 'in_time_epoch']);
            $outEpochCol = myhub_first_column($columns, ['punch_out', 'out_time_epoch']);
            $inDateCol = myhub_first_column($columns, ['date_created', 'punch_in_time', 'in_time', 'created_at']);
            $outDateCol = myhub_first_column($columns, ['out_time', 'punch_out_time', 'updated_at']);
            $idCol = myhub_first_column($columns, ['id', 'punch_id']);
            if ($empCol === '' || ($inEpochCol === '' && $inDateCol === '')) continue;
            $select = [
                ($idCol !== '' ? "`{$idCol}`" : '0') . ' AS id',
                "`{$empCol}` AS emp_id",
                ($shiftCol !== '' ? "`{$shiftCol}`" : "''") . ' AS shift_id',
                ($inEpochCol !== '' ? "`{$inEpochCol}`" : '0') . ' AS punch_in',
                ($outEpochCol !== '' ? "`{$outEpochCol}`" : '0') . ' AS punch_out',
                ($inDateCol !== '' ? "`{$inDateCol}`" : "''") . ' AS date_created',
                ($outDateCol !== '' ? "`{$outDateCol}`" : "''") . ' AS out_time',
            ];
            $dateExpr = $inDateCol !== '' ? "DATE(`{$inDateCol}`) = CURDATE()" : "FROM_UNIXTIME(`{$inEpochCol}`, '%Y-%m-%d') = CURDATE()";
            $orderExpr = $idCol !== '' ? "`{$idCol}` DESC" : ($inDateCol !== '' ? "`{$inDateCol}` DESC" : "`{$inEpochCol}` DESC");
            $stmt = $sourcePdo->prepare(
                'SELECT ' . implode(', ', $select) . " FROM `{$table}` WHERE {$dateExpr} ORDER BY `{$empCol}` ASC, {$orderExpr}"
            );
            $stmt->execute();
            $rows = [];
            foreach (($stmt->fetchAll(PDO::FETCH_ASSOC) ?: []) as $row) {
                $empId = (int)($row['emp_id'] ?? 0);
                if ($empId <= 0 || isset($rows[$empId])) continue;
                $rows[$empId] = $row;
            }
            return $rows;
        } catch (Throwable $e) {
            error_log('MyHub Horizon punch source failed: ' . $e->getMessage());
        }
    }
    return [];
}
function myhub_horizon_chat_id(PDO $taskPdo, int $empId): string
{
    try {
        if (myhub_first_table($taskPdo, ['tbl_location_track_inch']) === '') return (string)$empId;
        $stmt = $taskPdo->prepare("SELECT chat_id FROM tbl_location_track_inch WHERE emp_id = :emp_id AND COALESCE(TRIM(chat_id), '') <> '' ORDER BY id DESC LIMIT 1");
        $stmt->execute([':emp_id' => $empId]);
        $chatId = trim((string)($stmt->fetchColumn() ?: ''));
        return $chatId !== '' ? $chatId : (string)$empId;
    } catch (Throwable $e) {
        error_log('MyHub Horizon chat id failed: ' . $e->getMessage());
        return (string)$empId;
    }
}

function myhub_horizon_employee_map(PDO $employeePdo, array $empIds): array
{
    if (!$empIds) return [];
    $people = [];
    foreach (myhub_people($employeePdo, $empIds) as $person) {
        $people[(int)$person['emp_id']] = $person;
    }
    return $people;
}

function myhub_horizon_latest_locations(PDO $taskPdo, array $rows): array
{
    if (!$rows) return [];
    if (myhub_first_table($taskPdo, ['locations_test']) === '') return [];
    $locationColumns = myhub_columns($taskPdo, 'locations_test');
    $addressCol = myhub_first_column($locationColumns, ['address', 'location_address', 'place_address', 'formatted_address']);
    $addressSql = $addressCol !== '' ? ", `{$addressCol}` AS address" : ", '' AS address";

    $userMeta = [];
    $params = [];
    $placeholders = [];
    $minTs = 0;
    $maxTs = 0;
    $i = 0;
    foreach ($rows as $empId => $row) {
        $inTs = myhub_horizon_ts($row, 'punch_in', 'date_created');
        if ($inTs <= 0) continue;
        $outTs = myhub_horizon_ts($row, 'punch_out', 'out_time');
        $endTs = $outTs > $inTs ? $outTs : time();
        $chatId = trim(myhub_horizon_chat_id($taskPdo, (int)$empId));
        if ($chatId === '') continue;
        $userMeta[$chatId] = [
            'emp_id' => (int)$empId,
            'from_ts' => $inTs,
            'to_ts' => $endTs,
        ];
        $key = ':user_' . $i++;
        $placeholders[] = $key;
        $params[$key] = $chatId;
        $minTs = $minTs === 0 ? $inTs : min($minTs, $inTs);
        $maxTs = max($maxTs, $endTs);
    }
    if (!$userMeta || !$placeholders || $minTs <= 0 || $maxTs <= 0) return [];

    $params[':from_dt'] = date('Y-m-d H:i:s', $minTs);
    $params[':to_dt'] = date('Y-m-d H:i:s', $maxTs);
    $params[':from_ts'] = (string)$minTs;
    $params[':to_ts'] = (string)$maxTs;
    $stmt = $taskPdo->prepare(
        'SELECT user_id, latitude, longitude, timestamp, date_created, username, ip_address' . $addressSql . '
         FROM locations_test
         WHERE user_id IN (' . implode(', ', $placeholders) . ')
           AND COALESCE(latitude, "") <> ""
           AND COALESCE(longitude, "") <> ""
           AND ((date_created BETWEEN :from_dt AND :to_dt) OR (timestamp BETWEEN :from_ts AND :to_ts))
         ORDER BY date_created DESC, id DESC'
    );
    $stmt->execute($params);

    $locations = [];
    foreach (($stmt->fetchAll(PDO::FETCH_ASSOC) ?: []) as $point) {
        $chatId = trim((string)($point['user_id'] ?? ''));
        $meta = $userMeta[$chatId] ?? null;
        if (!$meta) continue;
        $empId = (int)($meta['emp_id'] ?? 0);
        if ($empId <= 0 || isset($locations[$empId])) continue;
        $lat = (float)($point['latitude'] ?? 0);
        $lng = (float)($point['longitude'] ?? 0);
        if ($lat < -90 || $lat > 90 || $lng < -180 || $lng > 180 || ($lat == 0.0 && $lng == 0.0)) continue;
        $capturedTs = (int)($point['timestamp'] ?? 0);
        if ($capturedTs <= 1) $capturedTs = strtotime((string)($point['date_created'] ?? '')) ?: 0;
        if ($capturedTs > 0 && ($capturedTs < (int)$meta['from_ts'] || $capturedTs > (int)$meta['to_ts'])) {
            continue;
        }
        $locations[$empId] = [
            'latitude' => $lat,
            'longitude' => $lng,
            'location_address' => trim((string)($point['address'] ?? '')),
            'location_updated_at' => $capturedTs > 0 ? date('Y-m-d H:i:s', $capturedTs) : (string)($point['date_created'] ?? ''),
        ];
    }
    return $locations;
}

function myhub_horizon(PDO $employeePdo, int $viewerEmpId): never
{
    if (!myhub_horizon_allowed($viewerEmpId)) chat_json(['status' => false, 'error' => 'Horizon access is restricted.'], 403);
    $rows = myhub_horizon_today_punch_rows($employeePdo);
    $visibleEmpIds = myhub_horizon_visible_emp_ids($employeePdo, $viewerEmpId);
    if ($visibleEmpIds) {
        $rows = array_intersect_key($rows, array_fill_keys($visibleEmpIds, true));
    }
    $people = myhub_horizon_employee_map($employeePdo, array_keys($rows));
    $employees = [];
    $now = time();
    $latestLocations = [];
    try {
        $latestLocations = myhub_horizon_latest_locations(myhub_task_db(), $rows);
    } catch (Throwable $e) {
        error_log('MyHub Horizon latest locations failed: ' . $e->getMessage());
    }
    foreach ($rows as $empId => $row) {
        $inTs = myhub_horizon_ts($row, 'punch_in', 'date_created');
        $outTs = myhub_horizon_ts($row, 'punch_out', 'out_time');
        if ($inTs <= 0) continue;
        $seconds = max(0, ($outTs > $inTs ? $outTs : $now) - $inTs);
        $person = $people[$empId] ?? ['emp_id' => $empId, 'name' => 'Employee ' . $empId, 'designation' => ''];
        $location = $latestLocations[(int)$empId] ?? [];
        $employees[] = [
            'emp_id' => $empId,
            'name' => (string)($person['name'] ?? ('Employee ' . $empId)),
            'designation' => (string)($person['designation'] ?? ''),
            'punch_in' => date('Y-m-d H:i:s', $inTs),
            'punch_out' => $outTs > $inTs ? date('Y-m-d H:i:s', $outTs) : '',
            'working_seconds' => $seconds,
            'working_hours' => myhub_horizon_duration($seconds),
            'status' => $outTs > $inTs ? 'Punched out' : 'Running',
            'shift_id' => (string)($row['shift_id'] ?? ''),
            'latitude' => (float)($location['latitude'] ?? 0),
            'longitude' => (float)($location['longitude'] ?? 0),
            'location_address' => (string)($location['location_address'] ?? ''),
            'location_updated_at' => (string)($location['location_updated_at'] ?? ''),
        ];
    }
    usort($employees, fn(array $a, array $b): int => strcmp($a['name'], $b['name']));
    chat_json(['status' => true, 'date' => date('Y-m-d'), 'count' => count($employees), 'employees' => $employees]);
}

function myhub_horizon_timeline(PDO $employeePdo, int $viewerEmpId): never
{
    if (!myhub_horizon_allowed($viewerEmpId)) chat_json(['status' => false, 'error' => 'Horizon access is restricted.'], 403);
    $targetEmpId = (int)($_GET['emp_id'] ?? 0);
    if ($targetEmpId <= 0) chat_json(['status' => false, 'error' => 'emp_id is required.'], 422);
    if (!myhub_horizon_can_view_emp($employeePdo, $viewerEmpId, $targetEmpId)) chat_json(['status' => false, 'error' => 'You can only view your own Horizon data and employees reporting to you.'], 403);
    $rows = myhub_horizon_today_punch_rows($employeePdo);
    $row = $rows[$targetEmpId] ?? null;
    if (!$row) chat_json(['status' => false, 'error' => 'Employee has not punched in today.'], 404);
    $inTs = myhub_horizon_ts($row, 'punch_in', 'date_created');
    $outTs = myhub_horizon_ts($row, 'punch_out', 'out_time');
    $endTs = $outTs > $inTs ? $outTs : time();
    $points = [];
    try {
        $taskPdo = myhub_task_db();
        $chatId = myhub_horizon_chat_id($taskPdo, $targetEmpId);
        if (myhub_first_table($taskPdo, ['locations_test']) !== '') {
            $locationColumns = myhub_columns($taskPdo, 'locations_test');
            $addressCol = myhub_first_column($locationColumns, ['address', 'location_address', 'place_address', 'formatted_address']);
            $addressSql = $addressCol !== '' ? ", `{$addressCol}` AS address" : ", '' AS address";
            $stmt = $taskPdo->prepare(
                'SELECT latitude, longitude, timestamp, date_created, username, ip_address' . $addressSql . '
                 FROM locations_test
                 WHERE user_id = :user_id
                   AND COALESCE(latitude, "") <> ""
                   AND COALESCE(longitude, "") <> ""
                   AND ((date_created BETWEEN :from_dt AND :to_dt) OR (timestamp BETWEEN :from_ts AND :to_ts))
                 ORDER BY date_created ASC, id ASC
                 LIMIT 2000'
            );
            $stmt->execute([':user_id' => $chatId, ':from_dt' => date('Y-m-d H:i:s', $inTs), ':to_dt' => date('Y-m-d H:i:s', $endTs), ':from_ts' => (string)$inTs, ':to_ts' => (string)$endTs]);
            foreach (($stmt->fetchAll(PDO::FETCH_ASSOC) ?: []) as $point) {
                $lat = (float)($point['latitude'] ?? 0);
                $lng = (float)($point['longitude'] ?? 0);
                if ($lat < -90 || $lat > 90 || $lng < -180 || $lng > 180 || ($lat == 0.0 && $lng == 0.0)) continue;
                $capturedTs = (int)($point['timestamp'] ?? 0);
                if ($capturedTs <= 1) $capturedTs = strtotime((string)($point['date_created'] ?? '')) ?: 0;
                $points[] = ['latitude' => $lat, 'longitude' => $lng, 'captured_at' => $capturedTs > 0 ? date('Y-m-d H:i:s', $capturedTs) : (string)($point['date_created'] ?? ''), 'address' => trim((string)($point['address'] ?? '')), 'username' => (string)($point['username'] ?? ''), 'ip_address' => (string)($point['ip_address'] ?? '')];
            }
        }
    } catch (Throwable $e) {
        error_log('MyHub Horizon locations failed: ' . $e->getMessage());
    }
    $halfHour = [];
    $addressCache = [];
    $nextCheckpoint = $inTs;
    $reverseGeocodeBudget = 4;
    foreach ($points as $point) {
        $pointTs = strtotime((string)$point['captured_at']) ?: 0;
        if ($pointTs <= 0) continue;
        while ($pointTs >= $nextCheckpoint) {
            $copy = $point;
            $copy['checkpoint_at'] = date('Y-m-d H:i:s', $nextCheckpoint);
            if (trim((string)($copy['address'] ?? '')) === '' && $reverseGeocodeBudget > 0) {
                $key = number_format((float)$copy['latitude'], 5, '.', '') . ',' . number_format((float)$copy['longitude'], 5, '.', '');
                if (!isset($addressCache[$key])) {
                    $addressCache[$key] = chat_reverse_geocode_address((float)$copy['latitude'], (float)$copy['longitude']);
                    $reverseGeocodeBudget--;
                }
                $copy['address'] = $addressCache[$key];
            }
            $halfHour[] = $copy;
            $nextCheckpoint += 1800;
        }
    }
    $people = myhub_horizon_employee_map($employeePdo, [$targetEmpId]);
    $person = $people[$targetEmpId] ?? ['emp_id' => $targetEmpId, 'name' => 'Employee ' . $targetEmpId, 'designation' => ''];
    chat_json(['status' => true, 'employee' => $person, 'punch_in' => date('Y-m-d H:i:s', $inTs), 'punch_out' => $outTs > $inTs ? date('Y-m-d H:i:s', $outTs) : '', 'working_seconds' => max(0, $endTs - $inTs), 'working_hours' => myhub_horizon_duration(max(0, $endTs - $inTs)), 'point_count' => count($points), 'points' => $points, 'half_hour_points' => $halfHour, 'start_marker' => $points[0] ?? null, 'end_marker' => $points ? $points[count($points) - 1] : null]);
}


function myhub_ensure_suggestion_complaints_table(PDO $pdo): void
{
    $pdo->exec("CREATE TABLE IF NOT EXISTS suggestion_complaints (
        id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
        username VARCHAR(128) NOT NULL,
        emp_id INT NULL,
        assigned_to_emp_id INT NULL,
        assigned_to_username VARCHAR(128) NULL,
        entry_type ENUM('suggestion','complaint') NOT NULL DEFAULT 'suggestion',
        category VARCHAR(80) NULL,
        subject VARCHAR(180) NULL,
        message TEXT NOT NULL,
        attachment_paths TEXT NULL,
        priority ENUM('low','normal','high','critical') NOT NULL DEFAULT 'normal',
        status ENUM('open','in_review','resolved','closed','rejected') NOT NULL DEFAULT 'open',
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX idx_suggestion_emp (emp_id, created_at),
        INDEX idx_suggestion_assigned (assigned_to_emp_id, status, created_at),
        INDEX idx_suggestion_status (status, created_at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");
    chat_ensure_column($pdo, 'suggestion_complaints', 'assigned_to_emp_id', "INT NULL AFTER emp_id");
    chat_ensure_column($pdo, 'suggestion_complaints', 'assigned_to_username', "VARCHAR(128) NULL AFTER assigned_to_emp_id");
}

function myhub_suggestion_upload_files(int $empId): string
{
    if (empty($_FILES)) return '';
    $files = [];
    foreach ($_FILES as $input) {
        if (!is_array($input)) continue;
        if (is_array($input['name'] ?? null)) {
            $count = count($input['name']);
            for ($i = 0; $i < $count; $i++) {
                $files[] = [
                    'name' => $input['name'][$i] ?? '',
                    'tmp_name' => $input['tmp_name'][$i] ?? '',
                    'error' => $input['error'][$i] ?? UPLOAD_ERR_NO_FILE,
                    'size' => $input['size'][$i] ?? 0,
                ];
            }
        } else {
            $files[] = $input;
        }
    }
    $stored = [];
    $root = dirname(__DIR__);
    $relativeDir = 'uploads/suggestions/' . $empId . '/' . date('Ymd');
    $targetDir = $root . DIRECTORY_SEPARATOR . str_replace('/', DIRECTORY_SEPARATOR, $relativeDir);
    if (!is_dir($targetDir) && !mkdir($targetDir, 0775, true) && !is_dir($targetDir)) {
        chat_json(['status' => false, 'error' => 'Suggestion upload directory is unavailable.'], 500);
    }
    foreach ($files as $file) {
        $error = (int)($file['error'] ?? UPLOAD_ERR_NO_FILE);
        if ($error === UPLOAD_ERR_NO_FILE) continue;
        if ($error !== UPLOAD_ERR_OK) {
            chat_json(['status' => false, 'error' => 'Suggestion file upload failed with code ' . $error], 422);
        }
        if ((int)($file['size'] ?? 0) > 10 * 1024 * 1024) {
            chat_json(['status' => false, 'error' => 'Each suggestion file must be 10MB or smaller.'], 422);
        }
        $name = preg_replace('/[^A-Za-z0-9._-]+/', '_', basename((string)($file['name'] ?? 'file')));
        $name = $name !== '' ? $name : 'file';
        $targetName = date('His') . '_' . bin2hex(random_bytes(4)) . '_' . $name;
        $target = $targetDir . DIRECTORY_SEPARATOR . $targetName;
        if (!move_uploaded_file((string)$file['tmp_name'], $target)) {
            chat_json(['status' => false, 'error' => 'Unable to save suggestion file.'], 500);
        }
        $stored[] = $relativeDir . '/' . $targetName;
        if (count($stored) >= 5) break;
    }
    return implode(',', $stored);
}

function myhub_suggestion_row(PDO $employeePdo, array $row): array
{
    $people = myhub_people($employeePdo, [(int)($row['emp_id'] ?? 0), (int)($row['assigned_to_emp_id'] ?? 0)]);
    $by = $people[0] ?? ['emp_id' => (int)($row['emp_id'] ?? 0), 'name' => (string)($row['username'] ?? ''), 'designation' => ''];
    $to = $people[1] ?? ['emp_id' => (int)($row['assigned_to_emp_id'] ?? 0), 'name' => (string)($row['assigned_to_username'] ?? ''), 'designation' => ''];
    return [
        'id' => (int)($row['id'] ?? 0),
        'username' => (string)($row['username'] ?? ''),
        'emp_id' => (int)($row['emp_id'] ?? 0),
        'created_by' => $by,
        'assigned_to_emp_id' => (int)($row['assigned_to_emp_id'] ?? 0),
        'assigned_to' => $to,
        'entry_type' => (string)($row['entry_type'] ?? 'suggestion'),
        'category' => (string)($row['category'] ?? ''),
        'subject' => (string)($row['subject'] ?? ''),
        'message' => (string)($row['message'] ?? ''),
        'attachment_paths' => (string)($row['attachment_paths'] ?? ''),
        'priority' => (string)($row['priority'] ?? 'normal'),
        'status' => (string)($row['status'] ?? 'open'),
        'created_at' => (string)($row['created_at'] ?? ''),
        'updated_at' => (string)($row['updated_at'] ?? ''),
    ];
}

function myhub_suggestions(int $empId): never
{
    $chatPdo = chat_db();
    $employeePdo = myhub_employee_db();
    myhub_ensure_suggestion_complaints_table($chatPdo);
    $stmt = $chatPdo->prepare(
        'SELECT * FROM suggestion_complaints
         WHERE emp_id = :emp_id OR assigned_to_emp_id = :emp_id
         ORDER BY created_at DESC, id DESC
         LIMIT 200'
    );
    $stmt->execute([':emp_id' => $empId]);
    $rows = array_map(
        static fn(array $row): array => myhub_suggestion_row($employeePdo, $row),
        $stmt->fetchAll(PDO::FETCH_ASSOC) ?: []
    );
    chat_json(['status' => true, 'items' => $rows]);
}

function myhub_create_suggestion(int $empId): never
{
    $entryType = strtolower(trim((string)($_POST['entry_type'] ?? $_POST['type'] ?? 'suggestion')));
    if (!in_array($entryType, ['suggestion', 'complaint'], true)) $entryType = 'suggestion';
    $category = mb_substr(trim((string)($_POST['category'] ?? 'General')), 0, 80);
    $priority = strtolower(trim((string)($_POST['priority'] ?? 'normal')));
    if (!in_array($priority, ['low', 'normal', 'high', 'critical'], true)) $priority = 'normal';
    $subject = mb_substr(trim((string)($_POST['subject'] ?? '')), 0, 180);
    $message = trim((string)($_POST['message'] ?? ''));
    $assignedTo = (int)($_POST['assigned_to_emp_id'] ?? $_POST['to_emp_id'] ?? 0);
    if ($assignedTo <= 0) chat_json(['status' => false, 'error' => 'Select the user this suggestion or complaint is for.'], 422);
    if ($subject === '') chat_json(['status' => false, 'error' => 'Subject is required.'], 422);
    if ($message === '') chat_json(['status' => false, 'error' => 'Message is required.'], 422);

    $chatPdo = chat_db();
    $employeePdo = myhub_employee_db();
    myhub_ensure_suggestion_complaints_table($chatPdo);
    $targetPeople = myhub_people($employeePdo, [$assignedTo]);
    $target = $targetPeople[0] ?? ['emp_id' => $assignedTo, 'name' => (string)$assignedTo];
    $attachmentPaths = myhub_suggestion_upload_files($empId);
    $stmt = $chatPdo->prepare(
        'INSERT INTO suggestion_complaints
         (username, emp_id, assigned_to_emp_id, assigned_to_username, entry_type, category, subject, message, attachment_paths, priority, status)
         VALUES (:username, :emp_id, :assigned_to_emp_id, :assigned_to_username, :entry_type, :category, :subject, :message, :attachment_paths, :priority, :status)'
    );
    $stmt->execute([
        ':username' => myhub_activity_username($empId),
        ':emp_id' => $empId,
        ':assigned_to_emp_id' => $assignedTo,
        ':assigned_to_username' => myhub_activity_username($assignedTo),
        ':entry_type' => $entryType,
        ':category' => $category !== '' ? $category : 'General',
        ':subject' => $subject,
        ':message' => $message,
        ':attachment_paths' => $attachmentPaths,
        ':priority' => $priority,
        ':status' => 'open',
    ]);
    $id = (int)$chatPdo->lastInsertId();
    try {
        $creator = myhub_people($employeePdo, [$empId])[0] ?? ['name' => (string)$empId, 'emp_id' => $empId];
        $body = ucfirst($entryType) . " received\n"
            . 'ID: ' . $id . "\n"
            . 'From: ' . myhub_people_label([$creator]) . "\n"
            . 'For: ' . myhub_people_label([$target]) . "\n"
            . 'Category: ' . ($category !== '' ? $category : 'General') . "\n"
            . 'Priority: ' . ucfirst($priority) . "\n"
            . 'Subject: ' . $subject . "\n"
            . 'Message: ' . mb_substr($message, 0, 1200);
        chat_send_system_notification($assignedTo, $body, 'suggestion_complaint', 'suggestion-' . $id . '-' . $assignedTo);
    } catch (Throwable $e) {
        error_log('Suggestion notification skipped: ' . $e->getMessage());
    }
    chat_json(['status' => true, 'suggestion_id' => $id, 'message' => 'Suggestion or complaint submitted successfully.']);
}
function myhub_verticals(PDO $pdo): never
{
    $table = myhub_first_table($pdo, ['tbl_vertical', 'vertical', 'verticals']);
    if ($table === '') chat_json(['status' => true, 'verticals' => []]);
    $columns = myhub_columns($pdo, $table);
    $idCol = myhub_first_column($columns, ['id', 'vertical_id']);
    $nameCol = myhub_first_column($columns, ['vertical_name', 'name', 'title']);
    if ($idCol === '' || $nameCol === '') chat_json(['status' => true, 'verticals' => []]);
    $stmt = $pdo->query("SELECT `{$idCol}` AS id, `{$nameCol}` AS name FROM `{$table}` ORDER BY `{$nameCol}` ASC LIMIT 500");
    chat_json(['status' => true, 'verticals' => $stmt->fetchAll(PDO::FETCH_ASSOC) ?: []]);
}

function myhub_tasks(int $empId): never
{
    $limit = max(20, min(100, (int)($_GET['limit'] ?? 50)));
    $offset = max(0, min(5000, (int)($_GET['offset'] ?? 0)));
    $taskPdo = myhub_task_db();
    $columns = myhub_columns($taskPdo, 'task_master', defined('TASK_DB_NAME') ? TASK_DB_NAME : null);
    if (empty($columns['title'])) {
        chat_json(['status' => false, 'error' => 'Task table is unavailable.'], 500);
    }

    $followerCol = isset($columns['task_followers']) ? 'task_followers' : (isset($columns['followed_by']) ? 'followed_by' : '');
    $deadlineCol = isset($columns['deadline']) ? 'deadline' : (isset($columns['due_date']) ? 'due_date' : '');
    $descCol = isset($columns['description']) ? 'description' : (isset($columns['task_description']) ? 'task_description' : '');

    $select = ['id', 'title'];
    foreach (['priority', 'status', 'emp_id', 'created_by'] as $column) {
        if (isset($columns[$column])) $select[] = $column;
    }
    if ($followerCol !== '') $select[] = "`{$followerCol}` AS follower_ids";
    if ($deadlineCol !== '') $select[] = "`{$deadlineCol}` AS deadline";
    if ($descCol !== '') $select[] = "`{$descCol}` AS description";
    $selectSql = implode(', ', array_unique($select));

    try {
        $stmt = $taskPdo->query("SELECT {$selectSql} FROM task_master ORDER BY id DESC LIMIT 1000");
        $rows = $stmt ? ($stmt->fetchAll(PDO::FETCH_ASSOC) ?: []) : [];
    } catch (Throwable $e) {
        error_log('MyHub task safe list failed: ' . $e->getMessage());
        chat_json(['status' => false, 'error' => 'Unable to load task list.'], 500);
    }

    $related = [];
    foreach ($rows as $row) {
        $assignees = myhub_parse_emp_ids((string)($row['emp_id'] ?? ''));
        $followers = myhub_parse_emp_ids((string)($row['follower_ids'] ?? ''));
        $createdBy = (int)($row['created_by'] ?? 0);
        if ($createdBy === $empId || in_array($empId, $assignees, true) || in_array($empId, $followers, true)) {
            $related[(int)$row['id']] = $row;
        }
    }
    $tasks = array_values($related);
    $employeePdo = myhub_employee_db();
    $peopleIds = [];
    foreach ($tasks as $task) {
        $peopleIds = array_merge(
            $peopleIds,
            myhub_parse_emp_ids((string)($task['emp_id'] ?? '')),
            myhub_parse_emp_ids((string)($task['follower_ids'] ?? '')),
            [(int)($task['created_by'] ?? 0)]
        );
    }
    $peopleMap = [];
    foreach (myhub_people($employeePdo, $peopleIds) as $person) {
        $peopleMap[(int)$person['emp_id']] = $person;
    }
    foreach ($tasks as &$task) {
        $assigneeIds = myhub_parse_emp_ids((string)($task['emp_id'] ?? ''));
        $followerIds = myhub_parse_emp_ids((string)($task['follower_ids'] ?? ''));
        $task['assignees'] = array_values(array_map(static fn(int $id): array => $peopleMap[$id] ?? ['emp_id' => $id, 'name' => (string)$id, 'designation' => ''], $assigneeIds));
        $task['followers'] = array_values(array_map(static fn(int $id): array => $peopleMap[$id] ?? ['emp_id' => $id, 'name' => (string)$id, 'designation' => ''], $followerIds));
        $creatorId = (int)($task['created_by'] ?? 0);
        $task['creator'] = $creatorId > 0 ? ($peopleMap[$creatorId] ?? ['emp_id' => $creatorId, 'name' => (string)$creatorId, 'designation' => '']) : null;
    }
    unset($task);

    usort($tasks, static function(array $a, array $b) use ($empId): int {
        $aCreated = (int)($a['created_by'] ?? 0) === $empId ? 0 : 1;
        $bCreated = (int)($b['created_by'] ?? 0) === $empId ? 0 : 1;
        if ($aCreated !== $bCreated) return $aCreated <=> $bCreated;
        $aDeadline = trim((string)($a['deadline'] ?? ''));
        $bDeadline = trim((string)($b['deadline'] ?? ''));
        $aTime = $aDeadline === '' ? PHP_INT_MAX : strtotime($aDeadline);
        $bTime = $bDeadline === '' ? PHP_INT_MAX : strtotime($bDeadline);
        if ($aTime !== $bTime) return $aTime <=> $bTime;
        return ((int)($b['id'] ?? 0)) <=> ((int)($a['id'] ?? 0));
    });

    $now = time();
    $today = date('Y-m-d');
    $metrics = [
        'open_count' => 0,
        'request_close_count' => 0,
        'closed_count' => 0,
        'due_today' => 0,
        'overdue' => 0,
    ];
    foreach ($tasks as $task) {
        $status = (int)($task['status'] ?? 0);
        $closed = in_array($status, [3, 4, 5], true);
        if ($status === 1) $metrics['request_close_count']++;
        if ($closed) {
            $metrics['closed_count']++;
        } else {
            if ($status !== 1) $metrics['open_count']++;
            $deadline = trim((string)($task['deadline'] ?? ''));
            if ($deadline !== '') {
                if (substr($deadline, 0, 10) === $today) $metrics['due_today']++;
                $deadlineTime = strtotime($deadline);
                if ($deadlineTime !== false && $deadlineTime < $now) $metrics['overdue']++;
            }
        }
    }

    $page = array_slice($tasks, $offset, $limit);
    chat_json([
        'status' => true,
        'metrics' => $metrics,
        'tasks' => $page,
        'limit' => $limit,
        'offset' => $offset,
    ]);
}

function myhub_create_task(int $empId): never
{
    $input = json_decode(file_get_contents('php://input') ?: '{}', true);
    if (!is_array($input)) {
        chat_json(['status' => false, 'error' => 'Invalid request body.'], 400);
    }
    $title = trim((string)($input['title'] ?? ''));
    $description = trim((string)($input['description'] ?? ''));
    $priority = strtolower(trim((string)($input['priority'] ?? 'medium')));
    $deadlineInput = trim((string)($input['deadline'] ?? ''));
    $groupId = max(0, (int)($input['group_id'] ?? 0));
    $assignees = array_values(array_unique(array_filter(array_map('intval', (array)($input['assignees'] ?? [])), static fn(int $id): bool => $id > 0)));
    $followers = array_values(array_unique(array_filter(array_map('intval', (array)($input['followers'] ?? [])), static fn(int $id): bool => $id > 0)));
    if ($title === '') {
        chat_json(['status' => false, 'error' => 'Please enter a task title.'], 422);
    }
    if (!$assignees) {
        $assignees = [$empId];
    }
    if (!$followers) {
        $followers = [$empId];
    }
    $priority = match ($priority) {
        'h', 'high' => 'high',
        'l', 'low' => 'low',
        default => 'medium',
    };
    $deadline = null;
    if ($deadlineInput !== '') {
        $ts = strtotime(str_replace('T', ' ', $deadlineInput));
        if ($ts === false) chat_json(['status' => false, 'error' => 'Invalid due date.'], 422);
        $deadline = date('Y-m-d H:i:s', $ts);
    }
    $taskPdo = myhub_task_db();
    $columns = myhub_columns($taskPdo, 'task_master', defined('TASK_DB_NAME') ? TASK_DB_NAME : null);
    $insert = ['title' => $title];
    if (isset($columns['priority'])) $insert['priority'] = $priority;
    if (isset($columns['description'])) $insert['description'] = $description;
    elseif (isset($columns['task_description'])) $insert['task_description'] = $description;
    if (isset($columns['deadline'])) $insert['deadline'] = $deadline;
    elseif (isset($columns['due_date'])) $insert['due_date'] = $deadline;
    if (isset($columns['emp_id'])) $insert['emp_id'] = implode(',', $assignees);
    if (isset($columns['task_followers'])) $insert['task_followers'] = implode(',', $followers);
    elseif (isset($columns['followed_by'])) $insert['followed_by'] = implode(',', $followers);
    if (isset($columns['task_groups'])) {
        $inputGroup = max(0, (int)($input['task_groups'] ?? $input['task_group'] ?? 0));
        $insert['task_groups'] = (string)($groupId > 0 ? $groupId : ($inputGroup > 0 ? $inputGroup : 99));
    }
    if (isset($columns['created_by'])) $insert['created_by'] = $empId;
    if (isset($columns['task_type'])) $insert['task_type'] = trim((string)($input['task_type'] ?? 'general'));
    if (isset($columns['meet_type'])) $insert['meet_type'] = max(1, (int)($input['meet_type'] ?? 1));
    if (isset($columns['vertical'])) $insert['vertical'] = trim((string)($input['vertical'] ?? 'general'));
    if (isset($columns['status'])) $insert['status'] = max(1, (int)($input['status'] ?? 2));
    if (isset($columns['next_followup_date'])) $insert['next_followup_date'] = trim((string)($input['next_followup_date'] ?? ''));
    if (isset($columns['created_at'])) $insert['created_at'] = date('Y-m-d H:i:s');
    if (isset($columns['updated_at'])) $insert['updated_at'] = date('Y-m-d H:i:s');
    $fieldSql = implode(', ', array_map(static fn(string $field): string => "`{$field}`", array_keys($insert)));
    $placeholderSql = implode(', ', array_map(static fn(string $field): string => ':' . $field, array_keys($insert)));
    $stmt = $taskPdo->prepare("INSERT INTO task_master ({$fieldSql}) VALUES ({$placeholderSql})");
    $stmt->execute($insert);
    $taskId = (int)$taskPdo->lastInsertId();
    try {
        $createdUpdate = $taskPdo->prepare(
            'INSERT INTO task_explained
             (task_id, comments, updated_by, comment_type)
             VALUES (:task_id, :comments, :updated_by, :comment_type)'
        );
        $createdUpdate->execute([
            ':task_id' => $taskId,
            ':comments' => 'Task created',
            ':updated_by' => $empId,
            ':comment_type' => 'Task Created',
        ]);
    } catch (Throwable $e) {
        error_log('Task created without task_explained audit row: ' . $e->getMessage());
    }
    $employeePdo = myhub_employee_db();
    $creatorPeople = myhub_people($employeePdo, [$empId]);
    $assigneePeople = myhub_people($employeePdo, $assignees);
    $followerPeople = myhub_people($employeePdo, $followers);
    $body = myhub_task_notification_body(
        'Task created',
        $taskId,
        $title,
        $description,
        $creatorPeople[0] ?? ['emp_id' => $empId, 'name' => (string)$empId, 'designation' => ''],
        $assigneePeople,
        $followerPeople,
        $priority,
        trim((string)($insert['vertical'] ?? $input['vertical'] ?? ''))
    );
    myhub_notify_task_participants($taskId, 'task_created', $body, $empId, $assignees, $followers, 'created');
    chat_json(['status' => true, 'task' => ['id' => $taskId, 'title' => $title]]);
}

function myhub_task_detail(int $empId): never
{
    $taskId = max(0, (int)($_GET['task_id'] ?? 0));
    if ($taskId <= 0) {
        chat_json(['status' => false, 'error' => 'Task ID is required.'], 422);
    }
    $taskPdo = myhub_task_db();
    $employeePdo = myhub_employee_db();
    $columns = myhub_columns($taskPdo, 'task_master', defined('TASK_DB_NAME') ? TASK_DB_NAME : null);
    if (empty($columns['title'])) {
        chat_json(['status' => false, 'error' => 'Task table is unavailable.'], 500);
    }
    $empExpr = isset($columns['emp_id']) ? "REPLACE(COALESCE(emp_id, ''), ' ', '')" : "''";
    $related = [];
    $bindings = [':task_id' => $taskId];
    if (isset($columns['emp_id'])) {
        $related[] = "{$empExpr} = :emp_text";
        $related[] = "FIND_IN_SET(:emp_assignee, {$empExpr})";
        $bindings[':emp_text'] = (string)$empId;
        $bindings[':emp_assignee'] = (string)$empId;
    }
    if (isset($columns['created_by'])) {
        $related[] = 'created_by = :creator';
        $bindings[':creator'] = $empId;
    }
    $followerColumn = isset($columns['task_followers'])
        ? 'task_followers'
        : (isset($columns['followed_by']) ? 'followed_by' : '');
    if ($followerColumn !== '') {
        $related[] = "FIND_IN_SET(:follower, REPLACE(COALESCE(`{$followerColumn}`, ''), ' ', ''))";
        $bindings[':follower'] = (string)$empId;
    }
    if (!$related) {
        chat_json(['status' => false, 'error' => 'Task ownership columns are unavailable.'], 500);
    }
    $priorityExpr = isset($columns['priority']) ? 'priority' : "''";
    $statusExpr = isset($columns['status']) ? 'COALESCE(status, 0)' : '0';
    $deadlineCol = isset($columns['deadline']) ? 'deadline' : (isset($columns['due_date']) ? 'due_date' : 'NULL');
    $descCol = isset($columns['description']) ? 'description' : (isset($columns['task_description']) ? 'task_description' : "''");
    $stmt = $taskPdo->prepare(
        'SELECT id, title, ' . $priorityExpr . ' AS priority, ' . $statusExpr . ' AS status, ' .
        $deadlineCol . ' AS deadline, ' . $descCol . ' AS description, ' .
        (isset($columns['created_by']) ? 'created_by' : '0 AS created_by') . ', ' .
        (isset($columns['emp_id']) ? 'emp_id' : "'' AS emp_id") . ', ' .
        ($followerColumn !== '' ? "`{$followerColumn}` AS follower_ids" : "'' AS follower_ids") .
        ' FROM task_master WHERE id = :task_id AND (' . implode(' OR ', $related) . ') LIMIT 1'
    );
    $stmt->execute($bindings);
    $task = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!$task) {
        chat_json(['status' => false, 'error' => 'Task not found or access denied.'], 404);
    }

    $assigneeIds = myhub_parse_emp_ids((string)($task['emp_id'] ?? ''));
    $followerIds = myhub_parse_emp_ids((string)($task['follower_ids'] ?? ''));
    $assignees = myhub_people($employeePdo, $assigneeIds);
    $followers = myhub_people($employeePdo, $followerIds);
    $creator = myhub_people($employeePdo, [(int)($task['created_by'] ?? 0)]);

    $updates = [];
    $updatesTable = myhub_first_table($taskPdo, ['task_explained', 'task_updates', 'task_comments']);
    if ($updatesTable !== '') {
        $updateColumns = myhub_columns($taskPdo, $updatesTable, defined('TASK_DB_NAME') ? TASK_DB_NAME : null);
        $updateIdCol = isset($updateColumns['id']) ? 'id' : '';
        $updateTaskCol = myhub_first_column($updateColumns, ['task_id', 'task_master_id']);
        $commentCol = myhub_first_column($updateColumns, ['comments', 'comment', 'description', 'remarks', 'update_text']);
        $updatedByCol = myhub_first_column($updateColumns, ['updated_by', 'created_by', 'emp_id']);
        $filePathCol = myhub_first_column($updateColumns, ['file_path', 'attachment', 'file_url']);
        $createdCol = myhub_first_column($updateColumns, ['created_at', 'updated_at', 'date', 'created_on']);
        $updatedCol = myhub_first_column($updateColumns, ['updated_at', 'created_at', 'date', 'updated_on']);
        $followupCol = myhub_first_column($updateColumns, ['next_followup_date', 'followup_date', 'next_action_date']);
        $typeCol = myhub_first_column($updateColumns, ['comment_type', 'type', 'update_type']);
        if ($updateTaskCol !== '' && $commentCol !== '') {
            $selectParts = [
                $updateIdCol !== '' ? "`{$updateIdCol}` AS id" : '0 AS id',
                "`{$updateTaskCol}` AS task_id",
                "`{$commentCol}` AS comments",
                $updatedByCol !== '' ? "`{$updatedByCol}` AS updated_by" : '0 AS updated_by',
                $filePathCol !== '' ? "`{$filePathCol}` AS file_path" : "'' AS file_path",
                $createdCol !== '' ? "`{$createdCol}` AS created_at" : "'' AS created_at",
                $updatedCol !== '' ? "`{$updatedCol}` AS updated_at" : "'' AS updated_at",
                $followupCol !== '' ? "`{$followupCol}` AS next_followup_date" : "'' AS next_followup_date",
                $typeCol !== '' ? "`{$typeCol}` AS comment_type" : "'' AS comment_type",
            ];
            $orderCol = $createdCol !== '' ? $createdCol : ($updateIdCol !== '' ? $updateIdCol : $updateTaskCol);
            $updatesStmt = $taskPdo->prepare(
                'SELECT ' . implode(', ', $selectParts) . "
                 FROM `{$updatesTable}`
                 WHERE `{$updateTaskCol}` = :task_id
                 ORDER BY `{$orderCol}` DESC" . ($updateIdCol !== '' ? ", `{$updateIdCol}` DESC" : '') . '
                 LIMIT 200'
            );
            $updatesStmt->execute([':task_id' => $taskId]);
            $updates = $updatesStmt->fetchAll(PDO::FETCH_ASSOC) ?: [];
        }
    }
    $updaterIds = [];
    foreach ($updates as $update) {
        $id = (int)($update['updated_by'] ?? 0);
        if ($id > 0) $updaterIds[] = $id;
    }
    $updaterMap = [];
    foreach (myhub_people($employeePdo, $updaterIds) as $person) {
        $updaterMap[(int)$person['emp_id']] = $person;
    }
    foreach ($updates as &$update) {
        $person = $updaterMap[(int)($update['updated_by'] ?? 0)] ?? null;
        $update['updated_by_name'] = (string)($person['name'] ?? ($update['updated_by'] ?? 'Unknown'));
        $update['updated_by_designation'] = (string)($person['designation'] ?? '');
    }
    unset($update);

    $task['assignees'] = $assignees;
    $task['followers'] = $followers;
    $task['creator'] = $creator[0] ?? null;
    chat_json([
        'status' => true,
        'task' => $task,
        'updates' => $updates,
    ]);
}

function myhub_ensure_leave_otp_table(PDO $pdo): void
{
    $pdo->exec(
        'CREATE TABLE IF NOT EXISTS xmpp_leave_otp_requests (
            id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
            emp_id INT NOT NULL,
            approver_emp_id INT NOT NULL DEFAULT 232,
            request_key VARCHAR(64) NOT NULL,
            from_date DATE NOT NULL,
            to_date DATE NOT NULL,
            leave_type_id INT NOT NULL DEFAULT 2,
            reason TEXT NULL,
            no_of_days DECIMAL(6,2) NOT NULL DEFAULT 0,
            otp_code VARCHAR(12) NOT NULL,
            requested_at DATETIME NOT NULL,
            expires_at DATETIME NOT NULL,
            verified_at DATETIME NULL,
            consumed_at DATETIME NULL,
            notification_message_id BIGINT NULL,
            UNIQUE KEY uniq_request_key (request_key),
            KEY idx_emp_pending (emp_id, consumed_at, expires_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci'
    );
}

function myhub_leave_day_count(string $from, string $to): float
{
    $fromDate = new DateTimeImmutable(date('Y-m-d', strtotime($from)));
    $toDate = new DateTimeImmutable(date('Y-m-d', strtotime($to)));
    if ($toDate < $fromDate) {
        throw new InvalidArgumentException('To date must be the same or after from date.');
    }
    return (float)$fromDate->diff($toDate)->days + 1.0;
}

function myhub_leave_request_key(int $empId, string $from, string $to, int $type, string $reason): string
{
    return hash('sha256', implode('|', [
        $empId,
        date('Y-m-d', strtotime($from)),
        date('Y-m-d', strtotime($to)),
        $type,
        trim($reason),
    ]));
}

function myhub_active_leave_otp(PDO $pdo, string $requestKey): ?array
{
    myhub_ensure_leave_otp_table($pdo);
    $stmt = $pdo->prepare(
        'SELECT *
         FROM xmpp_leave_otp_requests
         WHERE request_key = :request_key
           AND consumed_at IS NULL
         LIMIT 1'
    );
    $stmt->execute([':request_key' => $requestKey]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    return $row ?: null;
}

define('MYHUB_LEAVE_TEST_APPROVER_EMP_ID', 302);

function myhub_dispatch_leave_otp(PDO $pdo, int $empId, array $otpRow): array
{
    $body = sprintf(
        "Leave request OTP for employee %d\nFrom: %s\nTo: %s\nDays: %s\nOTP: %s",
        $empId,
        (string)$otpRow['from_date'],
        (string)$otpRow['to_date'],
        rtrim(rtrim(number_format((float)$otpRow['no_of_days'], 2, '.', ''), '0'), '.'),
        (string)$otpRow['otp_code']
    );
    $sent = chat_send_system_notification(
        MYHUB_LEAVE_TEST_APPROVER_EMP_ID,
        $body,
        'leave_otp',
        'leave-otp-' . $otpRow['request_key']
    );
    $update = $pdo->prepare(
        'UPDATE xmpp_leave_otp_requests
         SET notification_message_id = :message_id
         WHERE id = :id'
    );
    $update->execute([
        ':message_id' => (int)($sent['message_id'] ?? 0),
        ':id' => (int)$otpRow['id'],
    ]);
    return $sent;
}

function myhub_leave(PDO $pdo, int $empId): never
{
    $columns = myhub_columns($pdo, 'track_leave_request');
    if (!$columns) {
        chat_json(['status' => false, 'error' => 'Leave table is unavailable.'], 500);
    }
    $empColumn = isset($columns['emp_id']) ? 'emp_id' : (isset($columns['employee_id']) ? 'employee_id' : (isset($columns['user_id']) ? 'user_id' : ''));
    if ($empColumn === '') {
        chat_json(['status' => false, 'error' => 'Leave employee column is unavailable.'], 500);
    }
    $reasonCol = isset($columns['reason']) ? 'reason' : (isset($columns['leave_reason']) ? 'leave_reason' : "''");
    $stmt = $pdo->prepare(
        "SELECT from_date, to_date, leave_type_id, approval_status, {$reasonCol} AS reason
         FROM track_leave_request
         WHERE `{$empColumn}` = :emp_id
         ORDER BY from_date DESC
         LIMIT 120"
    );
    $stmt->execute([':emp_id' => $empId]);
    chat_json(['status' => true, 'leaves' => $stmt->fetchAll(PDO::FETCH_ASSOC) ?: []]);
}

function myhub_apply_leave(PDO $pdo, int $empId): never
{
    $input = json_decode(file_get_contents('php://input') ?: '{}', true);
    if (!is_array($input)) chat_json(['status' => false, 'error' => 'Invalid request body.'], 400);
    $from = trim((string)($input['from_date'] ?? ''));
    $to = trim((string)($input['to_date'] ?? ''));
    $type = max(1, (int)($input['leave_type_id'] ?? 2));
    $reason = trim((string)($input['reason'] ?? ''));
    $otp = trim((string)($input['otp'] ?? ''));
    if ($from === '' || $to === '' || strtotime($from) === false || strtotime($to) === false) {
        chat_json(['status' => false, 'error' => 'Select valid leave dates.'], 422);
    }
    $fromDate = date('Y-m-d', strtotime($from));
    $toDate = date('Y-m-d', strtotime($to));
    if (strtotime($toDate) < strtotime($fromDate)) {
        chat_json(['status' => false, 'error' => 'To date must be after from date.'], 422);
    }
    $noOfDays = myhub_leave_day_count($fromDate, $toDate);
    $requestKey = myhub_leave_request_key($empId, $fromDate, $toDate, $type, $reason);
    $existingOtp = myhub_active_leave_otp($pdo, $requestKey);

    if ($otp === '') {
        if (!$existingOtp || (!empty($existingOtp['expires_at']) && strtotime((string)$existingOtp['expires_at']) < time())) {
            $code = str_pad((string)random_int(0, 999999), 6, '0', STR_PAD_LEFT);
            if ($existingOtp) {
                $stmt = $pdo->prepare(
                    'UPDATE xmpp_leave_otp_requests
                     SET otp_code = :otp_code,
                         requested_at = NOW(),
                         expires_at = DATE_ADD(NOW(), INTERVAL 3 DAY),
                         verified_at = NULL,
                         consumed_at = NULL,
                         no_of_days = :no_of_days,
                         reason = :reason,
                         leave_type_id = :leave_type_id,
                         from_date = :from_date,
                         to_date = :to_date
                     WHERE id = :id'
                );
                $stmt->execute([
                    ':otp_code' => $code,
                    ':no_of_days' => $noOfDays,
                    ':reason' => $reason,
                    ':leave_type_id' => $type,
                    ':from_date' => $fromDate,
                    ':to_date' => $toDate,
                    ':id' => (int)$existingOtp['id'],
                ]);
            } else {
                $stmt = $pdo->prepare(
                    'INSERT INTO xmpp_leave_otp_requests
                     (emp_id, approver_emp_id, request_key, from_date, to_date, leave_type_id, reason, no_of_days, otp_code, requested_at, expires_at)
                     VALUES
                     (:emp_id, :approver_emp_id, :request_key, :from_date, :to_date, :leave_type_id, :reason, :no_of_days, :otp_code, NOW(), DATE_ADD(NOW(), INTERVAL 3 DAY))'
                );
                $stmt->execute([
                    ':emp_id' => $empId,
                    ':approver_emp_id' => MYHUB_LEAVE_TEST_APPROVER_EMP_ID,
                    ':request_key' => $requestKey,
                    ':from_date' => $fromDate,
                    ':to_date' => $toDate,
                    ':leave_type_id' => $type,
                    ':reason' => $reason,
                    ':no_of_days' => $noOfDays,
                    ':otp_code' => $code,
                ]);
            }
            $existingOtp = myhub_active_leave_otp($pdo, $requestKey);
        }
        if (!$existingOtp) {
            chat_json(['status' => false, 'error' => 'Unable to create leave OTP.'], 500);
        }
        $sent = myhub_dispatch_leave_otp($pdo, $empId, $existingOtp);
        chat_json([
            'status' => true,
            'otp_required' => true,
            'request_key' => $requestKey,
            'no_of_days' => $noOfDays,
            'otp_sent_to_emp_id' => MYHUB_LEAVE_TEST_APPROVER_EMP_ID,
            'expires_at' => $existingOtp['expires_at'],
            'notification_message_id' => $sent['message_id'] ?? 0,
            'message' => 'OTP sent for leave approval. Enter the same OTP to submit.',
        ]);
    }

    if (!$existingOtp) {
        chat_json(['status' => false, 'error' => 'Request OTP first.'], 422);
    }
    if (!empty($existingOtp['consumed_at'])) {
        chat_json(['status' => false, 'error' => 'This leave OTP was already used. Request a new OTP.'], 422);
    }
    if ((string)$existingOtp['otp_code'] !== $otp) {
        chat_json(['status' => false, 'error' => 'Invalid OTP.'], 422);
    }

    $columns = myhub_columns($pdo, 'track_leave_request');
    $empColumn = isset($columns['emp_id']) ? 'emp_id' : (isset($columns['employee_id']) ? 'employee_id' : (isset($columns['user_id']) ? 'user_id' : ''));
    if ($empColumn === '' || empty($columns['from_date']) || empty($columns['to_date'])) {
        chat_json(['status' => false, 'error' => 'Leave table columns are unavailable.'], 500);
    }
    $insert = [$empColumn => $empId, 'from_date' => $fromDate, 'to_date' => $toDate];
    if (isset($columns['leave_type_id'])) $insert['leave_type_id'] = $type;
    if (isset($columns['reason'])) $insert['reason'] = $reason;
    elseif (isset($columns['leave_reason'])) $insert['leave_reason'] = $reason;
    $daysColumn = myhub_first_column($columns, ['no_of_days', 'nodays', 'total_days', 'leave_days', 'days_count']);
    if ($daysColumn !== '') $insert[$daysColumn] = $noOfDays;
    if (isset($columns['otp'])) $insert['otp'] = $otp;
    if (isset($columns['approval_status'])) $insert['approval_status'] = 1;
    if (isset($columns['approver_emp_id'])) $insert['approver_emp_id'] = (string)MYHUB_LEAVE_TEST_APPROVER_EMP_ID;
    if (isset($columns['created_at'])) $insert['created_at'] = date('Y-m-d H:i:s');
    if (isset($columns['updated_at'])) $insert['updated_at'] = date('Y-m-d H:i:s');
    $fieldSql = implode(', ', array_map(static fn(string $field): string => "`{$field}`", array_keys($insert)));
    $placeholderSql = implode(', ', array_map(static fn(string $field): string => ':' . $field, array_keys($insert)));
    $stmt = $pdo->prepare("INSERT INTO track_leave_request ({$fieldSql}) VALUES ({$placeholderSql})");
    $stmt->execute($insert);
    $leaveId = (int)$pdo->lastInsertId();

    $consume = $pdo->prepare(
        'UPDATE xmpp_leave_otp_requests
         SET verified_at = COALESCE(verified_at, NOW()),
             consumed_at = NOW()
         WHERE id = :id'
    );
    $consume->execute([':id' => (int)$existingOtp['id']]);

    chat_json([
        'status' => true,
        'otp_verified' => true,
        'leave_id' => $leaveId,
        'no_of_days' => $noOfDays,
        'message' => 'Leave request submitted successfully.',
    ]);
}

$section = strtolower(trim((string)($_GET['section'] ?? 'directory')));

try {
    if ($_SERVER['REQUEST_METHOD'] === 'POST' && $section === 'task_create') {
        myhub_create_task($empId);
    }
    if ($_SERVER['REQUEST_METHOD'] === 'POST' && $section === 'leave_apply') {
        myhub_apply_leave(myhub_leave_db(), $empId);
    }
    if ($_SERVER['REQUEST_METHOD'] === 'POST' && $section === 'activity') {
        myhub_create_activity($empId);
    }
    if ($_SERVER['REQUEST_METHOD'] === 'POST' && $section === 'suggestions') {
        myhub_create_suggestion($empId);
    }
    match ($section) {
        'directory' => myhub_directory(myhub_employee_db()),
        'verticals' => myhub_verticals(myhub_employee_db()),
        'tasks' => myhub_tasks($empId),
        'task_detail' => myhub_task_detail($empId),
        'leave' => myhub_leave(myhub_leave_db(), $empId),
        'activity' => myhub_activity_logs($empId),
        'suggestions' => myhub_suggestions($empId),
        'horizon' => myhub_horizon(myhub_employee_db(), $empId),
        'horizon_timeline' => myhub_horizon_timeline(myhub_employee_db(), $empId),
        default => chat_json(['status' => false, 'error' => 'Unknown MyHub section.'], 404),
    };
} catch (Throwable $e) {
    error_log('MyHub failed [' . $section . ']: ' . $e->getMessage());
    $message = 'Unable to load MyHub data.';
    if ($section === 'leave' || $section === 'leave_apply' || chat_diagnostics_allowed($empId)) {
        $message = $e->getMessage() !== '' ? $e->getMessage() : $message;
    }
    chat_json(['status' => false, 'error' => $message], 500);
}


