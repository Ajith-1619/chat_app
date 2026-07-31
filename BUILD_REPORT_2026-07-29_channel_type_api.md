# Build Report - Channel Type API Preservation

Date: 2026-07-29 15:37:44 +05:30
Status: Complete, no Flutter/web build requested

## Requirement
External API channel creation/update must respect the provided channel type. Example: channel_type: "task" must create a task/workspace channel, not an operational channel.

## Root Cause
- server_patch/api/_shared/bootstrap.php ignored channel_type and only read channel_kind/kind.
- Chat channel create paths fell back to operational when no matching channel definition existed.
- server_patch/chat/update_channel.php allowed only a hardcoded list of channel kinds, so custom types could be lost on edit.

## Fix
- Accepted channel_type as the preferred field and kept channel_kind, 	ype_key, and kind as aliases.
- Normalized custom channel types safely instead of forcing them to operational.
- Preserved unknown/custom channel types so the Flutter Workspace filter can classify them outside the core Channels tab.
- Updated external API documentation.

## Verification
- php -l server_patch/api/_shared/bootstrap.php passed.
- php -l server_patch/chat/create_channel.php passed.
- php -l server_patch/chat/external_create_conversation.php passed.
- php -l server_patch/chat/update_channel.php passed.

## Deployment Note
Deploy the updated server_patch/api/_shared/bootstrap.php into the live /router_login/api/_shared/bootstrap.php path and the chat PHP files into /router_login/chat/ equivalents.
