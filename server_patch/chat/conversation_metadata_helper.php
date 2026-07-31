<?php
declare(strict_types=1);

function chat_conversation_metadata_ensure_schema(PDO $pdo): void
{
    $pdo->exec("CREATE TABLE IF NOT EXISTS flow_conversation_metadata_definitions (
        id INT AUTO_INCREMENT PRIMARY KEY,
        scope_type VARCHAR(40) NOT NULL DEFAULT 'conversation',
        channel_type VARCHAR(80) NOT NULL DEFAULT '*',
        field_key VARCHAR(120) NOT NULL,
        field_label VARCHAR(160) NOT NULL,
        field_type ENUM('user','datetime','enum','lookup','number','currency','boolean','text') NOT NULL DEFAULT 'text',
        enum_values TEXT NULL,
        lookup_source VARCHAR(160) NULL,
        is_required TINYINT NOT NULL DEFAULT 0,
        is_system TINYINT NOT NULL DEFAULT 0,
        status TINYINT NOT NULL DEFAULT 1,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        UNIQUE KEY uniq_metadata_definition (scope_type, channel_type, field_key),
        INDEX idx_metadata_definition_status (status, channel_type)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");

    $pdo->exec("CREATE TABLE IF NOT EXISTS flow_conversation_metadata (
        id BIGINT AUTO_INCREMENT PRIMARY KEY,
        conversation_jid VARCHAR(255) NOT NULL,
        group_id INT NULL,
        field_key VARCHAR(120) NOT NULL,
        field_type VARCHAR(40) NOT NULL DEFAULT 'text',
        text_value TEXT NULL,
        number_value DECIMAL(18,4) NULL,
        datetime_value DATETIME NULL,
        bool_value TINYINT NULL,
        user_emp_id INT NULL,
        lookup_value VARCHAR(255) NULL,
        source VARCHAR(80) NOT NULL DEFAULT 'system',
        source_message_id BIGINT NULL,
        confidence DECIMAL(5,2) NULL,
        updated_by_emp_id INT NULL,
        updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        UNIQUE KEY uniq_conversation_field (conversation_jid, field_key),
        INDEX idx_metadata_group (group_id, field_key),
        INDEX idx_metadata_user (user_emp_id),
        INDEX idx_metadata_datetime (datetime_value),
        INDEX idx_metadata_lookup (field_key, lookup_value)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");

    $pdo->exec("CREATE TABLE IF NOT EXISTS flow_conversation_metadata_events (
        id BIGINT AUTO_INCREMENT PRIMARY KEY,
        conversation_jid VARCHAR(255) NOT NULL,
        group_id INT NULL,
        message_id BIGINT NULL,
        actor_emp_id INT NULL,
        event_type VARCHAR(80) NOT NULL,
        command_token VARCHAR(80) NULL,
        payload_json JSON NULL,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_metadata_event_conversation (conversation_jid, created_at),
        INDEX idx_metadata_event_type (event_type, created_at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");

    $defaults = [
        ['channel_type', 'Channel Type', 'enum'], ['status', 'Status', 'enum'], ['priority', 'Priority', 'enum'],
        ['previous_action', 'Previous Action', 'text'], ['next_action', 'Next Action', 'text'],
        ['next_action_summary', 'Next Action Summary', 'text'], ['next_action_owner', 'Next Action Owner', 'user'],
        ['participants', 'Participants', 'text'],
        ['customer', 'Customer', 'lookup'], ['project', 'Project', 'lookup'], ['department', 'Department', 'lookup'],
        ['region', 'Region', 'lookup'], ['site', 'Site', 'lookup'], ['product', 'Product', 'lookup'],
        ['sop', 'SOP', 'lookup'], ['sla', 'SLA', 'number'], ['eta', 'ETA', 'datetime'],
        ['severity', 'Severity', 'enum'], ['labels', 'Labels', 'text'], ['last_updated', 'Last Updated', 'datetime'],
    ];
    $stmt = $pdo->prepare("INSERT IGNORE INTO flow_conversation_metadata_definitions (scope_type, channel_type, field_key, field_label, field_type, is_system) VALUES ('conversation', '*', :field_key, :field_label, :field_type, 1)");
    foreach ($defaults as $field) {
        $stmt->execute([':field_key' => $field[0], ':field_label' => $field[1], ':field_type' => $field[2]]);
    }
}

function chat_metadata_command_token(string $body): string
{
    if (preg_match('/^\s*\/(update|assign|decision|meeting|action|followup|reminder|tags|ai)\b/i', $body, $m)) {
        return '/' . strtolower($m[1]);
    }
    return '';
}

function chat_metadata_action_date(string $body): ?string
{
    if (function_exists('chat_channel_action_date')) return chat_channel_action_date($body);
    $text = strtolower($body);
    if (preg_match('/\b(tomorrow|tommorrow|tosmorrow|tmrw)\b/', $text)) return date('Y-m-d H:i:s', strtotime('+1 day 18:00:00'));
    if (preg_match('/\btoday\b/', $text)) return date('Y-m-d H:i:s', strtotime('today 18:00:00'));
    if (preg_match('/\b(\d{4}-\d{2}-\d{2})(?:\s+(\d{1,2}:\d{2}))?\b/', $body, $m)) return date('Y-m-d H:i:s', strtotime($m[1] . ' ' . ($m[2] ?? '18:00')));
    return null;
}

function chat_metadata_upsert(PDO $pdo, string $jid, ?int $groupId, string $key, string $type, mixed $value, string $source, ?int $messageId, ?int $actorEmpId, ?float $confidence = null): void
{
    $text = null; $number = null; $date = null; $bool = null; $user = null; $lookup = null;
    switch ($type) {
        case 'user': $user = is_numeric($value) ? (int)$value : null; $text = is_numeric($value) ? null : trim((string)$value); break;
        case 'datetime': $date = trim((string)$value) !== '' ? date('Y-m-d H:i:s', strtotime((string)$value) ?: time()) : null; break;
        case 'number':
        case 'currency': $number = is_numeric($value) ? (float)$value : null; break;
        case 'boolean': $bool = !empty($value) ? 1 : 0; break;
        case 'lookup':
        case 'enum': $lookup = mb_substr(trim((string)$value), 0, 255); $text = $lookup; break;
        default: $text = trim((string)$value); break;
    }
    $stmt = $pdo->prepare("INSERT INTO flow_conversation_metadata
        (conversation_jid, group_id, field_key, field_type, text_value, number_value, datetime_value, bool_value, user_emp_id, lookup_value, source, source_message_id, confidence, updated_by_emp_id)
        VALUES (:jid, :group_id, :field_key, :field_type, :text_value, :number_value, :datetime_value, :bool_value, :user_emp_id, :lookup_value, :source, :message_id, :confidence, :actor)
        ON DUPLICATE KEY UPDATE group_id = VALUES(group_id), field_type = VALUES(field_type), text_value = VALUES(text_value), number_value = VALUES(number_value), datetime_value = VALUES(datetime_value), bool_value = VALUES(bool_value), user_emp_id = VALUES(user_emp_id), lookup_value = VALUES(lookup_value), source = VALUES(source), source_message_id = VALUES(source_message_id), confidence = VALUES(confidence), updated_by_emp_id = VALUES(updated_by_emp_id), updated_at = NOW()");
    $stmt->execute([
        ':jid' => strtolower($jid), ':group_id' => $groupId, ':field_key' => $key, ':field_type' => $type,
        ':text_value' => $text !== '' ? $text : null, ':number_value' => $number, ':datetime_value' => $date,
        ':bool_value' => $bool, ':user_emp_id' => $user, ':lookup_value' => $lookup !== '' ? $lookup : null,
        ':source' => $source, ':message_id' => $messageId, ':confidence' => $confidence, ':actor' => $actorEmpId,
    ]);
}

function chat_metadata_sync_conversation(PDO $pdo, array $group, ?int $actorEmpId = null, ?int $messageId = null, string $source = 'system'): void
{
    chat_conversation_metadata_ensure_schema($pdo);
    $jid = strtolower((string)($group['room_jid'] ?? ''));
    $groupId = isset($group['id']) ? (int)$group['id'] : null;
    if ($jid === '') return;
    chat_metadata_upsert($pdo, $jid, $groupId, 'channel_type', 'enum', (string)($group['channel_kind'] ?? $group['group_type'] ?? 'group'), $source, $messageId, $actorEmpId, 1.0);
    chat_metadata_upsert($pdo, $jid, $groupId, 'status', 'enum', (string)($group['status'] ?? 'Open'), $source, $messageId, $actorEmpId, 1.0);
    chat_metadata_upsert($pdo, $jid, $groupId, 'priority', 'enum', (string)($group['priority'] ?? 'Normal'), $source, $messageId, $actorEmpId, 1.0);
    chat_metadata_upsert($pdo, $jid, $groupId, 'next_action', 'text', (string)($group['next_action_text'] ?? ''), $source, $messageId, $actorEmpId, 0.9);
    chat_metadata_upsert($pdo, $jid, $groupId, 'next_action_summary', 'text', (string)($group['next_action_summary'] ?? ''), $source, $messageId, $actorEmpId, 0.85);
    chat_metadata_upsert($pdo, $jid, $groupId, 'next_action_owner', 'text', (string)($group['next_action_persons'] ?? ''), $source, $messageId, $actorEmpId, 0.8);
    if (!empty($group['next_action_date'])) chat_metadata_upsert($pdo, $jid, $groupId, 'eta', 'datetime', (string)$group['next_action_date'], $source, $messageId, $actorEmpId, 0.8);
    chat_metadata_upsert($pdo, $jid, $groupId, 'last_updated', 'datetime', date('Y-m-d H:i:s'), $source, $messageId, $actorEmpId, 1.0);
}

function chat_metadata_command_body(string $body, string $token): string
{
    if ($token === '') return trim($body);
    $text = preg_replace('/^\s*' . preg_quote($token, '/') . '\b\s*/i', '', $body) ?? $body;
    return trim($text);
}

function chat_metadata_record_message(PDO $pdo, array $group, int $messageId, int $actorEmpId, string $body, array $mentions = []): void
{
    chat_conversation_metadata_ensure_schema($pdo);
    $jid = strtolower((string)($group['room_jid'] ?? ''));
    $groupId = (int)($group['id'] ?? 0);
    if ($jid === '' || $groupId <= 0 || $messageId <= 0 || trim($body) === '') return;
    $token = chat_metadata_command_token($body);
    $commandBody = chat_metadata_command_body($body, $token);
    $eventType = $token !== '' ? 'command.' . substr($token, 1) : 'message.context';
    $payload = ['body' => mb_substr($body, 0, 4000), 'command_body' => mb_substr($commandBody, 0, 4000), 'mentions' => $mentions];
    $stmt = $pdo->prepare('INSERT INTO flow_conversation_metadata_events (conversation_jid, group_id, message_id, actor_emp_id, event_type, command_token, payload_json) VALUES (:jid, :group_id, :message_id, :actor, :event_type, :command, :payload)');
    $stmt->execute([':jid' => $jid, ':group_id' => $groupId, ':message_id' => $messageId, ':actor' => $actorEmpId, ':event_type' => $eventType, ':command' => $token !== '' ? $token : null, ':payload' => json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES)]);

    if ($token === '/update' && $commandBody !== '') {
        chat_metadata_upsert($pdo, $jid, $groupId, 'current_status', 'text', $commandBody, 'command', $messageId, $actorEmpId, 0.9);
    } elseif ($token === '/decision' && $commandBody !== '') {
        chat_metadata_upsert($pdo, $jid, $groupId, 'pending_decisions', 'text', $commandBody, 'command', $messageId, $actorEmpId, 0.9);
    } elseif ($token === '/meeting' && $commandBody !== '') {
        chat_metadata_upsert($pdo, $jid, $groupId, 'current_status', 'text', 'Meeting notes: ' . $commandBody, 'command', $messageId, $actorEmpId, 0.85);
    } elseif ($token === '/tags') {
        $labels = preg_split('/[,#]+/', $commandBody) ?: [];
        $labels = array_values(array_unique(array_filter(array_map(static fn(string $item): string => trim($item), $labels))));
        if ($labels) chat_metadata_upsert($pdo, $jid, $groupId, 'labels', 'text', implode(', ', $labels), 'command', $messageId, $actorEmpId, 0.9);
        chat_metadata_upsert($pdo, $jid, $groupId, 'last_updated', 'datetime', date('Y-m-d H:i:s'), 'command', $messageId, $actorEmpId, 1.0);
        return;
    }

    $isExplicitActionCommand = in_array($token, ['/assign', '/action', '/followup', '/reminder'], true);
    $isTaskLike = function_exists('chat_channel_action_is_task_like') && chat_channel_action_is_task_like($body);
    if ($isExplicitActionCommand || $isTaskLike) {
        $actionText = $commandBody !== '' ? $commandBody : $body;
        chat_metadata_upsert($pdo, $jid, $groupId, 'previous_action', 'text', (string)($group['previous_action_text'] ?? ''), 'message', $messageId, $actorEmpId, 0.7);
        chat_metadata_upsert($pdo, $jid, $groupId, 'next_action', 'text', $actionText, 'message', $messageId, $actorEmpId, 0.85);
        $summary = function_exists('chat_channel_action_summary') ? chat_channel_action_summary($body) : mb_substr(trim($actionText), 0, 240);
        chat_metadata_upsert($pdo, $jid, $groupId, 'next_action_summary', 'text', $summary, 'message', $messageId, $actorEmpId, 0.8);
        $eta = chat_metadata_action_date($body);
        if ($eta !== null) chat_metadata_upsert($pdo, $jid, $groupId, 'eta', 'datetime', $eta, 'message', $messageId, $actorEmpId, 0.75);
        $owner = '';
        if (function_exists('chat_channel_action_persons')) {
            $persons = chat_channel_action_persons($pdo, $groupId, $actorEmpId, $body, $mentions, false);
            $owner = implode(', ', array_map(static fn(array $m): string => trim((string)$m['name']) . ' (' . (int)$m['emp_id'] . ')', $persons));
        }
        chat_metadata_upsert($pdo, $jid, $groupId, 'next_action_owner', 'text', $owner !== '' ? $owner : 'Person not mentioned', 'message', $messageId, $actorEmpId, 0.75);
    } else {
        chat_metadata_upsert($pdo, $jid, $groupId, 'last_updated', 'datetime', date('Y-m-d H:i:s'), 'message', $messageId, $actorEmpId, 1.0);
        return;
    }
    try {
        $refresh = $pdo->prepare('SELECT * FROM xmpp_groups WHERE id = :group_id LIMIT 1');
        $refresh->execute([':group_id' => $groupId]);
        $freshGroup = $refresh->fetch(PDO::FETCH_ASSOC) ?: $group;
        chat_metadata_sync_conversation($pdo, $freshGroup, $actorEmpId, $messageId, 'message');
    } catch (Throwable $e) {
        chat_metadata_sync_conversation($pdo, $group, $actorEmpId, $messageId, 'message');
    }
}

