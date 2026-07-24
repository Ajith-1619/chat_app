# Flow External API v1

Deploy this folder to `/var/www/html/router_login/api/`.

Base URL:

```text
https://chat.skylinkonline.net/router_login/api/{module}/v1/{resource}
```

Authentication:

```http
Authorization: Bearer <external_api_key>
X-Flow-Actor-Emp-Id: 302
Content-Type: application/json
```

API keys are stored in `flow_api_clients` as SHA-256 hashes. The deployment can also expose a temporary environment key through `FLOW_EXTERNAL_API_DEV_KEY`.

Modules included:

- `chat/v1` - message read/send
- `users/v1` - user directory/profile/presence
- `groups/v1` - group list/create/update/profile/members
- `channels/v1` - channel list/create/update/profile/members
- `tasks/v1` - task list/create/detail/update comments
- `reminders/v1` - reminder/follow-up list/create
- `notifications/v1` - push/system notification create
- `files/v1` - attachment records
- `attendance/v1` - placeholder for deployment-specific attendance mapping
- `location/v1` - location tracking records
- `releases/v1` - release build records
- `diagnostics/v1` - diagnostics records

See `docs/external_api/` for request/response examples and the endpoint catalogue.

## Create API Client

Run this on the server after uploading the folder:

```bash
php /var/www/html/router_login/api/_shared/create_client.php \
  --name=ExternalPortal \
  --key='CHANGE_ME_EXTERNAL_PORTAL_KEY' \
  --owner=302 \
  --scopes='*'
```

Recommended production scopes can be limited, for example:

```text
chat:read,chat:write,users:read,groups:read,groups:write,channels:read,channels:write,tasks:read,tasks:write,reminders:read,reminders:write,notifications:write,files:read,location:read,releases:read,diagnostics:read
```

## Quick Samples

Create task:

```http
POST /router_login/api/tasks/v1
Authorization: Bearer <external_api_key>
X-Flow-Actor-Emp-Id: 302
Content-Type: application/json

{"title":"Follow up with customer","description":"Call before 5 PM","assignees":[302],"followers":[116],"priority":"high","deadline":"2026-07-24 17:00:00","vertical":"Operations"}
```

Create group:

```http
POST /router_login/api/groups/v1
Authorization: Bearer <external_api_key>
X-Flow-Actor-Emp-Id: 302
Content-Type: application/json

{"name":"External Portal Test","member_emp_ids":[302,116],"description":"Created through Flow external API"}
```

Send message:

```http
POST /router_login/api/chat/v1/messages
Authorization: Bearer <external_api_key>
X-Flow-Actor-Emp-Id: 302
Content-Type: application/json

{"to_jid":"116@chat.skylinkonline.net","body":"Message from external portal"}
```

## Expanded Endpoint Coverage

### Chat
- `GET chat/v1/messages?jid=<jid>&limit=50`
- `POST chat/v1/messages`
- `GET chat/v1/search?q=<text>`
- `GET chat/v1/{message_id}/info`
- `POST chat/v1/{message_id}/edit`
- `POST chat/v1/{message_id}/delete`
- `POST chat/v1/{message_id}/pin`
- `POST chat/v1/{message_id}/bookmark`
- `POST chat/v1/{message_id}/reaction`
- `POST chat/v1/{message_id}/forward`

### Groups And Channels
- `GET groups/v1`, `GET channels/v1`
- `GET groups/v1/{id}`, `GET channels/v1/{id}`
- `POST groups/v1`, `POST channels/v1`
- `PATCH groups/v1/{id}`, `PATCH channels/v1/{id}`
- `DELETE groups/v1/{id}`, `DELETE channels/v1/{id}`
- `GET groups/v1/{id}/members`, `GET channels/v1/{id}/members`
- `POST groups/v1/{id}/members`, `POST channels/v1/{id}/members`
- `DELETE groups/v1/{id}/members/{emp_id}`
- `POST groups/v1/{id}/members/{emp_id}/promote`
- `GET groups/v1/{id}/wakeup`, `POST groups/v1/{id}/wakeup`
- `POST groups/v1/{id}/external-users`
- `GET groups/v1/{id}/ai`, `POST groups/v1/{id}/ai`

### Files, Saved, Search
- `GET files/v1`
- `POST files/v1` with JSON `file_base64`, `file_name`, `to_jid`, optional `restricted`
- `GET saved/v1`
- `POST saved/v1`
- `GET search/v1?q=<text>`

### Tasks, Reminders, Notifications
- `GET tasks/v1`, `GET tasks/v1/{id}`
- `POST tasks/v1`
- `POST tasks/v1/{id}/updates`
- `GET reminders/v1`, `POST reminders/v1`
- `POST notifications/v1`

### Operations
- `GET storage/v1?emp_id=<id>`
- `PATCH storage/v1/{emp_id}` with `limit_mb`
- `GET location/v1`, `POST location/v1`
- `GET attendance/v1`, `POST attendance/v1`
- `GET releases/v1`, `POST releases/v1`
- `POST releases/v1/{id}/approve`
- `POST releases/v1/{id}/rollback`
- `GET diagnostics/v1`
- `GET ai/v1`, `POST ai/v1`
- `GET external-users/v1`
- `POST external-users/v1/{request_id}/approve`
- `POST polls/v1`
- `POST checklists/v1`

Notes:
- These endpoints are API-key/Bearer-token based and isolated from the existing session-only `/chat` APIs.
- File upload currently accepts base64 JSON for external integrations. Multipart upload can be added as a transport upgrade without changing route names.
- Attendance API writes to `flow_api_attendance_events` unless deployment-specific attendance tables are mapped later.
