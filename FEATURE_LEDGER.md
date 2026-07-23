
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
