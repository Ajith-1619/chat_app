# BUILD_REPORT_2026-07-18_admin_cache_post_map_type_fix

## Scope
Standalone Flow Master Admin frontend hotfix only. No Flutter/web/APK/Windows build was run.

## Completed
- Fixed storage limit save JSON parsing path.
- Added cache-busting to live admin `index.php` for `app.js` and `app.css`.
- Added missing Last Location Map button click binding.
- Added Employee Type panel render in user detail.
- Kept storage/type saves inside the current user detail view without dashboard reload.

## Live Verification
- Live `api.php` lint: passed.
- Live `index.php` asset refs:
  - `app.css?v=202607181650`
  - `app.js?v=202607181650`
- Live `app.js` contains:
  - `response.text()` POST parser.
  - `employeeTypePanel(employeeType, user.emp_id)` render.
  - `[data-location-map]` click binding.
- Live POST actions:
  - `update_user_storage_limit`: JSON `status=true`.
  - `update_employee_type`: JSON `status=true`.
