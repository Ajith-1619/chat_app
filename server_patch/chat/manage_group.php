<?php
declare(strict_types=1);
require_once __DIR__ . '/bootstrap.php';

$session = chat_require_user();
$input = json_decode(file_get_contents('php://input') ?: '{}', true);
if (!is_array($input)) chat_json(['status' => false, 'error' => 'Invalid JSON'], 422);
$groupId = (int)($input['group_id'] ?? 0);
$empId = (int)($input['emp_id'] ?? 0);
$action = strtolower(trim((string)($input['action'] ?? '')));
$showHistory = filter_var($input['show_history'] ?? false, FILTER_VALIDATE_BOOLEAN);
if ($action === 'leave') $empId = (int)$session['emp_id'];
if ($groupId <= 0 || $empId <= 0 || !in_array($action, ['add', 'remove', 'promote', 'demote', 'leave'], true)) {
    chat_json(['status' => false, 'error' => 'Valid group, employee and action are required'], 422);
}

try {
    $pdo = chat_db();
    chat_ensure_schema($pdo);
    chat_ensure_column($pdo, 'xmpp_group_members', 'history_visible_from', 'DATETIME NULL AFTER joined_at');
    $owner = $pdo->prepare(
        'SELECT g.room_jid, gm.role
         FROM xmpp_groups g
         INNER JOIN xmpp_group_members gm ON gm.group_id = g.id
         WHERE g.id = :group_id AND gm.emp_id = :owner_id
         LIMIT 1'
    );
    $owner->execute([':group_id' => $groupId, ':owner_id' => (int)$session['emp_id']]);
    $ownerRow = $owner->fetch(PDO::FETCH_ASSOC) ?: [];
    $roomJid = (string)($ownerRow['room_jid'] ?? '');
    $currentRole = (string)($ownerRow['role'] ?? '');
    if ($roomJid === '') chat_json(['status' => false, 'error' => 'You are not a member of this group'], 403);
    $canManageMembers = in_array($currentRole, ['owner', 'admin'], true);
    if ($action !== 'leave' && !$canManageMembers) {
        chat_json(['status' => false, 'error' => 'Only a group owner or admin can manage members'], 403);
    }
    if (in_array($action, ['promote', 'demote'], true) && $currentRole !== 'owner') {
        chat_json(['status' => false, 'error' => 'Only the group owner can change admin roles'], 403);
    }
    if ($action === 'remove' && $currentRole === 'admin') {
        $targetRole = $pdo->prepare(
            'SELECT role FROM xmpp_group_members WHERE group_id = :group_id AND emp_id = :emp_id LIMIT 1'
        );
        $targetRole->execute([':group_id' => $groupId, ':emp_id' => $empId]);
        if ((string)($targetRole->fetchColumn() ?: '') !== 'member') {
            chat_json(['status' => false, 'error' => 'Admins can remove members only'], 403);
        }
    }
    if ($action === 'leave' && $currentRole === 'owner') {
        chat_json(['status' => false, 'error' => 'The owner cannot remove themselves'], 422);
    }
    $room = explode('@', $roomJid, 2)[0];
    if ($action === 'add') {
        $stmt = $pdo->prepare(
            "INSERT INTO xmpp_group_members (group_id, emp_id, role, history_visible_from)
             VALUES (:group_id, :emp_id, 'member', :history_visible_from)
             ON DUPLICATE KEY UPDATE
               role = IF(role IN ('owner', 'admin'), role, 'member'),
               history_visible_from = VALUES(history_visible_from)"
        );
        $stmt->execute([
            ':group_id' => $groupId,
            ':emp_id' => $empId,
            ':history_visible_from' => $showHistory ? null : date('Y-m-d H:i:s'),
        ]);
        $read = $pdo->prepare(
            'INSERT INTO xmpp_group_reads (group_id, emp_id, last_read_message_id, read_at)
             SELECT :group_id, :emp_id, COALESCE(MAX(id), 0), NOW()
             FROM xmpp_messages
             WHERE to_jid = :room_jid
             ON DUPLICATE KEY UPDATE
               last_read_message_id = VALUES(last_read_message_id),
               read_at = NOW()'
        );
        $read->execute([
            ':group_id' => $groupId,
            ':emp_id' => $empId,
            ':room_jid' => $roomJid,
        ]);
        chat_ejabberd_client()->setRoomAffiliation($room, chat_jid($empId), 'member');
        chat_ejabberd_client()->inviteToRoom($room, chat_jid($empId), 'Added to Skylink group');
    } elseif ($action === 'remove') {
        $stmt = $pdo->prepare(
            'DELETE FROM xmpp_group_members
             WHERE group_id = :group_id AND emp_id = :emp_id AND role <> \'owner\''
        );
        $stmt->execute([':group_id' => $groupId, ':emp_id' => $empId]);
        $deleteRead = $pdo->prepare(
            'DELETE FROM xmpp_group_reads WHERE group_id = :group_id AND emp_id = :emp_id'
        );
        $deleteRead->execute([':group_id' => $groupId, ':emp_id' => $empId]);
        chat_ejabberd_client()->setRoomAffiliation($room, chat_jid($empId), 'none');
    } elseif ($action === 'promote' || $action === 'demote') {
        $role = $action === 'promote' ? 'admin' : 'member';
        $stmt = $pdo->prepare(
            'UPDATE xmpp_group_members
             SET role = :role
             WHERE group_id = :group_id AND emp_id = :emp_id AND role <> \'owner\''
        );
        $stmt->execute([':role' => $role, ':group_id' => $groupId, ':emp_id' => $empId]);
        chat_ejabberd_client()->setRoomAffiliation($room, chat_jid($empId), $role === 'admin' ? 'admin' : 'member');
    } elseif ($action === 'leave') {
        $stmt = $pdo->prepare(
            'DELETE FROM xmpp_group_members
             WHERE group_id = :group_id AND emp_id = :emp_id AND role <> \'owner\''
        );
        $stmt->execute([':group_id' => $groupId, ':emp_id' => $empId]);
        $deleteRead = $pdo->prepare(
            'DELETE FROM xmpp_group_reads WHERE group_id = :group_id AND emp_id = :emp_id'
        );
        $deleteRead->execute([':group_id' => $groupId, ':emp_id' => $empId]);
        chat_ejabberd_client()->setRoomAffiliation($room, chat_jid($empId), 'none');
    }
    $employeePdo = getEmployeeDB();
    $actor = chat_user_payload(
        $employeePdo,
        (int)$session['emp_id'],
        chat_jid((int)$session['emp_id']),
        false
    );
    $member = chat_user_payload($employeePdo, $empId, chat_jid($empId), false);
    $systemBody = match ($action) {
        'add' => (string)$actor['name'] . ' added ' . (string)$member['name'] . ' to the conversation',
        'promote' => (string)$actor['name'] . ' promoted ' . (string)$member['name'] . ' to admin',
        'demote' => (string)$actor['name'] . ' changed ' . (string)$member['name'] . ' to member',
        'leave' => (string)$member['name'] . ' left the conversation',
        default => (string)$member['name'] . ' was removed by ' . (string)$actor['name'],
    };
    chat_ejabberd_client()->sendMessage(
        chat_jid((int)$session['emp_id']),
        $roomJid,
        $systemBody,
        'groupchat'
    );
    $system = $pdo->prepare(
        'INSERT INTO xmpp_messages
         (from_jid, to_jid, body, message_type, source_device, source_name, status)
         VALUES (:from, :to, :body, \'system\', \'server\', \'Membership\', \'sent\')'
    );
    $system->execute([
        ':from' => chat_jid((int)$session['emp_id']),
        ':to' => $roomJid,
        ':body' => $systemBody,
    ]);
    chat_json(['status' => true, 'action' => $action, 'emp_id' => $empId]);
} catch (Throwable $e) {
    error_log('chat/manage_group failed: ' . $e->getMessage());
    chat_json(['status' => false, 'error' => 'Unable to update group members'], 500);
}
