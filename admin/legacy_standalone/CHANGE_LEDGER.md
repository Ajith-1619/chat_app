# Change Ledger

## CHG-2026-07-17-001 - MVC web shell refactor
- Requirement: REQ-2026-07-17-001
- Feature IDs: FEAT-ADMIN-UI-001, FEAT-ADMIN-MVC-001, FEAT-ADMIN-EDIT-001
- Impact Analysis: Login and dashboard rendering moved to controllers/views. Existing _bootstrap.php helpers, api.php data endpoints, session handling, CSRF, and DB queries remain unchanged.
- Regression Risks: Login routing, logout routing, CSRF meta output, modal post payloads, responsive dashboard layout.
- Implementation Plan: Add lightweight MVC directories, render login/dashboard through views, refresh CSS for app shell, replace prompt/confirm flows with modal forms, run PHP lint.
- Status: Completed
