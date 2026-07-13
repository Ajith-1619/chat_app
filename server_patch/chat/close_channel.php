<?php
declare(strict_types=1);
require_once __DIR__ . '/bootstrap.php';

$session = chat_require_user();
$pdo = chat_db();
chat_ensure_schema($pdo);
$input = json_decode(file_get_contents('php://input') ?: '{}', true);
$channelId = max(0, (int)($input['channel_id'] ?? 0));
$check = $pdo->prepare(
    'SELECT 1 FROM xmpp_groups g
     INNER JOIN xmpp_group_members gm ON gm.group_id = g.id
     WHERE g.id = :id AND g.group_type = \'channel\'
       AND gm.emp_id = :emp_id AND gm.role = \'owner\' LIMIT 1'
);
$check->execute([':id' => $channelId, ':emp_id' => (int)$session['emp_id']]);
if (!$check->fetchColumn()) {
    chat_json(['status' => false, 'error' => 'Only the channel owner can close it'], 403);
}
$stmt = $pdo->prepare(
    'UPDATE xmpp_groups
     SET is_archived = 1, archived_at = NOW(), status = \'Closed\'
     WHERE id = :id'
);
$stmt->execute([':id' => $channelId]);
$timeline = $pdo->prepare(
    'INSERT INTO xmpp_channel_timeline (group_id, event_type, body, actor_emp_id)
     VALUES (:group_id, \'Ticket Closed\', \'Channel closed and archived\', :actor)'
);
$timeline->execute([
    ':group_id' => $channelId,
    ':actor' => (int)$session['emp_id'],
]);
chat_json(['status' => true]);
