# Build Report - 2026-07-24 - Chat Text Selection Root Fix

## Scope
- Fixed web/desktop chat message text selection without blocking chat scroll.
- Refreshed Flutter web release artifacts.

## Changed File
- lib/chat/chat_screen.dart

## Verification
- dart format .\lib\chat\chat_screen.dart: Passed.
- flutter analyze .\lib\chat\chat_screen.dart: Completed with existing warnings/info only; no compile errors.
- flutter build web --release: Passed.

## Output
- build/web

## Manual Check
- Select message text in Chrome by dragging across sent/received text bubbles.
- Ctrl+C and paste selected text.
- Scroll chat before/after selection.
- Right-click message action menu.
