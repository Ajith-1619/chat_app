# Build Report - 2026-08-04 - Archive Legacy Queue Repair

## Summary
Added automatic repair for legacy manual archive jobs that were left queued with a future `scheduled_at` because of an earlier PHP-vs-DB time mismatch.

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
After deploying the updated helper, old manual queued archive jobs should be normalized and immediately eligible for worker processing.
