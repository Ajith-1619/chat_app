<?php
declare(strict_types=1);

require_once __DIR__ . '/SystemNotification.php';

function notification_recipient_ids(array $reminder): array
{
    $ids = [(int)($reminder['created_by_emp_id'] ?? 0)];
    $assigned = json_decode((string)($reminder['assignee_ids_json'] ?? '[]'), true);
    foreach (is_array($assigned) ? $assigned : [] as $id) $ids[] = (int)$id;
    return array_values(array_unique(array_filter($ids, static fn(int $id): bool => $id > 0)));
}

function notification_event(PDO $pdo, int $empId, string $eventKey, string $eventType, array $reminder, string $body): void
{
    $stmt = $pdo->prepare(
        'INSERT IGNORE INTO xmpp_notification_events
         (emp_id, event_key, event_type, reminder_id, title, body, created_at)
         VALUES (:emp, :event_key, :event_type, :reminder_id, :title, :body, NOW())'
    );
    $stmt->execute([
        ':emp' => $empId,
        ':event_key' => $eventKey,
        ':event_type' => $eventType,
        ':reminder_id' => (int)($reminder['id'] ?? 0),
        ':title' => (string)($reminder['title'] ?? ''),
        ':body' => $body,
    ]);
}

function notification_emit_to_recipients(PDO $pdo, array $reminder, string $eventType, string $eventKeyPrefix, string $body): void
{
    foreach (notification_recipient_ids($reminder) as $recipient) {
        chat_send_system_notification(
            $recipient,
            $body,
            $eventType,
            $eventKeyPrefix . ':' . $recipient
        );
    }
}
function notification_next_due(array $reminder, DateTimeImmutable $due): ?DateTimeImmutable
{
    $type = strtolower((string)($reminder['recurrence_type'] ?? 'once'));
    if ($type === 'once') return null;
    if ($type === 'daily') return $due->modify('+1 day');
    if ($type === 'custom') {
        $count = max(1, (int)($reminder['custom_interval'] ?? 1));
        $unit = in_array(($reminder['custom_unit'] ?? ''), ['day', 'week', 'month'], true)
            ? (string)$reminder['custom_unit'] : 'week';
        return $due->modify('+' . $count . ' ' . $unit);
    }
    if ($type === 'weekly') {
        $days = array_map('intval', json_decode((string)($reminder['weekdays_json'] ?? '[]'), true) ?: []);
        for ($step = 1; $step <= 14; $step++) {
            $candidate = $due->modify('+' . $step . ' day');
            if (in_array((int)$candidate->format('N'), $days, true)) return $candidate;
        }
        return $due->modify('+1 week');
    }
    if ($type === 'monthly') {
        $days = array_map('intval', json_decode((string)($reminder['month_days_json'] ?? '[]'), true) ?: []);
        for ($step = 1; $step <= 62; $step++) {
            $candidate = $due->modify('+' . $step . ' day');
            if (in_array((int)$candidate->format('j'), $days, true)) return $candidate;
        }
        return $due->modify('+1 month');
    }
    return null;
}

function notification_materialize_due(PDO $pdo): void
{
    $rows = $pdo->query(
        'SELECT * FROM xmpp_reminders
         WHERE active = 1 AND next_due_at IS NOT NULL AND next_due_at <= NOW()
         ORDER BY next_due_at ASC LIMIT 200'
    )->fetchAll(PDO::FETCH_ASSOC) ?: [];
    foreach ($rows as $reminder) {
        $dueRaw = (string)$reminder['next_due_at'];
        $due = new DateTimeImmutable($dueRaw);
        $label = ($reminder['kind'] ?? 'reminder') === 'followup' ? 'Follow-up due' : 'Reminder due';
        notification_emit_to_recipients(
            $pdo,
            $reminder,
            'due',
            'due:' . (int)$reminder['id'] . ':' . $due->format('YmdHis'),
            $label . ': ' . (string)$reminder['title']
        );
        $next = notification_next_due($reminder, $due);
        $stmt = $pdo->prepare(
            'UPDATE xmpp_reminders SET next_due_at = :next
             WHERE id = :id AND next_due_at = :previous'
        );
        $stmt->execute([
            ':next' => $next?->format('Y-m-d H:i:s'),
            ':id' => (int)$reminder['id'],
            ':previous' => $dueRaw,
        ]);
    }
}