<?php
declare(strict_types=1);

require_once __DIR__ . '/bootstrap.php';
require_once __DIR__ . '/archive_storage_helper.php';

function saved_messages_base_url(string $scriptName): string
{
    $scheme = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
    $host = trim((string)($_SERVER['HTTP_HOST'] ?? ''));
    $scriptDir = rtrim(str_replace('\\', '/', dirname((string)($_SERVER['SCRIPT_NAME'] ?? '/chat/saved_messages.php'))), '/');
    $baseDir = preg_replace('#/chat$#', '', $scriptDir) ?: '';
    return $scheme . '://' . $host . $baseDir . '/chat/' . ltrim($scriptName, '/');
}

function saved_messages_proxy_url(int $messageId): string
{
    return saved_messages_base_url('saved_message_stream.php') . '?id=' . $messageId;
}

function saved_messages_active_provider(PDO $pdo): ?array
{
    archive_storage_ensure_schema($pdo);
    $stmt = $pdo->query(
        "SELECT *
         FROM flow_archive_providers
         WHERE status = 1
           AND provider_key = 'google_drive'
           AND (COALESCE(refresh_token, '') <> '' OR COALESCE(access_token, '') <> '')
         ORDER BY updated_at DESC, id DESC
         LIMIT 1"
    );
    $provider = $stmt ? $stmt->fetch(PDO::FETCH_ASSOC) : false;
    return is_array($provider) ? $provider : null;
}

function saved_messages_provider_root_folder(PDO $pdo, array $provider): array
{
    $token = archive_storage_provider_access_token($pdo, $provider);
    $rootFolderId = trim((string)($provider['root_folder_id'] ?? ''));
    if ($rootFolderId === '') {
        $rootName = trim((string)($provider['root_folder_path'] ?? 'Flow Archive'));
        if ($rootName === '') {
            $rootName = 'Flow Archive';
        }
        $root = archive_storage_google_create_folder($token, $rootName);
        $rootFolderId = (string)($root['id'] ?? '');
        if ($rootFolderId === '') {
            throw new RuntimeException('Archive root folder was not created in Google Drive.');
        }
        $pdo->prepare('UPDATE flow_archive_providers SET root_folder_id = :root_folder_id, updated_at = NOW() WHERE id = :id')
            ->execute([
                ':root_folder_id' => $rootFolderId,
                ':id' => (int)($provider['id'] ?? 0),
            ]);
        $provider['root_folder_id'] = $rootFolderId;
    }
    return [$provider, $token, $rootFolderId];
}

function saved_messages_drive_folder(PDO $pdo, array $provider, int $empId): array
{
    [$provider, $token, $rootFolderId] = saved_messages_provider_root_folder($pdo, $provider);
    $folder = archive_storage_google_ensure_folder_path(
        $token,
        $rootFolderId,
        ['Flow Saved Messages', (string)$empId, date('Y'), date('m')]
    );
    return [
        'provider' => $provider,
        'token' => $token,
        'folder_id' => (string)($folder['folder_id'] ?? ''),
        'folder_path' => trim((string)($folder['folder_path'] ?? ''), '/'),
    ];
}

function saved_messages_normalize_relative_upload_path(string $value): string
{
    $relative = trim(str_replace('\\', '/', $value));
    $relative = preg_replace('#^/+?#', '', $relative) ?? '';
    if ($relative === '') {
        return '';
    }
    if (str_starts_with($relative, 'uploads/')) {
        $relative = substr($relative, strlen('uploads/'));
    }
    if ($relative === '' || str_contains($relative, '..')) {
        return '';
    }
    return ltrim($relative, '/');
}

function saved_messages_relative_upload_path(string $url): string
{
    $value = trim($url);
    if ($value === '') {
        return '';
    }
    if (!str_contains($value, '://') && !str_contains($value, '?')) {
        return saved_messages_normalize_relative_upload_path($value);
    }

    $query = parse_url($value, PHP_URL_QUERY);
    if (is_string($query) && $query !== '') {
        $params = [];
        parse_str($query, $params);
        $candidate = trim((string)($params['path'] ?? $params['file'] ?? ''));
        if ($candidate !== '') {
            return saved_messages_normalize_relative_upload_path($candidate);
        }
    }

    $path = parse_url($value, PHP_URL_PATH);
    if (!is_string($path) || $path === '') {
        return '';
    }
    $needle = '/uploads/';
    $pos = strpos($path, $needle);
    if ($pos === false) {
        return '';
    }
    return saved_messages_normalize_relative_upload_path(substr($path, $pos + strlen($needle)));
}

function saved_messages_cleanup_upload(string $relativePath): void
{
    if ($relativePath === '') {
        return;
    }
    $path = archive_storage_resolve_local_upload_path($relativePath);
    if ($path && is_file($path)) {
        @unlink($path);
    }
}

function saved_messages_drive_text_payload(int $empId, string $body): string
{
    return json_encode([
        'kind' => 'saved_message',
        'emp_id' => $empId,
        'body' => $body,
        'created_at' => gmdate('c'),
    ], JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE) ?: '{}';
}

function saved_messages_drive_allowed_emp(int $empId): bool
{
    return in_array($empId, [302, 232, 78, 116, 553, 218], true);
}

function saved_messages_has_column(PDO $pdo, string $column): bool
{
    $stmt = $pdo->prepare(
        'SELECT COUNT(*)
         FROM INFORMATION_SCHEMA.COLUMNS
         WHERE TABLE_SCHEMA = DATABASE()
           AND TABLE_NAME = :table_name
           AND COLUMN_NAME = :column_name'
    );
    $stmt->execute([
        ':table_name' => 'xmpp_saved_messages',
        ':column_name' => $column,
    ]);
    return ((int)$stmt->fetchColumn()) > 0;
}
function saved_messages_ensure_archive_columns(PDO $pdo): void
{
    $columns = [
        'storage_mode' => "VARCHAR(20) NOT NULL DEFAULT 'database' AFTER file_type",
        'drive_provider_id' => 'BIGINT NULL AFTER storage_mode',
        'drive_file_id' => 'VARCHAR(255) NULL AFTER drive_provider_id',
        'drive_folder_id' => 'VARCHAR(255) NULL AFTER drive_file_id',
        'drive_payload_type' => "VARCHAR(20) NOT NULL DEFAULT 'message' AFTER drive_folder_id",
        'drive_mime_type' => 'VARCHAR(160) NULL AFTER drive_payload_type',
        'drive_size_bytes' => 'BIGINT NOT NULL DEFAULT 0 AFTER drive_mime_type',
        'metadata_json' => 'LONGTEXT NULL AFTER drive_size_bytes',
    ];
    foreach ($columns as $column => $definition) {
        if (!saved_messages_has_column($pdo, $column)) {
            $pdo->exec("ALTER TABLE `xmpp_saved_messages` ADD COLUMN `$column` $definition");
        }
    }
}

function saved_messages_utf8_safe(mixed $value): mixed
{
    if (is_array($value)) {
        foreach ($value as $key => $child) {
            $value[$key] = saved_messages_utf8_safe($child);
        }
        return $value;
    }
    if (!is_string($value)) {
        return $value;
    }
    if ($value === '') {
        return '';
    }
    if (preg_match('//u', $value) === 1) {
        return $value;
    }
    if (function_exists('iconv')) {
        $converted = @iconv('UTF-8', 'UTF-8//IGNORE', $value);
        if (is_string($converted) && preg_match('//u', $converted) === 1) {
            return $converted;
        }
    }
    $clean = preg_replace('/[^\x09\x0A\x0D\x20-\x7E]/', '', $value);
    return is_string($clean) ? $clean : '';
}

function saved_messages_output_row(array $message): array
{
    $storageMode = trim((string)($message['storage_mode'] ?? 'database'));
    $driveFileId = trim((string)($message['drive_file_id'] ?? ''));
    $payloadType = trim((string)($message['drive_payload_type'] ?? 'message'));
    if ($storageMode === 'drive' && $driveFileId !== '' && $payloadType === 'file') {
        $message['file_url'] = saved_messages_proxy_url((int)($message['id'] ?? 0));
        if (trim((string)($message['file_type'] ?? '')) === '') {
            $message['file_type'] = trim((string)($message['drive_mime_type'] ?? ''));
        }
    }
    unset($message['storage_mode'], $message['drive_file_id'], $message['drive_payload_type'], $message['drive_mime_type']);
    return saved_messages_utf8_safe($message);
}

try {
    $session = chat_require_user();
    $pdo = chat_db();
    chat_ensure_schema($pdo);
    saved_messages_ensure_archive_columns($pdo);
    $empId = (int)$session['emp_id'];

    if ($_SERVER['REQUEST_METHOD'] === 'GET') {
        $selectColumns = ['id', 'body', 'file_url', 'file_name', 'file_type', 'created_at'];
        foreach (['storage_mode', 'drive_file_id', 'drive_payload_type', 'drive_mime_type'] as $optionalColumn) {
            if (saved_messages_has_column($pdo, $optionalColumn)) {
                $selectColumns[] = $optionalColumn;
            }
        }

        $isRsm = strtolower(trim((string)($_GET['scope'] ?? ''))) === 'rsm';
        if ($isRsm && !in_array($empId, [302, 116], true)) {
            chat_json(['status' => false, 'error' => 'RSM is restricted to employees 302 and 116.'], 403);
        }
        if ($isRsm) {
            $selectColumns[] = 'emp_id AS saved_by_emp_id';
            $stmt = $pdo->prepare(
                'SELECT ' . implode(', ', $selectColumns) . '
                 FROM xmpp_saved_messages
                 WHERE emp_id IN (302, 116)
                 ORDER BY id DESC LIMIT 400'
            );
            $stmt->execute();
        } else {
            $stmt = $pdo->prepare(
                'SELECT ' . implode(', ', $selectColumns) . '
                 FROM xmpp_saved_messages
                 WHERE emp_id = :emp_id
                 ORDER BY id DESC LIMIT 200'
            );
            $stmt->execute([':emp_id' => $empId]);
        }        $messages = $stmt->fetchAll(PDO::FETCH_ASSOC) ?: [];
        $messages = array_map('saved_messages_output_row', $messages);
        chat_json(['status' => true, 'messages' => $messages]);
    }

    $input = json_decode(file_get_contents('php://input') ?: '{}', true);
    if (!is_array($input)) {
        chat_json(['status' => false, 'error' => 'Invalid JSON'], 422);
    }

    $body = trim((string)($input['message'] ?? ''));
    $fileUrl = trim((string)($input['file_url'] ?? ''));
    $fileName = trim((string)($input['file_name'] ?? ''));
    $fileType = trim((string)($input['file_type'] ?? ''));
    if ($body === '' && $fileUrl === '') {
        chat_json(['status' => false, 'error' => 'Message or file is required'], 422);
    }

    $storageMode = 'database';
    $driveProviderId = null;
    $driveFileId = null;
    $driveFolderId = null;
    $drivePayloadType = $fileUrl !== '' ? 'file' : 'message';
    $driveMimeType = null;
    $driveSizeBytes = 0;
    $metadata = [];
    $persistedFileUrl = $fileUrl !== '' ? $fileUrl : null;
    try {
        $hasArchiveColumns = saved_messages_has_column($pdo, 'storage_mode');
        $driveAllowed = saved_messages_drive_allowed_emp($empId);
        $driveResult = $driveAllowed ? 'provider_not_connected' : 'employee_not_allowlisted';
        if (!$hasArchiveColumns) {
            $driveResult = 'archive_columns_missing';
        }
        $provider = ($hasArchiveColumns && $driveAllowed) ? saved_messages_active_provider($pdo) : null;
        if ($provider) {
            $driveResult = 'drive';
            $folder = saved_messages_drive_folder($pdo, $provider, $empId);
            $providerId = (int)($provider['id'] ?? 0);
            if ($fileUrl !== '') {
                $relativePath = saved_messages_relative_upload_path($fileUrl);
                $localPath = $relativePath !== '' ? archive_storage_resolve_local_upload_path($relativePath) : null;
                if ($localPath && is_file($localPath)) {
                    $resolvedName = $fileName !== '' ? $fileName : basename($localPath);
                    $resolvedType = $fileType !== '' ? $fileType : 'application/octet-stream';
                    $uploaded = archive_storage_google_upload_file(
                        $folder['token'],
                        $folder['folder_id'],
                        $resolvedName,
                        $localPath,
                        $resolvedType
                    );
                    $storageMode = 'drive';
                    $driveProviderId = $providerId;
                    $driveFileId = trim((string)($uploaded['id'] ?? '')) ?: null;
                    $driveFolderId = $folder['folder_id'];
                    $drivePayloadType = 'file';
                    $driveMimeType = $resolvedType;
                    $driveSizeBytes = max(0, (int)filesize($localPath));
                    $metadata = [
                        'caption' => $body,
                        'original_relative_path' => $relativePath,
                        'folder_path' => $folder['folder_path'],
                        'drive_name' => (string)($uploaded['name'] ?? $resolvedName),
                        'web_view_link' => (string)($uploaded['webViewLink'] ?? ''),
                    ];
                    $persistedFileUrl = null;
                    saved_messages_cleanup_upload($relativePath);
                } else {
                    $metadata['drive_skip_reason'] = 'upload_path_not_resolved';
                    $metadata['original_file_url'] = $fileUrl;
                }
            } elseif ($body !== '') {
                $textPayload = saved_messages_drive_text_payload($empId, $body);
                $textName = 'saved-note-' . gmdate('Ymd-His') . '-' . bin2hex(random_bytes(4)) . '.json';
                $uploaded = archive_storage_google_upload_bytes(
                    $folder['token'],
                    $folder['folder_id'],
                    $textName,
                    $textPayload,
                    'application/json'
                );
                $storageMode = 'drive';
                $driveProviderId = $providerId;
                $driveFileId = trim((string)($uploaded['id'] ?? '')) ?: null;
                $driveFolderId = $folder['folder_id'];
                $drivePayloadType = 'message';
                $driveMimeType = 'application/json';
                $driveSizeBytes = strlen($textPayload);
                $metadata = [
                    'folder_path' => $folder['folder_path'],
                    'drive_name' => (string)($uploaded['name'] ?? $textName),
                    'web_view_link' => (string)($uploaded['webViewLink'] ?? ''),
                    'cached_body' => true,
                ];
            }
        }
    } catch (Throwable $error) {
        error_log('saved_messages drive offload failed: ' . $error->getMessage());
        $driveResult = 'drive_upload_failed';
        $metadata['drive_error'] = 'Google Drive upload failed; message retained in database.';
    }

    if ($hasArchiveColumns) {
        $stmt = $pdo->prepare(
            'INSERT INTO xmpp_saved_messages (
                emp_id, body, file_url, file_name, file_type,
                storage_mode, drive_provider_id, drive_file_id, drive_folder_id,
                drive_payload_type, drive_mime_type, drive_size_bytes, metadata_json
             ) VALUES (
                :emp_id, :body, :file_url, :file_name, :file_type,
                :storage_mode, :drive_provider_id, :drive_file_id, :drive_folder_id,
                :drive_payload_type, :drive_mime_type, :drive_size_bytes, :metadata_json
             )'
        );
        $stmt->execute([
            ':emp_id' => $empId,
            ':body' => $body,
            ':file_url' => $persistedFileUrl,
            ':file_name' => $fileName !== '' ? saved_messages_utf8_safe($fileName) : null,
            ':file_type' => $fileType !== '' ? saved_messages_utf8_safe($fileType) : null,
            ':storage_mode' => $storageMode,
            ':drive_provider_id' => $driveProviderId,
            ':drive_file_id' => $driveFileId,
            ':drive_folder_id' => $driveFolderId,
            ':drive_payload_type' => $drivePayloadType,
            ':drive_mime_type' => $driveMimeType,
            ':drive_size_bytes' => $driveSizeBytes,
            ':metadata_json' => $metadata ? json_encode(saved_messages_utf8_safe($metadata), JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE) : null,
        ]);
    } else {
        $storageMode = 'database';
        $stmt = $pdo->prepare(
            'INSERT INTO xmpp_saved_messages (
                emp_id, body, file_url, file_name, file_type
             ) VALUES (
                :emp_id, :body, :file_url, :file_name, :file_type
             )'
        );
        $stmt->execute([
            ':emp_id' => $empId,
            ':body' => $body,
            ':file_url' => $persistedFileUrl,
            ':file_name' => $fileName !== '' ? saved_messages_utf8_safe($fileName) : null,
            ':file_type' => $fileType !== '' ? saved_messages_utf8_safe($fileType) : null,
        ]);
    }

    $messageId = (int)$pdo->lastInsertId();
    chat_json([
        'status' => true,
        'message_id' => $messageId,
        'storage_mode' => $storageMode,
        'drive_enabled' => $driveAllowed,
        'drive_result' => $driveResult,
        'file_url' => $storageMode === 'drive' && $drivePayloadType === 'file' ? saved_messages_proxy_url($messageId) : $persistedFileUrl,
    ]);
} catch (Throwable $error) {
    error_log('saved_messages endpoint failed: ' . $error->getMessage());
    chat_json([
        'status' => false,
        'error' => saved_messages_utf8_safe($error->getMessage()),
    ], 500);
}


