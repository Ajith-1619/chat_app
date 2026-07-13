<?php
declare(strict_types=1);
require_once __DIR__ . '/bootstrap.php';

$session = chat_require_user();
$traceId = trim((string)($_SERVER['HTTP_X_SKYLINK_TRACE_ID'] ?? 'push-' . bin2hex(random_bytes(8))));
$traceStarted = microtime(true);
$raw = file_get_contents('php://input') ?: '{}';
$input = json_decode($raw, true);
if (!is_array($input)) {
    chat_json(['status' => false, 'error' => 'Invalid JSON'], 422);
}

$token = trim((string)($input['token'] ?? ''));
$platform = strtolower(trim((string)($input['platform'] ?? 'android')));
if ($token === '' || strlen($token) > 512) {
    chat_json(['status' => false, 'error' => 'Valid push token is required'], 422);
}
if (!in_array($platform, ['android', 'ios'], true)) {
    $platform = 'android';
}

try {
    $pdo = chat_db();
    chat_ensure_schema($pdo);
    $stmt = $pdo->prepare(
        'INSERT INTO xmpp_push_tokens (emp_id, token, platform)
         VALUES (:emp_id, :token, :platform)
         ON DUPLICATE KEY UPDATE
           emp_id = VALUES(emp_id),
           platform = VALUES(platform),
           updated_at = CURRENT_TIMESTAMP'
    );
$stmt->execute([
        ':emp_id' => (int)$session['emp_id'],
        ':token' => $token,
        ':platform' => $platform,
]);
chat_diagnostic_trace((int)$session['emp_id'], $traceId, 'notification', 'register_push_token', (microtime(true) - $traceStarted) * 1000, 'success', ['platform' => $platform]);
chat_json(['status' => true]);
} catch (Throwable $e) {
    error_log('chat/register_push_token failed: ' . $e->getMessage());
    chat_json(['status' => false, 'error' => 'Unable to register push notifications'], 500);
}
