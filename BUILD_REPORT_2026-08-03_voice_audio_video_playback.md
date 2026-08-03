
# Build Report - 2026-08-03 - Voice Audio Video Playback

## Scope
- Fix uploaded voice notes showing `00:00` and not playing.
- Add inline audio playback inside chat bubbles with download/open actions.
- Enable real in-app video playback on mobile/non-web preview.

## Files Changed
- `lib/chat/chat_screen.dart`
- `lib/chat_api.dart`
- `lib/attachments/attachment_widgets.dart`
- `lib/video_preview_embed_stub.dart`
- `lib/media_object_url.dart`
- `lib/media_object_url_stub.dart`
- `lib/media_object_url_web.dart`
- `pubspec.yaml`
- `server_patch/chat/send_message.php`
- `server_patch/chat/history.php`
- `server_patch/chat/bootstrap.php`

## What Changed
1. Voice recording send flow now computes real duration and passes it as `duration_ms`.
2. Attachment send APIs now propagate duration metadata and server message inserts persist it.
3. History responses now return `duration_ms` so reloaded voice notes retain playable length.
4. Audio attachments now render an inline player in chat and still support download/open actions.
5. Web audio preview now reads bytes and plays through a local object URL.
6. Non-web video preview now uses `video_player` instead of the old placeholder screen.

## Validation
- Ran `flutter analyze`.
- Result: no new analyzer errors from this patch; repository still has many pre-existing warnings unrelated to this change.

## Deploy Notes
- Dart changes require a fresh app/web build before users receive the new inline players.
- PHP files under `server_patch/chat/` must be moved to the live server so duration metadata persists and returns from history.

## Remaining Live Checks
- Confirm new voice notes no longer show `00:00` after upload and after chat reload.
- Confirm inline audio player works on web and Android.
- Confirm mobile video preview opens and plays inside Flow.
- Confirm restricted audio/video still obey download restrictions.
