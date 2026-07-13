<?php
declare(strict_types=1);
require_once __DIR__ . '/bootstrap.php';

$session = chat_require_user();
$pdo = chat_db();
$empId = (int)$session['emp_id'];

if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    $jid = strtolower(trim((string)($_GET['jid'] ?? '')));
    if (!chat_is_user_jid($jid) && !chat_is_room_jid($jid)) {
        chat_json(['status' => false, 'error' => 'Valid conversation is required'], 422);
    }
    $draft = $pdo->prepare(
        'SELECT body, reply_to_id, updated_at FROM xmpp_drafts
         WHERE emp_id = :emp_id AND conversation_jid = :jid LIMIT 1'
    );
    $draft->execute([':emp_id' => $empId, ':jid' => $jid]);
    $position = $pdo->prepare(
        'SELECT message_id, updated_at FROM xmpp_read_positions
         WHERE emp_id = :emp_id AND conversation_jid = :jid LIMIT 1'
    );
    $position->execute([':emp_id' => $empId, ':jid' => $jid]);
    chat_json([
        'status' => true,
        'draft' => $draft->fetch(PDO::FETCH_ASSOC) ?: null,
        'read_position' => $position->fetch(PDO::FETCH_ASSOC) ?: null,
    ]);
}

$input = json_decode(file_get_contents('php://input') ?: '{}', true);
if (!is_array($input)) chat_json(['status' => false, 'error' => 'Invalid JSON'], 422);
$jid = strtolower(trim((string)($input['jid'] ?? '')));
$action = strtolower(trim((string)($input['action'] ?? '')));
if (!chat_is_user_jid($jid) && !chat_is_room_jid($jid)) {
    chat_json(['status' => false, 'error' => 'Valid conversation is required'], 422);
}
if ($action === 'draft') {
    $body = (string)($input['body'] ?? '');
    $replyToId = max(0, (int)($input['reply_to_id'] ?? 0));
    if (trim($body) === '') {
        $stmt = $pdo->prepare(
            'DELETE FROM xmpp_drafts WHERE emp_id = :emp_id AND conversation_jid = :jid'
        );
        $stmt->execute([':emp_id' => $empId, ':jid' => $jid]);
    } else {
        $stmt = $pdo->prepare(
            'INSERT INTO xmpp_drafts (emp_id, conversation_jid, body, reply_to_id)
             VALUES (:emp_id, :jid, :body, :reply_to_id)
             ON DUPLICATE KEY UPDATE body = VALUES(body), reply_to_id = VALUES(reply_to_id), updated_at = NOW()'
        );
        $stmt->execute([
            ':emp_id' => $empId,
            ':jid' => $jid,
            ':body' => mb_substr($body, 0, 12000),
            ':reply_to_id' => $replyToId > 0 ? $replyToId : null,
        ]);
    }
} elseif ($action === 'read_position') {
    $messageId = max(0, (int)($input['message_id'] ?? 0));
    $stmt = $pdo->prepare(
        'INSERT INTO xmpp_read_positions (emp_id, conversation_jid, message_id)
         VALUES (:emp_id, :jid, :message_id)
         ON DUPLICATE KEY UPDATE message_id = VALUES(message_id), updated_at = NOW()'
    );
    $stmt->execute([':emp_id' => $empId, ':jid' => $jid, ':message_id' => $messageId]);
} else {
    chat_json(['status' => false, 'error' => 'Unsupported action'], 422);
}
chat_json(['status' => true]);
