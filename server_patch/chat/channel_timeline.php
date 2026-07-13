<?php
declare(strict_types=1);
require_once __DIR__ . '/bootstrap.php';

$session = chat_require_user();
$input = json_decode(file_get_contents('php://input') ?: '{}', true);
if (!is_array($input)) chat_json(['status' => false, 'error' => 'Invalid JSON'], 422);
$groupId = max(0, (int)($input['group_id'] ?? 0));
$eventType = trim((string)($input['event_type'] ?? 'Activity'));
$body = trim((string)($input['body'] ?? $eventType));
if ($groupId <= 0 || $eventType === '') chat_json(['status' => false, 'error' => 'Timeline event is required'], 422);

$pdo = chat_db();
chat_ensure_schema($pdo);
$member = $pdo->prepare(
    'SELECT 1 FROM xmpp_group_members WHERE group_id = :group_id AND emp_id = :emp_id LIMIT 1'
);
$member->execute([':group_id' => $groupId, ':emp_id' => (int)$session['emp_id']]);
if (!$member->fetchColumn()) chat_json(['status' => false, 'error' => 'Channel membership is required'], 403);

$stmt = $pdo->prepare(
    'INSERT INTO xmpp_channel_timeline (group_id, event_type, body, actor_emp_id)
     VALUES (:group_id, :event_type, :body, :actor)'
);
$stmt->execute([
    ':group_id' => $groupId,
    ':event_type' => mb_substr($eventType, 0, 80),
    ':body' => $body,
    ':actor' => (int)$session['emp_id'],
]);
chat_json(['status' => true, 'event_id' => (int)$pdo->lastInsertId()]);
