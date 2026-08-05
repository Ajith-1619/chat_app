<?php
declare(strict_types=1);

// Run under the chat bootstrap on live deployments when its deployment-owned
// config files are present. For exported/local contexts where those files do not
// exist, fall back to the admin standalone bootstrap. If chat bootstrap is active,
// expose a minimal flow_admin_db() adapter so archive helpers do not depend on the
// admin tree being deployed in the same relative location.
$chatBootstrap = __DIR__ . '/bootstrap.php';
$chatConfig = __DIR__ . '/../config.php';
$chatDb = __DIR__ . '/../db.php';
$adminBootstrap = __DIR__ . '/../../admin/legacy_standalone/_bootstrap.php';

if (is_file($chatBootstrap) && is_file($chatConfig) && is_file($chatDb)) {
    require_once $chatBootstrap;
    if (!function_exists('flow_admin_db')) {
        if (function_exists('chat_db')) {
            function flow_admin_db(): PDO { return chat_db(); }
        } elseif (function_exists('getDB')) {
            function flow_admin_db(): PDO { return getDB(); }
        }
    }
} elseif (is_file($adminBootstrap)) {
    require_once $adminBootstrap;
}

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
