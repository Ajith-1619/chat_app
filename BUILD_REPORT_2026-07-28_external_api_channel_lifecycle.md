# Build Report - External API Group/Channel Send And Channel Lifecycle

Date: 2026-07-28 18:05:00 +05:30

## Scope
- Added explicit API support/docs for group/channel message send.
- Added explicit channel lifecycle routes: close, archive, unarchive.
- Preserved existing direct message and soft-delete behavior.

## Files Changed
- server_patch/api/_shared/bootstrap.php
- server_patch/api/_shared/extended.php
- docs/external_api/FLOW_EXTERNAL_API_DOCUMENTATION.md
- docs/external_api/CHAT_V1.md
- docs/external_api/CHANNELS_V1.md
- docs/external_api/ENDPOINT_CATALOG.md
- docs/external_api/VERSIONED_API_ROUTES.md
- docs/external_api/README.md
- server_patch/api/FLOW_EXTERNAL_API_DOCUMENTATION.md
- server_patch/api/README.md

## Validation
- php -l server_patch/api/_shared/bootstrap.php: passed
- php -l server_patch/api/_shared/extended.php: passed

## Build
- Flutter build: not run; not requested for this API/docs change.
