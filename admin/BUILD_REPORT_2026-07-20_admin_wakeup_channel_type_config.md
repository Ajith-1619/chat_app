# Build Report - Admin Wake-up Channel Type Config

Date: 2026-07-20
Type: Admin patch deploy

## Requirement
Show configurable wake-up interval, next wake-up message date/time, and channel type dropdown in admin group/channel detail.

## Changes
- Added wake-up interval options and labels in admin API.
- Added next wake-up calculation using last activity and last sent wake-up time.
- Added channel type dropdown options from `xmpp_channel_definitions` with fallback types.
- Extended group update action to save `wakeup_interval_minutes`, `wakeup_updated_by_emp_id`, and `wakeup_updated_at` when columns exist.
- Updated admin UI and CSS for the wake-up configuration panel.

## Validation
- Local PHP lint passed for `admin/legacy_standalone/api.php`.
- Live PHP lint passed for `/var/www/html/admin/api.php`.
- `node --check admin/public/admin/app.js` passed.
- `git diff --check` passed.

## Deployment
Uploaded to live admin folder:
- `/var/www/html/admin/api.php`
- `/var/www/html/admin/app.js`
- `/var/www/html/admin/app.css`

## Build Status
No Flutter web/APK/Windows build was generated.
