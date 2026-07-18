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

## REG-2026-07-18-001 - User detail latest location
- Passed: Yes
- Checks: API syntax lint passed.
- Remaining Risk: Production will still show blanks if no table has employee id plus latitude/longitude columns for that user.

## REG-2026-07-18-002 - User location card refresh
- Passed: Yes
- Checks: API syntax lint and frontend syntax check.
- Remaining Risk: Address remains blank if the production source table stores only latitude/longitude and has no address/city/state/country fields.

## REG-2026-07-18-003 - User attendance detail regression
- Passed: Yes
- Checks: API syntax lint and frontend syntax check.
- Remaining Risk: Attendance values depend on production attendance/punch tables having recognizable employee id, date, punch in, punch out, status, or duration columns.

## REG-2026-07-18-004 - User detail JSON response stability
- Passed: Yes
- Checks: API syntax lint and frontend syntax check.
- Remaining Risk: A production-only schema mismatch can still surface an API error, but missing today attendance rows are now handled safely.

## REG-2026-07-18-005 - User detail JSON timeout regression
- Passed: Yes
- Checks: PHP syntax lint and direct user_detail API JSON verification.
- Remaining Risk: Attendance values require exact production HR table/column mapping before real punch/leave data can be shown.

## REG-20260718-ADMIN-LOCATION-PUNCH
- Time: 2026-07-18 14:49:38
- Checked: Existing user detail JSON remains status=true; sensitive fields were not printed during verification.
- Risk: Reverse geocode fallback depends on server internet availability; DB saved address is preferred when present.


## REG-20260718-ADMIN-LOCATION-TIMELINE-PUNCH-HOURS
- Time: 2026-07-18 15:20 IST
- Passed: Yes
- Checks: Location no longer selects old 2024 login_tracking when a newer 2026 punch row exists; punch status remains Punched in; login hours are non-zero and running; map/timeline frontend assets were deployed.
- Remaining Risk: Map embeds depend on OpenStreetMap availability in the browser; timeline only shows rows present in today's mapped tracking tables.

## REG-20260718-ADMIN-USER-FILE-STORAGE-LIMIT
- Time: 2026-07-18 15:45 IST
- Passed: Yes
- Checks: User detail no longer returns zero for repeated-param message/file queries; sent/received message counts remain correct; files and uploaded storage are populated; storage limit defaults to Unlimited when unset.
- Remaining Risk: Storage limit is now configurable in admin; upload enforcement in chat send/upload APIs must read this table in a separate app/backend enforcement change if strict blocking is required.

## REG-20260718-ADMIN-STORAGE-DEVICE-EMPLOYEE-TYPE
- Time: 2026-07-18 16:20 IST
- Passed: Yes
- Checks: Storage limit update no longer depends on a full dashboard reload; active device section falls back to presence when no device table exists; employee type defaults preserve existing emp_type mapping and admin overrides are audited.
- Remaining Risk: Active device detail richness depends on production device/session tables; when only xmpp_user_presence exists, device detail is limited to presence timestamps.

## REG-20260718-ADMIN-CACHE-POST-MAP-TYPE-FIX
- Time: 2026-07-18 16:55 IST
- Passed: Yes
- Checks: Browser is forced to latest app.js through asset version; storage/type saves no longer call the old JSON parser; map click handler is bound on user detail render.
- Remaining Risk: User browsers with a fully stale page must refresh once to load the new asset URL from index.php.

## REG-20260718-ADMIN-AI-ACCESS
- Time: 2026-07-18 17:25 IST
- Passed: Yes
- Checks: AI Access module loads through admin side nav; API keys are masked on read; A/B/C1/C2 defaults are returned; existing admin API PHP syntax remains valid.
- Remaining Risk: Actual AI usage enforcement must be wired into future AI chat/API execution paths to consume these admin rules and decrement token/search limits.
