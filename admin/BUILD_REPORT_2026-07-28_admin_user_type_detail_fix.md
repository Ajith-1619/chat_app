# BUILD_REPORT_2026-07-28_admin_user_type_detail_fix

- Timestamp: 2026-07-28 12:20:00 +05:30
- Scope: Admin Users page employee type edit and user detail load reliability.
- Changed files:
  - admin/public/admin/app.js
  - admin/legacy_standalone/api.php
  - admin/legacy_standalone/_bootstrap.php
- Result: Employee type Save Type button is wired in inline and modal details. User detail JSON is safer for invalid UTF-8 profile data. Optional AI access failures no longer block the main user detail panel.
- Verification: PHP lint passed; JS syntax check passed.
- Build: Not run.
