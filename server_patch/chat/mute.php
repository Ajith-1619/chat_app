<?php
declare(strict_types=1);
require_once __DIR__ . '/bootstrap.php';

$session = chat_require_user();
$input = json_decode(file_get_contents('php://input') ?: '{}', true);
if (!is_array($input)) chat_json(['status' => false, 'error' => 'Invalid JSON'], 422);
$target = strtolower(trim((string)($input['jid'] ?? '')));
$muted = (bool)($input['muted'] ?? true);
if (!chat_is_user_jid($target) && !chat_is_room_jid($target)) {
    chat_json(['status' => false, 'error' => 'Valid chat JID is required'], 422);
}
$pdo = chat_db();
chat_ensure_schema($pdo);
if ($muted) {
    $stmt = $pdo->prepare(
        'INSERT INTO xmpp_mutes (emp_id, target_jid, muted_until)
         VALUES (:emp_id, :target_jid, NULL)
         ON DUPLICATE KEY UPDATE muted_until = NULL'
    );
    $stmt->execute([':emp_id' => (int)$session['emp_id'], ':target_jid' => $target]);
} else {
    $stmt = $pdo->prepare('DELETE FROM xmpp_mutes WHERE emp_id = :emp_id AND target_jid = :target_jid');
    $stmt->execute([':emp_id' => (int)$session['emp_id'], ':target_jid' => $target]);
}
chat_json(['status' => true, 'muted' => $muted]);
