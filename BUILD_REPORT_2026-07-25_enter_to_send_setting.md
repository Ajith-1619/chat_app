# Build Report - Enter To Send User Setting

Date: 2026-07-25

## Request
Add a setting so users can choose whether Enter sends the message or inserts a new line.

## Changed Files
- lib/main.dart
- lib/app/skylink_app.dart
- lib/settings/settings_screens.dart
- lib/chat/chat_screen.dart

## Behavior
- Default: Enter sends message.
- If enabled: Enter sends, Shift+Enter / Ctrl+Enter inserts a new line.
- If disabled: Enter inserts a new line; send button still sends.
- Mobile soft keyboard uses send/newline action based on the setting.

## Verification
- dart format passed.
- flutter analyze on changed Dart files completed with no compile errors.
- Existing warning/info backlog remains in large legacy files.

## Build
- Not run in this turn.

## Manual Checks Pending
- Settings > Appearance > Enter sends message toggle.
- Web/desktop Enter, Shift+Enter, Ctrl+Enter.
- Android APK soft keyboard behavior.