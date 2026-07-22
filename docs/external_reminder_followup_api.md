# External Reminder And Follow-up Create API

Use this API from external apps/portals to create Flow reminders and follow-ups without browser login sessions.

## Endpoint

```http
POST https://dns.watchtower247.in/router_login/chat/external_create_reminder.php
Content-Type: application/json
Authorization: Bearer skylink-flow-work-api-key-2026
```

Also accepted for compatibility:

```http
Authorization: Bearer skylink-flow-conversation-api-key-2026
X-Skylink-Work-Key: skylink-flow-work-api-key-2026
X-Skylink-API-Key: skylink-flow-work-api-key-2026
```

Server can override with `SKYLINK_WORK_API_KEY`.

## Create Reminder

```json
{
  "kind": "reminder",
  "created_by_emp_id": 302,
  "title": "Call customer about payment",
  "notes": "Created from external CRM portal.",
  "assignee_ids": [302, 116],
  "starts_at": "2026-07-23 10:30",
  "recurrence": "once",
  "source": "crm_portal",
  "source_conversation_jid": "",
  "source_conversation_name": "CRM Portal",
  "source_message_text": "Customer requested a callback."
}
```

## Create Follow-up

```json
{
  "kind": "followup",
  "created_by_emp_id": 302,
  "title": "Follow up installation site readiness",
  "notes": "Check whether the site is ready before dispatch.",
  "assignee_ids": [218, 302],
  "starts_at": "2026-07-24 15:00",
  "recurrence": "daily",
  "source": "installation_portal",
  "reference_text": "Site readiness pending."
}
```

## Recurrence Values

```text
once, daily, weekly, monthly, custom
```

For custom recurrence:

```json
{
  "recurrence": "custom",
  "custom_interval": 2,
  "custom_unit": "week"
}
```

`custom_unit` supports:

```text
day, week, month
```

## Success Response

```json
{
  "status": true,
  "id": 101,
  "kind": "followup",
  "title": "Follow up installation site readiness",
  "created_by_emp_id": 302,
  "assignee_ids": [218, 302],
  "starts_at": "2026-07-24 15:00:00",
  "next_due_at": "2026-07-24 15:00:00",
  "recurrence": "daily"
}
```

## Notes

- `created_by_emp_id` is required and must be active.
- `assignee_ids` must be active employee IDs. If empty, creator is assigned.
- Creation emits the existing Flow system notification event to creator/assignees.
- No chat login cookie is required; API key is required.
