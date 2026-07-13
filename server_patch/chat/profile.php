<?php
declare(strict_types=1);
require_once __DIR__ . '/bootstrap.php';

$session = chat_require_user();
$pdo = chat_db();
chat_ensure_schema($pdo);
$empId = (int)($_GET['emp_id'] ?? $session['emp_id']);
if ($empId <= 0) chat_json(['status' => false, 'error' => 'Employee id is required'], 422);

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if ($empId !== (int)$session['emp_id']) chat_json(['status' => false, 'error' => 'Forbidden'], 403);
    $input = json_decode(file_get_contents('php://input') ?: '{}', true);
    $avatar = trim((string)($input['avatar_url'] ?? ''));
    $stmt = $pdo->prepare(
        'INSERT INTO xmpp_users (emp_id, jid, xmpp_password, avatar_url, status)
         VALUES (:emp_id, :jid, \'\', :avatar, 1)
         ON DUPLICATE KEY UPDATE avatar_url = VALUES(avatar_url)'
    );
    $stmt->execute([':emp_id' => $empId, ':jid' => chat_jid($empId), ':avatar' => $avatar ?: null]);
}

$employee = chat_user_payload(getEmployeeDB(), $empId, chat_jid($empId));
$detailsStmt = getEmployeeDB()->prepare(
    'SELECT email, mobile_no, emp_type, work_location, emp_shift, profile_photo
     FROM employee WHERE emp_id = :emp_id LIMIT 1'
);
$detailsStmt->execute([':emp_id' => $empId]);
$details = $detailsStmt->fetch(PDO::FETCH_ASSOC) ?: [];
$employee['email'] = (string)($details['email'] ?? '');
$employee['mobile'] = (string)($details['mobile_no'] ?? '');
$employee['employee_type'] = (string)($details['emp_type'] ?? '');
$employee['work_location'] = (string)($details['work_location'] ?? '');
$employee['shift_id'] = (string)($details['emp_shift'] ?? '');
$stmt = $pdo->prepare('SELECT avatar_url FROM xmpp_users WHERE emp_id = :emp_id LIMIT 1');
$stmt->execute([':emp_id' => $empId]);
$chatAvatar = (string)($stmt->fetchColumn() ?: '');
$employee['avatar_url'] = chat_public_upload_url($chatAvatar !== ''
    ? $chatAvatar
    : (string)($details['profile_photo'] ?? ''));
$sessionStmt = $pdo->prepare(
    'SELECT device_name, platform, app_source, last_seen_at
     FROM xmpp_app_sessions
     WHERE emp_id = :emp_id AND revoked_at IS NULL
     ORDER BY last_seen_at DESC LIMIT 1'
);
$sessionStmt->execute([':emp_id' => $empId]);
$latestSession = $sessionStmt->fetch(PDO::FETCH_ASSOC) ?: [];
$employee['device_model'] = (string)($latestSession['device_name'] ?? '');
$employee['device_platform'] = (string)($latestSession['platform'] ?? '');
$employee['messenger_source'] = (string)($latestSession['app_source'] ?? '');
$employee['last_activity_at'] = (string)($latestSession['last_seen_at'] ?? '');
$messageStmt = $pdo->prepare(
    'SELECT latitude, longitude, location_address, source_name, created_at
     FROM xmpp_messages
     WHERE from_jid = :jid AND latitude IS NOT NULL AND longitude IS NOT NULL
     ORDER BY created_at DESC, id DESC LIMIT 1'
);
$messageStmt->execute([':jid' => chat_jid($empId)]);
$messageLocation = $messageStmt->fetch(PDO::FETCH_ASSOC) ?: [];
$taskLocation = [];
try {
    $taskPdo = getTaskDB();
    $locStmt = $taskPdo->prepare(
        'SELECT latitude, longitude, date_created
         FROM locations_test
         WHERE user_id = :emp_id
         ORDER BY date_created DESC, id DESC LIMIT 1'
    );
    $locStmt->execute([':emp_id' => $empId]);
    $taskLocation = $locStmt->fetch(PDO::FETCH_ASSOC) ?: [];
} catch (Throwable $ignored) {
    $taskLocation = [];
}
$messageTs = strtotime((string)($messageLocation['created_at'] ?? '')) ?: 0;
$taskTs = strtotime((string)($taskLocation['date_created'] ?? '')) ?: 0;
$latestLocation = $taskTs > $messageTs ? $taskLocation : $messageLocation;
$employee['latest_latitude'] = isset($latestLocation['latitude']) ? (string)$latestLocation['latitude'] : '';
$employee['latest_longitude'] = isset($latestLocation['longitude']) ? (string)$latestLocation['longitude'] : '';
$employee['latest_location_at'] = $taskTs > $messageTs
    ? (string)($taskLocation['date_created'] ?? '')
    : (string)($messageLocation['created_at'] ?? '');
$employee['latest_location_address'] = $taskTs > $messageTs
    ? ''
    : (string)($messageLocation['location_address'] ?? '');
if ($employee['latest_location_address'] === '' && !empty($latestLocation['latitude']) && !empty($latestLocation['longitude'])) {
    $employee['latest_location_address'] = chat_reverse_geocode_address(
        (float)$latestLocation['latitude'],
        (float)$latestLocation['longitude']
    );
}
$employee['app_version'] = '';
if (!empty($messageLocation['source_name']) && preg_match('/v([0-9][0-9A-Za-z.+-]*)/', (string)$messageLocation['source_name'], $match)) {
    $employee['app_version'] = 'v' . $match[1];
}
chat_json(['status' => true, 'profile' => $employee]);
