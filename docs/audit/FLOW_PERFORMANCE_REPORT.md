# FLOW_PERFORMANCE_REPORT

Generated: 2026-07-11
Revalidated: 2026-07-11 from current workspace review.

## Targets

- Screen load: under 500 ms
- API calls: under 300 ms
- Message delivery: under 500 ms
- Push notification: under 2 seconds

## Findings

| Severity | Flow | Finding | Root Cause | Fix / Plan |
|---|---|---|---|---|
| High | Home conversations | Excess background API calls every 15 seconds | History prefetch ran after every recent chat poll | Fixed: prefetch limited to first 3 conversations and only initial/manual load |
| High | Group members | Slow group member sheet | N+1 queries for presence/avatar per member | Fixed: bulk queries |
| High | Recent chats | Missing/slow group/channel list | Limits too low and groups sorted by creation date | Fixed: larger limits and latest activity sort |
| Medium | Search users | Prior diagnostics showed `search_users.php` can exceed 15s | Employee table search is broad and returns 500 rows | Add indexed normalized search table or min query length + pagination |
| Medium | History | Large conversations load only latest 100/200, no cursor pagination | Fixed limits prevent huge payloads but block older lazy load | Add cursor pagination `before_id` and lazy prepend |
| Medium | Push | Notification dispatch can take >2s | Firebase sends serially per token | Batch/concurrent token dispatch with per-token result recording |

## Index improvements added

Added best-effort indexes in `chat_ensure_schema()`:

- `idx_xmpp_messages_to_id_deleted`
- `idx_xmpp_messages_from_to_id`
- `idx_xmpp_messages_created_id`
- `idx_xmpp_group_members_emp_group`
- `idx_xmpp_groups_archived_type_created`
- `idx_xmpp_user_presence_seen`

These are wrapped in `try/catch` so existing live schemas do not break.
