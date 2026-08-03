<?php
declare(strict_types=1);

require_once __DIR__ . '/bootstrap.php';
require_once __DIR__ . '/archive_storage_helper.php';

try {
    $viewer = chat_require_user();
    $itemIdOrConversation = trim((string)($_GET['item'] ?? $_GET['conversation_jid'] ?? $_POST['item'] ?? $_POST['conversation_jid'] ?? ''));
    if ($itemIdOrConversation === '') {
        throw new RuntimeException('Archived item id or conversation_jid is required.');
    }
    $pdo = flow_admin_db();
    chat_json(archive_storage_stream_manifest($pdo, (int)($viewer['emp_id'] ?? 0), $itemIdOrConversation));
} catch (Throwable $e) {
    chat_json([
        'status' => false,
        'error' => $e->getMessage(),
    ], 422);
}
