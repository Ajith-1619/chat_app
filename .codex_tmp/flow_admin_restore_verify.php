<?php
function call_action($action, $extra) {
  chdir('/var/www/html/admin');
  $_SERVER['HTTP_ACCEPT']='application/json'; $_SERVER['REQUEST_METHOD']='POST'; $_GET=['action'=>$action]; $_POST=['id'=>'24','csrf'=>'probe'] + $extra; $_SERVER['HTTP_X_FLOW_ADMIN_CSRF']='probe';
  if (session_status() !== PHP_SESSION_ACTIVE) session_start(); $_SESSION['flow_admin_emp_id']=302; $_SESSION['flow_admin_csrf']='probe'; include '/var/www/html/admin/api.php';
}
if ($argv[1] === 'limit') call_action('update_user_storage_limit', ['storage_limit_mb'=>'']);
if ($argv[1] === 'type') call_action('update_employee_type', ['employee_type'=>'C1']);
