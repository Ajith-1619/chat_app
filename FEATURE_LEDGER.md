
## FEATURE-RELEASE-MANAGEMENT-DRAFT-ANDROID-2.0.4
- Date: 2026-07-15
- Area: Release Management
- Platform: Android, Web artifact generated locally
- Status: Draft registered for Android; web package generated locally


## FEAT-ATTACHMENT-RESTRICTED-VIEW
- Date: 2026-07-16 11:42:08
- Restricted attachment flag added to chat attachment model, send flow, history response, backend persistence, preview UI, and media download guard.
- Unrestricted attachments expose Download and Open with actions.
- Status: Implemented.


## FEAT-SAVED-MESSAGES-FORWARD-PASTE
- Date: 2026-07-16 11:56:28
- Added Saved Messages as a first-class forward target.
- Saved forward uses saved message storage instead of normal chat send.
- Saved Messages supports clipboard media paste through existing web bridge, explicit text paste shortcut, multi-file attach, and desktop drag/drop save.
- Fixed duplicate saved checklist/poll creation.


## FEATURE-20260716-FLOW-MASTER-ADMIN
- Date: 2026-07-16 15:34:05 +05:30
- Feature: Standalone Flow Master Admin web app under admin/.
- Capabilities: Super-admin login, overview metrics, users, groups/channels, messages, files, tasks, location, notifications, releases, diagnostics, audit log, CSRF-protected audited admin actions.
- Access: Employee IDs 302 and 116 only by default.

## FEATURE-20260720-GROUP-CHANNEL-CREATOR-POLICY
- Date: 2026-07-20
- Area: Group and Channel Management
- Capability: Employee type policy blocks C1/C2 users from creating groups/channels while preserving A/B access.
- Status: Implemented.

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

## 2026-07-24 11:53:02 - Versioned External API Layer
- Added server_patch/api with /{module}/v1 endpoints and shared bootstrap dispatch.
- Modules: chat, users, groups, channels, tasks, reminders, notifications, files, attendance, location, releases, diagnostics.


## 2026-07-24 12:18:16 - Flow API v1 Expanded Modules
- Added modules: search/v1, saved/v1, ai/v1, external-users/v1, storage/v1, polls/v1, checklists/v1.
- Expanded chat/group/channel/files/location/attendance/releases handlers with action endpoints.


## 2026-07-24 12:34:54 - External API Documentation Catalogue
- Documented auth, scopes, standard responses, JID formats, Postman setup, and all implemented module endpoint examples.


## 2026-07-24 12:49:18 - Plugin Hooks And SDK
- Added FlowPluginEventBus with hook registry, permission/data declarations, plugin event/error/artifact logging, and safe execution wrappers.
- Added auto-translate example plugin using message.received only through hook system.


## 2026-07-24 13:10:00 - Chat Selection Freeze Refinement
- Refined web chat selection mode to block pending forced auto-scroll callbacks while a message text selection is active.
- Extended the initial selection lock window so first-drag text selection is less likely to be interrupted by polling or delayed scroll retries.

## 2026-07-24 14:53:05 +05:30 - Web Message Selection Interaction
- Message text now starts selection freeze on drag movement instead of every pointer down/click.
- Selection finish now recalculates scroll position so the jump-to-latest button can reappear after selection mode ends.

## 2026-07-24 - Selectable Chat Bubble Text
- Feature: Web/Desktop chat bubbles use SelectableText.rich with parent swipe/long-press gestures disabled only for plain text bubbles on pointer platforms.
- Preserved: Mobile long press/swipe, right-click menu, attachments, read more, formatted spans, message info and actions.

## 2026-07-24 15:55:18 - Chat Text Selection
- Feature: Native-style selectable message text on Web/Desktop.
- Behavior: Text selection and Ctrl+C are prioritized for plain text bubbles while existing right-click message actions remain available; mobile swipe and long-press behavior is preserved.


## 2026-07-24 15:55:36 +05:30 - Feature Update: Native Message Text Selection
- Feature: Chat message bubbles now allow native SelectableText drag selection on web/desktop for sent, received, formatted, and long messages.
- Preserved: Right-click actions, attachments, previews, read more, and mobile long-press/swipe behavior.


## 2026-07-24 16:45:46 +05:30 - Chat Selection Stability
- Feature: Chat message text selection and copy on Flutter Web/Desktop.
- Status: Updated. Parent bubble gestures no longer compete with selectable message text; manual chat scrolling remains enabled.

## 2026-07-24 17:24:54 +05:30 - Channel Operational Badge
- Feature: Channel list next-action person badge.
- Status: Added to home/channel list UI and wired to recent chat API metadata.

## 2026-07-24 18:00:10 +05:30 - Release Management
- Feature: Android draft release flow.
- Status: v2.0.5+28 APK built, uploaded, and registered as Draft for 302 approval.

## 2026-07-24 - AI API User Room Controls
- Added Flutter AI API screen for assigned users.
- Added backend endpoint patch chat/ai_access.php for access checks and room AI enable/disable.


## 2026-07-25 - AI API Access Management
- Added API Access management screen for employee 302.
- Added user assignment endpoint for AI access.
- Updated AI API room endpoint so users require explicit assignment before seeing AI API menu.


## 2026-07-25 - Channel Profile And Folder Management
- Feature: Mobile channel profile now exposes operational metadata from ChannelProfile.
- Feature: Chat folders screen now shows default filters (All, Unread, Online, Personal, Groups, Channels, Starred) and supports editing custom folders.
- Feature: Reply-message jump now temporarily highlights the target bubble.

## 2026-07-25 - Performance Stabilization
- Feature: Reduced Android history prefetch burst size and frequency.
- Feature: Cached diagnostic app/device metadata per API client session.
- Feature: Moved AI room reply generation out of synchronous send-message response path.

## 2026-07-25 - Persistent Chat Folders
- Feature: Chat folders are loaded/saved through backend API instead of local SharedPreferences.
- Feature: Folder edit/delete/reorder saves to DB and appears in the main filter strip after default filters.
- Feature: Existing local folders migrate once to DB when backend has no folders.

## 2026-07-25 - Mobile Composer Responsive Cleanup
- Feature: Mobile chat composer now uses compact responsive sizing for small screens.
- Feature: Composer visible B button removed; formatting remains available through the text selection context menu.
- Feature: Mobile multiline composer growth is capped lower to avoid oversized input area while typing.


## 2026-07-25 - Enter To Send User Setting
- Feature: Added Appearance setting named Enter sends message.
- Feature: Composer keyboard behavior now follows the saved user preference in SharedPreferences.
- Feature: Open chat composer reacts through appEnterToSend ValueNotifier without requiring app restart.


## 2026-07-25 - v2.0.6 Web APK Build And Android Draft
- Feature: Release artifacts refreshed for v2.0.6+29.
- Feature: Android release build is staged as Development/Draft with rollout 0% and force update disabled.
- Feature: Web build output refreshed under build/web and packaged as release ZIP.


## 2026-07-27 - Full View Image Preview
- Feature: Image attachment preview now uses a full-viewport viewer with black backdrop instead of a centered boxed preview.
- Feature: Pinch/zoom and pan now operate against the full preview area for a more natural media-viewer experience.

## 2026-07-27 - Android Public Download Visibility
- Feature: Android attachment downloads now save to public Pictures/Skylink, Movies/Skylink, Music/Skylink, or Downloads/Skylink based on file type.
- Feature: Saved-message downloads now use the same permission and public-save flow as normal chat attachments.
- Feature: Modern Android devices avoid the old misleading app-storage fallback warning when public save does not need runtime storage permission.

## 2026-07-27 13:00:45 - Chat List Workspace Filter
- Feature: Chat filter strip now separates core channels from custom workspace channels using channel kind metadata.
- Core channel kinds: incident, action, operational, project, announcement.


## 2026-07-27 13:10:59 +05:30 - Attachment Preview Metadata
- Feature: Recent conversation preview now supports last-file metadata from chat APIs and renders attachment-specific preview labels/icons in the conversation list and chat folder list.


## 2026-07-27 14:50:32 +05:30 - Broadcast Messaging
- Feature: Added text-only Broadcast compose flow with searchable multi-recipient selection, Type A UI gate, backend Type A enforcement, broadcast audit tables, direct-message fan-out, XMPP delivery attempt, and push queue integration.


## 2026-07-27 - Broadcast Lists
- Added saved broadcast list management for Type A users: named lists, recipient selection updates, soft delete, and send using saved recipients.


## 2026-07-27 - Conversation Metadata Engine
- Added metadata definition/value/event tables for typed fields including channel type, status, priority, previous action, next action, owner, participants and extensible custom metadata definitions.
- Added slash command discovery for /ai, /update, /assign, /decision, /meeting, /action, /followup, /reminder, and /tags in the chat composer.


## 2026-07-27 - Employee Event Notifications
- Added daily employee celebration notifications for birthdays and work anniversaries using the System Notifications conversation.
- Notifications are sent to every active employee and tracked per event/date/employee/recipient to avoid duplicate daily sends.


## 2026-07-27 - Next Action Summary And Clarification
- Feature: Channel action detection now stores next_action_summary with the detected next action metadata.
- Feature: Missing next action person/date creates a structured Flow MCO clarification card in the channel conversation.
- Feature: Clarification cards can be opened from chat to update summary, owner, and date through a dedicated API endpoint.


## 2026-07-27 - Wake-up Last Message Summary
- Feature: Wake-up notifications now append a readable last message summary for text, files, photos, videos, audio, locations, checklists, polls, and Flow MCO clarification messages.


## FEATURE-20260728-NOTIFICATION-HISTORY-AND-BROADCAST-ACCESS
- Date: 2026-07-28 10:25:00 +05:30
- System Notifications now use the server history/read path on web so persisted DB notifications are visible and read-state updates run.
- Broadcast creation entry now defers permission enforcement to the backend employee-type override instead of cached Flutter profile state.
## FEATURE-20260728-SLASH-COMMAND-AI
- Date: 2026-07-28 10:55:00 +05:30
- Composer now updates slash command query state on every text change so /, /a, /ai can show the command picker.
- Channel/group AI trigger now accepts configured trigger plus /ai and legacy @ai.
## FEATURE-20260728-NEXT-ACTION-DATE-PARSER
- Date: 2026-07-28 11:10:00 +05:30
- Next action parser now understands end/last of this month, month end, end of next month, and next month end.
- Next action date is cleared when the new actionable message does not include a date, so the right panel cannot show an old stale date.
## FEATURE-20260728-CONTEXT-AWARE-ACTION-ENGINE
- Date: 2026-07-28 11:35:00 +05:30
- Added stricter actionable-message detection to avoid normal conversation becoming next action.
- Added last-20-message context scan with up to five recent actionable messages summarized into the current next action.
- Added previous_action_text persistence on channels and channel profile payload support.
- Missing person/date continue to be stored as next_action_missing_fields and generate Flow MCO clarification messages.
## 2026-07-28 - Feature: Type A Effective Group/Channel Admin
- Type A employee access now upgrades group/channel membership authority to admin without requiring manual per-room role edits.
- Owner role remains preserved above admin.
- Admin employee type update promotes existing member rows to admin.

## 2026-07-28 - Feature: My Activity
- Added My Hub tile and screen for logging daily work activity.
- Supports activity type dropdown, optional file upload, description, start/end time, and current-month history list.

## 2026-07-28 - External API Channel Lifecycle
- Feature: Versioned API now documents and supports external group/channel message send using room JID and explicit channel close/archive/unarchive actions.
- User Value: External portals can post into Flow groups/channels and manage channel lifecycle without using internal chat UI APIs.

## 2026-07-28 - Horizon
- Feature: My Hub Horizon attendance visibility dashboard.
- Access: Restricted to employee IDs 116, 232, 302, 428, and 553.
- Capabilities: Today punched-in employee list, punch times, running/closed working hours, route view with start marker, last/end marker, and half-hour timeline checkpoints.

## 2026-07-28 - Feature: My Hub Horizon Map Address Timeline
- Status: Updated
- Capability: Authorized Horizon users can open an employee route with map tiles, route markers, 30-minute checkpoints, and address-aware timeline details.

## 2026-07-28 - Feature: Horizon Scoped Team Visibility
- Status: Updated
- Capability: Horizon supports super-admin all-employee monitoring and manager/direct-report scoped monitoring with interactive map zoom.

## 2026-07-28 - Feature: Flow Command Guide
- Status: Added
- Capability: Group/channel users can type /help to view supported Flow slash commands and descriptions.

## 2026-07-28 - Feature: Interactive Horizon Map Pan
- Status: Added
- Capability: Horizon route map supports pan, zoom buttons, and mouse-wheel zoom for map inspection.

## FEAT-2026-07-28-MULTI-PLATFORM-DRAFT
- Multi-platform release artifacts generated for Web, Android, and Windows.
- Android and Windows registered as Draft releases for 302 approval.
- Status: Complete.


## 2026-07-29 - High-volume chat history pagination
- Requirement: Make high-message groups/channels faster like WhatsApp/Telegram by loading only recent messages first and loading older messages on scroll-up.
- Change: Added limit and efore_message_id support to chat/history.php, defaulting to 50 messages instead of 1000.
- Change: Updated Flutter ChatApi.getHistory and ChatScreen to fetch latest 50 messages, trim old persisted cache, and lazy-prepend older messages when users scroll near the top.
- Impact: Reduces initial chat payload, first render work, and repeated refresh cost for high-volume support groups/channels.
- Verification: php -l server_patch/chat/history.php passed. lutter analyze lib/chat_api.dart lib/chat/chat_screen.dart completed with existing warnings/info only, no compile errors.
- Updated: 2026-07-29 14:59:38

## FEAT-CHANNEL-TYPE-PRESERVATION
- Status: Complete
- Area: External APIs, channel creation, workspace classification.
- Behavior: channel_type, channel_kind, 	ype_key, and kind aliases normalize to a stored xmpp_groups.channel_kind; unknown/custom values no longer fall back to operational.
- Updated: 2026-07-29 15:37:44 +05:30

## FEAT-SLASH-COMMANDS
- Status: Complete
- Area: Chat composer, group/channel metadata, reminders/follow-ups.
- Behavior: /help opens guide, /ai triggers AI, /reminder and /followup open creation flow, /update /decision /meeting /tags update metadata, /assign /action /followup /reminder update next-action behavior through backend.
- Updated: 2026-07-29 16:06:09 +05:30


## FEAT-CHANNEL-MEMBER-PICKER
- Status: Complete
- Area: New group/channel creation.
- Behavior: Member search results remain selectable inside a dedicated scrollable list even when channel description/type/priority fields are visible.
- Updated: 2026-07-29 16:40:00 +05:30

## FEAT-BROADCAST-MODAL-PICKER
- Status: Complete
- Area: Broadcast creation and recipient selection.
- Behavior: Broadcast list/name/message/search/select-all/send controls are shown in a centered modal, while recipients remain scrollable with an empty state.
- Updated: 2026-07-29 17:05:00 +05:30

## FEAT-MYHUB-SUGGESTIONS-COMPLAINTS
- Status: Complete
- Area: MyHub feedback workflow.
- Behavior: Users can submit suggestions or complaints to a selected employee; sender and selected receiver can see the item list; attachments up to 5 files are supported.
- Updated: 2026-07-29 17:45:00 +05:30

## FEAT-CHAT-LIST-NEXT-ACTION-BADGE
- Status: Completed
- Summary: Channel chat list next-action indicator now renders a compact owner/date pill instead of the old fixed text label.
- Files: lib/home/home_screen.dart

## FEAT-WEB-BUILD-NEXT-ACTION-BADGE
- Status: Completed
- Summary: Generated the web release artifact with base href `/chat/` for server deployment.

## FEAT-DIRECT-USER-SEND-API
- Status: Completed
- Summary: External portals can send and fetch direct one-to-one messages by employee ID using API-key authentication.
- Endpoint: POST/GET `/api/chat/v1/direct/messages`.

## FEAT-DIRECT-MESSAGE-API-PHYSICAL-ROUTE
- Status: Completed
- Summary: Added a physical fallback route for `/api/chat/v1/direct/messages` so the endpoint works even when Apache rewrite/PATH_INFO is not forwarding.

## FEAT-DIRECT-MESSAGE-POSTMAN-COMPATIBILITY
- Status: Completed
- Summary: Direct message API now accepts JSON, form-data, x-www-form-urlencoded, query aliases, and alternate field names for sender/recipient/message.

## FEAT-DIRECT-MESSAGE-BODY-DIAGNOSTICS
- Status: Completed
- Summary: Direct message API now parses raw JSON locally, falls back to form/query input, accepts aliases, and returns safe debug fields when required input is missing.

## FEAT-DIRECT-MESSAGE-PHYSICAL-HANDLER
- Status: Completed
- Summary: `/api/chat/v1/direct/messages/index.php` now handles GET/POST direct messages itself instead of only forwarding to the shared dispatcher.

## FEAT-DIRECT-SEND-PHYSICAL-ENDPOINT
- Status: Completed
- Summary: Added `/api/chat/v1/direct_send.php`, a rewrite-independent direct one-to-one message API endpoint.

## FEATURE-2026-07-30-NEXT-ACTION-MONITOR
- Status: Implemented
- Area: Channel operations / Flow Marshal
- Summary: Monitors channel next-action metadata, sends due reminders, and creates completion polls without duplicating messages.

## FEATURE-2026-07-30-TASK-CREATE-PHYSICAL-ENDPOINT
- Status: Implemented
- Area: External API / Tasks
- Summary: Added `/api/tasks/v1/create.php` as a POST-only task create endpoint with robust JSON/form/query parsing and debug marker.
- [2026-07-30] FEAT-SHARE-ANDROID-INBOUND: Added native Android ACTION_SEND/ACTION_SEND_MULTIPLE bridge, Flow target picker, and ChatScreen pending-share attachment preview flow.

## FEAT-VIDEO-ATTACHMENT-SEND
- Status: Completed
- Feature: Photo/video picker and native large-file streaming upload for attachments.
- Platforms: Android/native, Web unchanged.

- 2026-07-30 | FEAT-RELEASE-BUILD | COMPLETE | Generated Flow Messenger Web and Android APK release artifacts for v2.0.8+31.

- 2026-07-30 | FEAT-RELEASE-GOVERNANCE | COMPLETE | v2.0.8+31 artifacts uploaded to live downloads; Android draft release registered without production exposure.

## FEATURE-2026-07-31-CHAT-UPLOAD-50MB
- Status: Implemented
- Feature: 50 MB attachment/video upload policy.
- Behavior: Files/videos over 50 MB are rejected before preview/send on the client and by the server if bypassed.

## FEATURE-2026-07-31-LMS-LEAD-WEBHOOK
- Status: Implemented
- Feature: Bidirectional LMS lead timeline sync from Flow participant messages.
- Behavior: Real participant text messages in LMS lead channels are queued and delivered to LMS; LMS/API/system messages are skipped.

## 2026-07-31 - Attachment upload reliability
- Feature area: Chat attachments
- Update: Added native-path byte fallback for non-streamed uploads so picker/share sourced files can still enter the normal upload pipeline.
- User impact: Prevents premature Unable to read <file> failures before upload starts.

## 2026-07-31 - Horizon overview drilldown
- Added a shared all-employee Horizon map with named markers, quick employee chips, inline selected-user route/timeline drilldown, and retained full-screen route view.

## 2026-07-31 - Broadcast reliability
- Broadcast send flow now preserves/derives a valid title during send requests so saved lists can be updated and sent without PHP runtime failure.

## FEAT-20260801-HORIZON-LIVE-VIEW-PAGE
- Added a separate Horizon all-employees live view entry point instead of embedding the overview map inside the main Horizon page.
- Horizon employee payload now carries latest location metadata for overview markers.
- Chat preview text now uses readable attachment labels instead of corrupted placeholder glyphs.

- 2026-08-01 | Chat composer mentions | Active @mention detection follows cursor position instead of only end-of-text.

- 2026-08-01 | Notification routing | Added muted operational-info notification path for punch/location alerts on Android push/local notifications.

- 2026-08-01 | External channel lifecycle API | Channel close/archive and delete now support both noun-prefixed and compact versioned paths.

## FEAT-20260801-WEB-FILE-PICKER-BYTES
- Added a dedicated web browser file-picker bridge so manual attachment selection reads browser File bytes directly before upload.
- Manual file select now uses the same reliable byte-loading path as drag/drop and clipboard paste.

## FEAT-20260801-COMPOSER-UPLOAD-LATENCY
- Composer slash and mention suggestions now use cursor-aware token parsing instead of full-text regex matching.
- Web picker, Android share, and drag/drop attachment preparation now convert selected files in parallel for lower wait time before preview/send.
- Chat upload server patch now includes both .user.ini and .htaccess limit configuration for 50MB attachment support.

## 2026-08-01 - Attachment Preview Enhancements
- Added local preview metadata support for optimistic image/video attachments.
- Added inline video bubble rendering path for web using embedded HTML video.
- Added in-app video preview screen support for uploaded and pending video attachments.

## FEAT-20260801-ATTENDANCE-CALENDAR-STATE-COLORS
- Attendance month grid now classifies each day as punched, week off/holiday, missed, or future.
- Punch days keep the green success indicator, week off/holiday uses a separate amber state, missed past days use a distinct alert state, and future days stay muted.

## FEAT-20260801-LEAVE-TYPE-OTP-ALIGNMENT
- Leave application dropdown now exposes only `Leave` and `Comp Off`.
- Leave OTP flow now targets the configured testing approver employee and persists OTP / approver fields when those columns exist in `track_leave_request`.

## FEAT-20260801-RELEASE-2-0-9
- Version updated to `2.0.9+32` for the next release cycle.
- Added draft registration script `server_patch/register_draft_2_0_9.php` for Android release registration.
- Added release deploy helpers `tool/deploy_2_0_9.ps1` and `tool/deploy_2_0_9.psftp` for APK artifact upload.

## FEAT-20260803-WEB-PUNCH-SHIFT-FALLBACK
- Attendance profile screen now loads the employee profile even in punch-in mode.
- When live shift list fetch is unavailable, the assigned employee shift is shown as a fallback dropdown option instead of leaving the menu empty.

## FEAT-20260803-WEB-PUNCH-SHIFT-PROXY
- Attendance shift list now loads through chat/attendance.php so web browsers use the same-origin chat backend instead of a direct cross-site call.
- Assigned-shift fallback remains in place when the remote shift service returns no data.


## 2026-08-03 - LMS lead webhook forwarding hardening
- Feature: LMS lead-channel outbound webhook queue now normalizes sender JIDs to numeric employee-id localparts, keeps both channel id and room JID in payload, and preserves existing queued retry delivery.
## FEAT-20260803-ARCHIVE-STORAGE
- Added Flow Archive Storage foundation with provider catalog, archive policies, archive jobs, archived item manifests, and admin management UI.
- Added archived search + archived conversation stream endpoints so archived conversations can remain searchable and readable without restoring to active storage.
- Google Drive is the first concrete provider path; other providers are modeled through the shared provider architecture for future extension.

## FEAT-20260803-VOICE-AUDIO-VIDEO-PLAYBACK
- Voice-note attachments now carry `duration_ms` from recorder -> API -> DB -> history so playback duration survives reload.
- Audio attachments now render with an inline in-chat player and download/open actions instead of only a generic file tile.
- Non-web video preview now uses a real `video_player` surface so mobile video attachments can open and play inside Flow.
- Web audio preview now streams from attachment bytes via object URLs, which keeps encrypted/restricted media playable inside Flow without exposing raw server URLs.


## FEAT-20260803-HORIZON-LATENCY-MAP-UX
- Horizon attendance load now uses a batched latest-location fetch instead of one location query per employee.
- Horizon timeline keeps address enrichment bounded so route/timeline loads do not stall on many reverse-geocode lookups.
- Horizon overview and employee route maps now zoom around the mouse pointer, keep more nearby map tiles warm, and support smoother drag/pan exploration on web/desktop.


## FEAT-20260803-MESSAGE-EDIT-INSTANT-REFRESH
- Message edit flows now update the visible chat list by stable message id instead of depending on the original ChatMessage object instance.
- Edited normal messages, checklists, and polls now repaint immediately in the open conversation after save.

## FEATURE-20260804-HORIZON-SPLIT-LOAD
- Date: 2026-08-04
- Area: My Hub Horizon
- Capability: Main Horizon page now loads attendance/employee visibility first, while all-employees live map fetches location-enriched payload on demand.
- Status: Implemented.
## FEATURE-20260804-ARCHIVE-PROVIDER-SETUP-HARDENING
- Date: 2026-08-04
- Area: Admin Archive Storage
- Capability: Provider save flow now handles insert/update placeholders correctly and supports cleaner Google Drive onboarding.
- Status: Implemented.

## FEATURE-20260804-ARCHIVE-WORKER-EXECUTION
- Date: 2026-08-04
- Area: Archive Storage
- Capability: Archive worker now boots from the standard chat runtime on live deployments and falls back to the admin standalone bootstrap for exported/local contexts.
- Status: Implemented.

## FEATURE-20260804-ARCHIVE-LIVE-GROUP-COMPAT
- Date: 2026-08-04
- Area: Archive Storage
- Capability: Archive policy scheduler and group label resolution now use the live `xmpp_groups.room_name` label shape.
- Status: Implemented.

## FEATURE-20260804-ARCHIVE-SCHEMA-COMPAT
- Date: 2026-08-04
- Area: Archive Storage
- Capability: Archive scheduling now detects available `xmpp_groups` columns dynamically and works across legacy and live schemas.
- Status: Implemented.

- `FEATURE-20260804-ARCHIVE-PDO-COMPAT` Archive manifest and participant queries now use unique named parameters for PDO compatibility across live MySQL/PHP environments.

- `FEATURE-20260804-ARCHIVE-MANUAL-QUEUE-NOW` Manual archive queueing now defaults to database `NOW()` instead of PHP local time when no schedule is supplied.

- `FEATURE-20260804-ARCHIVE-LEGACY-QUEUE-AUTO-REPAIR` Archive worker now normalizes legacy manual queued jobs whose `scheduled_at` was incorrectly saved in the future.

- `FEATURE-20260804-ARCHIVE-SCHEMA-SAFE-REACTION-ORDER` Archive reaction extraction now builds its `ORDER BY` clause from the columns actually present in `xmpp_message_reactions`.

- `FEATURE-20260804-ARCHIVE-PARTICIPANT-FALLBACK` Archive participant discovery now falls back to parsing numeric employee IDs from direct-message JIDs when `sender_emp_id` is unavailable.

- `FEATURE-20260804-ARCHIVE-GROUP-MEMBER-FALLBACK` Archive worker now resolves group participants through `xmpp_group_members.room_jid` or `xmpp_group_members.group_id` depending on the live schema.

## FEAT-20260804-SAVED-MESSAGES-DRIVE-OFFLOAD
- Date: 2026-08-04
- Feature: Saved Messages can offload text/file payloads to Google Drive using the existing archive provider connection.
- Notes: Files are streamed back through Flow via chat/saved_message_stream.php; API contract for Flutter remains unchanged.

- 2026-08-04: Saved Messages Drive-backed storage now tolerates legacy malformed text/file metadata and supports forwarded attachment URLs that arrive through media/path wrappers before offload or DB fallback.

## 2026-08-05 Saved Messages schema compatibility
- Fixed saved_messages.php to detect optional archive columns before SELECT/INSERT.
- Legacy xmpp_saved_messages schemas now fall back to database storage instead of failing on storage_mode.
- PHP lint passed for saved_messages.php, saved_message_stream.php, and upload_file.php.


## 2026-08-05 Saved Messages Google Drive allowlist
- Requirement: real-time Saved Messages Drive offload for employees 302, 232, 78, 116, 553, and 218 only, covering text, files, and images.
- Change: `server_patch/chat/saved_messages.php` now gates Drive offload by the six-employee allowlist and keeps other users on database storage.
- Observability: POST response now returns `drive_enabled` and `drive_result` (`drive`, `provider_not_connected`, `employee_not_allowlisted`, `drive_upload_failed`, or `archive_columns_missing`).
- Verification: PHP syntax checks passed for Saved Messages, stream, and archive helper endpoints.

## 2026-08-05 Saved Messages archive-column self-healing
- Root cause: live `xmpp_saved_messages` schema did not contain Drive archive columns, so saves fell back to database with `archive_columns_missing`.
- Change: `saved_messages.php` now verifies/adds the archive columns on request before selecting storage mode, then applies the six-employee Drive allowlist.
- Deployment: upload the updated `server_patch/chat/saved_messages.php` to `/var/www/html/router_login/chat/saved_messages.php`; no Flutter/web build is required.
- Verification: PHP lint passed.

## 2026-08-05 - Horizon responsive loading hardening
- Horizon now reads attendance from the employee DB before contacting the remote task DB.
- Optional location/timeline reads no longer depend on an `id` column being present.
- Employee 218 is included in the Horizon elevated visibility allowlist.
## 2026-08-05 Horizon Live View Stabilization
- Requirement: Make Horizon cards-first, add a separate compact all-employee live map, preserve employee-card and marker navigation to individual route timelines, and remove the recurring 20-second Horizon timeout.
- Status: Implemented locally; production deployment pending.
- Verification: PHP lint passed for `server_patch/chat/myhub.php` and `db.php`; Flutter analyze completed with informational lints only and no compile errors.

## 2026-08-05 Horizon Navigation Correction
- Main Horizon remains cards-first; employee route/timeline is no longer rendered inline on the landing page.
- Employee card click opens a separate `HorizonEmployeeMapScreen` route.
- All employees live view opens a separate `HorizonAllEmployeesMapScreen` route with compact map and cards.
- Web release rebuilt successfully after the navigation correction.

## 2026-08-05 Horizon Card Grid and Separate Route Correction
- Replaced Horizon employee list rows with responsive employee cards: 3 columns on wide web, 2 on tablet, 1 on mobile.
- Removed the selected employee route/timeline from the Horizon landing page.
- Employee cards now open a dedicated employee route/timeline page.
- The All employees live view remains a separate map page and uses the same card grid.
- Verified `flutter analyze --no-pub lib/myhub_horizon_screen.dart lib/chat_api.dart`: no errors; only existing style infos in chat_api.dart.
- Verified `flutter build web --release`: succeeded; output is `build/web` and WASM dry run succeeded.

## 2026-08-05 Horizon Compact Map and Timeline Scroll Fix
- Reduced all-employees map height from 340px to 260px so employee cards remain visible in the same viewport.
- Reduced individual route map to 220px mobile / 280px wider layouts.
- Wrapped individual route/timeline content in `SingleChildScrollView`; half-hour points and address details are now reachable by scrolling.
- Preserved existing draggable/zoomable OSM map interaction. Google Maps requires a configured browser API key and billing project before switching providers.
- Validation: `flutter analyze --no-pub lib/myhub_horizon_screen.dart` passed; `flutter build web --release` passed with WASM dry run.

## 2026-08-05 Horizon Normal Map Sizing
- Requirement: Keep Horizon maps at a normal centered width/height and preserve the employee cards and scrollable timeline below.
- Change: Constrained the individual route map to 920px and the all-employee overview map to 1100px, while retaining responsive mobile width and existing pan/zoom behavior.
- Verification: `flutter analyze --no-pub lib\myhub_horizon_screen.dart` passed. `flutter build web --release` timed out after 124 seconds; no fresh release artifact is claimed.

## 2026-08-05 RSM Shared Saved Archive
- Requirement: Provide an RSM conversation visible only to employees 302 and 116, aggregating saved messages/files from both users with Drive-backed content access.
- Implementation: Added an access-controlled `scope=rsm` saved-message query, separate RSM cache key, `saved_by_emp_id` model metadata, and an RSM virtual chat entry in the home list and desktop/mobile routing.
- Verification: `saved_messages.php` PHP lint passed; targeted Flutter analyzer completed with existing lint/info warnings and no new compile errors.
- Risk/decision: RSM is currently a virtual Flow conversation backed by the saved-message store; it is not an ejabberd/XMPP room. Real room provisioning and server-side write fan-out require the deployed channel API/XMPP provisioning contract.
