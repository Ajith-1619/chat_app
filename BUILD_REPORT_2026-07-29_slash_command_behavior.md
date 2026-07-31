# Build Report - Slash Command Behavior

Date: 2026-07-29 16:06:09 +05:30
Status: Complete, no app build requested

## Requirement
Group/channel slash commands must have proper behavior and functions, not just suggestion/help text.

## Changes
- /help continues to open the Flow command guide.
- /ai continues to send as a normal chat message so the backend AI worker can answer when room AI is enabled.
- /reminder opens the reminder creation flow using the command body as the initial content.
- /followup opens the follow-up creation flow using the command body as the initial content.
- /update records current status metadata.
- /decision records decision metadata.
- /meeting records meeting-note metadata.
- /tags stores labels metadata.
- /assign, /action, /followup, /reminder are treated as explicit actionable commands for next-action detection and MCO clarification.

## Verification
- PHP lint passed for conversation_metadata_helper.php and channel_action_helper.php.
- Flutter analyze ran for chat_screen.dart and chat_api.dart; result contains existing warnings/info, with no new syntax/compile error from this change.

## Notes
Manual runtime checks should confirm /reminder, /followup, /ai, /tags, /assign, and /action in a real group/channel.
