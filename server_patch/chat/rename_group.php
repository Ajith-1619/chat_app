<?php
declare(strict_types=1);
require_once __DIR__ . '/bootstrap.php';

$session = chat_require_user();
$input = json_decode(file_get_contents('php://input') ?: '{}', true);
if (!is_array($input)) chat_json(['status' => false, 'error' => 'Invalid JSON'], 422);
$groupId = max(0, (int)($input['group_id'] ?? 0));
$name = trim((string)($input['name'] ?? ''));
if ($groupId <= 0 || $name === '' || mb_strlen($name) > 150) {
    chat_json(['status' => false, 'error' => 'Valid group name is required'], 422);
}
$pdo = chat_db();
chat_ensure_schema($pdo);
$stmt = $pdo->prepare(
    'SELECT g.room_jid FROM xmpp_groups g
     INNER JOIN xmpp_group_members gm ON gm.group_id = g.id
     WHERE g.id = :group_id AND gm.emp_id = :emp_id AND gm.role = \'owner\' LIMIT 1'
);
$stmt->execute([':group_id' => $groupId, ':emp_id' => (int)$session['emp_id']]);
$roomJid = (string)($stmt->fetchColumn() ?: '');
if ($roomJid === '') chat_json(['status' => false, 'error' => 'Only the owner can rename this group'], 403);
$update = $pdo->prepare('UPDATE xmpp_groups SET room_name = :name WHERE id = :group_id');
$update->execute([':name' => $name, ':group_id' => $groupId]);
try {
    chat_ejabberd_client()->request('change_room_option', [
        'name' => explode('@', $roomJid, 2)[0],
        'service' => SKYCHAT_MUC_DOMAIN,
        'option' => 'title',
        'value' => $name,
    ]);
} catch (Throwable $e) {
    error_log('Group title sync failed: ' . $e->getMessage());
}
chat_json(['status' => true, 'name' => $name]);
