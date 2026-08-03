# Build Report - Message Edit Instant Refresh

Date: 2026-08-03 23:59:00 +05:30

## Requirement
When a message is edited, the changed text must update immediately in the currently open chat without forcing the user to leave and reopen the conversation.

## Files Changed
- lib/chat/chat_screen.dart

## Root Cause
The edit flows were trying to update the visible message list with `_messages.indexOf(message)`. That only works while the exact same `ChatMessage` instance is still present in `_messages`. If the list has been rebuilt or refreshed while the edit dialog is open, that identity lookup fails, so the backend edit succeeds but the visible bubble stays stale until the chat reloads.

## Fix
- Added `_replaceMessageById(...)` helper.
- Switched normal message edit, checklist edit, and poll edit flows to replace messages by stable `message.id`.
- Preserved all other message fields from the current in-list model while updating text / edited state.

## Verification
- `flutter analyze lib/chat/chat_screen.dart`
  - Result: no new build-blocking errors from this patch.
  - Note: analyzer still reports pre-existing warnings/info items already present in `chat_screen.dart`.
