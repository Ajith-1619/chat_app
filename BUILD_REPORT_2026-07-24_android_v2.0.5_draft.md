# Build Report - 2026-07-24 - Android Draft v2.0.5+28

## Scope
- Build Android APK for the next version.
- Upload APK to live server downloads folder.
- Register release as Draft for employee 302 approval.

## Version
- Previous: 2.0.4+27
- New: 2.0.5+28

## Commands
`powershell
flutter build apk --release
`

## Local Artifacts
- release/Skylink-Chat-v2.0.5.apk
- release/Skylink-Chat-v2.0.5.apk.sha256
- server_patch/register_draft_2_0_5.php

## Verification
- APK build: Passed.
- PHP syntax: Passed for register_draft_2_0_5.php.
- Upload: Passed.
- Live APK HEAD check: HTTP 200, 66,371,349 bytes.
- Draft registration: android draft release_id=33.

## SHA256
5F687D21B339FE53B1390A9D61158B81C5DF927243B2991BF95162D6BD5BED09

## Approval State
- stage: Development
- status: Draft
- rollout_percent: 0
- force_update: 0
- Approval required: Employee ID 302
