# Build Report - New Channel Member List Scroll

Date: 2026-07-29 16:40:00 +05:30

## Requirement
New channel creation modal must show searched users in a scrollable selectable list.

## Files Changed
- lib/home/home_screen.dart

## Implementation
- Increased the bounded modal height for the new group/channel sheet.
- Reduced channel description field height so it does not consume the member list area.
- Added a dedicated scrollable member results list with visible scrollbar and empty state.
- Preserved existing select-all visible users, search filtering, selected count, and create behavior.

## Verification
- Ran flutter analyze .\lib\home\home_screen.dart.
- Result: existing warning/info backlog remains; no new blocking compile errors identified.

## Build
No web/APK/Windows build was requested for this change.
