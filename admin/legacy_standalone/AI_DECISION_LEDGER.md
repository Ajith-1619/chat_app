# AI Decision Ledger

## DEC-2026-07-17-001 - Use lightweight MVC instead of installing Laravel
- Context: User requested Laravel-like MVC for an existing standalone PHP admin folder.
- Decision: Added controllers, views, and a View renderer without installing Laravel.
- Rationale: Preserves current deployment shape, avoids dependency and routing disruption, and still gives MVC separation for future growth.

## DEC-2026-07-17-002 - Preserve api.php procedural endpoint logic
- Context: The existing admin dashboard depends on api.php actions and database helper functions.
- Decision: Kept api.php behavior unchanged in this pass.
- Rationale: Reduces regression risk while improving UI/UX and page architecture.
