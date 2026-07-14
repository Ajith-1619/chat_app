# Work Report - 2026-07-13

## Project

Skylink / Watchtower Flow Chat App

## Date

2026-07-13

## Summary

Today work report for tracking completed updates, builds, deploys, and pending checks.

## Completed Updates

### 1. Agent Documentation

- Created root-level `AGENTS.md`.
- Added project structure, build commands, release process, live server paths, task rules, MyHub rules, file/location notes, and known analyzer warnings.

### 2. MyHub Task Creation Rules

- Confirmed `task_master` legacy structure from provided screenshots.
- Updated task-create backend rules so task creation fills required/default fields, not only title and description.
- Defaults include priority, assignee, follower, group, task type, meet type, status, created by, next follow-up date, vertical, and timestamps.
- Protected task creation from failing when `task_explained` audit insert fails.

### 3. MyHub Task List and Filters

- Updated task list backend to include tasks where current user is:
  - assignee in `emp_id`
  - creator in `created_by`
  - follower in `task_followers` or `followed_by`
- Updated legacy status handling:
  - `status = 2` is treated as open/active.
  - closed statuses are treated as `3`, `4`, or `5`.
- Added/updated task filters:
  - All
  - Open
  - Request close
  - Closed
  - Created by me
  - Following
  - Due today
  - Overdue
  - Stale

### 4. Live Backend Deploy

- Deployed MyHub backend task-create/task-list fixes to live server:
  - `server_patch/chat/myhub.php`
  - `/var/www/html/router_login/chat/myhub.php`

### 5. Web Build

- Built Flutter Web release with base href `/chat/`.
- Command:

```powershell
flutter build web --release --base-href /chat/
```

- Output:
  - `build/web`



### 6. Message Location Metadata vs Location Attachments

- Fixed normal text/file messages so saved send/read latitude-longitude metadata does not make the message render as a location attachment.
- Normal messages can carry send/read location metadata for Message Info only.
- Current location and live location continue to render as map cards only when sent through the explicit location attachment options.
- Chat history read calls now send read latitude/longitude metadata from the chat screen when available.
- Message bubble inline address display is limited to explicit location attachments; normal message metadata remains available in Message Info.



### 7. Attachment Download Fix

- Fixed web attachment downloads by routing `chatApi.downloadAttachment` through the existing browser download bridge instead of trying to write to a local filesystem path.
- Normal files and images now use `chat/media.php?download=1` for download behavior.
- Location messages are blocked from download because they are not files.
- Added a direct download button overlay on image bubbles.
- File tiles and preview-screen download actions continue to use the same download path.



### 8. Attendance Punch Out Availability

- Updated My Hub attendance UI so the Punch Out button is always enabled unless a punch action is currently in progress.
- Punch Out no longer depends on current punch-in/punch-out/carry-over state in the UI.
- Backend response will decide whether the punch-out action is accepted.

## Validation

- PHP syntax check passed for `server_patch/chat/myhub.php`.
- Flutter analyze was run for changed Dart files.
- No new Dart errors were introduced.
- Existing analyzer warnings remain from older code.

## Important Notes

- Current web build is local in `build/web`.
- UI filter changes require web/APK deployment to be visible to users.
- Live backend task fixes are already deployed.
- Release approval flow remains controlled by employee `302`.

## Pending / Next Checks

- Verify task creation from UI in live web/app.
- Confirm newly created task appears in MyHub task list.
- Confirm tasks where current user is follower appear under `Following`.
- Deploy latest web build to live `/var/www/html/chat/` when required.
- Build and upload next APK if Android users need the updated task filter UI.

## Update Log

- 2026-07-13: Created work report file.

### 9. Suggested Feature Roadmap From Project Review

- Restricted file workflow:
  - Add a sender-side Restricted file option during attachment preview.
  - Store restricted metadata with each attachment.
  - Allow restricted files to open only inside Flow preview.
  - Disable normal download/share actions for restricted files.
  - Add file view audit logs with viewer, time, device, and IP/location metadata where permitted.
  - Note: screenshot and screen-record blocking can be enforced more strongly on Android/Windows native builds than on Web.

- Enterprise file preview and edit center:
  - Open PDF, images, TXT, CSV, XLSX, DOC/DOCX, HTML, PHP/source files inside Flow by default.
  - Add read-only preview first, then controlled edit/version history for supported office/text formats.
  - Add annotations, comments, watermarking, and viewed-by tracking for business documents.

- Attachment download manager:
  - Add queued downloads with progress, retry, pause/cancel, and completed location display.
  - Show clear errors for missing server files, permission denial, and restricted files.
  - Keep image/file download available by default; block only restricted files and non-file location cards.

- Location intelligence:
  - Keep normal send/read latitude-longitude as metadata only for Message Info.
  - Keep current/live location as explicit map-card messages only.
  - Add live location expiry, stop sharing, viewer list, and update frequency controls.
  - Add location visibility policy by user/group/channel/admin role.

- MyHub task command center:
  - Expand Create Task with full legacy fields: priority, deadline, assignee, followers, group, type, vertical, meet type, and status.
  - Add task views: My Tasks, Created by Me, Following, Due Today, Overdue, Stale, Kanban, and Calendar.
  - Add SLA reminders, follow-ups, escalation rules, and task activity timeline.
  - Add message-to-task linking so task origin stays connected to chat context.

- Channel type architecture:
  - Complete metadata-driven Channel Definitions for Incident, Action, Operational, Project, and Announcement.
  - Each type should support its own SOP, SLA, KPIs, permissions, widgets, checklists, workflows, and AI Marshal behavior.
  - Add channel-to-channel relationships such as Incident -> Action, Operational -> Incident, and Project -> Action with full audit trails.

- AI Marshal layer:
  - Add AI Summary, task extraction, incident classification, SLA risk alerts, suggested replies, and action recommendation flows.
  - Add admin-controlled AI permissions per channel type and per role.
  - Keep all AI actions auditable with source message references.

- Release management:
  - Add in-app build upload/register screen for APK, Windows, Web, and Linux artifacts.
  - Keep Draft -> 302 Approval -> Production flow.
  - Add staged rollout percentage, forced update flag, rollback action, checksums, and release notes preview.

- Admin health dashboard:
  - Show XMPP status, API latency, notification delivery, pending queues, failed jobs, attachment storage health, and release status.
  - Add diagnostics for message send failures, read receipt failures, push failures, and group membership sync gaps.

- Offline and reliability improvements:
  - Add outbox queue with retry for messages/files/location/task actions.
  - Add duplicate prevention using client message IDs across reconnects.
  - Add conflict handling for task updates, attendance actions, and edited messages.

- Mentions and notification controls:
  - Improve group/channel member mention picker with real members, departments, roles, online users, admins, and everyone.
  - Add role-based permission for @everyone, @online, and @admins.
  - Add mention notification throttling for large channels.

- Attendance improvements:
  - Add carry-over shift resolver UI when a previous working day has no punch-out.
  - Add punch-out reason, correction request, supervisor approval, and attendance audit trail.
  - Add device/location confidence status for punch actions.

- Search and knowledge:
  - Add global search across chats, channels, files, tasks, reminders, follow-ups, and release notes.
  - Add saved filters and quick jump to original message/file/task.
  - Add OCR/indexing for images and PDFs where permitted.

- QA automation:
  - Add smoke tests for login, send text, send file, download file, current location, live location, task create, task list, punch in/out, and release approval.
  - Add regression tests for Android text send not becoming location messages.
  - Add performance checks for chat load, message send, file preview, task list, and notification delivery.


### 10. Attachment Picker, Contact Send, and Channel Date Picker

- Added Create checklist into the attachment picker near Document/File so checklist creation can start from the same send menu.
- Added Contact option in the attachment picker for Android.
- Added Android READ_CONTACTS permission and native contact picker bridge.
- Contact messages now send as Flow contact cards and render inside chat with name, phone, and email details.
- Updated channel creation Target date and Next action date fields to use date/time pickers instead of manual typing.

Validation:
- `flutter analyze .\lib\main.dart` completed with no new Dart errors.
- Existing warnings/info remain from older code.
- Android debug APK compile was attempted twice but timed out during Gradle/Flutter build; leftover build processes were cleaned up.


### 11. Clipboard Paste and Text Copy Fix

- Updated web file paste handling to listen during the capture phase so pasted files are received before Flutter text fields consume the paste event.
- Added clipboard file fallback naming for pasted images/files that do not provide a filename.
- Improved web text copy by using browser `navigator.clipboard.writeText` first, with the existing textarea fallback retained.
- Restored normal selection context menus for message text, attachment text previews, AI summary text, and translate dialog text so selected text can be copied.

Validation:
- `dart format` completed for changed files.
- `flutter analyze .\lib\main.dart .\lib\clipboard_media_bridge_web.dart .\lib\clipboard_text_bridge_web.dart` completed with no new errors; existing warnings/info remain.


### 12. v2.0.2 Draft Release Build and Upload

- Bumped app version to `2.0.2+25`.
- Built Flutter Web release with base href `/chat/`.
- Built Android release APK.
- Built Windows release app and packaged it as installer EXE, not zip.
- Created release artifacts:
  - `release/Skylink-Chat-v2.0.2.apk`
  - `release/Skylink-Chat-Setup-v2.0.2.exe`
  - `release/Skylink-Chat-Web-v2.0.2.zip`
- Generated SHA256 files for all three artifacts.
- Uploaded artifacts to live server downloads folder.
- Uploaded and executed `register_draft_2_0_2.php`.
- Draft release rows created:
  - Android release_id `23`
  - Windows release_id `24`
  - Web release_id `25`
- Release remains Draft / Development with rollout `0` and force update disabled; employee `302` approval is required to move live.

Validation:
- APK URL returned HTTP 200.
- Windows installer EXE URL returned HTTP 200.
- Web zip URL returned HTTP 200.
- `.gitignore` was rewritten as UTF-8 because Flutter web build crashed while reading it during migration.


### 13. APK Send Timeout, Task List Visibility, and Task Notification Fix

- Removed normal text-message GPS metadata lookup from APK send flow so text sends do not fail with the 6-second location timeout shown in the screenshot.
- Kept current/live location sending limited to explicit location actions only.
- Increased MyHub task list fetch limit from 30 to 100 so created/followed tasks are less likely to be hidden by older rows.
- Updated MyHub backend task ordering so tasks created by the current user are prioritized in the returned list.
- Disabled local task alert notifications during normal task list refresh so newly/open tasks do not appear as notification noise.
- Deployed `server_patch/chat/myhub.php` to live `/var/www/html/router_login/chat/myhub.php`.

Validation:
- PHP syntax check passed locally and on live server for `myhub.php`.
- `flutter analyze .\lib\main.dart .\lib\chat_api.dart .\lib\myhub_tasks_screen.dart` completed with no new errors; existing warnings/info remain.
- No web/APK/Windows build was created for this fix, as requested.

## 14. Message Location Metadata + Send Latency Correction
- Restored send/read lat-long and address metadata for normal text messages, files/images, voice notes, contacts, checklists, forwards where applicable.
- Kept current/live location as explicit map-card attachment only; normal sends now save location metadata without rendering as location messages.
- Added fast cached Android location/address lookup so composer sends do not wait on slow GPS/reverse-geocode calls.
- Added read-location address forwarding from Flutter to history.php so read address can be saved directly when available.
- Diagnostics showed `api/send_message_total` was blocked by `notification/dispatch_push` (~6 seconds). Changed send_message.php to queue push dispatch and spawn a background worker, keeping message DB/XMPP flow intact while returning faster.

## 15. Web/Windows/Location Intelligence Follow-up
- Diagnosed `chat.skylinkonline.net`: HTTP port 80 works for `/` and `/chat/`, HTTPS port 443 refuses connections. Users must open `http://chat.skylinkonline.net/chat/` until SSL is enabled on that host.
- Fixed map-card preview to render OpenStreetMap tiles inside the Flow app instead of depending on the failing static-map image service.
- Location attachment tap now opens an in-app map dialog; it no longer launches an external maps/browser app.
- Preserved the separation: normal send/read lat-long stays metadata for Message Info, current/live location stays explicit map-card messages.
- Added live-location stop control in the attachment sheet and made the update frequency visible as every 1 minute.
- Hardened Windows installer script so it verifies `skylink_chat.exe` was extracted before creating shortcuts/startup, preventing broken shortcuts to a missing exe.
- Remaining architecture item: full location visibility policy by user/group/channel/admin role needs schema/API/UI expansion beyond the current user-level visibility manager.

## 16. v2.0.3 Draft Build
- Fixed web selected-text copy: browser copy event now writes selected text to clipboard; Ctrl/Cmd+C is allowed.
- Fixed sender location address display under message bubbles for users with location visibility access; no longer limited to explicit location cards.
- Built and uploaded Android APK, Web ZIP, and Windows installer EXE as Draft.
- Registered Draft builds on live server: Android release_id=26, Windows release_id=27, Web release_id=28.
- Verified download URLs return HTTP 200.
- Artifact hashes:
  - APK: 2CFF4882BB997E766A17A6EA5603D30983DD6F8983715A6239E364378B0191F1
  - Web ZIP: 8537B52CDDC1847D1FD7294DDAA14FDCC51F9AE69BE2A58334514C67B56147E7
  - Windows EXE: 4159F8985A91A792FAAD42C56E9D51BD45A34D5F5253DBD43FDD1BE5075FFD49

## 17. MyHub Task Detail Hotfix
- Fixed task click/detail load failures caused by rigid `task_explained` update-history column assumptions.
- Detail endpoint now supports `task_explained`, `task_updates`, or `task_comments` and gracefully returns an empty update list if no compatible update table exists.
- Deployed `chat/myhub.php` to live server and verified remote PHP syntax.
