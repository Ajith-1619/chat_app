<?php
declare(strict_types=1);
require_once __DIR__ . '/bootstrap.php';

$session = chat_require_user();
$profile = chat_user_payload(
    getEmployeeDB(),
    (int)$session['emp_id'],
    chat_jid((int)$session['emp_id']),
    false
);
chat_json([
    'status' => true,
    'emp_id' => (string)$profile['emp_id'],
    'name' => (string)$profile['name'],
    'designation' => (string)$profile['designation'],
    'jid' => (string)$profile['jid'],
    'avatar_url' => (string)($profile['avatar_url'] ?? ''),
]);
