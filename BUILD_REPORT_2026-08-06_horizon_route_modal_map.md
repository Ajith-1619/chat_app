# Horizon Route Modal Map - 2026-08-06

## Change
Employee route views now open in a bounded modal with close, Map/Satellite layers, zoom controls, drag support, route polyline, start/end markers, and checkpoint time labels. The separate all-employees live map remains available from Horizon.

## Verification
- flutter analyze --no-pub lib/myhub_horizon_screen.dart: passed
- flutter build web --release: passed

## Notes
Uses the existing OpenStreetMap and ArcGIS raster tile providers. No Google Maps API key was added.

## Timeout Fix
- Removed sequential reverse-geocoding calls from server_patch/chat/myhub.php Horizon timeline endpoint; they could consume the full 45-second request timeout.
- PHP lint passed after the change.


## Modal Layout Update
- Fixed employee/punch header, map-only modal body, no modal scrolling, and route time labels retained on the map.
- Flutter Web release rebuilt successfully.

