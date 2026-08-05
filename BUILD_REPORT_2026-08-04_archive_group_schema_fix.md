# Build Report - 2026-08-04 Archive Group Schema Fix

## Summary
Fixed the archive storage scheduler to use the live `xmpp_groups.room_name` column instead of the non-existent legacy `name` column.

## Files Changed
- `server_patch/chat/archive_storage_helper.php`
- `REQUIREMENT_LEDGER.md`
- `FEATURE_LEDGER.md`
- `CHANGE_LEDGER.md`
- `BUILD_LEDGER.md`
- `REGRESSION_LEDGER.md`
- `AI_DECISION_LEDGER.md`

## Root Cause
Archive policy scheduling and label lookup still referenced `g.name`, but the deployed chat schema stores conversation names in `room_name`.

## Fix
Replaced archive helper label queries and scheduling queries to use `room_name` / `room_jid`.

## Validation
- `php -l server_patch/chat/archive_storage_helper.php` passed.

## Deployment Note
Upload the patched `server_patch/chat/archive_storage_helper.php` file to the live server before rerunning the archive worker.
