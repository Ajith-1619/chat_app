# Build Report - 2026-08-06 Live Admin Apache Route Fix

- Verified live API paths `/admin/public/api` and `/admin/api` return Apache 404 HTML.
- Changed `admin/public/admin/app.js` to use the existing `?ajax=api&admin=1` entrypoint.
- Live probe of `/admin/public/?ajax=api&admin=1&action=overview` returned JSON rather than HTML.
- Upload `admin/public/admin/app.js` to `/var/www/html/admin/public/admin/app.js` and hard-refresh.
- The JSON server error still requires an authenticated admin session/backend validation; it is separate from the previous HTML/404 issue.
