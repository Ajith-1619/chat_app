<?php
declare(strict_types=1);

require_once __DIR__ . '/bootstrap.php';
require_once __DIR__ . '/archive_storage_helper.php';

try {
    $viewer = chat_require_user();
    $query = trim((string)($_GET['q'] ?? $_POST['q'] ?? ''));
    $pdo = flow_admin_db();
    chat_json(archive_storage_search_for_user($pdo, (int)($viewer['emp_id'] ?? 0), $query));
} catch (Throwable $e) {
    chat_json([
        'status' => false,
        'error' => $e->getMessage(),
    ], 422);
}
