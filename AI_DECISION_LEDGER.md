
## DECISION-20260715-VERSION-2.0.4
- Date: 2026-07-15
- Decision: Use version 2.0.4+27 for this build instead of reusing 2.0.3+26.
- Reason: Existing 2.0.3 artifacts and draft scripts were already present; new version avoids duplicate release-registration ambiguity.

## DECISION-20260715-GROUP-ADMIN-SCOPE
- Date: 2026-07-15
- Decision: Keep promote/demote restricted to owners, while admins receive add/remove/rename management access.
- Reason: Prevents admins from escalating or demoting other admins without owner control while satisfying admin operational management needs.


## DECISION-20260715-SCROLL-FORCE-VS-SELECTION
- Date: 2026-07-15
- Decision: Keep selection guard for passive auto-scroll but bypass it for explicit user jump/open-chat scrolls.
- Reason: Preserves copy/select stability while restoring expected Telegram/WhatsApp-style latest-message positioning.


## DECISION-20260715-INITIAL-INDEX-NOT-AUTOSCROLL
- Date: 2026-07-15
- Decision: Use list initialScrollIndex for first chat render instead of programmatic scroll.
- Reason: Default bottom positioning should be layout state, while programmatic scroll should only happen for explicit user action or newly-sent messages.


## 2026-07-15 18:20:41 +05:30
- Decision: Keep task notifications backend-side so all clients receive consistent System Notifications and task APIs remain the source of truth.
- Decision: Preserve existing poll vote arrays by option text during poll edit to avoid losing votes when labels are unchanged.
- Decision: Saved Messages now uses an attachment option sheet first, matching the chat composer pattern without changing existing file upload backend.


## 2026-07-16 10:39:38 +05:30
- Decision: Keep latitude/longitude stored as metadata, but resolve coordinate-looking display values to address at the UI boundary using existing reverse_geocode API/cache.


## 2026-07-16 11:03:55 +05:30
- Decision: Poll votes already store employee IDs, so frontend maps IDs to known participant names for creator visibility. Checklist now stores checked_by IDs on toggle to support the same visibility model.



## DEC-20260716-ATTACHMENT-RESTRICTED
- Date: 2026-07-16 11:42:08
- Decision: Store restricted state as xmpp_messages.file_restricted and propagate through API JSON/attachment metadata.
- Decision: Restricted files remain previewable inline inside Flow but hide download/open-with controls and reject app download requests via media.php?download=1.
- Decision: Unrestricted files retain normal download behavior and use externalApplication launch for Open with.


## DEC-20260716-SAVED-FORWARD-PASTE
- Date: 2026-07-16 11:56:28
- Decision: Treat Saved Messages as a special forward target with jid saved@chat.skylinkonline.net and type saved.
- Decision: Store forwarded attachments in saved_messages using file_url/file_name/file_type rather than sending a pseudo-chat message.
- Decision: Improve Windows Saved Messages usability with explicit text paste and desktop drop using existing dependencies; browser clipboard file paste remains through ClipboardMediaBridge.


## DEC-20260716-CHAT-SELECTION-SCROLL-LOCK
- Date: 2026-07-16 12:06:05
- Decision: Preserve latest-message initial positioning through ScrollablePositionedList.initialScrollIndex/initialAlignment, while separately locking viewport during text selection by restoring the visible anchor. This separates chat-open behavior from selection behavior instead of using one scroll-to-bottom rule for both.


## DEC-20260716-DESKTOP-PANEL-BUBBLE-WIDTH
- Date: 2026-07-16 12:12:05
- Decision: Keep the right profile panel opt-in through ChatScreen.onProfileTap rather than opening automatically on chat selection.
- Decision: Use desktop-specific bubble max-width cap and shrink-wrapping to move message presentation closer to WhatsApp/Telegram while retaining max width for long content.


## DEC-20260716-MULTIPLATFORM-DRAFT-BUILD
- Date: 2026-07-16 13:20:24
- Decision: Reuse version 2.0.4+27 already present in pubspec.yaml and refresh all three platform artifacts from current workspace state.
- Decision: Register all three platforms as Development/Draft with rollout_percent 0 and force_update 0, preserving 302 approval gate.
- Decision: Upload web ZIP to downloads as draft artifact only; live web app folder was not replaced.


## DEC-20260716-STANDALONE-FLOW-MASTER-ADMIN
- Date: 2026-07-16 15:34:05 +05:30
- Decision: Keep all admin app code inside admin/ and use local deploy-owned admin_config.php instead of requiring chat/bootstrap.php.
- Reason: User requires /admin to be a separate PHP web application outside the chat folder, with no calls to outside pages.
- Tradeoff: Credentials must be configured separately on the server; admin_config.php is gitignored and sample config is committed.

## DEC-20260716-ADMIN-COUNTS-LIVE-CHAT
- Time: 2026-07-16 18:15:28
- Decision: Use xmpp_users for Overview Users because admin Users screen is for live chat accounts, while employee table can contain broader HR records.
- Decision: Split Groups and Channels as separate admin views rather than a combined table to match operational admin workflows.


## DEC-20260720-C1C2-GROUP-CHANNEL-CREATE-BLOCK
- Date: 2026-07-20
- Decision: Enforce the create restriction in backend create_group.php/create_channel.php and mirror it in UI.
- Reason: UI-only checks can be bypassed; backend guard protects all clients, while UI avoids letting restricted users reach a dead-end create sheet.
- Mapping: Admin override A/B/C1/C2 wins; employee.emp_type 1 maps to B and 0 maps to C1.

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

## 2026-07-24 11:53:02 - External API Architecture Decision
- Decision: Use standalone versioned /api/{module}/v1 PHP layer with local API-key auth instead of exposing session-only chat endpoints directly.
- Reason: External portals need stable Bearer auth, scopes, audit trails, and non-session access without breaking existing app behavior.


## 2026-07-24 12:18:16 - API Expansion Decision
- Decision: Add second-layer extended handlers instead of rewriting original session endpoints.
- Reason: Keeps current app stable while exposing external portal API access with Bearer keys, scopes, and audit logging.

