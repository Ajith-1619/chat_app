<?php
declare(strict_types=1);
require_once __DIR__ . '/bootstrap.php';

$session = chat_require_user();
$traceId = trim((string)($_SERVER['HTTP_X_SKYLINK_TRACE_ID'] ?? 'message-' . bin2hex(random_bytes(8))));
$requestStarted = microtime(true);
$raw = file_get_contents('php://input') ?: '{}';
$input = json_decode($raw, true);
if (!is_array($input)) {
    chat_json(['status' => false, 'error' => 'Invalid JSON'], 422);
}

$to = trim((string)($input['to'] ?? ''));
$body = trim((string)($input['message'] ?? ''));
$fileUrl = trim((string)($input['file_url'] ?? ''));
$fileName = trim((string)($input['file_name'] ?? ''));
$fileType = mb_substr(trim((string)($input['file_type'] ?? '')), 0, 255);
$fileSize = max(0, (int)($input['file_size'] ?? 0));
$latitude = isset($input['latitude']) && is_numeric($input['latitude']) ? (float)$input['latitude'] : null;
$longitude = isset($input['longitude']) && is_numeric($input['longitude']) ? (float)$input['longitude'] : null;
$locationAddress = mb_substr(trim((string)($input['location_address'] ?? '')), 0, 500);
$replyToId = max(0, (int)($input['reply_to_id'] ?? 0));
$mentions = array_values(array_unique(array_filter(
    array_map(
        static function(mixed $value): int|string {
            $text = strtolower(trim((string)$value));
            if (in_array($text, ['@channel', '@online', '@admins'], true)) return $text;
            return (int)$value;
        },
        (array)($input['mentions'] ?? [])
    ),
    static fn(int|string $value): bool => is_string($value) || $value > 0
)));
$threadRootId = max(0, (int)($input['thread_root_id'] ?? 0));
$silent = !empty($input['silent']);
$visibilityMode = strtolower(trim((string)($input['visibility_mode'] ?? 'all')));
if (!in_array($visibilityMode, ['all', 'selected'], true)) $visibilityMode = 'all';
$selectedRecipientIds = array_values(array_unique(array_filter(
    array_map('intval', (array)($input['recipient_emp_ids'] ?? [])),
    static fn(int $value): bool => $value > 0
)));
$clientMessageId = mb_substr(trim((string)($input['client_message_id'] ?? '')), 0, 80);
$forwardedFromMessageId = max(0, (int)($input['forwarded_from_message_id'] ?? 0));
$originalSenderJid = mb_substr(trim((string)($input['original_sender_jid'] ?? '')), 0, 255);
$originalSenderName = mb_substr(trim((string)($input['original_sender_name'] ?? '')), 0, 255);
$originalSourceName = mb_substr(trim((string)($input['original_source_name'] ?? '')), 0, 160);
$sourceDevice = strtolower(trim((string)($input['source_device'] ?? 'unknown')));
$sourceName = trim((string)($input['source_name'] ?? ''));
if (!in_array($sourceDevice, ['mobile', 'desktop', 'web', 'launchpad', 'linux', 'windows', 'android', 'ios'], true)) {
    $sourceDevice = 'unknown';
}
if ($to === '' || (!chat_is_user_jid($to) && !chat_is_room_jid($to))) {
    chat_json(['status' => false, 'error' => 'Invalid receiver'], 422);
}
if ($body === '' && $fileUrl === '') {
    chat_json(['status' => false, 'error' => 'Message is required'], 422);
}
if (mb_strlen($body) > 4000) {
    chat_json(['status' => false, 'error' => 'Message is too long'], 422);
}

$from = chat_jid((int)$session['emp_id']);
try {
    $pdo = chat_db();
    chat_ensure_schema($pdo);
    if ($clientMessageId !== '') {
        $duplicate = $pdo->prepare(
            'SELECT id FROM xmpp_messages
             WHERE from_jid = :from_jid AND client_message_id = :client_id LIMIT 1'
        );
        $duplicate->execute([':from_jid' => $from, ':client_id' => $clientMessageId]);
        $existingId = (int)($duplicate->fetchColumn() ?: 0);
        if ($existingId > 0) {
            chat_json(['status' => true, 'message_id' => $existingId, 'duplicate' => true]);
        }
    }
    $isGroup = chat_is_room_jid($to);
    $group = [];
    if ($isGroup) {
        $group = chat_group_for_member($pdo, $to, (int)$session['emp_id']);
        if (!$group) {
            chat_json(['status' => false, 'error' => 'You are not a member of this group'], 403);
        }
    } elseif ($visibilityMode === 'selected') {
        chat_json(['status' => false, 'error' => 'Selected recipients are available only in groups and channels'], 422);
    }
    if ($visibilityMode === 'selected') {
        if ($fileUrl !== '') {
            chat_json(['status' => false, 'error' => 'Selected recipients are supported for text messages only'], 422);
        }
        if (!$selectedRecipientIds) {
            chat_json(['status' => false, 'error' => 'Select at least one recipient'], 422);
        }
        $memberStmt = $pdo->prepare(
            'SELECT gm.emp_id
             FROM xmpp_group_members gm
             INNER JOIN xmpp_groups g ON g.id = gm.group_id
             WHERE g.room_jid = :room_jid'
        );
        $memberStmt->execute([':room_jid' => strtolower($to)]);
        $memberIds = array_values(array_unique(array_map('intval', $memberStmt->fetchAll(PDO::FETCH_COLUMN) ?: [])));
        $allowed = array_flip($memberIds);
        foreach ($selectedRecipientIds as $recipientId) {
            if (!isset($allowed[$recipientId])) {
                chat_json(['status' => false, 'error' => 'Selected recipients must be group members'], 422);
            }
        }
        $selectedRecipientIds[] = (int)$session['emp_id'];
        $selectedRecipientIds = array_values(array_unique(array_filter($selectedRecipientIds, static fn(int $id): bool => $id > 0)));
    }
    if ($locationAddress === '' && $latitude !== null && $longitude !== null) {
        $locationAddress = chat_reverse_geocode_address($latitude, $longitude);
    }
    if ($isGroup && array_filter($mentions, 'is_string')) {
        $memberStmt = $pdo->prepare(
            'SELECT gm.emp_id, gm.role
             FROM xmpp_group_members gm
             INNER JOIN xmpp_groups g ON g.id = gm.group_id
             WHERE g.room_jid = :room_jid AND gm.emp_id <> :sender'
        );
        $memberStmt->execute([
            ':room_jid' => strtolower($to),
            ':sender' => (int)$session['emp_id'],
        ]);
        $members = $memberStmt->fetchAll(PDO::FETCH_ASSOC) ?: [];
        foreach ($members as $member) {
            $memberId = (int)$member['emp_id'];
            if (in_array('@channel', $mentions, true) ||
                (in_array('@admins', $mentions, true) &&
                    in_array((string)$member['role'], ['owner', 'admin'], true)) ||
                (in_array('@online', $mentions, true) &&
                    chat_ejabberd_is_online(chat_jid($memberId)))) {
                $mentions[] = $memberId;
            }
        }
        $mentions = array_values(array_unique(array_filter(
            $mentions,
            static fn(int|string $value): bool => is_int($value) && $value > 0
        )));
    }
    if ($replyToId > 0) {
        $replyCheck = $pdo->prepare(
            'SELECT 1 FROM xmpp_messages
             WHERE id = :id AND deleted_at IS NULL
               AND (
                 (to_jid = :target)
                 OR (from_jid = :me AND to_jid = :target_direct)
                 OR (from_jid = :target_peer AND to_jid = :me_direct)
               )
               AND (COALESCE(visibility_mode, \'all\') <> \'selected\' OR from_jid = :me_visibility OR EXISTS (SELECT 1 FROM xmpp_message_recipients vmr WHERE vmr.message_id = xmpp_messages.id AND vmr.emp_id = :visibility_emp_id))
             LIMIT 1'
        );
        $replyCheck->execute([
            ':id' => $replyToId,
            ':target' => strtolower($to),
            ':me' => $from,
            ':target_direct' => strtolower($to),
            ':target_peer' => strtolower($to),
            ':me_direct' => $from,
            ':me_visibility' => $from,
            ':visibility_emp_id' => (int)$session['emp_id'],
        ]);
        if (!$replyCheck->fetchColumn()) {
            chat_json(['status' => false, 'error' => 'Reply message is unavailable'], 422);
        }
    }
    $messageBody = $fileUrl !== '' ? trim($body . "\n" . $fileUrl) : $body;
    $xmppStarted = microtime(true);
    $result = null;
    $xmppDelivered = false;
    try {
        if ($isGroup && $visibilityMode === 'selected') {
            $result = ['selected_visibility' => true, 'recipients' => count($selectedRecipientIds)];
            chat_diagnostic_trace((int)$session['emp_id'], $traceId, 'xmpp', 'send_message_selected_skip_room_broadcast', (microtime(true) - $xmppStarted) * 1000, 'success', ['type' => 'group', 'recipients' => count($selectedRecipientIds)]);
        } else {
            $result = chat_ejabberd_client()->sendMessage(
                $from,
                strtolower($to),
                $messageBody,
                $isGroup ? 'groupchat' : 'chat'
            );
            $xmppDelivered = true;
            chat_diagnostic_trace((int)$session['emp_id'], $traceId, 'xmpp', 'send_message', (microtime(true) - $xmppStarted) * 1000, 'success', ['type' => $isGroup ? 'group' : 'dm']);
        }
    } catch (Throwable $xmppError) {
        chat_diagnostic_trace((int)$session['emp_id'], $traceId, 'xmpp', 'send_message', (microtime(true) - $xmppStarted) * 1000, 'error', ['type' => $isGroup ? 'group' : 'dm']);
        error_log('chat/send_message xmpp delivery skipped: ' . $xmppError->getMessage());
    }
    $dbStarted = microtime(true);
    $insertColumns = [
        'from_jid', 'to_jid', 'body', 'file_url', 'file_name', 'file_type',
        'file_size', 'latitude', 'longitude', 'location_address',
        'client_message_id', 'forwarded_from_message_id', 'original_sender_jid',
        'original_sender_name', 'original_source_name', 'message_type',
        'reply_to_id', 'thread_root_id', 'mentions_json', 'source_device',
        'source_name', 'visibility_mode', 'status',
    ];
    $insertValues = [
        ':from_jid' => $from,
        ':to_jid' => $to,
        ':body' => $body,
        ':file_url' => $fileUrl !== '' ? $fileUrl : null,
        ':file_name' => $fileName !== '' ? $fileName : null,
        ':file_type' => $fileType !== '' ? $fileType : null,
        ':file_size' => $fileSize,
        ':latitude' => $latitude,
        ':longitude' => $longitude,
        ':location_address' => $locationAddress !== '' ? $locationAddress : null,
        ':client_message_id' => $clientMessageId !== '' ? $clientMessageId : null,
        ':forwarded_from_message_id' => $forwardedFromMessageId > 0 ? $forwardedFromMessageId : null,
        ':original_sender_jid' => $originalSenderJid !== '' ? $originalSenderJid : null,
        ':original_sender_name' => $originalSenderName !== '' ? $originalSenderName : null,
        ':original_source_name' => $originalSourceName !== '' ? $originalSourceName : null,
        ':message_type' => $fileUrl !== '' ? 'file' : ($isGroup ? 'groupchat' : 'chat'),
        ':reply_to_id' => $replyToId > 0 ? $replyToId : null,
        ':thread_root_id' => $threadRootId > 0 ? $threadRootId : null,
        ':mentions_json' => $mentions ? json_encode($mentions) : null,
        ':source_device' => $sourceDevice,
        ':source_name' => $sourceName !== '' ? mb_substr($sourceName, 0, 120) : null,
        ':visibility_mode' => $visibilityMode,
        ':status' => 'sent',
    ];
    $runInsert = static function() use ($pdo, $insertColumns, $insertValues): void {
        $columnsSql = implode(', ', $insertColumns);
        $placeholderSql = implode(', ', array_map(static fn(string $column): string => ':' . $column, $insertColumns));
        $stmt = $pdo->prepare("INSERT INTO xmpp_messages ({$columnsSql}) VALUES ({$placeholderSql})");
        $stmt->execute($insertValues);
    };
    try {
        $runInsert();
    } catch (PDOException $insertError) {
        $insertMessage = $insertError->getMessage();
        if (stripos($insertMessage, 'location_address') !== false) {
            chat_ensure_column($pdo, 'xmpp_messages', 'location_address', 'VARCHAR(500) NULL AFTER longitude');
            $runInsert();
        } elseif (stripos($insertMessage, 'file_type') !== false) {
            $pdo->exec('ALTER TABLE xmpp_messages MODIFY file_type VARCHAR(255) NULL');
            $runInsert();
        } else {
            throw $insertError;
        }
    }
    chat_diagnostic_trace((int)$session['emp_id'], $traceId, 'database', 'persist_message', (microtime(true) - $dbStarted) * 1000, 'success', ['file_size' => $fileSize]);
    $messageId = (int)($pdo->lastInsertId() ?: 0);
    if ($visibilityMode === 'selected' && $messageId > 0) {
        $recipientStmt = $pdo->prepare(
            'INSERT IGNORE INTO xmpp_message_recipients (message_id, emp_id) VALUES (:message_id, :emp_id)'
        );
        foreach ($selectedRecipientIds as $recipientId) {
            $recipientStmt->execute([':message_id' => $messageId, ':emp_id' => $recipientId]);
        }
    }
    $responsePayload = [
        'status' => true,
        'from' => $from,
        'to' => $to,
        'message_id' => $messageId,
        'sent_at' => date('c'),
        'server_result' => $result ?? null,
        'xmpp_delivered' => $xmppDelivered,
        'visibility_mode' => $visibilityMode,
    ];
    $responseFinished = false;
    if (function_exists('fastcgi_finish_request')) {
        chat_diagnostic_trace((int)$session['emp_id'], $traceId, 'api', 'send_message_total', (microtime(true) - $requestStarted) * 1000, 'success');
        http_response_code(200);
        header('Content-Type: application/json; charset=utf-8');
        header('Connection: close');
        echo json_encode($responsePayload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        fastcgi_finish_request();
        $responseFinished = true;
    }
    try {
        $pushStarted = microtime(true);
        if (!$silent) {
            $employeePdo = getEmployeeDB();
            $sender = chat_user_payload($employeePdo, (int)$session['emp_id'], $from, false);
            $groupName = '';
            if ($isGroup) {
                $groupName = (string)($group['room_name'] ?? '');
            }
            $pushJobId = chat_enqueue_push_notification(
                $pdo,
                (int)$session['emp_id'],
                (string)$sender['name'],
                strtolower($to),
                $body,
                $fileName,
                $groupName,
                array_values(array_filter($mentions, 'is_int')),
                $visibilityMode === 'selected' ? $selectedRecipientIds : []
            );
            chat_spawn_push_worker();
        }
        chat_diagnostic_trace((int)$session['emp_id'], $traceId, 'notification', $silent ? 'dispatch_push_silent_skip' : 'dispatch_push_queued', (microtime(true) - $pushStarted) * 1000, 'success', ['job_id' => $pushJobId ?? 0]);
    } catch (Throwable $pushError) {
        chat_diagnostic_trace((int)$session['emp_id'], $traceId, 'notification', 'dispatch_push_queued', (microtime(true) - $pushStarted) * 1000, 'error');
        error_log('chat/send_message push queue skipped: ' . $pushError->getMessage());
    }
    if ($responseFinished) exit;
} catch (Throwable $e) {
    chat_diagnostic_trace((int)$session['emp_id'], $traceId, 'api', 'send_message_total', (microtime(true) - $requestStarted) * 1000, 'error');
    error_log('chat/send_message failed: ' . $e->getMessage());
    chat_json(['status' => false, 'error' => 'Unable to send message through chat server: ' . $e->getMessage()], 502);
}

chat_diagnostic_trace((int)$session['emp_id'], $traceId, 'api', 'send_message_total', (microtime(true) - $requestStarted) * 1000, 'success');
chat_json([
    'status' => true,
    'from' => $from,
    'to' => $to,
    'message_id' => $messageId ?? (int)($pdo->lastInsertId() ?: 0),
    'sent_at' => date('c'),
    'server_result' => $result ?? null,
    'xmpp_delivered' => $xmppDelivered ?? false,
    'visibility_mode' => $visibilityMode ?? 'all',
]);
