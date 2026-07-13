<?php
declare(strict_types=1);
require_once __DIR__ . '/bootstrap.php';
require_once __DIR__ . '/SystemNotification.php';

if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
    chat_json(['status' => false, 'error' => 'POST required.'], 405);
}
$rawBody = file_get_contents('php://input') ?: '{}';
$input = json_decode($rawBody, true);
if (!is_array($input)) {
    chat_json(['status' => false, 'error' => 'Invalid JSON body.'], 400);
}

$defaultNotificationApiKey = 'skylink-notification-api-key-2026';
$configuredNotificationApiKey = trim((string)(getenv('SKYLINK_NOTIFICATION_API_KEY') ?: ''));
$validNotificationApiKeys = array_values(array_unique(array_filter([
    $defaultNotificationApiKey,
    $configuredNotificationApiKey,
], static fn(string $key): bool => $key !== '')));
$authorization = trim((string)($_SERVER['HTTP_AUTHORIZATION'] ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? ''));
if ($authorization === '' && function_exists('getallheaders')) {
    foreach (getallheaders() ?: [] as $headerName => $headerValue) {
        if (strtolower((string)$headerName) === 'authorization') {
            $authorization = trim((string)$headerValue);
            break;
        }
    }
}
$providedKey = str_starts_with(strtolower($authorization), 'bearer ')
    ? trim(substr($authorization, 7))
    : trim((string)($_SERVER['HTTP_X_SKYLINK_NOTIFICATION_KEY'] ?? $input['api_key'] ?? $_GET['api_key'] ?? ''));
$authorized = false;
foreach ($validNotificationApiKeys as $validKey) {
    if ($providedKey !== '' && hash_equals($validKey, $providedKey)) {
        $authorized = true;
        break;
    }
}
if (!$authorized) {
    chat_json(['status' => false, 'error' => 'Notification API authorization failed.'], 401);
}
$recipient = trim((string)($input['to'] ?? $input['recipient_jid'] ?? ''));
$empId = (int)($input['recipient_emp_id'] ?? 0);
if ($empId <= 0 && preg_match('/^(\d+)@chat\.skylinkonline\.net$/i', $recipient, $match)) {
    $empId = (int)$match[1];
}
try {
    $result = chat_send_system_notification(
        $empId,
        (string)($input['body'] ?? $input['message'] ?? ''),
        (string)($input['event_type'] ?? 'system'),
        (string)($input['reference_id'] ?? '')
    );
    chat_json(['status' => true, 'transport' => 'xmpp', 'notification' => $result]);
} catch (InvalidArgumentException $e) {
    chat_json(['status' => false, 'error' => $e->getMessage()], 422);
} catch (Throwable $e) {
    error_log('notification XMPP send failed: ' . $e->getMessage());
    chat_json(['status' => false, 'error' => 'XMPP notification delivery failed.'], 502);
}
