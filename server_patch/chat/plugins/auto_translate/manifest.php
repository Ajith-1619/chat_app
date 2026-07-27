<?php
declare(strict_types=1);

return [
    'plugin_key' => 'flow.auto_translate',
    'name' => 'Flow Auto Translate Example',
    'version' => '1.0.0',
    'description' => 'Example plugin proving message.received hook integration without core message logic.',
    'hooks' => ['message.received'],
    'permissions' => ['db.write_artifacts'],
    'data_access' => [
        'message_fields' => ['id', 'from_jid', 'to_jid', 'body', 'message_type', 'created_at'],
    ],
    'handler' => 'Plugin.php',
    'handler_class' => 'FlowAutoTranslatePlugin',
    'enabled_by_default' => 1,
];
