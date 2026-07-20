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

## REG-20260720-ADMIN-AI-API
- Time: 2026-07-20 17:30 IST
- Passed: Yes
- Checks: Existing admin modules remain routed; AI API endpoint returns JSON; API keys remain masked on read; Type A/B/C1/C2 default rules remain intact.
- Remaining Risk: Chat runtime AI usage enforcement still needs to consume these admin rules when AI features are connected.

## REG-20260720-ADMIN-AI-USERS-LIST
- Time: 2026-07-20 12:45 IST
- Passed: Yes
- Checks: AI API page still renders provider form and type rules; assigned users list only includes users with assigned AI keys; API keys remain masked.
- Remaining Risk: Token usage consumed/remaining counters require runtime AI usage logging in a later integration.

## REG-20260720-ADMIN-HIDE-AI-TYPE-RULES
- Time: 2026-07-20 12:55 IST
- Passed: Yes
- Checks: AI API key form remains visible; AI Users Access list remains visible; removed section is no longer rendered.
- Remaining Risk: Backend type rules remain available but hidden from this screen.

## REG-20260720-ADMIN-GROUP-CHANNEL-MEMBER-DELETE
- Date: 2026-07-20
- Verified: Local PHP lint passed for admin legacy API; live /var/www/html/admin/api.php PHP lint passed; node --check passed for admin app.js; git diff --check passed.
- Watch: Add-member XMPP sync is best-effort; DB membership is saved and audited even if Ejabberd admin API is unavailable.

## REG-20260720-ADMIN-WAKEUP-CHANNEL-TYPE-CONFIG
- Date: 2026-07-20
- Verified: Local PHP lint passed, local JS syntax check passed, git diff --check passed, and live /var/www/html/admin/api.php PHP lint passed after upload.
- Watch: Next wake-up display is calculated from last activity and last wake-up sent time; actual worker scheduling still depends on server cron/notification worker.

## REG-20260720-ADMIN-WAKEUP-AI-SCHEMA-FIX
- Date: 2026-07-20
- Risk: Admin API schema migration could affect existing AI API records if columns were missing.
- Verification: Local PHP lint passed, live PHP lint passed after upload, and admin CSS selectors verified.
- Status: Passed.

## REG-20260720-ADMIN-AI-JSON-ENDPOINT-FIX
- Date: 2026-07-20
- Risk: Admin API fetch URL changes could affect module loading.
- Verification: admin/routes/web.php PHP lint passed; local /api?admin=1&action=ai_access with Accept header returns HTTP 401 instead of HTML when unauthenticated, confirming JSON auth path is used.
- Status: Passed with note: node --check was blocked by local sandbox ACL, and app.js change was limited to fetch headers.

## REG-20260720-ADMIN-AI-LOAD-FIX
- Date: 2026-07-20
- Risk: Incorrect API URL fallback could break flat live admin or local Laravel admin differently.
- Verification: app.js shows resolveApiUrl for Laravel /api?admin=1 and standalone api.php?admin=1; PHP lint passed for routes and legacy dashboard view.
- Status: Passed.

## REG-20260720-ADMIN-AI-ACCESS-TIMEOUT-FIX
- Date: 2026-07-20
- Risk: AI Users Access list now shows explicit assigned AI users only.
- Verification: Local CLI ai_access API returned JSON status=true in 5 seconds; local/live PHP lint passed for api.php.
- Status: Passed.

## REG-20260720-ADMIN-AI-HY093-FIX
- Date: 2026-07-20
- Risk: AI provider create could fail if placeholder names do not match execute params.
- Verification: Local PHP lint passed; scan found no repeated admin_emp_id placeholder pattern; live PHP lint passed after upload.
- Status: Passed.

## REG-20260720-ADMIN-AI-KEY-MASK-FIX
- Date: 2026-07-20
- Risk: API key masking could accidentally expose raw keys.
- Verification: Local ai_access JSON smoke test returned api_key_masked as ASCII stars and did not include api_key; live PHP lint passed.
- Status: Passed.

## REG-20260720-EXT-USERS
- Verified: PHP lint passed for admin API, chat bootstrap and send_message. JS syntax check passed for admin app.js.
- Risk: Actual email/WhatsApp/Telegram/SMS gateway worker is queued-only and must be connected separately before outbound delivery goes live.


## REG-20260720-EXTERNAL-REQUESTS
- Verified: PHP lint passed for new chat endpoint, group members endpoint, admin API and admin controller; admin app.js syntax check passed; targeted Dart analyze reported existing warnings only, no new compile errors.
- Risk: Outbound email/WhatsApp/Telegram/SMS delivery still requires gateway worker; current implementation queues approved welcome/mention deliveries.


## REG-20260720-EXTERNAL-REQUEST-ROUTE-FIX
- Verified: admin legacy API PHP lint passed and admin app.js syntax check passed.
