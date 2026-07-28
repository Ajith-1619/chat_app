
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

