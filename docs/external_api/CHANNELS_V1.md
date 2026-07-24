# Channels API v1

Base:

```text
/api/channels/v1
```

## Endpoints

| Method | Path | Scope | Description |
| --- | --- | --- | --- |
| GET | `/channels` | `channels:read` | List channels visible to actor |
| POST | `/channels` | `channels:write` | Create channel |
| GET | `/channels/{channel_id}` | `channels:read` | Channel profile |
| PATCH | `/channels/{channel_id}` | `channels:write` | Update channel details |
| DELETE | `/channels/{channel_id}` | `channels:write` | Archive/delete channel |
| GET | `/channels/{channel_id}/members` | `channels:read` | Channel members |
| POST | `/channels/{channel_id}/members` | `channels:write` | Add channel members |
| DELETE | `/channels/{channel_id}/members/{emp_id}` | `channels:write` | Remove member |
| GET | `/channels/{channel_id}/timeline` | `channels:read` | Channel audit timeline |
| GET | `/channels/{channel_id}/tags` | `channels:read` | Channel hashtags |
| GET | `/channels/{channel_id}/next-action` | `channels:read` | AI/script detected next action |
| PATCH | `/channels/{channel_id}/description` | `channels:write` | Update channel purpose/description |
| PATCH | `/channels/{channel_id}/wake-up` | `channels:write` | Update wake-up interval |
| PATCH | `/channels/{channel_id}/ai-access` | `channels:write` | Assign AI API access to channel |
| POST | `/channels/{channel_id}/external-users/request` | `channels:write` | Request external user addition |

## Create Channel

```http
POST /api/channels/v1/channels
```

```json
{
  "name": "#flowrollout",
  "channel_type": "operational",
  "description": "Flow rollout planning and operational updates",
  "member_emp_ids": [302, 116],
  "allow_empty_channel": true,
  "target_date": "2026-08-01",
  "next_action": "",
  "next_action_person": "",
  "next_action_date": "",
  "wakeup_enabled": false,
  "wakeup_interval_minutes": 1440
}
```

## Channel Types

```text
incident
action
operational
project
announcement
```

## AI Behavior

When channel AI access is enabled:

- `@ai` reads latest configured conversation context.
- Channel description must be included as purpose/context.
- Actionable messages should update:
  - `next_action`
  - `next_action_person`
  - `next_action_date`

Example message:

```text
@Ajith_P complete the chat application task tomorrow
```

Expected detection:

```json
{
  "next_action": "Complete the chat application task",
  "next_action_person": "Ajith P",
  "next_action_date": "tomorrow"
}
```

