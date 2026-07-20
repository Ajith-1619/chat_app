# Build Report - External Users - 2026-07-20

Status: Implemented, build not run.

Changes:
- Added standalone admin external user management for group/channel detail screens.
- Added external contact, group external membership, and external delivery queue schema creation.
- Added welcome message queueing when an external user is added.
- Added mention-only delivery queueing from chat send flow.

Validation:
- php -l admin/legacy_standalone/api.php: pass
- php -l server_patch/chat/bootstrap.php: pass
- php -l server_patch/chat/send_message.php: pass
- node --check admin/public/admin/app.js: pass

Notes:
- External users are not Flow app users and do not receive normal group/channel messages.
- Outbound channel workers for email, WhatsApp, Telegram and SMS remain gateway integration work; records are queued in xmpp_external_delivery_queue.
