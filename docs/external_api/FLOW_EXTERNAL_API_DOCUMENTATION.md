# Flow External API Documentation

Date: 2026-07-24
Base URL: `https://dns.watchtower247.in/router_login/api/{module}/v1/{resource}`

This document covers the external API endpoints exposed from `server_patch/api`. These APIs are designed for external portals, automation tools, admin systems, and integrations that need to connect to Flow without using the Flutter app session.

## 1. Authentication

All endpoints require a Bearer API key.

```http
Authorization: Bearer <external_api_key>
X-Flow-Actor-Emp-Id: 302
Content-Type: application/json
```

`X-Flow-Actor-Emp-Id` tells Flow which employee is performing the action. If omitted, the API client owner is used.

API keys are stored as SHA-256 hashes in `flow_api_clients`.

Create an API client on the server:

```bash
php /var/www/html/router_login/api/_shared/create_client.php \
  --name=ExternalPortal \
  --key='CHANGE_ME_EXTERNAL_PORTAL_KEY' \
  --owner=302 \
  --scopes='*'
```

Recommended production scopes:

```text
chat:read,chat:write,users:read,groups:read,groups:write,channels:read,channels:write,tasks:read,tasks:write,reminders:read,reminders:write,notifications:write,files:read,files:write,location:read,location:write,attendance:read,attendance:write,releases:read,releases:write,diagnostics:read,ai:read,ai:write,external-users:read,external-users:write,storage:read,storage:write,saved:read,saved:write,search:read
```

## 2. Standard Response Format

Success:

```json
{
  "status": true,
  "request_id": "abc123",
  "data_key": {}
}
```

Error:

```json
{
  "status": false,
  "error": "Unauthorized",
  "code": "UNAUTHORIZED",
  "request_id": "abc123"
}
```

Common HTTP status codes:

| Code | Meaning |
| --- | --- |
| 200 | Success |
| 201 | Created |
| 400 | Invalid request |
| 401 | Missing or invalid API key |
| 403 | API key does not have required scope |
| 404 | Endpoint or record not found |
| 405 | Method not allowed |
| 422 | Validation error |
| 500 | Server/database error |

## 3. JID Formats

User JID:

```text
{employee_id}@chat.skylinkonline.net
```

Group/channel JID:

```text
{room_slug}@conference.chat.skylinkonline.net
```

Example:

```text
116@chat.skylinkonline.net
channel-flowrollout-f5e7be47@conference.chat.skylinkonline.net
```

## 4. Chat API

Module base:

```text
https://dns.watchtower247.in/router_login/api/chat/v1
```

### 4.1 Fetch Messages

```http
GET /chat/v1/messages?jid=<jid>&limit=50
```

Example:

```http
GET https://dns.watchtower247.in/router_login/api/chat/v1/messages?jid=116@chat.skylinkonline.net&limit=50
Authorization: Bearer <api_key>
X-Flow-Actor-Emp-Id: 302
```

Response key: `messages`.

### 4.2 Send Text Message

```http
POST /chat/v1/messages
```

Body:

```json
{
  "to_jid": "116@chat.skylinkonline.net",
  "body": "Hi from external portal",
  "message_type": "chat",
  "source_name": "External Portal",
  "client_message_id": "portal-1001"
}
```


### 4.2.a Send One-to-One Message By Employee ID

Use this when an external portal has employee IDs but not JIDs.

```http
POST https://dns.watchtower247.in/router_login/api/chat/v1/direct/messages
Authorization: Bearer <api_key>
X-Flow-Actor-Emp-Id: 302
Content-Type: application/json
```

```json
{
  "sender_emp_id": 302,
  "recipient_emp_id": 116,
  "body": "Hi from external portal",
  "source_name": "External Portal",
  "client_message_id": "portal-dm-1001"
}
```

`sender_emp_id` is optional. If omitted, Flow uses `X-Flow-Actor-Emp-Id` or the API client owner. Scope required: `chat:write`.

Fetch direct history:

```http
GET https://dns.watchtower247.in/router_login/api/chat/v1/direct/messages?recipient_emp_id=116&sender_emp_id=302&limit=50
Authorization: Bearer <api_key>
```

Response key: `messages`.
Group/channel body:

```json
{
  "to_jid": "channel-flowrollout-f5e7be47@conference.chat.skylinkonline.net",
  "body": "Update from external portal",
  "message_type": "groupchat",
  "source_name": "External Portal"
}
```

Group/channel messages use the same endpoint as direct messages. Use the room JID from the group/channel profile. If `message_type` is omitted, the API detects `@conference.` room JIDs and stores the message as `groupchat`.

Examples:

```http
POST https://dns.watchtower247.in/router_login/api/chat/v1/messages
```

```json
{
  "to_jid": "st-velocity-complaints-44b18839@conference.chat.skylinkonline.net",
  "body": "Group update from CRM portal"
}
```

```json
{
  "to_jid": "channel-flowrollout-f5e7be47@conference.chat.skylinkonline.net",
  "body": "Channel update from external portal"
}
```

Response key: `message`.

### 4.3 Search Chat Messages

```http
GET /chat/v1/search?q=<text>
```

Response key: `results`.

### 4.4 Message Info

```http
GET /chat/v1/{message_id}/info
```

Returns message metadata, including delivery/read/location fields if available.

### 4.5 Edit Message

```http
POST /chat/v1/{message_id}/edit
```

Body:

```json
{
  "body": "Updated message text"
}
```

### 4.6 Delete Message

```http
POST /chat/v1/{message_id}/delete
```

Soft deletes the message by setting `deleted_at`.

### 4.7 Pin Message

```http
POST /chat/v1/{message_id}/pin
```

### 4.8 Bookmark Message

```http
POST /chat/v1/{message_id}/bookmark
```

### 4.9 React To Message

```http
POST /chat/v1/{message_id}/reaction
```

Body:

```json
{
  "emoji": "??"
}
```

### 4.10 Forward Message

```http
POST /chat/v1/{message_id}/forward
```

Body:

```json
{
  "to_jid": "116@chat.skylinkonline.net"
}
```

## 5. Users API

Module base:

```text
https://dns.watchtower247.in/router_login/api/users/v1
```

### 5.1 List Users

```http
GET /users/v1?limit=100
```

Response key: `users`.

### 5.2 Get User Profile

```http
GET /users/v1/{emp_id}
```

Response key: `user`.

Includes available presence rows.

## 6. Groups API

Module base:

```text
https://dns.watchtower247.in/router_login/api/groups/v1
```

### 6.1 List Groups

```http
GET /groups/v1?limit=100
```

Response key: `groups`.

### 6.2 Get Group Detail

```http
GET /groups/v1/{group_id}
```

Response key: `group`.

Includes `members`.

### 6.3 Create Group

```http
POST /groups/v1
```

Body:

```json
{
  "name": "External Portal Test Group",
  "description": "Created through external API",
  "member_emp_ids": [302, 116],
  "owner_emp_id": 302
}
```

### 6.4 Update Group

```http
PATCH /groups/v1/{group_id}
```

Body fields can include:

```json
{
  "room_name": "Updated Group Name",
  "description": "Updated description",
  "status": "Open",
  "priority": "Normal",
  "target_date": "2026-07-31 18:00:00",
  "next_action_text": "Follow up with customer",
  "next_action_persons": "Ajith P",
  "next_action_date": "2026-07-25 10:00:00",
  "wakeup_enabled": 1,
  "wakeup_interval_minutes": 1440,
  "is_archived": 0
}
```

### 6.5 Delete/Archive Group

```http
DELETE /groups/v1/{group_id}
```

This archives/marks the group deleted instead of hard deleting.

### 6.6 List Members

```http
GET /groups/v1/{group_id}/members
```

### 6.7 Add Members

```http
POST /groups/v1/{group_id}/members
```

Body:

```json
{
  "emp_ids": [302, 116],
  "role": "member",
  "show_old_messages": false
}
```

If `show_old_messages` is false, member history starts from join time.

### 6.8 Remove Member

```http
DELETE /groups/v1/{group_id}/members/{emp_id}
```

### 6.9 Promote Member To Admin

```http
POST /groups/v1/{group_id}/members/{emp_id}/promote
```

### 6.10 Get Wake-Up Config

```http
GET /groups/v1/{group_id}/wakeup
```

Returns next wake-up estimate where available.

### 6.11 Update Wake-Up Config

```http
POST /groups/v1/{group_id}/wakeup
```

Body:

```json
{
  "enabled": 1,
  "interval_minutes": 1440
}
```

### 6.12 Request External User Add

```http
POST /groups/v1/{group_id}/external-users
```

Body:

```json
{
  "display_name": "External Customer",
  "email": "customer@example.com",
  "phone": "9999999999",
  "whatsapp_number": "9999999999",
  "telegram_username": "external_customer",
  "delivery_channels": ["email", "whatsapp"]
}
```

Creates a pending approval request.

### 6.13 Group AI Access

```http
GET /groups/v1/{group_id}/ai
POST /groups/v1/{group_id}/ai
```

POST body:

```json
{
  "ai_key_id": 1,
  "enabled": 1,
  "daily_tokens": 10000,
  "daily_searches": 100
}
```

## 7. Channels API

Module base:

```text
https://dns.watchtower247.in/router_login/api/channels/v1
```

Channels support the same structure as groups, plus channel-specific fields.

### 7.1 List Channels

```http
GET /channels/v1?limit=100
```

### 7.2 Get Channel Detail

```http
GET /channels/v1/{channel_id}
```

### 7.3 Create Channel

```http
POST /channels/v1
```

Body:

```json
{
  "name": "Flow Rollout",
  "description": "Channel purpose and operating context",
  "channel_type": "task",
  "member_emp_ids": [302, 116],
  "owner_emp_id": 302,
  "priority": "Normal"
}
```

`channel_type` is the preferred field. `channel_kind`, `type_key`, and `kind` are accepted as backward-compatible aliases. Standard channel types (`incident`, `action`, `operational`, `project`, `announcement`) appear under Channels; custom types such as `task` are preserved and appear under Workspace.

### 7.4 Update Channel

```http
PATCH /channels/v1/{channel_id}
```

Body can include:

```json
{
  "room_name": "Updated Channel Name",
  "description": "Updated channel purpose",
  "channel_type": "incident",
  "status": "Open",
  "priority": "High",
  "next_action_text": "Complete rollout checklist",
  "next_action_persons": "Ajith P",
  "next_action_date": "2026-07-25 10:00:00"
}
```

### 7.5 Channel Members, Wake-Up, External Users, AI

Same route pattern as groups:

```http
GET /channels/v1/{channel_id}/members
POST /channels/v1/{channel_id}/members
DELETE /channels/v1/{channel_id}/members/{emp_id}
POST /channels/v1/{channel_id}/members/{emp_id}/promote
GET /channels/v1/{channel_id}/wakeup
POST /channels/v1/{channel_id}/wakeup
POST /channels/v1/{channel_id}/external-users
GET /channels/v1/{channel_id}/ai
POST /channels/v1/{channel_id}/ai
POST /channels/v1/{channel_id}/close
POST /channels/v1/{channel_id}/archive
POST /channels/v1/{channel_id}/unarchive
DELETE /channels/v1/{channel_id}
```

### 7.6 Close, Archive, And Reopen Channel

Close marks a channel operationally closed and archives it from active lists:

```http
POST /channels/v1/{channel_id}/close
```

Archive hides a channel from active lists without using the closed status:

```http
POST /channels/v1/{channel_id}/archive
```

Unarchive restores the channel to active/open state:

```http
POST /channels/v1/{channel_id}/unarchive
```

Responses include `id`, `action`, `is_archived`, and `status`.

`DELETE /channels/v1/{channel_id}` is retained as a compatibility soft-delete/archive endpoint.

## 8. Tasks API

Module base:

```text
https://dns.watchtower247.in/router_login/api/tasks/v1
```

### 8.1 List Tasks

```http
GET /tasks/v1?limit=100
```

### 8.2 Get Task Detail

```http
GET /tasks/v1/{task_id}
```

### 8.3 Create Task

```http
POST /tasks/v1
```

Body:

```json
{
  "title": "Follow up with customer",
  "description": "Call before 5 PM",
  "priority": "high",
  "assignees": [302],
  "followers": [116],
  "task_groups": "99",
  "task_type": "general",
  "deadline": "2026-07-24 17:00:00",
  "meet_type": "1",
  "status": 2,
  "next_followup_date": "2026-07-25",
  "vertical": "Operations"
}
```

Defaults follow Flow legacy task rules when optional fields are missing.

### 8.4 Add Task Update

```http
POST /tasks/v1/{task_id}/updates
```

Body:

```json
{
  "comments": "Customer requested update tomorrow."
}
```

## 9. Reminders And Follow-Ups API

Module base:

```text
https://dns.watchtower247.in/router_login/api/reminders/v1
```

### 9.1 List Reminders

```http
GET /reminders/v1
```

### 9.2 Create Reminder Or Follow-Up

```http
POST /reminders/v1
```

Body:

```json
{
  "kind": "reminder",
  "title": "Call customer",
  "notes": "Follow up for payment confirmation",
  "assignee_emp_ids": [302, 116],
  "starts_at": "2026-07-24 16:00:00",
  "recurrence_type": "once"
}
```

For follow-up:

```json
{
  "kind": "followup",
  "title": "Project status follow-up",
  "starts_at": "2026-07-25 10:00:00"
}
```

## 10. Notifications API

Module base:

```text
https://dns.watchtower247.in/router_login/api/notifications/v1
```

### 10.1 Send System Notification

```http
POST /notifications/v1
```

Body:

```json
{
  "recipient_emp_id": 302,
  "event_type": "external_alert",
  "reference_id": "portal-1001",
  "title": "Portal Alert",
  "body": "A new approval is waiting."
}
```

## 11. Files API

Module base:

```text
https://dns.watchtower247.in/router_login/api/files/v1
```

### 11.1 List File Messages

```http
GET /files/v1?limit=100
```

Response key: `files`.

### 11.2 Upload File As Message

```http
POST /files/v1
```

Body:

```json
{
  "to_jid": "116@chat.skylinkonline.net",
  "file_name": "report.pdf",
  "file_type": "application/pdf",
  "file_base64": "JVBERi0x...",
  "caption": "Monthly report",
  "restricted": 0,
  "message_type": "file"
}
```

For restricted files:

```json
{
  "to_jid": "channel-flowrollout-f5e7be47@conference.chat.skylinkonline.net",
  "file_name": "confidential.xlsx",
  "file_type": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
  "file_base64": "UEsDB...",
  "caption": "Restricted report",
  "restricted": 1
}
```

Current transport is base64 JSON. Multipart can be added later without changing the route name.

## 12. Saved Messages API

Module base:

```text
https://dns.watchtower247.in/router_login/api/saved/v1
```

### 12.1 List Saved Messages

```http
GET /saved/v1
```

### 12.2 Create Saved Message

```http
POST /saved/v1
```

Body:

```json
{
  "body": "Private note for myself",
  "file_url": null,
  "file_name": null,
  "file_type": null
}
```

## 13. Global Search API

Module base:

```text
https://dns.watchtower247.in/router_login/api/search/v1
```

### 13.1 Search All Messages

```http
GET /search/v1?q=attachment
```

Response key: `results`.

## 14. Storage API

Module base:

```text
https://dns.watchtower247.in/router_login/api/storage/v1
```

### 14.1 Get User Storage

```http
GET /storage/v1?emp_id=302
```

or

```http
GET /storage/v1/302
```

Response key: `storage`.

### 14.2 Update User Storage Limit

```http
PATCH /storage/v1/{emp_id}
```

Body:

```json
{
  "limit_mb": 2048
}
```

## 15. Location API

Module base:

```text
https://dns.watchtower247.in/router_login/api/location/v1
```

### 15.1 List Location Records

```http
GET /location/v1?limit=100
```

### 15.2 Update User Location

```http
POST /location/v1
```

Body:

```json
{
  "emp_id": 302,
  "latitude": 13.0649727,
  "longitude": 80.1396886,
  "address": "Chennai, Tamil Nadu, India",
  "source": "external_api"
}
```

## 16. Attendance API

Module base:

```text
https://dns.watchtower247.in/router_login/api/attendance/v1
```

### 16.1 List External Attendance Events

```http
GET /attendance/v1?limit=100
```

### 16.2 Create Punch Event

```http
POST /attendance/v1
```

Body:

```json
{
  "emp_id": 302,
  "event_type": "punch_in",
  "latitude": 13.0649727,
  "longitude": 80.1396886,
  "address": "Chennai, Tamil Nadu, India"
}
```

Supported `event_type` examples:

```text
punch_in, punch_out, break_start, break_end
```

Note: this endpoint stores external events in `flow_api_attendance_events`. Mapping to legacy attendance tables can be done when live table rules are finalized.

## 17. Releases API

Module base:

```text
https://dns.watchtower247.in/router_login/api/releases/v1
```

### 17.1 List Releases

```http
GET /releases/v1?limit=100
```

### 17.2 Create Draft Release

```http
POST /releases/v1
```

Body:

```json
{
  "platform": "android",
  "version": "2.0.5",
  "build_number": 28,
  "artifact_url": "https://dns.watchtower247.in/router_login/downloads/Skylink-Chat-v2.0.5.apk",
  "notes": "External release draft"
}
```

### 17.3 Approve Release

```http
POST /releases/v1/{release_id}/approve
```

### 17.4 Rollback Release

```http
POST /releases/v1/{release_id}/rollback
```

## 18. Diagnostics API

Module base:

```text
https://dns.watchtower247.in/router_login/api/diagnostics/v1
```

### 18.1 List Diagnostics

```http
GET /diagnostics/v1?limit=100
```

Response key: `diagnostics`.

## 19. AI API

Module base:

```text
https://dns.watchtower247.in/router_login/api/ai/v1
```

### 19.1 List AI Keys

```http
GET /ai/v1
```

Response key: `ai_keys`.

Only masked API keys are returned.

### 19.2 Create AI Key

```http
POST /ai/v1
```

Body:

```json
{
  "title": "Open Router API",
  "ai_name": "custom",
  "model": "auto",
  "endpoint": "https://openrouter.ai/api/v1/chat/completions",
  "api_key": "sk-or-REPLACE_WITH_REAL_KEY",
  "other_details": "Used for Flow channel AI",
  "status": 1
}
```

The raw key is not returned by the API.

## 20. External Users API

Module base:

```text
https://dns.watchtower247.in/router_login/api/external-users/v1
```

### 20.1 List External User Requests

```http
GET /external-users/v1
```

Response key: `requests`.

### 20.2 Approve External User Request

```http
POST /external-users/v1/{request_id}/approve
```

Approving creates an `external_contacts` record and links it to the group/channel.

External user add request is created from group/channel route:

```http
POST /groups/v1/{group_id}/external-users
POST /channels/v1/{channel_id}/external-users
```

## 21. Poll API

Module base:

```text
https://dns.watchtower247.in/router_login/api/polls/v1
```

### 21.1 Create Poll Message

```http
POST /polls/v1
```

Body:

```json
{
  "to_jid": "channel-flowrollout-f5e7be47@conference.chat.skylinkonline.net",
  "payload": {
    "question": "Trip pogalam ah?",
    "allow_multiple": false,
    "options": [
      {"text": "yes"},
      {"text": "no"},
      {"text": "try"}
    ]
  }
}
```

The API stores a Flow poll payload message with `SKYLINK_POLL:` prefix.

## 22. Checklist API

Module base:

```text
https://dns.watchtower247.in/router_login/api/checklists/v1
```

### 22.1 Create Checklist Message

```http
POST /checklists/v1
```

Body:

```json
{
  "to_jid": "channel-flowrollout-f5e7be47@conference.chat.skylinkonline.net",
  "payload": {
    "title": "Today work flow",
    "items": [
      {"text": "apk build"},
      {"text": "web build"},
      {"text": "windows build"}
    ]
  }
}
```

The API stores a Flow checklist payload message with `SKYLINKCHECKLIST:` prefix.

## 23. Postman Setup

Recommended collection variables:

| Variable | Value |
| --- | --- |
| `base_url` | `https://dns.watchtower247.in/router_login/api` |
| `api_key` | your external API key |
| `actor_emp_id` | `302` |
| `user_jid` | `116@chat.skylinkonline.net` |
| `room_jid` | channel/group JID |

Default headers:

```http
Authorization: Bearer {{api_key}}
X-Flow-Actor-Emp-Id: {{actor_emp_id}}
Content-Type: application/json
```

Example request URL:

```text
{{base_url}}/chat/v1/messages?jid={{user_jid}}&limit=50
```

## 24. Security Notes

- Do not share production API keys in screenshots or documentation.
- Use limited scopes for external portals instead of `*` once integration is stable.
- Rotate API keys if exposed.
- All actions are designed to be auditable through `flow_api_audit_logs`.
- Destructive operations such as delete/archive should be restricted to trusted integration clients.

## 25. Current Implementation Notes

- External APIs are isolated under `/api` and do not replace existing `/chat` app APIs.
- Existing Flutter app behavior should remain unchanged.
- File upload uses base64 JSON in this version.
- Attendance currently stores external punch events separately until legacy attendance mapping is finalized.
- API keys are hashed; raw keys cannot be recovered from the database.
