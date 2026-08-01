# Build Report - 2026-08-01 - Muted Punch and Location Notifications

## Summary
Changed notification routing so operational info notifications such as punch in, punch out, and location-off alerts arrive as muted notifications, while actual DM, group, and channel messages continue to use the normal high-priority chat notification behavior.

## Files Changed
- lib/notification_service.dart
- server_patch/chat/FirebasePush.php

## Root Cause
Both app-side local notifications and server-side FCM payloads were using the same high-priority message channel with sound enabled for every notification type.

## Implementation
- Added a dedicated muted Android notification channel: `skylink_system_info`.
- Added shared detection for muted operational info categories using `event_type` and text fallback matching.
- App foreground/background local notifications now route punch/location info to the muted channel.
- Server FCM push payload now routes the same categories to the muted channel and removes the default sound.

## Verification
- `flutter analyze lib/notification_service.dart`
- `php -l server_patch/chat/FirebasePush.php`

## Notes
`PROJECT_STATE.md` and `CHANGE_LEDGER_SPEC.md` were not present in the workspace during this update.
