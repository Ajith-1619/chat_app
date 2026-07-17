# Change Ledger

## CHG-2026-07-17-002 - Laravel conversion
- Requirement: REQ-2026-07-17-002
- Impact Analysis: Admin folder is now a Laravel 12 project. Existing backend helpers/API are preserved under legacy_standalone and invoked through Laravel routes.
- Regression Verification: route:list, syntax lint, and artisan test passed.
- Status: Completed
