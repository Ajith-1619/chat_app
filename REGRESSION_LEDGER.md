
## REGRESSION-20260715-V2.0.4-BUILD
- Date: 2026-07-15
- Verification: Flutter web release build completed.
- Verification: Flutter Android APK release build completed.
- Verification: Uploaded APK URL returned HTTP 200 with expected content length.
- Remaining risk: Manual functional smoke test on live draft not executed in this terminal session.
- Analyzer note: 524 existing warnings/info remain, mostly unused imports from prior module split.

## REGRESSION-20260715-GROUP-ADMIN-PERMISSIONS
- Date: 2026-07-15
- Verification: flutter analyze completed; no new compile-blocking errors observed, existing warnings/info remain.
- Verification: PHP syntax check passed for server_patch/chat/rename_group.php.
- Not run: Web/APK build, per user scope.


### Follow-up Validation
- Date: 2026-07-15
- flutter analyze rerun: existing warnings/info only, no compile-blocking errors observed.
- PHP lint: rename_group.php passed.


## REGRESSION-20260715-CHAT-BOTTOM-SCROLL
- Date: 2026-07-15
- Verification: flutter analyze completed with existing warnings/info only; no new compile-blocking errors observed.
- Build: Not run per scope.


## REGRESSION-20260715-WEB-BUILD-SCROLL-FIX
- Date: 2026-07-15
- Verification: Web release build completed successfully after chat bottom-scroll fix.
- Manual browser smoke test: Not run in this terminal session.


## REGRESSION-20260715-CHAT-LATEST-INITIAL-RENDER
- Date: 2026-07-15
- Verification: flutter analyze error scan found no analyzer errors.
- Remaining: Existing repo warnings/info remain.
- Build: Not run per scope.


## 2026-07-15 18:20:41 +05:30
- Regression scope: message editing, poll voting payload, Saved Messages attachments, task create/update APIs.
- Verification: PHP lint passed for myhub.php and task_update.php. Flutter analyzer error-level scan returned no Dart errors; existing repo warnings remain.
- Risk: System Notification delivery depends on notification XMPP account; failures are caught and logged so task save/update remains unaffected.


## 2026-07-16 10:39:38 +05:30
- Regression scope: Message Info location rows, reader read-address rows, profile Latest location card.
- Verification: Flutter analyzer error-level scan returned no errors. Existing warnings remain.


## 2026-07-16 11:03:55 +05:30
- Regression scope: checklist edit/save, poll edit/save, checklist toggle, poll vote display, creator-only details.
- Verification: Flutter analyzer error-level scan returned no errors. PHP lint passed for checklist_toggle.php.



## REG-20260716-ATTACHMENT-RESTRICTED
- Date: 2026-07-16 11:42:08
- Regression Scope: File/image send, attachment preview, attachment download, open-with, chat history serialization, PHP send/history/media endpoints.
- Verification: PHP lint passed for bootstrap.php, send_message.php, history.php, media.php. Dart targeted analyzer had no error-level findings; existing warnings/infos remain.
- Build: Not run for this change.


## REG-20260716-SAVED-FORWARD-PASTE
- Date: 2026-07-16 11:56:28
- Regression Scope: Message forward flow, Saved Messages note/file save, Saved Messages composer paste, Home mobile scaffold, Saved Messages desktop embed.
- Verification: dart analyze lib/chat/chat_screen.dart lib/home/home_screen.dart returned no error-level findings. Existing warnings/infos remain.
- Build: Not run for this change.


## REG-20260716-CHAT-SELECTION-SCROLL-LOCK
- Date: 2026-07-16 12:06:05
- Regression Scope: Chat open position, jump-to-latest button, new message auto-scroll, text selection/copy inside message bubbles.
- Verification: dart analyze lib/chat/chat_screen.dart returned no error-level findings. Existing warnings/infos remain.
- Build: Not run for this change.


## REG-20260716-DESKTOP-PANEL-BUBBLE-WIDTH
- Date: 2026-07-16 12:12:05
- Regression Scope: Desktop chat open, profile panel toggle, message bubble layout, attachment/checklist/poll/contact bubbles.
- Verification: dart analyze lib/home/home_screen.dart lib/chat/chat_screen.dart returned no error-level findings. Existing warnings/infos remain.
- Build: Not run for this change.


## REG-20260716-MULTIPLATFORM-DRAFT-BUILD
- Date: 2026-07-16 13:20:24
- Regression Scope: Release packaging, draft registration, artifact upload reachability.
- Verification: PHP lint passed. flutter analyze completed with existing warnings/infos. Web/APK/Windows builds succeeded. Live artifact HEAD checks returned HTTP 200.
- Residual Risk: Manual app smoke testing on target devices still recommended before employee 302 production approval.


## REG-20260716-STANDALONE-FLOW-MASTER-ADMIN
- Date: 2026-07-16 15:34:05 +05:30
- Risk: Local admin_config.php must be deployed with correct DB/XMPP credentials or /admin will show configuration error.
- Risk: Full-control admin actions are powerful; mitigated with super-admin allowlist, CSRF, confirmation UI, and audit logging.
- Regression check: Admin no longer requires /chat/bootstrap.php; PHP lint passed; chat app files were not modified.

## REG-20260716-ADMIN-SPLIT-GROUPS-CHANNELS
- Time: 2026-07-16 18:15:28
- Risk: Admin UI cache may keep old app.js; user should hard refresh.
- Checked: PHP syntax valid locally and on live server; admin app remains standalone under /admin.


## REG-20260716-ADMIN-GROUP-CHANNEL-FUNCTION
- Time: 2026-07-16 18:20:59
- Checked: Admin API route now has matching function for Groups and Channels views; overview counts unchanged.


## REG-20260720-C1C2-GROUP-CHANNEL-CREATE-BLOCK
- Date: 2026-07-20
- Scope: Group/channel creation authorization.
- Verified: Local PHP syntax passed for bootstrap/create_group/create_channel/profile; live server PHP syntax passed after upload; flutter analyze on home_screen.dart had no new blocking errors, only existing warnings/info.
- Regression Watch: A/B users should still create groups/channels; C1/C2 should receive 403 from backend and UI feedback before create sheet opens.

## 2026-07-21 - Saved Messages Download Regression
- Scope: Saved Messages file/image UI only. Verified dart format passed. flutter/dart analyze timed out in this workspace, so no full analyzer result was produced.

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

## 2026-07-23 17:53:58 +05:30 - Web Build After Right Click Menu Fix
- Build: flutter build web --release --base-href /chat/
- Result: Passed. Output generated at build/web.
- Scope: Includes restored message right-click floating menu and channel hashtag support.
- Notes: Flutter reported dependency update notices and wasm dry-run suggestion only; no build failure.

## 2026-07-23 18:37:04 +05:30 - Local Admin Run
- Action: Started standalone admin Laravel app locally.
- Command: C:\xampp\php\php.exe artisan serve --host=127.0.0.1 --port=8000 from admin folder.
- Result: Local server responded HTTP 200 OK at http://127.0.0.1:8000/.
- Notes: Secret config files were not read or printed.

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

## 2026-07-24 11:53:02 - External API Regression Check
- Existing chat endpoints were not modified; new API layer is isolated under server_patch/api.
- Risk: attendance v1 remains deployment-table-specific placeholder until live attendance schema is mapped.
- PHP syntax check passed for all new API files.


## 2026-07-24 12:18:16 - Expanded API Regression
- Existing /chat app endpoints remain untouched; external APIs stay isolated under /api.
- Runtime schema guards were added for new external helper tables and location columns.
- Known limitation: external file upload uses base64 JSON transport first; multipart can be added later without changing route names.


## 2026-07-24 12:34:54 - API Docs Regression Note
- No runtime code changed for this documentation task.
- Documentation uses live base URL requested by user.


## 2026-07-24 12:49:18 - Plugin System Regression
- Core messenger logic remains generic; no plugin-specific behavior embedded in send/create/member code.
- Plugin exceptions are caught and logged separately so core chat operations continue.
- Risk: same-request PHP sandbox cannot hard-timeout CPU-bound plugins; future async worker recommended for heavy plugins.


## 2026-07-24 13:10:00 - Chat Selection Regression Note
- Expected preserved behavior: opening a chat can still land on the latest message because no selection freeze is active at initial load.
- Expected fixed behavior: selecting/copying message text should not trigger pending forced auto-scroll or delayed retry jumps.
- Remaining manual check: verify web browser text drag selection and normal chat scrolling together on the deployed build.

## 2026-07-24 14:34:05 +05:30 - Web Build Regression Check
- Verification: Web release build completed successfully after chat selection freeze changes.
- Risk: Manual browser validation still needed for message text selection stability on the deployed web build.

## 2026-07-24 14:53:05 +05:30 - Chat Scroll Selection Regression
- Verification: dart format passed; flutter analyze .\\lib\\chat\\chat_screen.dart completed with existing lint warnings only.
- Expected behavior: normal message click no longer freezes/changes scroll state; selecting text still preserves viewport; jump-to-latest button state refreshes after selection.

## 2026-07-24 14:58:22 +05:30 - History Limit Regression
- Verification: php -l passed for server_patch/chat/history.php.
- Risk: Returning more history can increase payload size for very active groups; full paginated load-older is recommended as the next improvement.

## 2026-07-24 15:08:16 +05:30 - Web Build Regression Check
- Verification: Web release build completed after chat selection fix and history limit patch.
- Manual checks recommended: web chat text selection, jump-to-latest button, old group history loading after server history.php upload.

## 2026-07-24 - Chat Selection Regression Verification
- Scope: sent/received text bubbles, long/formatted messages, Read more, action menu, scrolling, queued history updates.
- Verification: dart format passed. flutter analyze lib/chat/chat_screen.dart completed with no compile errors; 48 existing warnings/infos remain in the large chat file unrelated to this change.
- Manual acceptance still needed in Chrome: drag-select message text, Ctrl+C, paste, menu actions, scroll.

## 2026-07-24 15:55:18 - Regression Verification
- Verified message text rendering still uses SelectableText.rich.
- Verified right-click context menu handler remains enabled through onSecondaryTapDown.
- Verified mobile/touch swipe reply and long-press actions remain enabled because the new guard applies only Web/Desktop plain text bubbles outside message-selection mode.
- Ran dart format and flutter analyze for lib/chat/chat_screen.dart; analyzer reports existing warnings/info only, no compile errors from this change.


## 2026-07-24 15:55:36 +05:30 - Regression Check: Chat Text Selection
- Scope: Sent/received text bubbles, formatted text, long messages/read more, right-click message actions, attachments, scrolling.
- Risk mitigated: Parent GestureDetector no longer competes with SelectableText mouse drag on web/desktop plain text bubbles.
- Verification: dart format passed; flutter analyze .\\lib\\chat\\chat_screen.dart completed with existing warnings/info only and no new compile errors from this change.


## 2026-07-24 16:03:47 +05:30 - Web Build Regression Check
- Scope: Full Flutter web compilation after chat text selection fix.
- Result: Passed; build/web generated successfully.
- Manual checks pending: Chrome text selection, Ctrl+C, jump-to-latest button, message actions, scrolling.

## 2026-07-24 16:20:07 +05:30 - Web Build Verification
- Scope: Full Flutter web release compile after chat history spinner fix.
- Result: Passed; build/web generated successfully.
- Manual checks pending: open chat history, message text selection, Ctrl+C copy, scrolling, jump-to-latest button.

## 2026-07-24 16:45:46 +05:30 - Regression Verification
- Area: Chat message selection, chat scrolling, jump-to-latest, message action menu.
- Result: Automated build passed. Manual browser verification still recommended on live deployment with long/short sent and received messages.
- Risk: Existing analyzer warnings remain unrelated to this scoped change.

## 2026-07-24 17:24:54 +05:30 - Regression Verification
- Area: Home chat list, channel filter, recent chat API.
- Result: PHP syntax passed; Dart analyzer has no compile errors for changed files. Existing analyzer warnings remain unrelated.
- Manual checks: Channel list should show badge only when next_action_persons is present; personal chats/groups without channel next action remain unchanged.

## 2026-07-24 17:31:47 +05:30 - Web Build Regression Check
- Area: Flutter web build output.
- Result: Release build passed with no build errors.
- Manual check pending: Verify channel list badge rendering with live next_action_persons/next_action_date data.

## 2026-07-24 18:00:10 +05:30 - Release Regression Verification
- Area: Android release build and draft deployment.
- Result: flutter build apk --release passed; PHP register script syntax passed; uploaded APK URL returned HTTP 200; draft registration returned release_id 33.
- Manual check: Employee 302 should approve from Release Management before production rollout.

## 2026-07-24 - AI API Room Toggle Regression Notes
- Verified: PHP lint passed for server_patch/chat/ai_access.php.
- Verified: flutter analyze on changed Dart files reported no compile errors; existing warnings/info remain.
- Risk: Live server must receive chat/ai_access.php before deployed web/app can call the endpoint.


## 2026-07-25 - Web Build Verification
- Verified: Flutter web release compilation completed successfully.
- Risk: Manual browser smoke test not run in this turn.


## 2026-07-25 - AI API Access Page Verification
- Verified: PHP lint passed before upload.
- Verified: Live endpoint reachable and protected by authentication.
- Manual app check pending: open AI API menu while logged in as 302 and refresh if cached.


## 2026-07-25 - AI Access Regression Verification
- Verified: PHP lint passed for AI access endpoints.
- Verified: Live endpoints return HTTP 401 without session, confirming protected endpoint availability.
- Verified: Flutter analyzer found no new compile errors in changed files; existing warnings remain.
- Pending: Web build/deploy required for live UI menu update.


## 2026-07-25 - Regression Verification: Channel/Folders/Reply
- Verified: Changed Dart files analyze without compile errors.
- Preserved: Existing chat actions, folder create/delete/reorder, and chat opening flows remain in place.
- Pending manual check: Mobile manage channel sheet with live channel metadata; folder edit UX; reply jump highlight in browser/app.

## 2026-07-25 - Regression Verification: Latency Patch
- Verified: Backend PHP syntax is valid.
- Verified: Dart API client has no compile errors.
- Risk: Live server must allow PHP CLI exec or run ai_room_worker.php through a queue/cron for @ai replies after this async change.
- Manual check pending: send normal text, send @ai message in enabled channel, confirm normal send returns faster and AI reply appears shortly after.

## 2026-07-25 - Web Build After Latency Patch
- Verified: Web release compilation passed.
- Pending manual smoke test: login, chat list, open chat, send message, AI room reply, folders/channel manage views.

## 2026-07-25 - Regression Verification: Chat Folders
- Verified: Existing filter strip keeps default filters and appends custom folders.
- Verified: Folder edit/delete/reorder calls the same save path, now backend-backed.
- Risk: Live app will fail folder load/save until chat_folders.php is deployed to server_patch/chat live path.
- Manual pending: Create folder, reorder, refresh/rebuild, confirm order and membership persist.

## 2026-07-25 - Mobile Composer Responsive Cleanup
- Verified: Composer still uses the same send, long-press send target, schedule, voice, attach, emoji, and text controller callbacks.
- Preserved: Formatting actions remain available from the composer text selection context menu after selecting text.
- Pending manual check: Install/run APK on narrow and normal Android phones, type long text, confirm composer remains compact and send/voice/attach still work.


## 2026-07-25 - Enter To Send User Setting
- Verified: Default remains Enter-to-send for existing users because missing preference defaults to true.
- Verified: Shift/Ctrl+Enter newline path is preserved when Enter-to-send is enabled.
- Verified: Send button path is unchanged and still sends regardless of keyboard preference.
- Pending manual check: Toggle setting in Appearance, test Enter and Shift/Ctrl+Enter on web/desktop/APK hardware keyboard and Android soft keyboard send action.


## 2026-07-25 - v2.0.6 Web APK Build And Android Draft
- Verified: flutter analyze .\\lib\\main.dart passed with no issues.
- Verified: Flutter web release build passed.
- Verified: Flutter Android release APK build passed.
- Verified: register_draft_2_0_6.php PHP syntax passed and live execution returned release_id=34.
- Pending manual smoke: login, chat open/send, composer Enter setting, file send/download, task screen, and 302 approval flow.


## 2026-07-27 - Regression Verification: Full View Image Preview
- Verified: Audio, location, PDF, office, text, and binary preview branches were not changed.
- Verified: The image preview still uses the existing attachment bytes path and broken-image fallback.
- Preserved: Attachment preview screen structure, download action, and non-image preview flows remain unchanged.
- Pending manual check: Open an image in web/APK, zoom in/out, pan across the image, and confirm the image is no longer trapped inside a small box.

## 2026-07-27 - Regression Verification: Android Public Download Visibility
- Verified: Existing web download flow remains unchanged.
- Verified: Restricted files still block download and remain in-app only.
- Verified: Normal attachment download callers and saved-message download callers still use the same chat API path and success snackbar flow.
- Pending manual check: On Android, download an image and confirm it appears in Gallery/Pictures; download a document and confirm it appears in Files > Downloads/Skylink.
- Environment blocker: Native compile was not fully verified locally because the machine does not have JAVA_HOME/java configured for Gradle.

## 2026-07-27 13:00:45 - Workspace Filter Verification
- Verified All remains first and Workspace remains second in filter strip.
- Verified reorder dialog operates only on movable filters: Unread, Online, Personal, Groups, Channels, Starred.
- Verified Channels filter excludes non-core channel kinds; Workspace filter includes non-core channel kinds.
- Ran dart format and flutter analyze on touched files; analyzer reported existing warnings/info only, no compile errors.


## 2026-07-27 13:10:59 +05:30 - Chat List Attachment Preview Regression Check
- Scope: Recent chat list and chat folder list preview rendering.
- Preserved: Normal text message previews still use existing plain-text cleanup; voice message icon remains for non-file voice previews; group/channel filtering untouched in this change.
- Risk: Live server must deploy server_patch/chat/recent_chats.php so older API responses do not omit file metadata.
- Validation: PHP lint passed and scoped Flutter analyze showed no compile errors from this change.


## 2026-07-27 14:50:32 +05:30 - Broadcast Regression Check
- Scope: Home compose actions, drawer actions, user search, direct message persistence, Type A authorization.
- Preserved: Existing direct chat, group, channel, selected-user send, and attachment flows were not rewritten.
- Risk: First version is text-only; file/location/voice broadcast support remains future work. Live server must deploy server_patch/chat/broadcast.php.
- Validation: server_patch/chat/broadcast.php PHP syntax passed; Flutter analyzer has no new compile errors.


## 2026-07-27 - Broadcast Regression Verification
- PHP syntax check passed for server_patch/chat/broadcast.php.
- dart format completed for lib/chat_api.dart and lib/home/home_screen.dart.
- flutter analyze completed with no new compile errors; existing lint warnings remain in scoped files.
- Existing one-shot send remains supported through optional broadcastId API signature.


## 2026-07-27 - Slash AI Metadata Verification
- PHP lint passed for conversation_metadata_helper.php, ai_room_helper.php, send_message.php, create_group.php, and update_channel.php.
- dart format completed for lib/chat/chat_screen.dart and lib/ai_api_screen.dart.
- flutter analyze completed for the modified Flutter files with no compile errors; existing warnings remain unrelated to this change.
- Metadata write failures are caught/logged so core message send remains protected.


## 2026-07-27 - Employee Event Notification Verification
- PHP lint passed for server_patch/chat/employee_event_notifications.php.
- No Flutter UI/build changes were required.
- Duplicate protection uses event date/type/source employee/recipient plus unique notification reference.


## 2026-07-27 - Next Action Summary And Clarification
- Preserved: Existing send_message flow still saves normal next action text/person/date and does not block message sending if timeline/metadata logging fails.
- Preserved: Existing checklist, poll, attachment, contact, and normal selectable text message rendering remain separate branches.
- Risk: Live server must deploy the new PHP endpoint and helper changes so auto-created columns exist before the UI update card can save.


## 2026-07-27 - Wake-up Last Message Summary
- Preserved: Existing wake-up due calculation, Ejabberd groupchat send, xmpp_messages persistence, and wakeup_last_sent_at update remain unchanged.
- Risk: Live server must deploy wakeup_helpers.php for new summary text to appear in scheduled wake-up notifications.


## 2026-07-27 - Web Build After Wake-up Summary
- Verification: Web release compiled successfully after wake-up last-message summary backend patch and prior chat metadata updates.
- Remaining manual checks: Deploy server_patch/chat/wakeup_helpers.php with the web build, then confirm scheduled wake-up messages include Last message summary in group/channel chat.

