# Build Report - 2026-07-29 - Direct Message API 404 Fallback

## Summary
Added a physical fallback route for the one-to-one direct message API so `/api/chat/v1/direct/messages` can work even when Apache rewrite rules are not active.

## Files Changed
- server_patch/api/chat/v1/direct/messages/index.php
- docs/external_api/CHAT_V1.md

## Verification
- `php -l server_patch/api/chat/v1/direct/messages/index.php`: Passed

## Deployment Note
Upload both:
- `server_patch/api/_shared/extended.php` -> `/var/www/html/router_login/api/_shared/extended.php`
- `server_patch/api/chat/v1/direct/messages/index.php` -> `/var/www/html/router_login/api/chat/v1/direct/messages/index.php`
