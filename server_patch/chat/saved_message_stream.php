<?php
declare(strict_types=1);

require_once __DIR__ . '/bootstrap.php';
require_once __DIR__ . '/archive_storage_helper.php';

try {
    $session = chat_require_user();
    $pdo = chat_db();
    chat_ensure_schema($pdo);
    archive_storage_ensure_schema($pdo);
    $empId = (int)$session['emp_id'];
    $messageId = (int)($_GET['id'] ?? 0);
    if ($messageId <= 0) {
        http_response_code(404);
        exit('Saved file not found.');
    }

    $stmt = $pdo->prepare(
        'SELECT *
         FROM xmpp_saved_messages
         WHERE id = :id AND emp_id = :emp_id
         LIMIT 1'
    );
    $stmt->execute([':id' => $messageId, ':emp_id' => $empId]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!is_array($row)) {
        http_response_code(404);
        exit('Saved file not found.');
    }

    $storageMode = trim((string)($row['storage_mode'] ?? 'database'));
    $driveFileId = trim((string)($row['drive_file_id'] ?? ''));
    if ($storageMode !== 'drive' || $driveFileId === '') {
        $fallbackUrl = trim((string)($row['file_url'] ?? ''));
        if ($fallbackUrl !== '') {
            header('Location: ' . $fallbackUrl, true, 302);
            exit;
        }
        http_response_code(404);
        exit('Saved file is not available.');
    }

    $providerId = (int)($row['drive_provider_id'] ?? 0);
    $providerStmt = $pdo->prepare('SELECT * FROM flow_archive_providers WHERE id = :id LIMIT 1');
    $providerStmt->execute([':id' => $providerId]);
    $provider = $providerStmt->fetch(PDO::FETCH_ASSOC);
    if (!is_array($provider)) {
        http_response_code(500);
        exit('Saved file provider is missing.');
    }

    $token = archive_storage_provider_access_token($pdo, $provider);
    $bytes = archive_storage_download_google_file($token, $driveFileId);

    $name = trim((string)($row['file_name'] ?? ''));
    if ($name === '') {
        $name = 'saved-file';
    }
    $mimeType = trim((string)($row['drive_mime_type'] ?? $row['file_type'] ?? '')) ?: 'application/octet-stream';
    $download = !empty($_GET['download']);
    $disposition = $download ? 'attachment' : 'inline';

    header('Content-Type: ' . $mimeType);
    header('Content-Length: ' . strlen($bytes));
    header('Content-Disposition: ' . $disposition . '; filename="' . addslashes($name) . '"');
    header('Cache-Control: private, max-age=300');
    echo $bytes;
} catch (Throwable $error) {
    error_log('saved_message_stream endpoint failed: ' . $error->getMessage());
    http_response_code(500);
    exit('Unable to stream saved file.');
}

