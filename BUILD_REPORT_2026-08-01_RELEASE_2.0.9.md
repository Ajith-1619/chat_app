# BUILD REPORT - 2026-08-01 - RELEASE 2.0.9

## Summary
- Built Flow Web release artifact for version 2.0.9.
- Built Flow Android release APK for version 2.0.9.
- Uploaded the Android APK draft artifact to the live server.
- Registered Android draft release id 38 for employee 302 approval.

## Artifacts
- `release/Skylink-Chat-Web-v2.0.9.zip`
- `release/Skylink-Chat-Web-v2.0.9.zip.sha256`
- `release/Skylink-Chat-v2.0.9.apk`
- `release/Skylink-Chat-v2.0.9.apk.sha256`

## Validation
- `flutter analyze` completed with pre-existing warnings only.
- `php -l server_patch/chat/SystemNotification.php`
- `php -l server_patch/chat/myhub.php`
- `php -l server_patch/register_draft_2_0_9.php`
- `flutter build web --release`
- `flutter build apk --release`

## Live Draft
- Uploaded to: `/var/www/html/router_login/downloads/Skylink-Chat-v2.0.9.apk`
- Registration URL: `https://dns.watchtower247.in/router_login/register_draft_2_0_9.php`
- Result: `android draft release_id=38`

## Approval
- Employee `302` can now approve the Android draft through Release Management.
- Until approval, public production users should continue seeing only production-approved versions.