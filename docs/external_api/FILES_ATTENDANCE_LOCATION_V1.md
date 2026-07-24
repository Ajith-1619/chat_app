# Files, Attendance, Location API v1

Date: 2026-07-24

## Files Base

```text
/api/files/v1
```

| Method | Path | Scope | Description |
| --- | --- | --- | --- |
| POST | `/files` | `files:write` | Upload file |
| GET | `/files/{file_id}` | `files:read` | File metadata |
| GET | `/files/{file_id}/download` | `files:read` | Download if unrestricted |
| GET | `/storage/me` | `files:read` | Actor storage usage |
| GET | `/storage/users/{emp_id}` | `files:read` | User storage usage |
| PATCH | `/storage/users/{emp_id}/limit` | `files:write` | Set storage limit |

Rules:

- Restricted files cannot be downloaded externally.
- Unrestricted files can return download URL or bytes.
- File uploads should support idempotency.

## Attendance Base

```text
/api/attendance/v1
```

| Method | Path | Scope | Description |
| --- | --- | --- | --- |
| GET | `/me` | `attendance:read` | Actor attendance status |
| GET | `/users/{emp_id}` | `attendance:read` | User attendance status |
| GET | `/users/{emp_id}/month` | `attendance:read` | Monthly report |
| POST | `/punch-in` | `attendance:write` | Punch in, optional for v1 |
| POST | `/punch-out` | `attendance:write` | Punch out, optional for v1 |

Recommendation:

- Keep punch APIs disabled for external systems until admin approval.
- Start with read-only attendance APIs.

## Location Base

```text
/api/location/v1
```

| Method | Path | Scope | Description |
| --- | --- | --- | --- |
| POST | `/locations` | `location:write` | Save device/location metadata |
| GET | `/users/{emp_id}/latest` | `location:read` | Latest allowed location |
| GET | `/users/{emp_id}/timeline` | `location:read` | Today timeline |
| GET | `/reverse-geocode` | `location:read` | Lat/lon to address |
| GET | `/visibility` | `location:read` | Visibility policy |
| PATCH | `/visibility` | `location:write` | Update visibility policy |

Rules:

- Normal send/read lat-long is metadata only.
- Current/live location must be explicit map-card message only.
- Visibility policies must be enforced for users, groups, channels, and admin role.

