# Build Report - 2026-08-05 - Horizon Timeout Fix

## Status
Implemented and locally linted. No Flutter build was required for this backend-only correction.

## Root Cause
The Horizon punch query opened the remote task database before reading attendance from the primary employee database. The task and employee PDO connections were not bounded by a connect timeout, so a slow/unreachable remote database could consume the client HTTP timeout. Location queries also assumed every location table had an `id` column.

## Changes
- Employee attendance DB is queried first.
- Task DB is opened only when the employee DB has no supported punch table.
- Task and employee PDO connections have a five-second connection timeout.
- Horizon location/timeline ordering no longer requires an `id` column.
- Employee 218 is included in the elevated Horizon visibility list.

## Verification
- `php -l server_patch/chat/myhub.php`: passed.
- `php -l db.php`: passed.
- Live deployment and timing verification remain pending.
## UI Follow-up (2026-08-05)
- Horizon landing view now remains cards-first and does not auto-open the first employee route.
- All employees live view uses a compact 340px map panel and employee cards below it.
- Clicking a map marker or employee card opens that employee's route/timeline screen.
- Horizon location and timeline requests use a 45-second request budget; normal chat requests retain the existing 20-second default.
- Flutter analysis: no errors; only pre-existing informational style lints.

## 2026-08-05 Horizon Navigation Correction
- Main Horizon remains cards-first; employee route/timeline is no longer rendered inline on the landing page.
- Employee card click opens a separate `HorizonEmployeeMapScreen` route.
- All employees live view opens a separate `HorizonAllEmployeesMapScreen` route with compact map and cards.
- Web release rebuilt successfully after the navigation correction.

## 2026-08-05 Horizon Card Grid and Separate Route Correction
- Replaced Horizon employee list rows with responsive employee cards: 3 columns on wide web, 2 on tablet, 1 on mobile.
- Removed the selected employee route/timeline from the Horizon landing page.
- Employee cards now open a dedicated employee route/timeline page.
- The All employees live view remains a separate map page and uses the same card grid.
- Verified `flutter analyze --no-pub lib/myhub_horizon_screen.dart lib/chat_api.dart`: no errors; only existing style infos in chat_api.dart.
- Verified `flutter build web --release`: succeeded; output is `build/web` and WASM dry run succeeded.

## 2026-08-05 Horizon Fresh Clean Web Artifact
- Performed `flutter clean` before rebuilding to remove stale incremental web artifacts.
- Rebuilt release web bundle successfully; build id is 2.0.9 / build number 32.
- Current source routes employee cards to `HorizonEmployeeMapScreen`; main Horizon does not render an inline employee route.

## 2026-08-05 Horizon Deployment Root Correction
- Verified fresh artifact does not contain the old inline Horizon route marker (`Full view` / selected inline route widget).
- Confirmed project deployment documentation: Flutter live web files must replace `/var/www/html/chat/`; `/var/www/html/router_login/chat/` is the PHP/API backend folder and cannot update the Flutter UI.

## 2026-08-05 Horizon Compact Map and Timeline Scroll Fix
- Reduced all-employees map height from 340px to 260px so employee cards remain visible in the same viewport.
- Reduced individual route map to 220px mobile / 280px wider layouts.
- Wrapped individual route/timeline content in `SingleChildScrollView`; half-hour points and address details are now reachable by scrolling.
- Preserved existing draggable/zoomable OSM map interaction. Google Maps requires a configured browser API key and billing project before switching providers.
- Validation: `flutter analyze --no-pub lib/myhub_horizon_screen.dart` passed; `flutter build web --release` passed with WASM dry run.
