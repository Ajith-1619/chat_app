# Deploy Report - Flow v2.0.8+31 Draft

Date: 2026-07-30
Request: Move next-version Web/APK build to live server and keep it as Draft for employee 302 approval.

## Uploaded Artifacts
- /var/www/html/router_login/downloads/Skylink-Chat-v2.0.8.apk
- /var/www/html/router_login/downloads/Skylink-Chat-v2.0.8.apk.sha256
- /var/www/html/router_login/downloads/Skylink-Chat-Web-v2.0.8.zip
- /var/www/html/router_login/downloads/Skylink-Chat-Web-v2.0.8.zip.sha256
- /var/www/html/router_login/register_draft_2_0_8.php

## Draft Registration
- Executed: https://dns.watchtower247.in/router_login/register_draft_2_0_8.php
- Result: ndroid draft release_id=37
- Stage: Development
- Status: Draft
- Rollout: 0%
- Force update: disabled
- Approval required: Employee ID 302

## Verification
- APK URL returned HTTP 200 with content length 67176597.
- Web ZIP URL returned HTTP 200 with content length 11385356.
- chat/version.php still shows Android production approved version 2.0.6, so the draft is not live for normal users yet.

## Notes
- Passwords were read from local FileZilla credentials at runtime and were not printed or committed.
- PROJECT_STATE.md and CHANGE_LEDGER_SPEC.md are missing from the workspace.