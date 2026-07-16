
## CHANGE-20260715-V2.0.4-BUILD
- Date: 2026-07-15
- Changed: Bumped app version from 2.0.3+26 to 2.0.4+27.
- Generated: release/Skylink-Chat-v2.0.4.apk and release/Skylink-Chat-Web-v2.0.4.zip with SHA256 files.
- Server: Uploaded Android APK and SHA256 to /var/www/html/router_login/downloads/.
- Server: Uploaded register_draft_2_0_4.php and registered Android draft release_id=29.

## CHANGE-20260715-GROUP-ADMIN-PERMISSIONS
- Date: 2026-07-15
- Changed: Desktop right panel member list now exposes owner-only Promote/Demote and owner/admin Remove actions.
- Changed: Manage members bottom sheet now exposes owner-only Promote/Demote and owner/admin Remove actions.
- Changed: groupMemberAction supports direct web helper path for promote/demote/remove parity.
- Changed: rename_group.php allows owner/admin rename instead of owner-only.


### Follow-up Permission Polish
- Date: 2026-07-15
- Chat info member actions now hide admin-to-admin removal/promote choices; admins only manage ordinary members while owners can promote/demote.


## CHANGE-20260715-CHAT-BOTTOM-SCROLL
- Date: 2026-07-15
- Changed: Initial chat history load now forces an instant scroll to latest after the message list attaches.
- Changed: Jump-to-latest button now forces bottom scroll and clears new-message count even when browser text selection is active.
- Changed: Auto-scroll still respects active text selection so selecting message text does not move the chat.


## CHANGE-20260715-CHAT-LATEST-INITIAL-RENDER
- Date: 2026-07-15
- Root cause: Chat list rendered from index 0 and then used delayed forced scroll-to-bottom; that pending forced scroll could fire during text selection and move the chat to bottom.
- Changed: ScrollablePositionedList now starts at the latest message using initialScrollIndex/initialAlignment.
- Changed: Removed first-load forced scroll; explicit jump-to-latest button remains force-scroll.


## 2026-07-15 18:20:41 +05:30
- Changed lib/chat/chat_screen.dart: added _editPollMessage and routed poll messages away from generic text edit dialog.
- Changed lib/home/home_screen.dart: Saved Messages attach button now opens an option sheet before file picker.
- Changed server_patch/chat/myhub.php: task creation now dispatches non-blocking System Notifications to involved users.
- Changed server_patch/chat/task_update.php: task updates now dispatch non-blocking System Notifications to involved users.


## 2026-07-16 10:39:38 +05:30
- Changed lib/chat_api.dart: UserProfile.fromJson now preserves latest_location_address and latest_location_at from backend.
- Changed lib/chat/chat_screen.dart: Message Info resolves coordinate-only send/read location fields through reverse geocode before display, including reader rows.


## 2026-07-16 11:03:55 +05:30
- Changed lib/chat/chat_screen.dart: checklist/poll edit dialogs now use dynamic per-item/per-option fields with add/remove controls and preserve existing state/votes.
- Changed lib/attachments/attachment_widgets.dart: LiveChecklistCard and LivePollCard can show creator-only participant details.
- Changed server_patch/chat/checklist_toggle.php: checklist toggles now maintain checked_by employee ID history for display.



## CHG-20260716-ATTACHMENT-RESTRICTED
- Date: 2026-07-16 11:42:08
- Files: lib/chat_api.dart, lib/chat/chat_screen.dart, lib/attachments/attachment_widgets.dart, server_patch/chat/bootstrap.php, server_patch/chat/send_message.php, server_patch/chat/history.php, server_patch/chat/media.php
- Change: Added file_restricted metadata, send dialog Restricted checkbox, app-only restricted preview behavior, hidden restricted download/open-with actions, unrestricted file action menu, and server download blocking through media.php.
- Risk: Server raw uploads may still need web-server protection if users manually access direct upload URLs outside media.php.


## CHG-20260716-SAVED-FORWARD-PASTE
- Date: 2026-07-16 11:56:28
- Files: lib/chat/chat_screen.dart, lib/home/home_screen.dart
- Change: Forward sheet now includes Saved Messages and routes selected forwards to chatApi.saveMessage. SavedMessagesScreen now registers clipboard media paste, supports desktop file drop, multiple file saving, explicit Ctrl/Cmd+V text paste, and avoids double-saving checklist/poll notes.
- Risk: Native Windows file clipboard paste is limited by Flutter/OS clipboard APIs; drag/drop and text paste are supported with existing packages.


## CHG-20260716-CHAT-SELECTION-SCROLL-LOCK
- Date: 2026-07-16 12:06:05
- File: lib/chat/chat_screen.dart
- Change: Added selection viewport anchoring. When text selection starts, the first visible item index/alignment is captured and restored for several short frames, preventing Flutter selection ensure-visible from moving the selected message to the bottom. Initial chat list alignment changed to 1.0 so chat opens at the latest message directly.


## CHG-20260716-DESKTOP-PANEL-BUBBLE-WIDTH
- Date: 2026-07-16 12:12:05
- Files: lib/home/home_screen.dart, lib/chat/chat_screen.dart
- Change: Default desktop profile panel state changed to closed; opening a chat now keeps profile closed and existing onProfileTap opens it. Chat message bubble max width is capped for desktop and wrapped with IntrinsicWidth plus min-size column so simple text bubbles shrink closer to content width.
