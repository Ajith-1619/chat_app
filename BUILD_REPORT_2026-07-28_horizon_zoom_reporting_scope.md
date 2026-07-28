# Build Report - 2026-07-28 - Horizon Zoom And Reporting Scope

## Scope
- Horizon map now has zoom in/out controls and mouse-wheel zoom support.
- Super users 116, 232, 302, 428, and 553 keep all-employee Horizon visibility.
- Other users can view only their own data and direct reports from employee.reporting_to.
- Timeline endpoint enforces the same access rule.

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

## Build
- Not run for this change.

## Deployment Notes
- Upload server_patch/chat/myhub.php to live router_login/chat/myhub.php for reporting_to visibility.
- Run/deploy a Flutter web build for map zoom controls to appear in the live web app.
