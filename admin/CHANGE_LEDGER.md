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

## CHG-2026-07-18-001 - Latest location discovery fix
- Requirement: REQ-2026-07-18-001
- Impact Analysis: Backend-only API aggregation change. Existing user detail UI is preserved while location lookup now supports multiple database sources and broader location column names.
- Regression Verification: API PHP syntax lint passed.
- Status: Completed

## CHG-2026-07-18-002 - Location address/time refresh fix
- Requirement: REQ-2026-07-18-002
- Impact Analysis: User detail backend now detects direct address fields, composed address fields, and common login timestamp columns. Frontend refreshes only the location card manually or every five minutes without reloading the page.
- Regression Verification: API PHP syntax lint passed; JavaScript syntax check passed.
- Status: Completed

## CHG-2026-07-18-003 - User attendance detail panel
- Requirement: REQ-2026-07-18-003
- Impact Analysis: Adds read-only attendance aggregation to user_detail and renders it below Identity/Last Location. Existing password edit, memberships, location refresh, and group/channel views are preserved.
- Regression Verification: API PHP syntax lint passed; JavaScript syntax check passed.
- Status: Completed

## CHG-2026-07-18-004 - Attendance JSON error fix
- Requirement: REQ-2026-07-18-003
- Impact Analysis: Fixes undefined attendance array access when a user has current-month records but no today row, preventing Laravel HTML error pages from replacing JSON API responses. Silent location auto-refresh no longer disables the visible Refresh button.
- Regression Verification: API PHP syntax lint passed; JavaScript syntax check passed.
- Status: Completed

## CHG-2026-07-18-005 - User detail timeout JSON fix
- Requirement: REQ-2026-07-18-003
- Impact Analysis: Removed broad dynamic attendance and location schema scans from the user_detail hot path. Location now uses a bounded known-table list including login_tracking; attendance returns a stable not-mapped payload until exact HR schema is supplied.
- Regression Verification: API PHP syntax lint passed; direct CLI user_detail returned JSON; JavaScript syntax check previously passed.
- Status: Completed

## CHG-20260718-ADMIN-USER-LOCATION-ATTENDANCE
- Time: 2026-07-18 14:49:38
- Fixed user detail Last Location mapping to include date_created as Updated.
- Added address fallback for coordinate-only tracking rows using saved message address or reverse geocode fallback.
- Re-enabled Punch & Leave Status by scanning live employee punch/punch_log attendance tables.
- Deployed fixed legacy_standalone/api.php to live /var/www/html/admin/api.php.


## CHG-20260718-ADMIN-LOCATION-TIMELINE-PUNCH-HOURS
- Time: 2026-07-18 15:20 IST
- Requirement: Admin user detail Last Location must use latest live row, not old ascending login_tracking row; Today Login Hours must run from punch-in to current IST time; Last Location needs a Map action with today's timeline.
- Impact Analysis: Standalone admin-only change. Backend now prioritizes punch/punch_log/logout/login tracking for location, compares latest timestamps across sources, returns location_timeline, and calculates open punch duration using Asia/Kolkata time to match stored punch records. Frontend adds Map button and modal timeline without touching chat app runtime.
- Regression Verification: Local PHP lint passed; local JS syntax check passed; live /var/www/html/admin/api.php lint passed; live user_detail for emp 24 returned location_updated=2026-07-18 10:10:40, location_source=employee:punch, timeline_count=1, today_status=Punched in, login_label=05:09:54.
- Status: Completed

## CHG-20260718-ADMIN-USER-FILE-STORAGE-LIMIT
- Time: 2026-07-18 15:45 IST
- Requirement: Admin user detail must show file count/storage correctly and allow setting storage limit per user.
- Impact Analysis: Standalone admin-only change. Fixed repeated SQL parameter handling in user message/file stats, broadened attachment detection across file/attachment/media columns, stores per-user storage limits in admin-owned `flow_admin_user_storage_limits`, and adds a Files & Storage user-detail panel with MB limit input.
- Regression Verification: Local PHP lint passed; local JS syntax check passed; live /var/www/html/admin/api.php lint passed; live user_detail for emp 24 returned messages_sent=159, messages_received=89, files_total=68, files_sent=62, files_received=6, storage_label=7.81 MB, limit_label=Unlimited.
- Status: Completed

## CHG-20260718-ADMIN-STORAGE-DEVICE-EMPLOYEE-TYPE
- Time: 2026-07-18 16:20 IST
- Requirement: Storage limit update must return JSON without browser parse error; user detail must show active device details; employees must be classified into A/B/C1/C2 with default mapping emp_type=1 -> B and emp_type=0 -> C1 plus admin update provision.
- Impact Analysis: Standalone admin-only change. Added robust admin action JSON parsing, storage/type save without full page reload, active-device fallback from xmpp_user_presence, and admin-owned employee type override table. Existing employee.emp_type is not destructively changed.
- Regression Verification: Local PHP lint passed; local JS syntax check passed; live PHP lint passed; live storage limit POST returned JSON true; live employee type POST returned JSON true; test values restored to Unlimited/C1 after verification.
- Status: Completed

## CHG-20260718-ADMIN-CACHE-POST-MAP-TYPE-FIX
- Time: 2026-07-18 16:55 IST
- Requirement: Storage limit save must stop showing `Unexpected token '<'`; employee type controls must render in user detail; Last Location Map button must open the map/timeline modal.
- Impact Analysis: Standalone admin frontend fix plus live cache-busting. Updated app.js POST handling to parse text before JSON, keep storage/type saves on the user detail pane, wire the map button click handler, reset hidden modal submit state, and render Employee Type panel. Added asset query versions in live index.php so browsers load the latest app.js/app.css.
- Regression Verification: Local node --check passed; live PHP lint passed; live index.php now loads app.js/app.css with v=202607181650; live app.js contains response.text POST parsing, employeeTypePanel render, and data-location-map binding. Live update_user_storage_limit and update_employee_type both returned JSON status=true.
- Status: Completed

## CHG-20260718-ADMIN-AI-ACCESS
- Time: 2026-07-18 17:25 IST
- Requirement: User type A and B need AI API access controls, where Type A can use multiple AI APIs and Type B can use one AI API, with per-day token/search limits and admin-managed API keys.
- Impact Analysis: Standalone admin-only change. Added admin-owned AI provider, type rule, and user override tables; added AI Access side-nav module; added masked API key listing and save forms; added user detail AI Access summary. Chat runtime AI enforcement is not changed in this step.
- Regression Verification: Local PHP lint passed; local JS syntax check passed; live /var/www/html/admin/api.php lint passed; live index.php contains AI Access nav and cache-busted assets; live ai_access endpoint returned status=true with default A=multiple, B=single, C1/C2=none.
- Status: Completed

## CHG-20260720-ADMIN-AI-API
- Time: 2026-07-20 17:30 IST
- Requirement: Add AI API side-nav module and support multiple saved AI keys, AI name dropdown, title/API key/details, A/B type usage rules, and per-user key assignment.
- Impact Analysis: Admin-only change. Laravel module route list now exposes ai_access as AI API; admin JS wording/form updated; backend save_ai_user_access persists per-user selected providers and daily token/search overrides; user detail now includes available providers for assignment.
- Regression Verification: Local PHP lint passed for AdminController, routes, and legacy API; local JS syntax check passed; live flat admin api.php lint passed; live index.php shows AI API nav with cache-busted assets; live ai_access endpoint returned JSON status=true.
- Status: Completed

## CHG-20260720-ADMIN-AI-USERS-LIST
- Time: 2026-07-20 12:45 IST
- Requirement: Show AI using users below AI API key entry and type rules, including assigned API names and token/search allocation.
- Impact Analysis: Admin-only change. Added ai_access users payload derived from employee list plus AI type/user assignment rules. Added AI Users Access table under the AI API page and CSS to prevent rule panel overflow.
- Regression Verification: Local PHP lint passed; local JS syntax check passed; live /var/www/html/admin/api.php lint passed; live app.js contains AI Users Access render and cache-busted asset v=202607202.
- Status: Completed

## CHG-20260720-ADMIN-HIDE-AI-TYPE-RULES
- Time: 2026-07-20 12:55 IST
- Requirement: Remove User Type Access section from AI API admin page.
- Impact Analysis: Frontend-only admin change. Existing backend rule support remains for compatibility, but the AI API page no longer renders the type-rule card. Provider entry is full width and AI Users Access stays below it.
- Regression Verification: Local node --check passed; live app.js deployed; live index.php cache-busted to v=202607203; live grep confirms AI API Keys and AI Users Access are present while User Type Access is absent.
- Status: Completed

## CHG-20260720-ADMIN-GROUP-CHANNEL-MEMBER-DELETE
- Date: 2026-07-20
- Files: admin/legacy_standalone/api.php, admin/public/admin/app.js, admin/public/admin/app.css
- Impact Analysis: Adds admin-only member insertion and soft-delete/archive support for group/channel records. Existing role update/remove, group edit, and list rendering are preserved.
- Deployment: Uploaded to /var/www/html/admin/api.php, app.js, and app.css.

## CHG-20260720-ADMIN-WAKEUP-CHANNEL-TYPE-CONFIG
- Date: 2026-07-20
- Files: admin/legacy_standalone/api.php, admin/public/admin/app.js, admin/public/admin/app.css
- Impact Analysis: Extends existing update_group action to persist wake-up interval metadata and updates the admin detail UI. Existing member management/delete/group edit behavior is preserved.
- Deployment: Uploaded to /var/www/html/admin/api.php, app.js, and app.css.

## CHG-20260720-ADMIN-WAKEUP-AI-SCHEMA-FIX
- Date: 2026-07-20
- Files: admin/legacy_standalone/api.php, admin/public/admin/app.css, admin/public/admin/app.js
- Impact Analysis: Fixes cramped wake-up admin UI and hardens AI API/storage-style schema setup by creating missing tables/columns automatically. Existing admin auth, group/channel update, member management, and dashboard modules are preserved.
- Deployment: Uploaded to /var/www/html/admin/api.php, app.js, and app.css.

## CHG-20260720-ADMIN-AI-JSON-ENDPOINT-FIX
- Date: 2026-07-20
- Files: admin/routes/web.php, admin/resources/views/admin/dashboard.blade.php, admin/public/admin/app.js
- Impact Analysis: Routes Laravel admin API calls to the real /api endpoint and sends Accept: application/json on admin fetch calls. This prevents login/dashboard HTML from being parsed as JSON. Existing standalone admin modules are preserved.
- Deployment: Uploaded updated app.js to /var/www/html/admin/app.js.

## CHG-20260720-ADMIN-AI-LOAD-FIX
- Date: 2026-07-20
- Files: admin/public/admin/app.js, admin/legacy_standalone/app/Views/admin/dashboard.php
- Impact Analysis: Makes admin API URL resolution work for both Laravel local admin and flat standalone /admin deployment, and improves load error parsing so HTML/session errors do not hide the real failure.
- Deployment: Uploaded updated app.js to /var/www/html/admin/app.js.

## CHG-20260720-ADMIN-AI-ACCESS-TIMEOUT-FIX
- Date: 2026-07-20
- Files: admin/legacy_standalone/api.php, admin/public/admin/app.js
- Impact Analysis: Replaces the slow AI Users list build with a direct assigned-access query, removing repeated per-employee AI summary queries. Existing provider save, user detail AI assignment, and type-rule defaults are preserved.
- Deployment: Uploaded to /var/www/html/admin/api.php and /var/www/html/admin/app.js.

## CHG-20260720-ADMIN-AI-HY093-FIX
- Date: 2026-07-20
- Files: admin/legacy_standalone/api.php
- Impact Analysis: Changes AI provider insert placeholders from duplicated :admin_emp_id to distinct :created_by_emp_id and :updated_by_emp_id. Existing update path and provider listing remain unchanged.
- Deployment: Uploaded to /var/www/html/admin/api.php.

## CHG-20260720-ADMIN-AI-KEY-MASK-FIX
- Date: 2026-07-20
- Files: admin/legacy_standalone/api.php, admin/public/admin/app.css
- Impact Analysis: Removes mojibake mask literal from SQL and masks API keys in PHP using ASCII stars. Adds fixed AI key table sizing to prevent horizontal garbage layout. Raw API keys remain excluded from the JSON response.
- Deployment: Uploaded to /var/www/html/admin/api.php and /var/www/html/admin/app.css.

## CHG-20260720-EXT-USERS
- Files: admin/legacy_standalone/api.php, admin/public/admin/app.js, admin/public/admin/app.css, server_patch/chat/bootstrap.php, server_patch/chat/send_message.php
- Change: Added external contact schema, admin add/remove UI/API, welcome queueing, and send-message mention-only queueing for external users.


## CHG-20260720-EXTERNAL-REQUESTS
- Files: lib/chat_api.dart, lib/chat/chat_screen.dart, server_patch/chat/external_user_request.php, server_patch/chat/group_members.php, admin/legacy_standalone/api.php, admin/public/admin/app.js, admin/public/admin/app.css, admin/app/Http/Controllers/AdminController.php, admin/legacy_standalone/app/Views/admin/dashboard.php
- Change: Added external user approval workflow from chat UI to admin approval and mention dropdown exposure after approval.


## CHG-20260720-EXTERNAL-REQUEST-ROUTE-FIX
- Fixed admin user detail external member count regression caused by group-only metric in user file stats.
- Registered external_requests GET route and approve/reject POST cases in legacy admin API.

## CHG-20260721-EXTERNAL-EMAIL-SMTP
- Files: server_patch/chat/external_delivery_worker.php, server_patch/chat/external_mail_config.php, server_patch/chat/send_message.php, admin/legacy_standalone/api.php
- Change: Added native SMTP STARTTLS email delivery worker for external user delivery queue using Flow mailbox configuration. Mention/welcome email queue now spawns the worker in background.

## 2026-07-21 - External Welcome Email Immediate Send
- Files: admin/legacy_standalone/api.php, admin/legacy_standalone/external_mailer.php, admin/legacy_standalone/external_mail_config.php
- Change: Admin add/approve external member now attempts welcome email immediately through Flow SMTP and marks the delivery queue row sent on success. Failed SMTP attempts remain queued with last_error for retry/debugging.


## 2026-07-21 - User Storage Quota And App Usage View
- Files: server_patch/chat/bootstrap.php, server_patch/chat/upload_file.php, server_patch/chat/storage_usage.php, lib/chat_api.dart, lib/settings/settings_screens.dart
- Change: Added default 2GB per-user storage quota, upload-time quota enforcement, user-facing Data and Storage settings screen, and conversation-wise user/group/channel storage breakdown.

