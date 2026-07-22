# Build Report - External Welcome Email - 2026-07-21

## Scope
- Fixed admin external user add/approve flow so welcome email is attempted immediately from the admin app.
- Added admin-local SMTP mailer/config files so admin does not depend only on the background worker path.
- Preserved delivery queue retry behavior by leaving failed email rows queued and recording last_error.

## Validation
- php -l admin/legacy_standalone/api.php passed.
- php -l admin/legacy_standalone/external_mailer.php passed.
- php -l admin/legacy_standalone/external_mail_config.php passed.

## Deployment Note
- Upload api.php, external_mailer.php, and external_mail_config.php into the live admin legacy folder used by the Laravel admin bridge.

