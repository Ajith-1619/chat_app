<?php
declare(strict_types=1);

require_once __DIR__ . '/bootstrap.php';
require_once __DIR__ . '/ai_room_helper.php';

try {
    if (PHP_SAPI !== 'cli') {
        http_response_code(404);
        exit;
    }
    $messageId = max(0, (int)($argv[1] ?? 0));
    if ($messageId <= 0) exit(0);
    $pdo = chat_db();
    chat_ensure_schema($pdo);
    $stmt = $pdo->prepare("SELECT m.id, m.body, m.to_jid, m.from_jid, g.id AS group_id, g.room_jid, g.room_name, g.description
        FROM xmpp_messages m
        INNER JOIN xmpp_groups g ON g.room_jid = m.to_jid
        WHERE m.id = :id
          AND m.deleted_at IS NULL
          AND m.file_url IS NULL
          AND COALESCE(m.visibility_mode, 'all') = 'all'
        LIMIT 1");
    $stmt->execute([':id' => $messageId]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC) ?: null;
    if (!$row || trim((string)($row['body'] ?? '')) === '') exit(0);
    chat_try_send_ai_room_reply(
        $pdo,
        [
            'id' => (int)$row['group_id'],
            'room_jid' => (string)$row['room_jid'],
            'room_name' => (string)$row['room_name'],
            'description' => (string)($row['description'] ?? ''),
        ],
        $messageId,
        (string)$row['body']
    );
} catch (Throwable $e) {
    error_log('ai_room_worker failed: ' . $e->getMessage());
    if (PHP_SAPI === 'cli') {
        fwrite(STDERR, 'ai_room_worker failed: ' . $e->getMessage() . PHP_EOL);
    }
}
