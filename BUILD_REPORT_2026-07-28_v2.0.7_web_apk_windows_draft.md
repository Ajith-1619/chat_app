# Build Report - 2026-07-28 - v2.0.7 Web/APK/Windows Draft

## Summary
Generated Flow Messenger v2.0.7+30 release artifacts for Web, Android APK, and Windows installer. Uploaded artifacts to the live server downloads folder and registered Android/Windows as Draft releases for Employee 302 approval.

## Artifacts
- Web ZIP: release/Skylink-Chat-Web-v2.0.7.zip
  - SHA256: E2C84A80C3F42151425B3171A01C0154AF7641A01DE35BC0B7D7DEA6E6CA7192
- Android APK: release/Skylink-Chat-v2.0.7.apk
  - SHA256: 85A9748D326B471B3D56F1F52D41D3B7FCBE9ED10ECE2494741E3F238E1A8DCD
- Windows installer: release/Skylink-Chat-Setup-v2.0.7.exe
  - SHA256: 9C50E146F228DA732589C98CB5EE2D417810A37B3ECBF8BFAFC20F4F7C7666AB

## Server Draft
- Upload path: /var/www/html/router_login/downloads
- Draft register script: /var/www/html/router_login/register_draft_2_0_7.php
- Register endpoint result: HTTP 200
- Android draft release_id: 35
- Windows draft release_id: 36
- Approval gate: Employee ID 302 in Release Management.

## Verification
- PHP lint: server_patch/register_draft_2_0_7.php passed.
- Flutter web build: passed.
- Flutter APK release build: passed.
- Flutter Windows release build: passed.
- Windows installer package: passed.

## Notes
- Targeted flutter analyze completed with existing warnings/info in chat_screen.dart, but no blocking compile errors. Release builds completed successfully.
- Web ZIP was uploaded as a draft artifact only; live web app folder was not overwritten.
