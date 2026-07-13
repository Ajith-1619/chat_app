<?php
declare(strict_types=1);
require_once __DIR__ . '/bootstrap.php';

$session = chat_require_user();
$pdo = chat_db();
chat_ensure_schema($pdo);
$stmt = $pdo->prepare(
    'SELECT g.id, g.room_name, g.room_jid, g.avatar_url, g.archived_at
     FROM xmpp_groups g
     INNER JOIN xmpp_group_members gm ON gm.group_id = g.id
     WHERE gm.emp_id = :emp_id
       AND g.group_type = \'channel\' AND g.is_archived = 1
     ORDER BY g.archived_at DESC'
);
$stmt->execute([':emp_id' => (int)$session['emp_id']]);
$channels = [];
foreach (($stmt->fetchAll(PDO::FETCH_ASSOC) ?: []) as $row) {
    $channels[] = [
        'type' => 'channel',
        'id' => (int)$row['id'],
        'name' => '#' . (string)$row['room_name'],
        'jid' => (string)$row['room_jid'],
        'avatar_url' => (string)($row['avatar_url'] ?? ''),
        'last' => 'Archived channel',
        'time' => (string)($row['archived_at'] ?? ''),
    ];
}
chat_json(['status' => true, 'channels' => $channels]);
