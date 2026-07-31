# Next Action Reminder And Completion Poll

Date: 2026-07-30

Flow channels can now monitor the current `next_action_text`, `next_action_persons`, and `next_action_date` metadata.

## Behavior

- One hour before the next action due time, Flow posts a channel reminder:
  - `This action is pending on your side. Please make an update.`
  - The message includes the current next action and due date/time.
- When the due date/time passes, Flow posts a poll in the same channel:
  - Question: `Is this action completed?`
  - Options:
    - `Complete - please update the channel`
    - `Not complete - please change the next action date`
- If the next action text, owner/person, summary, or due date changes, Flow treats it as a new action state and clears the old reminder/poll markers.
- Duplicate reminders and polls are prevented by a state hash and deterministic message IDs.

## Cron

The monitor is called from the existing notification worker:

```text
chat/notification_worker.php
```

Use the same cron that already processes notifications, scheduled messages, and wake-up reminders. A 5-minute interval is recommended so the one-hour reminder is delivered close to the expected time.

## Schema

The monitor auto-adds these columns to `xmpp_groups`:

- `next_action_reminder_sent_at`
- `next_action_due_poll_sent_at`
- `next_action_monitor_hash`

No manual SQL is required if the PHP process has migration privileges.
