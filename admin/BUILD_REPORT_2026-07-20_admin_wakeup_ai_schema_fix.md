# Build Report: Admin Wake-up + AI Schema Fix

Date: 2026-07-20
Build ID: BUILD-20260720-ADMIN-WAKEUP-AI-SCHEMA-FIX

## Scope
- Fixed wake-up configuration alignment in group/channel admin detail panels.
- Kept next wake-up message visible inside the wake-up configuration block.
- Hardened AI API provider backend setup so required admin AI tables and missing columns are created automatically.
- Deployed standalone admin files to /var/www/html/admin.

## Files Changed
- admin/legacy_standalone/api.php
- admin/public/admin/app.css
- admin/public/admin/app.js

## Validation
- Local PHP lint passed for admin/legacy_standalone/api.php.
- Live PHP lint passed for /var/www/html/admin/api.php.
- Wake-up CSS selector verification passed.

## Manual Follow-up
- Browser hard refresh may be needed to pick up app.css/app.js changes.
- AI API save should auto-create required tables on first save; no manual table creation is expected.
