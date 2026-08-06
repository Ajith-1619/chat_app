# Build Report - 2026-08-06 Admin Route Fix

## Change
Fixed admin AJAX endpoint resolution for deployments served from `/admin/` or `/admin/public/` by using a relative `api?admin=1` URL in the dashboard shell.

## Verification
- Local Laravel admin server started successfully.
- `http://127.0.0.1:8000/` returned HTTP 200.
- Flutter build not required; this is an admin PHP/Blade route fix.

## Deployment Note
Upload `admin/resources/views/admin/dashboard.blade.php` to the deployed admin application and clear Laravel compiled views/cache if the old API URL remains.
