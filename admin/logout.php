<?php
declare(strict_types=1);
require_once __DIR__ . '/_bootstrap.php';
flow_admin_start();
unset($_SESSION['flow_admin_emp_id']);
header('Location: index.php');
exit;

