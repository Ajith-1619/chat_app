# Build Report - 2026-08-08

## Scope
- Workspace sub-filter simplified to `All`.
- My Hub icon rendering made explicit and stable.
- Attachment caption editing added for sent non-location files/images.
- Leave OTP notification recipient changed to employee 232 and notification now includes employee name and reason.
- Existing custom folder reorder flow retained.

## Verification
- `flutter analyze --no-pub --no-fatal-infos --no-fatal-warnings lib/chat_api.dart lib/chat/chat_screen.dart lib/home/home_screen.dart` passed with existing warnings/infos only; no errors.
- `C:\xampp\php\php.exe -l server_patch/chat/myhub.php` passed.
- `flutter build web --release` passed.

## Output
- `build/web`

## Deployment
- No server deployment performed in this turn.
