# Regression Ledger

## REG-2026-07-17-002 - Laravel conversion regression
- Passed: Yes
- Checks: Laravel routes registered, PHP syntax clean, default test suite passed.
- Remaining Risk: Authenticated DB/API smoke test requires real admin credentials and database connectivity.

## REG-2026-07-17-003 - User detail regression
- Passed: Yes
- Checks: API syntax, frontend syntax, Laravel tests.
- Remaining Risk: Exact location/device fields depend on production DB table names; endpoint auto-detects common table/column names.

## REG-2026-07-17-004 - User detail modal UI
- Passed: Yes
- Checks: JavaScript syntax, Blade syntax, Laravel tests.

## REG-2026-07-17-005 - Group/channel detail regression
- Passed: Yes
- Checks: API syntax, frontend syntax, Laravel tests.
- Remaining Risk: Message/file/image counts depend on room_jid being stored in xmpp_messages from_jid/to_jid.

## REG-2026-07-17-006 - Group member list fix
- Passed: Yes
- Checks: API syntax, frontend syntax, Laravel tests.

## REG-2026-07-17-007 - User memberships regression
- Passed: Yes
- Checks: API syntax, frontend syntax, Laravel tests.

## REG-2026-07-17-008 - Separate page navigation
- Passed: Yes
- Checks: Routes registered, syntax checks passed, Laravel tests passed.

## REG-2026-07-17-009 - Master-detail layout regression
- Passed: Yes
- Checks: Frontend syntax, API/Blade syntax, Laravel tests.

## REG-2026-07-17-010 - Live search regression
- Passed: Yes
- Checks: Frontend syntax, API syntax, Laravel tests.

## REG-2026-07-17-011 - Search filter correctness
- Passed: Yes
- Checks: API syntax and Laravel tests.
