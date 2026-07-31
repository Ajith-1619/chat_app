# Chat API v1

Base:

```text
/api/chat/v1
```

## Endpoints

| Method | Path | Scope | Description |
| --- | --- | --- | --- |
| GET | `/conversations` | `chat:read` | Recent conversations visible to the actor |
| GET | `/conversations/{jid}/messages` | `chat:read` | Chat history |
| POST | `/messages` | `chat:write` | Send text/location/checklist/poll/contact message |
| POST | `/direct/messages` | `chat:write` | Send one-to-one direct message by employee ID |
| GET | `/direct/messages?recipient_emp_id={emp_id}` | `chat:read` | Fetch one-to-one direct message history by employee ID |
| PATCH | `/messages/{message_id}` | `chat:write` | Edit message |
| DELETE | `/messages/{message_id}` | `chat:write` | Delete/unsend message |
| GET | `/messages/{message_id}` | `chat:read` | Message info |
| POST | `/messages/{message_id}/actions` | `chat:write` | Star, pin, react |
| GET | `/messages/search` | `chat:read` | Global/user-visible message search |
| GET | `/saved-messages` | `chat:read` | Saved messages |
| POST | `/saved-messages` | `chat:write` | Save text/file message |

## Send Message

```http
POST /api/chat/v1/messages
```

The same endpoint sends direct, group, and channel messages. For direct messages pass a user JID. For group/channel messages pass the room JID from the group/channel profile.

```json
{
  "to_jid": "302@chat.skylinkonline.net",
  "body": "Hello from external portal",
  "message_type": "chat",
  "reply_to_id": 0,
  "thread_root_id": 0,
  "mentions": [],
  "send_latitude": 13.06,
  "send_longitude": 80.18,
  "send_address": "Chennai, Tamil Nadu"
}
```


## Send One-to-One Message By Employee ID

```http
POST /api/chat/v1/direct/messages
Authorization: Bearer <api_key>
Content-Type: application/json
```

This endpoint is for external portals that do not want to build JIDs manually. Flow resolves employee IDs to `{emp_id}@chat.skylinkonline.net` and stores a normal direct chat message.

```json
{
  "sender_emp_id": 302,
  "recipient_emp_id": 116,
  "body": "Hi from external portal",
  "source_name": "External Portal",
  "client_message_id": "portal-dm-1001"
}
```

`sender_emp_id` is optional. If omitted, Flow uses `X-Flow-Actor-Emp-Id` or the API client owner.

Fetch the one-to-one history:

```http
GET /api/chat/v1/direct/messages?recipient_emp_id=116&sender_emp_id=302&limit=50
Authorization: Bearer <api_key>
```

Response key: `messages`.
## Send Group Or Channel Message

```json
{
  "from_jid": "302@chat.skylinkonline.net",
  "to_jid": "channel-flowrollout-f5e7be47@conference.chat.skylinkonline.net",
  "body": "Channel update from external portal",
  "message_type": "groupchat",
  "client_message_id": "crm-channel-1001"
}
```

If `message_type` is omitted for a room JID, Flow stores it as `groupchat` automatically. `from_jid` or `sender_emp_id` can be supplied by external portals; if omitted, Flow uses the API key owner/actor.

## Group/Channel Selected Send

```json
{
  "to_jid": "channel-flow@conference.chat.skylinkonline.net",
  "body": "Restricted update",
  "visibility_mode": "selected",
  "recipient_emp_ids": [302, 116]
}
```

## Message Types

```text
text
file
image
voice
contact
checklist
poll
current_location
live_location
system
```

## Notes

- Location metadata should be saved as message metadata, not converted into location-card messages unless explicit `current_location` or `live_location`.
- Restricted messages must not leak to recent chats, search, media, unread count, or message info.
- Channel hashtags are parsed from text messages and exposed in channel profile.


### 404 Troubleshooting

If `/api/chat/v1/direct/messages` returns HTTP 404 after deployment, upload the physical fallback route too:

```text
server_patch/api/chat/v1/direct/messages/index.php
-> /var/www/html/router_login/api/chat/v1/direct/messages/index.php
```

This fallback is useful when Apache `.htaccess` rewrite or `PATH_INFO` forwarding is not enabled on the server.
## Direct Physical Endpoint Fallback

If the pretty route `/api/chat/v1/direct/messages` is still handled by an older server route, use this rewrite-independent physical endpoint:

```http
POST /api/chat/v1/direct_send.php
Authorization: Bearer <api_key>
Content-Type: application/json
```

```json
{
  "sender_emp_id": "302",
  "recipient_emp_id": "307",
  "body": "Hi from external portal",
  "source_name": "External Portal",
  "client_message_id": "portal-dm-12345678"
}
```

Upload:

```text
server_patch/api/chat/v1/direct_send.php
-> /var/www/html/router_login/api/chat/v1/direct_send.php
```

Validation errors from this file include `debug.handler = physical_direct_send_v1`.