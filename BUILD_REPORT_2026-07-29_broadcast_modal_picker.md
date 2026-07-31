# Build Report - Broadcast Modal Picker

Date: 2026-07-29 17:05:00 +05:30

## Requirement
Broadcast creation should open as a modal view, not a bottom drawer, and recipient selection must remain visible and scrollable.

## Files Changed
- lib/home/home_screen.dart

## Implementation
- Changed showBroadcastSheet to open a centered Dialog.
- Updated BroadcastSheet to use max width/height constraints and keyboard inset padding.
- Kept broadcast list, name, message, search, select-all, save, delete, and send logic unchanged.
- Added a dedicated Scrollbar/ListView recipient area with an empty state.
- Compacted the message field to keep recipient selection visible.

## Verification
- Ran dart format .\lib\home\home_screen.dart.
- Ran flutter analyze .\lib\home\home_screen.dart.
- Result: existing warnings/info remain; no new blocking compile errors identified.

## Build
No web/APK/Windows build was requested for this change.
