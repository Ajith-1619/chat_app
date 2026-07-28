# Build Report - 2026-07-28 - Horizon Map Address

## Scope
- Horizon employee route map now displays OpenStreetMap tiles behind the GPS path.
- Route overlay, start marker, latest marker, and 30-minute checkpoint markers are aligned using Web Mercator map coordinates.
- 30-minute timeline now shows address when available, with coordinates retained below it.
- Horizon timeline API now returns saved location address where present and fills missing checkpoint addresses using the existing cached reverse-geocode helper.

## Files Changed
- lib/myhub_horizon_screen.dart
- server_patch/chat/myhub.php
- CHANGE_LEDGER.md
- BUILD_LEDGER.md
- REGRESSION_LEDGER.md
- REQUIREMENT_LEDGER.md
- FEATURE_LEDGER.md
- AI_DECISION_LEDGER.md

## Validation
- php -l server_patch/chat/myhub.php: passed
- flutter analyze lib/myhub_horizon_screen.dart: passed
- flutter build web --release --base-href /chat/: passed

## Deployment Notes
- Deploy build/web to the chat web build location.
- Deploy server_patch/chat/myhub.php to the live router_login/chat/myhub.php path so the timeline returns address data.
