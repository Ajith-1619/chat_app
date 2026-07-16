<?php
declare(strict_types=1);
require_once __DIR__ . '/bootstrap.php';
require_once __DIR__ . '/SystemNotification.php';
function task_update_first_column(array $columns, array $candidates): string
{
    foreach ($candidates as $candidate) {
        if (isset($columns[$candidate])) return $candidate;
    }
    return '';
}

function task_update_first_table(PDO $pdo, array $tables): string
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

function task_update_columns(PDO $pdo, string $table): array
{
    $stmt = $pdo->prepare(
        'SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = :table_name'
    );
    $stmt->execute([':table_name' => $table]);
    return array_fill_keys(array_map('strtolower', $stmt->fetchAll(PDO::FETCH_COLUMN) ?: []), true);
}

function task_update_parse_emp_ids(string $value): array
{
    $parts = preg_split('/\s*,\s*/', trim($value)) ?: [];
    return array_values(array_unique(array_filter(array_map('intval', $parts), static fn(int $id): bool => $id > 0)));
}

function task_update_employee_db(): PDO
{
    if (function_exists('getEmployeeDB')) {
        try {
            return getEmployeeDB();
        } catch (Throwable $e) {
            error_log('Task update employee DB fallback: ' . $e->getMessage());
        }
    }
    return chat_db();
}

function task_update_people(PDO $employeePdo, array $empIds): array
{
    $empIds = array_values(array_unique(array_filter(array_map('intval', $empIds), static fn(int $id): bool => $id > 0)));
    if (!$empIds) return [];
    $table = task_update_first_table($employeePdo, ['employee', 'employees', 'users', 'tbl_employee']);
    if ($table === '') {
        return array_map(static fn(int $id): array => ['emp_id' => $id, 'name' => (string)$id], $empIds);
    }
    $columns = task_update_columns($employeePdo, $table);
    $idCol = task_update_first_column($columns, ['emp_id', 'employee_id', 'user_id', 'id']);
    $nameCol = task_update_first_column($columns, ['name', 'employee_name', 'emp_name', 'full_name', 'username']);
    if ($idCol === '' || $nameCol === '') {
        return array_map(static fn(int $id): array => ['emp_id' => $id, 'name' => (string)$id], $empIds);
    }
    $placeholders = implode(', ', array_fill(0, count($empIds), '?'));
    $stmt = $employeePdo->prepare("SELECT `{$idCol}` AS emp_id, `{$nameCol}` AS name FROM `{$table}` WHERE `{$idCol}` IN ({$placeholders})");
    $stmt->execute($empIds);
    $mapped = [];
    foreach (($stmt->fetchAll(PDO::FETCH_ASSOC) ?: []) as $row) {
        $mapped[(int)$row['emp_id']] = ['emp_id' => (int)$row['emp_id'], 'name' => (string)($row['name'] ?? $row['emp_id'])];
    }
    $result = [];
    foreach ($empIds as $id) $result[] = $mapped[$id] ?? ['emp_id' => $id, 'name' => (string)$id];
    return $result;
}

function task_update_people_label(array $people): string
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

function task_update_notify_participants(int $taskId, array $task, int $updatedById, string $comments, int $updateId): void
{
    $creatorId = (int)($task['created_by'] ?? 0);
    $assigneeIds = task_update_parse_emp_ids((string)($task['emp_id'] ?? ''));
    $followerIds = task_update_parse_emp_ids((string)($task['follower_ids'] ?? ''));
    $employeePdo = task_update_employee_db();
    $creatorPeople = task_update_people($employeePdo, [$creatorId]);
    $assigneePeople = task_update_people($employeePdo, $assigneeIds);
    $followerPeople = task_update_people($employeePdo, $followerIds);
    $updatedPeople = task_update_people($employeePdo, [$updatedById]);
    $body = mb_substr(implode("\n", [
        'Task updated',
        'Task ID: ' . $taskId,
        'Title: ' . (string)($task['title'] ?? ''),
        'Description: ' . (trim((string)($task['description'] ?? '')) !== '' ? trim((string)$task['description']) : '-'),
        'Created by: ' . task_update_people_label($creatorPeople),
        'Assignees: ' . task_update_people_label($assigneePeople),
        'Followers: ' . task_update_people_label($followerPeople),
        'Vertical: ' . (trim((string)($task['vertical'] ?? '')) !== '' ? trim((string)$task['vertical']) : '-'),
        'Priority: ' . (trim((string)($task['priority'] ?? '')) !== '' ? ucfirst(trim((string)$task['priority'])) : '-'),
        'Updated by: ' . task_update_people_label($updatedPeople),
        'Update: ' . $comments,
    ]), 0, 3900);
    $recipients = array_values(array_unique(array_filter(array_merge([$creatorId], $assigneeIds, $followerIds), static fn(int $id): bool => $id > 0)));
    foreach ($recipients as $recipientId) {
        try {
            chat_send_system_notification($recipientId, $body, 'task_updated', 'task-updated-' . $taskId . '-' . $updateId . '-' . $recipientId);
        } catch (Throwable $e) {
            error_log('Task update system notification skipped: ' . $e->getMessage());
        }
    }
}

$session = chat_require_user();
$empId = (int)$session['emp_id'];
$input = json_decode(file_get_contents('php://input') ?: '{}', true);
if (!is_array($input)) {
    chat_json(['status' => false, 'error' => 'Invalid request body.'], 400);
}
$taskId = max(0, (int)($input['task_id'] ?? 0));
$comments = trim((string)($input['comments'] ?? ''));
if ($taskId <= 0 || $comments === '') {
    chat_json(['status' => false, 'error' => 'Select a task and enter an update.'], 422);
}
if (mb_strlen($comments) > 10000) {
    chat_json(['status' => false, 'error' => 'Task update is too long.'], 422);
}

$pdo = function_exists('getTaskDB') ? getTaskDB() : getDB();
$schema = defined('TASK_DB_NAME') ? TASK_DB_NAME : null;
$columnStmt = $schema
    ? $pdo->prepare(
        'SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS
         WHERE TABLE_SCHEMA = :schema AND TABLE_NAME = :table'
    )
    : $pdo->prepare(
        'SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = :table'
    );
$params = [':table' => 'task_master'];
if ($schema) $params[':schema'] = $schema;
$columnStmt->execute($params);
$columns = array_fill_keys(array_map('strtolower', $columnStmt->fetchAll(PDO::FETCH_COLUMN) ?: []), true);

$related = [];
$bindings = [':task_id' => $taskId];
if (isset($columns['emp_id'])) {
    $related[] = "REPLACE(COALESCE(emp_id, ''), ' ', '') = :emp_text";
    $related[] = "FIND_IN_SET(:emp_assignee, REPLACE(COALESCE(emp_id, ''), ' ', ''))";
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
    $related[] = "FIND_IN_SET(:follower, REPLACE(COALESCE(" .
        $followerColumn . ", ''), ' ', ''))";
    $bindings[':follower'] = (string)$empId;
}
if (!$related) {
    chat_json(['status' => false, 'error' => 'Task ownership columns are unavailable.'], 500);
}
$statusSql = '';
$check = $pdo->prepare(
    'SELECT 1 FROM task_master WHERE id = :task_id AND (' .
    implode(' OR ', $related) . ')' . $statusSql . ' LIMIT 1'
);
$check->execute($bindings);
if (!$check->fetchColumn()) {
    chat_json(['status' => false, 'error' => 'Open task not found or access denied.'], 403);
}

$stmt = $pdo->prepare(
    'INSERT INTO task_explained
     (task_id, comments, updated_by, comment_type)
     VALUES (:task_id, :comments, :updated_by, :comment_type)'
);
$stmt->execute([
    ':task_id' => $taskId,
    ':comments' => $comments,
    ':updated_by' => $empId,
    ':comment_type' => 'Chat Update',
]);
$updateId = (int)$pdo->lastInsertId();
$descColumn = task_update_first_column($columns, ['description', 'task_description']);
$verticalColumn = task_update_first_column($columns, ['vertical']);
$taskSelect = ['id', 'title'];
foreach (['priority', 'emp_id', 'created_by'] as $column) {
    if (isset($columns[$column])) $taskSelect[] = "`{$column}`";
}
if ($descColumn !== '') $taskSelect[] = "`{$descColumn}` AS description";
if ($verticalColumn !== '') $taskSelect[] = "`{$verticalColumn}` AS vertical";
if ($followerColumn !== '') $taskSelect[] = "`{$followerColumn}` AS follower_ids";
$taskStmt = $pdo->prepare('SELECT ' . implode(', ', array_unique($taskSelect)) . ' FROM task_master WHERE id = :task_id LIMIT 1');
$taskStmt->execute([':task_id' => $taskId]);
$taskRow = $taskStmt->fetch(PDO::FETCH_ASSOC) ?: [];
if ($taskRow) {
    task_update_notify_participants($taskId, $taskRow, $empId, $comments, $updateId);
}
chat_json([
    'status' => true,
    'task_id' => $taskId,
    'update_id' => $updateId,
]);
