# Build Report: Admin Session Bridge

Date: 2026-08-06

## Root Cause
The deployed JavaScript called a direct PHP bridge. That bridge included the legacy API in a separate PHP request, so it could not read Laravel's authenticated session and returned `Admin login required.`.

## Fix
`admin/public/admin-api.php` now creates a Laravel request for `/api`, preserving the original query, method, cookies, headers, form fields, files, and body. The existing Laravel session and authorization checks remain active.

## Verification
- PHP lint passed for the bridge and legacy API.
- Unauthenticated local bridge response is JSON HTTP 401, not HTML or HTTP 500.
- Live deployment still requires uploading the changed bridge file and signing in again.

## Deployment
Upload:
`admin/public/admin-api.php` -> `/var/www/html/admin/public/admin-api.php`

Then log out, log in again, and hard refresh. Do not delete the Laravel `storage/framework/sessions` or `.env` files.
