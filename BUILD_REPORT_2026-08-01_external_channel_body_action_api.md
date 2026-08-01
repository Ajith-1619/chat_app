# BUILD REPORT - 2026-08-01 - External Channel Body Close API

## Summary
Added a body-based lifecycle fallback for external groups/channels API so close/archive/unarchive/delete can work without path-based lifecycle routes.

## Files Changed
- server_patch/api/_shared/extended.php

## What Changed
- Base POST endpoint now accepts lifecycle actions:
  - close
  - archive
  - unarchive
  - delete
- Target channel/group can be resolved from:
  - channel_id
  - group_id
  - id
  - room_jid
- Close continues to archive the channel and set status to Closed.
- Delete marks the record Deleted and archived.

## Root Cause
Live production was returning Apache 404 for /channels/{id}/close style routes before the PHP handler could execute. A body-based action on the base endpoint avoids that routing dependency.

## Validation
- PHP lint passed for server_patch/api/_shared/extended.php

## Deployment Note
This change works only after the updated server_patch file is deployed to the live server.

## Postman Test
URL:
- POST https://dns.watchtower247.in/router_login/api/channels/v1

Headers:
- Authorization: Bearer <FLOW_API_KEY>
- X-Flow-Actor-Emp-Id: 302
- Content-Type: application/json

Body by numeric ID:
```json
{
  "action": "close",
  "channel_id": 306
}
```

Body by room JID:
```json
{
  "action": "close",
  "room_jid": "channel-lead-example@conference.chat.skylinkonline.net"
}
```

Expected success:
```json
{
  "status": true,
  "channel": {
    "id": 306,
    "action": "close",
    "is_archived": 1,
    "status": "Closed"
  }
}
```