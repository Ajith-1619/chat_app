<?php
declare(strict_types=1);
require_once __DIR__ . '/bootstrap.php';

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
chat_json([
    'status' => true,
    'task_id' => $taskId,
    'update_id' => (int)$pdo->lastInsertId(),
]);