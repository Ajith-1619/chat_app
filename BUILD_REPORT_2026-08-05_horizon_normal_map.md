# Build Report - 2026-08-05 Horizon Normal Map Sizing

## Change
Centered and constrained Horizon maps so they no longer occupy the entire viewport. Individual route maps use a 920px desktop maximum and all-employee overview maps use a 1100px maximum; mobile layouts remain responsive. Employee cards and the scrollable timeline remain intact.

## Verification
- `flutter analyze --no-pub lib\myhub_horizon_screen.dart`: passed.
- `flutter build web --release`: timed out after 124 seconds in this environment; a fresh release build was not produced in this turn.

## Notes
The current map implementation remains the existing interactive map layer. Switching to Google Maps requires a configured API key and billing-enabled project.
