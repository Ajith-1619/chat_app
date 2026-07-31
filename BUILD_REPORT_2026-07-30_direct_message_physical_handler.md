# Build Report - 2026-07-30 - Direct Message Physical Handler

## Summary
Replaced the direct message fallback route with a self-contained authenticated handler to eliminate Apache rewrite/PATH_INFO/shared-dispatch uncertainty.

## Files Changed
- server_patch/api/chat/v1/direct/messages/index.php

## Verification
- `php -l server_patch/api/chat/v1/direct/messages/index.php`: Passed

## Deployment Note
Upload this file exactly to `/var/www/html/router_login/api/chat/v1/direct/messages/index.php`. If validation still does not include `debug.handler = physical_direct_messages_v2`, the request is not reaching this file.
