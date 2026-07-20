# Feature Ledger

## FEAT-LARAVEL-ADMIN-001 - Real Laravel admin console
- Requirement: REQ-2026-07-17-002
- Status: Implemented
- Summary: Laravel routes, controller, Blade views, public assets, and legacy API bridge are in place.

## FEAT-ADMIN-USER-DETAIL-001 - User full information modal
- Requirement: REQ-2026-07-17-003
- Status: Implemented
- Summary: Added user_detail API aggregation and rich View/Edit modal.

## FEAT-ADMIN-GROUP-DETAIL-001 - Group/channel full detail modal
- Requirement: REQ-2026-07-17-004
- Status: Implemented
- Summary: Added group_detail API and frontend role management controls.

## FEAT-ADMIN-USER-MEMBERSHIPS-001 - User group/channel memberships
- Requirement: REQ-2026-07-17-005
- Status: Implemented
- Summary: Added membership aggregation to user_detail and clickable membership rows in the user modal.

## FEAT-ADMIN-PAGES-001 - Separate module pages
- Requirement: REQ-2026-07-17-006
- Status: Implemented
- Summary: Added module route rendering, link-based sidenav, active page state, and JS initialization from page context.

## FEAT-ADMIN-MASTER-DETAIL-001 - Inline master-detail view/edit
- Requirement: REQ-2026-07-17-007
- Status: Implemented
- Summary: Added left-side basic list and right-side inline detail/edit panels for users, groups, and channels.

## FEAT-ADMIN-USER-LOCATION-001 - Robust latest user location lookup
- Requirement: REQ-2026-07-18-001
- Status: Implemented
- Summary: User detail API now scans known and discovered location/GPS/geo/track tables across chat, employee, and task databases using flexible column matching.

## FEAT-ADMIN-USER-LOCATION-002 - Location card refresh controls
- Requirement: REQ-2026-07-18-002
- Status: Implemented
- Summary: Added Last Location card refresh action and five-minute auto-refresh for selected user details, plus broader address/timestamp detection for login tracking style tables.

## FEAT-ADMIN-USER-ATTENDANCE-001 - User punch and leave summary
- Requirement: REQ-2026-07-18-003
- Status: Implemented
- Summary: Added dynamic attendance lookup across employee/task/chat databases and a Punch & Leave Status panel with live HH:MM:SS timer for open punch sessions.

## FEAT-2026-07-18-ADMIN-AI-ACCESS
- Requirement: REQ-2026-07-18-004
- Status: Implemented
- Summary: Added standalone admin AI Access module with provider/API key storage, A/B/C1/C2 type rules, daily token/search limits, and user-detail AI access summary.

## FEAT-ADMIN-GROUP-CHANNEL-MEMBER-DELETE
- Date: 2026-07-20
- Summary: Group/channel detail view now has employee search/add-member controls, role selection, show old messages toggle, audited delete action, and existing role/remove controls preserved.
- Status: Implemented.

## FEAT-ADMIN-WAKEUP-CHANNEL-TYPE-CONFIG
- Date: 2026-07-20
- Summary: Group/channel detail now supports wake-up enabled, wake-up interval choices, calculated next wake-up display, and channel definition dropdown types.
- Status: Implemented.

## FEAT-20260720-ADMIN-WAKEUP-AI-SCHEMA-FIX
- Date: 2026-07-20
- Feature: Admin group/channel wake-up configuration and AI API provider management reliability.
- Status: Completed.
- Notes: Wake-up controls are stacked responsively; AI provider/access tables auto-create and auto-migrate missing columns.

## FEAT-ADMIN-EXT-USERS
- Status: Implemented
- Adds External users panel in group/channel detail with delivery channel selection, remove action, mention token, welcome message, and mention-only delivery queue support.


## FEAT-EXTERNAL-USER-APPROVAL-FLOW
- Status: Implemented
- Chat app adds an Add external user request form for groups/channels. Admin adds External Requests module with approve/reject controls. Approved users appear in mention suggestions as External mention-only contacts.

