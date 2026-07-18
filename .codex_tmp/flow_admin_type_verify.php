<?php
function run_api(array $get, array $post = []) {
    chdir('/var/www/html/admin');
    $_SERVER['HTTP_ACCEPT'] = 'application/json';
    $_SERVER['REQUEST_METHOD'] = $post ? 'POST' : 'GET';
    $_GET = $get;
    $_POST = $post;
    if (session_status() !== PHP_SESSION_ACTIVE) session_start();
    $_SESSION['flow_admin_emp_id'] = 302;
    $_SESSION['flow_admin_csrf'] = 'probe';
    $_POST['csrf'] = 'probe';
    $_SERVER['HTTP_X_FLOW_ADMIN_CSRF'] = 'probe';
    ob_start();
    include '/var/www/html/admin/api.php';
    $raw = ob_get_clean();
    $pos = strpos($raw, '{'); if ($pos !== false) $raw = substr($raw, $pos);
    return json_decode($raw, true) ?: ['status' => false, 'raw' => substr($raw, 0, 120)];
}
$j = run_api(['action'=>'user_detail','id'=>'24']);
echo 'detail_status='.(($j['status']??false)?'true':'false').PHP_EOL;
echo 'employee_type='.($j['employee_type']['value']??'').PHP_EOL;
echo 'systems_count='.count($j['systems']??[]).PHP_EOL;
echo 'system_source='.(($j['systems'][0]['source']??'')).PHP_EOL;
echo 'storage_label='.($j['files']['storage_label']??'').PHP_EOL;
