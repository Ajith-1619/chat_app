# Watchtower Flow Build And Release Process

Last updated: 2026-07-14

This document explains how to build Web, Android APK, and Windows installer releases, where artifacts must be saved, how version control should be handled, how builds move to the live server as Draft releases, and how employee `302` approves a build for Production.

## Release Principles

- Every release must have a version in `pubspec.yaml`.
- Every release artifact must be saved in the local `release/` folder.
- Every uploaded artifact must first be registered as `Draft`.
- Draft builds must not become live for all users automatically.
- Production approval is restricted to Ajith, employee ID `302`.
- `chat/version.php` must expose only `ProductionApproved` builds to normal users.
- Never print, paste, or commit server passwords.

## Version Control

The app version is controlled from `pubspec.yaml`.

Current format:

```yaml
version: 2.0.3+26
```

Meaning:

- `2.0.3` is the user-facing version.
- `26` is the build number.
- Android uses this as `versionName = 2.0.3` and `versionCode = 26`.
- Windows uses the version name for product/file version.

Before building a new version:

1. Update `pubspec.yaml`.
2. Increase the build number after `+`.
3. Keep artifact names matching the version.
4. Update release notes/register draft script for the same version.

Example next version:

```yaml
version: 2.0.4+27
```

## Pre-Build Checklist

Run these before creating release artifacts:

```powershell
flutter clean
flutter pub get
flutter analyze
```

Recommended checks:

- Login works.
- Normal text message sends.
- File upload/download works.
- Current/live location renders as in-app map card.
- Message Info shows send/read time and address for allowed users.
- Task list and task detail load.
- Web copy/paste works.
- Android text/file/location send does not mix payload types.
- Windows app opens after install.

## Local Artifact Folder

All final artifacts must be placed here:

```text
release/
```

Current naming pattern:

```text
release/Skylink-Chat-v<version>.apk
release/Skylink-Chat-Web-v<version>.zip
release/Skylink-Chat-Setup-v<version>.exe
```

Example:

```text
release/Skylink-Chat-v2.0.3.apk
release/Skylink-Chat-Web-v2.0.3.zip
release/Skylink-Chat-Setup-v2.0.3.exe
```

Also create SHA256 checksum files:

```text
release/Skylink-Chat-v<version>.apk.sha256
release/Skylink-Chat-Web-v<version>.zip.sha256
release/Skylink-Chat-Setup-v<version>.exe.sha256
```

## Web Build

Build command:

```powershell
flutter build web --release
```

Output folder:

```text
build/web/
```

Package command:

```powershell
Compress-Archive -Path .\build\web\* -DestinationPath .\release\Skylink-Chat-Web-v<version>.zip -Force
```

Checksum:

```powershell
Get-FileHash .\release\Skylink-Chat-Web-v<version>.zip -Algorithm SHA256 | ForEach-Object { $_.Hash } | Set-Content .\release\Skylink-Chat-Web-v<version>.zip.sha256
```

Live server target:

```text
/var/www/html/router_login/downloads/Skylink-Chat-Web-v<version>.zip
```

If deploying the actual web app files, the web app folder is:

```text
/var/www/html/chat/
```

Important:

- Uploading the web ZIP to downloads only makes it available as a draft artifact.
- Replacing `/var/www/html/chat/` changes the live web app immediately, so do that only after approval or explicit instruction.

## Android APK Build

Build command:

```powershell
flutter build apk --release
```

Flutter output:

```text
build/app/outputs/flutter-apk/app-release.apk
```

Copy to release folder:

```powershell
Copy-Item .\build\app\outputs\flutter-apk\app-release.apk .\release\Skylink-Chat-v<version>.apk -Force
```

Checksum:

```powershell
Get-FileHash .\release\Skylink-Chat-v<version>.apk -Algorithm SHA256 | ForEach-Object { $_.Hash } | Set-Content .\release\Skylink-Chat-v<version>.apk.sha256
```

Live server target:

```text
/var/www/html/router_login/downloads/Skylink-Chat-v<version>.apk
```

## Windows Build

Enable Windows desktop if needed:

```powershell
flutter config --enable-windows-desktop
```

Build command:

```powershell
flutter build windows --release
```

Flutter output folder:

```text
build/windows/x64/runner/Release/
```

The project has a packaging helper:

```text
tool/package_windows_installer.ps1
```

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\package_windows_installer.ps1
```

Final installer output:

```text
release/Skylink-Chat-Setup-v<version>.exe
```

Checksum:

```powershell
Get-FileHash .\release\Skylink-Chat-Setup-v<version>.exe -Algorithm SHA256 | ForEach-Object { $_.Hash } | Set-Content .\release\Skylink-Chat-Setup-v<version>.exe.sha256
```

Live server target:

```text
/var/www/html/router_login/downloads/Skylink-Chat-Setup-v<version>.exe
```

Installer behavior:

- Installs to `%LOCALAPPDATA%\Programs\Skylink Chat`.
- Creates Start Menu shortcut.
- Creates Desktop shortcut.
- Starts `skylink_chat.exe` after install.

Important:

- The Windows release must be an `.exe` installer.
- Do not publish Windows ZIP as the user-facing release unless explicitly needed for debugging.

## Server Targets

Live host:

```text
168.144.88.207
```

Public base:

```text
https://dns.watchtower247.in/router_login/
```

API folder:

```text
/var/www/html/router_login/chat/
```

Download artifact folder:

```text
/var/www/html/router_login/downloads/
```

Web app folder:

```text
/var/www/html/chat/
```

Credentials:

- Deployment uses saved FileZilla/SFTP credentials.
- Password is read at runtime from `%APPDATA%\FileZilla\sitemanager.xml`.
- Do not store passwords in code, markdown, scripts, or commits.

## Upload Process

Upload final artifacts to:

```text
/var/www/html/router_login/downloads/
```

Upload these files:

```text
Skylink-Chat-v<version>.apk
Skylink-Chat-v<version>.apk.sha256
Skylink-Chat-Web-v<version>.zip
Skylink-Chat-Web-v<version>.zip.sha256
Skylink-Chat-Setup-v<version>.exe
Skylink-Chat-Setup-v<version>.exe.sha256
```

Public URLs should become:

```text
https://dns.watchtower247.in/router_login/downloads/Skylink-Chat-v<version>.apk
https://dns.watchtower247.in/router_login/downloads/Skylink-Chat-Web-v<version>.zip
https://dns.watchtower247.in/router_login/downloads/Skylink-Chat-Setup-v<version>.exe
```

Verify with browser or HTTP check:

```powershell
Invoke-WebRequest "https://dns.watchtower247.in/router_login/downloads/Skylink-Chat-v<version>.apk" -Method Head
Invoke-WebRequest "https://dns.watchtower247.in/router_login/downloads/Skylink-Chat-Web-v<version>.zip" -Method Head
Invoke-WebRequest "https://dns.watchtower247.in/router_login/downloads/Skylink-Chat-Setup-v<version>.exe" -Method Head
```

Expected:

```text
HTTP 200
```

## Draft Registration

Draft registration writes rows into:

- `xmpp_release_builds`
- `xmpp_release_history`
- `xmpp_release_notes`

Create a version-specific register file:

```text
server_patch/register_draft_<version>.php
```

Example:

```text
server_patch/register_draft_2_0_3.php
```

The register script should insert all platforms as Draft:

- `platform = android`
- `platform = windows`
- `platform = web`
- `version = <version>`
- `build_number = <build_number>`
- `stage = Development`
- `status = Draft`
- `rollout_percent = 0`
- `force_update = 0`
- `uploaded_by_emp_id = 302`

Upload the register script to:

```text
/var/www/html/router_login/register_draft_<version>.php
```

Execute it:

```text
https://dns.watchtower247.in/router_login/register_draft_<version>.php
```

Expected output:

```text
android draft release_id=<id>
windows draft release_id=<id>
web draft release_id=<id>
```

After successful registration, remove or restrict the public register script if it is no longer needed.

## Approval Process

Release management API:

```text
https://dns.watchtower247.in/router_login/chat/releases.php
```

Draft state:

```text
stage = Development
status = Draft
rollout_percent = 0
force_update = 0
```

Available actions:

- `reject_build`
- `deploy_to_testers`
- `deploy_to_pilot_users`
- `approve_for_production`
- `rollback_release`

Production approval:

- Only employee `302` can approve.
- Approval action is `approve_for_production`.
- Approved state becomes:

```text
stage = Production
status = ProductionApproved
rollout_percent = 100
approved_by_emp_id = 302
approved_at = current timestamp
deployed_at = current timestamp
```

When a new Production release is approved:

- Older ProductionApproved builds for the same platform are marked `Superseded`.
- `chat/version.php` starts returning the approved version.
- Users receive update availability based on platform/version response.

Force update:

- `force_update = 1` can be set only during production approval.
- If force update is enabled, `minimum` version becomes the approved version.
- Draft builds must never force-update users.

## Version API

Version endpoint:

```text
https://dns.watchtower247.in/router_login/chat/version.php
```

Rules:

- Reads only `ProductionApproved` builds.
- Requires `stage = Production`.
- Requires `approved_by_emp_id = 302`.
- Drafts are hidden from normal users.

Response contains:

- `android.latest`
- `android.minimum`
- `android.url`
- `android.force_update`
- `windows.latest`
- `windows.minimum`
- `windows.url`
- `windows.force_update`
- `release_governance.production_approver_emp_id`

## Web Live Deployment

There are two different web actions:

### Draft Web Artifact

Upload ZIP to downloads:

```text
/var/www/html/router_login/downloads/Skylink-Chat-Web-v<version>.zip
```

This is safe because it does not replace the live web app.

### Live Web App Replacement

Replace files under:

```text
/var/www/html/chat/
```

Only do this when:

- 302 has approved Production, or
- the user explicitly asks to move the web build live.

Before replacing live web:

- Keep backup of current `/var/www/html/chat/`.
- Upload all files from `build/web/`.
- Verify `https://chat.skylinkonline.net/chat/`.
- Verify login and chat load.

## Rollback Process

Rollback release management:

```text
action = rollback_release
```

Allowed only for employee `302`.

Rollback effects:

- Marks selected build `RolledBack`.
- Sets `force_update = 0`.
- Sets `rollout_percent = 0`.

For web file rollback:

- Restore previous `/var/www/html/chat/` backup.
- Re-check `chat/version.php`.
- Re-check login, message send, and file preview.

## Release Checklist

Before build:

- Version updated in `pubspec.yaml`.
- Build number incremented.
- Release notes prepared.
- Critical bugs fixed or documented.
- `flutter analyze` completed.

After local build:

- APK exists in `release/`.
- Web ZIP exists in `release/`.
- Windows EXE exists in `release/`.
- SHA256 files generated.
- APK opens on Android.
- Windows EXE installs and launches.
- Web ZIP contains `index.html`, `flutter_bootstrap.js`, assets, canvaskit.

After upload:

- Artifact URLs return HTTP 200.
- Draft register script executed.
- Release rows show Draft.
- `chat/version.php` still shows old ProductionApproved version until approval.

After approval:

- `chat/version.php` shows new approved version.
- Users see update according to rollout/force update.
- Old production build is superseded.
- Release history contains approval entry.

## Common Mistakes To Avoid

- Do not upload a Draft web build directly into `/var/www/html/chat/` unless live replacement is intended.
- Do not forget to increment build number.
- Do not register Android, Windows, and Web with mismatched version/build numbers.
- Do not leave `force_update = 1` on Draft builds.
- Do not approve production from any employee other than `302`.
- Do not publish Windows ZIP when user requested installer EXE.
- Do not commit server credentials.
- Do not delete old release artifacts until rollback window is finished.

## Current Known Good Pattern

The latest confirmed draft pattern used:

```text
release/Skylink-Chat-v2.0.3.apk
release/Skylink-Chat-Web-v2.0.3.zip
release/Skylink-Chat-Setup-v2.0.3.exe
```

Server URLs:

```text
https://dns.watchtower247.in/router_login/downloads/Skylink-Chat-v2.0.3.apk
https://dns.watchtower247.in/router_login/downloads/Skylink-Chat-Web-v2.0.3.zip
https://dns.watchtower247.in/router_login/downloads/Skylink-Chat-Setup-v2.0.3.exe
```

Draft registration:

```text
server_patch/register_draft_2_0_3.php
```
