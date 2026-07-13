# AGENTS.md

## Project

Skylink / Watchtower Flow chat application.

This is a Flutter multi-platform app with PHP backend patches in `server_patch/`.
Primary user-facing targets are Web, Android APK, Windows, and Linux.

## Main Paths

- Flutter app entry: `lib/main.dart`
- API client: `lib/chat_api.dart`
- MyHub tasks UI: `lib/myhub_tasks_screen.dart`
- Flow registry: `lib/flow_registry.dart`
- PHP backend patches: `server_patch/chat/`
- Release artifacts: `release/`
- Web build output: `build/web`
- Android APK output: `build/app/outputs/flutter-apk/app-release.apk`
- Today requirements tracker: `FLOW_TODAY_REQUIREMENTS.txt`
- Live deploy notes: `docs/live_deploy_process.md`

## Build Commands

Use PowerShell on Windows.

```powershell
flutter analyze .\lib\main.dart
flutter build web --release --base-href /chat/
flutter build apk --release
```

Web output is `build\web`.

APK output is `build\app\outputs\flutter-apk\app-release.apk`.

## Versioning

Version is controlled in `pubspec.yaml`.

Example:

```yaml
version: 2.0.1+24
```

For a new release, bump both:

- `versionName`: first part, for example `2.0.2`
- `versionCode`: build number after `+`, for example `25`

## Live Server

Live host:

- SSH/SFTP host: `168.144.88.207`
- User: `root`
- Public base URL: `https://dns.watchtower247.in/router_login/`
- API folder: `/var/www/html/router_login/chat/`
- Download folder: `/var/www/html/router_login/downloads/`
- Web app folder: `/var/www/html/chat/`

Do not print or commit passwords.

Saved FileZilla credentials are in:

```text
%APPDATA%\FileZilla\sitemanager.xml
```

Important: when reading the FileZilla password XML node, use `Pass.InnerText`, then base64 decode when `encoding="base64"`.

## Release Management Flow

For APK draft release:

1. Build APK.
2. Copy APK into `release/` with a versioned name.
3. Generate SHA256 file.
4. Upload APK and SHA256 to `/var/www/html/router_login/downloads/`.
5. Upload `server_patch/register_draft_<version>.php` to `/var/www/html/router_login/`.
6. Open the register URL, for example:

```text
https://dns.watchtower247.in/router_login/register_draft_2_0_1.php
```

Draft release should show:

- `stage = Development`
- `status = Draft`
- `rollout_percent = 0`
- `force_update = 0`

Only Ajith / employee `302` approval should move a release live.

## Recent Release Notes

Latest Android draft prepared:

- Version: `2.0.1+24`
- APK: `release/Skylink-Chat-v2.0.1.apk`
- Live URL: `https://dns.watchtower247.in/router_login/downloads/Skylink-Chat-v2.0.1.apk`
- Draft release id: `22`

## Task / MyHub Rules

The live `task_master` table is legacy-shaped. Visible columns include:

- `id`
- `title`
- `priority`
- `emp_id`
- `task_followers`
- `task_groups`
- `task_type`
- `deadline`
- `description`
- `created_by`
- `meet_type`
- `status`
- `created_at`
- `updated_at`
- `next_followup_date`
- `vertical`

Task create must save more than title and description. Backend defaults should fill:

- `priority = medium`
- `emp_id = assignee or current user`
- `task_followers = followers or current user`
- `task_groups = group id or 99`
- `task_type = general`
- `meet_type = 1`
- `status = 2`
- `created_by = current employee`
- `next_followup_date = ''`
- `vertical = general`
- timestamps when available

Legacy status note:

- `status = 2` is treated as open/active in this project.
- Closed statuses are treated as `3`, `4`, or `5`.

MyHub task list should include tasks where the current user is:

- assignee in `emp_id`
- creator in `created_by`
- follower in `task_followers` or `followed_by`

UI filters should include:

- All
- Open
- Request close
- Closed
- Created by me
- Following
- Due today
- Overdue
- Stale

## Chat / Location Rules

Normal text messages must not attach GPS metadata.

Current location and live location must be sent only through explicit attachment actions.

Location messages should render as map cards with a map image and pin, not as file attachments.

## File / Attachment Rules

The app must support common file types including:

- images
- PDF
- TXT
- CSV
- XLSX
- DOC / DOCX
- HTML / PHP
- APK

Default file click should open the in-app preview where possible.

## Development Notes

- Prefer small, targeted changes.
- Do not revert user changes.
- Use existing app patterns before adding new abstractions.
- Keep `FLOW_TODAY_REQUIREMENTS.txt` updated when requirements are completed.
- Run PHP syntax checks for changed PHP files:

```powershell
& 'C:\xampp\php\php.exe' -l .\server_patch\chat\myhub.php
```

- Run Flutter analyzer after Dart changes. Existing warnings may remain, but do not introduce new errors.

## Known Analyzer Warnings

The repo currently has old warnings/info such as:

- unused `_InfoPill`
- unused `_editImageBeforeSend`
- unused `_leaveGroup`
- unused `_friendlyChannelType`
- some deprecated `withOpacity`
- style-only interpolation warnings

Do not treat these as blockers unless working in those areas.
