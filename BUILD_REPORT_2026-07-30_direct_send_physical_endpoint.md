# Build Report - 2026-07-30 - Direct Send Physical Endpoint

## Summary
Added `/api/chat/v1/direct_send.php` as a physical direct-message API endpoint to bypass rewrite/PATH_INFO/opcache ambiguity seen with `/direct/messages`.

## Files Changed
- server_patch/api/chat/v1/direct_send.php
- docs/external_api/CHAT_V1.md

## Verification
- `php -l server_patch/api/chat/v1/direct_send.php`: Passed

## Test URL
`POST https://dns.watchtower247.in/router_login/api/chat/v1/direct_send.php`

## Deployment Note
Upload `server_patch/api/chat/v1/direct_send.php` to `/var/www/html/router_login/api/chat/v1/direct_send.php`.
