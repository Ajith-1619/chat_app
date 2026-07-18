<?php
chdir('/var/www/html/admin');
$_SERVER['HTTP_ACCEPT']='application/json'; $_SERVER['REQUEST_METHOD']='POST';
$_GET['action']=$argv[1]; $_POST=['id'=>'24','csrf'=>'probe'];
if($argv[1]==='update_user_storage_limit') $_POST['storage_limit_mb']='';
if($argv[1]==='update_employee_type') $_POST['employee_type']='C1';
$_SERVER['HTTP_X_FLOW_ADMIN_CSRF']='probe';
if(session_status()!==PHP_SESSION_ACTIVE) session_start();
$_SESSION['flow_admin_emp_id']=302; $_SESSION['flow_admin_csrf']='probe';
include '/var/www/html/admin/api.php';
