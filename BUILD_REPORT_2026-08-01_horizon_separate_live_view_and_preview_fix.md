# Build Report - 2026-08-01 Horizon Separate Live View And Preview Fix

## Summary
- Moved Horizon all-employees live view behind a separate page launcher.
- Added latest employee location data to the Horizon employee list response so markers can render.
- Replaced corrupted file-preview placeholders with readable File: labels and normal ellipsis truncation.

## Files
- lib/myhub_horizon_screen.dart
- server_patch/chat/myhub.php
- server_patch/chat/bootstrap.php

## Verification
- php -l server_patch/chat/myhub.php
- php -l server_patch/chat/bootstrap.php
- lutter analyze lib/myhub_horizon_screen.dart

## Notes
- PROJECT_STATE.md and CHANGE_LEDGER_SPEC.md are still not present in the workspace.
- Server patch files still need deployment to the live server before the web app reflects the backend fixes.
