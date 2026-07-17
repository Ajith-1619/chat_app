<?php
declare(strict_types=1);

// Copy to admin_config.php and fill live values.
// Standalone rule: admin app reads only files inside admin/.
return [
    'allowed_emp_ids' => [302, 116],
    'chat_domain' => 'chat.skylinkonline.net',
    'muc_domain' => 'conference.chat.skylinkonline.net',
    'ejabberd_api_url' => 'https://chat.skylinkonline.net:5443/api',
    'ejabberd_admin_jid' => 'CHANGE_ME_ADMIN_JID',
    'ejabberd_admin_password' => 'CHANGE_ME_ADMIN_PASSWORD',
    'databases' => [
        'chat' => [
            'host' => 'localhost',
            'port' => '3306',
            'database' => 'CHANGE_ME_CHAT_DB',
            'username' => 'CHANGE_ME_DB_USER',
            'password' => 'CHANGE_ME_DB_PASSWORD',
            'charset' => 'utf8mb4',
        ],
        'task' => [
            'host' => 'localhost',
            'port' => '3306',
            'database' => 'CHANGE_ME_TASK_DB',
            'username' => 'CHANGE_ME_DB_USER',
            'password' => 'CHANGE_ME_DB_PASSWORD',
            'charset' => 'utf8mb4',
        ],
        'employee' => [
            'host' => 'localhost',
            'port' => '3306',
            'database' => 'CHANGE_ME_EMPLOYEE_DB',
            'username' => 'CHANGE_ME_DB_USER',
            'password' => 'CHANGE_ME_DB_PASSWORD',
            'charset' => 'utf8mb4',
        ],
    ],
];
