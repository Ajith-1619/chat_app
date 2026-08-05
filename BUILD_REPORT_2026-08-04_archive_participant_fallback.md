# Build Report - 2026-08-04 - Archive Participant Fallback

## Summary
Removed the hard dependency on `sender_emp_id` during archive manifest participant extraction and added a JID-based fallback for older live schemas.

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
Archive jobs should move past the `Unknown column 'sender_emp_id' in 'SELECT'` failure on live servers with older `xmpp_messages` schemas.
