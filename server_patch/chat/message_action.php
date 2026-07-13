<?php
declare(strict_types=1);
require_once __DIR__ . '/bootstrap.php';

$session = chat_require_user();
$pdo = chat_db();
chat_ensure_schema($pdo);
$empId = (int)$session['emp_id'];

if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    $messageId = max(0, (int)($_GET['message_id'] ?? 0));
    $stmt = $pdo->prepare(
        'SELECT id, from_jid, to_jid, status, created_at, read_at, edited_at,
                latitude, longitude, location_address, read_latitude, read_longitude, read_location_address,
                source_device, source_name, read_source_device, read_source_name
         FROM xmpp_messages WHERE id = :id AND deleted_at IS NULL LIMIT 1'
    );
    $stmt->execute([':id' => $messageId]);
    $message = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!$message) chat_json(['status' => false, 'error' => 'Message not found'], 404);

    $messageReadLatitude = $message['read_latitude'] === null ? null : (float)$message['read_latitude'];
    $messageReadLongitude = $message['read_longitude'] === null ? null : (float)$message['read_longitude'];
    $messageReadLocationAddress = (string)($message['read_location_address'] ?? '');
    if ($messageReadLocationAddress === '' && $messageReadLatitude !== null && $messageReadLongitude !== null) {
        $messageReadLocationAddress = chat_reverse_geocode_address($messageReadLatitude, $messageReadLongitude);
    }
    $message['read_location_address'] = $messageReadLocationAddress;

    $reactionStmt = $pdo->prepare(
        'SELECT reaction, COUNT(*) AS count
         FROM xmpp_message_reactions WHERE message_id = :id GROUP BY reaction'
    );
    $reactionStmt->execute([':id' => $messageId]);

    $starStmt = $pdo->prepare(
        'SELECT 1 FROM xmpp_message_stars WHERE message_id = :id AND emp_id = :emp_id'
    );
    $starStmt->execute([':id' => $messageId, ':emp_id' => $empId]);

    $pinStmt = $pdo->prepare(
        'SELECT 1 FROM xmpp_message_pins WHERE message_id = :id LIMIT 1'
    );
    $pinStmt->execute([':id' => $messageId]);

    $readers = [];
    $pendingReaders = [];
    if (chat_is_room_jid((string)$message['to_jid'])) {
        $readerStmt = $pdo->prepare(
            'SELECT gm.emp_id, gm.role, gr.last_read_message_id, gr.read_at,
                    gr.read_latitude, gr.read_longitude, gr.read_location_address, gr.read_source_device, gr.read_source_name
             FROM xmpp_groups g
             INNER JOIN xmpp_group_members gm ON gm.group_id = g.id
             LEFT JOIN xmpp_group_reads gr
               ON gr.group_id = g.id AND gr.emp_id = gm.emp_id
             WHERE g.room_jid = :room_jid
             ORDER BY gm.role = \'owner\' DESC, gm.emp_id'
        );
        $readerStmt->execute([':room_jid' => (string)$message['to_jid']]);
        $employeePdo = getEmployeeDB();
        foreach (($readerStmt->fetchAll(PDO::FETCH_ASSOC) ?: []) as $reader) {
            $readerEmp = (int)$reader['emp_id'];
            $profile = chat_user_payload($employeePdo, $readerEmp, chat_jid($readerEmp), false);
            $readLatitude = $reader['read_latitude'] === null ? null : (float)$reader['read_latitude'];
            $readLongitude = $reader['read_longitude'] === null ? null : (float)$reader['read_longitude'];
            $readLocationAddress = (string)($reader['read_location_address'] ?? '');
            if ($readLocationAddress === '' && $readLatitude !== null && $readLongitude !== null) {
                $readLocationAddress = chat_reverse_geocode_address($readLatitude, $readLongitude);
            }
            $detail = [
                'emp_id' => (string)$readerEmp,
                'name' => (string)($profile['name'] ?? $readerEmp),
                'avatar_url' => (string)($profile['avatar_url'] ?? ''),
                'read_at' => (string)($reader['read_at'] ?? ''),
                'read_latitude' => $readLatitude,
                'read_longitude' => $readLongitude,
                'read_location_address' => $readLocationAddress,
                'read_source_device' => (string)($reader['read_source_device'] ?? ''),
                'read_source_name' => (string)($reader['read_source_name'] ?? ''),
            ];
            if ((int)($reader['last_read_message_id'] ?? 0) >= $messageId) {
                $readers[] = $detail;
            } else {
                $pendingReaders[] = $detail;
            }
        }
    }

    chat_json([
        'status' => true,
        'message' => $message,
        'reactions' => $reactionStmt->fetchAll(PDO::FETCH_ASSOC) ?: [],
        'starred' => (bool)$starStmt->fetchColumn(),
        'pinned' => (bool)$pinStmt->fetchColumn(),
        'readers' => $readers,
        'pending_readers' => $pendingReaders,
    ]);
}

$input = json_decode(file_get_contents('php://input') ?: '{}', true);
if (!is_array($input)) chat_json(['status' => false, 'error' => 'Invalid JSON'], 422);
$messageId = max(0, (int)($input['message_id'] ?? 0));
$action = strtolower(trim((string)($input['action'] ?? '')));
if ($messageId <= 0) chat_json(['status' => false, 'error' => 'Message is required'], 422);
$exists = $pdo->prepare('SELECT 1 FROM xmpp_messages WHERE id = :id AND deleted_at IS NULL');
$exists->execute([':id' => $messageId]);
if (!$exists->fetchColumn()) chat_json(['status' => false, 'error' => 'Message not found'], 404);

if ($action === 'reaction') {
    $reaction = trim((string)($input['reaction'] ?? ''));
    if ($reaction === '') {
        $stmt = $pdo->prepare(
            'DELETE FROM xmpp_message_reactions WHERE message_id = :id AND emp_id = :emp_id'
        );
        $stmt->execute([':id' => $messageId, ':emp_id' => $empId]);
    } else {
        $allowed = json_decode('["\uD83D\uDC4D","\u2764\uFE0F","\uD83D\uDE02","\uD83D\uDE2E","\uD83D\uDE22","\uD83D\uDD25","\uD83D\uDC4F","\uD83C\uDF89","\uD83D\uDE4F"]', true) ?: [];
        if (!in_array($reaction, $allowed, true)) {
            chat_json(['status' => false, 'error' => 'Unsupported reaction'], 422);
        }
        $stmt = $pdo->prepare(
            'INSERT INTO xmpp_message_reactions (message_id, emp_id, reaction)
             VALUES (:id, :emp_id, :reaction)
             ON DUPLICATE KEY UPDATE reaction = VALUES(reaction), created_at = NOW()'
        );
        $stmt->execute([':id' => $messageId, ':emp_id' => $empId, ':reaction' => $reaction]);
    }
} elseif ($action === 'star') {
    $starred = (bool)($input['starred'] ?? true);
    if ($starred) {
        $stmt = $pdo->prepare(
            'INSERT IGNORE INTO xmpp_message_stars (message_id, emp_id) VALUES (:id, :emp_id)'
        );
    } else {
        $stmt = $pdo->prepare(
            'DELETE FROM xmpp_message_stars WHERE message_id = :id AND emp_id = :emp_id'
        );
    }
    $stmt->execute([':id' => $messageId, ':emp_id' => $empId]);
} elseif ($action === 'pin') {
    $pinned = (bool)($input['pinned'] ?? true);
    if ($pinned) {
        $stmt = $pdo->prepare(
            'INSERT IGNORE INTO xmpp_message_pins (message_id, emp_id) VALUES (:id, :emp_id)'
        );
    } else {
        $stmt = $pdo->prepare(
            'DELETE FROM xmpp_message_pins WHERE message_id = :id AND emp_id = :emp_id'
        );
    }
    $stmt->execute([':id' => $messageId, ':emp_id' => $empId]);
} else {
    chat_json(['status' => false, 'error' => 'Unsupported action'], 422);
}

chat_json(['status' => true]);
