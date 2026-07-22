
## DECISION-20260715-VERSION-2.0.4
- Date: 2026-07-15
- Decision: Use version 2.0.4+27 for this build instead of reusing 2.0.3+26.
- Reason: Existing 2.0.3 artifacts and draft scripts were already present; new version avoids duplicate release-registration ambiguity.

## DECISION-20260715-GROUP-ADMIN-SCOPE
- Date: 2026-07-15
- Decision: Keep promote/demote restricted to owners, while admins receive add/remove/rename management access.
- Reason: Prevents admins from escalating or demoting other admins without owner control while satisfying admin operational management needs.


## DECISION-20260715-SCROLL-FORCE-VS-SELECTION
- Date: 2026-07-15
- Decision: Keep selection guard for passive auto-scroll but bypass it for explicit user jump/open-chat scrolls.
- Reason: Preserves copy/select stability while restoring expected Telegram/WhatsApp-style latest-message positioning.


## DECISION-20260715-INITIAL-INDEX-NOT-AUTOSCROLL
- Date: 2026-07-15
- Decision: Use list initialScrollIndex for first chat render instead of programmatic scroll.
- Reason: Default bottom positioning should be layout state, while programmatic scroll should only happen for explicit user action or newly-sent messages.


## 2026-07-15 18:20:41 +05:30
- Decision: Keep task notifications backend-side so all clients receive consistent System Notifications and task APIs remain the source of truth.
- Decision: Preserve existing poll vote arrays by option text during poll edit to avoid losing votes when labels are unchanged.
- Decision: Saved Messages now uses an attachment option sheet first, matching the chat composer pattern without changing existing file upload backend.


## 2026-07-16 10:39:38 +05:30
- Decision: Keep latitude/longitude stored as metadata, but resolve coordinate-looking display values to address at the UI boundary using existing reverse_geocode API/cache.


## 2026-07-16 11:03:55 +05:30
- Decision: Poll votes already store employee IDs, so frontend maps IDs to known participant names for creator visibility. Checklist now stores checked_by IDs on toggle to support the same visibility model.



## DEC-20260716-ATTACHMENT-RESTRICTED
- Date: 2026-07-16 11:42:08
- Decision: Store restricted state as xmpp_messages.file_restricted and propagate through API JSON/attachment metadata.
- Decision: Restricted files remain previewable inline inside Flow but hide download/open-with controls and reject app download requests via media.php?download=1.
- Decision: Unrestricted files retain normal download behavior and use externalApplication launch for Open with.


## DEC-20260716-SAVED-FORWARD-PASTE
- Date: 2026-07-16 11:56:28
- Decision: Treat Saved Messages as a special forward target with jid saved@chat.skylinkonline.net and type saved.
- Decision: Store forwarded attachments in saved_messages using file_url/file_name/file_type rather than sending a pseudo-chat message.
- Decision: Improve Windows Saved Messages usability with explicit text paste and desktop drop using existing dependencies; browser clipboard file paste remains through ClipboardMediaBridge.


## DEC-20260716-CHAT-SELECTION-SCROLL-LOCK
- Date: 2026-07-16 12:06:05
- Decision: Preserve latest-message initial positioning through ScrollablePositionedList.initialScrollIndex/initialAlignment, while separately locking viewport during text selection by restoring the visible anchor. This separates chat-open behavior from selection behavior instead of using one scroll-to-bottom rule for both.


## DEC-20260716-DESKTOP-PANEL-BUBBLE-WIDTH
- Date: 2026-07-16 12:12:05
- Decision: Keep the right profile panel opt-in through ChatScreen.onProfileTap rather than opening automatically on chat selection.
- Decision: Use desktop-specific bubble max-width cap and shrink-wrapping to move message presentation closer to WhatsApp/Telegram while retaining max width for long content.


## DEC-20260716-MULTIPLATFORM-DRAFT-BUILD
- Date: 2026-07-16 13:20:24
- Decision: Reuse version 2.0.4+27 already present in pubspec.yaml and refresh all three platform artifacts from current workspace state.
- Decision: Register all three platforms as Development/Draft with rollout_percent 0 and force_update 0, preserving 302 approval gate.
- Decision: Upload web ZIP to downloads as draft artifact only; live web app folder was not replaced.


## DEC-20260716-STANDALONE-FLOW-MASTER-ADMIN
- Date: 2026-07-16 15:34:05 +05:30
- Decision: Keep all admin app code inside admin/ and use local deploy-owned admin_config.php instead of requiring chat/bootstrap.php.
- Reason: User requires /admin to be a separate PHP web application outside the chat folder, with no calls to outside pages.
- Tradeoff: Credentials must be configured separately on the server; admin_config.php is gitignored and sample config is committed.

## DEC-20260716-ADMIN-COUNTS-LIVE-CHAT
- Time: 2026-07-16 18:15:28
- Decision: Use xmpp_users for Overview Users because admin Users screen is for live chat accounts, while employee table can contain broader HR records.
- Decision: Split Groups and Channels as separate admin views rather than a combined table to match operational admin workflows.


## DEC-20260720-C1C2-GROUP-CHANNEL-CREATE-BLOCK
- Date: 2026-07-20
- Decision: Enforce the create restriction in backend create_group.php/create_channel.php and mirror it in UI.
- Reason: UI-only checks can be bypassed; backend guard protects all clients, while UI avoids letting restricted users reach a dead-end create sheet.
- Mapping: Admin override A/B/C1/C2 wins; employee.emp_type 1 maps to B and 0 maps to C1.

## 2026-07-22 11:59:29 - Channel Description And Next Action Intelligence
- Requirement: Add channel description during create/edit, show it in the channel profile panel, and include it in @ai channel context.
- Requirement: Track Next Actions, Next Action Persons, and Next Action Date from channel chat messages and show them in the right-side panel.
- Change: Added xmpp_groups description/next-action schema migration fields and channel profile response fields.
- Change: Added channel update endpoint for owner/admin editable description/type/status/priority/next-action date.
- Change: Added post-send channel action extraction helper for task-like channel messages.
- Verification: PHP syntax checks passed for changed backend files. Dart format passed. Flutter/Dart analyze timed out in this workspace.

## 2026-07-22 16:13:54 - External Group/Channel Create API
- Requirement: External apps/portals must create Flow groups and channels without browser login session cookies.
- Change: Added API-key protected endpoint server_patch/chat/external_create_conversation.php for type=group/channel creation.
- Change: Added docs/external_conversation_create_api.md with Postman-ready request examples.
- Security: Supports Authorization Bearer, X-Skylink-Conversation-Key, X-Skylink-API-Key, and server-side key override via environment/config.
- Verification: PHP syntax check passed for external_create_conversation.php.

## 2026-07-22 16:27:15 - External Reminder/Follow-up Create API
- Requirement: External apps/portals must create Flow reminders and follow-ups without browser login session cookies.
- Change: Added API-key protected endpoint server_patch/chat/external_create_reminder.php for kind=reminder/followup creation.
- Change: Added docs/external_reminder_followup_api.md with Postman-ready request examples.
- Security: Supports Authorization Bearer, X-Skylink-Work-Key, X-Skylink-API-Key, and server-side key override via SKYLINK_WORK_API_KEY.
- Verification: PHP syntax check passed for external_create_reminder.php.

## 2026-07-22 16:46:39 - Channel Right Panel Metadata Visibility
- Requirement: Show channel description, editable details, Next Action, Next Action Persons, and Next Action Date in the right-side panel.
- Root Cause: Some channel/group records arrive in the UI as group previews, so channel-only checks hid metadata and edit controls even when channel profile data existed.
- Change: Updated lib/home/home_screen.dart to load channel profile metadata for group rooms and show channel detail cards whenever channel metadata is returned.
- Change: Added a local right-panel date picker helper and corrected rename dialog scoping after the visibility update.
- Verification: dart format passed. flutter analyze lib/home/home_screen.dart reports no errors; remaining items are existing warnings/infos.
- Build: Not run in this task.

## 2026-07-22 17:13:10 - Channel Right Panel Top Summary Visibility
- Requirement: Right-side panel must immediately show channel Description, Next Action, Next Action Person, and Next Action Date, with edit controls visible in the channel tools area.
- Root Cause: Channel metadata cards were placed below management/member details, so they were not visible in the first right-panel viewport.
- Change: Moved the important channel metadata summary directly below Search/Media in lib/home/home_screen.dart while keeping detailed cards lower in the panel.
- Verification: dart format passed. flutter analyze lib/home/home_screen.dart produced no errors; only existing warnings/infos remain.
- Build: flutter build web --release succeeded. Output: build/web.

## 2026-07-22 17:47:37 - Channel Next Action Detection, Description Profile, Selection Stability
- Requirement: Channel messages like @Ajith_P complete the Chat application task on tomorrow must update Next Action, Next Action Person, and Next Action Date.
- Requirement: Saved channel description must appear in the right-side panel after reload/save.
- Requirement: Selecting message text must not scroll/jump the chat window.
- Change: Relaxed channel detection in server_patch/chat/channel_action_helper.php to support channel-* JIDs and channel-kind records, not only group_type=channel.
- Change: Improved @mention matching for names like Ajith P / Ajith Kumar P using normalized name variants.
- Change: Relaxed channel profile/update endpoints to support channel-* JID records so description and metadata load consistently.
- Change: Removed forced scroll-anchor restore during browser text selection in lib/chat/chat_screen.dart.
- Verification: PHP syntax checks passed for channel_action_helper.php, channel_profile.php, update_channel.php, send_message.php. Flutter analyze on edited Dart files returned no errors, only existing warnings/infos.
- Build: flutter build web --release succeeded. Output: build/web.
