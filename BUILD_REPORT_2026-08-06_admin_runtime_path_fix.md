# Build Report - 2026-08-06 Admin API Runtime Path Fix

- Changed `admin/public/admin/app.js` to derive the API endpoint from the current admin URL.
- This supports both `/admin/` and `/admin/public/` and avoids stale absolute route values.
- Local Laravel root responds with HTTP 200.
- Unauthenticated local API responds with HTTP 401 JSON, which is expected.
- Live deployment requires uploading the Blade view and `public/admin/app.js`, clearing Laravel views, then hard-refreshing.
