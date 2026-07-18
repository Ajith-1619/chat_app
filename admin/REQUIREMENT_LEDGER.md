# Requirement Ledger

## REQ-2026-07-17-002 - Convert admin console to real Laravel project
- Date: 2026-07-17
- Status: Implemented
- Summary: Replaced lightweight MVC with a real Laravel 12 project and preserved standalone files in legacy_standalone.

## REQ-2026-07-17-003 - Full user View/Edit information
- Status: Implemented
- Summary: Users View/Edit now opens a full detail view with profile, message counts, file counts, storage, last location, latitude/longitude, presence, and active systems where data exists.

## REQ-2026-07-17-004 - Group/channel simplified list and full View/Edit details
- Status: Implemented
- Summary: Groups/channels list now shows basic fields only; View/Edit opens full details with members, owners/admins, message/file/image/storage stats, and member role controls.

## REQ-2026-07-17-005 - User involved groups and channels
- Status: Implemented
- Summary: User View/Edit now shows involved groups/channels count and clickable list that opens each group/channel detail modal.

## REQ-2026-07-17-006 - Split admin modules into separate pages
- Status: Implemented
- Summary: Admin modules now have separate Laravel routes/pages instead of navigating only as one SPA page.

## REQ-2026-07-17-007 - Master-detail Users/Groups/Channels pages
- Status: Implemented
- Summary: Users, Groups, and Channels now use a two-column page layout with left list and right inline view/edit pane instead of modal-first detail viewing.

## REQ-2026-07-18-001 - Show latest user location in detail pane
- Date: 2026-07-18
- Status: Implemented
- Summary: User detail must show the latest available address, latitude, longitude, updated time, and source instead of blanks when location data exists in any configured admin database.

## REQ-2026-07-18-002 - User location address, timestamp, and refresh
- Date: 2026-07-18
- Status: Implemented
- Summary: User detail Last Location must include address and updated time where available, refresh automatically every five minutes, and provide a manual Refresh button.

## REQ-2026-07-18-003 - User punch and leave status in detail pane
- Date: 2026-07-18
- Status: Implemented
- Summary: User detail must show today punch in/out status, running login duration when punch out is missing, current month punch days/login hours, and current month leave/week off date details below Identity and Last Location.

## REQ-2026-07-18-004 - AI API access by employee type
- Date: 2026-07-18
- Status: Implemented
- Summary: Admin must configure AI API providers/API keys and assign access rules by employee type, where Type A can have multiple AI APIs, Type B can have one AI API, and limits can be set per day by tokens and searches.
