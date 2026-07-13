<?php
declare(strict_types=1);
require_once __DIR__ . '/bootstrap.php';

$input = json_decode(file_get_contents('php://input') ?: '{}', true);
if (!is_array($input)) chat_json(['status' => false, 'error' => 'Invalid JSON'], 422);
$token = trim((string)($input['tracking_token'] ?? ''));
$offlineSeconds = max(0, (int)($input['offline_seconds'] ?? 0));
if ($token === '' || $offlineSeconds < 300) {
    chat_json(['status' => false, 'error' => 'Tracking token and offline duration are required'], 422);
}

try {
    $pdo = chat_db();
    chat_ensure_schema($pdo);
    $tracking = $pdo->prepare(
        'SELECT emp_id FROM xmpp_location_tracking
         WHERE token_hash = :token_hash AND active = 1 LIMIT 1'
    );
    $tracking->execute([':token_hash' => hash('sha256', $token)]);
    $empId = (int)($tracking->fetchColumn() ?: 0);
    if ($empId <= 0) chat_json(['status' => false, 'error' => 'Tracking session is unavailable'], 403);

    $recent = $pdo->prepare(
        'SELECT 1 FROM xmpp_offline_alerts
         WHERE emp_id = :emp_id AND created_at > DATE_SUB(NOW(), INTERVAL 30 MINUTE)
         LIMIT 1'
    );
    $recent->execute([':emp_id' => $empId]);
    if ($recent->fetchColumn()) chat_json(['status' => true, 'duplicate' => true]);

    $employeePdo = getEmployeeDB();
    $columns = $employeePdo->query(
        "SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'employee'
           AND COLUMN_NAME IN ('reporting_manager_id','reporting_manager','manager_id','report_to','reporting_to')"
    )->fetchAll(PDO::FETCH_COLUMN) ?: [];
    $managerEmpId = 0;
    foreach (['reporting_manager_id', 'manager_id', 'report_to', 'reporting_to', 'reporting_manager'] as $column) {
        if (!in_array($column, $columns, true)) continue;
        $managerStmt = $employeePdo->prepare(
            "SELECT `{$column}` FROM employee WHERE emp_id = :emp_id LIMIT 1"
        );
        $managerStmt->execute([':emp_id' => $empId]);
        $managerEmpId = (int)($managerStmt->fetchColumn() ?: 0);
        if ($managerEmpId > 0) break;
    }

    $insert = $pdo->prepare(
        'INSERT INTO xmpp_offline_alerts (emp_id, manager_emp_id, offline_seconds)
         VALUES (:emp_id, :manager_emp_id, :offline_seconds)'
    );
    $insert->execute([
        ':emp_id' => $empId,
        ':manager_emp_id' => $managerEmpId > 0 ? $managerEmpId : null,
        ':offline_seconds' => $offlineSeconds,
    ]);

    if ($managerEmpId > 0) {
        $employee = chat_user_payload($employeePdo, $empId, chat_jid($empId), false);
        chat_send_push_notifications(
            $pdo,
            $empId,
            (string)$employee['name'],
            chat_jid($managerEmpId),
            (string)$employee['name'] . ' was offline during an active punch-in for ' .
                max(5, (int)ceil($offlineSeconds / 60)) . ' minutes.'
        );
    }
    chat_json(['status' => true, 'manager_emp_id' => $managerEmpId]);
} catch (Throwable $e) {
    error_log('chat/offline_alert failed: ' . $e->getMessage());
    chat_json(['status' => false, 'error' => 'Unable to record offline alert'], 500);
}
