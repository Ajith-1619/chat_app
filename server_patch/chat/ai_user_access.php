<?php
declare(strict_types=1);

require_once __DIR__ . '/bootstrap.php';
require_once __DIR__ . '/ai_room_helper.php';

$session = chat_require_user();
$adminEmpId = (int)$session['emp_id'];
if ($adminEmpId !== 302) {
    chat_json(['status' => false, 'error' => 'AI access management is restricted to employee 302.'], 403);
}

$chatPdo = chat_db();
$employeePdo = getEmployeeDB();
chat_ensure_schema($chatPdo);
chat_ai_ensure_room_table($chatPdo);

function flow_ai_manage_ensure_schema(PDO $pdo): void
{
    $pdo->exec("CREATE TABLE IF NOT EXISTS flow_admin_ai_user_access (
        emp_id INT NOT NULL PRIMARY KEY,
        employee_type_override VARCHAR(8) NULL,
        provider_ids TEXT NULL,
        daily_token_limit INT NULL,
        daily_search_limit INT NULL,
        enabled TINYINT NOT NULL DEFAULT 1,
        updated_by_emp_id INT NULL,
        updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX idx_flow_ai_user_enabled (enabled, emp_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
}

function flow_ai_manage_default_provider_id(PDO $pdo): int
{
    $stmt = $pdo->query("SELECT id FROM flow_admin_ai_providers WHERE id = 2 AND status = 1 LIMIT 1");
    $id = (int)($stmt->fetchColumn() ?: 0);
    if ($id > 0) return $id;
    $stmt = $pdo->query("SELECT id FROM flow_admin_ai_providers WHERE status = 1 ORDER BY id ASC LIMIT 1");
    return (int)($stmt->fetchColumn() ?: 0);
}

function flow_ai_manage_providers(PDO $pdo): array
{
    $rows = $pdo->query("SELECT id, provider_name, api_type, model_name, status FROM flow_admin_ai_providers ORDER BY status DESC, id ASC")->fetchAll(PDO::FETCH_ASSOC) ?: [];
    return array_map(static fn(array $row): array => [
        'id' => (int)$row['id'],
        'title' => (string)($row['provider_name'] ?? ''),
        'api_type' => (string)($row['api_type'] ?? ''),
        'model' => (string)($row['model_name'] ?? ''),
        'active' => (int)($row['status'] ?? 0) === 1,
    ], $rows);
}

function flow_ai_manage_users(PDO $employeePdo, PDO $chatPdo, string $query): array
{
    $where = '';
    $params = [];
    if ($query !== '') {
        $where = " AND (CAST(emp_id AS CHAR) LIKE :q OR name LIKE :q OR designation LIKE :q)";
        $params[':q'] = '%' . $query . '%';
    }
    $stmt = $employeePdo->prepare("SELECT emp_id, name, designation, emp_type FROM employee WHERE status = 1 {$where} ORDER BY name ASC LIMIT 100");
    $stmt->execute($params);
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC) ?: [];
    $ids = array_values(array_unique(array_map(static fn(array $row): int => (int)$row['emp_id'], $rows)));
    $accessByEmp = [];
    if ($ids) {
        $ph = implode(',', array_fill(0, count($ids), '?'));
        $accessStmt = $chatPdo->prepare("SELECT emp_id, provider_ids, daily_token_limit, daily_search_limit, enabled, updated_at FROM flow_admin_ai_user_access WHERE emp_id IN ({$ph})");
        $accessStmt->execute($ids);
        foreach (($accessStmt->fetchAll(PDO::FETCH_ASSOC) ?: []) as $row) {
            $accessByEmp[(int)$row['emp_id']] = $row;
        }
    }
    return array_map(static function(array $row) use ($accessByEmp): array {
        $empId = (int)$row['emp_id'];
        $access = $accessByEmp[$empId] ?? [];
        $providerIds = trim((string)($access['provider_ids'] ?? ''));
        return [
            'emp_id' => $empId,
            'name' => (string)($row['name'] ?? ('Employee ' . $empId)),
            'designation' => (string)($row['designation'] ?? ''),
            'employee_type' => chat_employee_type_label($row['emp_type'] ?? ''),
            'jid' => chat_jid($empId),
            'has_ai_access' => (int)($access['enabled'] ?? 0) === 1 && $providerIds !== '',
            'provider_ids' => $providerIds,
            'daily_token_limit' => (int)($access['daily_token_limit'] ?? 0),
            'daily_search_limit' => (int)($access['daily_search_limit'] ?? 0),
            'updated_at' => (string)($access['updated_at'] ?? ''),
        ];
    }, $rows);
}

flow_ai_manage_ensure_schema($chatPdo);
$defaultProviderId = flow_ai_manage_default_provider_id($chatPdo);

if (($_SERVER['REQUEST_METHOD'] ?? 'GET') === 'POST') {
    $input = json_decode(file_get_contents('php://input') ?: '{}', true);
    if (!is_array($input)) $input = [];
    $targetEmpId = (int)($input['emp_id'] ?? 0);
    $enabled = filter_var($input['enabled'] ?? false, FILTER_VALIDATE_BOOL);
    $dailyTokens = max(0, (int)($input['daily_token_limit'] ?? 0));
    $dailySearches = max(0, (int)($input['daily_search_limit'] ?? 0));
    $providerIds = $enabled ? trim((string)($input['provider_ids'] ?? '')) : '';
    if ($providerIds === '' && $enabled && $defaultProviderId > 0) {
        $providerIds = (string)$defaultProviderId;
    }
    if ($targetEmpId <= 0) chat_json(['status' => false, 'error' => 'Select a user.'], 422);
    if ($enabled && $providerIds === '') chat_json(['status' => false, 'error' => 'No active AI provider is configured.'], 422);
    $check = $employeePdo->prepare('SELECT emp_id FROM employee WHERE status = 1 AND emp_id = :emp_id LIMIT 1');
    $check->execute([':emp_id' => $targetEmpId]);
    if (!$check->fetchColumn()) chat_json(['status' => false, 'error' => 'User not found.'], 404);

    $stmt = $chatPdo->prepare("INSERT INTO flow_admin_ai_user_access
        (emp_id, provider_ids, daily_token_limit, daily_search_limit, enabled, updated_by_emp_id, updated_at)
        VALUES (:emp_id, :provider_ids, :token_limit, :search_limit, :enabled, :admin_emp_id, NOW())
        ON DUPLICATE KEY UPDATE provider_ids = VALUES(provider_ids), daily_token_limit = VALUES(daily_token_limit), daily_search_limit = VALUES(daily_search_limit), enabled = VALUES(enabled), updated_by_emp_id = VALUES(updated_by_emp_id), updated_at = NOW()");
    $stmt->execute([
        ':emp_id' => $targetEmpId,
        ':provider_ids' => $providerIds,
        ':token_limit' => $dailyTokens,
        ':search_limit' => $dailySearches,
        ':enabled' => $enabled ? 1 : 0,
        ':admin_emp_id' => $adminEmpId,
    ]);
    chat_json(['status' => true, 'emp_id' => $targetEmpId, 'enabled' => $enabled, 'provider_ids' => $providerIds]);
}

$query = trim((string)($_GET['q'] ?? ''));
chat_json([
    'status' => true,
    'default_provider_id' => $defaultProviderId,
    'providers' => flow_ai_manage_providers($chatPdo),
    'users' => flow_ai_manage_users($employeePdo, $chatPdo, $query),
]);
