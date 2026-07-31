<?php
declare(strict_types=1);
require_once __DIR__ . '/bootstrap.php';
require_once __DIR__ . '/lms_webhook_helper.php';

function chat_lms_webhook_next_delay_minutes(int $attempts): int
{
    $delays = [1, 5, 15, 60, 180];
    return $delays[min(max(0, $attempts - 1), count($delays) - 1)];
}

function chat_lms_webhook_post(array $config, array $payload): array
{
    if (!function_exists('curl_init')) {
        return ['http_status' => 0, 'body' => '', 'error' => 'PHP cURL extension is unavailable.'];
    }
    $ch = curl_init((string)$config['url']);
    curl_setopt_array($ch, [
        CURLOPT_POST => true,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_CONNECTTIMEOUT => min(5, (int)$config['timeout_seconds']),
        CURLOPT_TIMEOUT => (int)$config['timeout_seconds'],
        CURLOPT_HTTPHEADER => [
            'Authorization: Bearer ' . (string)$config['token'],
            'Content-Type: application/json',
            'Accept: application/json',
        ],
        CURLOPT_POSTFIELDS => json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES),
    ]);
    $body = curl_exec($ch);
    $error = curl_error($ch);
    $status = (int)curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    return ['http_status' => $status, 'body' => is_string($body) ? $body : '', 'error' => $error ?: ''];
}

$limit = max(1, min(100, (int)($argv[1] ?? 20)));
$pdo = chat_db();
chat_ensure_schema($pdo);
chat_lms_webhook_ensure_schema($pdo);
$config = chat_lms_webhook_config();
if ($config['url'] === '' || $config['token'] === '') {
    error_log('LMS webhook worker skipped: missing local webhook URL/token configuration.');
    exit(0);
}

$stmt = $pdo->prepare(
    'SELECT * FROM xmpp_lms_webhook_queue
     WHERE status IN ("queued", "failed")
       AND attempts < :max_attempts
       AND next_attempt_at <= NOW()
     ORDER BY id ASC
     LIMIT :limit'
);
$stmt->bindValue(':max_attempts', (int)$config['max_attempts'], PDO::PARAM_INT);
$stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
$stmt->execute();
$jobs = $stmt->fetchAll(PDO::FETCH_ASSOC) ?: [];

foreach ($jobs as $job) {
    $jobId = (int)$job['id'];
    $payload = json_decode((string)$job['payload_json'], true);
    if (!is_array($payload)) {
        $pdo->prepare('UPDATE xmpp_lms_webhook_queue SET status = "permanent_failed", last_error = "Invalid queued payload JSON", updated_at = NOW() WHERE id = :id')
            ->execute([':id' => $jobId]);
        continue;
    }
    $pdo->prepare('UPDATE xmpp_lms_webhook_queue SET status = "sending", updated_at = NOW() WHERE id = :id')
        ->execute([':id' => $jobId]);

    $attempts = (int)$job['attempts'] + 1;
    $result = chat_lms_webhook_post($config, $payload);
    $httpStatus = (int)$result['http_status'];
    $body = trim((string)$result['body']);
    $decoded = json_decode($body, true);
    $ok = $httpStatus === 200 && is_array($decoded) && ($decoded['ok'] ?? false) === true && in_array((string)($decoded['status'] ?? ''), ['recorded', 'duplicate'], true);

    if ($ok) {
        $pdo->prepare('UPDATE xmpp_lms_webhook_queue SET status = "sent", attempts = :attempts, last_http_status = :http_status, last_error = NULL, delivered_at = NOW(), updated_at = NOW() WHERE id = :id')
            ->execute([':attempts' => $attempts, ':http_status' => $httpStatus, ':id' => $jobId]);
        continue;
    }

    $noRetry = in_array($httpStatus, [400, 401, 422], true) || ($httpStatus >= 400 && $httpStatus < 500);
    $error = $result['error'] !== '' ? $result['error'] : ('HTTP ' . $httpStatus);
    if ($body !== '') $error .= ' ' . mb_substr($body, 0, 220);
    $error = mb_substr($error, 0, 500);

    if ($noRetry || $attempts >= (int)$config['max_attempts']) {
        $pdo->prepare('UPDATE xmpp_lms_webhook_queue SET status = "permanent_failed", attempts = :attempts, last_http_status = :http_status, last_error = :error, updated_at = NOW() WHERE id = :id')
            ->execute([':attempts' => $attempts, ':http_status' => $httpStatus ?: null, ':error' => $error, ':id' => $jobId]);
        continue;
    }

    $delay = chat_lms_webhook_next_delay_minutes($attempts);
    $nextAttemptAt = date('Y-m-d H:i:s', time() + ($delay * 60));
    $pdo->prepare('UPDATE xmpp_lms_webhook_queue SET status = "failed", attempts = :attempts, last_http_status = :http_status, last_error = :error, next_attempt_at = :next_attempt_at, updated_at = NOW() WHERE id = :id')
        ->execute([':attempts' => $attempts, ':http_status' => $httpStatus ?: null, ':error' => $error, ':next_attempt_at' => $nextAttemptAt, ':id' => $jobId]);
}

