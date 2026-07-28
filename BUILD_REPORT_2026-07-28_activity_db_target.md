# Build Report - 2026-07-28 - Activity DB Target Correction

## Scope
Corrected My Hub activity logging to use the primary chat/XMPP database instead of the task database.

## File Changed
- server_patch/chat/myhub.php

## Verification
- PHP lint passed.

## Notes
- No Flutter build was run.
- Existing activity_log records previously inserted into the task DB will need one-time migration if required.