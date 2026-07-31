# Build Report - 2026-07-30 - Direct Message Body Diagnostics

## Summary
Added robust raw JSON/form/query parsing and safe diagnostics for the direct one-to-one external message endpoint.

## Files Changed
- server_patch/api/_shared/extended.php

## Verification
- `php -l server_patch/api/_shared/extended.php`: Passed

## Deployment Note
Upload `server_patch/api/_shared/extended.php` to `/var/www/html/router_login/api/_shared/extended.php`. If validation errors do not include a `debug` object after upload, the live server is still running the older file.
