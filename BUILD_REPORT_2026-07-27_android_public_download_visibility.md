# Build Report - 2026-07-27 - Android Public Download Visibility

## Scope
- Android attachment and saved-message download visibility fix.

## Files Changed
- android/app/src/main/AndroidManifest.xml
- android/app/src/main/kotlin/com/skylink/slync/MainActivity.kt
- lib/chat_api.dart
- lib/app/skylink_app.dart
- lib/home/home_screen.dart

## What Changed
- Added native Android public-save support on the existing skylink/android_settings channel.
- Downloads now route by type:
  - images -> Pictures/Skylink
  - videos -> Movies/Skylink
  - audio -> Music/Skylink
  - other files -> Downloads/Skylink
- Saved-message download now requests the same shared storage flow before saving.
- Legacy storage permission messaging now applies only to older Android versions where it is still relevant.

## Verification
- dart format .\lib\chat_api.dart .\lib\home\home_screen.dart .\lib\app\skylink_app.dart passed.
- lutter analyze .\lib\chat_api.dart .\lib\home\home_screen.dart .\lib\app\skylink_app.dart completed with no new compile errors; existing repo warning backlog remains.
- lutter build apk --debug timed out locally.
- ndroid\\gradlew.bat app:compileDebugKotlin could not run locally because JAVA_HOME/java is not configured on this machine.

## Manual Check Pending
- Android image download should appear in Gallery / Pictures / Skylink.
- Android document download should appear in Files / Downloads / Skylink.
- Saved-message download should use the same visible public save path.
