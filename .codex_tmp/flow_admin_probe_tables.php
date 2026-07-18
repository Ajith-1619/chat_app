<?php
require '/var/www/html/admin/_bootstrap.php';
$pdo = flow_admin_employee_db();
foreach (['punch','punch_log','login_tracking','logout_tracking'] as $t) {
    echo "TABLE {$t}\n";
    try {
        $cols = $pdo->query("SHOW COLUMNS FROM `{$t}`")->fetchAll(PDO::FETCH_COLUMN);
        echo implode(',', $cols) . "\n";
        $s = $pdo->prepare("SELECT * FROM `{$t}` WHERE emp_id=24 ORDER BY id DESC LIMIT 2");
        $s->execute();
        foreach ($s->fetchAll(PDO::FETCH_ASSOC) as $r) {
            foreach ($r as $k => $v) {
                if (in_array($k, ['id','emp_id','lat','lon','punch_in','punch_out','date_created','out_time','status','shift_id'], true)) {
                    echo $k . '=' . $v . ';';
                }
            }
            echo "\n";
        }
    } catch (Throwable $e) {
        echo 'ERR=' . $e->getMessage() . "\n";
    }
}
