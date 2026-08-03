# Build Report - Horizon Latency And Map UX

Date: 2026-08-03 23:58:00 +05:30

## Requirement
- Reduce Horizon open latency.
- Stop selected employee route preview from timing out on heavier daily location data.
- Improve in-app map zoom/pan feel for web/desktop without replacing the current Horizon surface.

## Files Changed
- lib/myhub_horizon_screen.dart
- server_patch/chat/myhub.php

## What Changed
1. Replaced Horizon home latest-location lookup from per-employee queries to a single batched candidate query over visible employees.
2. Preserved each employee's punch window filtering while selecting the newest valid point for the preview.
3. Reduced timeline latency by capping expensive reverse-geocode fallback work during half-hour checkpoint generation.
4. Improved both Horizon maps to zoom around the pointer location instead of always around the viewport center.
5. Increased nearby tile coverage and enabled gapless/medium-quality tile rendering for smoother navigation.
6. Kept the existing Horizon UX structure intact so employee list, separate live view, and full route view continue working the same way.

## Verification
- `flutter analyze lib/myhub_horizon_screen.dart lib/chat_api.dart`
  - Result: no new analyzer errors; existing info-level suggestions remain in `lib/chat_api.dart`.
- `php -l server_patch/chat/myhub.php`
  - Result: passed.
- `php -l server_patch/chat/bootstrap.php`
  - Result: passed.

## Known Follow-up
- Production browser verification is still needed against live Horizon datasets to confirm the timeout no longer reproduces and the map interaction feels better with real employee density.
