# Build Ledger

## BUILD-2026-07-17-002 - Laravel admin conversion
- Status: Passed
- Framework: Laravel 12.64.0
- Verification: route:list passed; PHP lint passed; artisan test passed with 2 tests.

## BUILD-2026-07-17-003 - User detail View/Edit
- Status: Passed
- Verification: legacy API lint passed; node --check passed; artisan test passed with 2 tests.

## BUILD-2026-07-17-004 - Scrollable user detail modal
- Status: Passed
- Verification: JS syntax passed; Blade syntax passed; artisan test passed with 2 tests.

## BUILD-2026-07-17-005 - Group/channel detail UI
- Status: Passed
- Verification: legacy API lint passed; node --check passed; artisan test passed with 2 tests.

## BUILD-2026-07-17-006 - Group member list fix
- Status: Passed
- Verification: API lint passed; node --check passed; artisan test passed with 2 tests.

## BUILD-2026-07-17-007 - User memberships
- Status: Passed
- Verification: API lint passed; node --check passed; artisan test passed with 2 tests.

## BUILD-2026-07-17-008 - Separate admin pages
- Status: Passed
- Verification: route:list passed; PHP lint passed; node --check passed; artisan test passed with 2 tests.

## BUILD-2026-07-17-009 - Master-detail layout
- Status: Passed
- Verification: node --check passed; PHP lint passed; artisan test passed with 2 tests.

## BUILD-2026-07-17-010 - Live search fix
- Status: Passed
- Verification: node --check passed; API lint passed; artisan test passed with 2 tests.

## BUILD-2026-07-17-011 - Search filter correctness
- Status: Passed
- Verification: API lint passed; artisan test passed with 2 tests.

## BUILD-2026-07-18-001 - Latest user location lookup
- Status: Passed
- Verification: legacy_standalone/api.php PHP lint passed.

## BUILD-2026-07-18-002 - User location refresh controls
- Status: Passed
- Verification: legacy_standalone/api.php PHP lint passed; public/admin/app.js node syntax check passed.

## BUILD-2026-07-18-003 - User attendance detail panel
- Status: Passed
- Verification: legacy_standalone/api.php PHP lint passed; public/admin/app.js node syntax check passed.

## BUILD-2026-07-18-004 - Attendance JSON error fix
- Status: Passed
- Verification: legacy_standalone/api.php PHP lint passed; public/admin/app.js node syntax check passed.

## BUILD-2026-07-18-005 - User detail timeout fix
- Status: Passed
- Verification: legacy_standalone/api.php PHP lint passed; direct user_detail API CLI run returned JSON instead of timing out/HTML.

## BUILD-20260718-ADMIN-USER-DETAIL-FIELD-FIX
- Time: 2026-07-18 14:49:38
- Scope: Admin PHP API hotfix only; no Flutter/web/APK build.
- Validation: Local and live PHP lint passed. Live user detail subset verified with address, updated_at, punch source, today status, punch in/out fields.


## BUILD-20260718-ADMIN-LOCATION-TIMELINE-PUNCH-HOURS
- Time: 2026-07-18 15:20 IST
- Scope: Standalone admin PHP/JS/CSS hotfix; no Flutter web/APK/Windows build.
- Files Deployed: /var/www/html/admin/api.php, /var/www/html/admin/app.js, /var/www/html/admin/app.css.
- Validation: Local PHP lint passed; local node --check passed; live PHP lint passed; live user_detail JSON verification passed with current punch location and running login hours.
- Status: Passed

## BUILD-20260718-ADMIN-USER-FILE-STORAGE-LIMIT
- Time: 2026-07-18 15:45 IST
- Scope: Standalone admin PHP/JS/CSS hotfix; no Flutter web/APK/Windows build.
- Files Deployed: /var/www/html/admin/api.php, /var/www/html/admin/app.js, /var/www/html/admin/app.css.
- Validation: Local PHP lint passed; local node --check passed; live PHP lint passed; live user_detail JSON verification passed with corrected files/storage counts.
- Status: Passed

## BUILD-20260718-ADMIN-STORAGE-DEVICE-EMPLOYEE-TYPE
- Time: 2026-07-18 16:20 IST
- Scope: Standalone admin PHP/JS/CSS hotfix; no Flutter web/APK/Windows build.
- Files Deployed: /var/www/html/admin/api.php, /var/www/html/admin/app.js, /var/www/html/admin/app.css.
- Validation: Local PHP lint passed; local node --check passed; live PHP lint passed; live POST actions for storage limit and employee type returned valid JSON.
- Status: Passed

## BUILD-20260718-ADMIN-CACHE-POST-MAP-TYPE-FIX
- Time: 2026-07-18 16:55 IST
- Scope: Standalone admin JS/CSS/API and live index cache-bust; no Flutter build.
- Files Deployed: /var/www/html/admin/api.php, /var/www/html/admin/app.js, /var/www/html/admin/app.css. Live /var/www/html/admin/index.php asset refs cache-busted.
- Validation: node --check passed; php -l live API passed; live POST actions returned valid JSON.
- Status: Passed

## BUILD-20260718-ADMIN-AI-ACCESS
- Time: 2026-07-18 17:25 IST
- Scope: Standalone admin PHP/JS/CSS and live index nav/cache-bust; no Flutter web/APK/Windows build.
- Files Deployed: /var/www/html/admin/api.php, /var/www/html/admin/app.js, /var/www/html/admin/app.css. Live /var/www/html/admin/index.php updated with AI Access side nav.
- Validation: Local PHP lint passed; local node --check passed; live PHP lint passed; live ai_access API returned JSON status=true.
- Status: Passed

## BUILD-20260720-ADMIN-AI-API
- Time: 2026-07-20 17:30 IST
- Scope: Admin PHP/JS/CSS only; no Flutter web/APK/Windows build.
- Files Deployed: /var/www/html/admin/api.php, /var/www/html/admin/app.js, /var/www/html/admin/app.css. Live index.php label/cache-bust updated.
- Validation: PHP lint and live AI API endpoint smoke test passed.
- Status: Passed

## BUILD-20260720-ADMIN-AI-USERS-LIST
- Time: 2026-07-20 12:45 IST
- Scope: Admin PHP/JS/CSS only; no Flutter build.
- Files Deployed: /var/www/html/admin/api.php, /var/www/html/admin/app.js, /var/www/html/admin/app.css.
- Validation: PHP lint passed, JS syntax passed, live API lint passed, live assets cache-busted.
- Status: Passed

## BUILD-20260720-ADMIN-HIDE-AI-TYPE-RULES
- Time: 2026-07-20 12:55 IST
- Scope: Admin JS/CSS only; no Flutter build.
- Files Deployed: /var/www/html/admin/app.js, /var/www/html/admin/app.css.
- Validation: JS syntax passed and live cache-bust verified.
- Status: Passed

## BUILD-20260720-ADMIN-GROUP-CHANNEL-MEMBER-DELETE
- Date: 2026-07-20
- Type: Admin PHP/JS/CSS patch deploy, no Flutter build.
- Files deployed: /var/www/html/admin/api.php, /var/www/html/admin/app.js, /var/www/html/admin/app.css.
- Validation: PHP lint local/live and JS syntax check passed.

## BUILD-20260720-ADMIN-WAKEUP-CHANNEL-TYPE-CONFIG
- Date: 2026-07-20
- Type: Admin PHP/JS/CSS patch deploy, no Flutter build.
- Files deployed: /var/www/html/admin/api.php, /var/www/html/admin/app.js, /var/www/html/admin/app.css.
- Validation: PHP lint local/live, JS syntax check, and diff whitespace check passed.

## BUILD-20260720-ADMIN-WAKEUP-AI-SCHEMA-FIX
- Date: 2026-07-20
- Type: Admin PHP/CSS/JS patch deploy, no Flutter build.
- Files deployed: /var/www/html/admin/api.php, /var/www/html/admin/app.js, /var/www/html/admin/app.css.
- Validation: PHP lint local/live passed; wake-up CSS selectors verified.

## BUILD-20260720-ADMIN-AI-JSON-ENDPOINT-FIX
- Date: 2026-07-20
- Type: Admin Laravel route/view plus JS patch, no Flutter build.
- Files deployed: /var/www/html/admin/app.js.
- Validation: PHP lint passed for routes/web.php; local API smoke test no longer returns HTML for JSON requests.

## BUILD-20260720-ADMIN-AI-LOAD-FIX
- Date: 2026-07-20
- Type: Admin JS/view patch, no Flutter build.
- Files deployed: /var/www/html/admin/app.js.
- Validation: PHP lint passed for route/view; live upload completed.

## BUILD-20260720-ADMIN-AI-ACCESS-TIMEOUT-FIX
- Date: 2026-07-20
- Type: Admin PHP/JS patch deploy, no Flutter build.
- Files deployed: /var/www/html/admin/api.php, /var/www/html/admin/app.js.
- Validation: Local CLI ai_access smoke test returned JSON; live PHP lint passed.

## BUILD-20260720-ADMIN-AI-HY093-FIX
- Date: 2026-07-20
- Type: Admin PHP patch deploy, no Flutter build.
- Files deployed: /var/www/html/admin/api.php.
- Validation: Local/live PHP lint passed.

## BUILD-20260720-ADMIN-AI-KEY-MASK-FIX
- Date: 2026-07-20
- Type: Admin PHP/CSS patch deploy, no Flutter build.
- Files deployed: /var/www/html/admin/api.php, /var/www/html/admin/app.css.
- Validation: Local smoke test and live PHP lint passed.

## BUILD-20260720-EXT-USERS
- Build: Not run, not requested for this implementation step.
- Validation: php -l admin/legacy_standalone/api.php; php -l server_patch/chat/bootstrap.php; php -l server_patch/chat/send_message.php; node --check admin/public/admin/app.js.


## BUILD-20260720-EXTERNAL-REQUESTS
- Build: Not run; implementation-only request.
- Validation: php -l server_patch/chat/external_user_request.php, group_members.php, admin API/controller; node --check admin/public/admin/app.js; targeted dart analyze changed Dart files.

