# Change Ledger

## CHG-2026-07-17-002 - Laravel conversion
- Requirement: REQ-2026-07-17-002
- Impact Analysis: Admin folder is now a Laravel 12 project. Existing backend helpers/API are preserved under legacy_standalone and invoked through Laravel routes.
- Regression Verification: route:list, syntax lint, and artisan test passed.
- Status: Completed

## CHG-2026-07-17-003 - User detail aggregation
- Requirement: REQ-2026-07-17-003
- Impact Analysis: Adds read-only aggregation endpoint and changes Users action from direct password edit to View/Edit detail modal. Existing password update endpoint remains available from inside the modal.
- Regression Verification: PHP lint, JS syntax check, and artisan test passed.

## CHG-2026-07-17-004 - User detail modal scroll and UI polish
- Impact Analysis: Frontend-only redesign for user detail modal, asset cache busting, internal modal scroll, and background scroll lock.
- Regression Verification: node --check, Blade lint, and artisan test passed.

## CHG-2026-07-17-005 - Group/channel detail and role management UI
- Impact Analysis: Simplifies group/channel list columns and adds full detail modal. Existing update_group, set_member_role, and remove_member actions are reused.
- Regression Verification: API lint, JS syntax check, and artisan test passed.

## CHG-2026-07-17-006 - Group member list dynamic columns fix
- Impact Analysis: Group/channel detail member query now selects only existing member columns, so missing joined/read/mute fields no longer hide members.
- Regression Verification: API lint, JS syntax check, and artisan test passed.

## CHG-2026-07-17-007 - User group/channel memberships
- Impact Analysis: Adds read-only membership aggregation to user_detail and opens existing group detail modal from membership rows.
- Regression Verification: API lint, JS syntax check, and artisan test passed.

## CHG-2026-07-17-008 - Separate admin module routes
- Impact Analysis: Sidenav now navigates to Laravel pages like /users, /groups, /channels, /tasks, /location, /notifications, /releases, /diagnostics, and /audit. Existing API-driven content and modals are preserved.
- Regression Verification: route:list, PHP lint, JS syntax check, and artisan test passed.

## CHG-2026-07-17-009 - Users/groups/channels master-detail layout
- Impact Analysis: Replaces table-first users/groups/channels rendering with two-column master-detail layout. Existing detail APIs and edit actions are reused.
- Regression Verification: JS syntax, PHP lint, and artisan test passed.

## CHG-2026-07-17-010 - Live search fix for master-detail pages
- Impact Analysis: Frontend API calls now use absolute /api path for separate pages. User search now includes name and designation after profile join.
- Regression Verification: JS syntax, API lint, and artisan test passed.

## CHG-2026-07-17-011 - Search filter correctness fix
- Impact Analysis: Removed pre-profile SQL filtering from users and moved groups/channels to display-field filtering so live search no longer drops valid display matches.
- Regression Verification: API lint and artisan test passed.
