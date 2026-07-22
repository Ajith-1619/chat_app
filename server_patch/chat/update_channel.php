<?php
declare(strict_types=1);
require_once __DIR__ . '/bootstrap.php';

$session = chat_require_user();
$pdo = chat_db();
chat_ensure_schema($pdo);

$input = json_decode(file_get_contents('php://input') ?: '{}', true);
if (!is_array($input)) chat_json(['status' => false, 'error' => 'Invalid JSON'], 422);

$groupId = max(0, (int)($input['group_id'] ?? 0));
if ($groupId <= 0) chat_json(['status' => false, 'error' => 'Channel is required'], 422);

$stmt = $pdo->prepare("SELECT g.*, gm.role FROM xmpp_groups g INNER JOIN xmpp_group_members gm ON gm.group_id = g.id WHERE g.id = :group_id AND gm.emp_id = :emp_id AND (g.group_type = 'channel' OR g.room_jid LIKE 'channel-%' OR g.room_name LIKE '#%') LIMIT 1");
$stmt->execute([':group_id' => $groupId, ':emp_id' => (int)$session['emp_id']]);
$channel = $stmt->fetch(PDO::FETCH_ASSOC);
if (!$channel) chat_json(['status' => false, 'error' => 'Channel not found'], 404);
if (!in_array((string)$channel['role'], ['owner', 'admin'], true)) {
    chat_json(['status' => false, 'error' => 'Only owner/admin can update channel details'], 403);
}

$description = trim((string)($input['description'] ?? ''));
if (mb_strlen($description) > 4000) $description = mb_substr($description, 0, 4000);
$kind = strtolower(trim((string)($input['channel_type'] ?? $input['channel_kind'] ?? $channel['channel_kind'] ?? 'operational')));
$allowedKinds = ['incident', 'action', 'operational', 'project', 'announcement', 'ticket', 'installation', 'l2_feasibility', 'protect'];
if (!in_array($kind, $allowedKinds, true)) $kind = (string)($channel['channel_kind'] ?? 'operational');
$status = trim((string)($input['status'] ?? $channel['status'] ?? 'Open')) ?: 'Open';
$priority = trim((string)($input['priority'] ?? $channel['priority'] ?? 'Normal')) ?: 'Normal';
$targetDateRaw = trim((string)($input['target_date'] ?? ''));
$nextActionRaw = trim((string)($input['next_action_date'] ?? ''));
$targetDate = $targetDateRaw !== '' ? date('Y-m-d H:i:s', strtotime($targetDateRaw) ?: time()) : null;
$nextActionDate = $nextActionRaw !== '' ? date('Y-m-d H:i:s', strtotime($nextActionRaw) ?: time()) : null;

$update = $pdo->prepare("UPDATE xmpp_groups
    SET description = :description,
        channel_kind = :kind,
        status = :status,
        priority = :priority,
        target_date = :target_date,
        next_action_date = :next_action_date
    WHERE id = :group_id");
$update->execute([
    ':description' => $description !== '' ? $description : null,
    ':kind' => $kind,
    ':status' => mb_substr($status, 0, 40),
    ':priority' => mb_substr($priority, 0, 20),
    ':target_date' => $targetDate,
    ':next_action_date' => $nextActionDate,
    ':group_id' => $groupId,
]);
try {
    $timeline = $pdo->prepare('INSERT INTO xmpp_channel_timeline (group_id, event_type, body, actor_emp_id) VALUES (:group_id, :event_type, :body, :actor)');
    $timeline->execute([
        ':group_id' => $groupId,
        ':event_type' => 'channel_details_updated',
        ':body' => 'Channel details updated',
        ':actor' => (int)$session['emp_id'],
    ]);
} catch (Throwable $e) {
    error_log('channel update timeline skipped: ' . $e->getMessage());
}

chat_json(['status' => true, 'message' => 'Channel updated']);
