# BUILD REPORT - Admin AI Users Access List
Date: 2026-07-20
Scope: Admin PHP/JS/CSS only; no app build.

## Implemented
- AI API page now returns users who have assigned AI keys.
- Added AI Users Access table below AI API provider and User Type Access sections.
- Table shows user, type, access mode, assigned AI keys, daily token limit, daily search limit, status and updated time.
- Adjusted AI rule layout to reduce horizontal overflow.

## Validation
- Local PHP lint passed for admin/legacy_standalone/api.php.
- Local node --check passed for admin/public/admin/app.js.
- Live /var/www/html/admin/api.php PHP lint passed.
- Live app.js/app.css deployed and index cache-busted to v=202607202.

## Follow-up
- Runtime token usage/remaining counters need AI call logging once chat AI execution is wired.
