<?php
declare(strict_types=1);
require_once __DIR__ . '/bootstrap.php';

$session = chat_require_user();
$search = trim((string)($_GET['search'] ?? ''));
$employeePdo = getEmployeeDB();

try {
    $colStmt = $employeePdo->prepare(
        "SELECT COLUMN_NAME
         FROM INFORMATION_SCHEMA.COLUMNS
         WHERE TABLE_SCHEMA = DATABASE()
           AND TABLE_NAME = 'employee'
           AND COLUMN_NAME IN ('mobile', 'phone', 'contact_no', 'contact_number', 'phone_number', 'mobile_no', 'personal_mobile', 'official_mobile')
         ORDER BY FIELD(COLUMN_NAME, 'mobile', 'mobile_no', 'contact_no', 'contact_number', 'phone', 'phone_number', 'official_mobile', 'personal_mobile')
         LIMIT 1"
    );
    $colStmt->execute();
    $phoneCol = (string)($colStmt->fetchColumn() ?: '');
} catch (Throwable $e) {
    $phoneCol = '';
}

$phoneSql = $phoneCol !== '' ? "`{$phoneCol}` AS xmpp_password_source" : "'' AS xmpp_password_source";
$available = [];
try {
    $meta = $employeePdo->prepare(
        "SELECT COLUMN_NAME
         FROM INFORMATION_SCHEMA.COLUMNS
         WHERE TABLE_SCHEMA = DATABASE()
           AND TABLE_NAME = 'employee'
           AND COLUMN_NAME IN ('name', 'designation', 'department', 'emp_type')"
    );
    $meta->execute();
    foreach (($meta->fetchAll(PDO::FETCH_COLUMN) ?: []) as $column) {
        $available[(string)$column] = true;
    }
} catch (Throwable $e) {
    $available = ['name' => true, 'designation' => true];
}
$designationSql = "'' AS designation";
if (isset($available['designation']) || isset($available['department']) || isset($available['emp_type'])) {
    $parts = [];
    foreach (['designation', 'department', 'emp_type'] as $column) {
        if (isset($available[$column])) {
            $parts[] = "NULLIF(`{$column}`, '')";
        }
    }
    $designationSql = 'COALESCE(' . implode(', ', $parts) . ", '') AS designation";
}
$params = [':current_emp_id' => (int)$session['emp_id']];
$searchParts = [];
if ($search !== '') {
    $needle = '%' . $search . '%';
    $searchParts[] = 'CAST(emp_id AS CHAR) LIKE :q_emp';
    $params[':q_emp'] = $needle;
}
foreach (['name', 'designation', 'department', 'emp_type'] as $column) {
    if ($search !== '' && isset($available[$column])) {
        $key = ':q_' . $column;
        $searchParts[] = "`{$column}` LIKE {$key}";
        $params[$key] = '%' . $search . '%';
    }
}
$where = $search !== ''
    ? ' AND (' . implode(' OR ', $searchParts) . ')'
    : '';
$stmt = $employeePdo->prepare(
    "SELECT emp_id, name,
            {$designationSql},
            {$phoneSql}
     FROM employee
     WHERE status = 1 {$where}
       AND emp_id <> :current_emp_id
     ORDER BY name ASC
     LIMIT 500"
);
$stmt->execute($params);
$rows = $stmt->fetchAll(PDO::FETCH_ASSOC) ?: [];

$avatars = [];
$empIds = array_values(array_filter(array_map(static fn($row): int => (int)($row['emp_id'] ?? 0), $rows)));
if ($empIds) {
    try {
        $chatPdo = chat_db();
        chat_ensure_schema($chatPdo);
        $placeholders = implode(',', array_fill(0, count($empIds), '?'));
        $avatarStmt = $chatPdo->prepare("SELECT emp_id, avatar_url FROM xmpp_users WHERE emp_id IN ({$placeholders})");
        $avatarStmt->execute($empIds);
        foreach (($avatarStmt->fetchAll(PDO::FETCH_ASSOC) ?: []) as $avatarRow) {
            $avatars[(int)$avatarRow['emp_id']] = (string)($avatarRow['avatar_url'] ?? '');
        }
    } catch (Throwable $e) {
        error_log('search_users avatar batch failed: ' . $e->getMessage());
    }
}

$users = [];
foreach ($rows as $row) {
    $empId = (int)($row['emp_id'] ?? 0);
    if ($empId <= 0) continue;
    $users[] = [
        'type' => 'chat',
        'emp_id' => (string)$empId,
        'name' => (string)($row['name'] ?? ('EMP-' . $empId)),
        'designation' => (string)($row['designation'] ?? 'Chat user'),
        'jid' => chat_jid($empId),
        'online' => false,
        'avatar_url' => $avatars[$empId] ?? '',
    ];
}

chat_json(['status' => true, 'users' => $users]);
