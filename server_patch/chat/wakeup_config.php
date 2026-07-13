<?php
declare(strict_types=1);
require_once __DIR__ . '/bootstrap.php';
require_once __DIR__ . '/wakeup_helpers.php';
$session = chat_require_user();
$pdo = chat_db();
chat_ensure_schema($pdo);
$input = [];
if (($_SERVER['REQUEST_METHOD'] ?? 'GET') === 'POST') {
    $input = json_decode(file_get_contents('php://input') ?: '{}', true);
    if (!is_array($input)) chat_json(['status' => false, 'error' => 'Invalid JSON'], 422);
}
$groupId = max(0, (int)($_GET['group_id'] ?? $input['group_id'] ?? 0));
$jid = strtolower(trim((string)($_GET['jid'] ?? $input['jid'] ?? '')));
if ($groupId <= 0 && $jid === '') chat_json(['status' => false, 'error' => 'Group or channel is required'], 422);
$stmt = $pdo->prepare(
    'SELECT g.*, gm.role,
            COALESCE(last_msg.last_message_at, g.created_at) AS last_activity_at
     FROM xmpp_groups g
     INNER JOIN xmpp_group_members gm ON gm.group_id = g.id
     LEFT JOIN (
        SELECT to_jid, MAX(created_at) AS last_message_at
        FROM xmpp_messages
        WHERE message_type IN (\'groupchat\', \'file\')
          AND deleted_at IS NULL
        GROUP BY to_jid
     ) last_msg ON last_msg.to_jid = g.room_jid
     WHERE (g.id = :group_id OR g.room_jid = :jid)
       AND gm.emp_id = :emp_id
       AND g.is_archived = 0
     LIMIT 1'
);
$stmt->execute([
    ':group_id' => $groupId,
    ':jid' => $jid,
    ':emp_id' => (int)$session['emp_id'],
]);
$group = $stmt->fetch(PDO::FETCH_ASSOC);
if (!$group) chat_json(['status' => false, 'error' => 'Conversation not found'], 404);
$role = strtolower((string)$group['role']);
$canEdit = in_array($role, ['owner', 'admin'], true);
if (($_SERVER['REQUEST_METHOD'] ?? 'GET') === 'POST') {
    if (!$canEdit) chat_json(['status' => false, 'error' => 'Only owners/admins can edit wake-up configuration'], 403);
    $enabled = !empty($input['enabled']) ? 1 : 0;
    $minutes = max(60, min(129600, (int)($input['interval_minutes'] ?? 1440)));
    $update = $pdo->prepare(
        'UPDATE xmpp_groups
         SET wakeup_enabled = :enabled,
             wakeup_interval_minutes = :minutes,
             wakeup_updated_by_emp_id = :emp_id,
             wakeup_updated_at = NOW()
         WHERE id = :group_id'
    );
    $update->execute([
        ':enabled' => $enabled,
        ':minutes' => $minutes,
        ':emp_id' => (int)$session['emp_id'],
        ':group_id' => (int)$group['id'],
    ]);
    $group['wakeup_enabled'] = $enabled;
    $group['wakeup_interval_minutes'] = $minutes;
}
$lastActivity = new DateTimeImmutable((string)$group['last_activity_at']);
$intervalMinutes = max(60, (int)($group['wakeup_interval_minutes'] ?? 1440));
$enabled = (int)($group['wakeup_enabled'] ?? 0) === 1;
$remainingSeconds = $enabled ? wakeup_business_remaining_seconds($intervalMinutes, $lastActivity) : 0;
chat_json([
    'status' => true,
    'config' => [
        'group_id' => (int)$group['id'],
        'jid' => (string)$group['room_jid'],
        'type' => (string)$group['group_type'],
        'enabled' => $enabled,
        'interval_minutes' => $intervalMinutes,
        'interval_label' => wakeup_interval_label($intervalMinutes),
        'last_activity_at' => (string)$group['last_activity_at'],
        'last_sent_at' => (string)($group['wakeup_last_sent_at'] ?? ''),
        'remaining_seconds' => $remainingSeconds,
        'remaining_label' => sprintf('%dh %dm', intdiv($remainingSeconds, 3600), intdiv($remainingSeconds % 3600, 60)),
        'can_edit' => $canEdit,
    ],
]);



