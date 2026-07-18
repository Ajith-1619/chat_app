# Build Report - 2026-07-18 - User Detail Timeout JSON Fix

## Fix
Resolved the Users detail pane `Unexpected token '<'` error by removing timeout-prone broad schema scans from the user_detail API path.

## Changes
- Restricted latest-location table discovery to a bounded list that includes `login_tracking`.
- Disabled broad attendance auto-discovery and returned a stable not-mapped attendance payload until the exact HR schema is available.

## Verification
- `C:\xampp\php\php.exe -l .\legacy_standalone\api.php` passed.
- Direct local `user_detail` API execution returned JSON successfully.
