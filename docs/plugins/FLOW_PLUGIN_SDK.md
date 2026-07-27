# Flow Messenger Plugin SDK

Date: 2026-07-24

Flow Messenger supports a server-side plugin/extension system for lifecycle events. Core Messenger code emits generic events only. Plugin-specific behavior must live inside plugin folders and must not be embedded into core chat, channel, or member management code.

## Goals

- Add new behavior without changing core Messenger business logic.
- Keep core chat send/create/member operations stable even if a plugin fails.
- Require plugins to declare hooks, permissions, and data access up front.
- Log plugin errors separately from core system errors.
- Prove the pattern with an auto-translate plugin on `message.received`.

## Hook Events

Supported hooks:

| Hook | Trigger |
| --- | --- |
| `message.sent` | After a message is persisted by chat/API send flow. |
| `message.received` | After a persisted message becomes available to the recipient/room. |
| `channel.created` | After a group/channel room is created and committed. |
| `member.added` | After a member is added during create/manage flows. |

## Core Files

| File | Purpose |
| --- | --- |
| `server_patch/chat/PluginEventBus.php` | Plugin registry sync, event dispatch, sandboxed execution, logs, artifact writer. |
| `server_patch/chat/plugins/auto_translate/manifest.php` | Example plugin manifest. |
| `server_patch/chat/plugins/auto_translate/Plugin.php` | Example plugin handler. |

## Database Tables

The plugin bus auto-creates these tables:

| Table | Purpose |
| --- | --- |
| `flow_plugins` | Registered plugins, declared hooks, permissions, data access, status. |
| `flow_plugin_event_logs` | Success/error event execution records per plugin. |
| `flow_plugin_error_logs` | Plugin errors isolated from core system errors. |
| `flow_plugin_artifacts` | Plugin outputs such as translations, summaries, enrichments. |

## Plugin Folder Structure

Create one folder per plugin:

```text
server_patch/chat/plugins/my_plugin/
  manifest.php
  Plugin.php
```

## Manifest Template

```php
<?php
declare(strict_types=1);

return [
    'plugin_key' => 'vendor.my_plugin',
    'name' => 'My Plugin',
    'version' => '1.0.0',
    'description' => 'What this plugin does.',
    'hooks' => ['message.received'],
    'permissions' => ['db.write_artifacts'],
    'data_access' => [
        'message_fields' => ['id', 'from_jid', 'to_jid', 'body', 'message_type', 'created_at'],
    ],
    'handler' => 'Plugin.php',
    'handler_class' => 'MyPlugin',
    'enabled_by_default' => 1,
];
```

## Handler Template

```php
<?php
declare(strict_types=1);

final class MyPlugin
{
    public function handle(string $hook, array $event, FlowPluginContext $context): void
    {
        if ($hook !== 'message.received') return;

        $message = $event['message'] ?? [];
        $messageId = (string)($message['id'] ?? '');
        $body = trim((string)($message['body'] ?? ''));
        if ($messageId === '' || $body === '') return;

        $context->saveArtifact(
            $hook,
            'message',
            $messageId,
            'my_artifact_type',
            ['value' => 'Plugin output']
        );
    }
}
```

## Permissions

Current permissions:

| Permission | Purpose |
| --- | --- |
| `db.write_artifacts` | Allows plugin to save output to `flow_plugin_artifacts`. |
| `db.read` | Allows plugin to access the PDO connection through context. |

Plugins should request the smallest required permissions.

## Data Access

Plugins can limit message payload fields:

```php
'data_access' => [
    'message_fields' => ['id', 'body', 'from_jid'],
]
```

The bus filters `event['message']` to only those fields before calling the plugin.

## Sandbox Behavior

Plugin execution is isolated by policy:

- Every plugin call is wrapped in `try/catch`.
- Plugin errors do not throw back into Messenger core flows.
- Plugin errors are written to `flow_plugin_error_logs`.
- Plugin event status/duration is written to `flow_plugin_event_logs`.
- Core chat/channel/member flows continue even when a plugin fails.

Note: PHP cannot safely hard-kill arbitrary plugin code inside the same request without process isolation. The current sandbox prevents crashes/blocking from exceptions and bad return values. Heavy plugins should be moved to async worker execution in a future phase.

## Example Plugin: Auto Translate

The included example plugin:

```text
server_patch/chat/plugins/auto_translate/
```

It listens to:

```text
message.received
```

It declares:

```php
'permissions' => ['db.write_artifacts']
```

It stores translations as artifacts:

```text
flow_plugin_artifacts.artifact_type = translation
```

The example intentionally does not modify message text and does not add translation logic into core Messenger files.

## Event Payload Examples

### message.sent

```json
{
  "event_id": "message-sent-123",
  "hook": "message.sent",
  "actor_emp_id": 302,
  "message": {
    "id": 123,
    "from_jid": "302@chat.skylinkonline.net",
    "to_jid": "116@chat.skylinkonline.net",
    "body": "Hello",
    "message_type": "chat",
    "created_at": "2026-07-24T10:00:00+05:30"
  }
}
```

### message.received

```json
{
  "event_id": "message-received-123",
  "hook": "message.received",
  "recipient_scope": "user",
  "message": {
    "id": 123,
    "from_jid": "302@chat.skylinkonline.net",
    "to_jid": "116@chat.skylinkonline.net",
    "body": "vanakkam",
    "message_type": "chat"
  }
}
```

### channel.created

```json
{
  "event_id": "channel-created-55",
  "hook": "channel.created",
  "actor_emp_id": 302,
  "channel": {
    "id": 55,
    "room_name": "#flowrollout",
    "room_jid": "channel-flowrollout@conference.chat.skylinkonline.net",
    "group_type": "channel",
    "channel_kind": "operational"
  }
}
```

### member.added

```json
{
  "event_id": "member-added-55-116",
  "hook": "member.added",
  "actor_emp_id": 302,
  "group_id": 55,
  "room_jid": "channel-flowrollout@conference.chat.skylinkonline.net",
  "member_emp_id": 116,
  "role": "member"
}
```

## Enabling Or Disabling Plugins

Plugins are auto-registered from manifests when the bus runs. To disable a plugin:

```sql
UPDATE flow_plugins SET status = 0 WHERE plugin_key = 'flow.auto_translate';
```

To re-enable:

```sql
UPDATE flow_plugins SET status = 1 WHERE plugin_key = 'flow.auto_translate';
```

## Future Extensions

Recommended future additions:

- Async plugin queue for slow AI/network plugins.
- Admin UI for plugin enable/disable and permission review.
- Per-workspace/channel plugin enablement.
- Webhook plugin type for external systems.
- Secret vault for plugin API keys.
- Plugin health dashboard.
