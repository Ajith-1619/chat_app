# Build Report - 2026-08-04 - Archive Reaction Order Fix

## Summary
Made archive reaction extraction schema-safe by removing the hard dependency on an `id` column in `xmpp_message_reactions`.

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
Archive jobs should move past the `Unknown column 'id' in 'ORDER BY'` failure on live servers whose reactions table has no `id` column.
