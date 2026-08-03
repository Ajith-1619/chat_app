
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

## 2026-07-24 11:53:02 - External API v1 Server Patch
- Requirement: Build module-first external APIs under server_patch/api for chat, users, groups, channels, tasks, reminders, notifications, files, attendance, location, releases, and diagnostics.
- Status: Completed first deployable PHP v1 layer with API-key auth, scopes, audit logs, and client creation helper.


## 2026-07-24 12:18:16 - Remaining External API Endpoints
- Requirement: Complete remaining Flow external API routes for chat actions, files, saved messages, search, storage, AI, external users, attendance, location, release actions, polls, and checklists.
- Status: Completed expanded v1 PHP endpoint coverage under server_patch/api.


## 2026-07-24 12:34:54 - Full External API Documentation
- Requirement: Create full documentation for all possible external API endpoints using base URL https://dns.watchtower247.in/router_login/api/{module}/v1/{resource}.
- Status: Completed documentation in docs/external_api/FLOW_EXTERNAL_API_DOCUMENTATION.md and copied to server_patch/api/FLOW_EXTERNAL_API_DOCUMENTATION.md.


## 2026-07-24 12:49:18 - Flow Messenger Plugin Extension System
- Requirement: Add plugin/extension system with hooks for message.received, message.sent, channel.created, member.added; sandbox plugin execution; separate plugin error logs; example auto-translate plugin; SDK documentation.
- Status: Completed server-side PHP plugin event bus, manifest registration, hook triggers, example plugin, and SDK docs.


## 2026-07-24 13:10:00 - Web Chat Text Selection Stability Follow-up
- Requirement: Re-check the persistent web message text selection jump/dance issue and preserve user context during selection.
- Status: Updated selection freeze guards so even forced scroll-to-bottom retries are blocked while text selection is active.

## 2026-07-24 14:53:05 +05:30 - Chat Selection Jump Root Fix Follow-up
- Requirement: Fix persistent web chat jump when clicking/selecting message text and restore jump-to-latest button visibility.
- Status: Updated message text pointer handling so normal click does not enter selection mode; only drag selection or actual non-collapsed selection freezes the viewport.

## 2026-07-24 14:58:22 +05:30 - Old Group Message History Limit
- Requirement: Check why old messages are not visible in some groups/channels.
- Finding: chat/history.php had a hard-coded latest 200 message cap for both group/channel and personal history.
- Status: Updated server patch to allow up to 1000 messages per history request by default.

## 2026-07-24 - Chat Web Text Selection Stability
- Requirement: Message text inside chat bubbles must be selectable with mouse drag on Flutter Web/Desktop without triggering swipe reply, tap actions, long press menus, message selection mode, auto-scroll, or list jump.
- Status: Implemented in chat message bubble/text selection path; pending browser acceptance check by user.

## 2026-07-24 15:55:18 - Web/Desktop Message Text Selection
- Requirement: Message bubble text must be selectable with mouse drag on Flutter Web/Desktop without triggering swipe reply, tap actions, long press menu, drag conflicts, or message selection mode.
- Scope: Sent/received/plain/formatted/long/read-more message text in desktop web browsers.


## 2026-07-24 15:55:36 +05:30 - Completed: Web/Desktop Message Text Selection
- Requirement: Message text inside chat bubbles must be selectable with mouse drag on Flutter Web/Desktop without triggering swipe reply, message tap, long press menu, drag/scroll conflict, or message selection mode.
- Status: Completed in Flutter source; production-safe minimal chat bubble gesture fix.


## 2026-07-24 16:45:46 +05:30 - Requirement Update
- Requirement: Message text selection on web/desktop must behave like native web text selection without moving the conversation.
- Status: Implemented in lib/chat/chat_screen.dart and built into build/web.

## 2026-07-24 17:24:54 +05:30 - Requirement Update
- Requirement: Show next-action person badge in channel list, using YOU for the current user and urgency color based on next-action date.
- Status: Implemented. Pending live server deployment of server_patch/chat/recent_chats.php and app build/deploy for users to see it.

## 2026-07-24 18:00:10 +05:30 - Requirement Update
- Requirement: APK build should be created for next version and staged on live server as Draft for 302 approval.
- Status: Complete. Version 2.0.5+28 draft registered as release_id 33.

## 2026-07-24 - AI API Room Toggle Access
- Status: Implemented locally
- Requirement: Show AI API menu only for users with AI access, list involved groups/channels, and allow toggling @ai support using default Open Router provider id 2.


## 2026-07-25 - AI API Access Assignment Split
- Status: Implemented locally; backend deployed.
- Requirement: Employee 302 must see an API Access management menu. Only users enabled there should see the AI API room-toggle menu.


## 2026-07-25 - Mobile Channel Profile, Folder Filters, Reply Highlight
- Requirement: Mobile Manage Channel must show description, next action, next action person, and next action date; web Chat Folders must show default filters and allow editing folders; reply preview jump must highlight the target message.
- Status: Implemented locally. Build not requested in this turn.

## 2026-07-25 - Chat API Latency Review
- Requirement: Check app/API latency and identify/fix slow paths where possible.
- Status: Implemented local optimizations for send-message AI work, Android history prefetch bursts, and diagnostics overhead. Live backend deploy required for send-message latency improvement.

## 2026-07-25 - DB-Backed Chat Folders
- Requirement: Chat folders must not be local-only; they must persist in database per user across builds/devices, remain editable, appear with All/Unread/Online filters, and persist reorder position.
- Status: Implemented locally. Backend endpoint must be deployed before production use.

## 2026-07-25 - Mobile Composer Responsive Cleanup
- Requirement: APK message composer must be flexible across mobile screen sizes, easier for continuous typing, and remove the always-visible B formatting icon.
- Status: Implemented locally in lib/chat/chat_screen.dart. Build not requested in this turn.


## 2026-07-25 - Enter To Send User Setting
- Requirement: User must be able to enable or disable Enter-to-send from Settings. When enabled, Enter sends and Shift/Ctrl+Enter inserts a new line. When disabled, Enter inserts a new line and the send button sends.
- Status: Implemented locally. Build not requested in this turn.


## 2026-07-25 - v2.0.6 Web APK Build And Android Draft
- Requirement: Build next version web and APK, then move APK to live server as Draft for employee 302 approval.
- Status: Completed. Version bumped to 2.0.6+29; web and APK builds passed; Android draft registered as release_id=34.


## 2026-07-27 18:35:00 +05:30 - Full View Image Preview
- Requirement: Image attachment preview must open in a full-view viewport instead of a small boxed area, and zoom/pan must use the full available preview space.
- Status: Implemented locally. Build not requested in this turn.

## 2026-07-27 19:20:00 +05:30 - Android Public Download Visibility
- Requirement: Mobile downloads must request storage where needed, save files/images into visible public device folders like WhatsApp/Telegram, and make the saved location clear to the user.
- Status: Implemented locally. Build not requested in this turn.

## 2026-07-27 13:00:45 - Workspace Chat Filter
- Requirement: Add a fixed Workspace filter next to All. Workspace lists channels whose channel type is not incident, action, operational, project, or announcement. Channels filter lists only those five core channel types. All and Workspace must not be reorderable; other filters remain reorderable.


## 2026-07-27 13:10:59 +05:30 - Chat List Attachment Preview
- Requirement: Chat list rows must show a clean file/photo/video/audio preview with an icon when the latest message is an attachment, instead of mojibake/raw encoded body text.
- Status: Implemented locally. Server patch must be deployed for live recent chat JSON to include explicit last_file_name/file_name metadata.


## 2026-07-27 14:50:32 +05:30 - Type A Broadcast Messaging
- Requirement: Flow must support Broadcast messaging where only Type A users can create/send a broadcast to multiple users, recipients receive it as private/direct messages, and replies remain one-to-one with the sender.
- Status: Implemented locally for text broadcasts. Backend patch must be deployed before production use.


## 2026-07-27 - Broadcast Saved List Management
- Requirement: Broadcast must support a saved name, add/remove recipients, and delete broadcast lists.
- Status: Implemented locally; backend patch and Flutter UI/API updated.


## 2026-07-27 - Slash AI And Conversation Metadata Engine
- Requirement: Replace @ai trigger with /ai, show slash command list when typing /, and add a strongly typed conversation metadata engine for channels, groups, and DMs.
- Status: Implemented foundation locally for /ai, slash suggestions, metadata schema, message command/event capture, and conversation snapshot sync.


## 2026-07-27 - Employee Birthday And Work Anniversary System Notifications
- Requirement: Use employee.dob and employee.doj to send birthday and work anniversary messages to all users in System Notifications.
- Status: Implemented backend daily notification endpoint with duplicate protection.


## 2026-07-27 - Next Action Summary And Clarification
- Requirement: When actionable messages update channel next action/person/date, also save a short action summary. If the message does not clearly include a next action person or date, show a Flow MCO-style clarification card in the conversation so members can update the missing details.
- Status: Implemented locally; server patch must be deployed for live channels.


## 2026-07-27 - Wake-up Last Message Summary
- Requirement: Wake-up reminder messages must include the latest conversation message summary along with the existing stale/no-new-message reminder text.
- Status: Implemented locally in backend wake-up helper. Build not required for this backend-only patch.


## REQ-20260728-SYSTEM-NOTIFICATION-BROADCAST-FIX
- Date: 2026-07-28 10:25:00 +05:30
- Requirement: System Notifications must show persisted older messages and clear unread count when opened; Broadcast entry must not be blocked by stale cached user type after Type A updates.
- Status: Implemented; validation completed with existing analyzer warnings only.
## REQ-20260728-SLASH-AI-COMMANDS
- Date: 2026-07-28 10:55:00 +05:30
- Requirement: Typing / must show Flow command suggestions; /ai must trigger Flow AI, with @ai kept as a legacy fallback.
- Status: Implemented; build not requested.
## REQ-20260728-NEXT-ACTION-MISSING-PERSON-DATE
- Date: 2026-07-28 11:10:00 +05:30
- Requirement: Actionable channel messages must not retain stale next-action dates; missing assignee/person must remain a clarification requirement, and phrases like end of this month must resolve correctly.
- Status: Implemented; build not requested.
## REQ-20260728-CONTEXT-AWARE-ACTION-ENGINE
- Date: 2026-07-28 11:35:00 +05:30
- Requirement: Only truly actionable channel messages should update next/previous action metadata; missing person/date must create backend clarification; last 10-20 messages should be considered for context-aware action summary/person/date.
- Status: Implemented; build not requested.
## 2026-07-28 - Type A Auto Admin For Groups/Channels
- Requirement: Type A users involved in any group/channel must automatically have admin access, even when stored membership role is member.
- Status: Implemented in server patch/admin control paths.
- Scope: Effective role resolution, membership sync, create/add/manage/update/wake-up/profile/mention flows.

## 2026-07-28 - My Hub Activity Log
- Requirement: Add My Hub > My Activity with daily activity form matching provided screenshot.
- Fields: Log Type, Files, Activity Description, From time, To time.
- Backend: Save into legacy activity_log table and show current-month logs for the logged-in user.
- Status: Implemented.

## 2026-07-28 - My Activity DB Target Correction
- Requirement: My Hub activity_log must be stored in the XMPP/chat application database, not the task database.
- Status: Implemented by switching activity GET/POST persistence to chat_db().

## 2026-07-28 - External API Group/Channel Send And Channel Lifecycle
- Requirement: External API documentation must clearly include group/channel message sending plus channel close/archive endpoints for external portals.
- Status: Implemented in server_patch API and documentation.
- Endpoints: POST /api/chat/v1/messages, POST /api/channels/v1/{channel_id}/close, POST /api/channels/v1/{channel_id}/archive, POST /api/channels/v1/{channel_id}/unarchive.

## 2026-07-28 - My Hub Horizon Attendance And Route Timeline
- Requirement: Add My Hub Horizon for employees 116, 232, 302, 428, and 553 to view all employees punched in today, punch in/out times, working hours, and per-employee route timeline from punch-in to punch-out/current time with 30-minute checkpoints.
- Status: Implemented locally; server_patch/chat/myhub.php must be deployed for live data.

## 2026-07-28 - Requirement: Horizon Map And Address Visibility
- Status: Completed
- Request: Horizon employee route must show a real map and the timeline must show readable addresses instead of only latitude/longitude.
- Verification: Backend lint, Horizon screen analyzer, and web release build passed.

## 2026-07-28 - Requirement: Horizon Zoom And Manager Reporting Visibility
- Status: Completed
- Request: Add map zoom in/out and allow non-super users to view self plus employees reporting to them through employee.reporting_to.
- Verification: PHP lint and Horizon Flutter analyzer passed.

## 2026-07-28 - Requirement: Slash Help For Groups And Channels
- Status: Completed
- Request: /help in groups/channels should show available slash commands such as ai and assign with descriptions.
- Verification: Chat screen analyzer completed without new errors.

## 2026-07-28 - Requirement: Horizon Map Drag Movement
- Status: Completed
- Request: Horizon map must move when the user mouse-click-drags the map, not only zoom around the default center.
- Verification: Horizon Flutter analyzer passed.

## REQ-2026-07-28-RELEASE-207
- Request: Build Web, APK, and Windows next version, upload APK/Windows to live server as draft for Employee 302 approval.
- Status: Complete.
- Version: 2.0.7+30.


## 2026-07-29 - High-volume chat history pagination
- Requirement: Make high-message groups/channels faster like WhatsApp/Telegram by loading only recent messages first and loading older messages on scroll-up.
- Change: Added limit and efore_message_id support to chat/history.php, defaulting to 50 messages instead of 1000.
- Change: Updated Flutter ChatApi.getHistory and ChatScreen to fetch latest 50 messages, trim old persisted cache, and lazy-prepend older messages when users scroll near the top.
- Impact: Reduces initial chat payload, first render work, and repeated refresh cost for high-volume support groups/channels.
- Verification: php -l server_patch/chat/history.php passed. lutter analyze lib/chat_api.dart lib/chat/chat_screen.dart completed with existing warnings/info only, no compile errors.
- Updated: 2026-07-29 14:59:38

## REQ-2026-07-29-CHANNEL-TYPE-API
- Status: Complete
- Request: External/API channel creation must respect supplied channel type such as 	ask instead of defaulting to operational.
- Outcome: channel_type is now accepted and preserved by v1 API, chat channel create, external conversation create, and channel update paths. Custom non-core types remain Workspace channels.
- Updated: 2026-07-29 15:37:44 +05:30

## REQ-2026-07-29-SLASH-COMMAND-BEHAVIOR
- Status: Complete
- Request: Add proper behavior/functions for group/channel slash commands instead of only showing comments/help.
- Outcome: Slash commands now route to AI/help/reminder/follow-up UI flows or backend metadata/action handlers.
- Updated: 2026-07-29 16:06:09 +05:30


## REQ-2026-07-29-NEW-CHANNEL-MEMBER-LIST-SCROLL
- Status: Complete
- Request: New channel dialog search shows matching users count but the users list is not visible/scrollable, making member selection impossible.
- Outcome: New group/channel member picker now keeps a visible scrollable users list with a scrollbar and empty state while preserving select-all and create behavior.
- Updated: 2026-07-29 16:40:00 +05:30

## REQ-2026-07-29-BROADCAST-MODAL-PICKER
- Status: Complete
- Request: Broadcast creation must use a proper modal view instead of a bottom drawer, and the member list must not collapse like the channel create dialog issue.
- Outcome: Broadcast opens as a centered modal with bounded height and a dedicated scrollable recipient list.
- Updated: 2026-07-29 17:05:00 +05:30

## REQ-2026-07-29-MYHUB-SUGGESTIONS-COMPLAINTS
- Status: Complete
- Request: Add MyHub Suggestions & Complaints where users can select the target user, submit suggestion/complaint with category/priority/subject/message/files, and the selected user can see it in their list.
- Outcome: Added MyHub UI, ChatApi methods, and chat DB-backed myhub.php section using suggestion_complaints with assigned user visibility.
- Updated: 2026-07-29 17:45:00 +05:30

## REQ-2026-07-29-CHAT-LIST-NEXT-ACTION-BADGE
- Status: Completed
- Request: Chat list next-action badge should not show the literal "NEXT ACTION" text; it should show only the assigned person/name, flex to the name length, and include the next-action date/time.
- Scope: Flutter web/app chat list UI only.

## REQ-2026-07-29-WEB-BUILD-NEXT-ACTION-BADGE
- Status: Completed
- Request: Produce a web release build after the chat-list next-action badge UI update.
- Scope: Flutter web release build.

## REQ-2026-07-29-DIRECT-USER-SEND-API
- Status: Completed
- Request: Add an external API to send one-to-one messages between Flow users without requiring browser session authentication.
- Scope: Versioned external API under `/api/chat/v1`.

## REQ-2026-07-29-DIRECT-MESSAGE-API-404-FALLBACK
- Status: Completed
- Request: Resolve HTTP 404 when calling the direct one-to-one message API from Postman.
- Scope: External API route compatibility.

## REQ-2026-07-29-DIRECT-MESSAGE-POSTMAN-BODY-FALLBACK
- Status: Completed
- Request: Direct user message API returned `recipient_emp_id is required` even when Postman body contained the field.
- Scope: External direct message API input parsing.

## REQ-2026-07-30-DIRECT-MESSAGE-VALIDATION-DIAGNOSTIC
- Status: Completed
- Request: Diagnose why Postman direct message API returns `recipient_emp_id is required` even with a visible JSON body.
- Scope: External direct message API validation/debug behavior.

## REQ-2026-07-30-DIRECT-MESSAGE-PHYSICAL-HANDLER
- Status: Completed
- Request: Fix persistent `recipient_emp_id is required` from Postman direct message API despite correct JSON body.
- Scope: Physical fallback API route.

## REQ-2026-07-30-DIRECT-SEND-PHYSICAL-ENDPOINT
- Status: Completed
- Request: Persistent validation error on `/api/chat/v1/direct/messages` after uploading API folder; provide a reliable endpoint that bypasses routing/cache ambiguity.
- Scope: External direct message physical endpoint.

## REQ-2026-07-30-DIRECT-SEND-LIVE-API-VERIFY
- Status: Completed
- Request: Verify whether the one-to-one direct send API works on the live server.
- Scope: Live HTTP API test.

## REQ-2026-07-30-NEXT-ACTION-REMINDER-POLL
- Status: Completed
- Request: Send a reminder one hour before channel next-action due time and post a completion poll after the due time passes.
- Scope: Channel next-action backend monitor and existing notification worker integration.

## REQ-2026-07-30-TASK-CREATE-PHYSICAL-ENDPOINT
- Status: Completed
- Request: Task create API returns task list even when Postman sends POST, so provide a reliable create endpoint.
- Scope: External Tasks API physical create route.
- [2026-07-30] REQ-SHARE-ANDROID-INBOUND: Android external share sheet must list Flow for text/files/images/videos/audio and route shared content to a selected user/group/channel.

## REQ-VIDEO-ATTACHMENT-SEND-20260730
- Date: 2026-07-30 16:53:00
- Status: Completed
- Request: Users must be able to select and send video files reliably from Flow chat.
- Scope: Flutter chat attachment picker and native upload path.

- 2026-07-30 | REQ-BUILD-208 | COMPLETE | Next version Web and APK release build requested and produced as v2.0.8+31.

- 2026-07-30 | REQ-DEPLOY-208 | COMPLETE | Move v2.0.8+31 Web/APK artifacts to live server downloads and register Android draft for employee 302 approval.

## REQ-2026-07-31-VIDEO-UPLOAD-LIMIT
- Status: Completed
- Request: Video file upload shows Upload failed with code 1 and cannot send.
- Outcome: Server upload limit patch added for large video/file uploads; upload errors now return readable diagnostics with PHP limits.

## REQ-2026-07-31-TELEGRAM-STYLE-UPLOAD-UX
- Status: Completed
- Request: Video/files should appear in chat immediately like Telegram, then upload in the background with a better UI.
- Outcome: Added optimistic attachment bubbles with per-file upload progress, file/video icons, pending state, and failed state.

## REQ-2026-07-31-CHAT-UPLOAD-50MB
- Status: Implemented
- Requirement: Flow chat must support files and videos up to a maximum of 50 MB and keep upload timeout long enough for slower networks.
- Scope: Chat attachment validation, server upload guard, PHP upload/runtime limits, attachment transfer timeout.

## REQ-2026-07-31-LMS-LEAD-WEBHOOK
- Status: Implemented
- Requirement: Flow must POST participant messages from LMS-created lead channels to the LMS webhook with stable message IDs and tenant slug.
- Scope: Backend send-message hook, async queue, retry worker, server-local secret config, LMS sync documentation.

## 2026-07-31 - Attachment upload read fallback
- Requirement: Users must be able to upload regular files from Android/Desktop pickers even when the picker returns only a native file path and no in-memory bytes.
- Scope: Chat attachment send flow.
- Status: Fixed in code; analyzer smoke-check completed.

## 2026-07-31 - Horizon all-employee map view
- Requirement: Horizon must show all visible employees on one map using last known coordinates, with pin/name selection opening that employee's full-day timeline.
- Status: Implemented in UI.

## 2026-07-31 - Broadcast send failure
- Requirement: Broadcast send must complete without generic Unable to send failures.
- Status: Backend send flow fixed in patch.

## REQ-20260801-HORIZON-SEPARATE-LIVE-VIEW
- Date: 2026-08-01
- Request: Move Horizon all-employees live view to a separate page, restore visible employee markers using latest coordinates, and fix corrupted forwarded/file preview text in chat list.
- Status: Implemented in local code; deployment/build not requested in this turn.

- 2026-08-01 | Chat | Fixed duplicate next-action due prompt send and cursor-aware mid-text @mention detection | Files: server_patch/chat/next_action_monitor_helpers.php, lib/chat/chat_screen.dart | Verify: php -l helper, flutter analyze lib/chat/chat_screen.dart

- 2026-08-01 | Notifications | Punch in/out and location-off notifications must be muted; actual DM/group/channel messages remain normal.

- 2026-08-01 | External API | Fix versioned channel close/delete routes so noun-prefixed paths like /api/channels/v1/channels/{id}/close resolve correctly.

## REQ-20260801-EXTERNAL-CHANNEL-BODY-CLOSE
- Date: 2026-08-01 20:10:00 +05:30
- Request: External API channel close/archive should work even when path-based lifecycle routes return live 404. Support passing channel ID or room JID in request body.
- Status: Implemented in server patch; validation complete; live deployment still required.


## REQ-20260801-PHYSICAL-CHANNEL-ACTION-ENDPOINT
- Date: 2026-08-01 20:25:00 +05:30
- Request: Provide a non-dispatch external API for channel lifecycle actions because base /channels/v1 still falls back to channel listing on live.
- Status: Implemented with physical endpoint files; validation complete; deploy pending.


## REQ-20260801-WEB-FILE-PICKER-UPLOAD
- Date: 2026-08-01 21:15:00 +05:30
- Request: Chat la drag-drop and copy/paste work aagudhu, aana normal file select panni send panna mudiyala. Manual file picker selection also must upload the chosen attachments safely.
- Status: Implemented in local code; validation completed.

## REQ-20260801-COMPOSER-UPLOAD-LATENCY
- Date: 2026-08-01 22:05:00 +05:30
- Request: Reduce / and @ trigger latency in the middle of composer text, improve manual file-picker/share attachment preparation, and address live video/file upload failures caused by server limits.
- Status: Implemented in local code and server patch config; live server still needs hidden config deployment for the larger upload limit to take effect.

## 2026-08-01 - Telegram-style attachment UX patch
- Requirement: show attachment UI immediately in chat, then continue upload in background.
- Requirement: render video attachments inline in chat on web instead of generic file-only fallback when preview data is available.
- Requirement: open video attachments inside Flow with a real in-app preview surface on web.

## REQ-20260801-ATTENDANCE-CALENDAR-STATE-COLORS
- Date: 2026-08-01 22:45:00 +05:30
- Request: Attendance calendar la punch days-ku mattum green tick irukkanum; week off, no-punch past dates, future dates ellam separate visual states-la kaattanum.
- Status: Implemented in local code; analyzer validation completed.

## REQ-20260801-LEAVE-TYPE-OTP-ALIGNMENT
- Date: 2026-08-01 23:20:00 +05:30
- Request: Leave apply screen la `Leave` and `Comp Off` mattum show aaganum; leave OTP testing-ku employee 302-ku poganum; `track_leave_request` insert structure screenshot schema-oda align aaganum.
- Status: Implemented in local code and server patch; validation completed.

## REQ-20260801-RELEASE-2-0-9
- Date: 2026-08-01 17:55:00 +05:30
- Request: Build fresh web and APK artifacts, move the APK to the live server, and register it as a draft release so employee 302 can approve rollout for all users.
- Status: Implemented. Web and APK builds completed, APK uploaded to live server, and Android draft registered successfully.

## REQ-20260803-WEB-PUNCH-SHIFT-FALLBACK
- Date: 2026-08-03 18:20:00 +05:30
- Request: Web punch-in screen la shift dropdown empty ah irukku; user attendance punch-in block aagudhu.
- Status: Implemented.

## REQ-20260803-WEB-PUNCH-SHIFT-PROXY
- Date: 2026-08-03 21:10:00 +05:30
- Request: Web punch-in screen la APK maari full shift list varanum; external shift service browser-la block aaguradha avoid pannanum.
- Status: Implemented with same-origin shift proxy and fresh web build.


## REQ-20260803-LMS-LEAD-WEBHOOK-FORWARDING
- Date: 2026-08-03 22:05:00 +05:30
- Request: LMS lead channels-la participant real messages varumbodhu Flow webhook forward pannanum; payload-la 	enant_slug, stable message_id, channel_id, 
oom_jid, numeric-employee based sender_jid, sender_name, ody irukkanum; 5xx/network retry, 4xx permanent fail.
- Status: Implemented in local server patch. Live deployment still requires the real LMS bearer token in server_patch/chat/lms_webhook_config.php or server env.
## REQ-20260803-ARCHIVE-STORAGE
- Request: Implement Flow Archive Storage with pluggable providers, Google Drive archive integration, admin archive management, archive policies/jobs, and unified archived search/streaming.
- Scope: Archive backend foundation, standalone admin management, archived search endpoint, archived manifest streaming, and schema/bootstrap support.
- Status: In progress foundation delivered; provider/job/search/stream path implemented without live OAuth verification in local sandbox.

## REQ-20260803-VOICE-AUDIO-VIDEO-PLAYBACK
- Date: 2026-08-03 23:40:00 +05:30
- Request: Voice recording upload aagudhu but 00:00 duration nala play aagala; audio file chat bubble-kulla play aaganum with download option; mobile video preview/playback work aaganum.
- Status: Implemented in local code and server patch; analyzer confirmed no new build-blocking errors.

## REQ-20260803-HORIZON-LATENCY-MAP-UX
- Date: 2026-08-03 23:58:00 +05:30
- Request: Horizon screen open aaguradhu slow ah irukku; selected employee timeline timeout aagudhu; map preview zoom/pan feel smoother and more Google Maps-like aaganum.
- Status: Implemented in local code and server patch; validation completed.

## REQ-20260803-MESSAGE-EDIT-INSTANT-REFRESH
- Date: 2026-08-03 23:59:00 +05:30
- Request: When a message is edited, the changed text should update immediately in the open chat screen without leaving and reopening the conversation.
- Status: Implemented in local code; validation completed.
