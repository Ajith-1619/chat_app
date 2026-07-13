<?php
declare(strict_types=1);
require_once __DIR__ . '/bootstrap.php';

$session = chat_require_user();
$input = json_decode(file_get_contents('php://input') ?: '{}', true);
if (!is_array($input)) chat_json(['status' => false, 'error' => 'Invalid JSON'], 422);
$jid = strtolower(trim((string)($input['jid'] ?? '')));
if (!chat_is_user_jid($jid) && !chat_is_room_jid($jid)) {
    chat_json(['status' => false, 'error' => 'Valid chat JID is required'], 422);
}
$pinned = (bool)($input['pinned'] ?? false);
$starred = (bool)($input['starred'] ?? false);
$pdo = chat_db();
chat_ensure_schema($pdo);
if ($pinned) {
    $count = $pdo->prepare(
        'SELECT COUNT(*) FROM xmpp_conversation_preferences
         WHERE emp_id = :emp_id AND is_pinned = 1 AND target_jid <> :target_jid'
    );
    $count->execute([
        ':emp_id' => (int)$session['emp_id'],
        ':target_jid' => $jid,
    ]);
    if ((int)$count->fetchColumn() >= 10) {
        chat_json(['status' => false, 'error' => 'You can pin a maximum of 10 chats'], 422);
    }
}
$stmt = $pdo->prepare(
    'INSERT INTO xmpp_conversation_preferences (emp_id, target_jid, is_pinned, is_starred)
     VALUES (:emp_id, :jid, :pinned, :starred)
     ON DUPLICATE KEY UPDATE is_pinned = VALUES(is_pinned), is_starred = VALUES(is_starred)'
);
$stmt->execute([
    ':emp_id' => (int)$session['emp_id'],
    ':jid' => $jid,
    ':pinned' => $pinned ? 1 : 0,
    ':starred' => $starred ? 1 : 0,
]);
chat_json(['status' => true, 'pinned' => $pinned, 'starred' => $starred]);
