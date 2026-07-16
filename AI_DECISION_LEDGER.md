
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
