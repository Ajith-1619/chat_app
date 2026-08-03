<?php
declare(strict_types=1);

require_once __DIR__ . '/_bootstrap.php';
require_once __DIR__ . '/archive_storage_helper.php';

try {
    $adminPdo = flow_admin_db();
    archive_storage_ensure_schema($adminPdo);
    $scheduled = archive_storage_schedule_policies($adminPdo);
    $results = archive_storage_process_due_jobs($adminPdo, 5);
    header('Content-Type: application/json');
    echo json_encode([
        'status' => true,
        'scheduled' => $scheduled,
        'results' => $results,
        'processed' => count($results),
    ], JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
} catch (Throwable $e) {
    http_response_code(500);
    header('Content-Type: application/json');
    echo json_encode([
        'status' => false,
        'error' => $e->getMessage(),
    ], JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
}
