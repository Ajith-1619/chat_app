<?php
declare(strict_types=1);

function chat_channel_action_ensure_schema(PDO $pdo): void
{
    chat_ensure_column($pdo, 'xmpp_groups', 'description', 'TEXT NULL AFTER avatar_url');
    chat_ensure_column($pdo, 'xmpp_groups', 'previous_action_text', 'TEXT NULL AFTER next_action_date');
    chat_ensure_column($pdo, 'xmpp_groups', 'next_action_text', 'TEXT NULL AFTER next_action_date');
    chat_ensure_column($pdo, 'xmpp_groups', 'next_action_summary', 'TEXT NULL AFTER next_action_text');
    chat_ensure_column($pdo, 'xmpp_groups', 'next_action_persons', 'TEXT NULL AFTER next_action_summary');
    chat_ensure_column($pdo, 'xmpp_groups', 'next_action_updated_at', 'DATETIME NULL AFTER next_action_persons');
    chat_ensure_column($pdo, 'xmpp_groups', 'next_action_source_message_id', 'BIGINT NULL AFTER next_action_updated_at');
    chat_ensure_column($pdo, 'xmpp_groups', 'next_action_missing_fields', 'VARCHAR(120) NULL AFTER next_action_source_message_id');
}

function chat_channel_action_is_task_like(string $body): bool
{
    $text = strtolower(trim($body));
    if ($text === '' || str_starts_with($text, 'skylink_')) return false;
    if (preg_match('/^\s*\/(ai|tags)\b/i', $text)) return false;
    if (preg_match('/\b(hi|hello|thanks|thank you|ok|okay|yes|no|noted|received|good morning|good evening)\b/i', $text) &&
        preg_match('/\b(task|complete|finish|update|call|send|check|close|resolve|assign|handover|remind|followup|follow up)\b/i', $text) !== 1) {
        return false;
    }
    return preg_match('/\b(task|complete|finish|update|call|send|check|close|resolve|assign|handover|remind|followup|follow up)\b/i', $text) === 1 ||
        preg_match('/\b(need|please|by|before|today|tomorrow|tommorrow|tosmorrow|tmrw|next week|month end|end of)\b.*\b(done|complete|send|check|close|resolve|update|call)\b/i', $text) === 1;
}

function chat_channel_action_date(string $body): ?string
{
    $text = strtolower($body);
    $base = null;
    if (preg_match('/\b(tomorrow|tommorrow|tosmorrow|tmrw)\b/', $text)) {
        $base = strtotime('+1 day 18:00:00');
    } elseif (preg_match('/\btoday\b/', $text)) {
        $base = strtotime('today 18:00:00');
    } elseif (preg_match('/\b(end|last)\s+of\s+(this\s+)?month\b|\bmonth\s+end\b/', $text)) {
        $base = strtotime('last day of this month 18:00:00');
    } elseif (preg_match('/\bend\s+of\s+next\s+month\b|\bnext\s+month\s+end\b/', $text)) {
        $base = strtotime('last day of next month 18:00:00');
    } elseif (preg_match('/\bnext\s+week\b/', $text)) {
        $base = strtotime('+7 days 18:00:00');
    } elseif (preg_match('/\b(\d{4}-\d{2}-\d{2})(?:\s+(\d{1,2}:\d{2}))?\b/', $body, $m)) {
        $base = strtotime($m[1] . ' ' . ($m[2] ?? '18:00'));
    } elseif (preg_match('/\b(\d{1,2})[\/-](\d{1,2})[\/-](\d{2,4})(?:\s+(\d{1,2}:\d{2}))?\b/', $body, $m)) {
        $year = strlen($m[3]) === 2 ? ('20' . $m[3]) : $m[3];
        $base = strtotime($year . '-' . $m[2] . '-' . $m[1] . ' ' . ($m[4] ?? '18:00'));
    }
    return $base ? date('Y-m-d H:i:s', $base) : null;
}

function chat_channel_action_norm(string $value): string
{
    $value = preg_replace('/([a-z])([A-Z])/', '$1 $2', $value) ?? $value;
    return strtolower(preg_replace('/[^a-z0-9]+/i', '', $value) ?? '');
}

function chat_channel_action_is_channel(array $group): bool
{
    $type = strtolower((string)($group['group_type'] ?? ''));
    $kind = strtolower((string)($group['channel_kind'] ?? ''));
    $jid = strtolower((string)($group['room_jid'] ?? ''));
    $name = strtolower((string)($group['room_name'] ?? ''));
    if ($type === 'channel' || $kind !== '') return true;
    if (str_starts_with($jid, 'channel-')) return true;
    if (str_contains($jid, '@conference.') && str_starts_with($name, '#')) return true;
    return false;
}

function chat_channel_action_members(PDO $pdo, int $groupId): array
{
    $stmt = $pdo->prepare('SELECT emp_id, role FROM xmpp_group_members WHERE group_id = :group_id ORDER BY role = \'owner\' DESC, role = \'admin\' DESC, emp_id ASC');
    $stmt->execute([':group_id' => $groupId]);
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC) ?: [];
    $employeePdo = getEmployeeDB();
    $members = [];
    foreach ($rows as $row) {
        $empId = (int)($row['emp_id'] ?? 0);
        if ($empId <= 0) continue;
        try {
            $payload = chat_user_payload($employeePdo, $empId, chat_jid($empId), false);
        } catch (Throwable $e) {
            $payload = ['name' => 'Employee ' . $empId, 'designation' => ''];
        }
        $name = trim((string)($payload['name'] ?? '')) ?: 'Employee ' . $empId;
        $members[] = [
            'emp_id' => $empId,
            'name' => $name,
            'search' => chat_channel_action_norm((string)$empId . ' ' . $name),
        ];
    }
    return $members;
}

function chat_channel_action_persons(PDO $pdo, int $groupId, int $senderEmpId, string $body, array $mentions, bool $fallbackToMembers = true): array
{
    $members = chat_channel_action_members($pdo, $groupId);
    $byId = [];
    foreach ($members as $member) $byId[(int)$member['emp_id']] = $member;
    $picked = [];
    foreach ($mentions as $mention) {
        if (is_int($mention) && isset($byId[$mention])) $picked[$mention] = $byId[$mention];
    }
    if (preg_match_all('/@([A-Za-z0-9_.-]+)/', $body, $matches)) {
        foreach ($matches[1] as $rawToken) {
            $token = chat_channel_action_norm($rawToken);
            if ($token === '' || in_array($token, ['ai', 'admin', 'admins', 'online', 'everyone', 'channel'], true)) continue;
            foreach ($members as $member) {
                $memberSearch = (string)$member['search'];
                $nameParts = array_values(array_filter(preg_split('/[^a-z0-9]+/i', (string)$member['name']) ?: []));
                $nameVariants = [];
                if (count($nameParts) >= 2) {
                    $first = (string)$nameParts[0];
                    $last = (string)end($nameParts);
                    $nameVariants[] = chat_channel_action_norm($first . $last);
                    $nameVariants[] = chat_channel_action_norm(substr($first, 0, 1) . $last);
                }
                if ((string)$member['emp_id'] === $rawToken || str_contains($memberSearch, $token) || in_array($token, $nameVariants, true)) {
                    $picked[(int)$member['emp_id']] = $member;
                }
            }
        }
    }
    if ($picked) return array_values($picked);
    if (!$fallbackToMembers) return [];
    return array_values(array_filter($members, static fn(array $m): bool => (int)$m['emp_id'] !== $senderEmpId));
}

function chat_channel_action_context(PDO $pdo, string $roomJid, int $currentMessageId, int $limit = 20): array
{
    $limit = max(5, min(20, $limit));
    $stmt = $pdo->prepare("SELECT id, body, created_at FROM xmpp_messages
        WHERE to_jid = :room_jid
          AND id <= :message_id
          AND (deleted_at IS NULL OR deleted_at = '0000-00-00 00:00:00')
          AND COALESCE(visibility_mode, 'all') = 'all'
          AND body IS NOT NULL AND body <> ''
        ORDER BY id DESC
        LIMIT {$limit}");
    $stmt->execute([':room_jid' => strtolower($roomJid), ':message_id' => $currentMessageId]);
    return array_reverse($stmt->fetchAll(PDO::FETCH_ASSOC) ?: []);
}

function chat_channel_action_context_body(array $rows, string $fallback): string
{
    $actionable = [];
    foreach ($rows as $row) {
        $body = trim((string)($row['body'] ?? ''));
        if ($body !== '' && chat_channel_action_is_task_like($body)) $actionable[] = $body;
    }
    if (!$actionable) return trim($fallback);
    $recent = array_slice($actionable, -5);
    return trim(implode("\n", $recent));
}

function chat_channel_action_context_summary(array $rows, string $fallback): string
{
    $parts = [];
    foreach ($rows as $row) {
        $body = trim((string)($row['body'] ?? ''));
        if ($body !== '' && chat_channel_action_is_task_like($body)) $parts[] = chat_channel_action_summary($body);
    }
    $parts = array_values(array_unique(array_filter($parts)));
    if (!$parts) return chat_channel_action_summary($fallback);
    $recent = array_slice($parts, -5);
    return mb_substr(implode('; ', $recent), 0, 500);
}
function chat_channel_action_summary(string $body): string
{
    $text = trim($body);
    $text = preg_replace('/^\s*\/(update|assign|decision|meeting|action|followup|reminder)\b\s*/i', '', $text) ?? $text;
    $text = preg_replace('/\s+/', ' ', $text) ?? $text;
    return mb_substr(trim($text), 0, 240);
}

function chat_channel_action_insert_clarification(PDO $pdo, array $group, int $messageId, int $senderEmpId, string $summary, array $missingFields): void
{
    if (!$missingFields) return;
    $groupId = (int)($group['id'] ?? 0);
    $roomJid = strtolower((string)($group['room_jid'] ?? ''));
    if ($groupId <= 0 || $roomJid === '' || $messageId <= 0) return;
    $clientId = 'action-clarify-' . $messageId;
    $exists = $pdo->prepare('SELECT id FROM xmpp_messages WHERE client_message_id = :client_id LIMIT 1');
    $exists->execute([':client_id' => $clientId]);
    if ($exists->fetchColumn()) return;
    $payload = [
        'source_message_id' => $messageId,
        'group_id' => $groupId,
        'summary' => $summary,
        'missing_fields' => array_values($missingFields),
        'created_by_emp_id' => $senderEmpId,
        'created_at' => date('c'),
    ];
    $body = 'SKYLINK_ACTION_CLARIFY:' . json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    $stmt = $pdo->prepare('INSERT INTO xmpp_messages
        (from_jid, to_jid, body, direction, message_type, is_group, group_id, source_device, source_name, client_message_id, created_at)
        VALUES (:from_jid, :to_jid, :body, :direction, :message_type, 1, :group_id, :source_device, :source_name, :client_id, NOW())');
    $stmt->execute([
        ':from_jid' => 'flow-ai@chat.skylinkonline.net',
        ':to_jid' => $roomJid,
        ':body' => $body,
        ':direction' => 'in',
        ':message_type' => 'chat',
        ':group_id' => $groupId,
        ':source_device' => 'system',
        ':source_name' => 'Flow MCO',
        ':client_id' => $clientId,
    ]);
}

function chat_update_channel_next_action_from_message(PDO $pdo, array $group, int $messageId, int $senderEmpId, string $body, array $mentions): void
{
    $groupId = (int)($group['id'] ?? 0);
    if ($groupId <= 0 || !chat_channel_action_is_channel($group)) return;
    if (!chat_channel_action_is_task_like($body)) return;
    chat_channel_action_ensure_schema($pdo);
    $roomJid = strtolower((string)($group['room_jid'] ?? ''));
    $contextRows = $roomJid !== '' ? chat_channel_action_context($pdo, $roomJid, $messageId, 20) : [];
    $contextBody = chat_channel_action_context_body($contextRows, $body);
    $persons = chat_channel_action_persons($pdo, $groupId, $senderEmpId, $contextBody, $mentions, false);
    $personLabels = array_map(static fn(array $m): string => trim((string)$m['name']) . ' (' . (int)$m['emp_id'] . ')', $persons);
    $nextDate = chat_channel_action_date($contextBody);
    $summary = chat_channel_action_context_summary($contextRows, $body);
    $missingFields = [];
    if (!$personLabels) $missingFields[] = 'person';
    if ($nextDate === null) $missingFields[] = 'date';
    $stmt = $pdo->prepare('UPDATE xmpp_groups
        SET previous_action_text = next_action_text,
            next_action_text = :action_text,
            next_action_summary = :summary,
            next_action_persons = :persons,
            next_action_date = :next_date,
            next_action_updated_at = NOW(),
            next_action_source_message_id = :message_id,
            next_action_missing_fields = :missing_fields
        WHERE id = :group_id');
    $stmt->execute([
        ':action_text' => mb_substr($summary !== '' ? $summary : trim($body), 0, 4000),
        ':summary' => $summary,
        ':persons' => $personLabels ? implode(', ', $personLabels) : 'Person not mentioned',
        ':next_date' => $nextDate,
        ':message_id' => $messageId,
        ':missing_fields' => $missingFields ? implode(',', $missingFields) : null,
        ':group_id' => $groupId,
    ]);
    chat_channel_action_insert_clarification($pdo, $group, $messageId, $senderEmpId, $summary, $missingFields);
    try {
        $timeline = $pdo->prepare('INSERT INTO xmpp_channel_timeline (group_id, event_type, body, actor_emp_id) VALUES (:group_id, :event_type, :body, :actor)');
        $timeline->execute([
            ':group_id' => $groupId,
            ':event_type' => 'next_action_detected',
            ':body' => mb_substr(json_encode(['summary' => $summary, 'message' => trim($body), 'missing_fields' => $missingFields], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES) ?: trim($body), 0, 1000),
            ':actor' => $senderEmpId,
        ]);
    } catch (Throwable $e) {
        error_log('channel next action timeline skipped: ' . $e->getMessage());
    }
}

