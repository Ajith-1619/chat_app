# Build Report: Admin AI HY093 Fix

Date: 2026-07-20
Build ID: BUILD-20260720-ADMIN-AI-HY093-FIX

## Root Cause
- AI provider insert SQL used the same named placeholder twice for created_by_emp_id and updated_by_emp_id.
- With PDO native prepares this raises SQLSTATE HY093 invalid parameter number.

## Fix
- Replaced duplicate :admin_emp_id insert placeholders with :created_by_emp_id and :updated_by_emp_id.
- Updated execute params to match the new placeholders.

## Validation
- Local PHP lint passed.
- Live PHP lint passed for /var/www/html/admin/api.php.

## Deployment
- Uploaded patched api.php to /var/www/html/admin.
