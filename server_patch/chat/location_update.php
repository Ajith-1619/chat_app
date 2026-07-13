<?php
declare(strict_types=1);
require_once __DIR__ . '/bootstrap.php';

$input = json_decode(file_get_contents('php://input') ?: '{}', true);
if (!is_array($input)) chat_json(['status' => false, 'error' => 'Invalid JSON'], 422);
$token = trim((string)($input['tracking_token'] ?? ''));
$latitude = trim((string)($input['latitude'] ?? ''));
$longitude = trim((string)($input['longitude'] ?? ''));
if ($token === '' || !is_numeric($latitude) || !is_numeric($longitude)) {
    chat_json(['status' => false, 'error' => 'Tracking token and coordinates are required'], 422);
}
$lat = (float)$latitude;
$lon = (float)$longitude;
if ($lat < -90 || $lat > 90 || $lon < -180 || $lon > 180) {
    chat_json(['status' => false, 'error' => 'Invalid coordinates'], 422);
}

try {
    $chatPdo = chat_db();
    chat_ensure_schema($chatPdo);
    $stmt = $chatPdo->prepare(
        'SELECT emp_id FROM xmpp_location_tracking
         WHERE token_hash = :token_hash AND active = 1 LIMIT 1'
    );
    $stmt->execute([':token_hash' => hash('sha256', $token)]);
    $empId = (int)($stmt->fetchColumn() ?: 0);
    if ($empId <= 0) chat_json(['status' => false, 'error' => 'Tracking session expired'], 401);

    $employee = chat_employee_row(getEmployeeDB(), $empId);
    $taskPdo = getTaskDB();
    $chatStmt = $taskPdo->prepare(
        "SELECT chat_id FROM tbl_location_track_inch
         WHERE emp_id = :emp_id AND COALESCE(TRIM(chat_id), '') <> ''
         ORDER BY id DESC LIMIT 1"
    );
    $chatStmt->execute([':emp_id' => $empId]);
    $chatId = trim((string)($chatStmt->fetchColumn() ?: ''));
    if ($chatId === '') $chatId = (string)$empId;
    $insert = $taskPdo->prepare(
        'INSERT INTO locations_test
         (user_id, latitude, longitude, timestamp, date_created, username, ip_address)
         VALUES (:user_id, :latitude, :longitude, :timestamp, NOW(), :username, :ip_address)'
    );
    $insert->execute([
        ':user_id' => $chatId,
        ':latitude' => (string)$lat,
        ':longitude' => (string)$lon,
        ':timestamp' => (string)time(),
        ':username' => (string)($employee['name'] ?? ('EMP-' . $empId)),
        ':ip_address' => (string)($_SERVER['REMOTE_ADDR'] ?? ''),
    ]);
    $touch = $chatPdo->prepare(
        'UPDATE xmpp_location_tracking SET last_location_at = NOW() WHERE emp_id = :emp_id'
    );
    $touch->execute([':emp_id' => $empId]);
    chat_json(['status' => true, 'saved_at' => date(DATE_ATOM)]);
} catch (Throwable $e) {
    error_log('chat/location_update failed: ' . $e->getMessage());
    chat_json(['status' => false, 'error' => 'Unable to save location'], 500);
}
