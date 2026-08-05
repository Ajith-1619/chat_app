# Build Report - 2026-08-04 - Archive Queue Timebase Fix

## Summary
Adjusted manual archive queue scheduling to use the database clock when no explicit `scheduled_at` value is supplied.

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
New manual archive jobs should be picked immediately by the worker instead of staying queued due to timezone mismatch between PHP and MySQL clocks.
