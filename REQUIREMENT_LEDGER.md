
## REQ-20260715-BUILD-APK-WEB
- Date: 2026-07-15
- Request: Generate web and Android APK release builds; upload APK to live server as Draft.
- Status: Completed
- Owner approval required for live rollout: Employee ID 302

## REQ-20260715-GROUP-ADMIN-PROMOTION
- Date: 2026-07-15
- Request: Add promote-to-admin option for group/channel members; admins can add/remove members and rename group/channel like owners.
- Status: Implemented in UI/API/backend patch; build not requested.


## REQ-20260715-CHAT-BOTTOM-SCROLL
- Date: 2026-07-15
- Request: Chat should open at latest message; jump-to-bottom button should work; text selection should not drag chat to bottom.
- Status: Implemented; build not requested.


## REQ-20260715-CHAT-LATEST-INITIAL-RENDER
- Date: 2026-07-15
- Request: Chat must open at bottom by default without auto-scroll side effects; selecting message text must not jump to bottom.
- Status: Implemented; build not requested.


## 2026-07-15 18:20:41 +05:30 - Poll edit, task notifications, Saved Messages attach menu
- Requirement: Poll edit must show structured poll fields instead of raw SKYLINK_POLL JSON.
- Requirement: Task create/update from chat must notify created-by, assignees, and followers through System Notifications with task metadata.
- Requirement: Saved Messages attachment icon must show chat-style attachment choices before opening file picker.
- Status: Implemented in Flutter UI and PHP server_patch files.


## 2026-07-16 10:39:38 +05:30 - Location address display
- Requirement: Message Info and profile Latest location must show readable address instead of raw latitude/longitude where location visibility allows it.
- Status: Implemented frontend address resolution and profile API mapping fix.


## 2026-07-16 11:03:55 +05:30 - Checklist and poll editing/detail visibility
- Requirement: Checklist edit must allow adding/removing individual fields with a plus button instead of one large textarea.
- Requirement: Poll edit must allow adding/removing individual options with a plus button.
- Requirement: Checklist/poll creator must see who checked each item and who voted for each option.
- Status: Implemented.



## REQ-20260716-ATTACHMENT-RESTRICTED
- Date: 2026-07-16 11:42:08
- Request: Add Restricted checkbox while sending images/files. Restricted attachments must preview only inside Flow with no download/open-with. Unrestricted attachments must allow download and external open-with.
- Status: Implemented, pending build/release.


## REQ-20260716-SAVED-FORWARD-PASTE
- Date: 2026-07-16 11:56:28
- Request: Forward message target picker must show Saved Messages. Saved Messages on Windows must support copy/paste workflow better.
- Status: Implemented, pending build/release.


## REQ-20260716-CHAT-SELECTION-SCROLL-LOCK
- Date: 2026-07-16 12:06:05
- Request: Chat must open directly at the latest/bottom message without a visible auto-scroll, and selecting text/message content must not push that message to the bottom.
- Status: Implemented, pending runtime verification/build.


## REQ-20260716-DESKTOP-PANEL-BUBBLE-WIDTH
- Date: 2026-07-16 12:12:05
- Request: Desktop right profile panel must not auto-open on every chat open; it should open only when profile/header is clicked. Message bubbles should shrink to content width like WhatsApp/Telegram instead of stretching full chat width.
- Status: Implemented, pending build/release.


## REQ-20260716-MULTIPLATFORM-DRAFT-BUILD
- Date: 2026-07-16 13:20:24
- Request: Build Web, APK, and Windows installer, upload all to live server, and keep them as Draft for approval.
- Status: Completed.


## REQ-20260716-STANDALONE-FLOW-MASTER-ADMIN
- Date: 2026-07-16 15:34:05 +05:30
- Request: Rework admin/ as standalone PHP master admin web app at /admin, outside /chat, with local frontend/backend/config helpers, same employee login, and super-admin-only full control for 302 and 116.
- Status: Implemented; no build/release requested.

## REQ-20260720-C1C2-CREATE-BLOCK
- Date: 2026-07-20
- Request: C1 and C2 employee type users must not be allowed to create groups or channels.
- Status: Implemented and backend deployed.
