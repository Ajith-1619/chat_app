<?php
declare(strict_types=1);

const SKYCHAT_LMS_WEBHOOK_URL = 'https://skylinkonline.net/lms/public/api/flow-webhook.php';
const SKYCHAT_LMS_TENANT_SLUG = 'skylink-tech';

function chat_lms_webhook_config(): array
{
    $config = [];
    $configFile = __DIR__ . '/lms_webhook_config.php';
    if (is_file($configFile)) {
        $loaded = require $configFile;
        if (is_array($loaded)) $config = $loaded;
    }
    return [
        'url' => trim((string)($config['url'] ?? getenv('SKYCHAT_LMS_WEBHOOK_URL') ?: SKYCHAT_LMS_WEBHOOK_URL)),
        'token' => trim((string)($config['token'] ?? getenv('SKYCHAT_LMS_WEBHOOK_TOKEN') ?: '')),
        'tenant_slug' => trim((string)($config['tenant_slug'] ?? getenv('SKYCHAT_LMS_TENANT_SLUG') ?: SKYCHAT_LMS_TENANT_SLUG)),
        'max_attempts' => max(1, (int)($config['max_attempts'] ?? 5)),
        'timeout_seconds' => max(3, (int)($config['timeout_seconds'] ?? 10)),
    ];
}

function chat_lms_webhook_ensure_schema(PDO $pdo): void
{
    $pdo->exec(
        'CREATE TABLE IF NOT EXISTS xmpp_lms_webhook_queue (
            id BIGINT AUTO_INCREMENT PRIMARY KEY,
            message_id BIGINT NOT NULL,
            group_id INT NULL,
            tenant_slug VARCHAR(80) NOT NULL DEFAULT "skylink-tech",
            room_jid VARCHAR(255) NOT NULL,
            payload_json TEXT NOT NULL,
            status VARCHAR(24) NOT NULL DEFAULT "queued",
            attempts INT NOT NULL DEFAULT 0,
            next_attempt_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            last_http_status INT NULL,
            last_error VARCHAR(500) NULL,
            delivered_at DATETIME NULL,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            UNIQUE KEY uq_lms_webhook_message (message_id),
            INDEX idx_lms_webhook_due (status, next_attempt_at),
            INDEX idx_lms_webhook_group (group_id, created_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci'
    );
}

function chat_lms_webhook_is_lms_lead_channel(array $group): bool
{
    if (strtolower((string)($group['group_type'] ?? '')) !== 'channel') return false;
    $kind = strtolower(trim((string)($group['channel_kind'] ?? '')));
    $roomJid = strtolower(trim((string)($group['room_jid'] ?? '')));
    if (in_array($kind, ['lead', 'lms-lead', 'lms_lead'], true)) return true;
    if (str_starts_with($roomJid, 'channel-lead-') || str_starts_with($roomJid, 'lead-')) return true;

    $metadata = json_decode((string)($group['metadata_json'] ?? ''), true);
    if (!is_array($metadata)) return false;
    $source = strtolower(trim((string)($metadata['source'] ?? $metadata['created_by'] ?? '')));
    $externalType = strtolower(trim((string)($metadata['type'] ?? $metadata['channel_type'] ?? '')));
    return str_contains($source, 'lms') || str_contains($externalType, 'lead') || !empty($metadata['lms_lead_id']) || !empty($metadata['lms_channel_id']);
}

function chat_lms_webhook_is_participant_message(string $fromJid, string $sourceDevice, string $sourceName): bool
{
    $from = strtolower(trim($fromJid));
    if ($from === '' || str_starts_with($from, 'system@') || str_starts_with($from, 'notification@')) return false;
    $device = strtolower(trim($sourceDevice));
    if (in_array($device, ['api', 'system', 'bot'], true)) return false;
    $source = strtolower(trim($sourceName));
    if ($source !== '' && (str_contains($source, 'lms') || str_contains($source, 'external api') || str_contains($source, 'system'))) return false;
    return true;
}

function chat_lms_webhook_sender_name(int $empId, string $fallbackJid): string
{
    try {
        $employeePdo = getEmployeeDB();
        $stmt = $employeePdo->prepare('SELECT name FROM employee WHERE emp_id = :emp_id LIMIT 1');
        $stmt->execute([':emp_id' => $empId]);
        $name = trim((string)($stmt->fetchColumn() ?: ''));
        if ($name !== '') return $name;
    } catch (Throwable $ignored) {
    }
    return $fallbackJid;
}

function chat_lms_webhook_queue_message(
    PDO $pdo,
    array $group,
    int $messageId,
    int $senderEmpId,
    string $fromJid,
    string $body,
    string $sourceDevice,
    string $sourceName
): void {
    if ($messageId <= 0 || trim($body) === '') return;
    if (!chat_lms_webhook_is_lms_lead_channel($group)) return;
    if (!chat_lms_webhook_is_participant_message($fromJid, $sourceDevice, $sourceName)) return;

    $config = chat_lms_webhook_config();
    if ($config['url'] === '' || $config['token'] === '') {
        error_log('LMS webhook not queued: missing local webhook URL/token configuration.');
        return;
    }

    chat_lms_webhook_ensure_schema($pdo);
    $roomJid = strtolower(trim((string)($group['room_jid'] ?? '')));
    $payload = [
        'tenant_slug' => $config['tenant_slug'],
        'channel_id' => (int)($group['id'] ?? 0),
        'room_jid' => $roomJid,
        'message_id' => 'flow-message-' . $messageId,
        'sender_jid' => strtolower($fromJid),
        'sender_name' => chat_lms_webhook_sender_name($senderEmpId, $fromJid),
        'body' => $body,
    ];
    $stmt = $pdo->prepare(
        'INSERT INTO xmpp_lms_webhook_queue
         (message_id, group_id, tenant_slug, room_jid, payload_json, status, attempts, next_attempt_at)
         VALUES (:message_id, :group_id, :tenant_slug, :room_jid, :payload_json, "queued", 0, NOW())
         ON DUPLICATE KEY UPDATE payload_json = VALUES(payload_json), updated_at = NOW()'
    );
    $stmt->execute([
        ':message_id' => $messageId,
        ':group_id' => (int)($group['id'] ?? 0) ?: null,
        ':tenant_slug' => $config['tenant_slug'],
        ':room_jid' => $roomJid,
        ':payload_json' => json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES),
    ]);
}

function chat_lms_webhook_spawn_worker(int $limit = 20): void
{
    if (PHP_SAPI === 'cli') return;
    $worker = __DIR__ . '/lms_webhook_worker.php';
    if (!is_file($worker)) return;
    $php = PHP_BINARY ?: 'php';
    $limit = max(1, min(100, $limit));
    if (stripos(PHP_OS_FAMILY, 'Windows') !== false) {
        @pclose(@popen('start /B "" ' . escapeshellarg($php) . ' ' . escapeshellarg($worker) . ' ' . escapeshellarg((string)$limit), 'r'));
        return;
    }
    @exec(escapeshellarg($php) . ' ' . escapeshellarg($worker) . ' ' . escapeshellarg((string)$limit) . ' > /dev/null 2>&1 &');
}
