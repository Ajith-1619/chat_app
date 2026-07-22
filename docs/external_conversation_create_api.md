# External Conversation Create API

Use this API from external apps/portals to create Flow groups or channels without a browser login session.

## Endpoint

```http
POST https://dns.watchtower247.in/router_login/chat/external_create_conversation.php
Content-Type: application/json
Authorization: Bearer skylink-flow-conversation-api-key-2026
```

Alternative key headers:

```http
X-Skylink-Conversation-Key: skylink-flow-conversation-api-key-2026
X-Skylink-API-Key: skylink-flow-conversation-api-key-2026
```

Server can override the default key with `SKYLINK_CONVERSATION_API_KEY` / `SKYCHAT_CONVERSATION_API_KEY`.

## Create Group

```json
{
  "type": "group",
  "created_by_emp_id": 302,
  "group_name": "Portal Created Group",
  "members": [302, 116, 218]
}
```

## Create Channel

```json
{
  "type": "channel",
  "created_by_emp_id": 302,
  "channel_name": "Portal Incident Channel",
  "description": "Created from customer portal for incident tracking.",
  "members": [302, 116, 218],
  "channel_type": "incident",
  "priority": "High",
  "status": "Open",
  "target_date": "2026-07-25 18:00",
  "next_action_date": "2026-07-23 18:00",
  "sla_minutes": 240,
  "stale_alert_minutes": 120,
  "source": "customer_portal",
  "external_reference_id": "PORTAL-INC-1001"
}
```

## Success Response

```json
{
  "status": true,
  "type": "channel",
  "group_id": 456,
  "room_name": "#Portal Incident Channel",
  "room_jid": "inc-portal-incident-channel-ab12cd34@conference.chat.skylinkonline.net",
  "channel_kind": "incident",
  "channel_definition_id": 1,
  "channel_definition_name": "Incident",
  "members": [302, 116, 218]
}
```

## Notes

- `created_by_emp_id` is required and becomes owner.
- Creator is automatically added to `members` if missing.
- C1/C2 user types are blocked from creating groups/channels.
- Members must be active employee IDs.
- Use environment/config override for production API key rotation.
