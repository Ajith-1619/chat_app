
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


## 2026-07-24 12:34:54 - API Documentation Decision
- Decision: Keep one canonical documentation file under docs/external_api and a deploy-bundle copy under server_patch/api.
- Reason: Developers can read docs locally while server admins can upload the API folder with documentation included.


## 2026-07-24 12:49:18 - Plugin Architecture Decision
- Decision: File manifest + database registry sync with hook-based dispatch and artifact outputs.
- Reason: Keeps plugins declarative, auditable, permission-scoped, and isolated from Flow core behavior.


## 2026-07-24 13:10:00 - Selection Freeze Decision
- Decision: Treat text selection as a hard viewport freeze that overrides even force-scroll requests.
- Reason: A delayed force-scroll callback can fire after the first pointer-down and move the conversation while the user is selecting text.

## 2026-07-24 14:53:05 +05:30 - Pointer Intent Decision
- Decision: Do not enter selection freeze on message text pointer-down; enter it only after drag threshold or actual selected text.
- Reason: Normal clicks were being treated as text-selection intent, which could keep scroll tracking stale and trigger anchor restore jumps.

## 2026-07-24 14:58:22 +05:30 - History Loading Decision
- Decision: Expand server history cap immediately from fixed 200 to bounded 1000 default while keeping route compatibility.
- Reason: The current Flutter chat screen does not implement older-message pagination, so the fixed backend cap was the fastest low-risk fix for missing old messages.

## 2026-07-24 - Keep Native Text Selection Separate
- Decision: Do not reuse Flow message-selection mode for browser/native text selection.
- Rationale: Message-selection mode captures anchors, queues history, and can rebuild app bar/list state. Native text selection needs a lightweight freeze that preserves viewport and lets SelectableText own mouse drags.
- Risk Control: Limited changes to lib/chat/chat_screen.dart only; mobile swipe/long-press behavior preserved.

## 2026-07-24 15:55:18 - Decision
- Decision: Fix root gesture conflict at the bubble boundary instead of rebuilding the chat list or replacing the message renderer.
- Reason: Parent GestureDetector drag/tap recognizers were competing with SelectableText mouse selection on Web/Desktop. Disabling those parent recognizers only for selectable text bubbles is the smallest production-safe fix.


## 2026-07-24 15:55:36 +05:30 - Decision: Let SelectableText Own Web/Desktop Drags
- Decision: Fix the root selection conflict by removing parent bubble drag/long-press/tap recognizers from selectable text bubbles on web/desktop instead of adding another scroll workaround.
- Rationale: Native text selection needs first ownership of mouse drag events; message actions remain available through right-click and mobile behavior remains unchanged.


## 2026-07-24 16:45:46 +05:30 - AI Decision
- Decision: Do not disable ListView scrolling during text selection. Let SelectableText own mouse drag gestures and freeze only background history/UI refresh effects.
- Rationale: Disabling scroll physics caused secondary regressions where chat scrolling stopped; parent gesture removal is the smaller root fix.

## 2026-07-24 17:24:54 +05:30 - AI Decision
- Decision: Render one compact badge from next_action_persons instead of adding a new row of multiple operational chips.
- Rationale: Matches requested image direction while keeping the chat list dense and low-risk.

## 2026-07-24 18:00:10 +05:30 - AI Decision
- Decision: Bump to 2.0.5+28 as the next Android release after existing 2.0.4+27.
- Rationale: Keeps version sequencing consistent with the current pubspec and release folder history.

## 2026-07-24 - AI API Access Design
- Decision: Keep AI room enablement metadata-driven through flow_admin_ai_room_access and default active provider id 2, with employee 302 as built-in admin access and assigned users controlled by flow_admin_ai_user_access.
- Reason: Avoid hardcoding AI behavior into chat rooms while letting authorized users enable @ai per group/channel.


## 2026-07-25 - AI Access Control Model
- Decision: Separate 302-only API Access management from user-facing AI API room toggles.
- Decision: Remove implicit 302 AI API access; AI API menu is now assignment-driven for all users.
- Reason: Matches product requirement that 302 grants AI API visibility to selected users only.


## 2026-07-25 - Decision: Minimal UI Extension
- Decision: Reuse existing ChannelProfile API for mobile manage-channel metadata instead of adding new backend calls.
- Decision: Keep default folder filters informational in Chat Folders and add edit only to custom folders.
- Decision: Implement reply target visibility with temporary bubble highlight after existing jump behavior.
- Reason: Smallest low-risk change that preserves current chat and folder behavior.

## 2026-07-25 - Decision: Remove Slow Work From Send Response
- Decision: Keep core message persistence/XMPP delivery synchronous, but move AI reply generation to a worker.
- Decision: Throttle Android background history prefetch instead of removing it entirely.
- Reason: Preserves user-facing behavior while reducing the biggest latency and network burst risks.

## 2026-07-25 - Decision: Backend-Owned Folder Preferences
- Decision: Store chat folders as whole ordered per-user folder documents in xmpp_chat_folders rather than keeping browser/device SharedPreferences as source of truth.
- Reason: Folder configuration must survive builds, browser cache changes, and multiple devices while keeping reorder/edit simple.

## 2026-07-25 - Decision: Mobile Composer Minimal Cleanup
- Decision: Remove only the always-visible B button instead of changing the formatting system.
- Decision: Make composer dimensions responsive inside _MessageComposer rather than rewriting the chat footer.
- Reason: Smallest safe fix for APK usability while preserving existing send, attachment, schedule, voice, and formatting workflows.


## 2026-07-25 - Decision: Composer Keyboard Preference
- Decision: Store Enter-to-send as a local per-user app preference using the existing SharedPreferences pattern.
- Decision: Default to true to preserve current behavior and avoid surprising existing users.
- Reason: Smallest stable change that gives user control without backend dependency or chat send-flow changes.


## 2026-07-25 - Decision: v2.0.6 Draft Release
- Decision: Increment to 2.0.6+29 after existing 2.0.5+28 draft.
- Decision: Upload/register only Android APK as live Draft per request; keep web build local/package-ready without replacing live web app.
- Reason: User requested web and APK builds, specifically APK moved to live draft for 302 approval.


## 2026-07-27 - Decision: Full-Viewport Image Viewer
- Decision: Fix the image preview by resizing the InteractiveViewer child to the full preview viewport instead of rewriting the attachment preview screen.
- Decision: Keep the change image-only and leave audio/document/location preview branches untouched.
- Reason: Smallest safe fix that resolves boxed zoom behavior without risking regressions in other attachment types.

## 2026-07-27 - Decision: Public Android Downloads
- Decision: Move Android download saving from direct path writes into a native public-save bridge using MediaStore on Android 10+ and legacy public directories on older Android versions.
- Decision: Save images/videos/audio into media collections and general documents into Downloads so users can find them in Gallery or Files naturally.
- Reason: Smallest reliable fix for user-visible downloads without rewriting the attachment UI or web/desktop download flows.

## 2026-07-27 13:00:45 - Decision
- Decision: Use existing recent chat channel_kind metadata instead of adding a backend call.
- Reason: The recent_chats endpoint already returns channel_kind; carrying it through ChatContact/ChatPreview keeps the change minimal and avoids new latency/API risk.


## 2026-07-27 13:10:59 +05:30 - Attachment Preview Decision
- Decision: Use explicit backend file metadata for recent chat previews instead of trying to decode corrupted or binary-looking message bodies in the UI.
- Rationale: File metadata is already selected by recent_chats.php and is the stable source of truth; this prevents mojibake from appearing and keeps normal message previews unchanged.


## 2026-07-27 14:50:32 +05:30 - Broadcast Architecture Decision
- Decision: Model Broadcast as a sender-owned list with direct-message fan-out instead of creating a hidden group/channel.
- Rationale: This matches WhatsApp/Telegram broadcast semantics: recipients do not see each other and replies return through normal one-to-one chat.
- Decision: Backend enforces Type A only, while UI provides an early Type A check for better feedback.


## 2026-07-27 - Broadcast Architecture Decision
- Used soft delete for broadcast lists so sent-message history/audit is preserved.
- Saved list send reuses direct one-to-one message fanout and stores recipients centrally to avoid exposing recipient lists to non-owners.
- Kept implementation scoped to existing broadcast.php, ChatApi, and BroadcastSheet without changing core chat message behavior.


## 2026-07-27 - Metadata Engine Decision
- Implemented metadata as first-class typed tables rather than plain text fields, with custom field definitions keyed by channel type for future admin configuration.
- Kept /ai as a slash command and migrated stored @ai room triggers on helper initialization to preserve existing AI-enabled rooms.
- Kept slash command UI as an insertion helper only, preserving the existing message send pipeline.


## 2026-07-27 - Employee Event Notification Decision
- Reused existing SystemNotification.php so messages appear in the existing System Notifications chat and push behavior remains consistent.
- Implemented as an authorized daily runner endpoint/CLI-safe script instead of adding polling to the app, avoiding extra client API calls.


## 2026-07-27 - Next Action Summary And Clarification
- Decision: Use a structured SKYLINK_ACTION_CLARIFY message prefix for missing owner/date clarification instead of a snackbar or side-panel-only warning.
- Rationale: The missing metadata belongs to the conversation context, and a chat card lets members resolve it where the actionable message happened while keeping the metadata engine database-driven.


## 2026-07-27 - Wake-up Last Message Summary
- Decision: Generate wake-up summaries from the latest stored message metadata/body instead of calling AI, keeping scheduled notification latency low and avoiding extra API cost.


## DECISION-20260728-SYSTEM-NOTIFICATION-BROADCAST-FIX
- Date: 2026-07-28 10:25:00 +05:30
- Decision: Route System Notifications through the server history API instead of browser XMPP/MAM because server persistence is the canonical source for employee event/system notifications and read clearing.
- Decision: Keep Broadcast Type A enforcement in the backend so admin-side employee type changes take effect without relying on stale cached client profile data.
## DECISION-20260728-SLASH-AI-COMMANDS
- Date: 2026-07-28 10:55:00 +05:30
- Decision: Keep /ai as the primary trigger and retain @ai as backward-compatible fallback so existing user habits do not silently fail.
- Decision: Process AI reply inline after response completion when available because server environments can disable/background-block exec workers.
## DECISION-20260728-NEXT-ACTION-DATE-PERSON-FIX
- Date: 2026-07-28 11:10:00 +05:30
- Decision: Do not carry forward previous next_action_date when a new actionable message lacks a date, because stale metadata is more misleading than a visible clarification requirement.
## DECISION-20260728-CONTEXT-AWARE-ACTION-ENGINE
- Date: 2026-07-28 11:35:00 +05:30
- Decision: Use deterministic backend heuristics over AI calls for baseline action extraction so normal messaging remains fast and reliable; AI can later enhance suggestions without blocking send.
- Decision: Preserve user trust by not carrying stale next-action dates and by asking for missing person/date through Flow MCO clarification records.
## 2026-07-28 - Decision: Effective Role Plus Physical Sync
- Decision: Preserve owner role, upgrade Type A member roles to admin through an effective-role helper, and opportunistically sync DB rows where safe.
- Reason: Keeps existing group/channel authorization simple while making Type A access consistent across old and new memberships.

## 2026-07-28 - Decision: Reuse MyHub Endpoint For Activity
- Decision: Extend chat/myhub.php with section=activity instead of adding a separate endpoint.
- Reason: My Hub already centralizes task/leave/directory sections and authenticated session handling.
- Legacy fit: Persisted username as Sky-{emp_id}, matching existing activity_log rows.

## 2026-07-28 - Decision: Reuse Chat Message Endpoint For Group/Channel Sends
- Decision: Keep one POST /api/chat/v1/messages endpoint for DM, group, and channel messages, using to_jid to identify the target.
- Reason: This matches the existing message table and avoids duplicating send logic across groups/channels modules.
- Guardrail: Room JIDs are detected by @conference. and stored as groupchat for correct client rendering.

## 2026-07-28 - Decision: Horizon Map Uses In-App Route Canvas
- Decision: Render Horizon route as an in-app line map/canvas for first implementation instead of adding a new map package or external browser dependency.
- Reason: Keeps implementation small, stable, and usable across Web/APK/Windows while using existing captured lat/long points.
- Future Option: Replace canvas background with OSM tiles if precise street-level route context is required.

## 2026-07-28 - Decision: Horizon Map Rendering
- Decision: Use the app's existing no-package OpenStreetMap tile approach and existing cached reverse-geocode helper rather than adding a new map package or duplicate geocoder.
- Reason: Smaller production-safe change, no dependency churn, and consistent behavior with current attachment/location previews.

## 2026-07-28 - Decision: Horizon Access Model
- Decision: Keep the fixed super-admin allowlist for company-wide Horizon access, and add dynamic self-plus-direct-report visibility for all other employees using employee.reporting_to.
- Reason: Matches operational hierarchy without exposing unrelated employee locations.

## 2026-07-28 - Decision: Local Slash Help Sheet
- Decision: /help opens a local command guide sheet instead of sending a help message to the conversation.
- Reason: Reduces chat noise while keeping command discovery fast and familiar.

## 2026-07-28 - Decision: Pan Offset In Web Mercator Pixels
- Decision: Store Horizon map drag movement as a Web Mercator world-pixel offset and share it between tile rendering and route painting.
- Reason: Keeps route markers aligned with OSM tiles without adding a heavyweight map package.

## DEC-2026-07-28-RELEASE-207
- Decision: Register Android and Windows as draft releases, not live rollout, so Employee 302 remains the production approval gate.
- Decision: Upload web ZIP as artifact but do not overwrite live /chat web app during this draft release request.


## DEC-2026-07-29-OPENROUTER-AUTO-MODEL
- Decision: Use OpenRouter model auto so provider-side routing can choose the model automatically.
- Decision: Keep old gpt-4o-mini stored values accepted but normalize them to auto during API calls.


## DEC-2026-07-29-BROADCAST-CHANNEL-CREATE-UX
- Decision: Select All applies to the currently visible/search-filtered users so admins can bulk-select all users or filtered subsets safely.
- Decision: Keep create flow as a modal bottom sheet on mobile but constrain it as a polished modal card on wider screens.


## DEC-2026-07-29-RECENT-CHAT-HIGH-VOLUME-SYNC
- Decision: Queue one missed refresh rather than running overlapping recent-list calls, preserving server safety while preventing stale left-list state.
- Decision: Raise recent-list limits moderately and add indexes instead of loading all conversations unbounded.


## 2026-07-29 - High-volume chat history pagination
- Requirement: Make high-message groups/channels faster like WhatsApp/Telegram by loading only recent messages first and loading older messages on scroll-up.
- Change: Added limit and efore_message_id support to chat/history.php, defaulting to 50 messages instead of 1000.
- Change: Updated Flutter ChatApi.getHistory and ChatScreen to fetch latest 50 messages, trim old persisted cache, and lazy-prepend older messages when users scroll near the top.
- Impact: Reduces initial chat payload, first render work, and repeated refresh cost for high-volume support groups/channels.
- Verification: php -l server_patch/chat/history.php passed. lutter analyze lib/chat_api.dart lib/chat/chat_screen.dart completed with existing warnings/info only, no compile errors.
- Updated: 2026-07-29 14:59:38

## DEC-2026-07-29-CHANNEL-TYPE-API
- Decision: Do not force channel definitions fallback to operational when an unknown channel type is supplied.
- Reason: Flow channel architecture is metadata-driven; custom types such as 	ask should be preserved and routed to Workspace instead of being mislabeled Operational.
- Updated: 2026-07-29 15:37:44 +05:30

## DEC-2026-07-29-SLASH-COMMAND-BEHAVIOR
- Decision: Keep slash commands lightweight: UI intercept only where a real creation flow exists; send other commands as messages so backend can record auditable metadata events without blocking chat.
- Reason: Preserves chat speed and avoids introducing a large command framework regression.
- Updated: 2026-07-29 16:06:09 +05:30


## DEC-2026-07-29-NEW-CHANNEL-MEMBER-LIST-SCROLL
- Decision: Fix the new channel member picker by resizing the dialog and giving the member results their own scrollable area instead of changing member search or selection logic.
- Reason: The bug was caused by available vertical space collapsing under the channel form fields; a layout-only fix has lower regression risk.
- Updated: 2026-07-29 16:40:00 +05:30

## DEC-2026-07-29-BROADCAST-MODAL-PICKER
- Decision: Convert broadcast from bottom drawer to centered dialog modal while preserving existing BroadcastSheet state/API methods.
- Reason: This improves desktop/web usability and avoids repeating the channel modal issue where form controls can consume the recipient list space.
- Updated: 2026-07-29 17:05:00 +05:30

## DEC-2026-07-29-MYHUB-SUGGESTIONS-COMPLAINTS
- Decision: Store Suggestions & Complaints in the chat/xmpp database through chat_db(), adding assigned_to_emp_id columns to the existing suggestion_complaints table rather than using task DB.
- Reason: User specified the table lives beside xmpp_users/xmpp tables, and receiver-specific visibility needs a durable assigned-user field.
- Updated: 2026-07-29 17:45:00 +05:30

## AI-DECISION-2026-07-29-CHAT-LIST-NEXT-ACTION-BADGE
- Decision: Keep the badge as a compact single pill with owner name plus due date/time instead of adding a second row or backend-derived label.
- Reason: Matches user request, preserves chat list density, and avoids API/data model changes.

## AI-DECISION-2026-07-29-WEB-NEXT-ACTION-BADGE
- Decision: Use the standard web release command with `/chat/` base href.
- Reason: Matches the existing Flow deployment path documented in build.md.

## AI-DECISION-2026-07-29-DIRECT-USER-SEND-API
- Decision: Add a convenience employee-id based direct-message endpoint instead of changing the existing JID-based `/messages` endpoint.
- Reason: External portals can send DMs without constructing JIDs, while existing group/channel/direct API compatibility remains stable.

## AI-DECISION-2026-07-29-DIRECT-MESSAGE-API-404-FALLBACK
- Decision: Add a physical route fallback instead of relying only on `.htaccess` rewrite.
- Reason: Production Apache rewrite/AllowOverride differences can cause 404; physical route keeps the documented URL stable.

## AI-DECISION-2026-07-29-DIRECT-MESSAGE-POSTMAN-BODY-FALLBACK
- Decision: Make the endpoint tolerant of multiple Postman/external client body formats instead of requiring strict raw JSON only.
- Reason: External integrations commonly send form-data or x-www-form-urlencoded during testing; accepting aliases reduces integration friction without weakening auth.

## AI-DECISION-2026-07-30-DIRECT-MESSAGE-BODY-DIAGNOSTICS
- Decision: Add safe parser diagnostics instead of guessing whether Postman, proxy, or old server code is dropping the body.
- Reason: The screenshot request is correct; debug fields will separate deployment mismatch from request transport/body parsing issues.

## AI-DECISION-2026-07-30-DIRECT-MESSAGE-PHYSICAL-HANDLER
- Decision: Make the physical fallback route self-contained.
- Reason: Persistent same validation response indicates the shared dispatcher or old live file may be handling the request; self-contained physical route removes PATH_INFO/rewrite uncertainty.

## AI-DECISION-2026-07-30-DIRECT-SEND-PHYSICAL-ENDPOINT
- Decision: Add a new physical `direct_send.php` endpoint.
- Reason: The screenshot response lacks debug markers from the latest route, proving the request is not reaching the updated handler; a new physical file avoids rewrite/opcache route ambiguity.

## DECISION-2026-07-30-NEXT-ACTION-MONITOR
- Decision: Integrate next-action reminders and due polls into the existing notification worker instead of creating a separate always-on service.
- Reason: Reuses the current cron/deployment path, avoids app-side polling, and keeps Flow faster while preventing duplicate operational messages through state hashes.

## DECISION-2026-07-30-TASK-CREATE-PHYSICAL-ENDPOINT
- Decision: Add a physical `create.php` endpoint instead of changing the generic `/tasks/v1` dispatcher.
- Reason: Live/Postman behavior indicates route or cached dispatcher ambiguity; a physical create file gives a deterministic integration URL.
- [2026-07-30] DEC-SHARE-ANDROID-INBOUND: Used native Kotlin MethodChannel instead of new dependency so Android content URI files are copied to app cache and existing Flow attachment preview/send path remains unchanged.

## DEC-VIDEO-ATTACHMENT-SEND-20260730
- Decision: Use FilePicker media type for gallery selection and stream native video/large file uploads from file path.
- Reason: Android videos can be large; reading full bytes before upload can fail or slow the app.

- 2026-07-30 | DEC-BUILD-208 | Versioned next release as 2.0.8+31 because current pubspec was 2.0.7+30 and user requested next version web/APK build.

- 2026-07-30 | DEC-DEPLOY-208 | Registered only Android in release governance because current version.php/release validation tracks android/windows/linux and no web platform is exposed to client update checks. Web ZIP uploaded as supporting artifact.

## DECISION-2026-07-31-CHAT-UPLOAD-50MB
- Decision: Enforce 50 MB at both Flutter and PHP layers instead of relying only on server ini limits.
- Reason: Client-side rejection gives immediate UX feedback; server-side guard protects external clients and misconfigured PHP limits.

## DECISION-2026-07-31-LMS-LEAD-WEBHOOK
- Decision: Use async queue + worker and server-local token config instead of direct synchronous webhook call in send_message.php.
- Reason: Prevents LMS downtime/latency from breaking Flow messaging and keeps bearer token out of logs/UI/repo config.

## 2026-07-31 - Attachment read strategy
- Decision: Prefer a local native-path byte fallback for non-streamed attachments instead of forcing every picker path to preload bytes.
- Why: Minimal safe fix, preserves current video/large-file streaming behavior, and directly targets the observed Unable to read failure.

## 2026-07-31 - Horizon interaction design
- Decision: Keep a single all-employees overview on the main Horizon screen and reuse the existing per-employee route experience as an inline drilldown plus optional full-screen view.
- Why: Matches the user's request while preserving the already-working single-user route map.

## 2026-07-31 - Broadcast error diagnosis
- Decision: Fix the backend send action instead of only improving client-side error messaging.
- Why: The observed failure was caused by an actual server-side variable bug, so masking it in UI would not solve delivery.

## DECISION-20260801-HORIZON-SEPARATION
- Date: 2026-08-01
- Decision: Keep all-employees live view on a separate Horizon page instead of embedding it into the main attendance screen.
- Reason: Matches requested workflow, reduces clutter on the main page, and keeps employee timeline/detail view separate from cross-employee monitoring.

- 2026-08-01 | Chose minimal fix: preserve existing mention UI and next-action poll UI, only corrected scheduling and cursor-aware parsing rather than redesigning composer behavior.

- 2026-08-01 | Chose channel-based muted notification routing instead of suppressing alerts entirely, preserving visibility while removing disruptive sound/vibration.

- 2026-08-01 | Fixed route parsing at the shared groups/channels handler instead of changing client URLs, preserving the published external API contract.

## DEC-20260801-EXTERNAL-CHANNEL-BODY-CLOSE
- Date: 2026-08-01 20:10:00 +05:30
- Decision: Add lifecycle fallback on the base channels/groups endpoint instead of depending only on /{id}/close style URLs.
- Reason: The user needs a stable external API that survives Apache rewrite/path-info differences and can close/archive by body payload alone.


## DEC-20260801-WEB-FILE-PICKER-UPLOAD
- Date: 2026-08-01 21:15:00 +05:30
- Decision: Fix the web manual file-picker path at the browser bridge layer instead of changing the shared upload pipeline.
- Reason: Drag/drop and clipboard paste already proved the uploader itself was healthy. Reading browser File bytes directly gives the smallest safe fix and keeps every other attachment flow intact.

## DEC-20260801-COMPOSER-UPLOAD-LATENCY
- Date: 2026-08-01 22:05:00 +05:30
- Decision: Keep the existing upload/send pipeline and optimize only the trigger parsing and attachment preparation layers.
- Reason: The send pipeline already works for drag/drop and paste, so the safer fix is to remove unnecessary detection/conversion overhead without rewriting message sending.

## 2026-08-01 - AI decision log
- Reused existing web platform view preview pattern instead of introducing a heavyweight new video dependency.
- Kept scope to optimistic attachment rendering and preview surfaces to avoid destabilizing composer/send logic.
- Accepted a platform split: rich inline video on web now, native fallback unchanged for this patch.

## DEC-20260801-ATTENDANCE-CALENDAR-STATE-COLORS
- Date: 2026-08-01 22:45:00 +05:30
- Decision: Keep the fix in the attendance calendar widget and derive UI state from existing attendance row flags instead of changing the API contract.
- Reason: The bug is a presentation issue, and using existing `isWeekoff`, `isHoliday`, `status`, `punchIn`, and `punchOut` fields keeps the change small and low-risk.

## DEC-20260801-LEAVE-TYPE-OTP-ALIGNMENT
- Date: 2026-08-01 23:20:00 +05:30
- Decision: Keep the approver employee as a single constant in the leave backend patch for the testing phase and map optional DB columns only when they exist.
- Reason: This keeps the current business-requested test routing simple now and makes the later switch from 302 to 232 a one-line safe change.

## DEC-20260801-LEAVE-OTP-CLIENT-ID-LIMIT
- Date: 2026-08-01 23:45:00 +05:30
- Decision: Fix the notification reference at the shared system-notification layer instead of only shortening leave OTP keys.
- Reason: The bug can hit any system notification with a long reference, so the shared fix prevents repeats elsewhere too.

## DEC-20260801-RELEASE-2-0-9
- Date: 2026-08-01 17:55:00 +05:30
- Decision: Bump to a new 2.0.9+32 release and register only the Android artifact as a live draft.
- Reason: This avoids overwriting the existing 2.0.8 release trail and matches the request to move only the APK into the live approval pipeline while still giving a fresh web build artifact locally.

## DEC-20260803-WEB-PUNCH-SHIFT-FALLBACK
- Date: 2026-08-03 18:20:00 +05:30
- Decision: Keep the live shift API path unchanged and add a local assigned-shift fallback from profile data.
- Reason: This is the smallest safe fix that unblocks web punch-in immediately without rewriting the attendance backend contract.

## DEC-20260803-WEB-PUNCH-SHIFT-PROXY
- Date: 2026-08-03 21:10:00 +05:30
- Decision: Move web shift retrieval behind chat/attendance.php instead of relying only on the profile fallback.
- Reason: The fallback prevents a blank dropdown, but the proxy restores the full shift list on web without exposing the browser to external attendance endpoint failures.


## 2026-08-03 - LMS webhook sender identity decision
- Decision: Normalize webhook sender_jid using the sender employee id plus the Flow chat domain instead of trusting the raw stored JID.
- Reason: LMS permission mapping extracts the numeric employee id from sender_jid, so the webhook producer must guarantee that format even if upstream message identity formatting evolves.
## DEC-20260803-ARCHIVE-STORAGE
- Decision: Implement archive storage as a provider-driven backend with Google Drive as the first concrete provider rather than hard-coding Drive behavior into Flow core.
- Reason: This keeps archive storage extensible for OneDrive, S3, Azure Blob, NAS, and future providers without reworking the archive lifecycle model.
- Decision: Keep archived conversations searchable and stream archived manifests directly from archive storage instead of forcing restore-to-server reads.
- Reason: This matches the product goal of reducing active server disk usage while preserving user access and search continuity.

## DEC-20260803-VOICE-AUDIO-VIDEO-PLAYBACK
- Date: 2026-08-03 23:40:00 +05:30
- Decision: Persist audio duration as first-class message metadata instead of inferring it client-side from downloaded media every time.
- Reason: This fixes the 00:00 voice-note bug at the actual data-contract layer and keeps playback stable across reloads, devices, and history fetches.
- Decision: For web audio preview, load attachment bytes and create a local object URL rather than relying on the stored attachment URL directly.
- Reason: Flow stores some media behind encrypted/indirect URLs, so byte-backed playback is the safest way to preserve in-app playback without weakening attachment protection.


## DEC-20260803-HORIZON-LATENCY-MAP-UX
- Date: 2026-08-03 23:58:00 +05:30
- Decision: Optimize Horizon by reducing backend query fan-out first, instead of only increasing request timeout.
- Reason: The user-facing pain is caused by real load-path inefficiency, so keeping the 20-second timeout and making the payload cheaper is safer and more scalable than masking the issue.
- Decision: Keep reverse-geocoding in Horizon timeline bounded rather than removing addresses entirely.
- Reason: Address context is still useful operationally, but an unbounded geocode loop can easily dominate the request time for long punch sessions.
- Decision: Improve the existing in-app canvas/tile map interaction instead of replacing the Horizon preview with an external map dependency.
- Reason: This preserves the current Flow in-app experience and keeps the fix scoped to smoother pointer-focused zoom and pan behavior.


## DEC-20260803-MESSAGE-EDIT-INSTANT-REFRESH
- Date: 2026-08-03 23:59:00 +05:30
- Decision: Fix edited-message repaint at the local state replacement layer instead of forcing a full history reload after each edit.
- Reason: The bug is caused by fragile object-identity lookups in the visible message list, so an id-based update is the smallest safe fix and avoids unnecessary network churn or scroll disruption.

## DECISION-20260804-HORIZON-ON-DEMAND-LOCATIONS
- Date: 2026-08-04
- Decision: Keep Horizon home lightweight and move latest-location enrichment to an explicit on-demand fetch used by the all-employees live map.
- Reason: Users need the Horizon screen to open reliably first; live coordinates are important, but they should not block the entire attendance surface.
## DECISION-20260804-ARCHIVE-PROVIDER-BRANCH-PARAMS
- Date: 2026-08-04
- Decision: Keep one prepared SQL branch selector but build execute parameters per insert/update branch.
- Reason: Smallest safe fix that removes HY093 without changing archive provider schema or UI flow.
## DECISION-20260804-ARCHIVE-POLICY-BRANCH-PARAMS
- Date: 2026-08-04
- Decision: Use branch-specific execute parameters for archive policy save, matching the provider save hardening pattern.
- Reason: Small safe fix that removes HY093 without altering policy schema or admin form behavior.

## DECISION-20260804-ARCHIVE-WORKER-BOOTSTRAP-FALLBACK
- Date: 2026-08-04
- Decision: Bootstrap archive worker through the normal chat bootstrap first, with a fallback to the admin standalone bootstrap.
- Reason: The worker executes inside the chat deployment on production, but developers also need a safe local/exported fallback for diagnostics without hard-coding a missing `_bootstrap.php` file.

## DECISION-20260804-ARCHIVE-ROOM-NAME
- Date: 2026-08-04
- Decision: Use `xmpp_groups.room_name` as the canonical archive label field instead of legacy `name`.
- Reason: The live Flow chat schema already uses `room_name`, so matching that schema is the smallest safe fix for archive scheduling.

## DECISION-20260804-ARCHIVE-DYNAMIC-GROUP-COLUMNS
- Date: 2026-08-04
- Decision: Detect available `xmpp_groups` columns from `INFORMATION_SCHEMA` and derive archive label/freshness SQL dynamically.
- Reason: This keeps the archive worker compatible with both newer and older live schemas without forcing a database migration first.

- `DECISION-20260804-ARCHIVE-UNIQUE-PDO-PARAMS` Chose unique named placeholders instead of reusing `:jid` because the live PDO/MySQL configuration rejects repeated named parameters during archive job execution.

- `DECISION-20260804-ARCHIVE-DB-NOW-SCHEDULING` Chose database `NOW()` as the default manual archive schedule source to avoid PHP-vs-MySQL timezone drift keeping jobs permanently queued.

- `DECISION-20260804-ARCHIVE-LEGACY-MANUAL-QUEUE-NORMALIZE` Chose automatic normalization for legacy manual queue rows so live archive processing recovers without requiring direct SQL access from the user.

- `DECISION-20260804-ARCHIVE-DYNAMIC-REACTION-ORDER` Chose dynamic reaction ordering because live environments vary on whether `xmpp_message_reactions` includes an auto-increment `id` column.

- `DECISION-20260804-ARCHIVE-PARTICIPANT-JID-PARSING` Chose JID-based employee extraction as the fallback because direct-message JIDs already carry the numeric employee ID prefix on live Flow deployments.

- `DECISION-20260804-ARCHIVE-GROUP-MEMBER-LINK-FALLBACK` Chose a dual-path membership lookup because Flow live deployments have mixed `xmpp_group_members` schemas using either `room_jid` or `group_id`.

## AI-DECISION-20260804-SAVED-MESSAGES-DRIVE
- Date: 2026-08-04
- Decision: Reused the existing archive Google Drive provider instead of introducing a second storage integration path.
- Reason: Keeps admin/provider setup single-source, reduces regression risk, and lets Saved Messages stream through the same authenticated Flow backend.

- 2026-08-04: Chose a narrow backend fix for Saved Messages instead of UI rewrites because the failing behavior was rooted in JSON serialization of legacy data plus unresolved forwarded-file URLs, and the smallest safe repair is to sanitize endpoint output and broaden URL parsing.
