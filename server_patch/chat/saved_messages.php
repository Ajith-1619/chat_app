<?php
declare(strict_types=1);
require_once __DIR__ . '/bootstrap.php';

$session = chat_require_user();
$pdo = chat_db();
chat_ensure_schema($pdo);
$empId = (int)$session['emp_id'];

if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    $stmt = $pdo->prepare(
        'SELECT id, body, file_url, file_name, file_type, created_at
         FROM xmpp_saved_messages WHERE emp_id = :emp_id
         ORDER BY id DESC LIMIT 200'
    );
    $stmt->execute([':emp_id' => $empId]);
    chat_json(['status' => true, 'messages' => $stmt->fetchAll(PDO::FETCH_ASSOC) ?: []]);
}

$input = json_decode(file_get_contents('php://input') ?: '{}', true);
if (!is_array($input)) chat_json(['status' => false, 'error' => 'Invalid JSON'], 422);
$body = trim((string)($input['message'] ?? ''));
$fileUrl = trim((string)($input['file_url'] ?? ''));
if ($body === '' && $fileUrl === '') {
    chat_json(['status' => false, 'error' => 'Message or file is required'], 422);
}
$stmt = $pdo->prepare(
    'INSERT INTO xmpp_saved_messages (emp_id, body, file_url, file_name, file_type)
     VALUES (:emp_id, :body, :file_url, :file_name, :file_type)'
);
$stmt->execute([
    ':emp_id' => $empId,
    ':body' => $body,
    ':file_url' => $fileUrl ?: null,
    ':file_name' => trim((string)($input['file_name'] ?? '')) ?: null,
    ':file_type' => trim((string)($input['file_type'] ?? '')) ?: null,
]);
chat_json(['status' => true, 'message_id' => (int)$pdo->lastInsertId()]);
