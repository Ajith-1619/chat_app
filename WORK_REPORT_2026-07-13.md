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
