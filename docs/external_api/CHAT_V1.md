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
| POST | `/messages` | `chat:send` | Send text/location/checklist/poll/contact message |
| PATCH | `/messages/{message_id}` | `chat:send` | Edit message |
| DELETE | `/messages/{message_id}` | `chat:send` | Delete/unsend message |
| GET | `/messages/{message_id}` | `chat:read` | Message info |
| POST | `/messages/{message_id}/actions` | `chat:send` | Star, pin, react |
| GET | `/messages/search` | `chat:read` | Global/user-visible message search |
| GET | `/saved-messages` | `chat:read` | Saved messages |
| POST | `/saved-messages` | `chat:send` | Save text/file message |

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

## Send Group Or Channel Message

```json
{
  "to_jid": "channel-flowrollout-f5e7be47@conference.chat.skylinkonline.net",
  "body": "Channel update from external portal",
  "message_type": "groupchat",
  "client_message_id": "crm-channel-1001"
}
```

If `message_type` is omitted for a room JID, Flow stores it as `groupchat` automatically.

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

