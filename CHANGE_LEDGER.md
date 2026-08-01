
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

## 2026-07-21 - Saved Messages Download Action
- Added normal attachment download option to Saved Messages file/image bubbles and saved-message action menu using existing chat attachment download flow.

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

## 2026-07-22 16:54:24 - Web Build After Channel Right Panel Fix
- Requirement: Produce a web release build so Ajith can verify right-side channel description and next-action panel fixes.
- Build Command: flutter build web --release
- Output: build/web
- Result: Success.
- Verification: Flutter web release compilation completed successfully. No build-time errors reported.

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

## 2026-07-23 11:06:49 - Channel Metadata Runtime Fix And Web Build
- Requirement: Right-side panel must show saved channel description and automatically detected Next Action / Person / Date for messages such as @Ajith_P complete the chat application on tomorrow.
- Root Cause: Channel metadata update relied on strict channel classification and ran after fastcgi response, so channel-* room records could remain empty when the panel refreshed.
- Change: send_message.php now updates channel next-action metadata before returning the message response.
- Change: channel_action_helper.php recognizes channel-* JIDs and normalizes mention variants like Ajith_P / Ajith P / Ajith Kumar P.
- Change: channel_profile.php and update_channel.php accept channel-* room records for profile/update, and chat_api.dart adds a cache buster for profile reloads.
- Change: chat_screen.dart no longer forces scroll-anchor jump during browser text selection.
- Verification: PHP syntax checks passed for changed backend files. Flutter analyze on edited Dart files returned no errors, only existing warnings/infos.
- Build: flutter build web --release succeeded. Output: build/web.

## 2026-07-23 11:44:25 - Web Message Text Selection Stability
- Requirement: Selecting partial message text in web must not scroll/jump the chat window, while native selection and Ctrl+C copy continue to work.
- Root Cause: Flutter web text selection can trigger parent scrollable ensure-visible behavior while the chat list is still scrollable and auto-scroll timers can run.
- Change: Added a pointer-down selection intent lock before selection starts and temporarily applies NeverScrollableScrollPhysics to the chat message list while selection is active.
- Change: Existing native SelectableText and browser copy behavior are preserved.
- Verification: dart format passed. flutter analyze lib/chat/chat_screen.dart returned no errors, only existing warnings/infos.
- Build: flutter build web --release succeeded. Output: build/web.

## 2026-07-23 13:15:16 +05:30 - Web Message Selection Scroll Regression Fix
- Requirement: Message text selection and copy must continue to work, but normal chat scrolling must not be blocked and selected messages must not jump to the bottom.
- Root Cause: The earlier fix used selection state to disable the message list scroll physics. Pointer down on selectable message text therefore turned normal scrolling off.
- Change: Kept ScrollablePositionedList on normal ClampingScrollPhysics, separated text-selection state from list scroll physics, and retained selection state only to guard automatic bottom jumps.
- Verification: dart format lib/chat/chat_screen.dart passed; lutter analyze lib/chat/chat_screen.dart reported no errors, only existing warnings; lutter build web --release --base-href /chat/ completed successfully.

## 2026-07-23 15:43:48 +05:30 - Message Text Selection Gesture Stabilization
- Requirement: Message text must be easy to select on the first attempt, without screen dancing, unwanted bubble menus, swipe actions, or bottom jumps.
- Root Cause: Selectable text gestures were competing with parent message bubble long-press/right-click/swipe handlers during the first selection attempt.
- Change: Added a short text-selection intent window, suppresses floating message menu while text selection is active, keeps list scrolling enabled, and prevents swipe gestures from interfering with active browser text selection.
- Verification: dart format lib/chat/chat_screen.dart passed; lutter analyze lib/chat/chat_screen.dart reported no errors, only existing warnings; lutter build web --release --base-href /chat/ completed successfully.

## 2026-07-23 16:15:23 +05:30 - Chat Context Preservation Rule
- Requirement: When users interact with existing chat content, Flow must preserve their context and must not automatically move the conversation.
- Covered Interactions: Text selection/copy, manual reading/scrolling older messages, opening image/file previews, and media/content viewing flows.
- Change: Added a central _shouldPreserveUserContext guard in ChatScreen, marks context during user scrolls, text selection, and attachment preview opens, and blocks non-forced auto-scroll while the guard is active or the user is away from latest messages. Explicit jump-to-latest still clears the guard and moves to the bottom.
- Verification: dart format passed for changed files; lutter analyze lib/chat/chat_screen.dart lib/attachments/attachment_widgets.dart reported no errors, only existing warnings; lutter build web --release --base-href /chat/ completed successfully.

## 2026-07-23 17:30:34 +05:30 - Channel Hashtag Support
- Requirement: Add channel-only #tag concept so channel messages can be categorized and found later.
- Feature: Channel messages now persist detected hashtags, expose top channel tags in channel profile data, show a Tags card in the right-side channel panel, and make #tags in message text tappable to open in-chat search.
- Change impact: Limited to channel send/profile endpoints and Flutter chat/right-panel rendering. Direct chats and normal groups do not persist channel tags.
- Regression verification: PHP lint passed for server_patch/chat/bootstrap.php, send_message.php, channel_profile.php. Targeted Flutter analyze showed no new errors. Web release build passed at build/web.

## 2026-07-23 17:49:44 +05:30 - Message Right Click Menu Restore
- Requirement: Restore message right-click floating menu after text-selection stability changes.
- Feature: Right-click on a chat message now opens the Flow floating message action menu even when selectable text pointer locks are active.
- Change impact: Limited to message bubble secondary-click handling in lib/chat/chat_screen.dart. Long-press text-selection guard remains unchanged.
- Regression verification: dart format passed. Targeted flutter analyze completed with no new errors; existing warnings remain.

## 2026-07-24 10:37:38 +05:30 - Chat Text Selection Mode Root Fix
- Requirement: Permanently stop chat jumping/flickering while selecting message text.
- Root cause: History refresh/polling and scroll-position listeners could call setState and replace the message list while browser text selection handles were active; scroll-to-bottom logic then fought the active viewport.
- Change: Added explicit Selection Mode in lib/chat/chat_screen.dart. Selection Mode captures bottom state and visible anchor, queues history refresh results, blocks message-list rebuilds/scroll listener UI changes/presence/location UI updates during selection, and merges queued history only after selection ends.
- Merge behavior: If the user was at bottom before selection, queued messages merge and the chat returns to bottom. If reading older content, queued messages merge while restoring the captured visible message anchor.
- Verification: dart format passed; targeted flutter analyze completed with no new errors; web release build passed at build/web.

## 2026-07-24 11:04:49 +05:30 - External API Planning Documentation
- Requirement: Investigate Unauthorized errors for task creation from external systems and plan external API access for Flow.
- Root cause: Existing app APIs require Flow session auth via chat_require_user(), so external portals/Postman calls without session return Unauthorized.
- Deliverables: Created docs/external_api/README.md, docs/external_api/ENDPOINT_CATALOG.md, and docs/external_api/TASK_API_DRAFT.md.
- Decision: Keep internal app APIs session-protected; add a versioned external API layer with bearer API keys, scopes, audit logs, rate limits, and stable endpoint paths.
- Build: Documentation-only change; no Flutter/PHP build required.

## 2026-07-24 11:28:40 +05:30 - Module Versioned External API Documentation
- Requirement: Define all Flow external APIs using module-first versioned paths such as chat/v1, users/v1, groups/v1, and channels/v1.
- Deliverables: Added VERSIONED_API_ROUTES.md, CHAT_V1.md, USERS_V1.md, GROUPS_V1.md, CHANNELS_V1.md, TASKS_REMINDERS_NOTIFICATIONS_V1.md, and FILES_ATTENDANCE_LOCATION_V1.md under docs/external_api.
- Change impact: Documentation-only; no runtime code changed. Existing session-protected app APIs remain unchanged.
- Decision: External platform APIs should use /router_login/api/{module}/v1/{resource}, bearer API keys, scopes, idempotency keys, rate limits, and audit logs.
- Build: Not required for documentation-only update.

## 2026-07-24 11:53:02 - server_patch/api external APIs
- Added server_patch/api/_shared/bootstrap.php for CORS, Bearer/X-Flow-Api-Key auth, scope checks, audit logging, idempotency table schema, and module dispatch.
- Added module v1 index.php files and .htaccess routing.
- Added CLI API client helper: server_patch/api/_shared/create_client.php.


## 2026-07-24 12:18:16 - Extended API Handlers
- Added server_patch/api/_shared/extended.php.
- Updated server_patch/api/_shared/bootstrap.php dispatcher/scopes to use extended handlers.
- Updated server_patch/api/.htaccess to allow hyphenated modules.
- Updated server_patch/api/README.md with expanded endpoint catalogue.


## 2026-07-24 12:34:54 - API Docs Added
- Added docs/external_api/FLOW_EXTERNAL_API_DOCUMENTATION.md.
- Added server_patch/api/FLOW_EXTERNAL_API_DOCUMENTATION.md copy for server_patch deployment bundle.


## 2026-07-24 12:49:18 - Plugin System Files
- Added server_patch/chat/PluginEventBus.php.
- Added server_patch/chat/plugins/auto_translate/manifest.php and Plugin.php.
- Added hook emits in send_message.php, create_channel.php, create_group.php, manage_group.php, and external API message/group paths.
- Added docs/plugins/FLOW_PLUGIN_SDK.md.


## 2026-07-24 13:10:00 - Chat Selection Auto-scroll Guard
- File: lib/chat/chat_screen.dart
- Change: Added _isSelectionFreezeActive and blocked _scrollToBottom plus delayed scroll retries while selection mode or browser text selection is active.
- Change: Increased selection pointer/active locks to keep the viewport stable during the first web selection drag.

## 2026-07-24 14:34:05 +05:30 - Web Build Artifact Refresh
- Change: Refreshed Flutter web release artifacts under build\\web.
- Verification: flutter build web --release passed.

## 2026-07-24 14:53:05 +05:30 - Chat Scroll Selection Fix
- File: lib/chat/chat_screen.dart
- Change: Added drag-threshold selection intent handling inside _CollapsibleMessageTextState.
- Change: Removed normal-click selection freeze behavior that could trigger queued history anchor restore and move the conversation.
- Change: Recomputed scroll button state when selection mode finishes.

## 2026-07-24 14:58:22 +05:30 - History Limit Expansion
- File: server_patch/chat/history.php
- Change: Added historyLimit query handling with safe bounds 50-1000 and replaced hard-coded LIMIT 200 with dynamic LIMIT.
- Impact: Group/channel/personal chats can return more old messages without changing Flutter UI.

## 2026-07-24 15:08:16 +05:30 - Web Build Artifact Refresh
- Change: Refreshed Flutter web release artifacts under build\\web.
- Verification: flutter build web --release passed.

## 2026-07-24 15:55:18 - lib/chat/chat_screen.dart
- Changed _MessageBubble gesture routing so Web/Desktop plain text bubbles do not register parent tap, long-press, or horizontal swipe handlers while no message-action selection is active.
- Passed message selection state into _MessageBubble so multi-select tap behavior remains available when the app is already in message selection mode.
- Existing SelectableText.rich rendering remains intact; no chat screen rewrite was performed.


## 2026-07-24 - Native Text Selection Freeze Fix
- File: lib/chat/chat_screen.dart
- Change: Separated native text selection freeze from message-action selection mode; queued history updates while native text selection is active; prevented auto-scroll during selection; kept parent horizontal swipe mobile-only for selectable text bubbles.
- Reason: Parent gestures and message selection mode were competing with Flutter Web SelectableText, causing jumpy selection and scroll movement.

## 2026-07-24 15:55:36 +05:30 - Chat Text Selection Gesture Ownership Fix
- File: lib/chat/chat_screen.dart
- Change: Plain text bubbles on web/desktop no longer register parent tap/long-press/horizontal-drag recognizers while not in message-selection mode, allowing SelectableText to own mouse drags.
- Change: Async chat refresh guards now respect _isSelectionFreezeActive to avoid UI rebuilds during text selection.
- Change: Text selection pointer warmup now triggers only after drag threshold instead of plain pointer down.


## 2026-07-24 16:03:47 +05:30 - Web Artifact Refresh
- Build artifacts refreshed under build/web after the chat text selection fix.
- No source change was made during this build step.

## 2026-07-24 16:45:46 +05:30 - Chat Text Selection Root Fix
- Requirement: Web/Desktop chat message text must be selectable without jump, scroll lock, or parent gesture interference.
- File: lib/chat/chat_screen.dart
- Change: Plain text bubbles on web/desktop now let SelectableText own mouse drags by disabling parent tap/long-press/horizontal swipe recognizers for selectable text bubbles.
- Change: Removed the temporary ListView physics disable that could permanently block scrolling when pointer-up was missed.
- Change: Kept selection context freeze for incoming/history refresh without rebuilding the message list on pointer down.
- Verification: dart format passed; flutter build web --release passed; flutter analyze had existing warnings/info only and no compile errors.

## 2026-07-24 17:24:54 +05:30 - Channel Next Action List Badge
- Requirement: Channel list rows must show the next-action person as a colored badge; current user should display as YOU; badge color should follow next-action date urgency.
- Files: lib/chat_api.dart, lib/home/home_screen.dart, server_patch/chat/recent_chats.php
- Change: recent_chats.php now includes next_action_text, next_action_persons, and next_action_date for group/channel previews.
- Change: ChatContact and ChatPreview carry next-action metadata into the home/channel list.
- Change: Channel tiles render a compact next-action person badge below the message preview, with date-based color: overdue red, today orange, future blue, no-date purple.
- Verification: dart format passed; php -l recent_chats.php passed; flutter analyze for changed Dart files completed with existing warnings/info only and no compile errors.

## 2026-07-24 17:31:47 +05:30 - Web Artifact Refresh
- Change: Refreshed Flutter web release artifacts under build/web after the channel next-action badge update.
- Verification: flutter build web --release passed.

## 2026-07-24 18:00:10 +05:30 - Android Draft Release v2.0.5+28
- Requirement: Build next Android APK version and move it to live server as Draft for employee 302 approval.
- Files: pubspec.yaml, release/Skylink-Chat-v2.0.5.apk, release/Skylink-Chat-v2.0.5.apk.sha256, server_patch/register_draft_2_0_5.php
- Change: Bumped app version from 2.0.4+27 to 2.0.5+28.
- Change: Built release APK and copied it to release folder with SHA256 checksum.
- Deployment: Uploaded APK, checksum, and register_draft_2_0_5.php to live server.
- Draft registration: https://dns.watchtower247.in/router_login/register_draft_2_0_5.php returned android draft release_id=33.
- Approval: Release remains Development/Draft with rollout 0% and force_update 0 until employee 302 approves it.

## 2026-07-24 - AI API Menu and Endpoint
- Changed: lib/ai_api_screen.dart, lib/chat_api.dart, lib/home/home_screen.dart, server_patch/chat/ai_access.php.
- Impact: User-facing AI enable toggles for group/channel rooms; menu hidden for unassigned users.


## 2026-07-25 - Web Build Artifact Refresh
- Action: Rebuilt web release output in build/web for current source state.


## 2026-07-25 - Live AI Access Endpoint Deploy
- Action: Uploaded server_patch/chat/ai_access.php to live backend /var/www/html/router_login/chat/ai_access.php.
- Reason: AI API side menu was visible, but the API access page could not load room/provider access because the endpoint was not available on live backend.


## 2026-07-25 - AI API Menu Visibility Correction
- Changed: lib/ai_access_management_screen.dart, lib/home/home_screen.dart, lib/chat_api.dart, server_patch/chat/ai_access.php, server_patch/chat/ai_user_access.php.
- Deployment: ai_access.php and ai_user_access.php uploaded to live backend.


## 2026-07-25 - Mobile Channel Metadata, Folder Edit, Reply Highlight
- Files: lib/chat/chat_screen.dart, lib/home/home_screen.dart.
- Change: Added channel profile metadata tiles in the mobile group/channel manage sheet.
- Change: Added edit support for chat folders and visible default filter list inside folders screen.
- Change: Added a 3-second highlight state after jumping to a replied message.
- Verification: dart format passed; flutter analyze scoped to changed files completed with no compile errors. Existing warnings/info remain.

## 2026-07-25 - Latency Optimization Patch
- Files: lib/chat_api.dart, server_patch/chat/send_message.php, server_patch/chat/ai_room_worker.php, FLOW_PERFORMANCE_REPORT.md.
- Change: History prefetch now throttles to once every 2 minutes and max 4 chats per burst.
- Change: Diagnostics no longer resolve app/device metadata for every event.
- Change: AI room replies are spawned through ai_room_worker.php instead of blocking send_message.php.
- Verification: PHP lint passed for changed PHP files; flutter analyze on lib/chat_api.dart reported no compile errors.

## 2026-07-25 - Web Build After Latency Patch
- Action: Refreshed Flutter web release artifacts under build/web after latest performance/app updates.
- Verification: flutter build web --release --base-href /chat/ passed.

## 2026-07-25 - Chat Folder Database Persistence
- Files: lib/chat_api.dart, lib/home/home_screen.dart, server_patch/chat/chat_folders.php.
- Change: Added chat/chat_folders.php API and xmpp_chat_folders table creation.
- Change: Added getChatFolders/saveChatFolders API client methods.
- Change: Home and ChatFoldersScreen now use backend persistence; local storage is only used for one-time migration and then removed.
- Verification: PHP lint passed; dart format passed; scoped flutter analyze has no compile errors.

## 2026-07-25 - Mobile Composer Responsive Cleanup
- Files: lib/chat/chat_screen.dart.
- Change: Reworked _MessageComposer sizing variables for compact/mobile widths.
- Change: Tightened icon constraints, action button sizes, padding, and TextField density.
- Change: Removed the permanent format-bold icon and deleted the unused popup helper.
- Verification: dart format passed; scoped flutter analyze reported no compile errors, with existing warning/info backlog remaining.


## 2026-07-25 - Enter To Send User Setting
- Files: lib/main.dart, lib/app/skylink_app.dart, lib/settings/settings_screens.dart, lib/chat/chat_screen.dart.
- Change: Added appEnterToSend global preference with default true.
- Change: Loaded/saved enter_to_send via SharedPreferences.
- Change: Added Appearance switch for Enter sends message.
- Change: Updated _MessageComposer hardware/software keyboard behavior for Enter, Shift+Enter, and Ctrl+Enter.
- Verification: dart format passed; scoped flutter analyze reported no compile errors, with existing warning/info backlog remaining.


## 2026-07-25 - v2.0.6 Web APK Build And Android Draft
- Files: pubspec.yaml, server_patch/register_draft_2_0_6.php, tool/deploy_2_0_6.ps1, tool/deploy_2_0_6.psftp, release artifacts.
- Change: Bumped app version from 2.0.5+28 to 2.0.6+29.
- Build: flutter analyze .\\lib\\main.dart passed; flutter build web --release --base-href /chat/ passed; flutter build apk --release passed.
- Artifacts: release/Skylink-Chat-v2.0.6.apk; release/Skylink-Chat-Web-v2.0.6.zip.
- Deployment: Uploaded APK, checksum, and register_draft_2_0_6.php to live server.
- Draft registration: https://dns.watchtower247.in/router_login/register_draft_2_0_6.php returned android draft release_id=34.


## 2026-07-27 - Full View Image Preview
- Files: lib/attachments/attachment_widgets.dart.
- Change: Replaced the boxed InteractiveViewer image preview with a viewport-sized LayoutBuilder/InteractiveViewer implementation.
- Change: Added a short code comment documenting why the child must match the full preview viewport.
- Verification: dart format passed; scoped flutter analyze completed with no compile errors from this change. Existing file-level warnings remain.

## 2026-07-27 - Android Public Download Visibility
- Files: android/app/src/main/AndroidManifest.xml, android/app/src/main/kotlin/com/skylink/slync/MainActivity.kt, lib/chat_api.dart, lib/app/skylink_app.dart, lib/home/home_screen.dart.
- Change: Added Android native savePublicDownload bridge and SDK query on the existing skylink/android_settings channel.
- Change: Updated attachment download flow to save Android files/images into visible public media/download directories through MediaStore or legacy public storage.
- Change: Added saved-message permission call before download and updated legacy-only storage permission messaging.
- Verification: dart format passed; scoped flutter analyze reported no new compile errors in changed Dart files. Native Gradle verification could not complete locally because JAVA_HOME/java is missing on this machine.

## 2026-07-27 13:00:45 - Workspace Filter Implementation
- lib/chat_api.dart: Added ChatContact.channelKind and mapped channel_kind/channel_type from recent chat API JSON.
- lib/home/home_screen.dart: Added ChatPreview.channelKind, core channel kind helpers, Workspace filter id 7, fixed All + Workspace chip placement, and movable-only saved/reorder filter order.


## 2026-07-27 13:10:59 +05:30 - Chat List File Preview Cleanup
- Files: lib/chat_api.dart, lib/home/home_screen.dart, server_patch/chat/recent_chats.php.
- Change: Added ChatContact/ChatPreview last file metadata fields and mapped last_file_name/file_name from recent chat JSON.
- Change: Added attachment preview labels and icons for photo, video, audio, PDF, and generic files in chat list rows.
- Change: Updated recent_chats.php to return explicit last_file_name/file_name values for direct chats, groups/channels, and system notification rows.
- Verification: dart format passed; PHP lint passed; scoped flutter analyze reported no new compile errors, with the existing 36 warning/info backlog remaining.


## 2026-07-27 14:50:32 +05:30 - Broadcast Messaging Implementation
- Files: lib/chat_api.dart, lib/home/home_screen.dart, server_patch/chat/broadcast.php.
- Change: Added ChatApi.sendBroadcast() to call chat/broadcast.php with recipient IDs, message, and source metadata.
- Change: Added Broadcast entry points in home actions, overflow menu, drawer, and New Message sheet.
- Change: Added BroadcastSheet with title, message, searchable recipient list, multi-select, validation, and send progress state.
- Change: Added server broadcast endpoint with xmpp_broadcast_lists, xmpp_broadcast_recipients, xmpp_broadcast_sends, and xmpp_broadcast_message_map auto-create schema.
- Change: Enforced broadcast create/send for employee type A only; recipients receive normal direct xmpp_messages so replies stay private.
- Verification: PHP lint passed; dart format passed; scoped flutter analyze reported no compile errors, with existing 36 warning/info backlog remaining.


## 2026-07-27 - Broadcast Name / Members / Delete
- Updated server_patch/chat/broadcast.php with GET recipient payloads and save/update/delete actions.
- Updated lib/chat_api.dart with BroadcastList model plus get/save/delete/send broadcast APIs.
- Updated lib/home/home_screen.dart BroadcastSheet with list picker, broadcast name, member add/remove, save, delete, and send controls.


## 2026-07-27 - /ai And Metadata Sync
- Updated server_patch/chat/ai_room_helper.php default trigger and migration from @ai to /ai.
- Added server_patch/chat/conversation_metadata_helper.php for typed metadata definitions, values, and events.
- Wired metadata sync into send_message.php, create_group.php, and update_channel.php.
- Updated lib/chat/chat_screen.dart with slash command suggestions and lib/ai_api_screen.dart/admin public JS copy to use /ai.


## 2026-07-27 - DOB/DOJ Notification Runner
- Added server_patch/chat/employee_event_notifications.php.
- Endpoint reads employee.emp_id, dob, doj, name/designation, detects today birthday/work anniversary, sends via chat_send_system_notification, and logs delivery in xmpp_employee_event_notifications.


## 2026-07-27 - Next Action Summary And Clarification
- Updated server_patch/chat/channel_action_helper.php to add next_action_summary and next_action_missing_fields schema, strict person detection, summary extraction, and clarification-card insertion.
- Added server_patch/chat/update_action_clarification.php to update missing next action metadata from the chat UI.
- Updated server_patch/chat/channel_profile.php and conversation_metadata_helper.php to expose/sync next action summary.
- Updated lib/chat_api.dart, lib/chat/chat_screen.dart, and lib/home/home_screen.dart for summary display and Flow MCO clarification card UI.


## 2026-07-27 - Wake-up Last Message Summary
- Updated server_patch/chat/wakeup_helpers.php with last-message summary extraction and wake-up message body enrichment.
- Wake-up summary fetch excludes previous wake-up reminder messages so the summary points to the latest real conversation content.


## CHANGE-20260728-SYSTEM-NOTIFICATION-BROADCAST-FIX
- Date: 2026-07-28 10:25:00 +05:30
- Changed lib/chat_api.dart: removed the web-only System Notifications XMPP history shortcut so history.php loads old messages and marks them read.
- Changed lib/home/home_screen.dart: removed stale cached-profile Broadcast gate; backend remains the source of truth for Type A permission.
## CHANGE-20260728-SLASH-AI-COMMANDS
- Date: 2026-07-28 10:55:00 +05:30
- Changed lib/chat/chat_screen.dart: composer listener now tracks slash query alongside mention query.
- Changed server_patch/chat/ai_room_helper.php: added AI trigger token fallback list for /ai and @ai.
- Changed server_patch/chat/send_message.php: after fastcgi response close, AI reply is processed inline to avoid worker-spawn failures blocking replies.
## CHANGE-20260728-NEXT-ACTION-DATE-PERSON-FIX
- Date: 2026-07-28 11:10:00 +05:30
- Changed server_patch/chat/channel_action_helper.php: added month-end date parsing and changed next_action_date update to use the new parsed value directly instead of preserving old dates.
- Changed server_patch/chat/conversation_metadata_helper.php: aligned metadata date parsing with channel action month-end phrases.
## CHANGE-20260728-CONTEXT-AWARE-ACTION-ENGINE
- Date: 2026-07-28 11:35:00 +05:30
- Changed server_patch/chat/channel_action_helper.php: stricter task detection, context collection, context summary, previous_action_text schema/update, and stale date clearing retained.
- Changed server_patch/chat/conversation_metadata_helper.php: normal conversations now update only last_updated, actionable messages sync with refreshed channel metadata, and previous_action is synced from previous_action_text.
- Changed server_patch/chat/channel_profile.php: returns previous_action_text for future right-panel display.
## CHANGE-20260728-WEB-BUILD
- Date: 2026-07-28 11:50:00 +05:30
- Generated Flutter web release output in build/web using base href /chat/.
## 2026-07-28 - Change: Type A Auto Admin Enforcement
- Added chat role helpers in server_patch/chat/bootstrap.php.
- Updated group/channel member, profile, management, creation, rename, wake-up, external request, and mention expansion flows to use effective Type A admin role.
- Updated admin employee type save and member role update to preserve Type A admin access.

## 2026-07-28 - Change: Activity Log UI/API
- Added lib/myhub_activity_screen.dart.
- Added ChatApi getMyHubActivities/saveMyHubActivity methods.
- Added My Activity route in lib/home/home_screen.dart.
- Added section=activity GET/POST support in server_patch/chat/myhub.php, saving to activity_log.

## 2026-07-28 - Change: Activity Log Uses Chat DB
- Updated server_patch/chat/myhub.php so activity_log table creation, insert, and current-month list use chat_db().
- Task module DB access remains unchanged for task_master flows.

## 2026-07-28 - Change: External API Group/Channel Send Docs And Channel Lifecycle Routes
- Changed server_patch/api/_shared/bootstrap.php: auto-detect room JIDs containing @conference. and store API messages as groupchat when message_type is omitted.
- Changed server_patch/api/_shared/extended.php: added POST/PATCH close, archive, and unarchive routes for group/channel handlers; DELETE remains compatibility soft-delete/archive.
- Updated external API docs: FLOW_EXTERNAL_API_DOCUMENTATION, CHAT_V1, CHANNELS_V1, ENDPOINT_CATALOG, VERSIONED_API_ROUTES, and server_patch/api doc mirrors.

## 2026-07-28 - Change: My Hub Horizon
- Added lib/myhub_horizon_screen.dart with Horizon list and in-app route map painter.
- Updated lib/chat_api.dart with getMyHubHorizon and getMyHubHorizonTimeline.
- Updated lib/home/home_screen.dart to show Horizon in My Hub.
- Updated server_patch/chat/myhub.php with section=horizon and section=horizon_timeline backend routes.

## 2026-07-28 - Change: Horizon Load Failure Hardening
- Changed server_patch/chat/myhub.php: Horizon punch list now detects punch table/columns dynamically and falls back across employee/task DB sources instead of failing the whole MyHub response.

## 2026-07-28 - Change: Horizon Map Tiles And Timeline Address
- Changed lib/myhub_horizon_screen.dart: Horizon route view now renders OpenStreetMap tiles behind the GPS route, aligns route/markers using Web Mercator coordinates, and shows Start/30 min/Last legend.
- Changed lib/myhub_horizon_screen.dart: 30-minute timeline now prefers checkpoint time and shows address plus latitude/longitude when address is available.
- Changed server_patch/chat/myhub.php: section=horizon_timeline now returns saved location address when present and reverse-geocodes missing checkpoint addresses via existing cached geocode helper.

## 2026-07-28 - Change: Horizon Zoom And Reporting Scope
- Changed lib/myhub_horizon_screen.dart: Horizon map now supports zoom in/out buttons and mouse-wheel zoom while keeping the OSM route overlay aligned.
- Changed server_patch/chat/myhub.php: Horizon super users 116, 232, 302, 428, and 553 continue to see all punched-in employees.
- Changed server_patch/chat/myhub.php: other users now see only their own punch data plus employees whose employee.reporting_to points to the viewer employee ID; timeline access enforces the same scope.

## 2026-07-28 - Change: Group Channel Slash Help
- Changed lib/chat/chat_screen.dart: added /help to Flow slash commands.
- Changed lib/chat/chat_screen.dart: typing and sending /help in a group/channel opens a local Flow command guide with each command and usage description instead of posting noise into the chat.
- Changed lib/chat/chat_screen.dart: /help from direct chats is handled with a snackbar explaining commands are for groups/channels.

## 2026-07-28 - Change: Horizon Map Drag Pan
- Changed lib/myhub_horizon_screen.dart: Horizon map now supports mouse/touch drag panning in addition to zoom buttons and mouse-wheel zoom.
- Changed lib/myhub_horizon_screen.dart: route overlay, start/end markers, and checkpoint markers now share the panned world-coordinate center with the tile layer so they remain synchronized while moving the map.

## CHG-2026-07-28-RELEASE-207
- Updated pubspec version from 2.0.6+29 to 2.0.7+30.
- Updated Windows installer packaging script to derive version from pubspec.yaml.
- Added server_patch/register_draft_2_0_7.php and tool/deploy_2_0_7.ps1/.psftp.


## CHG-2026-07-29-OPENROUTER-AUTO-MODEL
- Updated OpenRouter AI room helper fallback model from gpt-4o-mini to auto.
- External API documentation examples now use model auto for OpenRouter.
- Preserved backward compatibility for old saved gpt-4o-mini provider values by normalizing them to auto at runtime.


## CHG-2026-07-29-BROADCAST-CHANNEL-CREATE-UX
- Added Select All / Select all visible users support in Broadcast recipient picker.
- Added Select All / Select all visible users support in New Group/Channel member picker.
- Improved New Group/Channel create sheet into a constrained modal-style card on wide screens.
- Fixed create_channel.php undefined employee DB handle that caused Unable to create channel.


## CHG-2026-07-29-RECENT-CHAT-HIGH-VOLUME-SYNC
- Added queued refresh handling in HomeScreen so high-volume users do not drop chat-list refresh requests while a previous refresh is still active.
- Increased recent direct chat limit from 75 to 150 and group/channel limit from 100 to 250.
- Updated recent group/channel last-message and unread selection to respect history_visible_from and selected-message visibility.
- Added message/read indexes in chat schema for recent-list and unread-count performance.


## 2026-07-29 - High-volume chat history pagination
- Requirement: Make high-message groups/channels faster like WhatsApp/Telegram by loading only recent messages first and loading older messages on scroll-up.
- Change: Added limit and efore_message_id support to chat/history.php, defaulting to 50 messages instead of 1000.
- Change: Updated Flutter ChatApi.getHistory and ChatScreen to fetch latest 50 messages, trim old persisted cache, and lazy-prepend older messages when users scroll near the top.
- Impact: Reduces initial chat payload, first render work, and repeated refresh cost for high-volume support groups/channels.
- Verification: php -l server_patch/chat/history.php passed. lutter analyze lib/chat_api.dart lib/chat/chat_screen.dart completed with existing warnings/info only, no compile errors.
- Updated: 2026-07-29 14:59:38

## 2026-07-29 - Web Build Completed
- Request: Build web release after high-volume chat history pagination update.
- Command: flutter build web --release --base-href /chat/
- Output: build/web
- Status: Success
- Report: BUILD_REPORT_2026-07-29_web_history_pagination.md
- Updated: 2026-07-29 15:07:37

## CHG-2026-07-29-CHANNEL-TYPE-API
- Status: Complete
- Files: server_patch/api/_shared/bootstrap.php; server_patch/chat/create_channel.php; server_patch/chat/external_create_conversation.php; server_patch/chat/update_channel.php; docs/external_api/FLOW_EXTERNAL_API_DOCUMENTATION.md; server_patch/api/FLOW_EXTERNAL_API_DOCUMENTATION.md; docs/external_api/CHANNELS_V1.md
- Change: Preserve API-supplied channel type and document channel_type as preferred field.
- Verification: PHP lint passed for all modified PHP files.
- Updated: 2026-07-29 15:37:44 +05:30

## CHG-2026-07-29-SLASH-COMMAND-BEHAVIOR
- Status: Complete
- Files: lib/chat/chat_screen.dart; server_patch/chat/conversation_metadata_helper.php; server_patch/chat/channel_action_helper.php
- Change: Added slash command router in chat composer and command-aware metadata/action backend handling.
- Verification: PHP lint passed; Flutter analyze ran with pre-existing warnings/info and no new compile errors identified.
- Updated: 2026-07-29 16:06:09 +05:30


## CHG-2026-07-29-NEW-CHANNEL-MEMBER-LIST-SCROLL
- Status: Complete
- Files: lib/home/home_screen.dart
- Change: Increased new group/channel dialog height, compacted channel description field, and wrapped member results in a visible scrollable list.
- Verification: Flutter analyze on lib/home/home_screen.dart ran with existing warnings/info and no new blocking errors identified.
- Updated: 2026-07-29 16:40:00 +05:30

## CHG-2026-07-29-BROADCAST-MODAL-PICKER
- Status: Complete
- Files: lib/home/home_screen.dart
- Change: Replaced broadcast bottom sheet launcher with a dialog modal and updated BroadcastSheet layout to use center constraints, keyboard inset handling, compact message field, and scrollable recipient list.
- Verification: dart format passed. Flutter analyze on lib/home/home_screen.dart ran with existing warnings/info and no new blocking errors identified.
- Updated: 2026-07-29 17:05:00 +05:30

## CHG-2026-07-29-MYHUB-SUGGESTIONS-COMPLAINTS
- Status: Complete
- Files: server_patch/chat/myhub.php; lib/chat_api.dart; lib/myhub_suggestions_screen.dart; lib/home/home_screen.dart
- Change: Added suggestion_complaints table ensure/migration, create/list MyHub section, system notification to selected user, Flutter API helpers, Suggestions & Complaints screen, and My Hub tile routing.
- Verification: PHP lint passed. Dart format passed. Flutter analyze on touched Dart files ran with existing warnings/info and no new blocking errors identified.
- Updated: 2026-07-29 17:45:00 +05:30

## CHG-2026-07-29-CHAT-LIST-NEXT-ACTION-BADGE
- Status: Completed
- Changed: Removed "NEXT ACTION" suffix from the chat list badge, added date/time formatting, and widened the badge max width so names can size naturally.
- Risk: Low; presentational change only, no backend/API changes.

## CHG-2026-07-29-WEB-BUILD-NEXT-ACTION-BADGE
- Status: Completed
- Changed: Ran `flutter build web --release --base-href /chat/` and regenerated `build/web`.
- Risk: Low; build output only.

## CHG-2026-07-29-DIRECT-USER-SEND-API
- Status: Completed
- Changed: Added direct employee-id message handling in `server_patch/api/_shared/extended.php` and documented usage in external API docs.
- Risk: Low/Medium; scoped to external API route, existing `/chat/v1/messages` behavior preserved.

## CHG-2026-07-29-DIRECT-MESSAGE-API-404-FALLBACK
- Status: Completed
- Changed: Added `server_patch/api/chat/v1/direct/messages/index.php` forwarding to the chat v1 dispatcher and documented the fallback deployment path.
- Risk: Low; route only forwards to existing chat API dispatcher.

## CHG-2026-07-29-DIRECT-MESSAGE-POSTMAN-BODY-FALLBACK
- Status: Completed
- Changed: `POST /api/chat/v1/direct/messages` merges JSON input with `$_POST` and `$_GET`, and accepts `recipient_id`, `to`, `sender_id`, `from`, and `text` aliases.
- Risk: Low; only direct API POST input parsing changed.

## CHG-2026-07-30-DIRECT-MESSAGE-BODY-DIAGNOSTICS
- Status: Completed
- Changed: Replaced strict helper-only body parsing in `POST /api/chat/v1/direct/messages` with robust raw-body parsing and safe validation debug metadata.
- Risk: Low; authentication unchanged and debug does not echo secrets or body content.

## CHG-2026-07-30-DIRECT-MESSAGE-PHYSICAL-HANDLER
- Status: Completed
- Changed: Replaced fallback include-only route with a standalone authenticated direct-message handler using raw JSON/form/query parsing and safe debug metadata.
- Risk: Low; route is specific to one-to-one direct messages and keeps existing auth/audit helpers.

## CHG-2026-07-30-DIRECT-SEND-PHYSICAL-ENDPOINT
- Status: Completed
- Changed: Created `server_patch/api/chat/v1/direct_send.php` as a self-contained authenticated direct-message handler and documented it.
- Risk: Low; new endpoint only, no existing endpoint behavior removed.

## CHANGE-2026-07-30-NEXT-ACTION-MONITOR
- Type: Backend
- Files: server_patch/chat/next_action_monitor_helpers.php, server_patch/chat/notification_worker.php, docs/next_action_monitor.md
- Summary: Added a cron-safe next-action monitor with state hashing, one-hour reminders, and due-time completion polls.
- Risk: Low; existing chat UI untouched, notification worker response gains next_action stats.

## CHANGE-2026-07-30-TASK-CREATE-PHYSICAL-ENDPOINT
- Type: Backend/API
- Files: server_patch/api/tasks/v1/create.php; docs/external_api/TASKS_REMINDERS_NOTIFICATIONS_V1.md
- Summary: Added rewrite-independent task create endpoint to avoid `/api/tasks/v1` returning GET list behavior in Postman/live server.
- Risk: Low; existing `/api/tasks/v1` behavior remains unchanged.
- [2026-07-30] CHANGE-SHARE-ANDROID-INBOUND: Updated AndroidManifest share intent filters, MainActivity MethodChannel content URI cache copy, HomeScreen target picker, ChatScreen shared-file consumer, and shared Android share models.

## CHANGE-VIDEO-ATTACHMENT-SEND-20260730
- Status: Completed
- Files: lib/chat/chat_screen.dart, lib/chat_api.dart
- Change: Replaced image-only gallery picker with media picker and added path-based native upload for videos/large files to avoid loading full video bytes into memory.

- 2026-07-30 | CHG-BUILD-208 | COMPLETE | Bumped pubspec version to v2.0.8+31; built web release and Android release APK; packaged artifacts with SHA256 hashes.

- 2026-07-30 | CHG-DEPLOY-208 | COMPLETE | Added register_draft_2_0_8.php; uploaded APK/Web ZIP and SHA256 files to live server; executed draft registration.

## CHANGE-2026-07-31-VIDEO-UPLOAD-LIMIT
- Type: Backend/server config
- Files: server_patch/chat/upload_file.php, server_patch/chat/.user.ini
- Summary: Added PHP-FPM per-folder upload limit configuration for large attachments and replaced raw upload error code responses with descriptive upload-limit diagnostics.
- Risk: Low; upload handler behavior only changes failed-upload error messaging and server runtime limits when deployed.

## CHANGE-2026-07-31-TELEGRAM-STYLE-UPLOAD-UX
- Type: Flutter UI/UX
- Files: lib/chat/chat_screen.dart, lib/attachments/attachment_widgets.dart
- Summary: Added per-message upload progress tracking for attachment sends and enhanced attachment tiles to show uploading percentage, spinner, file/video-specific icon, and failed upload state before the final uploaded attachment replaces the temporary bubble.
- Risk: Medium; upload UI path changed, but backend send APIs and existing attachment preview/download behavior remain unchanged.

## CHANGE-2026-07-31-CHAT-UPLOAD-50MB
- Files changed: lib/attachment_validation.dart, lib/chat/chat_screen.dart, lib/chat_api.dart, server_patch/chat/upload_file.php, server_patch/chat/.user.ini
- Change: Reduced default upload max from 2 GB to 50 MB, allowed business file/video names through validation, added pre-preview validation, added server 413 guard, and aligned PHP upload timeout/size settings.
- Impact: Prevents oversized uploads from hanging or failing late while preserving upload progress UI for valid files.

## CHANGE-2026-07-31-LMS-LEAD-WEBHOOK
- Files changed: server_patch/chat/send_message.php, server_patch/chat/lms_webhook_helper.php, server_patch/chat/lms_webhook_worker.php, server_patch/chat/lms_webhook_config.sample.php, docs/LMS_WEBHOOK_SYNC.md
- Change: Added LMS webhook queue schema, lead-channel detection, participant-message filtering, stable flow-message IDs, async delivery worker, retry/no-retry policy, and local secret config template.
- Impact: Flow send path remains fast while LMS receives matching lead-channel activity updates.

## 2026-07-31 - Chat attachment send fallback
- File: lib/chat/chat_screen.dart
- Change: When PlatformFile.bytes is null for a regular attachment and a local file path exists, Flow now reads bytes from the native path before throwing Unable to read ....
- Reason: Android/Desktop pickers and share flows can return path-only files.
- Risk: Low; large/video files still use the existing stream/path upload branch.

## 2026-07-31 - Horizon overview map enhancement
- File: lib/myhub_horizon_screen.dart
- Change: Reworked Horizon to include an all-employees overview map, selectable marker/name list, inline selected employee timeline panel, and full route deep-link button.
- Risk: Medium-low UI-only change using existing Horizon APIs.

## 2026-07-31 - Broadcast send hotfix
- File: server_patch/chat/broadcast.php
- Change: Added missing $title initialization in the broadcast send action before list update/insert.
- Root cause: Send branch used $title without defining it, causing backend failure and generic UI error.

## CHANGE-20260801-HORIZON-LIVE-VIEW-AND-PREVIEW
- Timestamp: 2026-08-01 18:55 +05:30
- Files changed:
  - lib/myhub_horizon_screen.dart
  - server_patch/chat/myhub.php
  - server_patch/chat/bootstrap.php
- Summary:
  - Replaced inline Horizon overview section with separate-page launcher.
  - Added latest employee latitude/longitude/address metadata to Horizon employee list payload.
  - Normalized file/attachment preview labels in backend preview helpers.

- 2026-08-01 | Updated next-action monitor to send due prompt once only; updated chat composer mention parsing for mid-text cursor mentions.

- 2026-08-01 | Patched app and server notification channels so punch_in, punch_out, location_off and related alerts use muted delivery.

- 2026-08-01 | Patched flow_api_ext_groups_channels route parsing to strip optional leading groups/channels segment before id-based lifecycle handling.

## CHG-20260801-EXTERNAL-CHANNEL-BODY-CLOSE
- Date: 2026-08-01 20:10:00 +05:30
- Files: server_patch/api/_shared/extended.php
- Change: Added body-based lifecycle handling for external group/channel API. Base POST to /router_login/api/channels/v1 or /groups/v1 now accepts action=close|archive|unarchive|delete plus channel_id/group_id/id or room_jid, so lifecycle updates work without relying on path routing.
- Root cause: Live Apache path routing can return 404 before PHP reaches /channels/{id}/close style handlers.
- Risk: Change is intentionally narrow and only activates when explicit lifecycle action is present in the POST body.


## CHG-20260801-PHYSICAL-CHANNEL-ACTION-ENDPOINT
- Date: 2026-08-01 20:25:00 +05:30
- Files: server_patch/api/channels/v1/action.php, server_patch/api/channels/v1/close.php
- Change: Added physical file endpoints for channel lifecycle actions so external callers can close/archive/unarchive/delete a channel by JSON body without depending on rewrite/dispatcher behavior.
- Root cause: Live /api/channels/v1 requests were still falling through to channel listing instead of lifecycle action handling.


## CHG-20260801-WEB-FILE-PICKER-UPLOAD
- Date: 2026-08-01 21:15:00 +05:30
- Files: lib/chat/chat_screen.dart, lib/web_attachment_bridge_web.dart, lib/web_attachment_bridge_stub.dart
- Change: Routed web media/file attachment selection through a browser FileUpload helper that reads bytes directly and returns PlatformFile objects ready for the existing upload pipeline.
- Root cause: On Flutter web, FilePicker can return selected PlatformFile entries without bytes for some manual picker flows, causing the existing send path to fail before upload starts.
- Risk: Low. Non-web picker flow remains unchanged; web drag/drop and paste behavior is preserved.

## CHG-20260801-COMPOSER-UPLOAD-LATENCY
- Date: 2026-08-01 22:05:00 +05:30
- Files: lib/chat/chat_screen.dart, lib/web_attachment_bridge_web.dart, lib/shared/android_share_intent.dart, server_patch/chat/.user.ini, server_patch/chat/.htaccess
- Change: Replaced regex-heavy in-composer slash/@ detection with lightweight cursor token parsing; parallelized browser/share/drop file conversion; raised deployable upload-limit config to support 50MB attachments.
- Root cause: In-between composer triggers were scanning the full text with end-anchored regex, and live upload failures were caused by server PHP limits still capped at 2MB/8MB.
- Risk: Low-to-medium. Composer behavior changed only for trigger detection near cursor; attachment upload path is unchanged after file conversion, but live server must receive hidden config files.

## 2026-08-01 - Attachment/video UX
- Extended ChatAttachment with previewBytes/localPath and isVideo helper.
- Updated temp attachment creation in chat send flow to carry local preview data for image/video uploads.
- Added video preview embed helpers for web/stub platforms.
- Upgraded attachment widget rendering to show inline image/video cards with upload progress overlays.
- Updated attachment preview screen to open video inside Flow instead of generic binary fallback.

## 2026-08-01 - Attendance calendar state styling
- Date: 2026-08-01 22:45:00 +05:30
- Files: lib/profile/profile_screens.dart
- Change: Replaced the binary present/empty calendar rendering with explicit day-state helpers so only real punch days show the green tick while week off, missed, and future dates render with their own visual states.
- Root cause: The calendar treated every non-null attendance row as a punched day, so week offs and empty attendance records were incorrectly rendered as successful punch days.
- Risk: Low. Change is isolated to attendance calendar presentation and reuses existing backend attendance flags.

## 2026-08-01 - Leave apply schema alignment
- Date: 2026-08-01 23:20:00 +05:30
- Files: lib/myhub_leave_screens.dart, server_patch/chat/myhub.php
- Change: Reduced leave-type choices to the two business-approved options, redirected leave OTP notifications to employee 302 for testing, and aligned leave request inserts with `track_leave_request` columns such as `otp`, `approval_status`, `approver_emp_id`, and `updated_at` when available.
- Root cause: The UI still exposed legacy leave types and the backend leave insert logic did not fully map to the live employee-database table structure shown by the user.
- Risk: Low-to-medium. Flow is isolated to leave apply only, but live server patch deployment is required for OTP recipient and insert mapping changes to take effect.

## 2026-08-01 - Leave OTP notification key length fix
- Date: 2026-08-01 23:45:00 +05:30
- Files: server_patch/chat/SystemNotification.php
- Change: Added a bounded system-notification client-message-id normalizer so notification references fit within the `xmpp_messages.client_message_id` column.
- Root cause: Leave OTP notification references were prefixed with `notification:` after an 80-char trim, pushing the final stored value past the DB column limit and causing SQLSTATE 1406.
- Risk: Low. Change is isolated to system-notification dedupe/storage keys.

## 2026-08-01 - Release 2.0.9 build and draft registration
- Date: 2026-08-01 17:55:00 +05:30
- Files: pubspec.yaml, server_patch/register_draft_2_0_9.php, tool/deploy_2_0_9.ps1, tool/deploy_2_0_9.psftp
- Change: Bumped app version to 2.0.9+32, generated new release helpers, built web/APK artifacts, uploaded the Android APK to the live server, and registered Android draft release id 38 for employee 302 approval.
- Root cause: The previous published version was 2.0.8+31 and could not be reused safely for a fresh approval cycle.
- Risk: Low. Change is isolated to release packaging/deployment metadata and does not alter runtime product logic.
