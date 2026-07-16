
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
