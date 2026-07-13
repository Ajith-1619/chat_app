<?php
declare(strict_types=1);
require_once __DIR__ . '/bootstrap.php';

$session = chat_require_user();
$pdo = chat_db();
chat_ensure_schema($pdo);
$empId = (int)$session['emp_id'];

if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    $stmt = $pdo->prepare(
        'SELECT session_id, device_id, device_name, platform, app_source, ip_address,
                last_seen_at, created_at, revoked_at
         FROM xmpp_app_sessions WHERE emp_id = :emp_id
         ORDER BY last_seen_at DESC'
    );
    $stmt->execute([':emp_id' => $empId]);
    chat_json(['status' => true, 'sessions' => $stmt->fetchAll(PDO::FETCH_ASSOC) ?: []]);
}

$input = json_decode(file_get_contents('php://input') ?: '{}', true);
if (!is_array($input)) chat_json(['status' => false, 'error' => 'Invalid JSON'], 422);
$deviceId = trim((string)($input['device_id'] ?? ''));
$deviceName = trim((string)($input['device_name'] ?? 'Unknown device'));
$platform = strtolower(trim((string)($input['platform'] ?? 'unknown')));
$source = strtolower(trim((string)($input['app_source'] ?? $platform)));
if ($deviceId === '') chat_json(['status' => false, 'error' => 'Device id is required'], 422);
$sessionId = hash('sha256', $empId . '|' . $deviceId);
$stmt = $pdo->prepare(
    'INSERT INTO xmpp_app_sessions
     (session_id, emp_id, device_id, device_name, platform, app_source, ip_address, last_seen_at, revoked_at)
     VALUES (:session_id, :emp_id, :device_id, :device_name, :platform, :source, :ip, NOW(), NULL)
     ON DUPLICATE KEY UPDATE
       session_id = VALUES(session_id), device_name = VALUES(device_name),
       platform = VALUES(platform), app_source = VALUES(app_source),
       ip_address = VALUES(ip_address), last_seen_at = NOW(), revoked_at = NULL'
);
$stmt->execute([
    ':session_id' => $sessionId,
    ':emp_id' => $empId,
    ':device_id' => mb_substr($deviceId, 0, 255),
    ':device_name' => mb_substr($deviceName, 0, 160),
    ':platform' => mb_substr($platform, 0, 32),
    ':source' => mb_substr($source, 0, 32),
    ':ip' => $_SERVER['REMOTE_ADDR'] ?? null,
]);
chat_json(['status' => true, 'session_id' => $sessionId]);
