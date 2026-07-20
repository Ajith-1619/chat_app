# Build Report: Admin AI Access Timeout Fix

Date: 2026-07-20
Build ID: BUILD-20260720-ADMIN-AI-ACCESS-TIMEOUT-FIX

## Root Cause
- AI API page loaded AI Users by scanning the full employee list and repeatedly recalculating AI provider/rule summaries per employee.
- That made the ai_access endpoint slow enough to hit HTTP 500 / timeout.

## Fix
- AI Users list now reads only explicit assigned AI access rows from flow_admin_ai_user_access.
- Provider/rule data is loaded once and reused.
- Frontend load errors now preserve server status/details better.

## Validation
- Local ai_access API smoke test returned JSON status=true.
- Local PHP lint passed for admin/legacy_standalone/api.php.
- Live PHP lint passed for /var/www/html/admin/api.php.

## Deployment
- Uploaded patched api.php and app.js to /var/www/html/admin.
