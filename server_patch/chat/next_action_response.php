<?php
declare(strict_types=1);

require_once __DIR__ . '/bootstrap.php';
require_once __DIR__ . '/next_action_monitor_helpers.php';

function next_action_response_normalize_owner_ids(string $ownerText): array
{
    $ids = [];
    if (preg_match_all('/\((\d+)\)|\b(\d{1,6})\b/', $ownerText, $matches, PREG_SET_ORDER)) {
        foreach ($matches as $match) {
            $id = (int)($match[1] !== '' ? $match[1] : $match[2]);
            if ($id > 0) $ids[$id] = true;
        }
    }
    return array_keys($ids);
}

function next_action_response_authorized(PDO $pdo, array $group, int $empId): bool
{
    $ownerIds = next_action_response_normalize_owner_ids((string)($group['next_action_persons'] ?? ''));
    if ($ownerIds) return in_array($empId, $ownerIds, true);
    $role = strtolower((string)($group['role'] ?? ''));
    return in_array($role, ['owner', 'admin'], true);
}

function next_action_response_user_label(PDO $pdo, int $empId): string
{
    try {
        $payload = chat_user_payload(getEmployeeDB(), $empId, chat_jid($empId), false);
        $name = trim((string)($payload['name'] ?? ''));
        return $name !== '' ? $name : ('Employee ' . $empId);
    } catch (Throwable $e) {
        return 'Employee ' . $empId;
    }
}

$session = chat_require_user();
$input = json_decode(file_get_contents('php://input') ?: '{}', true);
if (!is_array($input)) chat_json(['status' => false, 'error' => 'Invalid JSON'], 422);

$messageId = (int)($input['message_id'] ?? 0);
$response = strtolower(trim((string)($input['response'] ?? '')));
$notes = trim((string)($input['notes'] ?? ''));
$nextActionDateRaw = trim((string)($input['next_action_date'] ?? ''));
if ($messageId <= 0 || !in_array($response, ['complete', 'not_complete'], true)) {
    chat_json(['status' => false, 'error' => 'Valid next action response is required'], 422);
}

try {
    $pdo = chat_db();
    chat_ensure_schema($pdo);
    next_action_monitor_ensure_schema($pdo);

    $stmt = $pdo->prepare('SELECT * FROM xmpp_messages WHERE id = :id AND deleted_at IS NULL LIMIT 1');
    $stmt->execute([':id' => $messageId]);
    $message = $stmt->fetch(PDO::FETCH_ASSOC) ?: [];
    if (!$message) chat_json(['status' => false, 'error' => 'Next action prompt not found'], 404);

    $prefix = 'SKYLINK_POLL:';
    $body = (string)($message['body'] ?? '');
    if (!str_starts_with($body, $prefix)) chat_json(['status' => false, 'error' => 'Message is not a next action prompt'], 422);
    $poll = json_decode(substr($body, strlen($prefix)), true);
    if (!is_array($poll) || (string)($poll['kind'] ?? '') !== 'next_action_due') {
        chat_json(['status' => false, 'error' => 'Message is not a next action prompt'], 422);
    }

    $roomJid = strtolower(trim((string)($message['to_jid'] ?? '')));
    if (!chat_is_room_jid($roomJid)) chat_json(['status' => false, 'error' => 'Next action prompt must belong to a group or channel'], 422);
    $group = chat_group_for_member($pdo, $roomJid, (int)$session['emp_id']);
    if (!$group) chat_json(['status' => false, 'error' => 'You are not a participant in this channel'], 403);
    if (!next_action_response_authorized($pdo, $group, (int)$session['emp_id'])) {
        chat_json(['status' => false, 'error' => 'Only the assigned next action person can update this prompt'], 403);
    }

    $actor = next_action_response_user_label($pdo, (int)$session['emp_id']);
    $groupId = (int)$group['id'];
    $action = next_action_monitor_clean((string)($group['next_action_summary'] ?? $group['next_action_text'] ?? ''), 700);

    if ($response === 'complete') {
        if ($notes === '') $notes = 'Completed.';
        $update = $pdo->prepare('UPDATE xmpp_groups
            SET previous_action_text = CASE WHEN COALESCE(next_action_text, \'\') = \'\' THEN previous_action_text ELSE next_action_text END,
                next_action_text = NULL,
                next_action_summary = NULL,
                next_action_persons = NULL,
                next_action_date = NULL,
                next_action_missing_fields = NULL,
                next_action_updated_at = NOW(),
                next_action_reminder_sent_at = NULL,
                next_action_due_poll_sent_at = NULL,
                next_action_due_prompt_response_at = NOW(),
                next_action_due_prompt_status = \'complete\',
                next_action_monitor_hash = NULL
            WHERE id = :group_id');
        $update->execute([':group_id' => $groupId]);
        $systemBody = "Next action completed by {$actor}.\n\nAction: {$action}\nUpdate: " . next_action_monitor_clean($notes, 1000);
    } else {
        $nextTs = $nextActionDateRaw !== '' ? strtotime($nextActionDateRaw) : false;
        if (!$nextTs) chat_json(['status' => false, 'error' => 'Next action date is required'], 422);
        $nextDate = date('Y-m-d H:i:s', $nextTs);
        if ($notes === '') $notes = 'Not complete. Next action date changed.';
        $update = $pdo->prepare('UPDATE xmpp_groups
            SET next_action_date = :next_date,
                next_action_updated_at = NOW(),
                next_action_reminder_sent_at = NULL,
                next_action_due_poll_sent_at = NULL,
                next_action_due_prompt_response_at = NOW(),
                next_action_due_prompt_status = \'not_complete\',
                next_action_monitor_hash = NULL
            WHERE id = :group_id');
        $update->execute([':next_date' => $nextDate, ':group_id' => $groupId]);
        $systemBody = "Next action not complete. Updated by {$actor}.\n\nAction: {$action}\nNew due: {$nextDate}\nUpdate: " . next_action_monitor_clean($notes, 1000);
    }

    $poll['responded_by_emp_id'] = (int)$session['emp_id'];
    $poll['responded_by_name'] = $actor;
    $poll['response'] = $response;
    $poll['response_notes'] = mb_substr($notes, 0, 1000);
    if ($response === 'not_complete') $poll['next_action_date'] = $nextDate ?? $nextActionDateRaw;
    $poll['updated_at'] = date(DATE_ATOM);
    $updatedBody = $prefix . json_encode($poll, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    $messageUpdate = $pdo->prepare('UPDATE xmpp_messages SET body = :body, edited_at = NOW() WHERE id = :id');
    $messageUpdate->execute([':body' => $updatedBody, ':id' => $messageId]);

    next_action_monitor_insert_room_message(
        $pdo,
        array_merge($group, ['room_jid' => $roomJid]),
        $systemBody,
        'Next action update',
        'next-action-response:' . $messageId . ':' . $response . ':' . (int)$session['emp_id']
    );

    chat_json(['status' => true, 'message_id' => $messageId, 'response' => $response]);
} catch (Throwable $e) {
    error_log('chat/next_action_response failed: ' . $e->getMessage());
    chat_json(['status' => false, 'error' => 'Unable to update next action response'], 500);
}