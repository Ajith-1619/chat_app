<?php
declare(strict_types=1);
require_once __DIR__ . '/bootstrap.php';

if (PHP_SAPI !== 'cli') {
    chat_json(['status' => false, 'error' => 'CLI only'], 403);
}

try {
    $pdo = chat_db();
    chat_ensure_schema($pdo);
    $stale = $pdo->query(
        'SELECT emp_id,
                TIMESTAMPDIFF(
                    SECOND,
                    COALESCE(last_location_at, started_at),
                    NOW()
                ) AS offline_seconds
         FROM xmpp_location_tracking
         WHERE active = 1
           AND COALESCE(last_location_at, started_at) < DATE_SUB(NOW(), INTERVAL 5 MINUTE)'
    )->fetchAll(PDO::FETCH_ASSOC) ?: [];
    $employeePdo = getEmployeeDB();
    $columns = $employeePdo->query(
        "SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'employee'
           AND COLUMN_NAME IN ('reporting_manager_id','reporting_manager','manager_id','report_to','reporting_to')"
    )->fetchAll(PDO::FETCH_COLUMN) ?: [];

    foreach ($stale as $row) {
        $empId = (int)$row['emp_id'];
        $punchStmt = $employeePdo->prepare(
            'SELECT punch_in, punch_out, date_created, out_time
             FROM punch
             WHERE emp_id = :emp_id AND DATE(date_created) = CURDATE()
             ORDER BY id DESC LIMIT 1'
        );
        $punchStmt->execute([':emp_id' => $empId]);
        $punch = $punchStmt->fetch(PDO::FETCH_ASSOC) ?: [];
        $hasPunchedIn =
            (int)($punch['punch_in'] ?? 0) > 1 || !empty($punch['date_created']);
        $hasPunchedOut =
            (int)($punch['punch_out'] ?? 0) > 1 || !empty($punch['out_time']);
        if (!$hasPunchedIn || $hasPunchedOut) {
            $stop = $pdo->prepare(
                'UPDATE xmpp_location_tracking
                 SET active = 0, stopped_at = NOW() WHERE emp_id = :emp_id'
            );
            $stop->execute([':emp_id' => $empId]);
            continue;
        }
        $recent = $pdo->prepare(
            'SELECT 1 FROM xmpp_offline_alerts
             WHERE emp_id = :emp_id AND created_at > DATE_SUB(NOW(), INTERVAL 30 MINUTE)
             LIMIT 1'
        );
        $recent->execute([':emp_id' => $empId]);
        if ($recent->fetchColumn()) continue;

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

        $offlineSeconds = max(300, (int)$row['offline_seconds']);
        $insert = $pdo->prepare(
            'INSERT INTO xmpp_offline_alerts (emp_id, manager_emp_id, offline_seconds)
             VALUES (:emp_id, :manager_emp_id, :offline_seconds)'
        );
        $insert->execute([
            ':emp_id' => $empId,
            ':manager_emp_id' => $managerEmpId > 0 ? $managerEmpId : null,
            ':offline_seconds' => $offlineSeconds,
        ]);
        if ($managerEmpId <= 0) continue;

        $employee = chat_user_payload($employeePdo, $empId, chat_jid($empId), false);
        chat_send_push_notifications(
            $pdo,
            $empId,
            (string)$employee['name'],
            chat_jid($managerEmpId),
            (string)$employee['name'] . ' has been offline during an active punch-in for ' .
                max(5, (int)ceil($offlineSeconds / 60)) . ' minutes.'
        );
    }
    fwrite(STDOUT, 'Processed ' . count($stale) . " stale tracking session(s).\n");
} catch (Throwable $e) {
    error_log('chat/offline_monitor failed: ' . $e->getMessage());
    fwrite(STDERR, $e->getMessage() . "\n");
    exit(1);
}
