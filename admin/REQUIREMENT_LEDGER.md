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

## REQ-2026-07-20-001 - Admin AI API key management and assignment
- Date: 2026-07-20
- Status: Implemented
- Summary: Admin side nav must show AI API, allow many AI API keys to be saved with title/name/key/details, configure A/B user type access and limits, and assign selected AI keys to users.

## REQ-2026-07-20-002 - AI API assigned users visibility
- Date: 2026-07-20
- Status: Implemented
- Summary: AI API admin page must show a list of users who have AI keys assigned, including the user, employee type, access mode, assigned AI API keys, daily token limit, daily search limit, status, and update time.

## REQ-2026-07-20-003 - Remove AI User Type Access section
- Date: 2026-07-20
- Status: Implemented
- Summary: Admin AI API page must not show the User Type Access card; it should show AI API key entry and AI Users Access list only.

## REQ-20260720-ADMIN-GROUP-CHANNEL-MEMBER-DELETE
- Date: 2026-07-20
- Summary: Admin dashboard must allow super admins to add users to groups/channels and delete groups/channels from active lists.
- Status: Implemented and live admin files deployed.

## REQ-20260720-ADMIN-WAKEUP-CHANNEL-TYPE-CONFIG
- Date: 2026-07-20
- Summary: Admin group/channel detail must show wake-up interval configuration, next wake-up date/time, and channel type as a dropdown instead of free text.
- Status: Implemented and deployed.

## REQ-20260720-ADMIN-WAKEUP-AI-SCHEMA-FIX
- Date: 2026-07-20
- Request: Fix admin wake-up configuration alignment, show next wake-up time, and make AI API key creation/storage style backend setup work without manual table creation.
- Status: Completed and deployed to live admin draft path.

## REQ-20260720-ADMIN-AI-JSON-ENDPOINT-FIX
- Date: 2026-07-20
- Request: AI API page must stop showing Unexpected token HTML/JSON parse errors in local Laravel admin and live admin.
- Status: Completed.

## REQ-20260720-ADMIN-AI-LOAD-FIX
- Date: 2026-07-20
- Request: AI API page must load instead of showing Unable to load admin data.
- Status: Completed.

## REQ-20260720-ADMIN-AI-ACCESS-TIMEOUT-FIX
- Date: 2026-07-20
- Request: AI API page must open and stop showing HTTP 500 / unable to load admin data.
- Status: Completed.

## REQ-20260720-ADMIN-AI-HY093-FIX
- Date: 2026-07-20
- Request: Fix AI API provider save error SQLSTATE HY093 invalid parameter number.
- Status: Completed.

## REQ-20260720-ADMIN-AI-KEY-MASK-FIX
- Date: 2026-07-20
- Request: Fix AI API key list showing corrupted/gibberish text and bad table alignment.
- Status: Completed.

## REQ-ADMIN-EXT-USERS-20260720
- Status: Implemented
- Requirement: Admin can add external email/WhatsApp/Telegram/SMS contacts to groups/channels, show them with External badge, and deliver only mentioned conversations through a queued outbound channel model.


## REQ-ADMIN-EXT-REQUEST-20260720
- Status: Implemented
- Requirement: Flow group/channel owner/admin can request adding an external user from chat UI; super admin approves/rejects in admin; approval adds external user to group/channel.

