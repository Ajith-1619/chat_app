# Build Report - v2.0.6 Web/APK And Android Draft

Date: 2026-07-25

## Version
- Previous: 2.0.5+28
- New: 2.0.6+29

## Commands
- flutter analyze .\\lib\\main.dart
- flutter build web --release --base-href /chat/
- flutter build apk --release

## Build Results
- Analyze: Passed, no issues in main.dart.
- Web build: Passed, output build/web.
- APK build: Passed, output build/app/outputs/flutter-apk/app-release.apk.

## Local Artifacts
- release/Skylink-Chat-v2.0.6.apk
- release/Skylink-Chat-v2.0.6.apk.sha256
- release/Skylink-Chat-Web-v2.0.6.zip
- release/Skylink-Chat-Web-v2.0.6.zip.sha256
- server_patch/register_draft_2_0_6.php

## Checksums
- APK SHA256: 909109EFF3D156CF29B0FC7F9D4965F7E52649F065F8D5A5D9E61EA03AFA4CFF
- Web ZIP SHA256: 0D7522C2791BE94D2D8E3CB5B024B936C1AAA3B9C47573EF1CA7D7AB0CA7919F

## Live Draft Deployment
- Uploaded APK: https://dns.watchtower247.in/router_login/downloads/Skylink-Chat-v2.0.6.apk
- Uploaded APK checksum: https://dns.watchtower247.in/router_login/downloads/Skylink-Chat-v2.0.6.apk.sha256
- Uploaded register script: /var/www/html/router_login/register_draft_2_0_6.php
- Live APK HEAD check: HTTP 200, Content-Length 66551717
- Draft registration result: android draft release_id=34

## Approval State
- stage: Development
- status: Draft
- rollout_percent: 0
- force_update: 0
- Approval required: Employee ID 302

## Notes
- Web build was created and packaged locally; live web app files were not replaced.
- APK is staged on live server as a Draft only. It will not go live for users until 302 approves it.