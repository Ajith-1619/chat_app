<?php
declare(strict_types=1);
require_once __DIR__ . '/bootstrap.php';

$input = json_decode(file_get_contents('php://input') ?: '{}', true);
if (!is_array($input)) chat_json(['status' => false, 'error' => 'Invalid request'], 422);
$username = strtolower(trim((string)($input['username'] ?? $input['employee_id'] ?? '')));
$password = (string)($input['password'] ?? '');
$username = preg_replace('/@chat\.skylinkonline\.net$/i', '', $username) ?: '';
$username = preg_replace('/^sky-/i', '', $username) ?: '';
$traceId = trim((string)($_SERVER['HTTP_X_SKYLINK_TRACE_ID'] ?? 'auth-' . bin2hex(random_bytes(8))));
$authStarted = microtime(true);
if ($username === '' || $password === '' || !preg_match('/^[a-z0-9._-]+$/i', $username)) {
    chat_json(['status' => false, 'error' => 'Username and password are required'], 422);
}

$client = chat_ejabberd_client();
if (!$client->authenticate($username, $password)) {
    if (ctype_digit($username)) {
        chat_diagnostic_trace((int)$username, $traceId, 'authentication', 'ejabberd_login', (microtime(true) - $authStarted) * 1000, 'failed');
    }
    chat_json(['status' => false, 'error' => 'Invalid Ejabberd username or password'], 401);
}

$empId = ctype_digit($username) ? (int)$username : 0;
if ($empId <= 0) {
    chat_json(['status' => false, 'error' => 'This Ejabberd account is not mapped to an employee ID'], 403);
}

chat_start();
session_regenerate_id(true);
$_SESSION['username'] = 'sky-' . $empId;
$_SESSION['employee_id'] = $empId;
$_SESSION['auth_source'] = 'ejabberd';

$pdo = chat_db();
chat_ensure_schema($pdo);
$stmt = $pdo->prepare(
    'INSERT INTO xmpp_users (emp_id, jid, xmpp_password, status)
     VALUES (:emp_id, :jid, :password, 1)
     ON DUPLICATE KEY UPDATE jid = VALUES(jid), xmpp_password = VALUES(xmpp_password), status = 1'
);
$stmt->execute([
    ':emp_id' => $empId,
    ':jid' => chat_jid($empId),
    ':password' => $password,
]);

$user = chat_user_payload(getEmployeeDB(), $empId, chat_jid($empId), true);
chat_diagnostic_trace($empId, $traceId, 'authentication', 'ejabberd_login', (microtime(true) - $authStarted) * 1000, 'success');
chat_json([
    'status' => true,
    'auth_source' => 'ejabberd',
    'session_id' => session_id(),
    'user' => $user,
]);
