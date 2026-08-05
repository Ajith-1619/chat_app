# Build Report - Horizon Main Timeout Split Load

Date: 2026-08-04

## Requirement
- Horizon home must stop timing out on open.
- Main screen should load even when employee live-location enrichment is expensive.
- All-employees live map can remain heavier, but it must fetch separately so the base Horizon view stays responsive.

## Files Changed
- lib/chat_api.dart
- lib/myhub_horizon_screen.dart
- server_patch/chat/myhub.php

## What Changed
1. Added an optional `include_locations` flag to the Horizon API client.
2. Changed the main Horizon screen to request the lightweight attendance payload first.
3. Changed the all-employees live map to fetch the heavier location-enriched payload only when that map is opened.
4. Updated the PHP Horizon endpoint so latest-location enrichment only runs when `include_locations=1` is present.
5. Preserved the full-day employee timeline flow; only the load sequencing changed.

## Verification
- `php -l server_patch/chat/myhub.php`
  - Result: passed.
- Code-path verification
  - Result: main Horizon screen now calls `getMyHubHorizon(includeLocations: false)` and all-employees live view calls `getMyHubHorizon(includeLocations: true)`.
- `flutter analyze lib/myhub_horizon_screen.dart lib/chat_api.dart`
  - Result: timed out in this workspace before returning a final result.

## Deploy Note
- This fix requires both the Flutter client change and the updated `server_patch/chat/myhub.php` on the server. If only the web build is refreshed without the PHP patch, the timeout can still reproduce.
