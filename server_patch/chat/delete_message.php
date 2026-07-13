<?php
declare(strict_types=1);
require_once __DIR__ . '/bootstrap.php';

$session = chat_require_user();
$input = json_decode(file_get_contents('php://input') ?: '{}', true);
if (!is_array($input)) chat_json(['status' => false, 'error' => 'Invalid JSON'], 422);
$messageId = (int)($input['message_id'] ?? 0);
if ($messageId <= 0) chat_json(['status' => false, 'error' => 'Message id is required'], 422);

try {
    $pdo = chat_db();
    chat_ensure_schema($pdo);
    $stmt = $pdo->prepare(
        'UPDATE xmpp_messages
         SET deleted_at = NOW(), body = \'\', file_url = NULL, file_name = NULL, file_type = NULL
         WHERE id = :id AND from_jid = :from_jid AND deleted_at IS NULL'
    );
    $stmt->execute([':id' => $messageId, ':from_jid' => chat_jid((int)$session['emp_id'])]);
    if ($stmt->rowCount() !== 1) {
        chat_json(['status' => false, 'error' => 'Message cannot be unsent'], 403);
    }
    chat_json(['status' => true, 'message_id' => $messageId]);
} catch (Throwable $e) {
    error_log('chat/delete_message failed: ' . $e->getMessage());
    chat_json(['status' => false, 'error' => 'Unable to unsend message'], 500);
}
