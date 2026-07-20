
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


## CHG-20260716-MULTIPLATFORM-DRAFT-BUILD
- Date: 2026-07-16 13:20:24
- Files: server_patch/register_draft_2_0_4.php, tool/package_windows_installer.ps1, tool/deploy_2_0_4.ps1, tool/deploy_2_0_4.psftp, tool/verify_2_0_4_upload.ps1, BUILD_REPORT_2026-07-16_v2.0.4.md
- Change: Generated v2.0.4 web/APK/Windows artifacts, updated draft registration to cover android/windows/web, added deployment/verification scripts, and hardened Windows installer packaging wait logic.


## CHG-20260716-STANDALONE-FLOW-MASTER-ADMIN
- Date: 2026-07-16 15:34:05 +05:30
- Files: admin/_bootstrap.php, admin/index.php, admin/api.php, admin/app.js, admin/app.css, admin/health.php, admin/logout.php, admin/admin_config.sample.php, .gitignore
- Change: Removed dependency on chat/bootstrap.php, added local admin config/auth/session/DB helpers, Ejabberd check_password login, secure sessions, CSRF, login rate limiting, audit log schema, dashboard APIs, and audited full-control actions.
- Validation: PHP syntax lint passed for admin PHP files. No web/APK/Windows build run.


## CHG-20260716-ADMIN-LOGIN-CONFIG-FALLBACK
- Date: 2026-07-16 16:00:54 +05:30
- Files: admin/_bootstrap.php, admin/bootstrap.php
- Change: Admin login now auto-loads existing /router_login/config.php and /router_login/db.php when admin_config.php is absent, uses legacy DB helpers when available, and shows a clear missing Ejabberd credential error instead of a generic invalid login. Added bootstrap.php compatibility wrapper for deployments that uploaded that filename.
- Validation: PHP lint passed for admin bootstrap/index/api/health and compatibility wrapper.


## CHG-20260716-ADMIN-STRICT-STANDALONE-CONFIG
- Date: 2026-07-16 16:12:53 +05:30
- Files: admin/_bootstrap.php, admin/admin_config.php, admin/admin_config.sample.php
- Change: Removed all fallback/loading from /router_login, DOCUMENT_ROOT, environment constants, and external DB helpers. Admin now reads only admin/admin_config.php and admin-folder files. Added local admin_config.php placeholder file for live server values.
- Validation: rg found no router_login/getDB/SKYCHAT external helper references in admin PHP files; PHP lint passed for all admin PHP files.


## CHG-20260716-ADMIN-AUTH-DB-FALLBACK
- Date: 2026-07-16 16:26:58 +05:30
- Files: admin/_bootstrap.php
- Change: Standalone admin login now reports detailed auth failure reasons and falls back to local chat DB xmpp_users.xmpp_password for super-admin authentication when Ejabberd admin API credentials are missing/placeholder or check_password rejects. No external router_login files are used.
- Validation: PHP lint passed for all admin PHP files.


## CHG-20260716-ADMIN-REAL-CONFIG-UPLOAD
- Date: 2026-07-16 17:19:02 +05:30
- Files: admin/admin_config.php and admin/* deployed to /var/www/html/admin
- Change: Generated standalone admin_config.php from the existing live chat config without printing secrets. Created /var/www/html/admin on live server and uploaded the full standalone admin app folder.
- Validation: Local PHP lint passed for admin_config.php. SFTP upload succeeded. HTTP health check from local machine could not connect to chat.skylinkonline.net.


## CHG-20260716-ADMIN-USERS-OVERVIEW-CLEANUP
- Date: 2026-07-16 17:33:01 +05:30
- Files: admin/api.php, admin/app.js
- Change: Admin Users view now discovers employee table and columns adaptively instead of assuming employee.name/status. Overview no longer renders Recent Messages section.
- Validation: PHP lint passed for admin/api.php before upload. Uploaded api.php and app.js to /var/www/html/admin.


## CHG-20260716-ADMIN-LIVE-USERS-PASSWORDS
- Date: 2026-07-16 17:45:16 +05:30
- Files: admin/api.php, admin/app.js
- Change: Users tab now lists live chat users from xmpp_users instead of employee/autodetected user tables, includes username/JID and stored password, joins employee profile details when available, and adds an audited Edit Password action that updates xmpp_users and attempts Ejabberd password sync.
- Validation: PHP lint passed for admin/api.php. Uploaded api.php and app.js to /var/www/html/admin.


## CHG-20260716-ADMIN-LIVE-DB-DETECTION-FIX
- Date: 2026-07-16 17:54:41 +05:30
- Files: admin/admin_config.php, admin/_bootstrap.php, admin/api.php, admin/app.js
- Change: Pointed standalone admin chat database to the live radius schema, changed table existence detection from SHOW TABLES LIKE parameter binding to INFORMATION_SCHEMA, and verified live counts: 73 users and 11422 messages. Users tab lists xmpp_users with edit-password action.
- Validation: PHP lint passed for admin/_bootstrap.php and admin/api.php. Live server temp verification returned table=yes, 73 users, 11422 messages.

## CHG-20260716-ADMIN-GROUP-CHANNEL-USERS
- Time: 2026-07-16 18:15:28
- Admin Users: removed Department from displayed/API payload and kept live chat username/password edit flow.
- Admin Overview: changed Users metric to live xmpp_users count and kept Groups/Channels split counts.
- Admin Navigation: split Groups and Channels into separate side-nav views.
- Admin Controls: added View/Edit action for group/channel name, channel kind, wake-up state, and archive state.
- Deployment: uploaded index.php, api.php, and app.js to /var/www/html/admin.


## CHG-20260716-ADMIN-GROUP-CHANNEL-FUNCTION-FIX
- Time: 2026-07-16 18:20:59
- Fixed undefined admin_groups_or_channels() route error by renaming the list function and applying group/channel type filtering.
- Uploaded corrected admin/api.php to /var/www/html/admin.


## CHANGE-20260720-C1C2-GROUP-CHANNEL-CREATE-BLOCK
- Date: 2026-07-20
- Files: lib/home/home_screen.dart, server_patch/chat/bootstrap.php, server_patch/chat/create_group.php, server_patch/chat/create_channel.php, server_patch/chat/profile.php
- Change: Added normalized employee type lookup with admin override support, backend guards for group/channel creation, profile employee_type normalization, and UI create-entry guard.
- Risk: Low; creation flow only. Existing group/channel membership and chat history logic unchanged.
- Deployment: Uploaded backend patch files to /var/www/html/router_login/chat/ and verified PHP syntax on server.
