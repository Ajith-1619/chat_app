# FLOW_BUG_REGISTER

Generated: 2026-07-11
Revalidated: 2026-07-11 from current workspace review.

| ID | Severity | Area | Issue | Root Cause | Impact | Fix / Plan | Effort |
|---|---|---|---|---|---|---|---|
| BUG-001 | Critical | Messaging API | Web send can fail with `Unknown column location_address` | Live schema marker allowed schema ensure to skip new columns | Messages fail after XMPP send attempt | Source fixed: schema marker bumped and send insert retries after ensuring column. Deploy PHP patch to live. | S |
| BUG-002 | High | Security / Diagnostics | Advanced diagnostics visible to `218` although requested only `116/302` | Client/server allow-list had `218` | Sensitive latency/device traces exposed to extra user | Fixed in `lib/chat_api.dart` and `server_patch/chat/bootstrap.php` | S |
| BUG-003 | High | Performance | Home poll prefetches many histories repeatedly | `_loadChats(silent: true)` triggered `prefetchHistories` for all recent chats | Excess API calls, slower app, higher battery/network use | Fixed: prefetch only top 3 and only on non-silent load | S |
| BUG-004 | High | Groups | Group member sheet slow/no response on large groups | Per-member employee/avatar/presence queries | Slow manage group/channel screen | Fixed: bulk employee, avatar and presence loading | M |
| BUG-005 | High | Groups/Channels | Some groups/channels missing from list | API returned only 20 and sorted by creation time | Active old groups/channels disappear | Fixed: higher limits and sort by latest activity | S |
| BUG-006 | Medium | Presence | Last seen can show “recently” when presence fallback has no timestamp | Presence depends on heartbeat/app sessions and may be stale | User confusion | Add periodic server-side reconciliation from sessions/messages and expose exact source | M |
| BUG-007 | Medium | Notifications | Push failures are logged but not surfaced in a health dashboard | Firebase dispatch is best-effort with limited delivery telemetry | Hard to debug missed notifications | Add notification trace rows by recipient and token status | M |
| BUG-008 | Medium | Attachments | Browser CORS can block historical media from old upload host | Mixed asset hosts without consistent CORS headers | Images/files may not preview on web | Normalize upload URLs through same domain/proxy or set CORS headers on old host | M |
| BUG-009 | Medium | Attendance | Offline tracking depends on foreground service and per-minute GPS | Battery/device permission sensitivity | Location records may stop if OS kills service | Add device whitelist guide and battery mode test suite | M |
| BUG-010 | Low | UI | Some MyHub flows use simple forms instead of Launchpad-polished UI | Stabilization pass prioritized reliability | Usable but not final UX | Improve UX after reliability baseline | M |
