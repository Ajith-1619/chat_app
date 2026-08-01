# Build Report - 2026-08-01 - Next Action Prompt Dedup + Mid-Text Mention Detection
## Summary
Fixed two chat issues:
1. Next-action due prompt/poll now sends only one time for a pending action instead of repeating multiple times.
2. Group/channel @mention suggestions now detect the active mention at the cursor, so mentions typed in the middle of the composer respond faster and correctly.
## Files Changed
- server_patch/chat/next_action_monitor_helpers.php
- lib/chat/chat_screen.dart
## Root Cause
- The next-action monitor resent the due prompt every 30 minutes until a response arrived.
- Mention detection only matched @... at the end of the full composer text, so cursor edits in the middle of the sentence were treated late or missed.
## Implementation
- Changed the due-poll condition to allow only the first send while the action remains unanswered.
- Added a cursor-aware _activeMentionMatch() helper and reused it for mention suggestion visibility and insertion.
## Verification
- php -l server_patch/chat/next_action_monitor_helpers.php passed.
- lutter analyze lib/chat/chat_screen.dart completed with existing warnings only; no new syntax errors remain.
## Risk
Low. Changes are narrow and localized to prompt scheduling plus mention parsing.
## Notes
PROJECT_STATE.md and CHANGE_LEDGER_SPEC.md were not present in the workspace during this update.
