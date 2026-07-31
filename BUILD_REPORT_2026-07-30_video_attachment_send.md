# Build Report - Video Attachment Send Fix

Date: 2026-07-30 16:53:00
Status: Completed, no build requested

## Changes
- Chat attachment picker now offers Photo or video and uses FileType.media.
- Native Android/desktop videos and files over 20 MB upload from file path instead of reading the entire file into memory.
- Web and small/image upload paths remain unchanged.

## Verification
- Ran flutter analyze hard-error filter.
- Result: no hard analyzer errors found.
- Existing repository warnings/infos remain.

## Manual Test
- Android: Attachment -> Photo or video -> pick MP4/MOV -> preview -> Send.
- Android: Attachment -> Document or file -> pick video from files -> preview -> Send.
- Web: Existing file/image flow should continue to work.
