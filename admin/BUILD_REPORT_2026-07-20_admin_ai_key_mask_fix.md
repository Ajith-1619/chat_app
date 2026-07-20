# Build Report: Admin AI Key Mask Fix

Date: 2026-07-20
Build ID: BUILD-20260720-ADMIN-AI-KEY-MASK-FIX

## Root Cause
- AI provider list generated the masked key in SQL using a corrupted bullet/mojibake literal.

## Fix
- API now selects api_key internally, masks it in PHP with admin_mask_secret(), and removes raw api_key before JSON output.
- AI key table column sizing now uses fixed widths and ellipsis for the key column.

## Validation
- Local ai_access smoke test returned api_key_masked=8344****3580 and no raw api_key.
- Live PHP lint passed for /var/www/html/admin/api.php.

## Deployment
- Uploaded patched api.php and app.css to /var/www/html/admin.
