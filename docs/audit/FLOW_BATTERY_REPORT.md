# FLOW_BATTERY_REPORT

Generated: 2026-07-11
Revalidated: 2026-07-11 from current workspace review.

## Battery risk summary

| Severity | Area | Finding | Impact | Fix / Plan |
|---|---|---|---|---|
| High | Home polling | Conversations poll every 15 seconds | Network and CPU wakeups | Reduced hidden load by removing silent history prefetch. Next: pause polling when app backgrounded and use push-triggered refresh |
| High | Chat polling | Open chat polls history every 12 seconds | Network wakeups while idle | Add adaptive polling: fast for first 60s after activity, slow when idle, pause background |
| High | Location tracking | Foreground service saves GPS every minute during punch-in | Battery drain, OS throttling | Keep only while punched in; add distance filter and skip unchanged coordinates |
| Medium | Presence | Presence refresh in open DM every ~60 seconds | Extra API calls | Acceptable short term; batch presence for visible list later |
| Medium | Connectivity check | Punched-in connectivity check every 20 seconds | DNS/network cost | Increase interval after stable online; keep immediate alert on offline |

## Current implementation notes

- Background location service is scoped to attendance punch-in.
- It uses Android foreground service notification.
- GPS off alert exists.
- More battery validation needs real-device testing across Vivo/Motorola/Samsung battery managers.

## Recommended battery tests

- 8-hour punched-in idle test.
- 2-hour active chat test.
- Background/foreground resume test.
- GPS off/on recovery test.
- Network loss recovery test.
