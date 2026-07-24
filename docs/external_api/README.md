# Flow External API Plan

Date: 2026-07-24

## Why The Current API Shows Unauthorized

Most current Flow endpoints call `chat_require_user()`. That means they expect a logged-in Flow app session, usually browser/app cookies from `chat/login.php`. External portals, Postman, CRM tools, websites, automation jobs, and partner systems do not have that Flow session, so they correctly receive:

```json
{
  "status": false,
  "error": "Unauthorized"
}
```

The permanent solution is not to remove authentication from existing app APIs. The right solution is to add a dedicated external API layer with API keys, scopes, audit logs, rate limits, and stable versioned paths.

## Recommended External API Base

Use module-first versioned public layers:

```text
https://chat.skylinkonline.net/router_login/api/chat/v1/
https://chat.skylinkonline.net/router_login/api/users/v1/
https://chat.skylinkonline.net/router_login/api/groups/v1/
https://chat.skylinkonline.net/router_login/api/channels/v1/
```

Local/server patch folder suggestion:

```text
server_patch/api/
```

Full route design is documented in:

```text
docs/external_api/VERSIONED_API_ROUTES.md
docs/external_api/CHAT_V1.md
docs/external_api/USERS_V1.md
docs/external_api/GROUPS_V1.md
docs/external_api/CHANNELS_V1.md
docs/external_api/TASKS_REMINDERS_NOTIFICATIONS_V1.md
docs/external_api/FILES_ATTENDANCE_LOCATION_V1.md
```

## Authentication

Use bearer API keys:

```http
Authorization: Bearer flow_xxxxx
Content-Type: application/json
```

Each key should have:

- key id
- key hash, never plain text after creation
- app name
- owner employee id
- allowed scopes
- allowed IPs, optional
- active/inactive status
- expiry date
- created/updated timestamps

## Core Tables To Add

```sql
CREATE TABLE flow_api_clients (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  client_name VARCHAR(150) NOT NULL,
  owner_emp_id INT NOT NULL,
  api_key_hash VARCHAR(255) NOT NULL,
  scopes_json JSON NOT NULL,
  allowed_ips_json JSON NULL,
  status TINYINT NOT NULL DEFAULT 1,
  expires_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uniq_api_key_hash (api_key_hash)
);

CREATE TABLE flow_api_audit_logs (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  client_id BIGINT UNSIGNED NULL,
  scope VARCHAR(100) NOT NULL,
  endpoint VARCHAR(255) NOT NULL,
  method VARCHAR(10) NOT NULL,
  actor_emp_id INT NULL,
  target_type VARCHAR(80) NULL,
  target_id VARCHAR(120) NULL,
  request_id VARCHAR(80) NOT NULL,
  ip_address VARCHAR(80) NULL,
  status_code INT NOT NULL,
  result_status VARCHAR(30) NOT NULL,
  error_message TEXT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_client_created (client_id, created_at),
  KEY idx_request_id (request_id)
);
```

## Scope Model

Use simple scopes first:

```text
chat:read
chat:send
chat:attachments
groups:read
groups:write
channels:read
channels:write
tasks:read
tasks:write
reminders:read
reminders:write
attendance:read
notifications:send
users:read
locations:read
releases:read
diagnostics:read
```

## Implementation Plan

1. Add external API bootstrap
   - `external/v1/bootstrap.php`
   - validates bearer token
   - loads client/scopes
   - rejects expired/inactive keys
   - writes audit logs

2. Add stable endpoint wrappers
   - Do not expose every internal PHP file directly.
   - Wrap only approved actions.
   - Keep internal app APIs unchanged.

3. Start with task APIs
   - `POST /tasks`
   - `POST /tasks/{id}/updates`
   - `GET /tasks`
   - `GET /tasks/{id}`

4. Add messaging APIs
   - send text
   - send attachment
   - read history
   - message info

5. Add group/channel APIs
   - create group/channel
   - add/remove members
   - read profile
   - channel description/next action

6. Add admin API management UI
   - create/revoke API keys
   - assign scopes
   - view usage and audit logs

## Response Shape

All external APIs should use a consistent envelope:

Success:

```json
{
  "status": true,
  "data": {},
  "request_id": "req_..."
}
```

Failure:

```json
{
  "status": false,
  "error": "Human readable error",
  "code": "FLOW_ERROR_CODE",
  "request_id": "req_..."
}
```

## Security Rules

- Never allow unauthenticated external write APIs.
- Never store plain API keys.
- Never expose `xmpp_password` through external APIs.
- Enforce scopes on every endpoint.
- Log every write action.
- Add rate limits per client.
- Add idempotency key support for create/send APIs.
- Keep destructive actions out of v1 unless explicitly approved.

## First Version Recommendation

Build v1 in this order:

1. Task create/update/read
2. Reminder/follow-up create/read
3. Send notification
4. Create group/channel
5. Send message
6. Upload/send file
7. Read chat history/search
8. User directory
9. Attendance read-only
10. Release read-only


