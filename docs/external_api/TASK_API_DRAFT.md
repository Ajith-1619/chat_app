# Task Create And Update External API Draft

Date: 2026-07-24

## Current Internal APIs

These work only with logged-in Flow session auth:

```text
POST /router_login/chat/myhub.php?section=task_create
POST /router_login/chat/task_update.php
GET  /router_login/chat/myhub.php?section=tasks&limit=100
GET  /router_login/chat/myhub.php?section=task_detail&task_id=123
```

For external portals, use the new external API wrapper below.

## Recommended External Task APIs

Base:

```text
https://chat.skylinkonline.net/router_login/chat/external/v1
```

Auth:

```http
Authorization: Bearer flow_xxxxx
Content-Type: application/json
Idempotency-Key: optional-unique-key
```

## Create Task

```http
POST /tasks
```

Required scope:

```text
tasks:write
```

Body:

```json
{
  "title": "Check router issue",
  "description": "Customer router login issue needs follow-up",
  "priority": "high",
  "deadline": "2026-07-24 18:00:00",
  "assignees": [302, 116],
  "followers": [307],
  "group_id": 99,
  "vertical": "Technology",
  "task_type": "general",
  "meet_type": 1,
  "status": 2,
  "next_followup_date": "2026-07-25"
}
```

Response:

```json
{
  "status": true,
  "data": {
    "task": {
      "id": 3358,
      "title": "Check router issue"
    }
  },
  "request_id": "req_20260724_..."
}
```

Validation:

- `title` required.
- `priority` accepts `high`, `medium`, `low`.
- `assignees` and `followers` must be employee IDs.
- If `assignees` is empty, use the API client owner or supplied `actor_emp_id`.
- If `followers` is empty, include creator by default.
- `deadline` must parse to a valid date/time.

## Update Task

```http
POST /tasks/{task_id}/updates
```

Required scope:

```text
tasks:write
```

Body:

```json
{
  "comments": "Work started. Waiting for customer confirmation.",
  "comment_type": "External Update"
}
```

Response:

```json
{
  "status": true,
  "data": {
    "task_id": 3358,
    "update_id": 1201
  },
  "request_id": "req_20260724_..."
}
```

Validation:

- `task_id` required.
- `comments` required.
- `comments` max length should be 10000 characters.
- API client must have `tasks:write`.

## List Tasks

```http
GET /tasks?limit=100&offset=0&emp_id=302&status=open
```

Required scope:

```text
tasks:read
```

Response:

```json
{
  "status": true,
  "data": {
    "tasks": []
  },
  "request_id": "req_20260724_..."
}
```

## Task Detail

```http
GET /tasks/{task_id}
```

Required scope:

```text
tasks:read
```

Response:

```json
{
  "status": true,
  "data": {
    "task": {},
    "updates": []
  },
  "request_id": "req_20260724_..."
}
```

## Notification Behavior

On create and update:

- send system notification to creator
- send system notification to assignees
- send system notification to followers
- include title, description, created by, assignees, followers, vertical, priority

## Implementation Files To Create

```text
server_patch/chat/external/v1/bootstrap.php
server_patch/chat/external/v1/tasks.php
server_patch/chat/external/v1/task_updates.php
```

Alternative single-router style:

```text
server_patch/chat/external/v1/index.php
```

## Postman Example

```bash
curl -X POST "https://chat.skylinkonline.net/router_login/chat/external/v1/tasks" \
  -H "Authorization: Bearer flow_xxxxx" \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: task-test-001" \
  -d "{\"title\":\"API task test\",\"priority\":\"high\",\"assignees\":[302],\"followers\":[307]}"
```

