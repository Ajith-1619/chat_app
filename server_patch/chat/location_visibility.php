<?php
declare(strict_types=1);
require_once __DIR__ . '/bootstrap.php';

$session = chat_require_user();
$empId = (int)$session['emp_id'];
$pdo = chat_db();
chat_ensure_schema($pdo);

function location_visibility_can_manage(int $empId): bool
{
    $configured = trim((string)(getenv('SKYCHAT_LOCATION_MANAGERS') ?: ''));
    $allowed = [116, 302];
    if ($configured !== '') {
        $allowed = array_values(array_filter(array_map(
            static fn(string $value): int => (int)trim($value),
            explode(',', $configured)
        )));
    }
    return in_array($empId, $allowed, true);
}

if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    $mine = (string)($_GET['mine'] ?? '') === '1';
    if ($mine) {
        $stmt = $pdo->prepare('SELECT enabled FROM xmpp_location_visibility WHERE emp_id = :emp_id LIMIT 1');
        $stmt->execute([':emp_id' => $empId]);
        chat_json([
            'status' => true,
            'can_manage' => location_visibility_can_manage($empId),
            'enabled' => (bool)$stmt->fetchColumn(),
        ]);
    }

    if (!location_visibility_can_manage($empId)) {
        chat_json(['status' => false, 'error' => 'Location visibility settings are restricted'], 403);
    }

    $employeePdo = getEmployeeDB();
    $rows = [];
    $stmt = $employeePdo->query(
        'SELECT emp_id, name, designation
         FROM employee
         WHERE status = 1
         ORDER BY name ASC'
    );
    $ids = [];
    foreach (($stmt ? $stmt->fetchAll(PDO::FETCH_ASSOC) : []) as $row) {
        $id = (int)($row['emp_id'] ?? 0);
        if ($id <= 0) continue;
        $ids[] = $id;
        $rows[$id] = [
            'emp_id' => (string)$id,
            'name' => (string)($row['name'] ?? ('EMP-' . $id)),
            'designation' => (string)($row['designation'] ?? ''),
            'enabled' => in_array($id, [116, 302], true),
        ];
    }
    if ($ids) {
        $placeholders = implode(',', array_fill(0, count($ids), '?'));
        $visibility = $pdo->prepare(
            "SELECT emp_id, enabled FROM xmpp_location_visibility WHERE emp_id IN ($placeholders)"
        );
        $visibility->execute($ids);
        foreach (($visibility->fetchAll(PDO::FETCH_ASSOC) ?: []) as $item) {
            $id = (int)$item['emp_id'];
            if (isset($rows[$id])) $rows[$id]['enabled'] = (bool)$item['enabled'];
        }
    }
    chat_json(['status' => true, 'can_manage' => true, 'users' => array_values($rows)]);
}

$input = json_decode(file_get_contents('php://input') ?: '{}', true);
if (!is_array($input)) chat_json(['status' => false, 'error' => 'Invalid JSON'], 422);
if (!location_visibility_can_manage($empId)) {
    chat_json(['status' => false, 'error' => 'Location visibility settings are restricted'], 403);
}
$target = max(0, (int)($input['emp_id'] ?? 0));
if ($target <= 0) chat_json(['status' => false, 'error' => 'Employee is required'], 422);
$enabled = !empty($input['enabled']) ? 1 : 0;
$stmt = $pdo->prepare(
    'INSERT INTO xmpp_location_visibility (emp_id, enabled, updated_by_emp_id)
     VALUES (:emp_id, :enabled, :actor)
     ON DUPLICATE KEY UPDATE enabled = VALUES(enabled), updated_by_emp_id = VALUES(updated_by_emp_id)'
);
$stmt->execute([':emp_id' => $target, ':enabled' => $enabled, ':actor' => $empId]);
chat_json(['status' => true, 'emp_id' => (string)$target, 'enabled' => (bool)$enabled]);
