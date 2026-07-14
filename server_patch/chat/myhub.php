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

function myhub_tasks(int $empId): never
{
    $limit = max(20, min(100, (int)($_GET['limit'] ?? 50)));
    $offset = max(0, min(5000, (int)($_GET['offset'] ?? 0)));
    $taskPdo = myhub_task_db();
    $columns = myhub_columns($taskPdo, 'task_master', defined('TASK_DB_NAME') ? TASK_DB_NAME : null);
    if (empty($columns['title'])) {
        chat_json(['status' => false, 'error' => 'Task table is unavailable.'], 500);
    }
    $empExpr = "REPLACE(COALESCE(emp_id, ''), ' ', '')";
    $followerCol = isset($columns['task_followers']) ? 'task_followers' : (isset($columns['followed_by']) ? 'followed_by' : '');
    $related = ["{$empExpr} = :emp_text", "FIND_IN_SET(:emp_csv_assignee, {$empExpr})"];
    $hasCreatedBy = isset($columns['created_by']);
    if ($hasCreatedBy) {
        $related[] = 'created_by = :emp_id';
    }
    if ($followerCol !== '') {
        $related[] = "FIND_IN_SET(:emp_csv_follower, REPLACE(COALESCE(`{$followerCol}`, ''), ' ', ''))";
    }
    $where = '(' . implode(' OR ', $related) . ')';
    $params = [':emp_text' => (string)$empId, ':emp_csv_assignee' => (string)$empId];
    if ($followerCol !== '') $params[':emp_csv_follower'] = (string)$empId;
    if ($hasCreatedBy) $params[':emp_id'] = $empId;
    $statusExpr = isset($columns['status']) ? 'COALESCE(status, 0)' : '0';
    // Legacy task_master uses status 2 for active/open tasks. Treat only 3+ as closed.
    $closedStatusSql = "{$statusExpr} IN (3, 4, 5)";
    $priorityExpr = isset($columns['priority']) ? 'priority' : "'' AS priority";
    $metricSql = "SELECT
        SUM(CASE WHEN {$statusExpr} <> 1 AND NOT ({$closedStatusSql}) THEN 1 ELSE 0 END) AS open_count,
        SUM(CASE WHEN {$statusExpr} = 1 THEN 1 ELSE 0 END) AS request_close_count,
        SUM(CASE WHEN {$closedStatusSql} THEN 1 ELSE 0 END) AS closed_count";
    if (isset($columns['deadline'])) {
        $metricSql .= ",
        SUM(CASE WHEN NOT ({$closedStatusSql}) AND DATE(deadline) = CURDATE() THEN 1 ELSE 0 END) AS due_today,
        SUM(CASE WHEN NOT ({$closedStatusSql}) AND deadline IS NOT NULL AND deadline < NOW() THEN 1 ELSE 0 END) AS overdue";
    } else {
        $metricSql .= ', 0 AS due_today, 0 AS overdue';
    }
    $metricSql .= " FROM task_master WHERE {$where}";
    $metricStmt = $taskPdo->prepare($metricSql);
    $metricStmt->execute($params);
    $metrics = $metricStmt->fetch(PDO::FETCH_ASSOC) ?: [];

    $deadlineCol = isset($columns['deadline']) ? 'deadline' : (isset($columns['due_date']) ? 'due_date' : "NULL");
    $descCol = isset($columns['description']) ? 'description' : (isset($columns['task_description']) ? 'task_description' : "''");
    $listAssigneeSql = isset($columns['emp_id']) ? 'emp_id' : "'' AS emp_id";
    $listFollowerSql = $followerCol !== '' ? "`{$followerCol}` AS follower_ids" : "'' AS follower_ids";
    $stmt = $taskPdo->prepare(
        "SELECT id, title, {$priorityExpr}, {$statusExpr} AS status, {$deadlineCol} AS deadline, {$descCol} AS description, " .
        (isset($columns['created_by']) ? 'created_by' : '0 AS created_by') . ', ' .
        $listAssigneeSql . ', ' . $listFollowerSql . "
         FROM task_master
         WHERE {$where}
         ORDER BY
           " . ($hasCreatedBy ? "CASE WHEN created_by = :emp_order_id THEN 0 ELSE 1 END," : "") . "
           CASE WHEN NOT ({$closedStatusSql}) AND {$deadlineCol} IS NOT NULL AND {$deadlineCol} < NOW() THEN 0 ELSE 1 END,
           CASE WHEN {$statusExpr} = 1 THEN 0 ELSE 1 END,
           CASE WHEN {$deadlineCol} IS NULL THEN 1 ELSE 0 END,
           COALESCE({$deadlineCol}, '2999-12-31') ASC,
           id DESC
         LIMIT {$limit} OFFSET {$offset}"
    );
    if ($hasCreatedBy) {
        $params[':emp_order_id'] = $empId;
    }
    $stmt->execute($params);
    chat_json([
        'status' => true,
        'metrics' => $metrics,
        'tasks' => $stmt->fetchAll(PDO::FETCH_ASSOC) ?: [],
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
        232,
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
                     (:emp_id, 232, :request_key, :from_date, :to_date, :leave_type_id, :reason, :no_of_days, :otp_code, NOW(), DATE_ADD(NOW(), INTERVAL 3 DAY))'
                );
                $stmt->execute([
                    ':emp_id' => $empId,
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
            'otp_sent_to_emp_id' => 232,
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
    if (isset($columns['approval_status'])) $insert['approval_status'] = 0;
    if (isset($columns['created_at'])) $insert['created_at'] = date('Y-m-d H:i:s');
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

try {
    $section = strtolower(trim((string)($_GET['section'] ?? 'directory')));
    if ($_SERVER['REQUEST_METHOD'] === 'POST' && $section === 'task_create') {
        myhub_create_task($empId);
    }
    if ($_SERVER['REQUEST_METHOD'] === 'POST' && $section === 'leave_apply') {
        myhub_apply_leave(myhub_employee_db(), $empId);
    }
    match ($section) {
        'directory' => myhub_directory(myhub_employee_db()),
        'tasks' => myhub_tasks($empId),
        'task_detail' => myhub_task_detail($empId),
        'leave' => myhub_leave(myhub_employee_db(), $empId),
        default => chat_json(['status' => false, 'error' => 'Unknown MyHub section.'], 404),
    };
} catch (Throwable $e) {
    error_log('MyHub failed: ' . $e->getMessage());
    chat_json(['status' => false, 'error' => 'Unable to load MyHub data.'], 500);
}
