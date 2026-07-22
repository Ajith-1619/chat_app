<?php
declare(strict_types=1);

return [
    'host' => getenv('FLOW_SMTP_HOST') ?: 'mail.skylinkonline.net',
    'port' => (int)(getenv('FLOW_SMTP_PORT') ?: 587),
    'username' => getenv('FLOW_SMTP_USERNAME') ?: 'flow@skylinkonline.net',
    'password' => getenv('FLOW_SMTP_PASSWORD') ?: 'flow@123',
    'from_email' => getenv('FLOW_SMTP_FROM_EMAIL') ?: 'flow@skylinkonline.net',
    'from_name' => getenv('FLOW_SMTP_FROM_NAME') ?: 'Flow Messager',
    'timeout_seconds' => (int)(getenv('FLOW_SMTP_TIMEOUT') ?: 20),
];
