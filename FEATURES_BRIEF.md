# Watchtower Flow Feature Catalogue

Date: 2026-07-14

This document explains the major features available in the Watchtower Flow / Skylink Chat application, what each feature is for, and how it behaves in the current product direction.

## 1. Product Overview

Watchtower Flow is an enterprise messaging and operations platform. It combines chat, groups, channels, tasks, attendance, notifications, file sharing, location intelligence, release management, and operational workflow tracking in one application.

The application is available for:
- Android APK.
- Web build.
- Windows desktop installer.
- Linux/Ubuntu build direction.

The product is designed to work like a modern messaging app, but with enterprise features such as task creation, channel workflows, audit visibility, release approvals, location visibility control, and operational reporting.

## 2. Login and Session Management

### What It Does
Users log in with their employee identity and access chat, My Hub, tasks, attendance, and operational modules.

### How It Works
- Employee ID is used as the primary login identity.
- The app automatically works with the chat JID format like `employee_id@chat.skylinkonline.net`.
- Sessions can be remembered on supported platforms.
- Active sessions can be viewed from the app.

### UI
- Login form with employee ID and password.
- Remember-me option.
- Error display for failed login.
- Loading state while authentication is checked.

### Related Features
- Active sessions.
- Profile.
- Device/source tracking.
- Push token registration.

## 3. Core Chat

### What It Does
The app supports real-time style conversations between users, groups, and channels.

### Conversation Types
- Personal one-to-one chat.
- Group chat.
- Channel conversations.
- System notification conversation.

### Message Types
- Normal text message.
- Reply message.
- Forwarded message.
- Thread reply.
- Image message.
- File/document message.
- Voice message.
- Contact message.
- Checklist message.
- Current location message.
- Live location message.
- System notification message.

### UI
- Chat list on the left.
- Conversation in the center.
- Profile/group/channel info panel on the right for larger screens.
- Mobile uses screen-by-screen navigation.

### Message Bubble Details
Each message can show:
- Message text or attachment preview.
- Time.
- Sent/read status.
- Source device line.
- Sender location address line if user has location visibility permission.
- Reply preview.
- Forwarded-from details.
- Thread indicator.

### Delivery Status
- Sending.
- Sent.
- Read.
- Failed.

## 4. Chat List and Filters

### What It Does
The chat list helps users quickly find conversations.

### Filters
- All.
- Unread.
- Online.
- Personal.
- Groups.

### Chat Row Shows
- Avatar or initials.
- Online status dot.
- Name.
- Designation or role tag.
- Last message preview.
- Time/date.
- Unread count.
- Pin indicator.
- Star/favorite indicator where applicable.

### Search
Users can search conversations and contacts.

### System Notifications
System notification conversation appears as a receive-only chat for OTP and backend alerts.

## 5. Message Actions

### What It Does
Messages support enterprise actions beyond normal chat apps.

### Supported / Planned Actions
- Copy.
- Reply.
- Forward.
- Bookmark.
- Create Task.
- Update Task.
- Create Reminder.
- Create Follow-up.
- AI Summary.
- Quote.
- Translate.
- Delete.
- Edit.
- Pin.
- Message Info.

### Selection Behavior
- Android: long press selects message.
- Web/Windows: right-click/context menu direction.
- Multi-select actions are supported in direction.

### Copy Behavior
- Message text can be selected.
- Web Ctrl+C / Cmd+C should copy selected text.
- File preview text should also support copy.

## 6. Message Info

### What It Does
Shows audit and delivery information for a message.

### Fields
- Sent time.
- Read time.
- Sent from device/source.
- Send address.
- Read address.
- Group/channel reader list where available.

### Location Visibility
Send/read addresses are visible only to users who have location visibility permission.

### Fallback Behavior
If live message info API fails, local message data should still show a basic info dialog.

## 7. Attachments and File Sharing

### What It Does
Users can send and receive many file types through chat.

### Supported File Types
- Images.
- PDF.
- TXT.
- CSV.
- XLSX.
- DOC/DOCX.
- HTML.
- PHP.
- APK.
- Generic binary files.

### Upload Features
- Multiple file selection.
- Image selection.
- Document/file selection.
- File drag and drop on web/desktop direction.
- Clipboard paste for files/images on web.
- Caption support.

### Preview Features
- Image preview.
- Text preview.
- PDF preview direction.
- Office/CSV preview direction.
- Binary file tile fallback.
- In-app preview by default.

### Download Features
- Download unrestricted files.
- Restricted files should disable download and open only inside app.

### UI
- Attachment bottom sheet.
- File preview/send dialog.
- File tile with icon, file name, size, and download button.
- Image preview with download icon.

## 8. Voice Messages

### What It Does
Users can record and send voice messages.

### Behavior
- Microphone permission is requested.
- Audio is recorded and sent as an attachment.
- Voice message appears in chat as audio content.
- Storage/download handling is part of attachment behavior.

### UI
- Voice button in composer.
- Recording state.
- Upload progress.
- Playback preview direction.

## 9. Contact Sharing

### What It Does
Users can send mobile contacts inside chat.

### Behavior
- Android contact permission is requested.
- User picks a contact from phone contacts.
- Contact card is sent as a structured message.

### UI
Contact card shows:
- Contact icon/avatar.
- Name.
- Phone numbers.
- Email addresses.

## 10. Live Checklist Messages

### What It Does
Users can create checklist messages directly inside chat.

### Behavior
- Checklist can be created from composer or message action.
- Items are stored as structured checklist data.
- Users can toggle checklist items.

### UI
Checklist card shows:
- Checklist title.
- Checklist icon.
- Progress count such as `1/5`.
- Progress bar.
- Checkbox rows.
- Completed item strike-through.

### Use Cases
- Build checklist.
- Deployment checklist.
- Daily workflow checklist.
- Task/action checklist.

## 11. Location Intelligence

### What It Does
The app separates audit location metadata from explicit location sharing.

### Two Location Modes
1. Metadata location.
2. Explicit location message.

### Metadata Location
Used for:
- Normal text message send location.
- File send location.
- Voice/contact/checklist send location.
- Read location.
- Message Info audit.

Important rule:
- Metadata location must not render as a map card.
- It is stored against the message for visibility/audit.

### Explicit Current Location
Used when user selects Current location from attachment menu.

UI:
- Map card.
- Red pin.
- Address line.
- Time and delivery status.

### Explicit Live Location
Used when user selects Live location from attachment menu.

Features:
- Duration selection.
- Update frequency label.
- Stop sharing control.
- Map-card message.
- Expiry direction.
- Viewer list direction.

### In-App Map
- Map card opens inside the app.
- Uses in-app map preview direction.
- Should not open external browser/map app by default.

### Location Visibility
Current direction:
- User-level location visibility.

Target direction:
- User-level policy.
- Group-level policy.
- Channel-level policy.
- Admin role override.
- Audit history for policy changes.

## 12. Groups and Channels

### What It Does
Teams can communicate through group and channel spaces.

### Features
- Create group/channel.
- Add members.
- Remove members.
- Owner/admin role handling.
- Group/channel profile panel.
- Manage group/channel action.
- Wake-up notification configuration.
- Mentions.

### Mention Support
Direction includes:
- Everyone/channel mention.
- Online users mention.
- Admin mention.
- Member list mention search.

### Channel Architecture Direction
Channel Type should define behavior, not just label.

Planned configurable channel types:
- Incident.
- Action.
- Operational.
- Project.
- Announcement.

Each type can have:
- UI rules.
- AI Marshal behavior.
- SOP.
- SLA rules.
- KPIs.
- Checklists.
- Permissions.
- Widgets.
- Workflows.

## 13. My Hub

### What It Does
My Hub is the operational workspace for non-chat workflows.

### Modules
- Tasks & Tickets.
- Attendance.
- Leave.
- Location/field activity direction.
- Future workflow modules.

### UI
- Operational module cards.
- Icons.
- Direct navigation into each module.

## 14. Tasks & Tickets

### What It Does
Tasks & Tickets manages work items linked to employees, followers, groups, deadlines, and chat workflows.

### Task Sources
- Existing task list from task backend.
- Task created from message.
- Task updated from message.
- Manual task updates.

### Task List Filters
- All.
- Open.
- Request close.
- Closed.
- Created by me.
- Following.
- Due today.
- Overdue.
- Stale.

### Task List Card Shows
- Title.
- Description snippet.
- Priority.
- Status.
- Deadline.
- Overdue/due/stale indicators.
- Created-by/follower context.

### Task Detail Shows
- Task title.
- Priority.
- Status.
- Deadline.
- Description.
- Creator.
- Assignees.
- Followers.
- Updates.
- Quick update chips.
- Update composer.

### Quick Updates
- Started.
- Follow up.
- Blocked.
- Close request.

### Task Creation From Chat
The app can create a task from a chat message.

Task payload direction includes:
- Title.
- Description.
- Priority.
- Assignees.
- Followers.
- Deadline.
- Created by.
- Task group/channel context.
- Status.
- Task type.
- Meet type.
- Vertical.

### Task Update From Chat
A selected message can be added as a task update/comment.

## 15. Attendance

### What It Does
Attendance manages punch-in/punch-out and calendar status.

### Features
- Attendance status.
- Punch in.
- Punch out.
- Attendance calendar.
- Previous working day punch-out guidance direction.

### Current UI Direction
- Punchout button should remain enabled by UI policy.
- If previous working day was not punched out, user should be guided to punch out before punching in again.

### UI
- Attendance cards.
- Calendar view.
- Punch controls.
- Status indicators.

## 16. Leave Management

### What It Does
Users can view and apply for leave.

### Features
- Leave list.
- Apply leave screen.
- Leave type.
- From/to dates.
- Reason.
- OTP/approval flow direction.

### UI
- Leave request cards.
- Apply form.
- Confirmation/OTP dialogs.

## 17. Reminders and Follow-ups

### What It Does
Users can create reminders and follow-ups from messages or manually.

### Features
- Reminder list.
- Create reminder.
- Recurrence.
- Assignees.
- Notes.
- Source conversation/message context.

### Reminder Types
- Reminder.
- Follow-up.
- Future workflow reminder types.

## 18. Scheduled Messages

### What It Does
Users can schedule messages to be sent later.

### Features
- Schedule message body.
- Select date/time.
- Select targets.
- View scheduled list direction.

### UI
- Scheduled message screen.
- Date/time picker.
- Target selection.

## 19. Notifications

### What It Does
The app supports system and push notifications.

### Notification Types
- System notification chat.
- OTP notification.
- External web application notification.
- Push notification.
- Wake-up notification.
- Task/update notification direction.

### External Notification API
Backend applications can push messages to the System Notifications conversation.

### Push Dispatch
Push notification registration and dispatch are supported. Dispatch is designed to avoid blocking message send response.

## 20. Profile and User Details

### What It Does
Shows employee/user profile information.

### Profile Fields
- Name.
- Employee ID.
- Designation.
- JID.
- Online/offline status.
- Device info.
- Last activity.
- Latest location address where allowed.
- Mobile/contact details.

### UI
- Profile header.
- Avatar.
- Info cards.
- Status indicators.

## 21. Saved Messages

### What It Does
Users can save important messages.

### Features
- Save/bookmark messages.
- View saved messages list.
- Open source context direction.

### UI
- Saved message cards.
- Chat-like preview style.

## 22. Global Search

### What It Does
Search across users, chats, channels, and messages.

### Features
- Search input.
- Result list.
- Jump to chat/message direction.

### UI
- Search screen.
- Grouped results.
- Empty state.

## 23. Chat Folders and Archived Channels

### Chat Folders
- Organize conversations into folders.
- Create/edit folder direction.
- Filter/group chat list direction.

### Archived Channels
- View archived channels.
- Open/restore archived conversations direction.

## 24. Settings

### What It Does
Settings centralizes user and application controls.

### Settings Areas
- Profile.
- Appearance.
- What’s New.
- Release Management.
- Active Sessions.
- Diagnostics.
- Location Visibility.
- Other app preferences.

## 25. Appearance Settings

### What It Does
Controls display and visual preferences.

### Features
- Message scale direction.
- Theme/dark mode direction.
- UI density direction.

## 26. Active Sessions

### What It Does
Shows devices/sessions connected to the user account.

### Fields
- Device ID.
- Device name.
- Platform.
- Source.
- Current session indicator direction.

## 27. Diagnostics

### What It Does
Shows operational performance and error diagnostics.

### Diagnostics Categories
- API calls.
- Message sending.
- Push notifications.
- XMPP.
- Database.
- Android app requests.
- Attendance.
- Location visibility.

### UI
- Bottleneck cards.
- Critical/error badges.
- Average/max latency.
- Measurement window.

### Use Case
Find slow message send, delayed notifications, API failures, and background bottlenecks.

## 28. Release Management

### What It Does
Manages release lifecycle for app builds.

### Platforms
- Android.
- Web.
- Windows.
- Linux/Ubuntu direction.

### Release Fields
- Platform.
- Version.
- Build number.
- Stage.
- Status.
- Artifact URL.
- Notes.
- Rollout percent.
- Force update.
- Uploaded by.

### Release Flow
- Draft.
- Approved.
- Live.
- Retired.

### Approval Rule
Employee 302 approval moves draft builds to live.

### Artifacts
- Android APK.
- Web ZIP.
- Windows installer EXE.
- SHA256 checksums.

## 29. What’s New / Release Notes

### What It Does
Shows app release notes and new features.

### Content Types
- Features.
- Fixes.
- Security notes.
- Known changes.

### UI
- Release note cards.
- Viewed/unviewed behavior direction.

## 30. Flow Registry

### What It Does
Tracks product, architecture, audit, and implementation requirements.

### Registry Content
- Feature requirements.
- Architecture requirements.
- Audit requirements.
- Implementation status.
- Future AI Marshal/SLA/channel workflow direction.

### UI
- Tabbed registry screen.
- Requirement cards/list.
- Dialogs for updating entries.

## 31. Work Reports and Documentation

### Existing Documentation Direction
- `WORK_REPORT_2026-07-13.md`: work updates and implementation history.
- `FLOW_TODAY_REQUIREMENTS.txt`: daily requirement tracking.
- `ui.md`: UI design inventory/specification.
- `FEATURES_BRIEF.md`: product feature catalogue.
- `AGENTS.md`: development/coding guidance.

## 32. Security and Privacy Direction

### Location Privacy
- Location address visible only when user has permission.
- Metadata stored for audit but not shown to unauthorized users.
- Current/live location is user-explicit.

### File Restrictions
- Restricted files should not download.
- Restricted files should open only inside app.
- Web screenshot/screen recording prevention cannot be fully guaranteed.

### Authorization
- Admin-only features must check role/permission.
- Release approval must enforce employee 302 rule.
- Group/channel management must enforce owner/admin role.

## 33. AI and Automation Direction

### AI Marshal Direction
Future Flow can support:
- AI summary.
- Task extraction from messages.
- SLA alerts.
- Incident-to-action workflows.
- Channel automation.
- Operational orchestration.

### Current UI Hooks
- AI Summary action in message toolbar direction.
- Flow Registry architecture direction.
- Channel type definition direction.

## 34. Platform Support

### Android
- Chat.
- File upload.
- Voice recording.
- Contact sharing.
- Current/live location.
- Push notifications.
- Attendance and My Hub.

### Web
- Chat.
- File preview.
- Copy/paste and drag/drop files.
- Text selection/copy.
- In-app map preview.
- Release/admin screens.

### Windows
- Desktop chat app.
- File handling.
- Installer EXE.
- Desktop shortcuts.
- Web-like mouse/keyboard workflows direction.

## 35. Important Pending Features

These are planned or partially implemented items:
- Full custom message selection toolbar across platforms.
- Full viewer list for live location.
- Location policy by user/group/channel/admin role.
- Rich in-app office editors.
- Better PDF rendering fallback.
- Full task creation form for all backend fields.
- Full channel-type metadata architecture.
- Dark mode audit.
- Accessibility audit.
- Automated unit/integration/UI/performance/battery tests.

## 36. Summary

Watchtower Flow currently combines messaging, files, locations, contacts, checklists, tasks, attendance, leave, notifications, release management, diagnostics, and requirement tracking. The app is evolving from a chat application into an enterprise operational workflow platform where conversations can become tasks, incidents, reminders, audits, and automated workflows.