# Build Report - 2026-07-28 - Web Build After Slash Help And Horizon Updates

## Scope
- Built Flutter web release for the current app state.
- Includes group/channel /help command guide changes.
- Includes Horizon map zoom UI and recent Horizon map/address updates.

## Command
```powershell
flutter build web --release --base-href /chat/
```

## Result
- Status: Success
- Output: build/web

## Notes
- Flutter reported dependency update notices.
- Material and Cupertino icons were tree-shaken.
- Wasm dry run succeeded suggestion was printed by Flutter.

## Deployment Notes
- Deploy build/web to the live web app folder when ready.
- For Horizon reporting_to backend behavior, deploy server_patch/chat/myhub.php to live router_login/chat/myhub.php.
