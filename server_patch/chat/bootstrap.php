<?php

declare(strict_types=1);

require_once __DIR__ . '/../config.php';
require_once __DIR__ . '/../db.php';
require_once __DIR__ . '/EjabberdApi.php';
require_once __DIR__ . '/FirebasePush.php';

const SKYCHAT_DOMAIN = 'chat.skylinkonline.net';
const SKYCHAT_MUC_DOMAIN = 'conference.chat.skylinkonline.net';
const SKYCHAT_UPLOAD_DOMAIN = 'upload.chat.skylinkonline.net';
const SKYCHAT_SYSTEM_NOTIFICATION_JID = 'notification@chat.skylinkonline.net';
const SKYCHAT_WEBSOCKET_URL = 'wss://chat.skylinkonline.net:5280/xmpp-websocket';
const SKYCHAT_BOSH_URL = 'https://chat.skylinkonline.net:5443/bosh';
const SKYCHAT_DIAGNOSTIC_USERS = [116, 302];
const SKYCHAT_RELEASE_APPROVER_EMP_ID = 302;

function chat_apply_cors(): void
{
    $origin = trim((string)($_SERVER['HTTP_ORIGIN'] ?? ''));
    $allowed = [
        'http://chat.skylinkonline.net',
        'https://chat.skylinkonline.net',
        'http://localhost:52630',
        'http://localhost:60070',
        'http://localhost:60067',
    ];
    if ($origin !== '' && (in_array($origin, $allowed, true) || preg_match('#^http://localhost:\d+$#', $origin))) {
        header('Access-Control-Allow-Origin: ' . $origin);
        header('Vary: Origin');
        header('Access-Control-Allow-Credentials: true');
        header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
        header('Access-Control-Allow-Headers: Accept, Content-Type, X-Skylink-Trace-Id, X-Skylink-Web-Session, X-Requested-With');
        header('Access-Control-Max-Age: 86400');
    }
    if (($_SERVER['REQUEST_METHOD'] ?? '') === 'OPTIONS') {
        http_response_code(204);
        exit;
    }
}

chat_apply_cors();

function chat_diagnostics_allowed(int $empId): bool
{
    return in_array($empId, SKYCHAT_DIAGNOSTIC_USERS, true);
}

function chat_diagnostic_trace(
    int $empId,
    string $traceId,
    string $category,
    string $operation,
    float $durationMs,
    string $status = 'ok',
    array $metadata = []
): void {
    if (!chat_diagnostics_allowed($empId)) return;
    try {
        $pdo = chat_db();
        $stmt = $pdo->prepare(
            'INSERT INTO xmpp_diagnostic_traces
             (emp_id, trace_id, category, operation, duration_ms, status, metadata_json)
             VALUES (:emp_id, :trace_id, :category, :operation, :duration_ms, :status, :metadata)'
        );
        $stmt->execute([
            ':emp_id' => $empId,
            ':trace_id' => substr($traceId ?: bin2hex(random_bytes(12)), 0, 80),
            ':category' => substr($category, 0, 40),
            ':operation' => substr($operation, 0, 120),
            ':duration_ms' => max(0, $durationMs),
            ':status' => substr($status, 0, 30),
            ':metadata' => json_encode($metadata, JSON_UNESCAPED_SLASHES),
        ]);
    } catch (Throwable $e) {
        error_log('diagnostic trace skipped: ' . $e->getMessage());
    }
}

function chat_start(): void
{
    if (session_status() !== PHP_SESSION_ACTIVE) {
        $webSession = trim((string)($_SERVER['HTTP_X_SKYLINK_WEB_SESSION'] ?? ''));
        if ($webSession !== '' && preg_match('/^[A-Za-z0-9,-]{16,160}$/', $webSession)) {
            session_id($webSession);
        }
        $secure = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off');
        session_set_cookie_params([
            'lifetime' => 0,
            'path' => '/',
            'secure' => $secure,
            'httponly' => true,
            'samesite' => $secure ? 'None' : 'Lax',
        ]);
        session_start();
    }
}

function chat_json(array $data, int $status = 200): never
{
    http_response_code($status);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

function chat_upload_encryption_key(): ?string
{
    $raw = trim((string)(getenv('SKYLINK_UPLOAD_ENCRYPTION_KEY') ?: ''));
    if ($raw === '') return null;
    $decoded = base64_decode($raw, true);
    $material = $decoded !== false && strlen($decoded) >= 32 ? $decoded : $raw;
    return hash('sha256', $material, true);
}

function chat_encrypt_upload_file(string $source, string $target, string $mime, string $originalName): bool
{
    $key = chat_upload_encryption_key();
    if ($key === null || !function_exists('openssl_encrypt')) return false;
    $plain = file_get_contents($source);
    if ($plain === false) return false;
    $iv = random_bytes(12);
    $tag = '';
    $cipher = openssl_encrypt($plain, 'aes-256-gcm', $key, OPENSSL_RAW_DATA, $iv, $tag);
    if (!is_string($cipher) || strlen($tag) !== 16) return false;
    $payload = "SKYENC1" . $iv . $tag . $cipher;
    if (file_put_contents($target, $payload, LOCK_EX) === false) return false;
    $meta = [
        'encrypted' => true,
        'algorithm' => 'AES-256-GCM',
        'mime' => $mime,
        'name' => $originalName,
        'plain_size' => strlen($plain),
    ];
    file_put_contents($target . '.meta', json_encode($meta, JSON_UNESCAPED_SLASHES), LOCK_EX);
    return true;
}

function chat_decrypt_upload_file(string $target): ?string
{
    $key = chat_upload_encryption_key();
    if ($key === null || !function_exists('openssl_decrypt')) return null;
    $payload = file_get_contents($target);
    if ($payload === false || !str_starts_with($payload, 'SKYENC1')) return null;
    $iv = substr($payload, 7, 12);
    $tag = substr($payload, 19, 16);
    $cipher = substr($payload, 35);
    $plain = openssl_decrypt($cipher, 'aes-256-gcm', $key, OPENSSL_RAW_DATA, $iv, $tag);
    return is_string($plain) ? $plain : null;
}

function chat_upload_file_meta(string $target): array
{
    $metaPath = $target . '.meta';
    if (!is_file($metaPath)) return [];
    $json = json_decode((string)file_get_contents($metaPath), true);
    return is_array($json) ? $json : [];
}
function chat_public_upload_url(?string $url): string
{
    $value = trim((string)$url);
    if ($value === '') return '';
    $path = parse_url($value, PHP_URL_PATH);
    if (!is_string($path) || $path === '') return $value;
    $needle = '/uploads/';
    $pos = strpos($path, $needle);
    if ($pos === false) return $value;
    $relative = substr($path, $pos + strlen($needle));
    if ($relative === '' || str_contains($relative, '..')) return '';
    $scheme = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
    $host = trim((string)($_SERVER['HTTP_HOST'] ?? ''));
    $scriptDir = rtrim(str_replace('\\', '/', dirname((string)($_SERVER['SCRIPT_NAME'] ?? '/chat/bootstrap.php'))), '/');
    $baseDir = preg_replace('#/chat$#', '', $scriptDir) ?: '';
    return $scheme . '://' . $host . $baseDir . '/chat/media.php?path=' . rawurlencode($relative);
}

function chat_require_user(): array
{
    chat_start();
    $username = trim((string)($_SESSION['username'] ?? ''));
    if ($username === '') {
        chat_json(['status' => false, 'error' => 'Unauthorized'], 401);
    }
    $empId = !empty($_SESSION['employee_id']) ? (int)$_SESSION['employee_id'] : 0;
    if ($empId <= 0 && preg_match('/(\d+)$/', $username, $m)) {
        $empId = (int)$m[1];
    }
    if ($empId <= 0) {
        chat_json(['status' => false, 'error' => 'Employee id missing'], 403);
    }
    session_write_close();
    try {
        $pdo = chat_db();
        $touch = $pdo->prepare(
            'INSERT INTO xmpp_user_presence (emp_id, last_seen_at)
             VALUES (:emp_id, NOW())
             ON DUPLICATE KEY UPDATE
               last_seen_at = IF(last_seen_at < DATE_SUB(NOW(), INTERVAL 15 SECOND), NOW(), last_seen_at)'
        );
        $touch->execute([':emp_id' => $empId]);
    } catch (Throwable $presenceError) {
        error_log('presence heartbeat skipped: ' . $presenceError->getMessage());
    }
    return ['username' => $username, 'emp_id' => $empId];
}

function chat_employee_row(PDO $pdo, int $empId): array
{
    $colStmt = $pdo->prepare(
        "SELECT COLUMN_NAME
         FROM INFORMATION_SCHEMA.COLUMNS
         WHERE TABLE_SCHEMA = DATABASE()
           AND TABLE_NAME = 'employee'
           AND COLUMN_NAME IN ('mobile', 'phone', 'contact_no', 'contact_number', 'phone_number', 'mobile_no', 'personal_mobile', 'official_mobile')
         ORDER BY FIELD(COLUMN_NAME, 'mobile', 'mobile_no', 'contact_no', 'contact_number', 'phone', 'phone_number', 'official_mobile', 'personal_mobile')
         LIMIT 1"
    );
    $colStmt->execute();
    $phoneCol = (string)($colStmt->fetchColumn() ?: '');
    $phoneSql = $phoneCol !== '' ? "`{$phoneCol}` AS xmpp_password_source" : "'' AS xmpp_password_source";
    $stmt = $pdo->prepare(
        "SELECT emp_id, name, COALESCE(NULLIF(designation, ''), NULLIF(department, ''), NULLIF(emp_type, ''), '') AS designation, {$phoneSql}
         FROM employee
         WHERE status = 1 AND emp_id = :emp_id
         LIMIT 1"
    );
    $stmt->execute([':emp_id' => $empId]);
    return $stmt->fetch(PDO::FETCH_ASSOC) ?: [];
}


function chat_employee_type_label(mixed $empType, ?string $override = null): string
{
    $override = strtoupper(trim((string)$override));
    if (in_array($override, ['A', 'B', 'C1', 'C2'], true)) return $override;
    $raw = trim((string)$empType);
    if ($raw === '1') return 'B';
    if ($raw === '0') return 'C1';
    $upper = strtoupper($raw);
    if (in_array($upper, ['A', 'B', 'C1', 'C2'], true)) return $upper;
    return $raw !== '' ? $raw : 'C1';
}

function chat_employee_type(PDO $chatPdo, PDO $employeePdo, int $empId): string
{
    $override = '';
    try {
        $stmt = $chatPdo->prepare("SELECT employee_type FROM flow_admin_employee_types WHERE emp_id = :emp_id LIMIT 1");
        $stmt->execute([':emp_id' => $empId]);
        $override = (string)($stmt->fetchColumn() ?: '');
    } catch (Throwable $ignored) {
        $override = '';
    }
    $empType = '';
    try {
        $stmt = $employeePdo->prepare('SELECT emp_type FROM employee WHERE emp_id = :emp_id LIMIT 1');
        $stmt->execute([':emp_id' => $empId]);
        $empType = (string)($stmt->fetchColumn() ?: '');
    } catch (Throwable $ignored) {
        $empType = '';
    }
    return chat_employee_type_label($empType, $override);
}

function chat_can_create_group_channel(PDO $chatPdo, PDO $employeePdo, int $empId): bool
{
    return !in_array(chat_employee_type($chatPdo, $employeePdo, $empId), ['C1', 'C2'], true);
}

function chat_require_group_channel_creator(PDO $chatPdo, PDO $employeePdo, int $empId): void
{
    $type = chat_employee_type($chatPdo, $employeePdo, $empId);
    if (in_array($type, ['C1', 'C2'], true)) {
        chat_json([
            'status' => false,
            'error' => 'Your user type is not allowed to create groups or channels.',
            'employee_type' => $type,
        ], 403);
    }
}
function chat_jid(int $empId): string
{
    return $empId . '@' . SKYCHAT_DOMAIN;
}

function chat_is_user_jid(string $jid): bool
{
    return preg_match('/^\d+@chat\.skylinkonline\.net$/i', $jid) === 1;
}

function chat_is_system_notification_jid(string $jid): bool
{
    return strtolower(trim($jid)) === SKYCHAT_SYSTEM_NOTIFICATION_JID;
}

function chat_is_room_jid(string $jid): bool
{
    return preg_match('/^[a-z0-9][a-z0-9-]*@conference\.chat\.skylinkonline\.net$/i', $jid) === 1;
}

function chat_group_for_member(PDO $pdo, string $roomJid, int $empId): array
{
    $stmt = $pdo->prepare(
        'SELECT g.id, g.room_name, g.room_jid, gm.role
         FROM xmpp_groups g
         INNER JOIN xmpp_group_members gm ON gm.group_id = g.id
         WHERE g.room_jid = :room_jid AND gm.emp_id = :emp_id
         LIMIT 1'
    );
    $stmt->execute([':room_jid' => strtolower($roomJid), ':emp_id' => $empId]);
    return $stmt->fetch(PDO::FETCH_ASSOC) ?: [];
}

function chat_firebase_credentials_path(): string
{
    $environment = trim((string)(getenv('SKYCHAT_FIREBASE_CREDENTIALS') ?: ''));
    if ($environment !== '') return $environment;
    if (defined('SKYCHAT_FIREBASE_CREDENTIALS')) {
        return trim((string)SKYCHAT_FIREBASE_CREDENTIALS);
    }
    $local = dirname(__DIR__) . '/firebase-service-account.json';
    if (is_file($local)) return $local;
    return '/etc/skylink/firebase-service-account.json';
}

function chat_push_preview(string $body, string $fileName = ''): string
{
    if (str_starts_with($body, 'SKYLINK_FILE:')) {
        $decoded = json_decode(substr($body, strlen('SKYLINK_FILE:')), true);
        if (is_array($decoded)) {
            $caption = trim((string)($decoded['caption'] ?? ''));
            if ($caption !== '') return $caption;
            $name = trim((string)($decoded['name'] ?? $fileName));
            return $name !== '' ? 'Ã°Å¸â€œÅ½ ' . $name : 'Ã°Å¸â€œÅ½ File';
        }
    }
    if (str_starts_with($body, 'SKYLINK_LOCATION:')) {
        $decoded = json_decode(substr($body, strlen('SKYLINK_LOCATION:')), true);
        if (is_array($decoded)) {
            $label = !empty($decoded['is_live']) ? 'Live location' : 'Current location';
            $address = trim((string)($decoded['location_address'] ?? ''));
            if ($address !== '') return $label . ' - ' . $address;
            return $label;
        }
    }
    if ($fileName !== '') return 'Ã°Å¸â€œÅ½ ' . $fileName;
    $plain = trim(preg_replace('/\s+/', ' ', $body) ?: '');
    return mb_strlen($plain) > 180 ? mb_substr($plain, 0, 177) . 'Ã¢â‚¬Â¦' : ($plain ?: 'New message');
}

function chat_push_recipient_ids(PDO $pdo, string $toJid, int $senderEmpId): array
{
    if (chat_is_user_jid($toJid) &&
        preg_match('/^(\d+)@/i', $toJid, $match)) {
        $empId = (int)$match[1];
        return $empId > 0 && $empId !== $senderEmpId ? [$empId] : [];
    }
    if (!chat_is_room_jid($toJid)) return [];
    $stmt = $pdo->prepare(
        'SELECT gm.emp_id
         FROM xmpp_group_members gm
         INNER JOIN xmpp_groups g ON g.id = gm.group_id
         WHERE g.room_jid = :room_jid AND gm.emp_id <> :sender'
    );
    $stmt->execute([':room_jid' => strtolower($toJid), ':sender' => $senderEmpId]);
    return array_values(array_unique(array_map('intval', $stmt->fetchAll(PDO::FETCH_COLUMN) ?: [])));
}

function chat_message_visibility_sql(string $messageAlias = 'm'): string
{
    $alias = preg_replace('/[^A-Za-z0-9_]/', '', $messageAlias) ?: 'm';
    return "(COALESCE({$alias}.visibility_mode, 'all') <> 'selected' OR {$alias}.from_jid = :visibility_me_jid OR EXISTS (SELECT 1 FROM xmpp_message_recipients vmr WHERE vmr.message_id = {$alias}.id AND vmr.emp_id = :visibility_emp_id))";
}

function chat_visible_message_condition(string $messageAlias = 'm'): string
{
    return chat_message_visibility_sql($messageAlias);
}

function chat_send_push_notifications(
    PDO $pdo,
    int $senderEmpId,
    string $senderName,
    string $toJid,
    string $body,
    string $fileName = '',
    string $groupName = '',
    array $mentionedEmpIds = [],
    array $recipientEmpIds = []
): void {
    $recipients = $recipientEmpIds
        ? array_values(array_unique(array_filter(array_map('intval', $recipientEmpIds), static fn(int $id): bool => $id > 0 && $id !== $senderEmpId)))
        : chat_push_recipient_ids($pdo, $toJid, $senderEmpId);
    if (!$recipients) return;
    $placeholders = implode(',', array_fill(0, count($recipients), '?'));
    $stmt = $pdo->prepare(
        "SELECT emp_id, token FROM xmpp_push_tokens WHERE emp_id IN ({$placeholders})"
    );
    $stmt->execute($recipients);
    $tokens = $stmt->fetchAll(PDO::FETCH_ASSOC) ?: [];
    if (!$tokens) return;

    $push = new FirebasePush(chat_firebase_credentials_path());
    $title = $groupName !== '' ? $senderName . ' Ã‚Â· ' . $groupName : $senderName;
    $preview = chat_push_preview($body, $fileName);
    $baseTitle = $title;
    foreach ($tokens as $row) {
        $recipientId = (int)$row['emp_id'];
        $isMention = in_array($recipientId, $mentionedEmpIds, true);
        if (!$isMention && chat_is_muted($pdo, $recipientId, $toJid)) continue;
        $title = $isMention ? '@ Mention from ' . $senderName : $baseTitle;
        try {
            $push->send((string)$row['token'], $title, $preview, [
                'jid' => $toJid,
                'sender_id' => (string)$senderEmpId,
                'sender_name' => $senderName,
                'body' => $preview,
                'type' => chat_is_room_jid($toJid) ? 'groupchat' : 'chat',
                'is_mention' => $isMention ? '1' : '0',
            ]);
        } catch (Throwable $e) {
            error_log('Firebase push failed for employee ' . (int)$row['emp_id'] . ': ' . $e->getMessage());
        }
    }
}

function chat_ensure_push_queue(PDO $pdo): void
{
    $pdo->exec(
        'CREATE TABLE IF NOT EXISTS xmpp_push_queue (
            id BIGINT AUTO_INCREMENT PRIMARY KEY,
            sender_emp_id INT NOT NULL,
            sender_name VARCHAR(255) NOT NULL,
            to_jid VARCHAR(255) NOT NULL,
            body TEXT NULL,
            file_name VARCHAR(255) NULL,
            group_name VARCHAR(255) NULL,
            mentioned_emp_ids TEXT NULL,
            status VARCHAR(24) NOT NULL DEFAULT \'pending\',
            attempts INT NOT NULL DEFAULT 0,
            error TEXT NULL,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            INDEX idx_push_queue_status (status, id),
            INDEX idx_push_queue_created (created_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci'
    );
    chat_ensure_column($pdo, 'xmpp_push_queue', 'recipient_emp_ids', 'TEXT NULL AFTER mentioned_emp_ids');
}

function chat_enqueue_push_notification(
    PDO $pdo,
    int $senderEmpId,
    string $senderName,
    string $toJid,
    string $body,
    string $fileName = '',
    string $groupName = '',
    array $mentionedEmpIds = [],
    array $recipientEmpIds = []
): int {
    chat_ensure_push_queue($pdo);
    $stmt = $pdo->prepare(
        'INSERT INTO xmpp_push_queue
         (sender_emp_id, sender_name, to_jid, body, file_name, group_name, mentioned_emp_ids, recipient_emp_ids)
         VALUES (:sender_emp_id, :sender_name, :to_jid, :body, :file_name, :group_name, :mentioned_emp_ids, :recipient_emp_ids)'
    );
    $stmt->execute([
        ':sender_emp_id' => $senderEmpId,
        ':sender_name' => mb_substr($senderName, 0, 255),
        ':to_jid' => strtolower($toJid),
        ':body' => $body,
        ':file_name' => $fileName !== '' ? mb_substr($fileName, 0, 255) : null,
        ':group_name' => $groupName !== '' ? mb_substr($groupName, 0, 255) : null,
        ':mentioned_emp_ids' => $mentionedEmpIds ? json_encode(array_values(array_map('intval', $mentionedEmpIds))) : null,
        ':recipient_emp_ids' => $recipientEmpIds ? json_encode(array_values(array_unique(array_map('intval', $recipientEmpIds)))) : null,
    ]);
    return (int)($pdo->lastInsertId() ?: 0);
}

function chat_spawn_push_worker(): void
{
    if (PHP_SAPI === 'cli') return;
    $php = PHP_BINARY ?: 'php';
    $script = __DIR__ . '/push_worker.php';
    if (!is_file($script)) return;
    $cmd = escapeshellarg($php) . ' ' . escapeshellarg($script) . ' > /dev/null 2>&1 &';
    @exec($cmd);
}

function chat_process_push_queue(int $limit = 25): int
{
    $pdo = chat_db();
    chat_ensure_push_queue($pdo);
    $stmt = $pdo->prepare(
        'SELECT * FROM xmpp_push_queue
         WHERE status IN (\'pending\', \'retry\') AND attempts < 5
         ORDER BY id ASC
         LIMIT :limit'
    );
    $stmt->bindValue(':limit', max(1, min(100, $limit)), PDO::PARAM_INT);
    $stmt->execute();
    $jobs = $stmt->fetchAll(PDO::FETCH_ASSOC) ?: [];
    $processed = 0;
    foreach ($jobs as $job) {
        $jobId = (int)$job['id'];
        $lock = $pdo->prepare(
            'UPDATE xmpp_push_queue
             SET status = \'processing\', attempts = attempts + 1, updated_at = NOW()
             WHERE id = :id AND status IN (\'pending\', \'retry\')'
        );
        $lock->execute([':id' => $jobId]);
        if ($lock->rowCount() < 1) continue;
        $started = microtime(true);
        try {
            $mentioned = json_decode((string)($job['mentioned_emp_ids'] ?? '[]'), true);
            if (!is_array($mentioned)) $mentioned = [];
            $recipients = json_decode((string)($job['recipient_emp_ids'] ?? '[]'), true);
            if (!is_array($recipients)) $recipients = [];
            chat_send_push_notifications(
                $pdo,
                (int)$job['sender_emp_id'],
                (string)$job['sender_name'],
                (string)$job['to_jid'],
                (string)($job['body'] ?? ''),
                (string)($job['file_name'] ?? ''),
                (string)($job['group_name'] ?? ''),
                array_values(array_map('intval', $mentioned)),
                array_values(array_map('intval', $recipients))
            );
            $done = $pdo->prepare('UPDATE xmpp_push_queue SET status = \'sent\', error = NULL, updated_at = NOW() WHERE id = :id');
            $done->execute([':id' => $jobId]);
            chat_diagnostic_trace((int)$job['sender_emp_id'], 'pushq-' . $jobId, 'notification', 'dispatch_push_async', (microtime(true) - $started) * 1000, 'success');
            $processed++;
        } catch (Throwable $e) {
            $fail = $pdo->prepare(
                'UPDATE xmpp_push_queue
                 SET status = CASE WHEN attempts >= 5 THEN \'failed\' ELSE \'retry\' END,
                     error = :error,
                     updated_at = NOW()
                 WHERE id = :id'
            );
            $fail->execute([':id' => $jobId, ':error' => mb_substr($e->getMessage(), 0, 1000)]);
            chat_diagnostic_trace((int)$job['sender_emp_id'], 'pushq-' . $jobId, 'notification', 'dispatch_push_async', (microtime(true) - $started) * 1000, 'error');
        }
    }
    return $processed;
}
function chat_db(): PDO
{
    return getDB();
}

function chat_user_payload(PDO $employeePdo, int $empId, ?string $jid = null, ?bool $online = null): array
{
    $employee = [];
    try {
        $employee = chat_employee_row($employeePdo, $empId);
    } catch (Throwable $e) {
        error_log('chat employee hydrate failed: ' . $e->getMessage());
    }
    $finalJid = $jid ?: chat_jid($empId);
    $avatarUrl = '';
    try {
        $avatarStmt = chat_db()->prepare('SELECT avatar_url FROM xmpp_users WHERE emp_id = :emp_id LIMIT 1');
        $avatarStmt->execute([':emp_id' => $empId]);
        $avatarUrl = (string)($avatarStmt->fetchColumn() ?: '');
    } catch (Throwable $e) {
        error_log('chat avatar hydrate failed: ' . $e->getMessage());
    }
    return [
        'emp_id' => (string)$empId,
        'name' => (string)($employee['name'] ?? ('EMP-' . $empId)),
        'designation' => (string)($employee['designation'] ?? 'Chat user'),
        'jid' => $finalJid,
        'online' => $online ?? chat_ejabberd_is_online($finalJid),
        'avatar_url' => chat_public_upload_url($avatarUrl),
    ];
}

function chat_ejabberd_api_url(): string
{
    return rtrim((string)(defined('SKYCHAT_EJABBERD_API_URL') ? SKYCHAT_EJABBERD_API_URL : 'https://chat.skylinkonline.net:5443/api'), '/');
}

function chat_ejabberd_admin_jid(): string
{
    return (string)(defined('SKYCHAT_EJABBERD_ADMIN_JID') ? SKYCHAT_EJABBERD_ADMIN_JID : '');
}

function chat_ejabberd_admin_password(): string
{
    return (string)(defined('SKYCHAT_EJABBERD_ADMIN_PASSWORD') ? SKYCHAT_EJABBERD_ADMIN_PASSWORD : '');
}

function chat_ejabberd_client(): EjabberdApi
{
    static $client = null;
    if ($client === null) {
        $client = new EjabberdApi(
            chat_ejabberd_api_url(),
            chat_ejabberd_admin_jid(),
            chat_ejabberd_admin_password(),
            SKYCHAT_DOMAIN,
            SKYCHAT_MUC_DOMAIN
        );
    }
    return $client;
}

function chat_ejabberd_api(string $command, array $payload = []): mixed
{
    return chat_ejabberd_client()->request($command, $payload);
}

function chat_ejabberd_registered_users(): array
{
    return chat_ejabberd_client()->registeredUsers();
}

function chat_ejabberd_connected_users(): array
{
    return chat_ejabberd_client()->connectedUsers();
}

function chat_ejabberd_is_online(string $jid): bool
{
    try {
        return chat_ejabberd_client()->isOnline($jid);
    } catch (Throwable $e) {
        error_log('ejabberd presence unavailable: ' . $e->getMessage());
        return false;
    }
}

function chat_ejabberd_account_exists(int $empId): bool
{
    return chat_ejabberd_client()->accountExists((string)$empId);
}

function chat_ejabberd_register(int $empId, string $password): void
{
    chat_ejabberd_client()->register((string)$empId, $password);
}

function chat_ejabberd_sync_password(int $empId, string $password): void
{
    $client = chat_ejabberd_client();
    $user = (string)$empId;
    if ($client->accountExists($user)) {
        $client->changePassword($user, $password);
        return;
    }
    $client->register($user, $password);
}

function chat_ejabberd_send_message(string $fromJid, string $toJid, string $body): mixed
{
    return chat_ejabberd_client()->sendMessage($fromJid, $toJid, $body);
}

function chat_ensure_schema(PDO $pdo): void
{
    $schemaMarker = sys_get_temp_dir() . '/skylink_chat_schema_20260702_v6';
    if (is_file($schemaMarker)) return;
    $pdo->exec(
        'CREATE TABLE IF NOT EXISTS xmpp_users (
            id INT AUTO_INCREMENT PRIMARY KEY,
            emp_id INT NOT NULL UNIQUE,
            jid VARCHAR(255) NOT NULL UNIQUE,
            xmpp_password VARCHAR(255) NOT NULL,
            status TINYINT NOT NULL DEFAULT 1,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci'
    );
    $pdo->exec(
        'CREATE TABLE IF NOT EXISTS xmpp_groups (
            id INT AUTO_INCREMENT PRIMARY KEY,
            room_name VARCHAR(150) NOT NULL,
            room_jid VARCHAR(255) NOT NULL UNIQUE,
            created_by_emp_id INT NOT NULL,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci'
    );
    $pdo->exec(
        'CREATE TABLE IF NOT EXISTS xmpp_group_members (
            id INT AUTO_INCREMENT PRIMARY KEY,
            group_id INT NOT NULL,
            emp_id INT NOT NULL,
            role VARCHAR(16) NOT NULL DEFAULT \'member\',
            joined_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            UNIQUE KEY uq_xmpp_group_member (group_id, emp_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci'
    );
    $pdo->exec(
        'CREATE TABLE IF NOT EXISTS xmpp_messages (
            id BIGINT AUTO_INCREMENT PRIMARY KEY,
            from_jid VARCHAR(255) NOT NULL,
            to_jid VARCHAR(255) NOT NULL,
            body TEXT NOT NULL,
            message_type VARCHAR(24) NOT NULL DEFAULT \'chat\',
            status VARCHAR(24) NOT NULL DEFAULT \'sent\',
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_xmpp_messages_from_created (from_jid, created_at),
            INDEX idx_xmpp_messages_to_created (to_jid, created_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci'
    );
    chat_ensure_column($pdo, 'xmpp_messages', 'file_url', 'VARCHAR(500) NULL AFTER body');
    chat_ensure_column($pdo, 'xmpp_messages', 'file_name', 'VARCHAR(255) NULL AFTER file_url');
    chat_ensure_column($pdo, 'xmpp_messages', 'file_type', 'VARCHAR(255) NULL AFTER file_name');
    $pdo->exec('ALTER TABLE xmpp_messages MODIFY file_type VARCHAR(255) NULL');
    chat_ensure_column($pdo, 'xmpp_messages', 'file_size', 'BIGINT NOT NULL DEFAULT 0 AFTER file_type');
    chat_ensure_column($pdo, 'xmpp_messages', 'file_restricted', 'TINYINT(1) NOT NULL DEFAULT 0 AFTER file_size');
    chat_ensure_column($pdo, 'xmpp_messages', 'read_at', 'DATETIME NULL AFTER status');
    chat_ensure_column($pdo, 'xmpp_messages', 'reply_to_id', 'BIGINT NULL AFTER message_type');
    chat_ensure_column($pdo, 'xmpp_messages', 'mentions_json', 'TEXT NULL AFTER reply_to_id');
    chat_ensure_column($pdo, 'xmpp_messages', 'deleted_at', 'DATETIME NULL AFTER read_at');
    chat_ensure_column($pdo, 'xmpp_messages', 'edited_at', 'DATETIME NULL AFTER deleted_at');
    chat_ensure_column($pdo, 'xmpp_messages', 'thread_root_id', 'BIGINT NULL AFTER reply_to_id');
    chat_ensure_column($pdo, 'xmpp_messages', 'source_device', 'VARCHAR(32) NOT NULL DEFAULT \'unknown\' AFTER mentions_json');
    chat_ensure_column($pdo, 'xmpp_messages', 'source_name', 'VARCHAR(120) NULL AFTER source_device');
    chat_ensure_column($pdo, 'xmpp_messages', 'visibility_mode', 'VARCHAR(16) NOT NULL DEFAULT \'all\' AFTER source_name');
    $pdo->exec(
        'CREATE TABLE IF NOT EXISTS xmpp_message_recipients (
            message_id BIGINT NOT NULL,
            emp_id INT NOT NULL,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (message_id, emp_id),
            INDEX idx_xmpp_message_recipients_emp (emp_id, message_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci'
    );
    $pdo->exec(
        'CREATE TABLE IF NOT EXISTS external_contacts (
            id INT AUTO_INCREMENT PRIMARY KEY,
            display_name VARCHAR(160) NOT NULL DEFAULT \'\',
            email VARCHAR(190) NULL,
            phone VARCHAR(40) NULL,
            whatsapp_number VARCHAR(40) NULL,
            telegram_username VARCHAR(120) NULL,
            telegram_chat_id VARCHAR(120) NULL,
            status TINYINT NOT NULL DEFAULT 1,
            created_by_emp_id INT NULL,
            updated_by_emp_id INT NULL,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            INDEX idx_external_contacts_name (display_name),
            INDEX idx_external_contacts_status (status)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci'
    );
    chat_ensure_column($pdo, 'external_contacts', 'display_name', 'VARCHAR(160) NOT NULL DEFAULT \'\'');
    chat_ensure_column($pdo, 'external_contacts', 'email', 'VARCHAR(190) NULL');
    chat_ensure_column($pdo, 'external_contacts', 'phone', 'VARCHAR(40) NULL');
    chat_ensure_column($pdo, 'external_contacts', 'whatsapp_number', 'VARCHAR(40) NULL');
    chat_ensure_column($pdo, 'external_contacts', 'telegram_username', 'VARCHAR(120) NULL');
    chat_ensure_column($pdo, 'external_contacts', 'telegram_chat_id', 'VARCHAR(120) NULL');
    chat_ensure_column($pdo, 'external_contacts', 'status', 'TINYINT NOT NULL DEFAULT 1');
    chat_ensure_column($pdo, 'external_contacts', 'created_by_emp_id', 'INT NULL');
    chat_ensure_column($pdo, 'external_contacts', 'updated_by_emp_id', 'INT NULL');
    chat_ensure_column($pdo, 'external_contacts', 'created_at', 'DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP');
    chat_ensure_column($pdo, 'external_contacts', 'updated_at', 'DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP');
    $pdo->exec(
        'CREATE TABLE IF NOT EXISTS xmpp_group_external_members (
            id BIGINT AUTO_INCREMENT PRIMARY KEY,
            group_id INT NOT NULL,
            external_contact_id INT NOT NULL,
            delivery_channels VARCHAR(160) NOT NULL DEFAULT \'\',
            mention_token VARCHAR(180) NOT NULL DEFAULT \'\',
            status TINYINT NOT NULL DEFAULT 1,
            added_by_emp_id INT NULL,
            added_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            removed_at DATETIME NULL,
            UNIQUE KEY uq_group_external_contact (group_id, external_contact_id),
            INDEX idx_group_external_group (group_id, status),
            INDEX idx_group_external_contact (external_contact_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci'
    );
    chat_ensure_column($pdo, 'xmpp_group_external_members', 'delivery_channels', 'VARCHAR(160) NOT NULL DEFAULT \'\'');
    chat_ensure_column($pdo, 'xmpp_group_external_members', 'mention_token', 'VARCHAR(180) NOT NULL DEFAULT \'\'');
    chat_ensure_column($pdo, 'xmpp_group_external_members', 'status', 'TINYINT NOT NULL DEFAULT 1');
    chat_ensure_column($pdo, 'xmpp_group_external_members', 'added_by_emp_id', 'INT NULL');
    chat_ensure_column($pdo, 'xmpp_group_external_members', 'added_at', 'DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP');
    chat_ensure_column($pdo, 'xmpp_group_external_members', 'removed_at', 'DATETIME NULL');
    $pdo->exec(
        'CREATE TABLE IF NOT EXISTS xmpp_external_delivery_queue (
            id BIGINT AUTO_INCREMENT PRIMARY KEY,
            group_id INT NOT NULL,
            external_contact_id INT NOT NULL,
            message_id BIGINT NULL,
            event_type VARCHAR(40) NOT NULL,
            channel VARCHAR(24) NOT NULL,
            destination VARCHAR(255) NOT NULL,
            subject VARCHAR(255) NOT NULL,
            body TEXT NOT NULL,
            status VARCHAR(24) NOT NULL DEFAULT \'queued\',
            attempts INT NOT NULL DEFAULT 0,
            last_error TEXT NULL,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            sent_at DATETIME NULL,
            INDEX idx_external_delivery_status (status, created_at),
            INDEX idx_external_delivery_message (message_id),
            INDEX idx_external_delivery_group (group_id, external_contact_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci'
    );
    chat_ensure_column($pdo, 'xmpp_users', 'avatar_url', 'VARCHAR(500) NULL AFTER jid');
    chat_ensure_column($pdo, 'xmpp_groups', 'avatar_url', 'VARCHAR(500) NULL AFTER room_jid');
    chat_ensure_column($pdo, 'xmpp_groups', 'group_type', 'VARCHAR(20) NOT NULL DEFAULT \'group\' AFTER avatar_url');
    chat_ensure_column($pdo, 'xmpp_groups', 'is_archived', 'TINYINT NOT NULL DEFAULT 0 AFTER group_type');
    chat_ensure_column($pdo, 'xmpp_groups', 'archived_at', 'DATETIME NULL AFTER is_archived');
    chat_ensure_column($pdo, 'xmpp_groups', 'channel_kind', 'VARCHAR(40) NOT NULL DEFAULT \'operational\' AFTER group_type');
    chat_ensure_column($pdo, 'xmpp_groups', 'status', 'VARCHAR(40) NOT NULL DEFAULT \'Open\' AFTER channel_kind');
    chat_ensure_column($pdo, 'xmpp_groups', 'target_date', 'DATETIME NULL AFTER status');
    chat_ensure_column($pdo, 'xmpp_groups', 'next_action_date', 'DATETIME NULL AFTER target_date');
    chat_ensure_column($pdo, 'xmpp_groups', 'sla_minutes', 'INT NULL AFTER next_action_date');
    chat_ensure_column($pdo, 'xmpp_groups', 'priority', 'VARCHAR(20) NOT NULL DEFAULT \'Normal\' AFTER sla_minutes');
    chat_ensure_column($pdo, 'xmpp_groups', 'owner_emp_id', 'INT NULL AFTER priority');
    chat_ensure_column($pdo, 'xmpp_groups', 'stale_alert_minutes', 'INT NULL AFTER owner_emp_id');
    chat_ensure_column($pdo, 'xmpp_groups', 'metadata_json', 'TEXT NULL AFTER stale_alert_minutes');
    chat_ensure_column($pdo, 'xmpp_groups', 'wakeup_enabled', 'TINYINT NOT NULL DEFAULT 0 AFTER metadata_json');
    chat_ensure_column($pdo, 'xmpp_groups', 'wakeup_interval_minutes', 'INT NOT NULL DEFAULT 1440 AFTER wakeup_enabled');
    chat_ensure_column($pdo, 'xmpp_groups', 'wakeup_last_sent_at', 'DATETIME NULL AFTER wakeup_interval_minutes');
    chat_ensure_column($pdo, 'xmpp_groups', 'wakeup_updated_by_emp_id', 'INT NULL AFTER wakeup_last_sent_at');
    chat_ensure_column($pdo, 'xmpp_groups', 'wakeup_updated_at', 'DATETIME NULL AFTER wakeup_updated_by_emp_id');
    chat_ensure_column($pdo, 'xmpp_groups', 'channel_definition_id', 'INT NULL AFTER channel_kind');
    chat_ensure_column($pdo, 'xmpp_groups', 'channel_template_key', 'VARCHAR(80) NULL AFTER channel_definition_id');
    $pdo->exec(
        'CREATE TABLE IF NOT EXISTS xmpp_channel_definitions (
            id INT AUTO_INCREMENT PRIMARY KEY,
            type_key VARCHAR(40) NOT NULL UNIQUE,
            name VARCHAR(80) NOT NULL,
            description TEXT NULL,
            ui_schema_json TEXT NULL,
            ai_marshal_json TEXT NULL,
            sop_json TEXT NULL,
            sla_json TEXT NULL,
            kpi_json TEXT NULL,
            checklist_json TEXT NULL,
            permissions_json TEXT NULL,
            widgets_json TEXT NULL,
            workflows_json TEXT NULL,
            extension_table VARCHAR(80) NULL,
            active TINYINT NOT NULL DEFAULT 1,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            INDEX idx_channel_definitions_active (active, type_key)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci'
    );
    $pdo->exec(
        'CREATE TABLE IF NOT EXISTS xmpp_channel_relationships (
            id BIGINT AUTO_INCREMENT PRIMARY KEY,
            source_group_id INT NOT NULL,
            target_group_id INT NOT NULL,
            relationship_type VARCHAR(40) NOT NULL,
            metadata_json TEXT NULL,
            created_by_emp_id INT NOT NULL,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_channel_relationship_source (source_group_id, relationship_type),
            INDEX idx_channel_relationship_target (target_group_id, relationship_type),
            UNIQUE KEY uq_channel_relationship (source_group_id, target_group_id, relationship_type)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci'
    );
    $pdo->exec(
        'CREATE TABLE IF NOT EXISTS xmpp_channel_audit_log (
            id BIGINT AUTO_INCREMENT PRIMARY KEY,
            group_id INT NOT NULL,
            event_type VARCHAR(80) NOT NULL,
            actor_emp_id INT NULL,
            old_json TEXT NULL,
            new_json TEXT NULL,
            metadata_json TEXT NULL,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_channel_audit_group_created (group_id, created_at),
            INDEX idx_channel_audit_event (event_type, created_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci'
    );
    foreach ([
        'xmpp_channel_incident' => 'severity VARCHAR(20) NULL, impact_scope VARCHAR(120) NULL, root_cause TEXT NULL, resolution_summary TEXT NULL',
        'xmpp_channel_action' => 'action_owner_emp_id INT NULL, due_at DATETIME NULL, completion_notes TEXT NULL',
        'xmpp_channel_operational' => 'ops_area VARCHAR(120) NULL, cadence VARCHAR(40) NULL, escalation_policy VARCHAR(120) NULL',
        'xmpp_channel_project' => 'project_code VARCHAR(80) NULL, milestone VARCHAR(160) NULL, budget_ref VARCHAR(120) NULL',
        'xmpp_channel_announcement' => 'audience VARCHAR(160) NULL, publish_at DATETIME NULL, expires_at DATETIME NULL',
    ] as $table => $columnsSql) {
        $pdo->exec(
            'CREATE TABLE IF NOT EXISTS ' . $table . ' (
                group_id INT NOT NULL PRIMARY KEY,
                ' . $columnsSql . ',
                metadata_json TEXT NULL,
                created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci'
        );
    }
    $definitions = [
        ['incident', 'Incident', 'Incident command channel with triage, severity, SOP, SLA and action escalation.', 'xmpp_channel_incident', 240, 'High', ['triage', 'containment', 'root_cause', 'resolution'], ['severity', 'sla', 'open_actions', 'mttr'], ['incident_brief', 'sla_clock', 'linked_actions', 'checklist'], ['incident_to_action', 'incident_update', 'incident_close']],
        ['action', 'Action', 'Action tracking channel for owners, due dates, checklists and completion evidence.', 'xmpp_channel_action', 1440, 'Normal', ['owner_assigned', 'due_date_set', 'evidence_added', 'completed'], ['completion_rate', 'overdue_actions'], ['action_owner', 'due_date', 'checklist', 'evidence'], ['action_update', 'action_complete']],
        ['operational', 'Operational', 'Operational channel for recurring work, monitoring, SOP execution and incident escalation.', 'xmpp_channel_operational', 1440, 'Normal', ['handover', 'health_check', 'escalate_if_needed'], ['uptime', 'pending_incidents', 'sla_health'], ['ops_health', 'runbook', 'handover', 'incident_button'], ['operational_to_incident', 'daily_summary']],
        ['project', 'Project', 'Project channel with milestones, decisions, risks, tasks and action creation.', 'xmpp_channel_project', 10080, 'Normal', ['kickoff', 'milestone_review', 'risk_review', 'closure'], ['milestone_health', 'open_actions', 'risk_count'], ['milestones', 'risks', 'linked_actions', 'decisions'], ['project_to_action', 'project_status_report']],
        ['announcement', 'Announcement', 'Broadcast-style channel with controlled posting, acknowledgement tracking and expiry.', 'xmpp_channel_announcement', 0, 'Normal', ['draft', 'approve', 'publish', 'acknowledge'], ['reach', 'acknowledgement_rate'], ['audience', 'publish_window', 'ack_tracker'], ['announcement_publish', 'ack_reminder']],
    ];
    $definitionStmt = $pdo->prepare(
        'INSERT INTO xmpp_channel_definitions
         (type_key, name, description, extension_table, sla_json, permissions_json, ui_schema_json, ai_marshal_json, sop_json, kpi_json, checklist_json, widgets_json, workflows_json)
         VALUES
         (:type_key, :name, :description, :extension_table, :sla_json, :permissions_json, :ui_schema_json, :ai_marshal_json, :sop_json, :kpi_json, :checklist_json, :widgets_json, :workflows_json)
         ON DUPLICATE KEY UPDATE
           name = VALUES(name), description = VALUES(description), extension_table = VALUES(extension_table),
           sla_json = VALUES(sla_json), permissions_json = VALUES(permissions_json), ui_schema_json = VALUES(ui_schema_json),
           ai_marshal_json = VALUES(ai_marshal_json), sop_json = VALUES(sop_json), kpi_json = VALUES(kpi_json),
           checklist_json = VALUES(checklist_json), widgets_json = VALUES(widgets_json), workflows_json = VALUES(workflows_json),
           active = 1, updated_at = NOW()'
    );
    foreach ($definitions as $definition) {
        [$key, $name, $description, $extensionTable, $slaMinutes, $priority, $sop, $kpis, $widgets, $workflows] = $definition;
        $definitionStmt->execute([
            ':type_key' => $key,
            ':name' => $name,
            ':description' => $description,
            ':extension_table' => $extensionTable,
            ':sla_json' => json_encode(['default_minutes' => $slaMinutes, 'priority' => $priority, 'breach_levels' => [50, 80, 100]], JSON_UNESCAPED_SLASHES),
            ':permissions_json' => json_encode(['owner' => ['manage', 'close', 'link'], 'admin' => ['manage_members', 'link', 'update'], 'member' => ['read', 'message', 'update']], JSON_UNESCAPED_SLASHES),
            ':ui_schema_json' => json_encode(['layout' => $key, 'widgets' => $widgets, 'accent' => $key === 'incident' ? 'red' : ($key === 'announcement' ? 'blue' : 'green')], JSON_UNESCAPED_SLASHES),
            ':ai_marshal_json' => json_encode(['enabled' => true, 'mode' => $key, 'suggest_next_actions' => true, 'summarize_timeline' => true], JSON_UNESCAPED_SLASHES),
            ':sop_json' => json_encode(['steps' => $sop], JSON_UNESCAPED_SLASHES),
            ':kpi_json' => json_encode(['metrics' => $kpis], JSON_UNESCAPED_SLASHES),
            ':checklist_json' => json_encode(['required' => $sop], JSON_UNESCAPED_SLASHES),
            ':widgets_json' => json_encode(['widgets' => $widgets], JSON_UNESCAPED_SLASHES),
            ':workflows_json' => json_encode(['allowed_links' => $workflows], JSON_UNESCAPED_SLASHES),
        ]);
    }
    chat_ensure_column($pdo, 'xmpp_messages', 'latitude', 'DECIMAL(10,7) NULL AFTER file_size');
    chat_ensure_column($pdo, 'xmpp_messages', 'longitude', 'DECIMAL(10,7) NULL AFTER latitude');
    chat_ensure_column($pdo, 'xmpp_messages', 'location_address', 'VARCHAR(500) NULL AFTER longitude');
    chat_ensure_column($pdo, 'xmpp_messages', 'read_latitude', 'DECIMAL(10,7) NULL AFTER read_at');
    chat_ensure_column($pdo, 'xmpp_messages', 'read_longitude', 'DECIMAL(10,7) NULL AFTER read_latitude');
    chat_ensure_column($pdo, 'xmpp_messages', 'read_location_address', 'VARCHAR(500) NULL AFTER read_longitude');
    chat_ensure_column($pdo, 'xmpp_messages', 'read_source_device', 'VARCHAR(32) NULL AFTER read_longitude');
    chat_ensure_column($pdo, 'xmpp_messages', 'read_source_name', 'VARCHAR(160) NULL AFTER read_source_device');
    chat_ensure_column($pdo, 'xmpp_messages', 'client_message_id', 'VARCHAR(80) NULL AFTER longitude');
    chat_ensure_column($pdo, 'xmpp_messages', 'forwarded_from_message_id', 'BIGINT NULL AFTER client_message_id');
    chat_ensure_column($pdo, 'xmpp_messages', 'original_sender_jid', 'VARCHAR(255) NULL AFTER forwarded_from_message_id');
    chat_ensure_column($pdo, 'xmpp_messages', 'original_sender_name', 'VARCHAR(255) NULL AFTER original_sender_jid');
    chat_ensure_column($pdo, 'xmpp_messages', 'original_source_name', 'VARCHAR(160) NULL AFTER original_sender_name');
    $pdo->exec(
        'CREATE TABLE IF NOT EXISTS xmpp_push_tokens (
            id BIGINT AUTO_INCREMENT PRIMARY KEY,
            emp_id INT NOT NULL,
            token VARCHAR(512) NOT NULL UNIQUE,
            platform VARCHAR(32) NOT NULL DEFAULT \'android\',
            updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            INDEX idx_xmpp_push_tokens_emp (emp_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci'
    );
    $pdo->exec(
        'CREATE TABLE IF NOT EXISTS xmpp_group_reads (
            group_id INT NOT NULL,
            emp_id INT NOT NULL,
            last_read_message_id BIGINT NOT NULL DEFAULT 0,
            read_at DATETIME NULL,
            PRIMARY KEY (group_id, emp_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci'
    );
    chat_ensure_column($pdo, 'xmpp_group_members', 'history_visible_from', 'DATETIME NULL AFTER joined_at');
    chat_ensure_column($pdo, 'xmpp_group_reads', 'read_latitude', 'DECIMAL(10,7) NULL AFTER read_at');
    chat_ensure_column($pdo, 'xmpp_group_reads', 'read_longitude', 'DECIMAL(10,7) NULL AFTER read_latitude');
    chat_ensure_column($pdo, 'xmpp_group_reads', 'read_location_address', 'VARCHAR(500) NULL AFTER read_longitude');
    chat_ensure_column($pdo, 'xmpp_group_reads', 'read_source_device', 'VARCHAR(32) NULL AFTER read_longitude');
    chat_ensure_column($pdo, 'xmpp_group_reads', 'read_source_name', 'VARCHAR(160) NULL AFTER read_source_device');
    $pdo->exec(
        'CREATE TABLE IF NOT EXISTS xmpp_saved_messages (
            id BIGINT AUTO_INCREMENT PRIMARY KEY,
            emp_id INT NOT NULL,
            body TEXT NOT NULL,
            file_url VARCHAR(500) NULL,
            file_name VARCHAR(255) NULL,
            file_type VARCHAR(100) NULL,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_saved_emp_created (emp_id, created_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci'
    );
    $pdo->exec(
        'CREATE TABLE IF NOT EXISTS xmpp_reminders (
            id BIGINT AUTO_INCREMENT PRIMARY KEY,
            kind VARCHAR(20) NOT NULL DEFAULT \'reminder\',
            title VARCHAR(255) NOT NULL,
            notes TEXT NULL,
            created_by_emp_id INT NOT NULL,
            assignee_ids_json TEXT NOT NULL,
            source_conversation_jid VARCHAR(255) NULL,
            source_conversation_name VARCHAR(160) NULL,
            source_message_id BIGINT NULL,
            source_message_text TEXT NULL,
            starts_at DATETIME NOT NULL,
            recurrence_type VARCHAR(20) NOT NULL DEFAULT \'once\',
            custom_interval INT NOT NULL DEFAULT 1,
            custom_unit VARCHAR(12) NOT NULL DEFAULT \'week\',
            weekdays_json TEXT NULL,
            month_days_json TEXT NULL,
            active TINYINT NOT NULL DEFAULT 1,
            stopped_at DATETIME NULL,
            stopped_by_emp_id INT NULL,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            INDEX idx_reminders_creator_active (created_by_emp_id, active, starts_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci'
    );
    chat_ensure_column($pdo, 'xmpp_reminders', 'next_due_at', 'DATETIME NULL AFTER starts_at');
    $pdo->exec(
        'CREATE TABLE IF NOT EXISTS xmpp_notification_events (
            id BIGINT AUTO_INCREMENT PRIMARY KEY,
            emp_id INT NOT NULL,
            event_key VARCHAR(190) NOT NULL,
            event_type VARCHAR(30) NOT NULL,
            reminder_id BIGINT NULL,
            title VARCHAR(255) NOT NULL,
            body TEXT NOT NULL,
            viewed_at DATETIME NULL,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            UNIQUE KEY uq_notification_event (event_key),
            INDEX idx_notification_emp_viewed (emp_id, viewed_at, id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci'
    );
    $pdo->exec(
        'CREATE TABLE IF NOT EXISTS xmpp_scheduled_messages (
            id BIGINT AUTO_INCREMENT PRIMARY KEY,
            created_by_emp_id INT NOT NULL,
            body TEXT NOT NULL,
            scheduled_at DATETIME NOT NULL,
            silent TINYINT NOT NULL DEFAULT 0,
            status VARCHAR(20) NOT NULL DEFAULT \'scheduled\',
            completed_at DATETIME NULL,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_scheduled_due (status, scheduled_at),
            INDEX idx_scheduled_creator (created_by_emp_id, scheduled_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci'
    );
    $pdo->exec(
        'CREATE TABLE IF NOT EXISTS xmpp_scheduled_message_targets (
            id BIGINT AUTO_INCREMENT PRIMARY KEY,
            schedule_id BIGINT NOT NULL,
            target_jid VARCHAR(255) NOT NULL,
            status VARCHAR(20) NOT NULL DEFAULT \'pending\',
            attempts INT NOT NULL DEFAULT 0,
            message_id BIGINT NULL,
            last_error VARCHAR(500) NULL,
            sent_at DATETIME NULL,
            UNIQUE KEY uq_scheduled_target (schedule_id, target_jid),
            INDEX idx_scheduled_target_status (status, schedule_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci'
    );
    $pdo->exec(
        'CREATE TABLE IF NOT EXISTS xmpp_mutes (
            emp_id INT NOT NULL,
            target_jid VARCHAR(255) NOT NULL,
            muted_until DATETIME NULL,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (emp_id, target_jid)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci'
    );
    $pdo->exec(
        'CREATE TABLE IF NOT EXISTS xmpp_app_sessions (
            session_id VARCHAR(128) PRIMARY KEY,
            emp_id INT NOT NULL,
            device_id VARCHAR(255) NOT NULL,
            device_name VARCHAR(160) NOT NULL,
            platform VARCHAR(32) NOT NULL,
            app_source VARCHAR(32) NOT NULL DEFAULT \'mobile\',
            ip_address VARCHAR(64) NULL,
            last_seen_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            revoked_at DATETIME NULL,
            UNIQUE KEY uq_app_session_device (emp_id, device_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci'
    );
    $pdo->exec(
        'CREATE TABLE IF NOT EXISTS xmpp_user_presence (
            emp_id INT PRIMARY KEY,
            last_seen_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci'
    );
    $pdo->exec(
        'CREATE TABLE IF NOT EXISTS xmpp_message_pins (
            message_id BIGINT NOT NULL,
            conversation_jid VARCHAR(255) NOT NULL,
            pinned_by_emp_id INT NOT NULL,
            pinned_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (message_id, conversation_jid),
            INDEX idx_message_pins_conversation (conversation_jid, pinned_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci'
    );
    $pdo->exec(
        'CREATE TABLE IF NOT EXISTS xmpp_drafts (
            emp_id INT NOT NULL,
            conversation_jid VARCHAR(255) NOT NULL,
            body TEXT NOT NULL,
            reply_to_id BIGINT NULL,
            updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (emp_id, conversation_jid)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci'
    );
    $pdo->exec(
        'CREATE TABLE IF NOT EXISTS xmpp_read_positions (
            emp_id INT NOT NULL,
            conversation_jid VARCHAR(255) NOT NULL,
            message_id BIGINT NOT NULL DEFAULT 0,
            updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (emp_id, conversation_jid)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci'
    );
    try {
        $pdo->exec('CREATE UNIQUE INDEX uq_xmpp_messages_client_id ON xmpp_messages (from_jid, client_message_id)');
    } catch (Throwable $ignored) {
        // The index already exists.
    }
    foreach ([
        'CREATE INDEX idx_xmpp_messages_to_id_deleted ON xmpp_messages (to_jid, id, deleted_at)',
        'CREATE INDEX idx_xmpp_messages_from_to_id ON xmpp_messages (from_jid, to_jid, id)',
        'CREATE INDEX idx_xmpp_messages_created_id ON xmpp_messages (created_at, id)',
        'CREATE INDEX idx_xmpp_group_members_emp_group ON xmpp_group_members (emp_id, group_id)',
        'CREATE INDEX idx_xmpp_groups_archived_type_created ON xmpp_groups (is_archived, group_type, created_at)',
        'CREATE INDEX idx_xmpp_user_presence_seen ON xmpp_user_presence (last_seen_at)',
    ] as $indexSql) {
        try {
            $pdo->exec($indexSql);
        } catch (Throwable $ignored) {
            // Index may already exist or be unsupported on an older live schema.
        }
    }
    $pdo->exec(
        'CREATE TABLE IF NOT EXISTS xmpp_location_tracking (
            emp_id INT NOT NULL PRIMARY KEY,
            token_hash CHAR(64) NOT NULL UNIQUE,
            shift_id INT NULL,
            active TINYINT NOT NULL DEFAULT 1,
            started_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            stopped_at DATETIME NULL,
            last_location_at DATETIME NULL,
            INDEX idx_location_tracking_token (token_hash, active)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci'
    );
    $pdo->exec(
        'CREATE TABLE IF NOT EXISTS xmpp_location_visibility (
            emp_id INT NOT NULL PRIMARY KEY,
            enabled TINYINT NOT NULL DEFAULT 0,
            updated_by_emp_id INT NULL,
            updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_location_visibility_enabled (enabled, emp_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci'
    );
    $pdo->exec(
        'INSERT INTO xmpp_location_visibility (emp_id, enabled, updated_by_emp_id)
         VALUES (116, 1, 302), (302, 1, 302)
         ON DUPLICATE KEY UPDATE enabled = IF(emp_id IN (116, 302), 1, enabled)'
    );
    $pdo->exec(
        'CREATE TABLE IF NOT EXISTS xmpp_offline_alerts (
            id BIGINT AUTO_INCREMENT PRIMARY KEY,
            emp_id INT NOT NULL,
            manager_emp_id INT NULL,
            offline_seconds INT NOT NULL DEFAULT 0,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_offline_alert_emp_created (emp_id, created_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci'
    );
    $pdo->exec(
        'CREATE TABLE IF NOT EXISTS xmpp_message_reactions (
            message_id BIGINT NOT NULL,
            emp_id INT NOT NULL,
            reaction VARCHAR(16) NOT NULL,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (message_id, emp_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci'
    );
    $pdo->exec(
        'CREATE TABLE IF NOT EXISTS xmpp_message_stars (
            message_id BIGINT NOT NULL,
            emp_id INT NOT NULL,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (message_id, emp_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci'
    );
    $pdo->exec(
        'CREATE TABLE IF NOT EXISTS xmpp_conversation_preferences (
            emp_id INT NOT NULL,
            target_jid VARCHAR(255) NOT NULL,
            is_pinned TINYINT NOT NULL DEFAULT 0,
            is_starred TINYINT NOT NULL DEFAULT 0,
            updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (emp_id, target_jid)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci'
    );
    $pdo->exec(
        'CREATE TABLE IF NOT EXISTS xmpp_release_builds (
            id BIGINT AUTO_INCREMENT PRIMARY KEY,
            platform VARCHAR(24) NOT NULL DEFAULT \'android\',
            version VARCHAR(32) NOT NULL,
            build_number INT NOT NULL DEFAULT 0,
            stage VARCHAR(24) NOT NULL DEFAULT \'Development\',
            status VARCHAR(24) NOT NULL DEFAULT \'Draft\',
            apk_url VARCHAR(500) NULL,
            notes TEXT NULL,
            rollout_percent INT NOT NULL DEFAULT 0,
            force_update TINYINT NOT NULL DEFAULT 0,
            uploaded_by_emp_id INT NOT NULL,
            approved_by_emp_id INT NULL,
            approved_at DATETIME NULL,
            deployed_at DATETIME NULL,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            UNIQUE KEY uq_release_platform_version_build (platform, version, build_number),
            INDEX idx_release_lookup (platform, stage, status, created_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci'
    );
    $pdo->exec(
        'CREATE TABLE IF NOT EXISTS xmpp_release_history (
            id BIGINT AUTO_INCREMENT PRIMARY KEY,
            release_id BIGINT NOT NULL,
            actor_emp_id INT NOT NULL,
            action VARCHAR(40) NOT NULL,
            from_status VARCHAR(24) NULL,
            to_status VARCHAR(24) NULL,
            notes TEXT NULL,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_release_history_release (release_id, created_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci'
    );
    $pdo->exec(
        'CREATE TABLE IF NOT EXISTS xmpp_release_notes (
            id BIGINT AUTO_INCREMENT PRIMARY KEY,
            platform VARCHAR(24) NOT NULL DEFAULT \'android\',
            version VARCHAR(32) NOT NULL,
            release_date DATE NOT NULL,
            new_features TEXT NULL,
            improvements TEXT NULL,
            bug_fixes TEXT NULL,
            security_updates TEXT NULL,
            implementation_details TEXT NULL,
            created_by_emp_id INT NULL,
            updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            UNIQUE KEY uq_release_notes_platform_version (platform, version),
            INDEX idx_release_notes_lookup (platform, version, release_date)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci'
    );
    $pdo->exec(
        'CREATE TABLE IF NOT EXISTS xmpp_release_note_views (
            release_note_id BIGINT NOT NULL,
            emp_id INT NOT NULL,
            viewed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (release_note_id, emp_id),
            INDEX idx_release_note_views_emp (emp_id, viewed_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci'
    );
    $pdo->exec(
        'CREATE TABLE IF NOT EXISTS xmpp_channel_timeline (
            id BIGINT AUTO_INCREMENT PRIMARY KEY,
            group_id INT NOT NULL,
            event_type VARCHAR(80) NOT NULL,
            body TEXT NOT NULL,
            actor_emp_id INT NULL,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_channel_timeline_group (group_id, created_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci'
    );
    @touch($schemaMarker);
}

function chat_reverse_geocode_address(?float $latitude, ?float $longitude): string
{
    if ($latitude === null || $longitude === null) {
        return '';
    }
    $latKey = number_format($latitude, 5, '.', '');
    $lngKey = number_format($longitude, 5, '.', '');
    $cacheKey = $latKey . ',' . $lngKey;
    static $memoryCache = [];
    static $cacheReady = false;
    if (array_key_exists($cacheKey, $memoryCache)) {
        return $memoryCache[$cacheKey];
    }

    $pdo = null;
    try {
        $pdo = chat_db();
        if (!$cacheReady) {
            $pdo->exec(
                'CREATE TABLE IF NOT EXISTS xmpp_geocode_cache (
                    lat_key VARCHAR(32) NOT NULL,
                    lng_key VARCHAR(32) NOT NULL,
                    address VARCHAR(500) NOT NULL,
                    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                    PRIMARY KEY (lat_key, lng_key)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci'
            );
            $cacheReady = true;
        }
        $stmt = $pdo->prepare('SELECT address FROM xmpp_geocode_cache WHERE lat_key = :lat_key AND lng_key = :lng_key LIMIT 1');
        $stmt->execute([':lat_key' => $latKey, ':lng_key' => $lngKey]);
        $cached = trim((string)($stmt->fetchColumn() ?: ''));
        if ($cached !== '') {
            $memoryCache[$cacheKey] = $cached;
            return $cached;
        }
    } catch (Throwable $e) {
        error_log('reverse geocode cache unavailable: ' . $e->getMessage());
    }

    $apiKey = getenv('GOOGLE_MAPS_API_KEY') ?: (defined('GOOGLE_MAPS_API_KEY') ? (string)GOOGLE_MAPS_API_KEY : 'AIzaSyDdDoEaS6QDSnA6yB5PUeEf4l5BH7kMEA8');
    if ($apiKey === '') {
        $memoryCache[$cacheKey] = '';
        return '';
    }
    $url = 'https://maps.googleapis.com/maps/api/geocode/json?latlng=' .
        rawurlencode($latitude . ',' . $longitude) . '&key=' . rawurlencode($apiKey);
    $context = stream_context_create(['http' => ['timeout' => 0.8]]);
    $raw = @file_get_contents($url, false, $context);
    if ($raw === false) {
        $memoryCache[$cacheKey] = '';
        return '';
    }
    $json = json_decode($raw, true);
    $address = '';
    if (is_array($json) && (($json['status'] ?? '') === 'OK') && !empty($json['results'][0]['formatted_address'])) {
        $address = mb_substr((string)$json['results'][0]['formatted_address'], 0, 500);
    }
    if ($address !== '' && $pdo instanceof PDO) {
        try {
            $stmt = $pdo->prepare(
                'INSERT INTO xmpp_geocode_cache (lat_key, lng_key, address)
                 VALUES (:lat_key, :lng_key, :address)
                 ON DUPLICATE KEY UPDATE address = VALUES(address), updated_at = NOW()'
            );
            $stmt->execute([':lat_key' => $latKey, ':lng_key' => $lngKey, ':address' => $address]);
        } catch (Throwable $e) {
            error_log('reverse geocode cache write failed: ' . $e->getMessage());
        }
    }
    $memoryCache[$cacheKey] = $address;
    return $address;
}
function chat_ensure_column(PDO $pdo, string $table, string $column, string $definition): void
{
    $stmt = $pdo->prepare(
        'SELECT COUNT(*)
         FROM INFORMATION_SCHEMA.COLUMNS
         WHERE TABLE_SCHEMA = DATABASE()
           AND TABLE_NAME = :table_name
           AND COLUMN_NAME = :column_name'
    );
    $stmt->execute([':table_name' => $table, ':column_name' => $column]);
    if ((int)$stmt->fetchColumn() === 0) {
        $pdo->exec("ALTER TABLE `{$table}` ADD COLUMN `{$column}` {$definition}");
    }
}

function chat_is_muted(PDO $pdo, int $empId, string $targetJid): bool
{
    $stmt = $pdo->prepare(
        'SELECT 1 FROM xmpp_mutes
         WHERE emp_id = :emp_id AND target_jid = :target_jid
           AND (muted_until IS NULL OR muted_until > NOW())
         LIMIT 1'
    );
    $stmt->execute([':emp_id' => $empId, ':target_jid' => strtolower($targetJid)]);
    return (bool)$stmt->fetchColumn();
}

function chat_ensure_xmpp_user(PDO $pdo, int $empId): array
{
    chat_ensure_schema($pdo);
    $stmt = $pdo->prepare('SELECT emp_id, jid, xmpp_password FROM xmpp_users WHERE emp_id = :emp_id AND status = 1 LIMIT 1');
    $stmt->execute([':emp_id' => $empId]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    if ($row) return $row;

    $password = bin2hex(random_bytes(18));
    $jid = chat_jid($empId);
    $insert = $pdo->prepare(
        'INSERT INTO xmpp_users (emp_id, jid, xmpp_password, status)
         VALUES (:emp_id, :jid, :password, 1)'
    );
    $insert->execute([':emp_id' => $empId, ':jid' => $jid, ':password' => $password]);
    return ['emp_id' => $empId, 'jid' => $jid, 'xmpp_password' => $password];
}

function chat_slug(string $name): string
{
    $slug = strtolower(trim($name));
    $slug = preg_replace('/[^a-z0-9]+/', '-', $slug) ?: '';
    $slug = trim($slug, '-');
    return $slug !== '' ? $slug : 'group-' . date('Ymd-His');
}
