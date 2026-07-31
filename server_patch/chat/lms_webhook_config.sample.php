<?php
declare(strict_types=1);

// Copy this file to lms_webhook_config.php on the server and put the real
// bearer token there. Do not commit or expose the real token in logs/UI.
return [
    'url' => 'https://skylinkonline.net/lms/public/api/flow-webhook.php',
    'token' => 'REPLACE_WITH_LMS_BEARER_TOKEN',
    'tenant_slug' => 'skylink-tech',
    'max_attempts' => 5,
    'timeout_seconds' => 10,
];
