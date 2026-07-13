<?php
declare(strict_types=1);
require_once __DIR__ . '/bootstrap.php';

$session = chat_require_user();
$input = json_decode(file_get_contents('php://input') ?: '{}', true);
if (!is_array($input)) chat_json(['status' => false, 'error' => 'Invalid JSON'], 422);
$messageId = (int)($input['message_id'] ?? 0);
$body = trim((string)($input['message'] ?? ''));
if ($messageId <= 0 || $body === '' || mb_strlen($body) > 4000) {
    chat_json(['status' => false, 'error' => 'Valid message and text are required'], 422);
}
try {
    $pdo = chat_db();
    chat_ensure_schema($pdo);
    $stmt = $pdo->prepare(
        'UPDATE xmpp_messages
         SET body = :body, edited_at = NOW()
         WHERE id = :id AND from_jid = :from_jid AND deleted_at IS NULL'
    );
    $stmt->execute([
        ':body' => $body,
        ':id' => $messageId,
        ':from_jid' => chat_jid((int)$session['emp_id']),
    ]);
    if ($stmt->rowCount() !== 1) {
        chat_json(['status' => false, 'error' => 'Message cannot be edited'], 403);
    }
    chat_json(['status' => true, 'message_id' => $messageId, 'edited_at' => date('c')]);
} catch (Throwable $e) {
    error_log('chat/edit_message failed: ' . $e->getMessage());
    chat_json(['status' => false, 'error' => 'Unable to edit message'], 500);
}
