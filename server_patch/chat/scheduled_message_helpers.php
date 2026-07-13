<?php
declare(strict_types=1);

function scheduled_message_process(PDO $pdo): void
{
    $rows = $pdo->query(
        "SELECT t.id AS target_id, t.target_jid, s.id AS schedule_id,
                s.created_by_emp_id, s.body, s.silent
         FROM xmpp_scheduled_message_targets t
         INNER JOIN xmpp_scheduled_messages s ON s.id = t.schedule_id
         WHERE t.status = 'pending' AND s.status = 'scheduled'
           AND s.scheduled_at <= NOW()
         ORDER BY s.scheduled_at ASC, t.id ASC LIMIT 200"
    )->fetchAll(PDO::FETCH_ASSOC) ?: [];

    foreach ($rows as $row) {
        $targetId = (int)$row['target_id'];
        $claim = $pdo->prepare(
            "UPDATE xmpp_scheduled_message_targets
             SET status = 'processing', attempts = attempts + 1
             WHERE id = :id AND status = 'pending'"
        );
        $claim->execute([':id' => $targetId]);
        if ($claim->rowCount() < 1) continue;
        try {
            $creator = (int)$row['created_by_emp_id'];
            $from = chat_jid($creator);
            $to = strtolower(trim((string)$row['target_jid']));
            $isGroup = chat_is_room_jid($to);
            if (!$isGroup && !chat_is_user_jid($to)) {
                throw new RuntimeException('Invalid scheduled receiver.');
            }
            if ($isGroup && !chat_group_for_member($pdo, $to, $creator)) {
                throw new RuntimeException('Sender is no longer a group member.');
            }
            $body = trim((string)$row['body']);
            chat_ejabberd_client()->sendMessage(
                $from,
                $to,
                $body,
                $isGroup ? 'groupchat' : 'chat'
            );
            $insert = $pdo->prepare(
                'INSERT INTO xmpp_messages
                 (from_jid, to_jid, body, message_type, status, source_device, source_name)
                 VALUES (:from_jid, :to_jid, :body, :message_type, :status, :source_device, :source_name)'
            );
            $insert->execute([
                ':from_jid' => $from,
                ':to_jid' => $to,
                ':body' => $body,
                ':message_type' => $isGroup ? 'groupchat' : 'chat',
                ':status' => 'sent',
                ':source_device' => 'scheduled',
                ':source_name' => 'Scheduled message',
            ]);
            $pdo->prepare(
                "UPDATE xmpp_scheduled_message_targets
                 SET status = 'sent', sent_at = NOW(), message_id = :message_id,
                     last_error = NULL WHERE id = :id"
            )->execute([
                ':message_id' => (int)$pdo->lastInsertId(),
                ':id' => $targetId,
            ]);
        } catch (Throwable $e) {
            $pdo->prepare(
                "UPDATE xmpp_scheduled_message_targets
                 SET status = CASE WHEN attempts >= 3 THEN 'failed' ELSE 'pending' END,
                     last_error = :error WHERE id = :id"
            )->execute([
                ':error' => mb_substr($e->getMessage(), 0, 500),
                ':id' => $targetId,
            ]);
        }
    }

    $pdo->exec(
        "UPDATE xmpp_scheduled_messages s
         SET status = CASE
           WHEN EXISTS (
             SELECT 1 FROM xmpp_scheduled_message_targets t
             WHERE t.schedule_id = s.id AND t.status IN ('pending', 'processing')
           ) THEN 'scheduled'
           WHEN EXISTS (
             SELECT 1 FROM xmpp_scheduled_message_targets t
             WHERE t.schedule_id = s.id AND t.status = 'failed'
           ) THEN 'partial'
           ELSE 'sent' END,
           completed_at = CASE WHEN NOT EXISTS (
             SELECT 1 FROM xmpp_scheduled_message_targets t
             WHERE t.schedule_id = s.id AND t.status IN ('pending', 'processing')
           ) THEN NOW() ELSE completed_at END
         WHERE s.status = 'scheduled' AND s.scheduled_at <= NOW()"
    );
}