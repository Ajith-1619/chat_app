# BUILD REPORT - 2026-08-01 - Physical Channel Action Endpoint

## Summary
Added direct physical channel lifecycle endpoints that bypass dispatcher/rewrite ambiguity.

## Files Changed
- server_patch/api/channels/v1/action.php
- server_patch/api/channels/v1/close.php

## What Changed
- Added POST/PATCH/DELETE capable action endpoint for channel lifecycle operations.
- Supports JSON body with channel_id, id, or room_jid.
- Supports actions: close, archive, unarchive, delete.
- Added close.php wrapper path for simple close requests.

## Why
Base /api/channels/v1 on live was still returning channel list responses, proving the request was not reaching the intended lifecycle branch reliably.

## Validation
- PHP lint passed for both new endpoint files.

## Live Usage
Preferred:
POST https://dns.watchtower247.in/router_login/api/channels/v1/action.php

Headers:
- Authorization: Bearer <FLOW_API_KEY>
- X-Flow-Actor-Emp-Id: 302
- Content-Type: application/json

Body:
```json
{
  "action": "close",
  "channel_id": 300
}
```

Alternative:
POST https://dns.watchtower247.in/router_login/api/channels/v1/close.php

Body:
```json
{
  "channel_id": 300
}
```

Expected response:
```json
{
  "status": true,
  "channel": {
    "id": 300,
    "action": "close",
    "is_archived": 1,
    "status": "Closed"
  }
}
```