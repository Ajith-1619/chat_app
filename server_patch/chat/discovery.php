<?php
declare(strict_types=1);
require_once __DIR__ . '/bootstrap.php';

$session = chat_require_user();
$pdo = chat_db();
chat_ensure_schema($pdo);
$empId = (int)$session['emp_id'];
$me = chat_jid($empId);
$view = strtolower(trim((string)($_GET['view'] ?? 'search')));
$jid = strtolower(trim((string)($_GET['jid'] ?? '')));
$query = trim((string)($_GET['q'] ?? ''));
$limit = max(10, min(100, (int)($_GET['limit'] ?? 60)));
$offset = max(0, min(5000, (int)($_GET['offset'] ?? 0)));
$sideLimit = max(10, min(50, (int)ceil($limit / 2)));

function discovery_message(array $row): array {
    $body = (string)($row['body'] ?? '');
    $fileUrl = (string)($row['file_url'] ?? '');
    $fileName = (string)($row['file_name'] ?? '');
    $fileType = (string)($row['file_type'] ?? '');
    $fileSize = (int)($row['file_size'] ?? 0);
    $caption = '';
    if (str_starts_with($body, 'SKYLINK_FILE:')) {
        $payload = json_decode(substr($body, strlen('SKYLINK_FILE:')), true);
        if (is_array($payload)) {
            if ($fileUrl === '') $fileUrl = trim((string)($payload['url'] ?? ''));
            if ($fileName === '') $fileName = trim((string)($payload['name'] ?? ''));
            if ($fileType === '') $fileType = trim((string)($payload['type'] ?? ''));
            if ($fileSize <= 0) $fileSize = (int)($payload['size'] ?? 0);
            $caption = trim((string)($payload['caption'] ?? ''));
        }
    }
    if (str_starts_with($body, 'SKYLINK_LOCATION:')) {
        $payload = json_decode(substr($body, strlen('SKYLINK_LOCATION:')), true);
        if (is_array($payload)) {
            $latitude = isset($payload['latitude']) && is_numeric($payload['latitude']) ? (float)$payload['latitude'] : null;
            $longitude = isset($payload['longitude']) && is_numeric($payload['longitude']) ? (float)$payload['longitude'] : null;
            $locationAddress = trim((string)($payload['location_address'] ?? ''));
            $caption = !empty($payload['is_live']) ? 'Live location' : 'Current location';
            if ($locationAddress !== '') {
                $caption .= ' - ' . $locationAddress;
            }
        }
    }
    return [
        'id' => (int)$row['id'],
        'from' => (string)$row['from_jid'],
        'to' => (string)$row['to_jid'],
        'body' => $body,
        'file_url' => $fileUrl,
        'file_name' => $fileName,
        'file_type' => $fileType,
        'file_size' => $fileSize,
        'caption' => $caption,
        'latitude' => $row['latitude'] === null ? null : (float)$row['latitude'],
        'longitude' => $row['longitude'] === null ? null : (float)$row['longitude'],
        'location_address' => (string)($row['location_address'] ?? ''),
        'message_type' => (string)($row['message_type'] ?? ''),
        'thread_root_id' => (string)($row['thread_root_id'] ?? ''),
        'created_at' => (string)$row['created_at'],
    ];
}
function discovery_enrich_messages(array $messages, int $empId, string $me): array {
    if (!$messages) return [];
    $pdo = chat_db();
    $employeePdo = null;
    try {
        $employeePdo = getEmployeeDB();
    } catch (Throwable $ignored) {
        $employeePdo = null;
    }
    $groupCache = [];
    $userCache = [];
    foreach ($messages as &$message) {
        $to = strtolower((string)($message['to'] ?? ''));
        $from = strtolower((string)($message['from'] ?? ''));
        $conversationJid = chat_is_room_jid($to) ? $to : ($from === strtolower($me) ? $to : $from);
        $message['conversation_jid'] = $conversationJid;
        $message['conversation_name'] = preg_replace('/@.*/', '', $conversationJid);
        $message['conversation_type'] = chat_is_room_jid($conversationJid) ? 'group' : 'chat';
        if (chat_is_room_jid($conversationJid)) {
            if (!array_key_exists($conversationJid, $groupCache)) {
                $stmt = $pdo->prepare('SELECT room_name, group_type FROM xmpp_groups WHERE room_jid = :jid LIMIT 1');
                $stmt->execute([':jid' => $conversationJid]);
                $groupCache[$conversationJid] = $stmt->fetch(PDO::FETCH_ASSOC) ?: [];
            }
            if ($groupCache[$conversationJid]) {
                $message['conversation_name'] = (string)($groupCache[$conversationJid]['room_name'] ?? $message['conversation_name']);
                $message['conversation_type'] = (string)($groupCache[$conversationJid]['group_type'] ?? 'group');
            }
        } elseif ($employeePdo && preg_match('/^(\d+)@chat\.skylinkonline\.net$/', $conversationJid, $match)) {
            $peerEmp = (int)$match[1];
            if (!array_key_exists($peerEmp, $userCache)) {
                $userCache[$peerEmp] = chat_employee_row($employeePdo, $peerEmp);
            }
            if ($userCache[$peerEmp]) {
                $message['conversation_name'] = (string)($userCache[$peerEmp]['name'] ?? $message['conversation_name']);
            }
        }
    }
    unset($message);
    return $messages;
}

if ($view === 'mentions') {
    $needle = json_encode($empId);
    $stmt = $pdo->prepare(
        "SELECT * FROM xmpp_messages
         WHERE deleted_at IS NULL AND from_jid <> :me
           AND mentions_json IS NOT NULL AND JSON_CONTAINS(mentions_json, :needle)
         ORDER BY id DESC LIMIT {$limit}"
    );
    $stmt->execute([':me' => $me, ':needle' => $needle]);
    chat_json(['status' => true, 'results' => array_map('discovery_message', $stmt->fetchAll(PDO::FETCH_ASSOC) ?: [])]);
}

if ($view === 'pins') {
    $stmt = $pdo->prepare(
        "SELECT m.* FROM xmpp_message_pins p
         INNER JOIN xmpp_messages m ON m.id = p.message_id
         WHERE p.conversation_jid = :jid AND m.deleted_at IS NULL
         ORDER BY p.pinned_at DESC LIMIT {$limit}"
    );
    $stmt->execute([':jid' => $jid]);
    chat_json(['status' => true, 'results' => array_map('discovery_message', $stmt->fetchAll(PDO::FETCH_ASSOC) ?: [])]);
}

if ($view === 'media') {
    if ($jid === '') chat_json(['status' => false, 'error' => 'Conversation JID is required'], 422);
    if (chat_is_room_jid($jid)) {
        if (!chat_group_for_member($pdo, $jid, $empId)) {
            chat_json(['status' => false, 'error' => 'Conversation is unavailable'], 403);
        }
        $stmt = $pdo->prepare(
            "SELECT * FROM xmpp_messages
             WHERE deleted_at IS NULL AND to_jid = :room
             ORDER BY id DESC LIMIT {$limit}"
        );
        $stmt->execute([':room' => $jid]);
    } else {
        $stmt = $pdo->prepare(
            "SELECT * FROM xmpp_messages
             WHERE deleted_at IS NULL AND (
               (to_jid = :jid_to AND from_jid = :me_from) OR
               (from_jid = :jid_from AND to_jid = :me_to)
             )
             ORDER BY id DESC LIMIT {$limit}"
        );
        $stmt->execute([
            ':jid_to' => $jid,
            ':me_from' => $me,
            ':jid_from' => $jid,
            ':me_to' => $me,
        ]);
    }
    chat_json([
        'status' => true,
        'results' => array_map('discovery_message', $stmt->fetchAll(PDO::FETCH_ASSOC) ?: []),
    ]);
}

$like = '%' . $query . '%';
$messages = [];
if ($query !== '') {
    $stmt = $pdo->prepare(
        "SELECT * FROM xmpp_messages
         WHERE deleted_at IS NULL
           AND (body LIKE :q_body OR file_name LIKE :q_file)
           AND (
                from_jid = :me_from OR to_jid = :me_to OR
                to_jid IN (
                    SELECT g.room_jid
                    FROM xmpp_groups g
                    INNER JOIN xmpp_group_members gm ON gm.group_id = g.id
                    WHERE gm.emp_id = :emp_id
                )
           )
         ORDER BY id DESC LIMIT {$limit} OFFSET {$offset}"
    );
    $stmt->execute([
        ':q_body' => $like,
        ':q_file' => $like,
        ':me_from' => $me,
        ':me_to' => $me,
        ':emp_id' => $empId,
    ]);
    $messages = discovery_enrich_messages(array_map('discovery_message', $stmt->fetchAll(PDO::FETCH_ASSOC) ?: []), $empId, $me);
}
$groups = [];
if ($query !== '') {
    $stmt = $pdo->prepare(
        "SELECT g.id, g.room_name AS name, g.room_jid AS jid, g.group_type AS type
         FROM xmpp_groups g
         INNER JOIN xmpp_group_members gm ON gm.group_id = g.id
         WHERE gm.emp_id = :emp_id AND g.room_name LIKE :q
         ORDER BY g.room_name LIMIT {$sideLimit}"
    );
    $stmt->execute([':q' => $like, ':emp_id' => $empId]);
    $groups = $stmt->fetchAll(PDO::FETCH_ASSOC) ?: [];
}
$users = [];
if ($query !== '') {
    try {
        $employeePdo = getEmployeeDB();
        $stmt = $employeePdo->prepare(
            "SELECT emp_id FROM employee
             WHERE status = 1
               AND (CAST(emp_id AS CHAR) LIKE :q_emp OR name LIKE :q_name OR designation LIKE :q_designation)
             ORDER BY name ASC LIMIT {$sideLimit}"
        );
        $stmt->execute([
            ':q_emp' => $like,
            ':q_name' => $like,
            ':q_designation' => $like,
        ]);
        foreach (($stmt->fetchAll(PDO::FETCH_COLUMN) ?: []) as $id) {
            $emp = (int)$id;
            if ($emp <= 0 || $emp === $empId) continue;
            $users[] = chat_user_payload($employeePdo, $emp, chat_jid($emp), false) + ['type' => 'chat'];
        }
    } catch (Throwable $e) {
        error_log('discovery user search skipped: ' . $e->getMessage());
    }
}
chat_json(['status' => true, 'messages' => $messages, 'conversations' => $groups, 'users' => $users, 'limit' => $limit, 'offset' => $offset, 'has_more_messages' => count($messages) >= $limit]);
