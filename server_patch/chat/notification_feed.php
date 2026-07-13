<?php
declare(strict_types=1);
require_once __DIR__ . '/bootstrap.php';
require_once __DIR__ . '/notification_helpers.php';

$session = chat_require_user();
$empId = (int)$session['emp_id'];
$pdo = chat_db();
notification_materialize_due($pdo);

$summary = ($_GET['summary'] ?? '') === '1';
if ($summary) {
    $stmt = $pdo->prepare(
        'SELECT id, title, body, created_at,
                (SELECT COUNT(*) FROM xmpp_notification_events u
                 WHERE u.emp_id = :unread_emp AND u.viewed_at IS NULL) AS unread_count
         FROM xmpp_notification_events
         WHERE emp_id = :emp ORDER BY id DESC LIMIT 1'
    );
    $stmt->execute([':unread_emp' => $empId, ':emp' => $empId]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC) ?: [];
    chat_json([
        'status' => true,
        'last' => (string)($row['body'] ?? 'Your private system notifications'),
        'time' => (string)($row['created_at'] ?? ''),
        'unread_count' => (int)($row['unread_count'] ?? 0),
    ]);
}

$stmt = $pdo->prepare(
    'SELECT id, event_type, title, body, created_at, viewed_at
     FROM xmpp_notification_events
     WHERE emp_id = :emp ORDER BY id ASC LIMIT 500'
);
$stmt->execute([':emp' => $empId]);
$rows = $stmt->fetchAll(PDO::FETCH_ASSOC) ?: [];
$messages = array_map(static function(array $row) use ($empId): array {
    return [
        'id' => (string)$row['id'],
        'from' => SKYCHAT_SYSTEM_NOTIFICATION_JID,
        'to' => chat_jid($empId),
        'body' => (string)$row['body'],
        'side' => 'them',
        'status' => $row['viewed_at'] ? 'read' : 'delivered',
        'created_at' => (string)$row['created_at'],
        'time' => date('H:i', strtotime((string)$row['created_at']) ?: time()),
        'sender_name' => 'Notifications',
        'source_device' => 'system',
        'source_name' => ucfirst((string)$row['event_type']),
        'message_type' => 'chat',
    ];
}, $rows);
if (($_GET['peek'] ?? '') !== '1' && $rows) {
    $pdo->prepare(
        'UPDATE xmpp_notification_events SET viewed_at = NOW()
         WHERE emp_id = :emp AND viewed_at IS NULL'
    )->execute([':emp' => $empId]);
}
chat_json(['status' => true, 'messages' => $messages]);