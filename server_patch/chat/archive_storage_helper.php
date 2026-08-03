<?php
declare(strict_types=1);

if (!function_exists('flow_admin_db')) {
    require_once __DIR__ . '/../../admin/legacy_standalone/_bootstrap.php';
}

const FLOW_ARCHIVE_PROVIDER_GOOGLE_DRIVE = 'google_drive';
const FLOW_ARCHIVE_PROVIDER_ONEDRIVE = 'onedrive';
const FLOW_ARCHIVE_PROVIDER_AMAZON_S3 = 'amazon_s3';
const FLOW_ARCHIVE_PROVIDER_AZURE_BLOB = 'azure_blob';
const FLOW_ARCHIVE_PROVIDER_NAS = 'nas';
const FLOW_ARCHIVE_PROVIDER_S3_COMPATIBLE = 's3_compatible';

const FLOW_ARCHIVE_GOOGLE_AUTH_URL = 'https://accounts.google.com/o/oauth2/v2/auth';
const FLOW_ARCHIVE_GOOGLE_TOKEN_URL = 'https://oauth2.googleapis.com/token';
const FLOW_ARCHIVE_GOOGLE_API_BASE = 'https://www.googleapis.com/drive/v3';
const FLOW_ARCHIVE_GOOGLE_UPLOAD_BASE = 'https://www.googleapis.com/upload/drive/v3/files';

function archive_storage_catalog(): array
{
    return [
        FLOW_ARCHIVE_PROVIDER_GOOGLE_DRIVE => [
            'provider_key' => FLOW_ARCHIVE_PROVIDER_GOOGLE_DRIVE,
            'label' => 'Google Drive',
            'supports_oauth' => true,
            'supports_streaming' => true,
            'supports_resumable_uploads' => true,
        ],
        FLOW_ARCHIVE_PROVIDER_ONEDRIVE => [
            'provider_key' => FLOW_ARCHIVE_PROVIDER_ONEDRIVE,
            'label' => 'OneDrive',
            'supports_oauth' => true,
            'supports_streaming' => false,
            'supports_resumable_uploads' => false,
        ],
        FLOW_ARCHIVE_PROVIDER_AMAZON_S3 => [
            'provider_key' => FLOW_ARCHIVE_PROVIDER_AMAZON_S3,
            'label' => 'Amazon S3',
            'supports_oauth' => false,
            'supports_streaming' => false,
            'supports_resumable_uploads' => true,
        ],
        FLOW_ARCHIVE_PROVIDER_AZURE_BLOB => [
            'provider_key' => FLOW_ARCHIVE_PROVIDER_AZURE_BLOB,
            'label' => 'Azure Blob Storage',
            'supports_oauth' => false,
            'supports_streaming' => false,
            'supports_resumable_uploads' => true,
        ],
        FLOW_ARCHIVE_PROVIDER_NAS => [
            'provider_key' => FLOW_ARCHIVE_PROVIDER_NAS,
            'label' => 'NAS / Shared Storage',
            'supports_oauth' => false,
            'supports_streaming' => false,
            'supports_resumable_uploads' => false,
        ],
        FLOW_ARCHIVE_PROVIDER_S3_COMPATIBLE => [
            'provider_key' => FLOW_ARCHIVE_PROVIDER_S3_COMPATIBLE,
            'label' => 'S3 Compatible',
            'supports_oauth' => false,
            'supports_streaming' => false,
            'supports_resumable_uploads' => true,
        ],
    ];
}

function archive_storage_provider_list(): array
{
    return array_values(archive_storage_catalog());
}

function archive_storage_table_exists(PDO $pdo, string $table): bool
{
    static $cache = [];
    $key = spl_object_hash($pdo) . ':' . strtolower($table);
    if (array_key_exists($key, $cache)) return $cache[$key];
    $stmt = $pdo->prepare("SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = :table LIMIT 1");
    $stmt->execute([':table' => $table]);
    return $cache[$key] = (bool)$stmt->fetchColumn();
}

function archive_storage_rows(PDO $pdo, string $sql, array $params = []): array
{
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);
    return is_array($rows) ? $rows : [];
}

function archive_storage_one(PDO $pdo, string $sql, array $params = []): ?array
{
    return archive_storage_rows($pdo, $sql, $params)[0] ?? null;
}

function archive_storage_mask_secret(string $value): string
{
    $value = trim($value);
    if ($value === '') return '';
    $len = strlen($value);
    if ($len <= 8) return str_repeat('*', $len);
    return substr($value, 0, 4) . str_repeat('*', max(4, $len - 8)) . substr($value, -4);
}

function archive_storage_audit(PDO $pdo, int $adminEmpId, string $action, string $targetType = '', string $targetId = '', array $payload = [], string $status = 'ok'): void
{
    archive_storage_ensure_schema($pdo);
    $stmt = $pdo->prepare(
        'INSERT INTO flow_archive_audit_log
        (admin_emp_id, action_name, target_type, target_id, payload_json, status, ip_address, created_at)
        VALUES
        (:admin_emp_id, :action_name, :target_type, :target_id, :payload_json, :status, :ip_address, NOW())'
    );
    $stmt->execute([
        ':admin_emp_id' => $adminEmpId,
        ':action_name' => $action,
        ':target_type' => $targetType,
        ':target_id' => $targetId,
        ':payload_json' => json_encode($payload, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE),
        ':status' => $status,
        ':ip_address' => substr((string)($_SERVER['REMOTE_ADDR'] ?? ''), 0, 45),
    ]);
}

function archive_storage_ensure_schema(PDO $pdo): void
{
    static $done = false;
    if ($done) return;

    $pdo->exec(
        "CREATE TABLE IF NOT EXISTS flow_archive_providers (
            id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
            provider_key VARCHAR(50) NOT NULL,
            provider_name VARCHAR(150) NOT NULL,
            status TINYINT(1) NOT NULL DEFAULT 1,
            oauth_client_id TEXT NULL,
            oauth_client_secret LONGTEXT NULL,
            oauth_redirect_uri TEXT NULL,
            oauth_scope TEXT NULL,
            refresh_token LONGTEXT NULL,
            access_token LONGTEXT NULL,
            access_token_expires_at DATETIME NULL,
            root_folder_id VARCHAR(255) NULL,
            root_folder_path VARCHAR(255) NULL,
            config_json LONGTEXT NULL,
            storage_limit_bytes BIGINT UNSIGNED NOT NULL DEFAULT 0,
            used_bytes BIGINT UNSIGNED NOT NULL DEFAULT 0,
            last_sync_at DATETIME NULL,
            last_error TEXT NULL,
            created_by INT NOT NULL DEFAULT 0,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            UNIQUE KEY uniq_archive_provider_name (provider_name),
            KEY idx_archive_provider_key (provider_key),
            KEY idx_archive_provider_status (status)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci"
    );

    $pdo->exec(
        "CREATE TABLE IF NOT EXISTS flow_archive_policies (
            id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
            policy_name VARCHAR(160) NOT NULL,
            provider_id BIGINT UNSIGNED NOT NULL,
            module_type VARCHAR(50) NOT NULL,
            trigger_mode VARCHAR(50) NOT NULL DEFAULT 'inactive_days',
            inactivity_days INT NOT NULL DEFAULT 90,
            archive_after_status VARCHAR(80) NULL,
            include_attachments TINYINT(1) NOT NULL DEFAULT 1,
            include_media TINYINT(1) NOT NULL DEFAULT 1,
            include_manifest TINYINT(1) NOT NULL DEFAULT 1,
            compression_mode VARCHAR(30) NOT NULL DEFAULT 'gzip',
            enabled TINYINT(1) NOT NULL DEFAULT 1,
            schedule_cron VARCHAR(80) NULL,
            filter_json LONGTEXT NULL,
            created_by INT NOT NULL DEFAULT 0,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            KEY idx_archive_policy_provider (provider_id),
            KEY idx_archive_policy_module (module_type),
            KEY idx_archive_policy_enabled (enabled)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci"
    );

    $pdo->exec(
        "CREATE TABLE IF NOT EXISTS flow_archive_jobs (
            id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
            policy_id BIGINT UNSIGNED NULL,
            provider_id BIGINT UNSIGNED NOT NULL,
            module_type VARCHAR(50) NOT NULL,
            entity_id VARCHAR(191) NOT NULL,
            entity_label VARCHAR(255) NULL,
            conversation_jid VARCHAR(255) NULL,
            status VARCHAR(30) NOT NULL DEFAULT 'queued',
            scheduled_at DATETIME NULL,
            started_at DATETIME NULL,
            finished_at DATETIME NULL,
            retry_count INT NOT NULL DEFAULT 0,
            next_retry_at DATETIME NULL,
            bytes_uploaded BIGINT UNSIGNED NOT NULL DEFAULT 0,
            attachment_count INT NOT NULL DEFAULT 0,
            message_count INT NOT NULL DEFAULT 0,
            manifest_file_id VARCHAR(255) NULL,
            archive_path VARCHAR(255) NULL,
            checksum_sha256 CHAR(64) NULL,
            summary_text LONGTEXT NULL,
            permissions_json LONGTEXT NULL,
            last_error TEXT NULL,
            created_by INT NOT NULL DEFAULT 0,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            KEY idx_archive_job_status (status),
            KEY idx_archive_job_module (module_type, entity_id),
            KEY idx_archive_job_provider (provider_id),
            KEY idx_archive_job_schedule (scheduled_at, next_retry_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci"
    );

    $pdo->exec(
        "CREATE TABLE IF NOT EXISTS flow_archive_items (
            id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
            job_id BIGINT UNSIGNED NOT NULL,
            provider_id BIGINT UNSIGNED NOT NULL,
            module_type VARCHAR(50) NOT NULL,
            entity_id VARCHAR(191) NOT NULL,
            entity_label VARCHAR(255) NULL,
            conversation_jid VARCHAR(255) NULL,
            archive_status VARCHAR(30) NOT NULL DEFAULT 'archived',
            provider_path VARCHAR(255) NULL,
            provider_file_id VARCHAR(255) NULL,
            manifest_file_id VARCHAR(255) NULL,
            summary_text LONGTEXT NULL,
            search_text LONGTEXT NULL,
            metadata_json LONGTEXT NULL,
            permissions_json LONGTEXT NULL,
            archived_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            restored_at DATETIME NULL,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            UNIQUE KEY uniq_archive_item (module_type, entity_id),
            KEY idx_archive_item_conversation (conversation_jid),
            KEY idx_archive_item_provider (provider_id),
            KEY idx_archive_item_status (archive_status)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci"
    );

    $pdo->exec(
        "CREATE TABLE IF NOT EXISTS flow_archive_audit_log (
            id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
            admin_emp_id INT NOT NULL DEFAULT 0,
            action_name VARCHAR(80) NOT NULL,
            target_type VARCHAR(50) NULL,
            target_id VARCHAR(191) NULL,
            payload_json LONGTEXT NULL,
            status VARCHAR(30) NOT NULL DEFAULT 'ok',
            ip_address VARCHAR(45) NULL,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            KEY idx_archive_audit_admin (admin_emp_id, created_at),
            KEY idx_archive_audit_action (action_name, created_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci"
    );

    $done = true;
}

function archive_storage_provider(PDO $pdo, int $providerId): ?array
{
    archive_storage_ensure_schema($pdo);
    return archive_storage_one($pdo, 'SELECT * FROM flow_archive_providers WHERE id = :id LIMIT 1', [':id' => $providerId]);
}

function archive_storage_policy_list(PDO $pdo): array
{
    archive_storage_ensure_schema($pdo);
    $rows = archive_storage_rows(
        $pdo,
        "SELECT p.*, pr.provider_name, pr.provider_key
         FROM flow_archive_policies p
         INNER JOIN flow_archive_providers pr ON pr.id = p.provider_id
         ORDER BY p.enabled DESC, p.updated_at DESC, p.id DESC"
    );
    foreach ($rows as &$row) {
        $row['filter_json'] = $row['filter_json'] !== null && $row['filter_json'] !== '' ? json_decode((string)$row['filter_json'], true) : [];
    }
    unset($row);
    return $rows;
}

function archive_storage_job_list(PDO $pdo, int $limit = 40): array
{
    archive_storage_ensure_schema($pdo);
    $limit = max(1, min($limit, 200));
    $rows = archive_storage_rows(
        $pdo,
        "SELECT j.*, p.provider_name, p.provider_key, pol.policy_name
         FROM flow_archive_jobs j
         INNER JOIN flow_archive_providers p ON p.id = j.provider_id
         LEFT JOIN flow_archive_policies pol ON pol.id = j.policy_id
         ORDER BY FIELD(j.status, 'running', 'queued', 'retry', 'failed', 'completed', 'archived'), COALESCE(j.scheduled_at, j.created_at) DESC, j.id DESC
         LIMIT {$limit}"
    );
    foreach ($rows as &$row) {
        $row['permissions_json'] = $row['permissions_json'] !== null && $row['permissions_json'] !== '' ? json_decode((string)$row['permissions_json'], true) : [];
    }
    unset($row);
    return $rows;
}

function archive_storage_item_list(PDO $pdo, int $limit = 60): array
{
    archive_storage_ensure_schema($pdo);
    $limit = max(1, min($limit, 200));
    $rows = archive_storage_rows(
        $pdo,
        "SELECT i.*, p.provider_name, p.provider_key
         FROM flow_archive_items i
         INNER JOIN flow_archive_providers p ON p.id = i.provider_id
         ORDER BY i.archived_at DESC, i.id DESC
         LIMIT {$limit}"
    );
    foreach ($rows as &$row) {
        $row['metadata_json'] = $row['metadata_json'] !== null && $row['metadata_json'] !== '' ? json_decode((string)$row['metadata_json'], true) : [];
        $row['permissions_json'] = $row['permissions_json'] !== null && $row['permissions_json'] !== '' ? json_decode((string)$row['permissions_json'], true) : [];
    }
    unset($row);
    return $rows;
}

function archive_storage_metrics(PDO $pdo): array
{
    archive_storage_ensure_schema($pdo);
    return [
        'providers' => (int)($pdo->query('SELECT COUNT(*) FROM flow_archive_providers')->fetchColumn() ?: 0),
        'active_policies' => (int)($pdo->query('SELECT COUNT(*) FROM flow_archive_policies WHERE enabled = 1')->fetchColumn() ?: 0),
        'queued_jobs' => (int)($pdo->query("SELECT COUNT(*) FROM flow_archive_jobs WHERE status IN ('queued', 'retry', 'running')")->fetchColumn() ?: 0),
        'failed_jobs' => (int)($pdo->query("SELECT COUNT(*) FROM flow_archive_jobs WHERE status = 'failed'")->fetchColumn() ?: 0),
        'archived_items' => (int)($pdo->query("SELECT COUNT(*) FROM flow_archive_items WHERE archive_status = 'archived'")->fetchColumn() ?: 0),
        'archived_bytes' => (int)($pdo->query("SELECT COALESCE(SUM(bytes_uploaded),0) FROM flow_archive_jobs WHERE status IN ('completed', 'archived')")->fetchColumn() ?: 0),
    ];
}

function archive_storage_admin_payload(PDO $pdo, string $search = ''): array
{
    archive_storage_ensure_schema($pdo);
    $providers = archive_storage_rows($pdo, 'SELECT * FROM flow_archive_providers ORDER BY status DESC, updated_at DESC, id DESC');
    foreach ($providers as &$provider) {
        $provider['oauth_client_secret_masked'] = archive_storage_mask_secret((string)($provider['oauth_client_secret'] ?? ''));
        $provider['refresh_token_masked'] = archive_storage_mask_secret((string)($provider['refresh_token'] ?? ''));
        $provider['access_token_masked'] = archive_storage_mask_secret((string)($provider['access_token'] ?? ''));
        $provider['config_json'] = $provider['config_json'] !== null && $provider['config_json'] !== '' ? json_decode((string)$provider['config_json'], true) : [];
    }
    unset($provider);

    $jobs = archive_storage_job_list($pdo, 30);
    $items = archive_storage_item_list($pdo, 30);

    if ($search !== '') {
        $needle = mb_strtolower($search);
        $jobs = array_values(array_filter($jobs, static function (array $row) use ($needle): bool {
            return str_contains(mb_strtolower((string)($row['entity_label'] ?? '')), $needle)
                || str_contains(mb_strtolower((string)($row['conversation_jid'] ?? '')), $needle)
                || str_contains(mb_strtolower((string)($row['module_type'] ?? '')), $needle);
        }));
        $items = array_values(array_filter($items, static function (array $row) use ($needle): bool {
            return str_contains(mb_strtolower((string)($row['entity_label'] ?? '')), $needle)
                || str_contains(mb_strtolower((string)($row['conversation_jid'] ?? '')), $needle)
                || str_contains(mb_strtolower((string)($row['module_type'] ?? '')), $needle)
                || str_contains(mb_strtolower((string)($row['summary_text'] ?? '')), $needle);
        }));
    }

    return [
        'status' => true,
        'catalog' => archive_storage_provider_list(),
        'providers' => $providers,
        'policies' => archive_storage_policy_list($pdo),
        'jobs' => $jobs,
        'items' => $items,
        'metrics' => archive_storage_metrics($pdo),
    ];
}

function archive_storage_google_auth_url(array $provider): string
{
    $clientId = trim((string)($provider['oauth_client_id'] ?? ''));
    $redirectUri = trim((string)($provider['oauth_redirect_uri'] ?? ''));
    if ($clientId === '' || $redirectUri === '') return '';
    $scope = trim((string)($provider['oauth_scope'] ?? 'https://www.googleapis.com/auth/drive.file https://www.googleapis.com/auth/drive.readonly'));
    $state = base64_encode(json_encode(['provider_id' => (int)($provider['id'] ?? 0), 'ts' => time()], JSON_UNESCAPED_SLASHES));
    return FLOW_ARCHIVE_GOOGLE_AUTH_URL . '?' . http_build_query([
        'response_type' => 'code',
        'client_id' => $clientId,
        'redirect_uri' => $redirectUri,
        'scope' => $scope,
        'access_type' => 'offline',
        'prompt' => 'consent',
        'state' => $state,
    ]);
}

function archive_storage_save_provider(PDO $pdo, int $adminEmpId): array
{
    archive_storage_ensure_schema($pdo);
    $id = (int)($_POST['id'] ?? 0);
    $providerKey = trim((string)($_POST['provider_key'] ?? FLOW_ARCHIVE_PROVIDER_GOOGLE_DRIVE));
    if (!array_key_exists($providerKey, archive_storage_catalog())) {
        return ['status' => false, 'error' => 'Unsupported storage provider.'];
    }

    $name = trim((string)($_POST['provider_name'] ?? ''));
    if ($name === '') return ['status' => false, 'error' => 'Provider name is required.'];

    $status = (int)($_POST['status'] ?? 1) === 1 ? 1 : 0;
    $oauthClientId = trim((string)($_POST['oauth_client_id'] ?? ''));
    $oauthClientSecret = trim((string)($_POST['oauth_client_secret'] ?? ''));
    $oauthRedirectUri = trim((string)($_POST['oauth_redirect_uri'] ?? ''));
    $oauthScope = trim((string)($_POST['oauth_scope'] ?? 'https://www.googleapis.com/auth/drive.file https://www.googleapis.com/auth/drive.readonly'));
    $rootFolderId = trim((string)($_POST['root_folder_id'] ?? ''));
    $rootFolderPath = trim((string)($_POST['root_folder_path'] ?? 'Flow Archive'));
    $storageLimitBytes = max(0, (int)($_POST['storage_limit_bytes'] ?? 0));
    $configJsonRaw = trim((string)($_POST['config_json'] ?? ''));
    $config = $configJsonRaw !== '' ? json_decode($configJsonRaw, true) : [];
    if ($configJsonRaw !== '' && !is_array($config)) return ['status' => false, 'error' => 'Invalid JSON in provider configuration.'];

    $existing = $id > 0 ? archive_storage_provider($pdo, $id) : null;
    $refreshToken = trim((string)($_POST['refresh_token'] ?? ''));
    $accessToken = trim((string)($_POST['access_token'] ?? ''));

    $stmt = $pdo->prepare(
        $id > 0
            ? "UPDATE flow_archive_providers SET
                provider_key = :provider_key,
                provider_name = :provider_name,
                status = :status,
                oauth_client_id = :oauth_client_id,
                oauth_client_secret = :oauth_client_secret,
                oauth_redirect_uri = :oauth_redirect_uri,
                oauth_scope = :oauth_scope,
                refresh_token = :refresh_token,
                access_token = :access_token,
                root_folder_id = :root_folder_id,
                root_folder_path = :root_folder_path,
                storage_limit_bytes = :storage_limit_bytes,
                config_json = :config_json,
                updated_at = NOW()
              WHERE id = :id"
            : "INSERT INTO flow_archive_providers
              (provider_key, provider_name, status, oauth_client_id, oauth_client_secret, oauth_redirect_uri, oauth_scope, refresh_token, access_token, root_folder_id, root_folder_path, storage_limit_bytes, config_json, created_by, created_at, updated_at)
              VALUES
              (:provider_key, :provider_name, :status, :oauth_client_id, :oauth_client_secret, :oauth_redirect_uri, :oauth_scope, :refresh_token, :access_token, :root_folder_id, :root_folder_path, :storage_limit_bytes, :config_json, :created_by, NOW(), NOW())"
    );
    $stmt->execute([
        ':id' => $id,
        ':provider_key' => $providerKey,
        ':provider_name' => $name,
        ':status' => $status,
        ':oauth_client_id' => $oauthClientId,
        ':oauth_client_secret' => $oauthClientSecret !== '' ? $oauthClientSecret : (string)($existing['oauth_client_secret'] ?? ''),
        ':oauth_redirect_uri' => $oauthRedirectUri,
        ':oauth_scope' => $oauthScope,
        ':refresh_token' => $refreshToken !== '' ? $refreshToken : (string)($existing['refresh_token'] ?? ''),
        ':access_token' => $accessToken !== '' ? $accessToken : (string)($existing['access_token'] ?? ''),
        ':root_folder_id' => $rootFolderId,
        ':root_folder_path' => $rootFolderPath,
        ':storage_limit_bytes' => $storageLimitBytes,
        ':config_json' => json_encode($config, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE),
        ':created_by' => $adminEmpId,
    ]);
    $providerId = $id > 0 ? $id : (int)$pdo->lastInsertId();
    archive_storage_audit($pdo, $adminEmpId, 'save_archive_provider', 'flow_archive_providers', (string)$providerId, [
        'provider_key' => $providerKey,
        'provider_name' => $name,
        'status' => $status,
        'root_folder_path' => $rootFolderPath,
        'oauth_connected' => ($refreshToken !== '' || (string)($existing['refresh_token'] ?? '') !== ''),
    ]);
    return ['status' => true, 'message' => 'Archive storage provider saved.', 'provider_id' => $providerId];
}

function archive_storage_save_policy(PDO $pdo, int $adminEmpId): array
{
    archive_storage_ensure_schema($pdo);
    $id = (int)($_POST['id'] ?? 0);
    $name = trim((string)($_POST['policy_name'] ?? ''));
    $providerId = (int)($_POST['provider_id'] ?? 0);
    $moduleType = trim((string)($_POST['module_type'] ?? 'channel'));
    if ($name === '' || $providerId <= 0 || $moduleType === '') return ['status' => false, 'error' => 'Policy name, provider and module type are required.'];

    $triggerMode = trim((string)($_POST['trigger_mode'] ?? 'inactive_days'));
    $days = max(0, (int)($_POST['inactivity_days'] ?? 90));
    $archiveAfterStatus = trim((string)($_POST['archive_after_status'] ?? ''));
    $enabled = (int)($_POST['enabled'] ?? 1) === 1 ? 1 : 0;
    $includeAttachments = (int)($_POST['include_attachments'] ?? 1) === 1 ? 1 : 0;
    $includeMedia = (int)($_POST['include_media'] ?? 1) === 1 ? 1 : 0;
    $includeManifest = (int)($_POST['include_manifest'] ?? 1) === 1 ? 1 : 0;
    $compressionMode = trim((string)($_POST['compression_mode'] ?? 'gzip'));
    $scheduleCron = trim((string)($_POST['schedule_cron'] ?? ''));
    $filterJsonRaw = trim((string)($_POST['filter_json'] ?? ''));
    $filterJson = $filterJsonRaw !== '' ? json_decode($filterJsonRaw, true) : [];
    if ($filterJsonRaw !== '' && !is_array($filterJson)) return ['status' => false, 'error' => 'Invalid JSON in archive policy filter.'];

    $stmt = $pdo->prepare(
        $id > 0
            ? "UPDATE flow_archive_policies SET
                policy_name = :policy_name,
                provider_id = :provider_id,
                module_type = :module_type,
                trigger_mode = :trigger_mode,
                inactivity_days = :inactivity_days,
                archive_after_status = :archive_after_status,
                include_attachments = :include_attachments,
                include_media = :include_media,
                include_manifest = :include_manifest,
                compression_mode = :compression_mode,
                enabled = :enabled,
                schedule_cron = :schedule_cron,
                filter_json = :filter_json,
                updated_at = NOW()
              WHERE id = :id"
            : "INSERT INTO flow_archive_policies
              (policy_name, provider_id, module_type, trigger_mode, inactivity_days, archive_after_status, include_attachments, include_media, include_manifest, compression_mode, enabled, schedule_cron, filter_json, created_by, created_at, updated_at)
              VALUES
              (:policy_name, :provider_id, :module_type, :trigger_mode, :inactivity_days, :archive_after_status, :include_attachments, :include_media, :include_manifest, :compression_mode, :enabled, :schedule_cron, :filter_json, :created_by, NOW(), NOW())"
    );
    $stmt->execute([
        ':id' => $id,
        ':policy_name' => $name,
        ':provider_id' => $providerId,
        ':module_type' => $moduleType,
        ':trigger_mode' => $triggerMode,
        ':inactivity_days' => $days,
        ':archive_after_status' => $archiveAfterStatus !== '' ? $archiveAfterStatus : null,
        ':include_attachments' => $includeAttachments,
        ':include_media' => $includeMedia,
        ':include_manifest' => $includeManifest,
        ':compression_mode' => $compressionMode,
        ':enabled' => $enabled,
        ':schedule_cron' => $scheduleCron !== '' ? $scheduleCron : null,
        ':filter_json' => json_encode($filterJson, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE),
        ':created_by' => $adminEmpId,
    ]);
    $policyId = $id > 0 ? $id : (int)$pdo->lastInsertId();
    archive_storage_audit($pdo, $adminEmpId, 'save_archive_policy', 'flow_archive_policies', (string)$policyId, [
        'policy_name' => $name,
        'provider_id' => $providerId,
        'module_type' => $moduleType,
        'trigger_mode' => $triggerMode,
        'enabled' => $enabled,
    ]);
    return ['status' => true, 'message' => 'Archive policy saved.', 'policy_id' => $policyId];
}

function archive_storage_group_label(PDO $pdo, string $entityId): string
{
    $row = archive_storage_one($pdo, 'SELECT name, title FROM xmpp_groups WHERE id = :id LIMIT 1', [':id' => $entityId]);
    return trim((string)($row['name'] ?? $row['title'] ?? ('Conversation ' . $entityId)));
}

function archive_storage_group_jid(PDO $pdo, string $entityId): string
{
    $row = archive_storage_one($pdo, 'SELECT room_jid FROM xmpp_groups WHERE id = :id LIMIT 1', [':id' => $entityId]);
    return trim((string)($row['room_jid'] ?? ''));
}

function archive_storage_queue_job(PDO $pdo, int $adminEmpId): array
{
    archive_storage_ensure_schema($pdo);
    $policyId = (int)($_POST['policy_id'] ?? 0);
    $providerId = (int)($_POST['provider_id'] ?? 0);
    $moduleType = trim((string)($_POST['module_type'] ?? 'channel'));
    $entityId = trim((string)($_POST['entity_id'] ?? ''));
    $entityLabel = trim((string)($_POST['entity_label'] ?? ''));
    $conversationJid = trim((string)($_POST['conversation_jid'] ?? ''));
    $scheduledAt = trim((string)($_POST['scheduled_at'] ?? ''));
    if ($providerId <= 0 || $entityId === '') return ['status' => false, 'error' => 'Provider and entity id are required to queue an archive job.'];

    if ($entityLabel === '' && in_array($moduleType, ['group', 'channel'], true)) $entityLabel = archive_storage_group_label($pdo, $entityId);
    if ($conversationJid === '' && in_array($moduleType, ['group', 'channel'], true)) $conversationJid = archive_storage_group_jid($pdo, $entityId);
    if ($conversationJid === '') return ['status' => false, 'error' => 'Conversation JID is required for archive jobs.'];

    $stmt = $pdo->prepare(
        "INSERT INTO flow_archive_jobs
        (policy_id, provider_id, module_type, entity_id, entity_label, conversation_jid, status, scheduled_at, created_by, created_at, updated_at)
        VALUES
        (:policy_id, :provider_id, :module_type, :entity_id, :entity_label, :conversation_jid, 'queued', :scheduled_at, :created_by, NOW(), NOW())"
    );
    $stmt->execute([
        ':policy_id' => $policyId > 0 ? $policyId : null,
        ':provider_id' => $providerId,
        ':module_type' => $moduleType,
        ':entity_id' => $entityId,
        ':entity_label' => $entityLabel !== '' ? $entityLabel : null,
        ':conversation_jid' => $conversationJid,
        ':scheduled_at' => $scheduledAt !== '' ? $scheduledAt : date('Y-m-d H:i:s'),
        ':created_by' => $adminEmpId,
    ]);
    $jobId = (int)$pdo->lastInsertId();
    archive_storage_audit($pdo, $adminEmpId, 'queue_archive_job', 'flow_archive_jobs', (string)$jobId, [
        'policy_id' => $policyId,
        'provider_id' => $providerId,
        'module_type' => $moduleType,
        'entity_id' => $entityId,
        'conversation_jid' => $conversationJid,
    ]);
    return ['status' => true, 'message' => 'Archive job queued.', 'job_id' => $jobId];
}

function archive_storage_http_request(string $url, string $method = 'GET', array $headers = [], ?string $body = null, int $timeout = 30): array
{
    $lines = [];
    foreach ($headers as $key => $value) {
        $lines[] = is_int($key) ? $value : ($key . ': ' . $value);
    }
    $context = stream_context_create([
        'http' => [
            'method' => $method,
            'header' => implode("\r\n", $lines),
            'content' => $body ?? '',
            'timeout' => $timeout,
            'ignore_errors' => true,
        ],
    ]);
    $raw = @file_get_contents($url, false, $context);
    $responseHeaders = $http_response_header ?? [];
    $statusCode = 0;
    foreach ($responseHeaders as $line) {
        if (preg_match('/\s(\d{3})\s/', $line, $match)) {
            $statusCode = (int)$match[1];
            break;
        }
    }
    return [
        'status_code' => $statusCode,
        'body' => is_string($raw) ? $raw : '',
        'headers' => $responseHeaders,
    ];
}

function archive_storage_google_refresh_token(PDO $pdo, array $provider): ?array
{
    $clientId = trim((string)($provider['oauth_client_id'] ?? ''));
    $clientSecret = trim((string)($provider['oauth_client_secret'] ?? ''));
    $refreshToken = trim((string)($provider['refresh_token'] ?? ''));
    if ($clientId === '' || $clientSecret === '' || $refreshToken === '') return null;
    $response = archive_storage_http_request(
        FLOW_ARCHIVE_GOOGLE_TOKEN_URL,
        'POST',
        ['Content-Type' => 'application/x-www-form-urlencoded'],
        http_build_query([
            'client_id' => $clientId,
            'client_secret' => $clientSecret,
            'refresh_token' => $refreshToken,
            'grant_type' => 'refresh_token',
        ]),
        30
    );
    if (($response['status_code'] ?? 0) < 200 || ($response['status_code'] ?? 0) >= 300) {
        throw new RuntimeException('Google token refresh failed with HTTP ' . (int)($response['status_code'] ?? 0));
    }
    $data = json_decode((string)($response['body'] ?? ''), true);
    if (!is_array($data) || empty($data['access_token'])) {
        throw new RuntimeException('Google token refresh returned invalid JSON.');
    }
    $accessToken = (string)$data['access_token'];
    $expiresIn = max(60, (int)($data['expires_in'] ?? 3600));
    $stmt = $pdo->prepare('UPDATE flow_archive_providers SET access_token = :token, access_token_expires_at = :expires, last_error = NULL, updated_at = NOW() WHERE id = :id');
    $stmt->execute([
        ':token' => $accessToken,
        ':expires' => date('Y-m-d H:i:s', time() + $expiresIn - 60),
        ':id' => (int)$provider['id'],
    ]);
    $provider['access_token'] = $accessToken;
    $provider['access_token_expires_at'] = date('Y-m-d H:i:s', time() + $expiresIn - 60);
    return $provider;
}

function archive_storage_provider_access_token(PDO $pdo, array $provider): string
{
    if (($provider['provider_key'] ?? '') !== FLOW_ARCHIVE_PROVIDER_GOOGLE_DRIVE) {
        throw new RuntimeException('Provider access token is implemented only for Google Drive right now.');
    }
    $token = trim((string)($provider['access_token'] ?? ''));
    $expires = strtotime((string)($provider['access_token_expires_at'] ?? ''));
    if ($token !== '' && $expires !== false && $expires > time() + 60) return $token;
    $provider = archive_storage_google_refresh_token($pdo, $provider);
    return trim((string)($provider['access_token'] ?? ''));
}

function archive_storage_exchange_google_code(PDO $pdo, int $adminEmpId): array
{
    archive_storage_ensure_schema($pdo);
    $providerId = (int)($_POST['provider_id'] ?? 0);
    $code = trim((string)($_POST['oauth_code'] ?? ''));
    $provider = archive_storage_provider($pdo, $providerId);
    if (!$provider) return ['status' => false, 'error' => 'Archive provider not found.'];
    if ($code === '') return ['status' => false, 'error' => 'OAuth code is required.'];

    $response = archive_storage_http_request(
        FLOW_ARCHIVE_GOOGLE_TOKEN_URL,
        'POST',
        ['Content-Type' => 'application/x-www-form-urlencoded'],
        http_build_query([
            'code' => $code,
            'client_id' => trim((string)($provider['oauth_client_id'] ?? '')),
            'client_secret' => trim((string)($provider['oauth_client_secret'] ?? '')),
            'redirect_uri' => trim((string)($provider['oauth_redirect_uri'] ?? '')),
            'grant_type' => 'authorization_code',
        ]),
        30
    );
    if (($response['status_code'] ?? 0) < 200 || ($response['status_code'] ?? 0) >= 300) {
        return ['status' => false, 'error' => 'Google OAuth token exchange failed with HTTP ' . (int)($response['status_code'] ?? 0)];
    }
    $data = json_decode((string)($response['body'] ?? ''), true);
    if (!is_array($data) || empty($data['access_token'])) return ['status' => false, 'error' => 'Google OAuth response was invalid.'];

    $stmt = $pdo->prepare('UPDATE flow_archive_providers SET access_token = :access_token, refresh_token = :refresh_token, access_token_expires_at = :expires_at, last_sync_at = NOW(), last_error = NULL, updated_at = NOW() WHERE id = :id');
    $stmt->execute([
        ':access_token' => (string)$data['access_token'],
        ':refresh_token' => trim((string)($data['refresh_token'] ?? (string)($provider['refresh_token'] ?? ''))),
        ':expires_at' => date('Y-m-d H:i:s', time() + max(60, (int)($data['expires_in'] ?? 3600)) - 60),
        ':id' => $providerId,
    ]);
    archive_storage_audit($pdo, $adminEmpId, 'exchange_archive_google_code', 'flow_archive_providers', (string)$providerId, ['connected' => true]);
    return ['status' => true, 'message' => 'Google Drive connected successfully.'];
}

function archive_storage_google_find_child(string $accessToken, string $parentId, string $name, string $mimeType = 'application/vnd.google-apps.folder'): ?array
{
    $query = sprintf(
        "name = '%s' and '%s' in parents and trashed = false and mimeType = '%s'",
        str_replace("'", "\\'", $name),
        str_replace("'", "\\'", $parentId),
        $mimeType
    );
    $response = archive_storage_http_request(
        FLOW_ARCHIVE_GOOGLE_API_BASE . '/files?' . http_build_query([
            'q' => $query,
            'fields' => 'files(id,name,webViewLink,size,mimeType)',
            'pageSize' => 1,
        ]),
        'GET',
        ['Authorization' => 'Bearer ' . $accessToken, 'Accept' => 'application/json'],
        null,
        30
    );
    if (($response['status_code'] ?? 0) < 200 || ($response['status_code'] ?? 0) >= 300) return null;
    $data = json_decode((string)($response['body'] ?? ''), true);
    return is_array($data) ? ($data['files'][0] ?? null) : null;
}

function archive_storage_google_create_folder(string $accessToken, string $name, string $parentId = ''): array
{
    $payload = [
        'name' => $name,
        'mimeType' => 'application/vnd.google-apps.folder',
    ];
    if ($parentId !== '') $payload['parents'] = [$parentId];
    $response = archive_storage_http_request(
        FLOW_ARCHIVE_GOOGLE_API_BASE . '/files?fields=id,name,webViewLink',
        'POST',
        [
            'Authorization' => 'Bearer ' . $accessToken,
            'Content-Type' => 'application/json',
            'Accept' => 'application/json',
        ],
        json_encode($payload, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE),
        30
    );
    if (($response['status_code'] ?? 0) < 200 || ($response['status_code'] ?? 0) >= 300) {
        throw new RuntimeException('Google Drive folder creation failed with HTTP ' . (int)($response['status_code'] ?? 0));
    }
    $data = json_decode((string)($response['body'] ?? ''), true);
    if (!is_array($data) || empty($data['id'])) throw new RuntimeException('Google Drive folder creation returned invalid JSON.');
    return $data;
}

function archive_storage_google_ensure_folder_path(string $accessToken, string $rootFolderId, array $segments): array
{
    $currentId = $rootFolderId;
    $createdPath = [];
    foreach ($segments as $segment) {
        $segment = trim((string)$segment);
        if ($segment === '') continue;
        $existing = archive_storage_google_find_child($accessToken, $currentId, $segment);
        if (!$existing) $existing = archive_storage_google_create_folder($accessToken, $segment, $currentId);
        $currentId = (string)($existing['id'] ?? '');
        $createdPath[] = $segment;
    }
    return ['folder_id' => $currentId, 'folder_path' => implode('/', $createdPath)];
}

function archive_storage_google_upload_bytes(string $accessToken, string $parentId, string $name, string $bytes, string $mimeType = 'application/octet-stream'): array
{
    $meta = json_encode(['name' => $name, 'parents' => [$parentId]], JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
    $boundary = 'flow-archive-' . bin2hex(random_bytes(8));
    $body = "--{$boundary}\r\n"
        . "Content-Type: application/json; charset=UTF-8\r\n\r\n"
        . $meta . "\r\n"
        . "--{$boundary}\r\n"
        . "Content-Type: {$mimeType}\r\n\r\n"
        . $bytes . "\r\n"
        . "--{$boundary}--";
    $response = archive_storage_http_request(
        FLOW_ARCHIVE_GOOGLE_UPLOAD_BASE . '?uploadType=multipart&fields=id,name,webViewLink,size',
        'POST',
        [
            'Authorization' => 'Bearer ' . $accessToken,
            'Content-Type' => 'multipart/related; boundary=' . $boundary,
            'Accept' => 'application/json',
        ],
        $body,
        120
    );
    if (($response['status_code'] ?? 0) < 200 || ($response['status_code'] ?? 0) >= 300) {
        throw new RuntimeException('Google Drive upload failed with HTTP ' . (int)($response['status_code'] ?? 0));
    }
    $data = json_decode((string)($response['body'] ?? ''), true);
    if (!is_array($data) || empty($data['id'])) throw new RuntimeException('Google Drive upload returned invalid JSON.');
    return $data;
}

function archive_storage_google_upload_file(string $accessToken, string $parentId, string $name, string $path, string $mimeType = 'application/octet-stream'): array
{
    if (!is_file($path)) throw new RuntimeException('Archive upload source file is missing: ' . $path);
    $content = file_get_contents($path);
    if (!is_string($content)) throw new RuntimeException('Unable to read archive upload source file.');
    return archive_storage_google_upload_bytes($accessToken, $parentId, $name, $content, $mimeType);
}

function archive_storage_resolve_local_upload_path(string $relativePath): ?string
{
    $relativePath = trim(str_replace(['..\\', '../'], '', $relativePath));
    if ($relativePath === '') return null;
    $candidates = [
        __DIR__ . DIRECTORY_SEPARATOR . $relativePath,
        dirname(__DIR__) . DIRECTORY_SEPARATOR . $relativePath,
        __DIR__ . DIRECTORY_SEPARATOR . 'uploads' . DIRECTORY_SEPARATOR . ltrim($relativePath, '\\/'),
    ];
    foreach ($candidates as $candidate) {
        $normalized = str_replace(['/', '\\'], DIRECTORY_SEPARATOR, $candidate);
        if (is_file($normalized)) return $normalized;
    }
    return null;
}

function archive_storage_message_rows(PDO $pdo, string $conversationJid): array
{
    $rows = archive_storage_rows(
        $pdo,
        "SELECT id, stanza_id, from_jid, to_jid, body, message_type, file_url, file_name, file_size, file_type, mime_type, file_path,
                created_at, updated_at, reply_to_id, thread_root_id, mentions_json, sender_emp_id, source_name, source_device,
                latitude, longitude, location_address, is_deleted
         FROM xmpp_messages
         WHERE (to_jid = :jid OR from_jid = :jid)
         ORDER BY created_at ASC, id ASC",
        [':jid' => $conversationJid]
    );
    foreach ($rows as &$row) {
        $row['mentions_json'] = $row['mentions_json'] !== null && $row['mentions_json'] !== '' ? json_decode((string)$row['mentions_json'], true) : [];
        $row['reactions'] = archive_storage_reactions($pdo, (int)($row['id'] ?? 0));
    }
    unset($row);
    return $rows;
}

function archive_storage_reactions(PDO $pdo, int $messageId): array
{
    if ($messageId <= 0 || !archive_storage_table_exists($pdo, 'xmpp_message_reactions')) return [];
    return archive_storage_rows(
        $pdo,
        'SELECT message_id, emp_id, reaction, created_at FROM xmpp_message_reactions WHERE message_id = :message_id ORDER BY created_at ASC, id ASC',
        [':message_id' => $messageId]
    );
}

function archive_storage_participants(PDO $pdo, string $conversationJid): array
{
    $participants = [];
    foreach (archive_storage_rows(
        $pdo,
        "SELECT DISTINCT COALESCE(emp_id, sender_emp_id, 0) AS emp_id
         FROM (
            SELECT sender_emp_id, sender_emp_id AS emp_id FROM xmpp_messages WHERE to_jid = :jid OR from_jid = :jid
            UNION ALL
            SELECT emp_id, emp_id FROM xmpp_group_members WHERE room_jid = :jid
         ) source
         WHERE COALESCE(emp_id, 0) > 0",
        [':jid' => $conversationJid]
    ) as $row) {
        $empId = (int)($row['emp_id'] ?? 0);
        if ($empId > 0) $participants[] = $empId;
    }
    $participants = array_values(array_unique($participants));
    sort($participants);
    return $participants;
}

function archive_storage_build_manifest(PDO $pdo, string $moduleType, string $entityId, string $entityLabel, string $conversationJid): array
{
    $messages = archive_storage_message_rows($pdo, $conversationJid);
    $participants = archive_storage_participants($pdo, $conversationJid);
    $attachments = [];
    $searchParts = [];
    foreach ($messages as $message) {
        $body = trim((string)($message['body'] ?? ''));
        if ($body !== '') $searchParts[] = $body;
        if (!empty($message['file_name']) || !empty($message['file_url']) || !empty($message['file_path'])) {
            $attachments[] = [
                'message_id' => (int)($message['id'] ?? 0),
                'file_name' => (string)($message['file_name'] ?? ''),
                'file_url' => (string)($message['file_url'] ?? ''),
                'file_path' => (string)($message['file_path'] ?? ''),
                'file_type' => (string)($message['file_type'] ?? ''),
                'mime_type' => (string)($message['mime_type'] ?? ''),
                'file_size' => (int)($message['file_size'] ?? 0),
            ];
        }
    }
    $summary = trim(implode("\n", array_slice($searchParts, -30)));
    $manifest = [
        'flow_archive_version' => 1,
        'module_type' => $moduleType,
        'entity_id' => $entityId,
        'entity_label' => $entityLabel,
        'conversation_jid' => $conversationJid,
        'generated_at' => date(DATE_ATOM),
        'message_count' => count($messages),
        'attachment_count' => count($attachments),
        'participants' => $participants,
        'messages' => $messages,
        'attachments' => $attachments,
    ];
    return [
        'manifest' => $manifest,
        'summary_text' => mb_substr($summary, 0, 5000),
        'search_text' => mb_substr(implode("\n", $searchParts), 0, 65535),
        'participants' => $participants,
        'attachments' => $attachments,
    ];
}

function archive_storage_job_folder_segments(array $job): array
{
    $moduleType = trim((string)($job['module_type'] ?? 'conversation'));
    $label = trim((string)($job['entity_label'] ?? ($job['entity_id'] ?? 'archive')));
    $safeLabel = preg_replace('/[^a-zA-Z0-9._-]+/', '-', $label) ?: 'archive';
    return ['Flow Archive', $moduleType, date('Y'), date('m'), $safeLabel . '-' . (string)($job['entity_id'] ?? '0')];
}

function archive_storage_process_job(PDO $pdo, int $jobId): array
{
    archive_storage_ensure_schema($pdo);
    $job = archive_storage_one($pdo, 'SELECT * FROM flow_archive_jobs WHERE id = :id LIMIT 1', [':id' => $jobId]);
    if (!$job) throw new RuntimeException('Archive job not found.');
    $provider = archive_storage_provider($pdo, (int)($job['provider_id'] ?? 0));
    if (!$provider) throw new RuntimeException('Archive provider not found.');
    if (($provider['provider_key'] ?? '') !== FLOW_ARCHIVE_PROVIDER_GOOGLE_DRIVE) {
        throw new RuntimeException('Only Google Drive archive execution is implemented right now.');
    }

    $pdo->prepare("UPDATE flow_archive_jobs SET status = 'running', started_at = NOW(), last_error = NULL, updated_at = NOW() WHERE id = :id")->execute([':id' => $jobId]);

    $token = archive_storage_provider_access_token($pdo, $provider);
    $rootFolderId = trim((string)($provider['root_folder_id'] ?? ''));
    if ($rootFolderId === '') {
        $rootName = trim((string)($provider['root_folder_path'] ?? 'Flow Archive'));
        $root = archive_storage_google_create_folder($token, $rootName);
        $rootFolderId = (string)($root['id'] ?? '');
        $pdo->prepare('UPDATE flow_archive_providers SET root_folder_id = :root_folder_id, updated_at = NOW() WHERE id = :id')
            ->execute([':root_folder_id' => $rootFolderId, ':id' => (int)$provider['id']]);
    }

    $folder = archive_storage_google_ensure_folder_path($token, $rootFolderId, archive_storage_job_folder_segments($job));
    $manifestPack = archive_storage_build_manifest(
        $pdo,
        (string)($job['module_type'] ?? 'channel'),
        (string)($job['entity_id'] ?? ''),
        (string)($job['entity_label'] ?? ''),
        (string)($job['conversation_jid'] ?? '')
    );
    $manifestJson = json_encode($manifestPack['manifest'], JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
    if (!is_string($manifestJson)) throw new RuntimeException('Unable to encode archive manifest.');
    $compressedManifest = gzencode($manifestJson, 6);
    if (!is_string($compressedManifest)) throw new RuntimeException('Unable to compress archive manifest.');
    $manifestFile = archive_storage_google_upload_bytes($token, (string)$folder['folder_id'], 'manifest.json.gz', $compressedManifest, 'application/gzip');

    $attachmentUploads = [];
    $bytesUploaded = strlen($compressedManifest);
    foreach ($manifestPack['attachments'] as $attachment) {
        $path = archive_storage_resolve_local_upload_path((string)($attachment['file_path'] ?? ''));
        if (!$path) continue;
        $uploaded = archive_storage_google_upload_file(
            $token,
            (string)$folder['folder_id'],
            basename($path),
            $path,
            trim((string)($attachment['mime_type'] ?? 'application/octet-stream')) ?: 'application/octet-stream'
        );
        $attachmentUploads[] = [
            'message_id' => (int)($attachment['message_id'] ?? 0),
            'file_name' => basename($path),
            'drive_file_id' => (string)($uploaded['id'] ?? ''),
            'size' => (int)filesize($path),
        ];
        $bytesUploaded += max(0, (int)filesize($path));
    }

    $permissionsJson = json_encode(['participants' => $manifestPack['participants']], JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
    $checksum = hash('sha256', $compressedManifest);

    $pdo->prepare(
        "UPDATE flow_archive_jobs SET
            status = 'completed',
            finished_at = NOW(),
            bytes_uploaded = :bytes_uploaded,
            attachment_count = :attachment_count,
            message_count = :message_count,
            manifest_file_id = :manifest_file_id,
            archive_path = :archive_path,
            checksum_sha256 = :checksum_sha256,
            summary_text = :summary_text,
            permissions_json = :permissions_json,
            updated_at = NOW()
         WHERE id = :id"
    )->execute([
        ':bytes_uploaded' => $bytesUploaded,
        ':attachment_count' => count($manifestPack['attachments']),
        ':message_count' => count($manifestPack['manifest']['messages']),
        ':manifest_file_id' => (string)($manifestFile['id'] ?? ''),
        ':archive_path' => (string)($folder['folder_path'] ?? ''),
        ':checksum_sha256' => $checksum,
        ':summary_text' => (string)$manifestPack['summary_text'],
        ':permissions_json' => $permissionsJson,
        ':id' => $jobId,
    ]);

    $stmt = $pdo->prepare(
        "INSERT INTO flow_archive_items
        (job_id, provider_id, module_type, entity_id, entity_label, conversation_jid, archive_status, provider_path, provider_file_id, manifest_file_id, summary_text, search_text, metadata_json, permissions_json, archived_at, created_at, updated_at)
        VALUES
        (:job_id, :provider_id, :module_type, :entity_id, :entity_label, :conversation_jid, 'archived', :provider_path, :provider_file_id, :manifest_file_id, :summary_text, :search_text, :metadata_json, :permissions_json, NOW(), NOW(), NOW())
        ON DUPLICATE KEY UPDATE
            job_id = VALUES(job_id),
            provider_id = VALUES(provider_id),
            entity_label = VALUES(entity_label),
            conversation_jid = VALUES(conversation_jid),
            archive_status = VALUES(archive_status),
            provider_path = VALUES(provider_path),
            provider_file_id = VALUES(provider_file_id),
            manifest_file_id = VALUES(manifest_file_id),
            summary_text = VALUES(summary_text),
            search_text = VALUES(search_text),
            metadata_json = VALUES(metadata_json),
            permissions_json = VALUES(permissions_json),
            archived_at = NOW(),
            updated_at = NOW()"
    );
    $stmt->execute([
        ':job_id' => $jobId,
        ':provider_id' => (int)$provider['id'],
        ':module_type' => (string)($job['module_type'] ?? ''),
        ':entity_id' => (string)($job['entity_id'] ?? ''),
        ':entity_label' => (string)($job['entity_label'] ?? ''),
        ':conversation_jid' => (string)($job['conversation_jid'] ?? ''),
        ':provider_path' => (string)($folder['folder_path'] ?? ''),
        ':provider_file_id' => (string)($folder['folder_id'] ?? ''),
        ':manifest_file_id' => (string)($manifestFile['id'] ?? ''),
        ':summary_text' => (string)$manifestPack['summary_text'],
        ':search_text' => (string)$manifestPack['search_text'],
        ':metadata_json' => json_encode([
            'manifest_drive_file_id' => (string)($manifestFile['id'] ?? ''),
            'attachment_drive_files' => $attachmentUploads,
            'message_count' => count($manifestPack['manifest']['messages']),
            'attachment_count' => count($manifestPack['attachments']),
            'checksum_sha256' => $checksum,
        ], JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE),
        ':permissions_json' => $permissionsJson,
    ]);

    return ['status' => true, 'job_id' => $jobId, 'message' => 'Archive job completed.', 'manifest_file_id' => (string)($manifestFile['id'] ?? '')];
}

function archive_storage_process_due_jobs(PDO $pdo, int $limit = 3): array
{
    archive_storage_ensure_schema($pdo);
    $rows = archive_storage_rows(
        $pdo,
        "SELECT id
         FROM flow_archive_jobs
         WHERE status IN ('queued', 'retry')
           AND COALESCE(next_retry_at, scheduled_at, created_at) <= NOW()
         ORDER BY COALESCE(next_retry_at, scheduled_at, created_at) ASC, id ASC
         LIMIT " . max(1, min($limit, 20))
    );
    $results = [];
    foreach ($rows as $row) {
        $jobId = (int)($row['id'] ?? 0);
        if ($jobId <= 0) continue;
        try {
            $results[] = archive_storage_process_job($pdo, $jobId);
        } catch (Throwable $e) {
            $pdo->prepare(
                "UPDATE flow_archive_jobs
                 SET status = 'failed',
                     retry_count = retry_count + 1,
                     next_retry_at = DATE_ADD(NOW(), INTERVAL LEAST(retry_count + 1, 12) * 10 MINUTE),
                     last_error = :last_error,
                     updated_at = NOW()
                 WHERE id = :id"
            )->execute([
                ':last_error' => mb_substr($e->getMessage(), 0, 4000),
                ':id' => $jobId,
            ]);
            $results[] = ['status' => false, 'job_id' => $jobId, 'error' => $e->getMessage()];
        }
    }
    return $results;
}

function archive_storage_schedule_policies(PDO $pdo): array
{
    archive_storage_ensure_schema($pdo);
    $scheduled = [];
    $policies = archive_storage_rows($pdo, "SELECT * FROM flow_archive_policies WHERE enabled = 1 AND module_type IN ('group','channel')");
    foreach ($policies as $policy) {
        $days = max(1, (int)($policy['inactivity_days'] ?? 90));
        $moduleType = (string)($policy['module_type'] ?? 'channel');
        $typeCondition = $moduleType === 'group' ? "COALESCE(group_type,'group')='group'" : "COALESCE(group_type,'channel')='channel'";
        $rows = archive_storage_rows(
            $pdo,
            "SELECT g.id, g.name, g.room_jid, MAX(m.created_at) AS last_message_at
             FROM xmpp_groups g
             LEFT JOIN xmpp_messages m ON m.to_jid = g.room_jid
             WHERE {$typeCondition} AND COALESCE(g.is_archived,0) = 1
             GROUP BY g.id, g.name, g.room_jid
             HAVING COALESCE(MAX(m.created_at), g.updated_at, g.created_at) <= DATE_SUB(NOW(), INTERVAL :days DAY)",
            [':days' => $days]
        );
        foreach ($rows as $row) {
            $entityId = (string)($row['id'] ?? '');
            if ($entityId === '') continue;
            $exists = archive_storage_one($pdo, "SELECT id FROM flow_archive_items WHERE module_type = :module_type AND entity_id = :entity_id LIMIT 1", [
                ':module_type' => $moduleType,
                ':entity_id' => $entityId,
            ]);
            if ($exists) continue;
            $duplicateJob = archive_storage_one($pdo, "SELECT id FROM flow_archive_jobs WHERE module_type = :module_type AND entity_id = :entity_id AND status IN ('queued','retry','running','completed') LIMIT 1", [
                ':module_type' => $moduleType,
                ':entity_id' => $entityId,
            ]);
            if ($duplicateJob) continue;
            $pdo->prepare(
                "INSERT INTO flow_archive_jobs
                 (policy_id, provider_id, module_type, entity_id, entity_label, conversation_jid, status, scheduled_at, created_by, created_at, updated_at)
                 VALUES
                 (:policy_id, :provider_id, :module_type, :entity_id, :entity_label, :conversation_jid, 'queued', NOW(), :created_by, NOW(), NOW())"
            )->execute([
                ':policy_id' => (int)$policy['id'],
                ':provider_id' => (int)$policy['provider_id'],
                ':module_type' => $moduleType,
                ':entity_id' => $entityId,
                ':entity_label' => (string)($row['name'] ?? ('Conversation ' . $entityId)),
                ':conversation_jid' => (string)($row['room_jid'] ?? ''),
                ':created_by' => (int)($policy['created_by'] ?? 0),
            ]);
            $scheduled[] = ['policy_id' => (int)$policy['id'], 'entity_id' => $entityId, 'module_type' => $moduleType];
        }
    }
    return $scheduled;
}

function archive_storage_download_google_file(string $accessToken, string $fileId): string
{
    $response = archive_storage_http_request(
        FLOW_ARCHIVE_GOOGLE_API_BASE . '/files/' . rawurlencode($fileId) . '?alt=media',
        'GET',
        ['Authorization' => 'Bearer ' . $accessToken],
        null,
        120
    );
    if (($response['status_code'] ?? 0) < 200 || ($response['status_code'] ?? 0) >= 300) {
        throw new RuntimeException('Google Drive download failed with HTTP ' . (int)($response['status_code'] ?? 0));
    }
    return (string)($response['body'] ?? '');
}

function archive_storage_item_for_user(PDO $pdo, int $viewerEmpId, string $itemIdOrConversation): ?array
{
    archive_storage_ensure_schema($pdo);
    $item = ctype_digit($itemIdOrConversation)
        ? archive_storage_one($pdo, 'SELECT * FROM flow_archive_items WHERE id = :id LIMIT 1', [':id' => (int)$itemIdOrConversation])
        : archive_storage_one($pdo, 'SELECT * FROM flow_archive_items WHERE conversation_jid = :conversation_jid LIMIT 1', [':conversation_jid' => $itemIdOrConversation]);
    if (!$item) return null;
    $permissions = $item['permissions_json'] !== null && $item['permissions_json'] !== '' ? json_decode((string)$item['permissions_json'], true) : [];
    $participants = array_map('intval', (array)($permissions['participants'] ?? []));
    if ($participants && !in_array($viewerEmpId, $participants, true)) {
        throw new RuntimeException('You do not have permission to view this archived conversation.');
    }
    return $item;
}

function archive_storage_stream_manifest(PDO $pdo, int $viewerEmpId, string $itemIdOrConversation): array
{
    $item = archive_storage_item_for_user($pdo, $viewerEmpId, $itemIdOrConversation);
    if (!$item) throw new RuntimeException('Archived conversation not found.');
    $provider = archive_storage_provider($pdo, (int)($item['provider_id'] ?? 0));
    if (!$provider) throw new RuntimeException('Archive provider not found.');
    $token = archive_storage_provider_access_token($pdo, $provider);
    $raw = archive_storage_download_google_file($token, (string)($item['manifest_file_id'] ?? ''));
    $json = gzdecode($raw);
    if (!is_string($json) || $json === '') throw new RuntimeException('Unable to decode archive manifest.');
    $manifest = json_decode($json, true);
    if (!is_array($manifest)) throw new RuntimeException('Archive manifest JSON is invalid.');
    return [
        'status' => true,
        'archived' => true,
        'item' => [
            'id' => (int)($item['id'] ?? 0),
            'module_type' => (string)($item['module_type'] ?? ''),
            'entity_id' => (string)($item['entity_id'] ?? ''),
            'entity_label' => (string)($item['entity_label'] ?? ''),
            'conversation_jid' => (string)($item['conversation_jid'] ?? ''),
            'archived_at' => (string)($item['archived_at'] ?? ''),
            'summary_text' => (string)($item['summary_text'] ?? ''),
            'archive_status' => (string)($item['archive_status'] ?? ''),
        ],
        'manifest' => $manifest,
    ];
}

function archive_storage_search_for_user(PDO $pdo, int $viewerEmpId, string $query, int $limit = 20): array
{
    archive_storage_ensure_schema($pdo);
    $query = trim($query);
    if ($query === '') return ['status' => true, 'rows' => []];
    $rows = archive_storage_rows(
        $pdo,
        "SELECT id, module_type, entity_id, entity_label, conversation_jid, archived_at, summary_text, metadata_json, permissions_json
         FROM flow_archive_items
         WHERE archive_status = 'archived'
           AND (
               entity_label LIKE :query
               OR summary_text LIKE :query
               OR search_text LIKE :query
               OR conversation_jid LIKE :query
           )
         ORDER BY archived_at DESC
         LIMIT " . max(1, min($limit, 100)),
        [':query' => '%' . $query . '%']
    );
    $filtered = [];
    foreach ($rows as $row) {
        $permissions = $row['permissions_json'] !== null && $row['permissions_json'] !== '' ? json_decode((string)$row['permissions_json'], true) : [];
        $participants = array_map('intval', (array)($permissions['participants'] ?? []));
        if ($participants && !in_array($viewerEmpId, $participants, true)) continue;
        $filtered[] = [
            'id' => (int)($row['id'] ?? 0),
            'module_type' => (string)($row['module_type'] ?? ''),
            'entity_id' => (string)($row['entity_id'] ?? ''),
            'entity_label' => (string)($row['entity_label'] ?? ''),
            'conversation_jid' => (string)($row['conversation_jid'] ?? ''),
            'archived_at' => (string)($row['archived_at'] ?? ''),
            'summary_text' => (string)($row['summary_text'] ?? ''),
            'badge' => 'Archived',
        ];
    }
    return ['status' => true, 'rows' => $filtered];
}
