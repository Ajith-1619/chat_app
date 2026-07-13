<?php
declare(strict_types=1);
require_once __DIR__ . '/bootstrap.php';

$session = chat_require_user();
$input = json_decode(file_get_contents('php://input') ?: '{}', true);
if (!is_array($input)) chat_json(['status' => false, 'error' => 'Invalid JSON'], 422);
$groupId = max(0, (int)($input['group_id'] ?? 0));
$avatarUrl = trim((string)($input['avatar_url'] ?? ''));
if ($groupId <= 0 || ($avatarUrl !== '' && filter_var($avatarUrl, FILTER_VALIDATE_URL) === false)) {
    chat_json(['status' => false, 'error' => 'Valid group and photo URL are required'], 422);
}
$pdo = chat_db();
chat_ensure_schema($pdo);
$check = $pdo->prepare(
    'SELECT gm.role FROM xmpp_group_members gm
     WHERE gm.group_id = :group_id AND gm.emp_id = :emp_id LIMIT 1'
);
$check->execute([':group_id' => $groupId, ':emp_id' => (int)$session['emp_id']]);
$role = (string)($check->fetchColumn() ?: '');
if (!in_array($role, ['owner', 'admin'], true)) {
    chat_json(['status' => false, 'error' => 'Only a group owner or admin can change the photo'], 403);
}
$stmt = $pdo->prepare('UPDATE xmpp_groups SET avatar_url = :avatar_url WHERE id = :group_id');
$stmt->execute([':avatar_url' => $avatarUrl ?: null, ':group_id' => $groupId]);
chat_json(['status' => true, 'avatar_url' => $avatarUrl]);
