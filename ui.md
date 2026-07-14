# Watchtower Flow UI Design Inventory

Date: 2026-07-14

This file documents the current UI design language and screen inventory for the Watchtower Flow / Skylink Chat application.

## Design System

### Visual Style
- Clean enterprise messaging interface with a WhatsApp/Telegram-style chat surface.
- Primary color is Flow blue, used for active states, send buttons, tabs, chips, selected rows, icons, and progress states.
- Backgrounds are light and low-contrast for operational readability.
- Chat messages use separated incoming/outgoing bubble colors.
- Cards are used for repeated entities such as chats, task summaries, profile details, release notes, and attachment tiles.
- Bottom sheets are used for quick actions and mobile-friendly selection flows.
- Dialogs are used for focused create/edit/configuration tasks.

### Color Tokens
- `AppColors.primary`: Main action blue.
- `AppColors.primaryDark`: Darker blue for gradients and emphasis.
- `AppColors.background`: App scaffold background.
- `AppColors.surface`: Card and panel surface.
- `AppColors.text`: Primary text color.
- `AppColors.muted`: Secondary text, metadata, timestamps.
- `AppColors.divider`: Borders and separators.
- `AppColors.online`: Online presence indicator.
- `AppColors.outgoing`: Outgoing message bubble.

### Common Patterns
- `Scaffold` + `AppBar` for most full screens.
- `Drawer` for global navigation.
- `TabBar` / `TabBarView` for grouped work areas.
- `showModalBottomSheet` for pickers and contextual flows.
- `AlertDialog` for confirmation, form, info, and configuration flows.
- `SelectionArea` / selectable text is used for message and preview copy workflows.
- Floating action buttons are reserved for jump-to-latest and high-priority contextual actions.

## Core Screens

### Splash / Boot
- Shows centered loading while session and app state initialize.
- Redirects to login or home based on stored session.

### Login
- Full-screen authentication form.
- Employee ID based login, with helper text explaining `@chat.skylinkonline.net` is added automatically.
- Includes remember-me behavior and clear error feedback.

### Home / Chat List
- Three-column responsive chat layout on wider screens.
- Left panel:
  - Search.
  - Filter chips: All, Unread, Online, Personal, Groups.
  - Chat rows with avatar, name, designation/tag, last message, timestamp, unread count, pin/star indicators.
- Center panel:
  - Active chat conversation.
- Right panel:
  - Profile / group / channel info.
  - Search and media shortcuts.
  - User detail cards.

### App Drawer
- Global navigation drawer with profile header.
- Uses blue gradient header and list-style navigation items.
- Routes include:
  - Chats.
  - My Hub.
  - Tasks & Tickets.
  - Reminders.
  - Saved Messages.
  - Archived Channels.
  - Chat Folders.
  - Global Search.
  - Diagnostics.
  - Release Management.
  - Appearance.
  - Profile.
  - Attendance.
  - Active Sessions.
  - Settings.
  - What’s New.

## Chat UI

### Conversation Header
- Back/menu access depending on platform width.
- Avatar with online presence dot.
- Name and presence line.
- Actions:
  - Bookmark.
  - Search.
  - Call.
  - More menu.

### Message List
- Date separators.
- Incoming/outgoing bubbles.
- Long message readability support.
- Reply preview block.
- Thread reply indicator.
- Forwarded-from label.
- Sender/source metadata:
  - Device/source line such as `via android - model - version`.
  - Location address line shown only for users with location visibility access.
- Delivery status:
  - Sent.
  - Read.
  - Failed.
  - Sending.

### Message Bubble Content Types
- Plain text.
- Formatted text:
  - Bold.
  - Italic.
  - Strikethrough.
  - Colored spans.
  - Mentions.
- Images.
- Documents / files.
- Audio / voice messages.
- Contact card.
- Live checklist.
- Current location map card.
- Live location map card.

### Composer
- Rounded input bar.
- Emoji toggle.
- Attachment button.
- Voice record button.
- Send button.
- Send button state is bound to current input text.
- Upload progress state.
- Reply composer preview.
- System notification conversations show locked, read-only composer state.

### Attachment Picker
Bottom sheet options:
- Photo or image.
- Document or file.
- Create checklist.
- Contact.
- Current location.
- Live location.
- Stop live location, when sharing is active.

### Attachment Preview
- Images preview inline.
- Files show file tile with icon, name, size, and download action.
- Text and document previews open inside the app when supported.
- Text previews support selection/copy on web.
- Location previews use in-app OpenStreetMap tiles.

### Location UI
- Normal send/read latitude-longitude is metadata only.
- Message Info shows send/read address when visibility allows.
- Current/live location are explicit map-card messages.
- Map cards open inside the app.
- Live location supports:
  - Expiry duration.
  - Stop sharing.
  - Update frequency label.
- Pending future work:
  - Live viewer list.
  - Full visibility policy by user/group/channel/admin role.

### Message Context / Selection UI
- Custom Flow selection toolbar direction:
  - Copy.
  - Reply.
  - Forward.
  - Bookmark.
  - Create Task.
  - AI Summary.
  - Quote.
  - Translate.
  - Delete.
  - Edit.
  - Pin.
  - Message Info.
- Right-click / long-press context actions support Flow-specific actions.

### Message Info Dialog
- Shows:
  - Sent time.
  - Read time.
  - Sent from device/source.
  - Send address, if location visibility is enabled.
  - Read address, if location visibility is enabled.
  - Reader list for group/channel where available.

## Group / Channel UI

### New Group / Channel Sheet
- Bottom sheet flow.
- Name and member selection.
- Searchable people list.

### Manage Group / Channel Sheet
- Member list.
- Admin/owner management.
- Add/remove members.
- Wake-up notification configuration for admins/owners.

### Channel Profile Panel
- Channel identity.
- Search/media shortcuts.
- JID / channel metadata.
- Status and role details.
- Management actions placed near the top before info sections.

## My Hub UI

### My Hub Landing
- Grid/list of operational modules:
  - Attendance.
  - Tasks & Tickets.
  - Leave.
  - Location.
  - Reports / future modules.

### Tasks & Tickets
- Desktop split-pane layout:
  - Left task list.
  - Right task detail pane.
- Mobile list-to-detail navigation.
- Filter chips:
  - All.
  - Open.
  - Request close.
  - Closed.
  - Created by me.
  - Following.
  - Due today.
  - Overdue.
  - Stale.
- Summary cards:
  - Open.
  - Due today.
  - Overdue.
  - Stale.
  - Closed.
- Task cards show:
  - Title.
  - Priority pill.
  - Status pill.
  - Due date.
  - Created-by / follower context.
- Detail pane shows:
  - Title.
  - Status.
  - Priority.
  - Deadline.
  - Alerts.
  - Description.
  - People.
  - Updates.
  - Quick update chips.
  - Update composer.

### Leave
- Leave list screen.
- Leave apply screen.
- OTP / approval dialog flow where required.
- Form fields for leave dates, type, reason, and submission.

### Attendance
- Attendance status and calendar.
- Punch in/out controls.
- Punch-out should remain available by UI policy.
- Calendar uses date-based attendance indicators.

## Operational Screens

### Reminders
- Reminder list.
- Reminder create flow.
- Supports recurrence and assignee selection.
- Dialogs for delete/update confirmations.

### Scheduled Messages
- Schedule message screen.
- Target selection.
- Date/time scheduling.
- Delivery status list.

### Saved Messages
- Saved message list.
- Message cards using chat-like bubble styling.
- Delete / reuse actions.

### Archived Channels
- Archive list.
- Restore/open channel actions.

### Chat Folders
- Folder list and create/edit dialog.
- Folder membership and filter logic.

### Global Search
- Search field at top.
- Results grouped by type.
- Jump-to-chat/message behavior.

### Discovery List
- User/group/channel discovery list.
- Searchable list with avatars and metadata.

## Admin / Settings UI

### Settings
- List-based settings hub.
- Links to:
  - Profile.
  - Appearance.
  - What’s New.
  - Release Management.
  - Sessions.
  - Diagnostics.

### Appearance
- Message scale / display controls.
- Theme-related preferences.

### Profile
- Profile detail cards.
- Avatar/header presentation.
- Device, designation, contact, activity, and location details.

### Active Sessions
- Session list.
- Device/source display.
- Current session indicators.

### Release Management
- Release build list.
- Platform filters.
- Draft/live status.
- Approval and rollout actions.
- Dialogs for changing release status and rollout settings.

### What’s New
- Release note list.
- Feature/security/fix grouping.
- Viewed/unviewed behavior.

### Diagnostics
- Diagnostics dashboard.
- Bottleneck report cards.
- Timing and error summaries.

### Flow Development Registry
- Tabbed development/audit screen.
- Requirements, implementation status, and registry items.
- Dialogs for updating requirements.

### Mojibake Lab
- Utility screen for text encoding recovery.
- Input/output panels.

## Content Components

### Contact Card
- Rounded card with avatar icon.
- Contact name.
- Phone numbers.
- Email rows.
- Tap/copy action direction.

### Live Checklist Card
- Header with checklist icon and title.
- Progress counter.
- Progress bar.
- Checkbox list with completed item strike-through.

### File Tile
- File icon.
- Name.
- Size.
- Download icon.
- Opens preview inside app when supported.

### Location Card
- Map tile background.
- Center pin.
- Gradient footer.
- Title:
  - Current location.
  - Live location.
- Address/coordinate line.
- Live duration chip.

### Task Cards
- Compact operational cards.
- Priority/status pills.
- Alert flags.
- Due/stale indicators.

### Info Cards
- Used in profile, My Hub, task details, settings.
- Label + value layout.
- Leading icons for scanning.

## Responsive Behavior

### Mobile
- Single-column navigation.
- Chat list opens chat screen.
- Task list opens task detail page.
- Bottom sheets are primary action surfaces.

### Tablet/Desktop/Web
- Split layout where possible.
- Chat list, conversation, and info panel can be visible together.
- MyHub tasks use split-pane list/detail.
- Keyboard/mouse context menus supported on web/desktop.

## Interaction Standards

### Copy / Selection
- Message text and preview text must support selection.
- Web `Ctrl+C` / `Cmd+C` must copy selected text.
- Context action Copy should copy complete selected message(s).

### Attachments
- Default click opens inside app.
- Download is explicit via download icon/button.
- Restricted files should disable download and force in-app preview only.

### Location
- Metadata location must not render as a map message.
- Explicit current/live location must render as a map-card message.
- Location visibility governs who sees address metadata.

### Error States
- Use inline error panels for recoverable screen loads.
- Use snackbars for short user action failures.
- Use retry buttons on load failure cards.

### Empty States
- Use concise centered messaging.
- Include action/retry where useful.

## Pending UI Design Work

- Full enterprise custom selection toolbar across Android, iOS, Windows, and Web.
- Live location viewer list.
- Location visibility policy editor by user/group/channel/admin role.
- Rich file editors for supported office/text/PDF formats.
- More complete dark mode audit.
- Accessibility pass for font scaling, focus order, and keyboard navigation.
- Dedicated task creation form with all `task_master` fields surfaced where required.
- Stronger release-management visual distinction between Draft, Approved, Live, and Retired.


---

# Detailed UI Specification

This section expands the inventory into a more implementation-ready UI reference. It can be used by developers, QA, and designers when checking whether the application behaves consistently across Android, Web, and Windows.

## 1. App Shell

### Purpose
The app shell is the persistent structure that holds authentication, navigation, and the active workspace.

### Primary UI Areas
- App boot loader.
- Login screen.
- Drawer navigation.
- Chat workspace.
- Module screens opened from drawer or My Hub.

### Layout Rules
- Mobile uses one active screen at a time.
- Desktop/web can show multi-pane layouts.
- Navigation should never hide the active task/chat context without a clear back path.
- Drawer should be reachable from primary workspace screens.
- App bar titles must be short and action-oriented.

### Required States
- Loading.
- Authenticated.
- Unauthenticated.
- Offline / reconnecting.
- Empty module.
- Permission blocked.
- API error with retry.

### QA Checks
- Back button works on Android and browser.
- Drawer does not cover modals incorrectly.
- Keyboard focus stays inside dialogs/bottom sheets.
- Screen width changes do not overlap panels.

## 2. Authentication UI

### Login Screen Layout
- Centered login card/form.
- Employee ID field.
- Password field.
- Remember me checkbox.
- Login button.
- Support/helper text for JID generation.
- Error message area.

### Interaction Rules
- Login button disabled when required fields are empty.
- Enter key submits when valid.
- Failed login shows clear message without clearing entered employee ID.
- Remember me persists the correct session only after successful login.

### Visual Details
- Primary button uses `AppColors.primary`.
- Helper text uses `AppColors.muted`.
- Inputs use rounded outlined style from the app theme.

## 3. Chat List UI

### Left Panel Structure
- Top menu button.
- Search field.
- New message / compose icon.
- Horizontal filter chips.
- Scrollable chat list.

### Filter Chips
- All.
- Unread.
- Online.
- Personal.
- Groups.

### Chat Row Data
Each row should show:
- Avatar or initials.
- Online dot.
- Name.
- Designation or role badge.
- Last message preview.
- Time/date.
- Unread count.
- Pin indicator.
- Star/favorite indicator where relevant.

### Row States
- Selected chat.
- Hovered row on web/desktop.
- Unread row.
- Pinned row.
- Muted row.
- System notification row.
- Group/channel row.

### Empty States
- No chats found.
- No unread chats.
- No online users.
- No groups.

## 4. Chat Workspace

### Desktop/Web Layout
- Left: chat list.
- Center: active conversation.
- Right: profile/group/channel info panel.

### Mobile Layout
- Chat list opens full chat screen.
- Profile panel opens as separate sheet/page.

### Conversation Header
Must include:
- Back/menu icon.
- Avatar.
- Online dot.
- Name.
- Presence text.
- Bookmark action.
- Search action.
- Call action.
- More menu.

### Presence Text Examples
- `online`
- `last seen today at 3:46 PM`
- `Group conversation`

### Header States
- Direct chat.
- Group/channel.
- System notification.
- Offline user.
- Loading presence.

## 5. Message List

### Message Grouping
- Date separator appears between days.
- Messages ordered oldest to newest.
- New messages append at bottom unless user is reading older messages.
- Jump-to-latest FAB appears when user is not near bottom.

### Bubble Layout
Outgoing:
- Right aligned.
- Uses outgoing bubble color.
- Shows delivery/read status.

Incoming:
- Left aligned.
- Uses incoming bubble color.
- Shows sender name in groups/channels.

### Bubble Metadata
Each message may show:
- Time.
- Edited label.
- Sent/read icon.
- Source line.
- Location address line, if user can view locations.

### Source Line
Format:
- `via android - motorola moto g96 5G - v2.0.3`
- `via web - chrome browser - v2.0.3`
- `via windows - desktop - v2.0.3`

### Location Metadata Line
Rules:
- Show only when location visibility allows.
- Show below message/source line.
- Use small muted text.
- Include location icon.
- Must apply to normal text messages, files, voice notes, contacts, checklists, and explicit location cards when metadata exists.
- Must not turn normal messages into map messages.

### Message Types
- Text.
- Reply.
- Thread reply.
- Forwarded.
- Image.
- File/document.
- Voice/audio.
- Contact.
- Checklist.
- Current location.
- Live location.
- System notification.

## 6. Text Message UI

### Formatting Support
- Bold.
- Italic.
- Strikethrough.
- Color tag.
- Mentions.

### Selection and Copy
Requirements:
- Partial message text selection must work.
- Full message copy action must work.
- Web `Ctrl+C` / `Cmd+C` must copy selected text.
- File preview text must support selection/copy.
- Copy action should not scroll the message unexpectedly.

### Long Text
- Long messages should be readable.
- Collapse/expand may be used for very long content.
- Text must not overflow bubble width.

## 7. Reply, Quote, Thread

### Reply Preview
- Shows original sender.
- Shows short preview of original content.
- Has close button in composer.

### Quoted Text
- Quote should be visually distinct.
- Quoted content should not merge confusingly with new content.

### Thread UI
- Thread reply indicator inside bubble.
- Thread view screen shows original message and replies.
- Thread composer has its own text input and send button.

## 8. Message Selection Toolbar

### Current Direction
The app should use a custom Watchtower Flow selection toolbar instead of default platform contextual action bars.

### Actions
- Copy.
- Reply.
- Forward.
- Bookmark.
- Create Task.
- AI Summary.
- Quote.
- Translate.
- Delete.
- Edit.
- Pin.
- Message Info.

### Behavior
- Long press selects message on Android.
- Right click opens context menu on web/desktop.
- Multi-select enables batch actions.
- Disabled actions should be visually disabled, not hidden unless irrelevant.

### Enterprise UX Rule
The toolbar should be consistent across:
- Android.
- iOS.
- Windows.
- Web.

## 9. Composer

### Layout
- Emoji icon.
- Text input.
- Optional formatting/AI/send-later controls.
- Attachment icon.
- Voice button.
- Send button.

### Send Button Rules
- Enabled immediately when current text is non-empty.
- Disabled when empty and no sendable payload exists.
- Must update through `TextEditingController` listener or `onChanged`.
- Must not require navigation/reopening to refresh enabled state.

### Keyboard Rules
- Enter sends where platform behavior expects it.
- Shift+Enter/newline should be considered for desktop/web.
- Paste text should update send button immediately.

### Upload State
- Composer shows upload progress.
- Attachment button disabled while upload is active.
- Send button should not send duplicate messages.

## 10. Attachment Picker

### Bottom Sheet Options
- Photo or image.
- Document or file.
- Create checklist.
- Contact.
- Current location.
- Live location.
- Stop live location, when active.

### File Requirements
- Support multiple files.
- Support all common file types: images, PDF, TXT, CSV, XLSX, DOC/DOCX, HTML, PHP, APK, and other binary files.
- No artificial size limit in UI.
- Errors must be actionable.

### Paste / Drag Drop
- Web copy/paste file upload should work.
- Web drag/drop should work.
- Clipboard images/files should open preview/send dialog.

## 11. Attachment Preview UI

### Shared Preview Shell
- App bar with back button.
- File name as title.
- Download icon when allowed.
- Error state with retry.
- In-app preview area.

### Image Preview
- Show actual image.
- Preserve aspect ratio.
- Support loading and error states.

### Text Preview
- Selectable text.
- Copy support.
- Scrollable.
- Monospace may be used for code-like files.

### PDF Preview
- Should open inside app where possible.
- If rendering fails, show clear retry/download fallback.

### Office/CSV Preview
- Should open inside app where possible.
- CSV should be readable as tabular or text fallback.
- XLSX/DOCX may use app-native preview/fallback strategy.

### Restricted Files
- Download disabled.
- Preview only inside app.
- Show restricted indicator.
- Screenshot/screen-record prevention is platform-limited and cannot be guaranteed on web.

## 12. Location Intelligence UI

### Two Separate Concepts
Metadata location:
- Stored on every normal send/read event.
- Used only in Message Info and metadata line when allowed.
- Does not render a map card.

Explicit location message:
- User chooses current/live location.
- Renders as map-card message.

### Current Location Card
Must show:
- Map tile preview.
- Red pin.
- Title `Current location`.
- Address/coordinate.
- Sent time/status.

### Live Location Card
Must show:
- Map tile preview.
- Red pin.
- Title `Live location`.
- Address/coordinate.
- Duration chip.
- Expiry info.

### Live Location Controls
- Duration picker.
- Update frequency label.
- Stop sharing.
- Future: viewer list.

### In-App Map Dialog
- Opens when map card is tapped.
- Must not open external browser/map app by default.
- Shows larger map preview.
- Shows selectable address.
- Shows expiry/update info for live location.

### Visibility Policy
Current:
- User-level location visibility controls.

Target:
- User-level policy.
- Group-level policy.
- Channel-level policy.
- Admin role override.
- Audit trail for policy changes.

## 13. Contact Message UI

### Contact Card Layout
- Circular contact icon.
- Contact name.
- Phone rows with phone icon.
- Email rows with mail icon.

### Interaction
- Tap to view contact details.
- Copy phone/email where possible.
- Android contact permission requested before picking contact.

## 14. Checklist Message UI

### Card Layout
- Checklist icon.
- Checklist title.
- Completed count.
- Progress bar.
- Checkbox rows.

### Interaction
- Tapping checkbox updates item status.
- Completed items show strike-through.
- Card should not resize unpredictably.

## 15. Message Info UI

### Dialog Fields
- Sent time.
- Read time.
- Sent from.
- Send address.
- Read address.
- Details/fallback error.
- Group reader details.

### Visibility
- Address fields only visible when current user has location visibility permission.

### Error Handling
- If remote info API fails, local message info should still open with whatever data exists.

## 16. Profile / Right Panel

### Direct User Panel
- Avatar.
- Name.
- Designation.
- Search button.
- Media button.
- JID.
- Employee ID.
- Designation.
- Status.
- Last location where allowed.

### Group/Channel Panel
- Avatar/icon.
- Name.
- Type.
- Member count.
- Search/media buttons.
- Manage group/channel action near top.
- Group/channel info below manage action.

### Layout Rule
Management actions should appear before informational details when they are primary workflow actions.

## 17. My Hub

### Landing Design
- Operational module launcher.
- Dense but readable cards.
- Icons for module identity.

### Modules
- Attendance.
- Tasks & Tickets.
- Leave.
- Location.
- Future operational workflows.

## 18. Tasks & Tickets Detailed UI

### Screen Layout
Desktop/web:
- Left task list.
- Right detail pane.

Mobile:
- Task list.
- Tap opens detail page.

### Task List
Each task row/card includes:
- Title.
- Description snippet.
- Priority.
- Status.
- Deadline.
- Due/overdue/stale flags.
- Created/following context.

### Filters
- All.
- Open.
- Request close.
- Closed.
- Created by me.
- Following.
- Due today.
- Overdue.
- Stale.

### Detail View
Includes:
- Title.
- Status pill.
- Priority pill.
- Due pill.
- Alert banners.
- Description card.
- People card.
- Updates list.
- Update composer.
- Quick update chips.

### Task Creation
Create task from message should include:
- Title.
- Description.
- Priority.
- Assignees.
- Followers.
- Deadline.
- Task group/channel context.
- Created by.
- Status.
- Task type, meet type, vertical when backend table supports them.

## 19. Leave UI

### Leave List
- Summary list of leave requests.
- Status indicators.
- Dates and leave type.

### Apply Leave
- Form fields: from date, to date, leave type, reason.
- Submit button.
- OTP dialog where required.

### States
- Loading leave balance/history.
- No leave requests.
- OTP pending.
- Error with retry.

## 20. Attendance UI

### Attendance Calendar
- Monthly calendar.
- Attendance status by date.
- Punch details.

### Punch Controls
- Punch in.
- Punch out.
- Punch out should remain enabled by UI policy.
- If previous working day lacks punchout, UI should guide user to punch out first.

### Error Rules
- Do not silently alter backend attendance records.
- UI should explain required next action.

## 21. Reminders UI

### Reminder List
- Reminder title.
- Kind/type.
- Next due date.
- Recurrence.
- Assignees.

### Create Reminder
- Title.
- Kind.
- Date/time.
- Recurrence.
- Assignees.
- Notes.

## 22. Release Management UI

### Purpose
Manage release lifecycle for Android, Web, Windows, and Linux.

### Build Row Fields
- Platform.
- Version.
- Build number.
- Status.
- Stage.
- Rollout percentage.
- Force update.
- Uploaded by.
- Notes.

### Status Flow
- Draft.
- Approved.
- Live.
- Retired.

### Approval Rule
- Employee 302 approval moves draft to live.

### Artifact UI
- APK download.
- Web ZIP download.
- Windows installer EXE download.
- Hash/checksum visibility.

## 23. Diagnostics UI

### Dashboard
- Bottleneck cards.
- Critical/error badges.
- Average and max duration.
- Recent measurements.

### Categories
- API.
- Notification.
- XMPP.
- Database.
- Android.
- Web.
- Attendance.
- Location.

### UI Rules
- Critical issues first.
- Use color but never color alone.
- Include timestamp/window.

## 24. Flow Registry UI

### Purpose
Track architecture and product requirements.

### Tabs
- Requirements.
- Implementation status.
- Audit/report items.

### Registry Item Fields
- ID.
- Title.
- Description.
- Status.
- Priority.
- Owner.
- Notes.

## 25. Accessibility Checklist

### Text
- No negative letter spacing.
- Font scaling should not break buttons/cards.
- Long labels wrap cleanly.

### Color
- Primary/secondary contrast must be sufficient.
- Badges need text labels, not color-only meaning.

### Input
- Focus order must be predictable.
- Dialog fields should be keyboard accessible.
- Buttons need tooltips when icon-only.

### Selection
- Web and desktop text selection must support copy.
- Android custom toolbar should expose the same core actions.

## 26. Platform Specific Notes

### Android
- Long press message selection.
- Contact permission.
- Location permission.
- Storage/download permission where required.
- Voice recording permission.

### Web
- Ctrl/Cmd+C must copy selected text.
- Drag/drop files.
- Paste files/images.
- In-app file preview.
- HTTPS/server config must be correct for production.

### Windows
- Installer must create valid shortcut to `skylink_chat.exe`.
- App opens as desktop window.
- File downloads should use user-accessible folders.
- Keyboard/mouse context interactions should match web as much as possible.

## 27. QA Matrix

| Area | Mobile | Web | Windows |
| --- | --- | --- | --- |
| Login | Required | Required | Required |
| Chat send | Required | Required | Required |
| File upload | Required | Required | Required |
| File paste | Optional | Required | Optional |
| Text copy | Required | Required | Required |
| Message info | Required | Required | Required |
| Location metadata | Required | Required | Required |
| Map card | Required | Required | Required |
| Live location stop | Required | Required | Required |
| Task list/detail | Required | Required | Required |
| Release update | Required | Required | Required |

## 28. Design Principles

- Operational density over decorative layout.
- Fast scanability over marketing presentation.
- Every action should be reachable with minimal navigation.
- Enterprise workflows should be explicit and auditable.
- Location privacy must be visible and role-aware.
- Attachments should open inside Flow by default.
- Errors should explain what the user can do next.
