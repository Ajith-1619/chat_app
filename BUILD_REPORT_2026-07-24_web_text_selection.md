# Build Report - 2026-07-24 - Web Release

## Scope
- Web release build after chat message text selection fix.

## Command
`powershell
flutter build web --release
`

## Result
- Passed.
- Output folder: uild/web

## Notes
- Flutter dependency notices shown only; no build failure.
- Wasm dry run succeeded.

## Manual Verification Pending
- Chrome web: drag-select chat message text, Ctrl+C paste.
- Confirm jump-to-latest button appears when viewing older messages and scrolls to latest.
- Confirm message action menu, attachments, Read more and scrolling still work.