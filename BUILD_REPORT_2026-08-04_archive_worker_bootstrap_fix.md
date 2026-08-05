# Build Report - 2026-08-04 Archive Worker Bootstrap Fix

## Summary
Fixed the archive storage worker boot path so it no longer requires a missing `server_patch/chat/_bootstrap.php`.

## Files Changed
- `server_patch/chat/archive_storage_worker.php`
- `REQUIREMENT_LEDGER.md`
- `FEATURE_LEDGER.md`
- `CHANGE_LEDGER.md`
- `BUILD_LEDGER.md`
- `REGRESSION_LEDGER.md`
- `AI_DECISION_LEDGER.md`

## Root Cause
The worker referenced a bootstrap file that does not exist in the chat patch folder. This caused local CLI execution to fail immediately and the live `/chat/archive_storage_worker.php` URL to return HTTP 500.

## Fix
The worker now loads `server_patch/chat/bootstrap.php` for normal live execution and falls back to `admin/legacy_standalone/_bootstrap.php` for exported/local contexts.

## Validation
- `php -l server_patch/chat/archive_storage_worker.php` passed.

## Deployment Note
This fix must be uploaded to the live server before re-running the worker URL or CLI command there.
