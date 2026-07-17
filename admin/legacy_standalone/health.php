<?php
declare(strict_types=1);
require_once __DIR__ . '/_bootstrap.php';

$result = [
    'status' => true,
    'app' => 'Flow Master Admin',
    'standalone' => true,
    'admin_folder' => __DIR__,
    'config_file_present' => is_file(__DIR__ . '/admin_config.php'),
    'checks' => [],
];

foreach (['chat', 'task', 'employee'] as $name) {
    try {
        $pdo = flow_admin_db_name($name);
        $result['checks'][$name . '_db'] = ['status' => true, 'driver' => $pdo->getAttribute(PDO::ATTR_DRIVER_NAME)];
    } catch (Throwable $e) {
        $result['status'] = false;
        $result['checks'][$name . '_db'] = ['status' => false, 'error' => $e->getMessage()];
    }
}

$result['checks']['ejabberd_config'] = [
    'status' => (flow_admin_config('ejabberd_admin_jid', '') !== '' && flow_admin_config('ejabberd_admin_password', '') !== ''),
    'api_url' => flow_admin_config('ejabberd_api_url', ''),
    'admin_jid_set' => flow_admin_config('ejabberd_admin_jid', '') !== '',
    'admin_password_set' => flow_admin_config('ejabberd_admin_password', '') !== '',
];

flow_admin_json($result, $result['status'] ? 200 : 500);
