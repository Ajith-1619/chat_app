# Build Report - 2026-07-29 - Direct User Send API

## Summary
Added a versioned external API endpoint for one-to-one Flow user messages by employee ID.

## Files Changed
- server_patch/api/_shared/extended.php
- docs/external_api/CHAT_V1.md
- docs/external_api/FLOW_EXTERNAL_API_DOCUMENTATION.md
- server_patch/api/FLOW_EXTERNAL_API_DOCUMENTATION.md

## Endpoint
- POST `/api/chat/v1/direct/messages`
- GET `/api/chat/v1/direct/messages?recipient_emp_id={emp_id}&sender_emp_id={emp_id}&limit=50`

## Verification
- `php -l server_patch/api/_shared/extended.php`: Passed
- `php -l server_patch/api/chat/v1/index.php`: Passed

## Build
App build not run; backend/API patch only.
