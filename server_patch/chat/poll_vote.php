<?php
declare(strict_types=1);
require_once __DIR__ . '/bootstrap.php';

$session = chat_require_user();
$input = json_decode(file_get_contents('php://input') ?: '{}', true);
if (!is_array($input)) chat_json(['status' => false, 'error' => 'Invalid JSON'], 422);
$messageId = (int)($input['message_id'] ?? 0);
$optionIndex = (int)($input['option_index'] ?? -1);
if ($messageId <= 0 || $optionIndex < 0) {
    chat_json(['status' => false, 'error' => 'Valid poll message and option are required'], 422);
}

try {
    $pdo = chat_db();
    chat_ensure_schema($pdo);
    $me = chat_jid((int)$session['emp_id']);
    $stmt = $pdo->prepare('SELECT * FROM xmpp_messages WHERE id = :id AND deleted_at IS NULL LIMIT 1');
    $stmt->execute([':id' => $messageId]);
    $message = $stmt->fetch(PDO::FETCH_ASSOC) ?: [];
    if (!$message) chat_json(['status' => false, 'error' => 'Poll not found'], 404);
    $to = (string)$message['to_jid'];
    $from = (string)$message['from_jid'];
    if (chat_is_room_jid($to)) {
        if (!chat_group_for_member($pdo, $to, (int)$session['emp_id'])) {
            chat_json(['status' => false, 'error' => 'You are not a participant in this poll'], 403);
        }
    } elseif ($to !== $me && $from !== $me) {
        chat_json(['status' => false, 'error' => 'You are not a participant in this poll'], 403);
    }
    $prefix = 'SKYLINK_POLL:';
    $body = (string)$message['body'];
    if (!str_starts_with($body, $prefix)) chat_json(['status' => false, 'error' => 'Message is not a poll'], 422);
    $poll = json_decode(substr($body, strlen($prefix)), true);
    if (!is_array($poll) || !isset($poll['options']) || !is_array($poll['options']) || !isset($poll['options'][$optionIndex])) {
        chat_json(['status' => false, 'error' => 'Poll option not found'], 404);
    }
    $allowMultiple = !empty($poll['allow_multiple']);
    foreach ($poll['options'] as $idx => &$option) {
        if (!isset($option['votes']) || !is_array($option['votes'])) $option['votes'] = [];
        $option['votes'] = array_values(array_unique(array_map('intval', $option['votes'])));
        $hasVote = in_array((int)$session['emp_id'], $option['votes'], true);
        if ($idx === $optionIndex) {
            if ($hasVote) {
                $option['votes'] = array_values(array_filter($option['votes'], static fn(int $id): bool => $id !== (int)$session['emp_id']));
            } else {
                $option['votes'][] = (int)$session['emp_id'];
            }
        } elseif (!$allowMultiple) {
            $option['votes'] = array_values(array_filter($option['votes'], static fn(int $id): bool => $id !== (int)$session['emp_id']));
        }
    }
    unset($option);
    $poll['updated_at'] = date(DATE_ATOM);
    $updatedBody = $prefix . json_encode($poll, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    $update = $pdo->prepare('UPDATE xmpp_messages SET body = :body, edited_at = NOW() WHERE id = :id');
    $update->execute([':body' => $updatedBody, ':id' => $messageId]);
    chat_json(['status' => true, 'message_id' => $messageId, 'poll' => $poll]);
} catch (Throwable $e) {
    error_log('chat/poll_vote failed: ' . $e->getMessage());
    chat_json(['status' => false, 'error' => 'Unable to update poll'], 500);
}
