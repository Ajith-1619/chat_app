# Build Report - 2026-07-18 - User Location Address And Refresh

## Requirement
REQ-2026-07-18-002 - Show address and updated time in Last Location, refresh every five minutes, and allow manual refresh.

## Changes
- Expanded latest-location address detection to include login/location address fields and composed area/city/state/country style fields.
- Expanded updated-time detection to include login tracking timestamp fields such as login_time, login_at, logged_at, and last_login_at.
- Added a Last Location Refresh button in user detail views.
- Added five-minute auto-refresh for the selected user location card.

## Impact Analysis
Only the user detail location lookup and location card rendering changed. Password edit, memberships, systems, groups, and channels behavior is preserved.

## Regression Verification
- `C:\xampp\php\php.exe -l .\legacy_standalone\api.php` passed.
- `node --check .\public\admin\app.js` passed.

## Remaining Risk
If the production `employee:login_tracking` table has latitude/longitude only and no address-like or city/state/country columns, the admin cannot display an address until that data is stored or reverse geocoding is added.
