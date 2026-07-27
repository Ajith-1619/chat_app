# Build Report - 2026-07-25 DB Chat Folders

## Scope
- Move chat folders from local SharedPreferences to backend DB persistence.
- Preserve folder edit, delete, reorder, and filter-strip display.
- One-time migrate existing local chat_folders_v1 data to backend if backend has no folders.

## Files Changed
- lib/chat_api.dart
- lib/home/home_screen.dart
- server_patch/chat/chat_folders.php

## Backend Table
- xmpp_chat_folders
- emp_id
- folder_name
- chat_jids_json
- sort_order
- created_at
- updated_at

## Validation
- php -l server_patch/chat/chat_folders.php passed.
- dart format passed for lib/chat_api.dart and lib/home/home_screen.dart.
- flutter analyze lib/chat_api.dart lib/home/home_screen.dart completed with no compile errors; existing warnings/info remain.

## Build
- Not run in this turn.

## Deployment Note
Deploy server_patch/chat/chat_folders.php to the live chat API folder before releasing the web/app build that calls it.
