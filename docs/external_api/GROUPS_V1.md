# Groups API v1

Base:

```text
/api/groups/v1
```

## Endpoints

| Method | Path | Scope | Description |
| --- | --- | --- | --- |
| GET | `/groups` | `groups:read` | List groups visible to actor |
| POST | `/groups` | `groups:write` | Create group |
| GET | `/groups/{group_id}` | `groups:read` | Group profile |
| PATCH | `/groups/{group_id}` | `groups:write` | Rename/update group |
| DELETE | `/groups/{group_id}` | `groups:write` | Delete/archive group |
| GET | `/groups/{group_id}/members` | `groups:read` | Member list |
| POST | `/groups/{group_id}/members` | `groups:write` | Add members |
| DELETE | `/groups/{group_id}/members/{emp_id}` | `groups:write` | Remove member |
| PATCH | `/groups/{group_id}/members/{emp_id}/role` | `groups:write` | Promote/demote admin |
| POST | `/groups/{group_id}/external-users/request` | `groups:write` | Request external user addition |
| GET | `/groups/{group_id}/wake-up` | `groups:read` | Wake-up configuration |
| PATCH | `/groups/{group_id}/wake-up` | `groups:write` | Update wake-up configuration |

## Create Group

```http
POST /api/groups/v1/groups
```

```json
{
  "name": "Network Support",
  "member_emp_ids": [302, 116],
  "allow_empty_group": true,
  "wakeup_enabled": false
}
```

Rules:

- Creator is always included.
- `C1` and `C2` users cannot create groups.
- Admin/owner can add/remove members.
- When adding new users, API should support `history_access: "new_only" | "full_history"`.

