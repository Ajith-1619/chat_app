# Build Report - 2026-08-04 - Archive Group Member Fallback

## Summary
Added schema-safe lookup for group members during archive participant extraction, supporting both `room_jid` and `group_id` membership linkage.

## Files Changed
- `server_patch/chat/archive_storage_helper.php`
- `REQUIREMENT_LEDGER.md`
- `FEATURE_LEDGER.md`
- `CHANGE_LEDGER.md`
- `BUILD_LEDGER.md`
- `REGRESSION_LEDGER.md`
- `AI_DECISION_LEDGER.md`

## Validation
- `php -l server_patch/chat/archive_storage_helper.php`

## Expected Outcome
Archive jobs should move past the `Unknown column 'room_jid' in 'WHERE'` failure on live servers whose membership table links rows by `group_id`.
