<?php
chdir('/var/www/html/admin');
$_SERVER['HTTP_ACCEPT'] = 'application/json';
$_SERVER['REQUEST_METHOD'] = 'POST';
$_GET['action'] = 'update_user_storage_limit';
$_POST['id'] = '24';
$_POST['storage_limit_mb'] = '100';
$_POST['csrf'] = 'probe';
$_SERVER['HTTP_X_FLOW_ADMIN_CSRF'] = 'probe';
if (session_status() !== PHP_SESSION_ACTIVE) session_start();
$_SESSION['flow_admin_emp_id'] = 302;
$_SESSION['flow_admin_csrf'] = 'probe';
include '/var/www/html/admin/api.php';
