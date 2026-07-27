# Build Report - 2026-07-24 - Web Release After Chat Spinner Fix

## Command
`powershell
flutter build web --release
`

## Result
- Passed.
- Output folder: uild/web

## Included Fixes
- Chat history no longer remains stuck on spinner because stale browser text selection no longer blocks first history render.
- Text selection freeze remains active only during Flow-controlled text-selection windows.

## Notes
- Flutter reported dependency update notices only.
- Wasm dry run succeeded.

## Manual Verification Pending
- Open direct/group/channel chat and confirm history loads.
- Select message text and copy with Ctrl+C.
- Confirm chat scroll and jump-to-latest button behavior.