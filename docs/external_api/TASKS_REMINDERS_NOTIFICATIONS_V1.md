# Tasks, Reminders, Notifications API v1

Date: 2026-07-24

## Tasks Base

```text
/api/tasks/v1
```

| Method | Path | Scope | Description |
| --- | --- | --- | --- |
| GET | `/tasks` | `tasks:read` | List tasks visible to actor |
| POST | `/tasks` | `tasks:write` | Create task |
| GET | `/tasks/{task_id}` | `tasks:read` | Task detail |
| PATCH | `/tasks/{task_id}` | `tasks:write` | Update task master fields |
| POST | `/tasks/{task_id}/updates` | `tasks:write` | Add task update/comment |
| POST | `/tasks/{task_id}/close-request` | `tasks:write` | Request closure |
| POST | `/tasks/{task_id}/reopen` | `tasks:write` | Reopen task |

## Create Task

```json
{
  "title": "Router check",
  "description": "Check router login issue",
  "priority": "high",
  "deadline": "2026-07-24 18:00:00",
  "assignees": [302],
  "followers": [307],
  "vertical": "Technology",
  "group_id": 99
}
```

## Add Task Update

```json
{
  "comments": "Customer confirmed issue is still active.",
  "comment_type": "External Update"
}
```

## Reminders Base

```text
/api/reminders/v1
```

| Method | Path | Scope | Description |
| --- | --- | --- | --- |
| GET | `/reminders` | `reminders:read` | Reminder list |
| POST | `/reminders` | `reminders:write` | Create reminder |
| POST | `/followups` | `reminders:write` | Create follow-up |
| POST | `/reminders/{id}/stop` | `reminders:write` | Stop reminder |

## Notifications Base

```text
/api/notifications/v1
```

| Method | Path | Scope | Description |
| --- | --- | --- | --- |
| GET | `/notifications` | `notifications:send` | Notification feed/status |
| POST | `/notifications` | `notifications:send` | Send system notification |
| POST | `/notifications/test` | `notifications:send` | Test notification |

## Send Notification

```json
{
  "recipient_emp_id": 302,
  "event_type": "external_alert",
  "reference_id": "portal-001",
  "body": "External portal alert"
}
```

