# Build Report - 2026-07-29 - Direct Message Postman Body Fallback

## Summary
Fixed direct message API input parsing so Postman/form clients can pass `recipient_emp_id` reliably.

## Files Changed
- server_patch/api/_shared/extended.php

## Verification
- `php -l server_patch/api/_shared/extended.php`: Passed

## Deployment Note
Upload `server_patch/api/_shared/extended.php` to `/var/www/html/router_login/api/_shared/extended.php` again. If the server still returns `recipient_emp_id is required`, the live server is running the older file or the request is not reaching this endpoint.
