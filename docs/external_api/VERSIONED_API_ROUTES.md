# Flow Versioned External API Routes

Date: 2026-07-24

## Objective

Expose Flow as a platform API for external portals, CRM systems, websites, automation jobs, customer tools, and partner applications.

Current internal APIs are app-session based and return `Unauthorized` when called externally without Flow login cookies. The new external API must be API-key based, versioned, scoped, audited, and stable.

## Base URL Pattern

Use module-first versioning:

```text
https://chat.skylinkonline.net/router_login/api/{module}/v1/{resource}
```

Examples:

```text
/api/chat/v1/messages
/api/users/v1/users
/api/groups/v1/groups
/api/channels/v1/channels
/api/tasks/v1/tasks
```

## Server Folder Pattern

Recommended patch/source structure:

```text
server_patch/api/
  _shared/
    bootstrap.php
    auth.php
    response.php
    audit.php
    rate_limit.php
    validation.php
  chat/v1/index.php
  users/v1/index.php
  groups/v1/index.php
  channels/v1/index.php
  tasks/v1/index.php
  reminders/v1/index.php
  notifications/v1/index.php
  files/v1/index.php
  attendance/v1/index.php
  location/v1/index.php
  releases/v1/index.php
  diagnostics/v1/index.php
```

Deployment target:

```text
/var/www/html/router_login/api/
```

## Authentication

External APIs use bearer keys:

```http
Authorization: Bearer flow_live_xxxxxxxxx
Content-Type: application/json
Idempotency-Key: optional-unique-key
```

Do not use Flow browser cookies for external systems.

## Standard Response

Success:

```json
{
  "status": true,
  "data": {},
  "request_id": "req_20260724_000001"
}
```

Failure:

```json
{
  "status": false,
  "error": "Unauthorized",
  "code": "FLOW_UNAUTHORIZED",
  "request_id": "req_20260724_000001"
}
```

## API Modules

| Module | Base Path | Purpose |
| --- | --- | --- |
| Chat | `/api/chat/v1` | Messages, history, message actions, saved messages |
| Users | `/api/users/v1` | Employee directory, profile, presence, sessions |
| Groups | `/api/groups/v1` | Group creation, members, roles, profile |
| Channels | `/api/channels/v1` | Channel creation, description, AI, wake-up, next actions |
| Tasks | `/api/tasks/v1` | Task create, update, list, detail |
| Reminders | `/api/reminders/v1` | Reminders and follow-ups |
| Notifications | `/api/notifications/v1` | System notifications and OTP-style push |
| Files | `/api/files/v1` | Upload, download, storage usage, restrictions |
| Attendance | `/api/attendance/v1` | Punch and attendance read APIs |
| Location | `/api/location/v1` | Location updates, visibility, reverse geocode |
| Releases | `/api/releases/v1` | Release notes and update metadata |
| Diagnostics | `/api/diagnostics/v1` | Health and performance diagnostics |

## Scope Matrix

| Scope | Allows |
| --- | --- |
| `chat:read` | Read conversations, history, message info |
| `chat:send` | Send, edit, delete, react, pin messages |
| `files:read` | View/download allowed files |
| `files:write` | Upload/send files |
| `users:read` | User directory/profile/presence |
| `groups:read` | Group list/profile/member read |
| `groups:write` | Create/update groups, manage members |
| `channels:read` | Channel profile/timeline/read APIs |
| `channels:write` | Create/update/archive channels, AI config |
| `tasks:read` | Task list/detail |
| `tasks:write` | Task create/update |
| `reminders:read` | Reminder/follow-up list |
| `reminders:write` | Reminder/follow-up create/stop |
| `notifications:send` | Send system notification |
| `attendance:read` | Attendance status/report read |
| `attendance:write` | Punch actions, only if approved |
| `location:read` | Location profile/history where policy allows |
| `location:write` | Submit location metadata |
| `releases:read` | Version/release metadata |
| `diagnostics:read` | Diagnostics read |

## Implementation Phases

### Phase 1: Foundation

- Shared API bootstrap.
- API key validation.
- Scope enforcement.
- JSON response helper.
- Audit log table.
- Rate limit table.
- Idempotency key table.

### Phase 2: Tasks And Notifications

- `POST /api/tasks/v1/tasks`
- `POST /api/tasks/v1/tasks/{id}/updates`
- `GET /api/tasks/v1/tasks`
- `GET /api/tasks/v1/tasks/{id}`
- `POST /api/notifications/v1/notifications`

### Phase 3: Chat And Files

- `POST /api/chat/v1/messages`
- `GET /api/chat/v1/conversations`
- `GET /api/chat/v1/conversations/{jid}/messages`
- `POST /api/files/v1/files`

### Phase 4: Groups And Channels

- `POST /api/groups/v1/groups`
- `POST /api/channels/v1/channels`
- member management
- channel description and next action APIs
- channel AI access APIs

### Phase 5: Admin API Management

- Create API clients.
- Assign scopes.
- Rotate/revoke keys.
- View usage and audit logs.

## Security Requirements

- Never expose plain passwords or XMPP passwords.
- Never allow wildcard full-access keys by default.
- Every write API must be audited.
- Every create/send API must support `Idempotency-Key`.
- External APIs must not bypass Flow business rules.
- Location APIs must enforce location visibility policies.
- File APIs must enforce restricted-download policy.

