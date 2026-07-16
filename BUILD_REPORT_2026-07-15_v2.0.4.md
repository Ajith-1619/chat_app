# Build Report - 2026-07-15 - v2.0.4

## Summary
- Web and Android APK release builds completed.
- Android APK uploaded to live server downloads and registered as Development/Draft.
- Live rollout remains gated by Employee ID 302 approval.

## Artifacts
- APK: release/Skylink-Chat-v2.0.4.apk
- APK SHA256: release/Skylink-Chat-v2.0.4.apk.sha256
- Web ZIP: release/Skylink-Chat-Web-v2.0.4.zip
- Web ZIP SHA256: release/Skylink-Chat-Web-v2.0.4.zip.sha256

## Server
- Uploaded APK URL: https://dns.watchtower247.in/router_login/downloads/Skylink-Chat-v2.0.4.apk
- Draft registration: android draft release_id=29
- Stage: Development
- Status: Draft
- Rollout: 0%
- Force update: Off

## Verification
- flutter analyze: completed with existing warnings/info; no compile-blocking errors observed.
- flutter build web --release --base-href /chat/: success.
- flutter build apk --release: success.
- APK HEAD check: HTTP 200, content-length 66010233.

## Notes
- Mandatory docs PROJECT_STATE.md and CHANGE_LEDGER_SPEC.md were not present in the workspace during pre-build review.
