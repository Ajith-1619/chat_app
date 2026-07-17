# Feature Ledger

## FEAT-ADMIN-UI-001 - Admin web shell
- Requirement: REQ-2026-07-17-001
- Status: Implemented
- Files: index.php, app/Views/layouts/admin.php, app/Views/admin/dashboard.php, app/Views/auth/login.php, app.css
- Summary: Added structured web-app layout with sidenav, top header, footer, polished cards, tables, and responsive behavior.

## FEAT-ADMIN-MVC-001 - Lightweight MVC organization
- Requirement: REQ-2026-07-17-001
- Status: Implemented
- Files: app/Core/View.php, app/Controllers/AuthController.php, app/Controllers/DashboardController.php, index.php, logout.php
- Summary: Introduced controller and view layers while preserving existing API and bootstrap behavior.

## FEAT-ADMIN-EDIT-001 - Modal edit workflow
- Requirement: REQ-2026-07-17-001
- Status: Implemented
- Files: app.js, app/Views/admin/dashboard.php, app.css
- Summary: Replaced browser prompt/confirm editing with in-app modal forms and confirmation panels.
