<?php
declare(strict_types=1);
require_once __DIR__ . '/bootstrap.php';

$session = chat_require_user();
$traceId = trim((string)($_SERVER['HTTP_X_SKYLINK_TRACE_ID'] ?? 'upload-' . bin2hex(random_bytes(8))));
$traceStarted = microtime(true);
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    chat_json(['status' => false, 'error' => 'POST is required'], 405);
}
if (!isset($_FILES['file']) || !is_array($_FILES['file'])) {
    chat_json(['status' => false, 'error' => 'File is required'], 422);
}

$file = $_FILES['file'];
$error = (int)($file['error'] ?? UPLOAD_ERR_NO_FILE);
if ($error !== UPLOAD_ERR_OK) {
    $limits = 'upload_max_filesize=' . ini_get('upload_max_filesize') . ', post_max_size=' . ini_get('post_max_size');
    $messages = [
        UPLOAD_ERR_INI_SIZE => 'The file is larger than the server upload limit.',
        UPLOAD_ERR_FORM_SIZE => 'The file is larger than the form upload limit.',
        UPLOAD_ERR_PARTIAL => 'The file upload was interrupted before completion.',
        UPLOAD_ERR_NO_FILE => 'No file was received by the server.',
        UPLOAD_ERR_NO_TMP_DIR => 'The server upload temp folder is missing.',
        UPLOAD_ERR_CANT_WRITE => 'The server could not write the uploaded file.',
        UPLOAD_ERR_EXTENSION => 'A server extension blocked the upload.',
    ];
    chat_json([
        'status' => false,
        'error' => ($messages[$error] ?? ('Upload failed with code ' . $error)) . ' ' . $limits,
        'upload_error_code' => $error,
        'upload_max_filesize' => ini_get('upload_max_filesize'),
        'post_max_size' => ini_get('post_max_size'),
    ], 422);
}
$size = (int)($file['size'] ?? 0);
if ($size <= 0) {
    chat_json(['status' => false, 'error' => 'File must be at least 1 byte.'], 422);
}
$maxUploadBytes = 50 * 1024 * 1024;
if ($size > $maxUploadBytes) {
    chat_json([
        'status' => false,
        'error' => 'File is too large. Maximum allowed size is 50 MB.',
        'max_upload_bytes' => $maxUploadBytes,
    ], 413);
}

$pdo = chat_db();
chat_assert_storage_quota($pdo, (int)$session['emp_id'], $size);

$original = trim((string)($file['name'] ?? 'file'));
$safeName = preg_replace('/[^A-Za-z0-9._-]+/', '_', basename($original)) ?: 'file';
$extension = strtolower(pathinfo($safeName, PATHINFO_EXTENSION));
$storedName = bin2hex(random_bytes(16)) . ($extension !== '' ? '.' . $extension : '');
$relativeDir = 'uploads/chat/' . (int)$session['emp_id'] . '/' . date('Y/m');
$root = dirname(__DIR__);
$targetDir = $root . DIRECTORY_SEPARATOR . str_replace('/', DIRECTORY_SEPARATOR, $relativeDir);
if (!is_dir($targetDir) && !mkdir($targetDir, 0775, true) && !is_dir($targetDir)) {
    chat_json(['status' => false, 'error' => 'Upload directory is unavailable'], 500);
}
$target = $targetDir . DIRECTORY_SEPARATOR . $storedName;
if (!move_uploaded_file((string)$file['tmp_name'], $target)) {
    chat_json(['status' => false, 'error' => 'Unable to store uploaded file'], 500);
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
$plainSize = $size;
if (str_starts_with(strtolower($mime), 'audio/')) {
    $encryptedTarget = $target . '.enc';
    if (chat_encrypt_upload_file($target, $encryptedTarget, $mime, $original)) {
        @unlink($target);
        $target = $encryptedTarget;
        $storedName .= '.enc';
    }
}
$scheme = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
$host = trim((string)($_SERVER['HTTP_HOST'] ?? ''));
$scriptDir = rtrim(str_replace('\\', '/', dirname((string)($_SERVER['SCRIPT_NAME'] ?? '/chat/upload_file.php'))), '/');
$baseDir = preg_replace('#/chat$#', '', $scriptDir) ?: '';
$url = $scheme . '://' . $host . $baseDir . '/' . $relativeDir . '/' . rawurlencode($storedName);

chat_diagnostic_trace((int)$session['emp_id'], $traceId, 'file_transfer', 'api_upload', (microtime(true) - $traceStarted) * 1000, 'success', ['size' => $plainSize, 'mime' => $mime]);
chat_json([
    'status' => true,
    'url' => chat_public_upload_url($url),
    'name' => $original,
    'mime_type' => $mime,
    'size' => $plainSize,
]);


