# BUILD_REPORT_2026-07-18_admin_location_timeline_punch_hours

## Scope
Standalone Flow Master Admin user detail hotfix only. No Flutter/web/APK/Windows build was run.

## Completed
- Latest Location now prefers the newest row across punch, punch_log, logout_tracking, login_tracking, and known location tables.
- Updated date now shows the latest punch/location timestamp instead of old ascending login_tracking data.
- Today Login Hours now calculates from punch-in to current Asia/Kolkata time for open punches.
- Last Location panel has a Map button that opens an in-admin map modal with today's location timeline.
- Live admin files were deployed to `/var/www/html/admin`.

## Live Verification
- `php -l /var/www/html/admin/api.php`: passed.
- `user_detail` for emp 24 returned:
  - `location_updated=2026-07-18 10:10:40`
  - `location_source=employee:punch`
  - `timeline_count=1`
  - `today_status=Punched in`
  - `punch_in=2026-07-18 10:10:40`
  - `login_label=05:09:54`

## Notes
Sensitive credentials were not printed. Browser may need hard refresh for updated `app.js` and `app.css`.
