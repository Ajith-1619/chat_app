<?php
declare(strict_types=1);
require_once __DIR__ . '/bootstrap.php';

$session = chat_require_user();
$groupId = (int)($_GET['group_id'] ?? 0);
if ($groupId <= 0) chat_json(['status' => false, 'error' => 'Group id is required'], 422);

$chatPdo = chat_db();
$employeePdo = getEmployeeDB();
chat_ensure_schema($chatPdo);

$memberCheck = $chatPdo->prepare(
    'SELECT role FROM xmpp_group_members WHERE group_id = :group_id AND emp_id = :emp_id LIMIT 1'
);
$memberCheck->execute([':group_id' => $groupId, ':emp_id' => (int)$session['emp_id']]);
$currentRole = (string)($memberCheck->fetchColumn() ?: '');
if ($currentRole === '') {
    chat_json(['status' => false, 'error' => 'You are not a member of this group'], 403);
}

$stmt = $chatPdo->prepare(
    'SELECT emp_id, role
     FROM xmpp_group_members
     WHERE group_id = :group_id
     ORDER BY role = \'owner\' DESC, role = \'admin\' DESC, joined_at ASC'
);
$stmt->execute([':group_id' => $groupId]);
$memberRows = $stmt->fetchAll(PDO::FETCH_ASSOC) ?: [];
$empIds = array_values(array_unique(array_map(static fn(array $row): int => (int)$row['emp_id'], $memberRows)));
if (!$empIds) {
    chat_json(['status' => true, 'current_role' => $currentRole, 'members' => []]);
}

$placeholders = implode(',', array_fill(0, count($empIds), '?'));
$employeeMap = [];
try {
    $employeeStmt = $employeePdo->prepare(
        "SELECT emp_id, name, COALESCE(NULLIF(designation, ''), NULLIF(department, ''), NULLIF(emp_type, ''), '') AS designation
         FROM employee
         WHERE emp_id IN ({$placeholders})"
    );
    $employeeStmt->execute($empIds);
    foreach (($employeeStmt->fetchAll(PDO::FETCH_ASSOC) ?: []) as $employee) {
        $employeeMap[(int)$employee['emp_id']] = $employee;
    }
} catch (Throwable $e) {
    error_log('group_members employee bulk load failed: ' . $e->getMessage());
}

$avatarMap = [];
$presenceMap = [];
try {
    $avatarStmt = $chatPdo->prepare("SELECT emp_id, avatar_url FROM xmpp_users WHERE emp_id IN ({$placeholders})");
    $avatarStmt->execute($empIds);
    foreach (($avatarStmt->fetchAll(PDO::FETCH_ASSOC) ?: []) as $avatar) {
        $avatarMap[(int)$avatar['emp_id']] = chat_public_upload_url((string)($avatar['avatar_url'] ?? ''));
    }
} catch (Throwable $e) {
    error_log('group_members avatar bulk load failed: ' . $e->getMessage());
}
try {
    $presenceStmt = $chatPdo->prepare(
        "SELECT emp_id, last_seen_at,
                last_seen_at >= DATE_SUB(NOW(), INTERVAL 45 SECOND) AS is_online
         FROM xmpp_user_presence
         WHERE emp_id IN ({$placeholders})"
    );
    $presenceStmt->execute($empIds);
    foreach (($presenceStmt->fetchAll(PDO::FETCH_ASSOC) ?: []) as $presence) {
        $presenceMap[(int)$presence['emp_id']] = $presence;
    }
} catch (Throwable $e) {
    error_log('group_members presence bulk load failed: ' . $e->getMessage());
}

$members = [];
foreach ($memberRows as $row) {
    $empId = (int)$row['emp_id'];
    $employee = $employeeMap[$empId] ?? [];
    $presence = $presenceMap[$empId] ?? [];
    $members[] = [
        'emp_id' => $empId,
        'jid' => chat_jid($empId),
        'name' => (string)($employee['name'] ?? ('EMP-' . $empId)),
        'designation' => (string)($employee['designation'] ?? 'Chat user'),
        'online' => (int)($presence['is_online'] ?? 0) === 1,
        'last_seen' => (string)($presence['last_seen_at'] ?? ''),
        'role' => (string)($row['role'] ?? 'member'),
        'avatar_url' => (string)($avatarMap[$empId] ?? ''),
    ];
}

chat_json(['status' => true, 'current_role' => $currentRole, 'members' => $members]);
