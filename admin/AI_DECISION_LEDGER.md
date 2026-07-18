# AI Decision Ledger

## DEC-2026-07-17-003 - Full Laravel conversion
- Decision: Scaffolded a real Laravel 12 app after the user requested actual Laravel.
- Rationale: Meets the framework requirement while preserving old standalone code for fallback.

## DEC-2026-07-17-004 - Auto-detect user location and system tables
- Decision: Used table/column discovery for location and active systems instead of hardcoding one schema.
- Rationale: Existing codebase already supports varied employee table names, and production device/location schema was not explicit in the repo.

## DEC-2026-07-17-005 - Keep room JID inside detail view only
- Decision: Removed room_jid from list response and exposed it only in View/Edit technical details.
- Rationale: Keeps list scan-friendly while preserving operational detail in the modal.

## DEC-2026-07-17-006 - Use Laravel module routes while preserving API widgets
- Decision: Split navigation into real Laravel pages and kept existing API-rendered module tables/modals.
- Rationale: Gives maintainable URLs/page ownership without risking current admin data behavior.

## DEC-2026-07-17-007 - Inline details over modal for primary modules
- Decision: Users, Groups, and Channels now use inline master-detail panes while keeping modals available for fallback/non-primary actions.
- Rationale: Improves readability, editing, and code ownership for high-use admin workflows.

## DEC-2026-07-18-001 - Multi-database dynamic location lookup
- Decision: Expanded latest-location lookup to discover location-like tables and scan chat, employee, and task databases before returning blank.
- Rationale: Production schema for live location was not explicit locally, and the UI already supports the required fields once the API returns them.

## DEC-2026-07-18-002 - Refresh location card instead of full user pane
- Decision: Implemented manual and five-minute refresh at the Last Location card level using the existing user_detail API.
- Rationale: Keeps the user detail form stable while still updating live location data frequently enough for admin monitoring.

## DEC-2026-07-18-003 - Dynamic attendance schema detection
- Decision: Used table and column discovery for attendance, punch, biometric, login, leave, and week off data instead of binding to one table name.
- Rationale: The production HR/attendance schema is not represented locally, so flexible discovery is the safest way to surface available data without breaking existing admin views.

## DEC-2026-07-18-004 - Safe attendance row access
- Decision: Replaced direct punch_in array access with null-safe fallbacks and kept silent auto-refresh from mutating button state.
- Rationale: Prevents PHP notices/warnings from being converted to HTML error responses consumed by the JavaScript JSON parser.

## DEC-2026-07-18-005 - Bound user detail data discovery
- Decision: Removed broad runtime schema scans from user_detail and kept only bounded location tables plus a stable attendance placeholder.
- Rationale: User detail must return quickly and always return JSON; exact attendance schema mapping can be added without risking page crashes.

## DEC-20260718-ADMIN-AI-ACCESS
- Time: 2026-07-18 17:25 IST
- Decision: Store AI provider/API configuration and employee-type access rules in admin-owned tables instead of changing employee master schema directly.
- Reason: Keeps the admin feature standalone, avoids destructive employee table changes, supports Type A multiple-provider access and Type B single-provider access, and allows future per-user overrides.
- Security Note: API keys are accepted by admin forms and masked in API responses; production secret rotation/encryption can be added as a follow-up hardening step.
