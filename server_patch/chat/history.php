<?php
declare(strict_types=1);
require_once __DIR__ . '/bootstrap.php';

$session = chat_require_user();
$traceId = trim((string)($_SERVER['HTTP_X_SKYLINK_TRACE_ID'] ?? 'history-' . bin2hex(random_bytes(8))));
$traceStarted = microtime(true);
$peer = trim((string)($_GET['jid'] ?? ''));
$peek = (string)($_GET['peek'] ?? '') === '1';
$readLatitude = isset($_GET['read_latitude']) && is_numeric($_GET['read_latitude']) ? (float)$_GET['read_latitude'] : null;
$readLongitude = isset($_GET['read_longitude']) && is_numeric($_GET['read_longitude']) ? (float)$_GET['read_longitude'] : null;
$readLocationAddress = mb_substr(trim((string)($_GET['read_location_address'] ?? '')), 0, 500);
if ($readLocationAddress === '' && $readLatitude !== null && $readLongitude !== null) {
    $readLocationAddress = chat_reverse_geocode_address($readLatitude, $readLongitude);
}
$readSourceDevice = strtolower(trim((string)($_GET['read_source_device'] ?? '')));
$readSourceName = trim((string)($_GET['read_source_name'] ?? ''));
if ($peer === '' || (!chat_is_user_jid($peer) && !chat_is_room_jid($peer))) {
    chat_json(['status' => false, 'error' => 'Valid peer JID is required'], 422);
}

$me = chat_jid((int)$session['emp_id']);
try {
    $pdo = chat_db();
    if (chat_is_room_jid($peer)) {
        $group = chat_group_for_member($pdo, $peer, (int)$session['emp_id']);
        if (!$group) {
            chat_json(['status' => false, 'error' => 'You are not a member of this group'], 403);
        }
        $employeePdo = getEmployeeDB();
        $stmt = $pdo->prepare(
            'SELECT *
             FROM (
                 SELECT id, from_jid, to_jid, body, file_url, file_name, file_type, file_size, latitude, longitude, location_address, message_type, reply_to_id,
                        thread_root_id, mentions_json, source_device, source_name, edited_at, status, created_at,
                        forwarded_from_message_id, original_sender_jid, original_sender_name, original_source_name
                 FROM xmpp_messages
                 WHERE to_jid = :room_jid
                   AND message_type IN (\'groupchat\', \'file\')
                   AND deleted_at IS NULL
                 ORDER BY created_at DESC, id DESC
                 LIMIT 200
             ) latest_messages
             ORDER BY created_at ASC, id ASC'
        );
        $stmt->execute([':room_jid' => strtolower($peer)]);
        $messages = [];
        $lastMessageId = 0;
        $senderCache = [];
        foreach (($stmt->fetchAll(PDO::FETCH_ASSOC) ?: []) as $row) {
            $lastMessageId = max($lastMessageId, (int)$row['id']);
            $senderName = '';
            if (preg_match('/^(\d+)@chat\.skylinkonline\.net$/i', (string)$row['from_jid'], $match)) {
                $senderId = (int)$match[1];
                if (!isset($senderCache[$senderId])) {
                    $senderCache[$senderId] = chat_employee_row($employeePdo, $senderId);
                }
                $senderName = (string)($senderCache[$senderId]['name'] ?? ('EMP-' . $senderId));
            }
            $messages[] = [
                'id' => (int)$row['id'],
                'from' => (string)$row['from_jid'],
                'to' => (string)$row['to_jid'],
                'body' => (string)$row['body'],
                'file_url' => (string)($row['file_url'] ?? ''),
                'file_name' => (string)($row['file_name'] ?? ''),
                'file_type' => (string)($row['file_type'] ?? ''),
                'file_size' => (int)($row['file_size'] ?? 0),
                'latitude' => $row['latitude'] === null ? null : (float)$row['latitude'],
                'longitude' => $row['longitude'] === null ? null : (float)$row['longitude'],
                'location_address' => (string)($row['location_address'] ?? ''),
                'message_type' => (string)$row['message_type'],
                'reply_to_id' => (int)($row['reply_to_id'] ?? 0),
                'thread_root_id' => (int)($row['thread_root_id'] ?? 0),
                'mentions' => json_decode((string)($row['mentions_json'] ?? '[]'), true) ?: [],
                'source_device' => (string)($row['source_device'] ?? 'unknown'),
                'source_name' => (string)($row['source_name'] ?? ''),
                'edited_at' => (string)($row['edited_at'] ?? ''),
                'read_at' => '',
                'forwarded_from_message_id' => (string)($row['forwarded_from_message_id'] ?? ''),
                'original_sender_jid' => (string)($row['original_sender_jid'] ?? ''),
                'original_sender_name' => (string)($row['original_sender_name'] ?? ''),
                'original_source_name' => (string)($row['original_source_name'] ?? ''),
                'sender_name' => $senderName,
                'side' => (string)$row['from_jid'] === $me ? 'me' : 'them',
                'status' => (string)$row['status'],
                'created_at' => (string)$row['created_at'],
                'time' => date('H:i', strtotime((string)$row['created_at']) ?: time()),
            ];
        }
        if (!$peek) {
            $read = $pdo->prepare(
                'INSERT INTO xmpp_group_reads
                 (group_id, emp_id, last_read_message_id, read_at, read_latitude, read_longitude, read_location_address, read_source_device, read_source_name)
                 VALUES (:group_id, :emp_id, :last_id, NOW(), :read_latitude, :read_longitude, :read_location_address, :read_source_device, :read_source_name)
                 ON DUPLICATE KEY UPDATE
                   last_read_message_id = GREATEST(last_read_message_id, VALUES(last_read_message_id)),
                   read_at = NOW(),
                   read_latitude = COALESCE(VALUES(read_latitude), read_latitude),
                   read_longitude = COALESCE(VALUES(read_longitude), read_longitude),
                   read_location_address = COALESCE(NULLIF(VALUES(read_location_address), \'\'), read_location_address),
                   read_source_device = COALESCE(NULLIF(VALUES(read_source_device), \'\'), read_source_device),
                   read_source_name = COALESCE(NULLIF(VALUES(read_source_name), \'\'), read_source_name)'
            );
            $read->execute([
                ':group_id' => (int)$group['id'],
                ':emp_id' => (int)$session['emp_id'],
                ':last_id' => $lastMessageId,
                ':read_latitude' => $readLatitude,
                ':read_longitude' => $readLongitude,
                ':read_location_address' => $readLocationAddress !== '' ? $readLocationAddress : null,
                ':read_source_device' => $readSourceDevice,
                ':read_source_name' => $readSourceName,
            ]);
        }
        chat_json([
            'status' => true,
            'group' => [
                'id' => (int)$group['id'],
                'name' => (string)$group['room_name'],
                'jid' => (string)$group['room_jid'],
            ],
            'messages' => $messages,
        ]);
    }
    if (!$peek) {
        $mark = $pdo->prepare(
            'UPDATE xmpp_messages
             SET status = :status,
                 read_at = COALESCE(read_at, NOW()),
                 read_latitude = COALESCE(read_latitude, :read_latitude),
                 read_longitude = COALESCE(read_longitude, :read_longitude),
                 read_location_address = COALESCE(NULLIF(read_location_address, \'\'), :read_location_address),
                 read_source_device = COALESCE(NULLIF(read_source_device, \'\'), :read_source_device),
                 read_source_name = COALESCE(NULLIF(read_source_name, \'\'), :read_source_name)
             WHERE from_jid = :peer AND to_jid = :me AND read_at IS NULL'
        );
        $mark->execute([
            ':status' => 'read',
            ':peer' => $peer,
            ':me' => $me,
            ':read_latitude' => $readLatitude,
            ':read_longitude' => $readLongitude,
            ':read_location_address' => $readLocationAddress !== '' ? $readLocationAddress : null,
            ':read_source_device' => $readSourceDevice,
            ':read_source_name' => $readSourceName,
        ]);
    }
    $stmt = $pdo->prepare(
        'SELECT *
         FROM (
             SELECT id, from_jid, to_jid, body, file_url, file_name, file_type, file_size, latitude, longitude, location_address, message_type, reply_to_id,
                    thread_root_id, mentions_json, source_device, source_name, edited_at, status, read_at, created_at,
                    forwarded_from_message_id, original_sender_jid, original_sender_name, original_source_name
             FROM xmpp_messages
             WHERE (
                  (from_jid = :me_from AND to_jid = :peer_to)
                  OR (from_jid = :peer_from AND to_jid = :me_to)
             )
               AND deleted_at IS NULL
             ORDER BY created_at DESC, id DESC
             LIMIT 200
         ) latest_messages
         ORDER BY created_at ASC, id ASC'
    );
    $stmt->execute([
        ':me_from' => $me,
        ':peer_to' => $peer,
        ':peer_from' => $peer,
        ':me_to' => $me,
    ]);
    $messages = [];
    foreach (($stmt->fetchAll(PDO::FETCH_ASSOC) ?: []) as $row) {
        $messages[] = [
            'id' => (int)$row['id'],
            'from' => (string)$row['from_jid'],
            'to' => (string)$row['to_jid'],
            'body' => (string)$row['body'],
            'file_url' => (string)($row['file_url'] ?? ''),
            'file_name' => (string)($row['file_name'] ?? ''),
            'file_type' => (string)($row['file_type'] ?? ''),
            'file_size' => (int)($row['file_size'] ?? 0),
            'latitude' => $row['latitude'] === null ? null : (float)$row['latitude'],
            'longitude' => $row['longitude'] === null ? null : (float)$row['longitude'],
            'location_address' => (string)($row['location_address'] ?? ''),
            'message_type' => (string)($row['message_type'] ?? 'chat'),
            'reply_to_id' => (int)($row['reply_to_id'] ?? 0),
            'thread_root_id' => (int)($row['thread_root_id'] ?? 0),
            'mentions' => json_decode((string)($row['mentions_json'] ?? '[]'), true) ?: [],
            'source_device' => (string)($row['source_device'] ?? 'unknown'),
            'source_name' => (string)($row['source_name'] ?? ''),
            'edited_at' => (string)($row['edited_at'] ?? ''),
            'read_at' => (string)($row['read_at'] ?? ''),
            'forwarded_from_message_id' => (string)($row['forwarded_from_message_id'] ?? ''),
            'original_sender_jid' => (string)($row['original_sender_jid'] ?? ''),
            'original_sender_name' => (string)($row['original_sender_name'] ?? ''),
            'original_source_name' => (string)($row['original_source_name'] ?? ''),
            'side' => (string)$row['from_jid'] === $me ? 'me' : 'them',
            'status' => (string)$row['status'],
            'is_read' => !empty($row['read_at']),
            'read_at' => (string)($row['read_at'] ?? ''),
            'created_at' => (string)$row['created_at'],
            'time' => date('H:i', strtotime((string)$row['created_at']) ?: time()),
        ];
    }
    chat_diagnostic_trace((int)$session['emp_id'], $traceId, 'database', 'message_history', (microtime(true) - $traceStarted) * 1000, 'success', ['count' => count($messages), 'peer_type' => chat_is_room_jid($peer) ? 'group' : 'dm']);
    chat_json(['status' => true, 'messages' => $messages]);
} catch (Throwable $e) {
    chat_diagnostic_trace((int)$session['emp_id'], $traceId, 'database', 'message_history', (microtime(true) - $traceStarted) * 1000, 'error');
    error_log('chat/history failed: ' . $e->getMessage());
    chat_json(['status' => false, 'error' => 'Unable to load chat history'], 500);
}
