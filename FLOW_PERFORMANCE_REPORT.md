# FLOW_PERFORMANCE_REPORT

Date: 2026-07-25
Scope: Chat API latency, app polling, message-send response path, diagnostics overhead.

## Findings

### Critical: send_message_total can become slow when post-send work runs synchronously
- Observed risk: send_message.php returns quickly only when fastcgi_finish_request() exists. On Apache/mod_php or environments without FastCGI finish support, post-send AI reply, push queue setup, and worker spawning can sit in the user-facing response path.
- Impact: Text sends can feel stuck for 5-6 seconds and may show timeout errors on Android under weak network.
- Fix applied: AI room replies are now moved to a separate CLI worker trigger (ai_room_worker.php) instead of calling the AI provider inside the send response path.

### High: Android history prefetch can create burst network load
- Observed risk: Home refresh prefetches up to 12 histories after recent_chats. This is helpful for warm cache, but it can create large bursts on mobile when many chats have last messages.
- Impact: Background network contention can slow active chat, recent list refresh, and battery.
- Fix applied: prefetch now runs at most once every 2 minutes, skips in-flight histories, and limits each burst to 4 chats.

### Medium: diagnostics collection repeats expensive app/device lookups
- Observed risk: PackageInfo.fromPlatform() and DeviceService.instance.info were resolved for each diagnostic event for diagnostic users 116/302.
- Impact: Extra platform-channel overhead during API-heavy sessions.
- Fix applied: diagnostic app version and device info are cached per ChatApi session.

### Medium: chat refresh concurrency is guarded, but polling is still frequent
- Current: home recent_chats polling every 15 seconds; open chat history polling every 12 seconds; presence every 60 seconds from chat screen.
- Recommendation: Keep for now, but next optimization should use adaptive polling: fast only when active/bottom, slower when user is reading older content, app background, or network is slow.

### Medium: backend schema ensure calls happen on hot APIs
- Current: recent_chats.php, history.php, send_message.php call chat_ensure_schema / chat_ensure_column in normal request path.
- Recommendation: Move schema migration to admin/deploy migration endpoint or cache schema-check state per request type with deployment version guard. This can reduce database metadata calls.

## Files Changed
- lib/chat_api.dart
- server_patch/chat/send_message.php
- server_patch/chat/ai_room_worker.php

## Validation
- php -l server_patch/chat/send_message.php: passed.
- php -l server_patch/chat/ai_room_worker.php: passed.
- flutter analyze lib/chat_api.dart: no compile errors; existing info-level lint messages remain.

## Deployment Note
- server_patch/chat/send_message.php and server_patch/chat/ai_room_worker.php must be deployed together to the live chat API folder.
- If exec() is disabled on the live server, AI room replies will not run through the worker until a cron/queue runner is configured.
