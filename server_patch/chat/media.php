<?php
declare(strict_types=1);
require_once __DIR__ . '/bootstrap.php';

$relative = rawurldecode(trim((string)($_GET['path'] ?? '')));
$relative = str_replace('\\', '/', $relative);
if ($relative === '' || str_contains($relative, '..') || !str_starts_with($relative, 'chat/')) {
    http_response_code(404);
    exit;
}

$root = realpath(dirname(__DIR__) . DIRECTORY_SEPARATOR . 'uploads');
$target = realpath(dirname(__DIR__) . DIRECTORY_SEPARATOR . 'uploads' . DIRECTORY_SEPARATOR . str_replace('/', DIRECTORY_SEPARATOR, $relative));
if ($root === false || $target === false || !str_starts_with($target, $root) || !is_file($target)) {
    http_response_code(404);
    exit;
}

$isDownload = (string)($_GET['download'] ?? '') === '1';
if ($isDownload) {
    try {
        $uploadPath = '%/uploads/' . str_replace('\\', '/', $relative);
        $pdo = chat_db();
        chat_ensure_column($pdo, 'xmpp_messages', 'file_restricted', 'TINYINT(1) NOT NULL DEFAULT 0 AFTER file_size');
        $stmt = $pdo->prepare(
            'SELECT id FROM xmpp_messages
             WHERE COALESCE(file_restricted, 0) = 1
               AND file_url LIKE :upload_path
             LIMIT 1'
        );
        $stmt->execute([':upload_path' => $uploadPath]);
        if ($stmt->fetchColumn()) {
            http_response_code(403);
            header('Content-Type: text/plain; charset=utf-8');
            echo 'Restricted files can only be viewed inside Flow.';
            exit;
        }
    } catch (Throwable $e) {
        error_log('restricted media download check skipped: ' . $e->getMessage());
    }
}

$meta = chat_upload_file_meta($target);
if (!empty($meta['encrypted'])) {
    $plain = chat_decrypt_upload_file($target);
    if ($plain === null) {
        http_response_code(403);
        exit;
    }
    $mime = trim((string)($meta['mime'] ?? 'application/octet-stream')) ?: 'application/octet-stream';
    $requestedName = trim((string)($_GET['name'] ?? ($meta['name'] ?? basename($target))));
    $requestedName = preg_replace('/[\x00-\x1F\x7F"\\\/]+/', '_', basename($requestedName)) ?: basename($target);
    $disposition = $isDownload ? 'attachment' : 'inline';
    header('Access-Control-Allow-Origin: *');
    header('Access-Control-Expose-Headers: Content-Length, Content-Type, Content-Disposition');
    header('Content-Disposition: ' . $disposition . '; filename="' . addcslashes($requestedName, '"\\') . '"; filename*=UTF-8\'\'' . rawurlencode($requestedName));
    header('X-Content-Type-Options: nosniff');
    header('Cross-Origin-Resource-Policy: cross-origin');
    header('Content-Type: ' . $mime);
    header('Content-Length: ' . strlen($plain));
    header('Cache-Control: private, max-age=3600');
    echo $plain;
    exit;
}
$mime = 'application/octet-stream';
if (function_exists('finfo_open')) {
    $finfo = finfo_open(FILEINFO_MIME_TYPE);
    if ($finfo !== false) {
        $detected = finfo_file($finfo, $target);
        if (is_string($detected) && $detected !== '') $mime = $detected;
        finfo_close($finfo);
    }
}

$requestedName = trim((string)($_GET['name'] ?? basename($target)));
$requestedName = preg_replace('/[\x00-\x1F\x7F"\\\/]+/', '_', basename($requestedName)) ?: basename($target);
$disposition = $isDownload ? 'attachment' : 'inline';

header('Access-Control-Allow-Origin: *');
header('Access-Control-Expose-Headers: Content-Length, Content-Type, Content-Disposition');
header('Content-Disposition: ' . $disposition . '; filename="' . addcslashes($requestedName, '"\\') . '"; filename*=UTF-8\'\'' . rawurlencode($requestedName));
header('X-Content-Type-Options: nosniff');
header('Cross-Origin-Resource-Policy: cross-origin');
header('Content-Type: ' . $mime);
header('Content-Length: ' . filesize($target));
header('Cache-Control: public, max-age=86400');
readfile($target);
