# Build Report - 2026-08-01 - Web File Picker Upload Fix

## Summary
Fixed the web chat attachment bug where manually selecting a file from the picker failed before upload, while drag/drop and copy/paste still worked.

## Root Cause
Flutter web manual picker flow could return selected PlatformFile objects without populated ytes, and the existing chat send flow requires readable bytes before upload starts.

## Files Changed
- lib/chat/chat_screen.dart
- lib/web_attachment_bridge_web.dart
- lib/web_attachment_bridge_stub.dart

## What Changed
1. Web attachment menu now uses a dedicated browser file-picker helper for media and file selection.
2. The helper reads browser File objects with FileReader.readAsArrayBuffer and converts them into byte-backed PlatformFile objects.
3. Non-web attachment picking behavior was left unchanged.
4. Added inline comments in the web bridge explaining why the dedicated picker path exists.

## Validation
- lutter analyze lib/chat/chat_screen.dart lib/web_attachment_bridge_web.dart lib/web_attachment_bridge_stub.dart
- Result: No new compile errors from this fix. Existing warnings in chat_screen.dart remain pre-existing and unrelated.

## Expected User Impact
- Web users can select files/images/videos through the normal file picker and send them.
- Existing drag/drop and copy/paste attachment flows continue to work.
- Upload behavior still uses the existing send pipeline, so preview/send UX stays consistent.
