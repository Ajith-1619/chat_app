# Build Report - 2026-08-04 Archive Dynamic Group Columns

## Summary
Hardened archive scheduling so it no longer assumes specific `xmpp_groups` columns such as `name` or `updated_at`.

## Files Changed
- `server_patch/chat/archive_storage_helper.php`
- `REQUIREMENT_LEDGER.md`
- `FEATURE_LEDGER.md`
- `CHANGE_LEDGER.md`
- `BUILD_LEDGER.md`
- `REGRESSION_LEDGER.md`
- `AI_DECISION_LEDGER.md`

## Root Cause
Live archive execution hit multiple schema differences in `xmpp_groups`, first around `name`, then around `updated_at`.

## Fix
Added dynamic `xmpp_groups` column discovery and used it to build label/freshness expressions safely.

## Validation
- `php -l server_patch/chat/archive_storage_helper.php` passed.

## Deployment Note
Upload the patched helper file before rerunning the live archive worker.
