<?php
declare(strict_types=1);
require_once __DIR__ . '/bootstrap.php';

$session = chat_require_user();
$chatPdo = chat_db();
$employeePdo = getEmployeeDB();
chat_ensure_schema($chatPdo);
chat_require_group_channel_creator($chatPdo, $employeePdo, (int)$session['emp_id']);
$raw = file_get_contents('php://input') ?: '{}';
$in = json_decode($raw, true);
if (!is_array($in)) chat_json(['status' => false, 'error' => 'Invalid JSON'], 422);

$groupName = trim((string)($in['group_name'] ?? ''));
$members = array_values(array_unique(array_filter(array_map('intval', (array)($in['members'] ?? [])), static fn(int $id): bool => $id > 0)));
if ($groupName === '') chat_json(['status' => false, 'error' => 'Group name is required'], 422);
$members[] = (int)$session['emp_id'];
$members = array_values(array_unique($members));

$ph = implode(',', array_fill(0, count($members), '?'));
$check = $employeePdo->prepare("SELECT emp_id FROM employee WHERE status = 1 AND emp_id IN ({$ph})");
$check->execute($members);
$validMembers = array_map('intval', $check->fetchAll(PDO::FETCH_COLUMN) ?: []);
if (!$validMembers) chat_json(['status' => false, 'error' => 'No valid members found'], 422);

$slug = chat_slug($groupName) . '-' . substr(bin2hex(random_bytes(4)), 0, 8);
$roomJid = $slug . '@' . SKYCHAT_MUC_DOMAIN;
try {
    chat_ejabberd_client()->createRoom($slug, $groupName);
} catch (Throwable $e) {
    error_log('chat/create_group ejabberd room create failed: ' . $e->getMessage());
    chat_json(['status' => false, 'error' => 'Unable to create the group room'], 502);
}
$chatPdo->beginTransaction();
$stmt = $chatPdo->prepare(
    'INSERT INTO xmpp_groups (room_name, room_jid, created_by_emp_id)
     VALUES (:room_name, :room_jid, :created_by)
     ON DUPLICATE KEY UPDATE room_name = VALUES(room_name)'
);
$stmt->execute([':room_name' => $groupName, ':room_jid' => $roomJid, ':created_by' => (int)$session['emp_id']]);
$groupId = (int)$chatPdo->lastInsertId();
if ($groupId <= 0) {
    $find = $chatPdo->prepare('SELECT id FROM xmpp_groups WHERE room_jid = :room_jid LIMIT 1');
    $find->execute([':room_jid' => $roomJid]);
    $groupId = (int)($find->fetchColumn() ?: 0);
}

$memberStmt = $chatPdo->prepare(
    'INSERT INTO xmpp_group_members (group_id, emp_id, role)
     VALUES (:group_id, :emp_id, :role)
     ON DUPLICATE KEY UPDATE role = VALUES(role)'
);
foreach ($validMembers as $empId) {
    $memberStmt->execute([
        ':group_id' => $groupId,
        ':emp_id' => $empId,
        ':role' => $empId === (int)$session['emp_id'] ? 'owner' : 'member',
    ]);
    try {
        chat_ejabberd_client()->setRoomAffiliation(
            $slug,
            chat_jid($empId),
            $empId === (int)$session['emp_id'] ? 'owner' : 'member'
        );
        chat_ejabberd_client()->inviteToRoom($slug, chat_jid($empId), 'Skylink Messenger group invite');
    } catch (Throwable $e) {
        error_log('chat/create_group invite failed for ' . $empId . ': ' . $e->getMessage());
        $chatPdo->rollBack();
        chat_json(['status' => false, 'error' => 'Unable to add all selected members'], 502);
    }
}
$chatPdo->commit();

chat_json([
    'status' => true,
    'group_id' => $groupId,
    'room_name' => $groupName,
    'room_jid' => $roomJid,
    'members' => $validMembers,
]);
