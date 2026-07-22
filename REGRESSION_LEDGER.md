
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
