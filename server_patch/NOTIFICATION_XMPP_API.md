# System Notification XMPP API

This endpoint sends one-way OTP and system alerts from notification@chat.skylinkonline.net to an employee JID such as 218@chat.skylinkonline.net.

## Required server configuration

Set these environment variables for PHP:

- SKYLINK_NOTIFICATION_API_KEY: bearer key used by approved backend applications. If it is not configured, the default key is skylink-notification-api-key-2026.
- SKYLINK_NOTIFICATION_XMPP_PASSWORD: password used only to register the notification ejabberd account if it does not already exist.

The ejabberd REST credentials already used by EjabberdApi.php must have permission to call send_message.

## Endpoint

POST /router_login/chat/notification_send.php

Headers:

Authorization: Bearer skylink-notification-api-key-2026
Content-Type: application/json

Example OTP body:

{
  "recipient_emp_id": 218,
  "event_type": "otp",
  "reference_id": "billing-login-78421",
  "body": "Your OTP is 482931"
}

recipient_jid or to may be used instead of recipient_emp_id:

{
  "to": "218@chat.skylinkonline.net",
  "event_type": "login_alert",
  "reference_id": "login-alert-78422",
  "body": "A new login was detected."
}

Successful response contains status=true, transport=xmpp, message_id, from and to.

## Delivery rule

The endpoint calls ejabberd/XMPP first. If ejabberd rejects delivery, it returns HTTP 502 and does not create notification history. After ejabberd accepts the stanza, a normal xmpp_messages row is written only as history/cache. Firebase push is supplementary for registered Android devices.

reference_id is the idempotency key. Reusing it returns the existing history ID and avoids sending the same notification twice.

The frontend treats this JID as receive-only: message composer and send controls are hidden, and ChatApi.sendMessage blocks outgoing attempts before any network request.
