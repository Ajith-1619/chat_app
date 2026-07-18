<?php
chdir('/var/www/html/admin');
$_SERVER['HTTP_ACCEPT'] = 'application/json';
$_GET['action'] = 'user_detail';
$_GET['id'] = '24';
if (session_status() !== PHP_SESSION_ACTIVE) session_start();
$_SESSION['flow_admin_emp_id'] = 302;
include '/var/www/html/admin/api.php';
