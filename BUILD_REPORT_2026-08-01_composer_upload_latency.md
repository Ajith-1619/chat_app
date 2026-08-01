# Build Report - 2026-08-01 - Composer Trigger And Upload Latency

## Summary
Fixed the slow / and @ suggestion behavior when typing in the middle of message text, improved attachment preparation speed for manual picker/share/drop flows, and prepared the server upload-limit configuration needed for 50MB video/file uploads.

## Root Causes
1. Composer trigger detection relied on regex checks against the whole text and end-of-text patterns, which becomes less responsive when the cursor is in the middle of a longer draft.
2. Browser/manual picker and Android share conversion prepared files sequentially, adding unnecessary wait time before preview/send.
3. Live server upload failures were caused by PHP upload limits still being capped at upload_max_filesize=2M and post_max_size=8M.

## Files Changed
- lib/chat/chat_screen.dart
- lib/web_attachment_bridge_web.dart
- lib/shared/android_share_intent.dart
- server_patch/chat/.user.ini
- server_patch/chat/.htaccess

## What Changed
- Added lightweight cursor-aware composer token detection for / and @ suggestions.
- Slash suggestions now resolve from the cursor position instead of only the end of the full composer text.
- Web manual file selection now converts chosen browser files in parallel.
- Android share-intent file conversion now resolves incoming files in parallel.
- Drag/drop conversion now also resolves files in parallel.
- Increased deployable PHP upload limit config to 50MB files with 64MB post body allowance.

## Validation
- lutter analyze lib/chat/chat_screen.dart lib/web_attachment_bridge_web.dart lib/shared/android_share_intent.dart
- Result: No new compile errors from these changes. Existing analyzer warnings remain unrelated/pre-existing.

## Deployment Note
To fix the live The file is larger than the server upload limit. upload_max_filesize=2M, post_max_size=8M error, both hidden files below must be deployed to the live chat PHP folder:
- server_patch/chat/.user.ini
- server_patch/chat/.htaccess

If hidden files are skipped during upload, the live server will continue enforcing the old 2MB/8MB limit even though app code is correct.
