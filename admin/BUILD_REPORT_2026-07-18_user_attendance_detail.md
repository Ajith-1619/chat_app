# Build Report - 2026-07-18 - User Punch And Leave Status

## Requirement
REQ-2026-07-18-003 - Show today punch status, login hours, current month punch days/login hours, and leave/week off dates below Identity and Last Location.

## Changes
- Added `attendance` payload to user_detail API.
- Added dynamic attendance table discovery for attendance, punch, biometric, login, leave, and week off tables across employee, task, and chat databases.
- Added Today Status, Punch In, Punch Out, Today Login Hours, This Month Punch Days, This Month Login Hours, Leave Dates, and Week Off Dates UI.
- Added live HH:MM:SS timer when punch in exists and punch out is missing.
- Expanded Last Location address/time candidate columns again for login tracking style schemas.

## Verification
- `C:\xampp\php\php.exe -l .\legacy_standalone\api.php` passed.
- `node --check .\public\admin\app.js` passed.

## Remaining Risk
If production stores address only as latitude/longitude, the app cannot show a readable address without reverse geocoding. If attendance/leave data uses unknown table or column names, exact schema mapping may still be needed.
