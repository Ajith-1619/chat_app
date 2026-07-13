<?php
declare(strict_types=1);
require_once __DIR__ . '/bootstrap.php';

chat_require_user();
$empId = max(0, (int)($_GET['emp_id'] ?? 0));
if ($empId <= 0) chat_json(['status' => false, 'error' => 'Employee is required'], 422);
$employeePdo = getEmployeeDB();
$payload = chat_user_payload($employeePdo, $empId, chat_jid($empId));
$row = chat_employee_row($employeePdo, $empId);
if (!$row) chat_json(['status' => false, 'error' => 'User not found'], 404);
$fullStmt = $employeePdo->prepare('SELECT * FROM employee WHERE emp_id = :emp_id LIMIT 1');
$fullStmt->execute([':emp_id' => $empId]);
$full = $fullStmt->fetch(PDO::FETCH_ASSOC) ?: [];
$sessionStmt = chat_db()->prepare(
    'SELECT device_name, platform, app_source, last_seen_at
     FROM xmpp_app_sessions WHERE emp_id = :emp_id AND revoked_at IS NULL
     ORDER BY last_seen_at DESC LIMIT 1'
);
$sessionStmt->execute([':emp_id' => $empId]);
$device = $sessionStmt->fetch(PDO::FETCH_ASSOC) ?: [];
$presenceStmt = chat_db()->prepare(
    'SELECT last_seen_at FROM xmpp_user_presence WHERE emp_id = :emp_id LIMIT 1'
);
$presenceStmt->execute([':emp_id' => $empId]);
$lastActivity = (string)($presenceStmt->fetchColumn() ?: '');
$payload['employee_id'] = (string)$empId;
$payload['email'] = (string)($full['email'] ?? $full['official_email'] ?? '');
$payload['mobile'] = (string)($full['mobile'] ?? $full['phone'] ?? $full['mobile_no'] ?? '');
$payload['department'] = (string)($full['department'] ?? $full['dept_name'] ?? '');
$payload['reporting_manager'] = (string)($full['reporting_manager'] ?? $full['manager_name'] ?? $full['report_to'] ?? '');
$payload['device_model'] = (string)($device['device_name'] ?? '');
$payload['app_version'] = (string)($device['app_source'] ?? '');
$payload['platform'] = (string)($device['platform'] ?? '');
$payload['last_activity'] = $lastActivity;
$payload['messenger_connected'] = chat_ejabberd_is_online(chat_jid($empId));
$payload['launchpad_active'] = $lastActivity !== '' && strtotime($lastActivity) >= time() - 600;
$messageStmt = chat_db()->prepare(
    'SELECT latitude, longitude, location_address, created_at
     FROM xmpp_messages
     WHERE from_jid = :jid
       AND latitude IS NOT NULL
       AND longitude IS NOT NULL
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
$payload['latest_latitude'] = isset($latestLocation['latitude']) ? (string)$latestLocation['latitude'] : '';
$payload['latest_longitude'] = isset($latestLocation['longitude']) ? (string)$latestLocation['longitude'] : '';
$payload['latest_location_at'] = $taskTs > $messageTs
    ? (string)($taskLocation['date_created'] ?? '')
    : (string)($messageLocation['created_at'] ?? '');
$payload['latest_location_address'] = $taskTs > $messageTs
    ? ''
    : (string)($messageLocation['location_address'] ?? '');
if ($payload['latest_location_address'] === '' && !empty($latestLocation['latitude']) && !empty($latestLocation['longitude'])) {
    $payload['latest_location_address'] = chat_reverse_geocode_address(
        (float)$latestLocation['latitude'],
        (float)$latestLocation['longitude']
    );
}
chat_json(['status' => true, 'user' => $payload]);
