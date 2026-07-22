<?php
declare(strict_types=1);

function chat_channel_action_ensure_schema(PDO $pdo): void
{
    chat_ensure_column($pdo, 'xmpp_groups', 'description', 'TEXT NULL AFTER avatar_url');
    chat_ensure_column($pdo, 'xmpp_groups', 'next_action_text', 'TEXT NULL AFTER next_action_date');
    chat_ensure_column($pdo, 'xmpp_groups', 'next_action_persons', 'TEXT NULL AFTER next_action_text');
    chat_ensure_column($pdo, 'xmpp_groups', 'next_action_updated_at', 'DATETIME NULL AFTER next_action_persons');
    chat_ensure_column($pdo, 'xmpp_groups', 'next_action_source_message_id', 'BIGINT NULL AFTER next_action_updated_at');
}

function chat_channel_action_is_task_like(string $body): bool
{
    $text = strtolower(trim($body));
    if ($text === '' || str_starts_with($text, 'skylink_')) return false;
    return preg_match('/\b(task|complete|finish|done|update|call|send|check|close|resolve|follow|followup|tomorrow|tommorrow|tosmorrow|tmrw|today|before|by|need|please|work|issue|assign|handover|remind)\b/i', $text) === 1;
}

function chat_channel_action_date(string $body): ?string
{
    $text = strtolower($body);
    $base = null;
    if (preg_match('/\b(tomorrow|tommorrow|tosmorrow|tmrw)\b/', $text)) {
        $base = strtotime('+1 day 18:00:00');
    } elseif (preg_match('/\btoday\b/', $text)) {
        $base = strtotime('today 18:00:00');
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

function chat_channel_action_persons(PDO $pdo, int $groupId, int $senderEmpId, string $body, array $mentions): array
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
    return array_values(array_filter($members, static fn(array $m): bool => (int)$m['emp_id'] !== $senderEmpId));
}

function chat_update_channel_next_action_from_message(PDO $pdo, array $group, int $messageId, int $senderEmpId, string $body, array $mentions): void
{
    $groupId = (int)($group['id'] ?? 0);
    if ($groupId <= 0 || !chat_channel_action_is_channel($group)) return;
    if (!chat_channel_action_is_task_like($body)) return;
    chat_channel_action_ensure_schema($pdo);
    $persons = chat_channel_action_persons($pdo, $groupId, $senderEmpId, $body, $mentions);
    $personLabels = array_map(static fn(array $m): string => trim((string)$m['name']) . ' (' . (int)$m['emp_id'] . ')', $persons);
    $nextDate = chat_channel_action_date($body);
    $stmt = $pdo->prepare('UPDATE xmpp_groups
        SET next_action_text = :action_text,
            next_action_persons = :persons,
            next_action_date = COALESCE(:next_date, next_action_date),
            next_action_updated_at = NOW(),
            next_action_source_message_id = :message_id
        WHERE id = :group_id');
    $stmt->execute([
        ':action_text' => mb_substr(trim($body), 0, 4000),
        ':persons' => $personLabels ? implode(', ', $personLabels) : 'Person not mentioned',
        ':next_date' => $nextDate,
        ':message_id' => $messageId,
        ':group_id' => $groupId,
    ]);
    try {
        $timeline = $pdo->prepare('INSERT INTO xmpp_channel_timeline (group_id, event_type, body, actor_emp_id) VALUES (:group_id, :event_type, :body, :actor)');
        $timeline->execute([
            ':group_id' => $groupId,
            ':event_type' => 'next_action_detected',
            ':body' => mb_substr(trim($body), 0, 1000),
            ':actor' => $senderEmpId,
        ]);
    } catch (Throwable $e) {
        error_log('channel next action timeline skipped: ' . $e->getMessage());
    }
}
