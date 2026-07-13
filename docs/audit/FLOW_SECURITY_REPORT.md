# FLOW_SECURITY_REPORT

Generated: 2026-07-11
Revalidated: 2026-07-11 from current workspace review.

## Findings

| Severity | Area | Issue | Root Cause | Fix / Plan |
|---|---|---|---|---|
| High | Diagnostics privacy | `218` had access to advanced diagnostics | Allow-list mismatch | Fixed: now only `116` and `302` |
| High | Location privacy | Location data can be sensitive | Feature intentionally stores lat/long/address | Keep visibility toggle default off; only enabled users see address/lat/long |
| Medium | API auth | APIs rely on PHP session cookie/web session header | Web deployments need strict cookie/CORS | Current CORS allow-list is explicit; deploy only over HTTPS for secure cookies |
| Medium | File URLs | Historical files may expose direct upload host | Public object URLs | Prefer signed/proxied downloads for confidential files |
| Medium | Release governance | Draft builds must not reach users | Process relies on release status | Current release code requires 302 for production approval |

## Access control confirmed in source

- Diagnostics client menu: `ChatApi.diagnosticEmployeeIds = {'116', '302'}`
- Diagnostics API traces: `SKYCHAT_DIAGNOSTIC_USERS = [116, 302]`
- Release production approval: employee `302`
- Location visibility defaults: `116` and `302` enabled, others off
