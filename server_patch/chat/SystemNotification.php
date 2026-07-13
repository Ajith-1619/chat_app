<?php
declare(strict_types=1);

function chat_ensure_system_notification_account(): void
{
    $client = chat_ejabberd_client();
    if ($client->accountExists('notification')) return;
    $password = trim((string)(getenv('SKYLINK_NOTIFICATION_XMPP_PASSWORD') ?: ''));
    if ($password === '') {
        throw new RuntimeException(
            'notification XMPP account is missing and SKYLINK_NOTIFICATION_XMPP_PASSWORD is not configured.'
        );
    }
    $client->register('notification', $password);
}

function chat_send_system_notification(
    int $recipientEmpId,
    string $body,
    string $eventType = 'system',
    string $referenceId = ''
): array {
    $message = trim($body);
    if ($recipientEmpId <= 0) {
        throw new InvalidArgumentException('A valid recipient employee ID is required.');
    }
    if ($message === '' || mb_strlen($message) > 4000) {
        throw new InvalidArgumentException('Notification body must contain 1 to 4000 characters.');
    }
    $event = preg_replace('/[^a-z0-9_-]+/i', '_', strtolower(trim($eventType))) ?: 'system';
    $reference = mb_substr(trim($referenceId), 0, 80);
    $to = chat_jid($recipientEmpId);
    $pdo = chat_db();
    chat_ensure_schema($pdo);

    if ($reference !== '') {
        $existing = $pdo->prepare(
            'SELECT id FROM xmpp_messages
             WHERE from_jid = :from_jid AND client_message_id = :reference LIMIT 1'
        );
        $existing->execute([
            ':from_jid' => SKYCHAT_SYSTEM_NOTIFICATION_JID,
            ':reference' => 'notification:' . $reference,
        ]);
        $existingId = (int)($existing->fetchColumn() ?: 0);
        if ($existingId > 0) {
            return ['message_id' => $existingId, 'duplicate' => true, 'to' => $to];
        }
    }

    chat_ensure_system_notification_account();

    // Delivery is XMPP-first. A failed ejabberd call never creates a DB notification.
    chat_ejabberd_client()->sendMessage(
        SKYCHAT_SYSTEM_NOTIFICATION_JID,
        $to,
        $message,
        'chat'
    );

    // History/cache is persisted only after ejabberd accepted the XMPP message.
    $stmt = $pdo->prepare(
        'INSERT INTO xmpp_messages
         (from_jid, to_jid, body, message_type, status, client_message_id,
          source_device, source_name)
         VALUES
         (:from_jid, :to_jid, :body, :message_type, :status, :client_message_id,
          :source_device, :source_name)'
    );
    $stmt->execute([
        ':from_jid' => SKYCHAT_SYSTEM_NOTIFICATION_JID,
        ':to_jid' => $to,
        ':body' => $message,
        ':message_type' => 'chat',
        ':status' => 'sent',
        ':client_message_id' => $reference !== '' ? 'notification:' . $reference : null,
        ':source_device' => 'system',
        ':source_name' => 'System ' . ucfirst($event),
    ]);
    $messageId = (int)$pdo->lastInsertId();

    // Push is supplementary for offline Android devices; XMPP remains the delivery transport.
    try {
        $tokens = $pdo->prepare('SELECT token FROM xmpp_push_tokens WHERE emp_id = :emp_id');
        $tokens->execute([':emp_id' => $recipientEmpId]);
        $push = new FirebasePush(chat_firebase_credentials_path());
        foreach (($tokens->fetchAll(PDO::FETCH_COLUMN) ?: []) as $token) {
            $push->send(
                (string)$token,
                'System Notifications',
                $message,
                [
                    'jid' => SKYCHAT_SYSTEM_NOTIFICATION_JID,
                    'message_id' => (string)$messageId,
                    'event_type' => $event,
                ]
            );
        }
    } catch (Throwable $pushError) {
        error_log('system notification push skipped: ' . $pushError->getMessage());
    }

    return [
        'message_id' => $messageId,
        'duplicate' => false,
        'from' => SKYCHAT_SYSTEM_NOTIFICATION_JID,
        'to' => $to,
    ];
}