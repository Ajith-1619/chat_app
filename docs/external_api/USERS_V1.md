# Users API v1

Base:

```text
/api/users/v1
```

## Endpoints

| Method | Path | Scope | Description |
| --- | --- | --- | --- |
| GET | `/users` | `users:read` | Search/list active employees |
| GET | `/users/{emp_id}` | `users:read` | Employee profile |
| PATCH | `/users/{emp_id}` | `users:write` | Update allowed user fields |
| GET | `/users/{emp_id}/presence` | `users:read` | Online/last seen |
| GET | `/users/{emp_id}/sessions` | `users:read` | Active device sessions |
| GET | `/users/{emp_id}/storage` | `files:read` | User storage usage |
| PATCH | `/users/{emp_id}/storage-limit` | `files:write` | Set per-user storage limit |
| GET | `/users/{emp_id}/groups` | `groups:read` | User group/channel memberships |
| GET | `/users/{emp_id}/tasks` | `tasks:read` | Tasks created/assigned/followed by user |

## Search Users

```http
GET /api/users/v1/users?search=ajith&limit=50
```

Response:

```json
{
  "status": true,
  "data": {
    "users": [
      {
        "emp_id": 302,
        "name": "Ajith Kumar P",
        "designation": "Splicer",
        "jid": "302@chat.skylinkonline.net",
        "status": "active"
      }
    ]
  },
  "request_id": "req_..."
}
```

## User Type

Flow supports employee types:

```text
A
B
C1
C2
```

External APIs should enforce:

- `A`, `B`: AI/API access allowed based on admin rules.
- `C1`, `C2`: no group/channel creation permission.

