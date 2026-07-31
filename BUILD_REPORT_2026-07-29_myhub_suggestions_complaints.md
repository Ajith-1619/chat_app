# Build Report - MyHub Suggestions & Complaints

Date: 2026-07-29 17:45:00 +05:30

## Requirement
Add Suggestions & Complaints to MyHub. Users must select who the item is for; the selected user must see the submitted item in their list.

## Files Changed
- server_patch/chat/myhub.php
- lib/chat_api.dart
- lib/myhub_suggestions_screen.dart
- lib/home/home_screen.dart

## Implementation
- Added chat DB-backed suggestion_complaints schema ensure/migration.
- Added assigned_to_emp_id and assigned_to_username support for receiver visibility.
- Added GET/POST MyHub section: chat/myhub.php?section=suggestions.
- Added up to 5 file uploads stored under uploads/suggestions/{emp_id}/{date}.
- Added system notification to the selected user when a suggestion/complaint is submitted.
- Added Flutter ChatApi methods for loading/submitting suggestions.
- Added MyHub Suggestions & Complaints screen and MyHub tile routing.

## Verification
- PHP lint passed for server_patch/chat/myhub.php.
- Dart format passed after converting the new file to UTF-8.
- Flutter analyze on touched Dart files completed with existing warnings/info; no new blocking compile errors identified.

## Build
No web/APK/Windows build was requested for this change.
