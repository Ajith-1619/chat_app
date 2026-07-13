<?php
declare(strict_types=1);
require_once __DIR__ . '/SystemNotification.php';

function wakeup_interval_label(int $minutes): string
{
    if ($minutes <= 0) return 'disabled';
    if ($minutes % 43200 === 0) {
        $months = intdiv($minutes, 43200);
        return $months === 1 ? '1 month' : $months . ' months';
    }
    if ($minutes % 1440 === 0) {
        $days = intdiv($minutes, 1440);
        return $days === 1 ? '1 day' : $days . ' days';
    }
    if ($minutes % 60 === 0) {
        $hours = intdiv($minutes, 60);
        return $hours === 1 ? '1 hour' : $hours . ' hours';
    }
    return $minutes . ' minutes';
}

function wakeup_is_business_day(DateTimeInterface $date): bool
{
    $weekday = (int)$date->format('N');
    return $weekday >= 1 && $weekday <= 5;
}

function wakeup_business_minutes_between(DateTimeInterface $start, DateTimeInterface $end): int
{
    if ($end <= $start) return 0;
    $cursor = new DateTimeImmutable($start->format('Y-m-d H:i:s'));
    $limit = new DateTimeImmutable($end->format('Y-m-d H:i:s'));
    $totalSeconds = 0;
    while ($cursor < $limit) {
        $dayEnd = $cursor->setTime(23, 59, 59)->modify('+1 second');
        $segmentEnd = $dayEnd < $limit ? $dayEnd : $limit;
        if (wakeup_is_business_day($cursor)) {
            $totalSeconds += max(0, $segmentEnd->getTimestamp() - $cursor->getTimestamp());
        }
        $cursor = $segmentEnd;
    }
    return intdiv($totalSeconds, 60);
}

function wakeup_business_remaining_seconds(int $intervalMinutes, DateTimeInterface $lastActivity, ?DateTimeInterface $now = null): int
{
    if ($intervalMinutes <= 0) return 0;
    if ($now === null) {
        $now = new DateTimeImmutable('now');
    }
    $elapsed = wakeup_business_minutes_between($lastActivity, $now);
    return max(0, ($intervalMinutes - $elapsed) * 60);
}

function wakeup_room_message(array $group, string $lastActivity): string
{
    $name = (string)($group['room_name'] ?? 'this conversation');
    $kind = ((string)($group['group_type'] ?? 'group')) === 'channel' ? 'channel' : 'group';
    $interval = wakeup_interval_label((int)($group['wakeup_interval_minutes'] ?? 1440));
    return "Wake-up reminder: No new message in {$kind} {$name} for {$interval}. Please share an update if this is still active.";
}

function wakeup_emit_group_message(PDO $pdo, array $group, string $lastActivity): int
{
    chat_ensure_system_notification_account();
    $roomJid = strtolower((string)$group['room_jid']);
    $body = wakeup_room_message($group, $lastActivity);
    chat_ejabberd_client()->sendMessage(
        SKYCHAT_SYSTEM_NOTIFICATION_JID,
        $roomJid,
        $body,
        'groupchat'
    );
    $stmt = $pdo->prepare(
        'INSERT INTO xmpp_messages
         (from_jid, to_jid, body, message_type, status, source_device, source_name, client_message_id)
         VALUES (:from_jid, :to_jid, :body, :message_type, :status, :source_device, :source_name, :client_message_id)'
    );
    $clientId = 'wakeup:' . (int)$group['id'] . ':' . date('YmdHi');
    $stmt->execute([
        ':from_jid' => SKYCHAT_SYSTEM_NOTIFICATION_JID,
        ':to_jid' => $roomJid,
        ':body' => $body,
        ':message_type' => 'groupchat',
        ':status' => 'sent',
        ':source_device' => 'system',
        ':source_name' => 'Wake-up notification',
        ':client_message_id' => $clientId,
    ]);
    $messageId = (int)$pdo->lastInsertId();
    $update = $pdo->prepare(
        'UPDATE xmpp_groups
         SET wakeup_last_sent_at = NOW()
         WHERE id = :group_id'
    );
    $update->execute([':group_id' => (int)$group['id']]);
    return $messageId;
}

function wakeup_process_due(PDO $pdo): int
{
    chat_ensure_schema($pdo);
    $stmt = $pdo->query(
        'SELECT g.*, COALESCE(last_msg.last_message_at, g.created_at) AS last_activity_at
         FROM xmpp_groups g
         LEFT JOIN (
            SELECT to_jid, MAX(created_at) AS last_message_at
            FROM xmpp_messages
            WHERE message_type IN (\'groupchat\', \'file\')
              AND deleted_at IS NULL
            GROUP BY to_jid
         ) last_msg ON last_msg.to_jid = g.room_jid
         WHERE g.is_archived = 0
           AND g.wakeup_enabled = 1
           AND g.wakeup_interval_minutes > 0
         ORDER BY COALESCE(last_msg.last_message_at, g.created_at) ASC
         LIMIT 50'
    );
    $count = 0;
    $now = new DateTimeImmutable('now');
    foreach (($stmt->fetchAll(PDO::FETCH_ASSOC) ?: []) as $group) {
        try {
            $lastActivity = new DateTimeImmutable((string)$group['last_activity_at']);
            $intervalMinutes = max(15, (int)($group['wakeup_interval_minutes'] ?? 1440));
            $lastSent = !empty($group['wakeup_last_sent_at'])
                ? new DateTimeImmutable((string)$group['wakeup_last_sent_at'])
                : null;
            $elapsed = wakeup_business_minutes_between($lastActivity, $now);
            $sentElapsed = $lastSent ? wakeup_business_minutes_between($lastSent, $now) : PHP_INT_MAX;
            if ($elapsed < $intervalMinutes || $sentElapsed < $intervalMinutes) {
                continue;
            }
            wakeup_emit_group_message($pdo, $group, (string)$group['last_activity_at']);
            $count++;
        } catch (Throwable $e) {
            error_log('wake-up notification failed for group ' . (int)$group['id'] . ': ' . $e->getMessage());
        }
    }
    return $count;
}



