
## BUILD-20260715-V2.0.4
- Timestamp: 2026-07-15 16:56:51 +05:30
- Version: 2.0.4+27
- Analyze: Completed with existing warnings/info only; no compile-blocking errors observed.
- Web build: flutter build web --release --base-href /chat/ succeeded.
- APK build: flutter build apk --release succeeded.
- APK artifact: release/Skylink-Chat-v2.0.4.apk (66010233 bytes)
- Web artifact: release/Skylink-Chat-Web-v2.0.4.zip (11336086 bytes)
- Uploaded APK URL: https://dns.watchtower247.in/router_login/downloads/Skylink-Chat-v2.0.4.apk
- Draft registration: android draft release_id=29

## BUILD-STATUS-20260715-GROUP-ADMIN-PERMISSIONS
- Timestamp: 2026-07-15 17:23:59 +05:30
- Build: Not run.
- Validation: flutter analyze and PHP lint only.


## BUILD-20260715-WEB-V2.0.4-SCROLL-FIX
- Timestamp: 2026-07-15 17:52:07 +05:30
- Version: 2.0.4+27
- Command: flutter build web --release --base-href /chat/
- Status: Success
- Output: build/web
- Artifact: release/Skylink-Chat-Web-v2.0.4.zip
- SHA256: release/Skylink-Chat-Web-v2.0.4.zip.sha256


## 2026-07-15 18:20:41 +05:30
- Build not requested and not run.
- Verification run: PHP syntax lint for modified backend files; Flutter analyze filtered for error-level issues.


## 2026-07-15 18:34:59 +05:30 - Web Build
- Command: flutter build web --release --base-href /chat/
- Result: Success.
- Output: build/web.
- Notes: Flutter reported dependency update notices and Wasm dry-run suggestion; no build failure.


## 2026-07-16 10:39:38 +05:30
- Build not requested and not run for location address display fix.


## 2026-07-16 11:03:55 +05:30
- Build not requested and not run for checklist/poll UI changes.



## BUILD-20260716-ATTACHMENT-RESTRICTED-VALIDATION
- Date: 2026-07-16 11:42:08
- Type: Validation only; no web/APK/Windows build requested or run.
- Checks: PHP lint passed for changed server files. Dart targeted analyzer produced no error-level output; warnings/infos are existing cleanup items.
- Status: Ready for build when requested.


## BUILD-20260716-SAVED-FORWARD-PASTE-VALIDATION
- Date: 2026-07-16 11:56:28
- Type: Validation only; no web/APK/Windows build requested or run.
- Checks: Dart targeted analyzer showed no error-level findings for changed Dart files.
- Status: Ready for build when requested.


## BUILD-20260716-CHAT-SELECTION-SCROLL-LOCK-VALIDATION
- Date: 2026-07-16 12:06:05
- Type: Validation only; no build requested or run.
- Checks: Dart targeted analyzer showed no error-level findings for lib/chat/chat_screen.dart.
- Status: Ready for build when requested.


## BUILD-20260716-DESKTOP-PANEL-BUBBLE-WIDTH-VALIDATION
- Date: 2026-07-16 12:12:05
- Type: Validation only; no build requested or run.
- Checks: Dart targeted analyzer showed no error-level findings for changed Dart files.
- Status: Ready for build when requested.


## BUILD-20260716-V2.0.4-MULTIPLATFORM-DRAFT
- Date: 2026-07-16 13:20:24
- Version: 2.0.4+27
- Web: Success, release/Skylink-Chat-Web-v2.0.4.zip, remote HTTP 200.
- APK: Success, release/Skylink-Chat-v2.0.4.apk, remote HTTP 200.
- Windows: Success, release/Skylink-Chat-Setup-v2.0.4.exe, remote HTTP 200.
- Draft IDs: android=29, windows=31, web=32.
- Approval: Production rollout still requires employee 302.


## BUILD-20260716-STANDALONE-FLOW-MASTER-ADMIN-VALIDATION
- Date: 2026-07-16 15:34:05 +05:30
- Type: Validation only; no Flutter/web/APK/Windows build requested or run.
- Checks: PHP lint passed for admin/admin_config.sample.php, admin/api.php, admin/health.php, admin/index.php, admin/logout.php, admin/_bootstrap.php.
- Status: Ready for server config/deploy verification.


## BUILD-20260716-ADMIN-LOGIN-FIX-VALIDATION
- Date: 2026-07-16 16:00:54 +05:30
- Type: Validation only; no build/deploy run.
- Checks: PHP lint passed for admin/_bootstrap.php and admin/bootstrap.php plus existing admin entry/API files.
- Status: Ready to upload admin/_bootstrap.php and admin/bootstrap.php to /var/www/html/admin/.


## BUILD-20260716-ADMIN-STRICT-STANDALONE-VALIDATION
- Date: 2026-07-16 16:12:53 +05:30
- Type: Validation only; no build/deploy run.
- Checks: PHP lint passed for all admin PHP files. Standalone dependency search passed with only local admin_config.php references.
- Status: Upload admin folder files and fill admin/admin_config.php on live server.


## BUILD-20260716-ADMIN-AUTH-FIX-VALIDATION
- Date: 2026-07-16 16:26:58 +05:30
- Type: Validation only; no build/deploy run.
- Checks: PHP lint passed for all admin PHP files.
- Status: Upload admin/_bootstrap.php and ensure admin/admin_config.php has real DB values.


## BUILD-20260716-ADMIN-CONFIG-DEPLOY
- Date: 2026-07-16 17:19:02 +05:30
- Type: Admin PHP deploy only; no Flutter build.
- Result: Uploaded standalone admin files to /var/www/html/admin with real local admin_config.php values copied from live chat config.
- Verification: SFTP upload succeeded; external HTTP health check unreachable from this environment.


## BUILD-20260716-ADMIN-USERS-FIX-DEPLOY
- Date: 2026-07-16 17:33:01 +05:30
- Type: Admin PHP/JS deploy only; no Flutter build.
- Result: Uploaded admin users list and overview cleanup fix to live admin folder.
- Verification: SFTP upload succeeded.


## BUILD-20260716-ADMIN-LIVE-USERS-DEPLOY
- Date: 2026-07-16 17:45:16 +05:30
- Type: Admin PHP/JS deploy only; no Flutter build.
- Result: Uploaded live chat users/password management update to /var/www/html/admin.
- Verification: SFTP upload succeeded.


## BUILD-20260716-ADMIN-LIVE-DB-FIX-DEPLOY
- Date: 2026-07-16 17:54:41 +05:30
- Type: Admin PHP/JS/config deploy only; no Flutter build.
- Result: Uploaded corrected admin config/bootstrap/API/JS to /var/www/html/admin.
- Verification: Server-side count check passed: 73 users, 11422 messages.

## BUILD-20260716-ADMIN-LIVE-VERIFY
- Time: 2026-07-16 18:15:28
- Scope: Standalone PHP admin app only; no Flutter web/APK/windows build requested or run.
- Validation: Local PHP lint passed for admin/api.php and admin/index.php.
- Live Validation: /var/www/html/admin/api.php lint passed; live counts verified as users=73, groups=164, channels=53.


## BUILD-20260716-ADMIN-GROUP-CHANNEL-FIX-VERIFY
- Time: 2026-07-16 18:20:59
- Scope: Admin PHP hotfix only; no Flutter build.
- Validation: Local and live PHP syntax passed. Live verification: function=yes, groups=164, channels=53.


## BUILD-20260720-C1C2-GROUP-CHANNEL-CREATE-BLOCK
- Date: 2026-07-20
- Type: Backend patch deploy, no Flutter build requested.
- Validation: PHP lint local/live passed. Flutter analyze scoped to lib/home/home_screen.dart completed with existing warnings/info only.
- Live Patch: server_patch/chat/*.php uploaded to /var/www/html/router_login/chat/.

## 2026-07-21 - Saved Messages Download
- Build not requested. dart format passed for lib/home/home_screen.dart; analyzer timed out.

## 2026-07-21 - Web Release Build
- Command: flutter build web --release
- Result: Success. Output: build/web. Notes: dependency outdated notices only; Wasm dry run succeeded.

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
