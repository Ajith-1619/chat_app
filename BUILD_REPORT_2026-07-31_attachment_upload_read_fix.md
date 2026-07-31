# Build Report - 2026-07-31 - Attachment Upload Read Fix

## Summary
Fixed a chat attachment regression where Android/Desktop file pickers could return a local file path without in-memory bytes, causing Flow to stop with Unable to read <file> before upload began.

## Changed Files
- lib/chat/chat_screen.dart

## Root Cause
The upload pipeline expected PlatformFile.bytes for normal attachments. Some pickers/share flows only provided path, so Flow threw an exception before attempting upload.

## Fix
- Added a native-path byte fallback for non-web, non-streamed attachments.
- Preserved the existing stream/path upload path for videos and larger files.

## Validation
- dart format lib/chat/chat_screen.dart
- lutter analyze lib/chat/chat_screen.dart
  - Result: existing warnings/infos remain, no new analyzer errors from this change.

## Notes
- PROJECT_STATE.md and CHANGE_LEDGER_SPEC.md are still missing from the workspace during mandatory doc review.
- No web/apk/windows build was run for this hotfix.
