<?php
require '/var/www/html/admin/_bootstrap.php';
$pdo = flow_admin_employee_db();
echo 'php_now=' . date('Y-m-d H:i:s') . "\n";
echo 'db_now=' . $pdo->query('SELECT NOW()')->fetchColumn() . "\n";
echo 'db_curdate=' . $pdo->query('SELECT CURDATE()')->fetchColumn() . "\n";
