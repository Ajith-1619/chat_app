# LMS Lead Channel Webhook Sync

Flow sends participant messages from LMS-created lead channels to the LMS activity timeline through an async webhook queue.

## Webhook

- URL: `https://skylinkonline.net/lms/public/api/flow-webhook.php`
- Method: `POST`
- Content-Type: `application/json`
- Tenant: `skylink-tech`

The bearer token must be configured only on the server. Do not commit it or expose it in UI/logs.

## Server Config

Copy:

```text
server_patch/chat/lms_webhook_config.sample.php
```

to the live server as:

```text
/var/www/html/router_login/chat/lms_webhook_config.php
```

Then put the real token in that server-local file, or set environment variables:

```text
SKYCHAT_LMS_WEBHOOK_URL
SKYCHAT_LMS_WEBHOOK_TOKEN
SKYCHAT_LMS_TENANT_SLUG
```

## Lead Channel Detection

A channel is treated as an LMS lead channel when any of these are true:

- `xmpp_groups.group_type = channel` and `channel_kind` is `lead`, `lms-lead`, or `lms_lead`
- `room_jid` starts with `channel-lead-` or `lead-`
- `metadata_json.source` contains `lms`
- `metadata_json.type` / `metadata_json.channel_type` contains `lead`
- `metadata_json.lms_lead_id` or `metadata_json.lms_channel_id` exists

## Payload

```json
{
  "tenant_slug": "skylink-tech",
  "channel_id": 288,
  "room_jid": "channel-lead-example@conference.chat.skylinkonline.net",
  "message_id": "flow-message-12345",
  "sender_jid": "302@chat.skylinkonline.net",
  "sender_name": "Employee Name",
  "body": "Message typed in Flow"
}
```

## Retry Rules

- `200 {"ok":true,"status":"recorded"}`: mark sent
- `200 {"ok":true,"status":"duplicate"}`: mark sent
- `400`, `401`, `422`, and other `4xx`: permanent failure, no retry
- `5xx`, network errors, or timeout: retry up to configured max attempts

Run the worker from cron every minute for reliable delayed retries:

```bash
* * * * * php /var/www/html/router_login/chat/lms_webhook_worker.php 50 >/dev/null 2>&1
```
