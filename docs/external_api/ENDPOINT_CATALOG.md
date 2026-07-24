# Flow External API Endpoint Catalogue

Date: 2026-07-24

This document maps the current internal Flow APIs and recommends stable external API paths.

Current internal base:

```text
https://chat.skylinkonline.net/router_login/chat/
```

Recommended external base:

```text
https://chat.skylinkonline.net/router_login/api/{module}/v1/
```

Examples:

```text
/api/chat/v1/messages
/api/users/v1/users
/api/groups/v1/groups
/api/channels/v1/channels
/api/tasks/v1/tasks
```

## Auth And Session

| Feature | Current Internal API | Method | External API | Scope |
| --- | --- | --- | --- | --- |
| Login | `login.php` | POST | Not recommended for external API | - |
| Current user | `current_user.php` | GET | `GET /me` | `users:read` |
| Profile | `profile.php` | GET/POST | `GET /me/profile` | `users:read` |
| Sessions | `sessions.php` | GET/POST | `GET /me/sessions` | `users:read` |

## Users

| Feature | Current Internal API | Method | External API | Scope |
| --- | --- | --- | --- | --- |
| Search users | `search_users.php` | GET | `GET /users?search=` | `users:read` |
| User profile | `user_profile.php?emp_id=` | GET | `GET /users/{emp_id}` | `users:read` |
| Presence | `presence.php?jid=` | GET | `GET /users/{emp_id}/presence` | `users:read` |
| Location visibility | `location_visibility.php` | GET/POST | `GET/POST /location-visibility` | `locations:read` |

## Chat

| Feature | Current Internal API | Method | External API | Scope |
| --- | --- | --- | --- | --- |
| Recent chats | `recent_chats.php` | GET | `GET /conversations` | `chat:read` |
| Chat history | `history.php?jid=` | GET | `GET /conversations/{jid}/messages` | `chat:read` |
| Send message | `send_message.php` | POST | `POST /messages` | `chat:send` |
| Send attachment | `upload_file.php` + `send_message.php` | POST | `POST /attachments` then `POST /messages` | `chat:attachments` |
| Delete/unsend | `delete_message.php` | POST | `POST /messages/{id}/delete` | `chat:send` |
| Edit message | `edit_message.php` | POST | `PATCH /messages/{id}` | `chat:send` |
| Message info | `message_action.php?message_id=` | GET | `GET /messages/{id}` | `chat:read` |
| Star/pin/react | `message_action.php` | POST | `POST /messages/{id}/actions` | `chat:send` |
| Media browser | `media.php` | GET | `GET /conversations/{jid}/media` | `chat:read` |
| Discovery/search | `discovery.php` | GET | `GET /search` | `chat:read` |
| Saved messages | `saved_messages.php` | GET/POST | `GET/POST /saved-messages` | `chat:read`, `chat:send` |

## Groups And Channels

| Feature | Current Internal API | Method | External API | Scope |
| --- | --- | --- | --- | --- |
| Create group | `create_group.php` | POST | `POST /groups` | `groups:write` |
| Create channel | `create_channel.php` | POST | `POST /channels` | `channels:write` |
| Group members | `group_members.php?group_id=` | GET | `GET /groups/{id}/members` | `groups:read` |
| Manage members | `manage_group.php` | POST | `POST /groups/{id}/members` | `groups:write` |
| Rename group | `rename_group.php` | POST | `PATCH /groups/{id}` | `groups:write` |
| Group profile | `group_profile.php` | POST | `PATCH /groups/{id}/profile` | `groups:write` |
| Channel profile | `channel_profile.php` | GET | `GET /channels/{id}` | `channels:read` |
| Update channel | `update_channel.php` | POST | `PATCH /channels/{id}` | `channels:write` |
| Close channel | `close_channel.php` | POST | `POST /channels/{id}/close` | `channels:write` |
| Archived channels | `archived_channels.php` | GET | `GET /channels/archived` | `channels:read` |
| Channel definitions | `channel_definitions.php` | GET | `GET /channel-definitions` | `channels:read` |
| Channel relationships | `channel_relationship.php` | GET/POST | `GET/POST /channel-relationships` | `channels:write` |
| Channel timeline | `channel_timeline.php` | GET | `GET /channels/{id}/timeline` | `channels:read` |
| Wake-up config | `wakeup_config.php` | GET/POST | `GET/PATCH /channels/{id}/wakeup` | `channels:write` |
| External user request | `external_user_request.php` | POST | `POST /external-user-requests` | `channels:write` |

## Tasks And MyHub

| Feature | Current Internal API | Method | External API | Scope |
| --- | --- | --- | --- | --- |
| Task list | `myhub.php?section=tasks` | GET | `GET /tasks` | `tasks:read` |
| Task detail | `myhub.php?section=task_detail&task_id=` | GET | `GET /tasks/{id}` | `tasks:read` |
| Create task | `myhub.php?section=task_create` | POST | `POST /tasks` | `tasks:write` |
| Update task | `task_update.php` | POST | `POST /tasks/{id}/updates` | `tasks:write` |
| Employee directory | `myhub.php?section=directory` | GET | `GET /employees` | `users:read` |
| Verticals | `myhub.php?section=verticals` | GET | `GET /verticals` | `tasks:read` |
| Leave list | `myhub.php?section=leave` | GET | `GET /leaves` | `attendance:read` |
| Leave apply | `myhub.php?section=leave_apply` | POST | `POST /leaves` | `attendance:read` |

## Reminders And Follow-Ups

| Feature | Current Internal API | Method | External API | Scope |
| --- | --- | --- | --- | --- |
| Reminder list | `reminders.php` | GET | `GET /reminders` | `reminders:read` |
| Create reminder | `reminders.php` | POST | `POST /reminders` | `reminders:write` |
| Create follow-up | `reminders.php` | POST | `POST /followups` | `reminders:write` |
| Stop reminder/follow-up | `reminders.php` | POST | `POST /reminders/{id}/stop` | `reminders:write` |

## Attendance And Location

| Feature | Current Internal API | Method | External API | Scope |
| --- | --- | --- | --- | --- |
| Attendance status | `attendance.php` | GET | `GET /attendance/me` | `attendance:read` |
| Punch in | `attendance.php` | POST | Not recommended for external v1 unless approved | `attendance:write` |
| Punch out | `attendance.php` | POST | Not recommended for external v1 unless approved | `attendance:write` |
| Location update | `location_update.php` | POST | `POST /locations` | `locations:write` |
| Reverse geocode | `reverse_geocode.php` | GET | `GET /locations/reverse-geocode` | `locations:read` |

## Notifications

| Feature | Current Internal API | Method | External API | Scope |
| --- | --- | --- | --- | --- |
| Notification feed | `notification_feed.php` | GET | `GET /notifications` | `notifications:send` |
| Send notification | `notification_send.php` | POST | `POST /notifications` | `notifications:send` |
| Register push token | `register_push_token.php` | POST | Not recommended for external API | - |

## Files And Storage

| Feature | Current Internal API | Method | External API | Scope |
| --- | --- | --- | --- | --- |
| Upload file | `upload_file.php` | POST multipart | `POST /files` | `chat:attachments` |
| Storage usage | `storage_usage.php` | GET | `GET /storage/me` | `chat:attachments` |
| Media list | `media.php` | GET | `GET /files` | `chat:read` |

## Release And Diagnostics

| Feature | Current Internal API | Method | External API | Scope |
| --- | --- | --- | --- | --- |
| Version | `version.php` | GET | `GET /version` | `releases:read` |
| Release notes | `release_notes.php` | GET/POST | `GET /release-notes` | `releases:read` |
| Releases | `releases.php` | GET/POST | `GET /releases` | `releases:read` |
| Diagnostics | `diagnostics.php` | GET/POST | `GET /diagnostics` | `diagnostics:read` |
| Ticket dashboard | `ticket_dashboard.php` | GET | `GET /tickets/dashboard` | `tasks:read` |

## External-Ready Endpoints Already Present

These files appear intended for external/portal integration and should be reviewed first:

```text
external_create_conversation.php
external_create_reminder.php
external_delivery_worker.php
external_user_request.php
notification_send.php
```

They still need the same consistent API-key auth and audit wrapper before becoming public platform APIs.


