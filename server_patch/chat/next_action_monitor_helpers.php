<?php
declare(strict_types=1);

require_once __DIR__ . '/SystemNotification.php';
require_once __DIR__ . '/channel_action_helper.php';

function next_action_monitor_ensure_schema(PDO $pdo): void
{
    chat_channel_action_ensure_schema($pdo);
    chat_ensure_column($pdo, 'xmpp_groups', 'next_action_reminder_sent_at', 'DATETIME NULL AFTER next_action_missing_fields');
    chat_ensure_column($pdo, 'xmpp_groups', 'next_action_due_poll_sent_at', 'DATETIME NULL AFTER next_action_reminder_sent_at');
    chat_ensure_column($pdo, 'xmpp_groups', 'next_action_due_prompt_response_at', 'DATETIME NULL AFTER next_action_due_poll_sent_at');
    chat_ensure_column($pdo, 'xmpp_groups', 'next_action_due_prompt_status', 'VARCHAR(40) NULL AFTER next_action_due_prompt_response_at');
    chat_ensure_column($pdo, 'xmpp_groups', 'next_action_monitor_hash', 'VARCHAR(80) NULL AFTER next_action_due_prompt_status');
}

function next_action_monitor_hash(array $group): string
{
    return hash('sha256', implode('|', [
        trim((string)($group['next_action_text'] ?? '')),
        trim((string)($group['next_action_summary'] ?? '')),
        trim((string)($group['next_action_persons'] ?? '')),
        trim((string)($group['next_action_date'] ?? '')),
    ]));
}

function next_action_monitor_clean(string $value, int $limit = 500): string
{
    $value = trim(preg_replace('/\s+/', ' ', $value) ?? $value);
    return mb_substr($value, 0, $limit);
}

function next_action_monitor_insert_room_message(
    PDO $pdo,
    array $group,
    string $body,
    string $sourceName,
    string $clientMessageId
): int {
    $roomJid = strtolower(trim((string)($group['room_jid'] ?? '')));
    if ($roomJid === '' || trim($body) === '') return 0;

    $exists = $pdo->prepare('SELECT id FROM xmpp_messages WHERE from_jid = :from_jid AND client_message_id = :client_id LIMIT 1');
    $exists->execute([
        ':from_jid' => SKYCHAT_SYSTEM_NOTIFICATION_JID,
        ':client_id' => $clientMessageId,
    ]);
    $existingId = (int)($exists->fetchColumn() ?: 0);
    if ($existingId > 0) return $existingId;

    chat_ensure_system_notification_account();
    try {
        chat_ejabberd_client()->sendMessage(SKYCHAT_SYSTEM_NOTIFICATION_JID, $roomJid, $body, 'groupchat');
    } catch (Throwable $e) {
        error_log('next action monitor xmpp send skipped: ' . $e->getMessage());
    }

    $stmt = $pdo->prepare(
        'INSERT INTO xmpp_messages
         (from_jid, to_jid, body, message_type, status, client_message_id, source_device, source_name, visibility_mode)
         VALUES (:from_jid, :to_jid, :body, :message_type, :status, :client_id, :source_device, :source_name, :visibility_mode)'
    );
    $stmt->execute([
        ':from_jid' => SKYCHAT_SYSTEM_NOTIFICATION_JID,
        ':to_jid' => $roomJid,
        ':body' => mb_substr($body, 0, 4000),
        ':message_type' => 'groupchat',
        ':status' => 'sent',
        ':client_id' => mb_substr($clientMessageId, 0, 80),
        ':source_device' => 'system',
        ':source_name' => mb_substr($sourceName, 0, 120),
        ':visibility_mode' => 'all',
    ]);
    return (int)$pdo->lastInsertId();
}

function next_action_monitor_reminder_body(array $group): string
{
    $owner = next_action_monitor_clean((string)($group['next_action_persons'] ?? ''), 180);
    if ($owner === '' || strtolower($owner) === 'person not mentioned') {
        $owner = 'Action owner';
    }
    $action = next_action_monitor_clean((string)($group['next_action_summary'] ?? $group['next_action_text'] ?? ''), 700);
    $due = next_action_monitor_clean((string)($group['next_action_date'] ?? ''), 80);
    return "{$owner}, this action is pending on your side. Please make an update.\n\nNext action: {$action}\nDue: {$due}";
}

function next_action_monitor_due_poll_body(array $group): string
{
    $action = next_action_monitor_clean((string)($group['next_action_summary'] ?? $group['next_action_text'] ?? ''), 220);
    $due = next_action_monitor_clean((string)($group['next_action_date'] ?? ''), 80);
    $owner = next_action_monitor_clean((string)($group['next_action_persons'] ?? ''), 180);
    $question = 'Next action update required';
    if ($action !== '') {
        $question .= ': ' . $action;
    }
    if ($due !== '') {
        $question .= ' Due: ' . $due;
    }
    $poll = [
        'question' => mb_substr($question, 0, 500),
        'allow_multiple' => false,
        'options' => [
            ['text' => 'Complete', 'votes' => [], 'action' => 'complete'],
            ['text' => 'Not complete', 'votes' => [], 'action' => 'not_complete'],
        ],
        'system_generated' => true,
        'kind' => 'next_action_due',
        'response_required' => true,
        'owner_only' => true,
        'owner_label' => $owner,
        'channel_id' => (int)($group['id'] ?? 0),
        'next_action_summary' => $action,
        'next_action_date' => $due,
        'created_at' => date(DATE_ATOM),
        'updated_at' => date(DATE_ATOM),
    ];
    return 'SKYLINK_POLL:' . json_encode($poll, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
}

function next_action_monitor_due_timestamp(array $group): int
{
    $raw = trim((string)($group['next_action_date'] ?? ''));
    if ($raw === '' || $raw === '0000-00-00 00:00:00') return 0;
    $timestamp = strtotime($raw);
    return $timestamp === false ? 0 : $timestamp;
}

function next_action_monitor_reset_if_changed(PDO $pdo, array $group, string $hash): array
{
    if (hash_equals((string)($group['next_action_monitor_hash'] ?? ''), $hash)) return $group;
    $stmt = $pdo->prepare(
        'UPDATE xmpp_groups
         SET next_action_reminder_sent_at = NULL,
             next_action_due_poll_sent_at = NULL,
             next_action_monitor_hash = :hash
         WHERE id = :group_id'
    );
    $stmt->execute([':hash' => $hash, ':group_id' => (int)$group['id']]);
    $group['next_action_reminder_sent_at'] = null;
    $group['next_action_due_poll_sent_at'] = null;
    $group['next_action_monitor_hash'] = $hash;
    return $group;
}

function next_action_monitor_process(PDO $pdo, ?int $now = null): array
{
    chat_ensure_schema($pdo);
    next_action_monitor_ensure_schema($pdo);
    $now = $now ?? time();
    $stmt = $pdo->query(
        "SELECT id, room_name, room_jid, group_type, channel_kind, status,
                next_action_text, next_action_summary, next_action_persons, next_action_date,
                next_action_reminder_sent_at, next_action_due_poll_sent_at,
                next_action_due_prompt_response_at, next_action_due_prompt_status,
                next_action_monitor_hash
         FROM xmpp_groups
         WHERE COALESCE(is_archived, 0) = 0
           AND COALESCE(next_action_text, '') <> ''
           AND next_action_date IS NOT NULL
           AND next_action_date <> '0000-00-00 00:00:00'
           AND COALESCE(status, 'Open') NOT IN ('Completed', 'Closed', 'Cancelled', 'Deleted')
         ORDER BY next_action_date ASC
         LIMIT 300"
    );
    $groups = $stmt->fetchAll(PDO::FETCH_ASSOC) ?: [];
    $checked = 0;
    $reminders = 0;
    $polls = 0;

    foreach ($groups as $group) {
        if (!chat_channel_action_is_channel($group)) continue;
        $checked++;
        $dueAt = next_action_monitor_due_timestamp($group);
        if ($dueAt <= 0) continue;
        $hash = next_action_monitor_hash($group);
        $group = next_action_monitor_reset_if_changed($pdo, $group, $hash);
        $groupId = (int)$group['id'];

        if ($now >= ($dueAt - 3600) && $now < $dueAt && empty($group['next_action_reminder_sent_at'])) {
            $clientId = 'next-action-reminder:' . $groupId . ':' . substr($hash, 0, 24);
            $messageId = next_action_monitor_insert_room_message($pdo, $group, next_action_monitor_reminder_body($group), 'Next action reminder', $clientId);
            if ($messageId > 0) {
                $update = $pdo->prepare('UPDATE xmpp_groups SET next_action_reminder_sent_at = NOW() WHERE id = :group_id');
                $update->execute([':group_id' => $groupId]);
                $reminders++;
            }
        }

        $lastPromptAt = strtotime((string)($group['next_action_due_poll_sent_at'] ?? '')) ?: 0;
        $hasResponse = !empty($group['next_action_due_prompt_response_at']);
        if ($now >= $dueAt && !$hasResponse && ($lastPromptAt <= 0 || ($now - $lastPromptAt) >= 1800)) {
            $clientId = 'next-action-prompt:' . $groupId . ':' . substr($hash, 0, 16) . ':' . date('YmdHi', $now);
            $messageId = next_action_monitor_insert_room_message($pdo, $group, next_action_monitor_due_poll_body($group), 'Next action poll', $clientId);
            if ($messageId > 0) {
                $update = $pdo->prepare('UPDATE xmpp_groups SET next_action_due_poll_sent_at = NOW() WHERE id = :group_id');
                $update->execute([':group_id' => $groupId]);
                $polls++;
            }
        }
    }

    return [
        'checked' => $checked,
        'reminders_sent' => $reminders,
        'polls_sent' => $polls,
    ];
}
