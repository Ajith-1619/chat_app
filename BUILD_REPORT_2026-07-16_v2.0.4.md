# Build Report - v2.0.4 Multi-Platform Draft

Date: 2026-07-16 13:20:24
Version: 2.0.4+27

## Local Builds
- Web: build/web, packaged as release/Skylink-Chat-Web-v2.0.4.zip
- Android APK: release/Skylink-Chat-v2.0.4.apk
- Windows installer: release/Skylink-Chat-Setup-v2.0.4.exe

## SHA256
- APK: E9318BF6E490C0BB074CBA3ED5BE3BE2E38EB39AACCC542BACBD29E549216AAD
- Web ZIP: 0DD5471E1C0D9434CF60F6FE2DD3A225F28B2A0084D1A14F89A485BE992CEE24
- Windows EXE: 468A9A92F2E3B8652DAA61263ED92EBB670B198E9A51D0EAD12BB41366759922

## Live Draft Uploads
- https://dns.watchtower247.in/router_login/downloads/Skylink-Chat-v2.0.4.apk
- https://dns.watchtower247.in/router_login/downloads/Skylink-Chat-Setup-v2.0.4.exe
- https://dns.watchtower247.in/router_login/downloads/Skylink-Chat-Web-v2.0.4.zip

## Draft Registration
- Android draft release_id=29
- Windows draft release_id=31
- Web draft release_id=32
- Stage: Development
- Status: Draft
- Rollout: 0%
- Force update: disabled
- Production approval required from employee 302.

## Verification
- PHP lint passed for changed server release/register and recent chat PHP files.
- flutter analyze completed with existing repo warnings/infos; no blocking build error was reported.
- flutter build web --release --base-href /chat/ succeeded.
- flutter build apk --release succeeded.
- flutter build windows --release succeeded.
- Windows installer packaged and final size verified at 14,951,424 bytes.
- Live HEAD checks returned HTTP 200 for all artifacts and checksum files.

## Notes
- First APK build attempt timed out; second longer run succeeded.
- package_windows_installer.ps1 was hardened to wait for a stable IExpress output before copying, preventing incomplete installer stubs.
