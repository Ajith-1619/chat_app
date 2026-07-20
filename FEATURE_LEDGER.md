
## FEATURE-RELEASE-MANAGEMENT-DRAFT-ANDROID-2.0.4
- Date: 2026-07-15
- Area: Release Management
- Platform: Android, Web artifact generated locally
- Status: Draft registered for Android; web package generated locally


## FEAT-ATTACHMENT-RESTRICTED-VIEW
- Date: 2026-07-16 11:42:08
- Restricted attachment flag added to chat attachment model, send flow, history response, backend persistence, preview UI, and media download guard.
- Unrestricted attachments expose Download and Open with actions.
- Status: Implemented.


## FEAT-SAVED-MESSAGES-FORWARD-PASTE
- Date: 2026-07-16 11:56:28
- Added Saved Messages as a first-class forward target.
- Saved forward uses saved message storage instead of normal chat send.
- Saved Messages supports clipboard media paste through existing web bridge, explicit text paste shortcut, multi-file attach, and desktop drag/drop save.
- Fixed duplicate saved checklist/poll creation.


## FEATURE-20260716-FLOW-MASTER-ADMIN
- Date: 2026-07-16 15:34:05 +05:30
- Feature: Standalone Flow Master Admin web app under admin/.
- Capabilities: Super-admin login, overview metrics, users, groups/channels, messages, files, tasks, location, notifications, releases, diagnostics, audit log, CSRF-protected audited admin actions.
- Access: Employee IDs 302 and 116 only by default.

## FEATURE-20260720-GROUP-CHANNEL-CREATOR-POLICY
- Date: 2026-07-20
- Area: Group and Channel Management
- Capability: Employee type policy blocks C1/C2 users from creating groups/channels while preserving A/B access.
- Status: Implemented.
