# Skylink Chat live deploy process

This project previously deployed release artifacts to the live server using the
saved FileZilla SFTP site credentials and `scp`.

Do not print or commit deployment passwords.

## Live target

- SSH/SFTP host: `168.144.88.207`
- SSH/SFTP user: `root`
- Public domain: `https://dns.watchtower247.in/router_login/`
- API folder: `/var/www/html/router_login/chat/`
- Download folder: `/var/www/html/router_login/downloads/`
- Web app folder: `/var/www/html/chat/`

## Credential source

The deploy password is read at runtime from:

`%APPDATA%\FileZilla\sitemanager.xml`

The helper `.deploy_askpass.cmd` reads the password from the
`SKYLINK_DEPLOY_PASSWORD` environment variable. The password is not written to
the repository.

## Draft release flow

1. Build local artifacts.
2. Upload API patches and artifacts to the live server.
3. Upload `server_patch/register_draft_<version>.php`.
4. Execute `https://dns.watchtower247.in/router_login/register_draft_<version>.php`.
5. Verify `chat/releases.php` as employee `302`; the build must show:
   - `stage = Development`
   - `status = Draft`
   - `rollout_percent = 0`
   - `force_update = 0`
6. Public `chat/version.php` must continue showing only `ProductionApproved`
   versions until Ajith (`302`) approves production.

## v1.4.2 confirmation

- Android draft release id: `10`
- Windows draft release id: `11`
- Web draft release id: `12`
