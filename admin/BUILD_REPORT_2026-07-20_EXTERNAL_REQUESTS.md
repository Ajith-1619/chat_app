# Build Report - External User Approval Flow - 2026-07-20

Status: Implemented. Build not run.

Changes:
- Added chat API endpoint for external user requests.
- Added group/channel profile button and form: Add external user.
- Added admin External Requests module with approve/reject.
- Approval converts request into active external group/channel member.
- Approved external users are returned in group member/mention data as role=external.

Validation:
- PHP lint passed for changed PHP files.
- admin/public/admin/app.js syntax check passed.
- Targeted Dart analyze completed with existing warnings only.

Deployment:
- Not deployed in this turn.
