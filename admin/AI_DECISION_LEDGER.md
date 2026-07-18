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
