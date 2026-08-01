# Build Report - 2026-08-01 - External Channel Lifecycle Route Fix

## Summary
Fixed the versioned external groups/channels API router so noun-prefixed lifecycle URLs such as `/api/channels/v1/channels/{id}/close` resolve correctly.

## Root Cause
`flow_api_segments()` returns path segments after `/v1/`, so the live route arrives as `channels/306/close`. The handler `flow_api_ext_groups_channels()` incorrectly expected the first segment to be numeric and skipped lifecycle handling, causing the request to fall through and effectively behave like a missing route on deployed servers.

## Files Changed
- `server_patch/api/_shared/extended.php`

## Implementation
- Normalized optional leading resource segment (`channels`, `channel`, `groups`, `group`) before numeric id parsing.
- This enables both URL styles:
  - `/api/channels/v1/channels/{id}/close`
  - `/api/channels/v1/{id}/close`
- Existing delete behavior remains soft-delete/archive.

## Verification
- `php -l server_patch/api/_shared/extended.php`

## Expected External APIs
- `POST /router_login/api/channels/v1/channels/{channel_id}/close`
- `DELETE /router_login/api/channels/v1/channels/{channel_id}`

## Notes
This repo patch must be deployed to the live server before Postman/LMS calls stop returning 404.
