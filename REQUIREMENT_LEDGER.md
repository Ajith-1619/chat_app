
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

## 2026-07-22 11:59:29 - Channel Description And Next Action Intelligence
- Requirement: Add channel description during create/edit, show it in the channel profile panel, and include it in @ai channel context.
- Requirement: Track Next Actions, Next Action Persons, and Next Action Date from channel chat messages and show them in the right-side panel.
- Change: Added xmpp_groups description/next-action schema migration fields and channel profile response fields.
- Change: Added channel update endpoint for owner/admin editable description/type/status/priority/next-action date.
- Change: Added post-send channel action extraction helper for task-like channel messages.
- Verification: PHP syntax checks passed for changed backend files. Dart format passed. Flutter/Dart analyze timed out in this workspace.

## 2026-07-22 16:13:54 - External Group/Channel Create API
- Requirement: External apps/portals must create Flow groups and channels without browser login session cookies.
- Change: Added API-key protected endpoint server_patch/chat/external_create_conversation.php for type=group/channel creation.
- Change: Added docs/external_conversation_create_api.md with Postman-ready request examples.
- Security: Supports Authorization Bearer, X-Skylink-Conversation-Key, X-Skylink-API-Key, and server-side key override via environment/config.
- Verification: PHP syntax check passed for external_create_conversation.php.

## 2026-07-22 16:27:15 - External Reminder/Follow-up Create API
- Requirement: External apps/portals must create Flow reminders and follow-ups without browser login session cookies.
- Change: Added API-key protected endpoint server_patch/chat/external_create_reminder.php for kind=reminder/followup creation.
- Change: Added docs/external_reminder_followup_api.md with Postman-ready request examples.
- Security: Supports Authorization Bearer, X-Skylink-Work-Key, X-Skylink-API-Key, and server-side key override via SKYLINK_WORK_API_KEY.
- Verification: PHP syntax check passed for external_create_reminder.php.

## 2026-07-22 16:46:39 - Channel Right Panel Metadata Visibility
- Requirement: Show channel description, editable details, Next Action, Next Action Persons, and Next Action Date in the right-side panel.
- Root Cause: Some channel/group records arrive in the UI as group previews, so channel-only checks hid metadata and edit controls even when channel profile data existed.
- Change: Updated lib/home/home_screen.dart to load channel profile metadata for group rooms and show channel detail cards whenever channel metadata is returned.
- Change: Added a local right-panel date picker helper and corrected rename dialog scoping after the visibility update.
- Verification: dart format passed. flutter analyze lib/home/home_screen.dart reports no errors; remaining items are existing warnings/infos.
- Build: Not run in this task.

## 2026-07-22 17:13:10 - Channel Right Panel Top Summary Visibility
- Requirement: Right-side panel must immediately show channel Description, Next Action, Next Action Person, and Next Action Date, with edit controls visible in the channel tools area.
- Root Cause: Channel metadata cards were placed below management/member details, so they were not visible in the first right-panel viewport.
- Change: Moved the important channel metadata summary directly below Search/Media in lib/home/home_screen.dart while keeping detailed cards lower in the panel.
- Verification: dart format passed. flutter analyze lib/home/home_screen.dart produced no errors; only existing warnings/infos remain.
- Build: flutter build web --release succeeded. Output: build/web.

## 2026-07-22 17:47:37 - Channel Next Action Detection, Description Profile, Selection Stability
- Requirement: Channel messages like @Ajith_P complete the Chat application task on tomorrow must update Next Action, Next Action Person, and Next Action Date.
- Requirement: Saved channel description must appear in the right-side panel after reload/save.
- Requirement: Selecting message text must not scroll/jump the chat window.
- Change: Relaxed channel detection in server_patch/chat/channel_action_helper.php to support channel-* JIDs and channel-kind records, not only group_type=channel.
- Change: Improved @mention matching for names like Ajith P / Ajith Kumar P using normalized name variants.
- Change: Relaxed channel profile/update endpoints to support channel-* JID records so description and metadata load consistently.
- Change: Removed forced scroll-anchor restore during browser text selection in lib/chat/chat_screen.dart.
- Verification: PHP syntax checks passed for channel_action_helper.php, channel_profile.php, update_channel.php, send_message.php. Flutter analyze on edited Dart files returned no errors, only existing warnings/infos.
- Build: flutter build web --release succeeded. Output: build/web.
