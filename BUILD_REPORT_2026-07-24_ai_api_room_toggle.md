# Build Report - AI API Room Toggle

Date: 2026-07-24
Status: Implemented locally, build not requested

## Requirement
Add an AI API menu for authorized users. The menu must show the user's involved groups and channels, allow per-room AI enable/disable, and use the default Open Router API provider (id 2) when enabled. The AI API side menu must only appear for users who have AI access assigned, with employee 302 allowed as the controller/admin path.

## Changes
- Added `lib/ai_api_screen.dart` for group/channel AI toggles.
- Added `chat/ai_access.php` endpoint patch under `server_patch/chat/`.
- Added ChatApi methods for AI access load and room toggle save.
- Added drawer visibility gate using `sharedChatApi.hasAiAccess()`.

## Validation
- `C:\xampp\php\php.exe -l server_patch/chat/ai_access.php`: passed.
- `flutter analyze lib/chat_api.dart lib/home/home_screen.dart lib/ai_api_screen.dart`: no compile errors; existing warnings/info remain.

## Deployment Note
`server_patch/chat/ai_access.php` must be copied to the live chat backend as `chat/ai_access.php` before the deployed app can call this feature.
