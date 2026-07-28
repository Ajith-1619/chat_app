import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'app/skylink_app.dart';
import 'chat_api.dart';

final ChatApi _horizonApi = sharedChatApi;

class MyHubHorizonScreen extends StatefulWidget {
  const MyHubHorizonScreen({super.key});

  @override
  State<MyHubHorizonScreen> createState() => _MyHubHorizonScreenState();
}

class _MyHubHorizonScreenState extends State<MyHubHorizonScreen> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _horizonApi.getMyHubHorizon();
  }

  void _refresh() {
    setState(() => _future = _horizonApi.getMyHubHorizon());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Horizon'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _HorizonEmpty(
              message: '${snapshot.error}',
              onRetry: _refresh,
            );
          }
          final data = snapshot.data ?? const <String, dynamic>{};
          final employees = _list(data['employees']);
          if (employees.isEmpty) {
            return const _HorizonEmpty(
              message: 'No employees have punched in today.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _HorizonSummary(data: data),
                const SizedBox(height: 12),
                ...employees.map(
                  (item) => _HorizonEmployeeTile(employee: item),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HorizonSummary extends StatelessWidget {
  const _HorizonSummary({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              child: const Icon(
                Icons.travel_explore_rounded,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Today attendance horizon',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${data['date'] ?? ''} - ${data['count'] ?? 0} punched in employees',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HorizonEmployeeTile extends StatelessWidget {
  const _HorizonEmployeeTile({required this.employee});

  final Map<String, dynamic> employee;

  @override
  Widget build(BuildContext context) {
    final name = '${employee['name'] ?? 'Employee'}';
    final designation = '${employee['designation'] ?? ''}'.trim();
    final empId = int.tryParse('${employee['emp_id'] ?? 0}') ?? 0;
    final status = '${employee['status'] ?? ''}';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary,
          child: Text(
            _initials(name),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (designation.isNotEmpty)
                Text(designation, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _MiniPill(
                    label: 'In',
                    value: _shortTime(employee['punch_in']),
                  ),
                  _MiniPill(
                    label: 'Out',
                    value: _shortTime(employee['punch_out']),
                  ),
                  _MiniPill(
                    label: 'Hours',
                    value: '${employee['working_hours'] ?? '--'}',
                  ),
                  _MiniPill(label: 'Status', value: status),
                ],
              ),
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: empId <= 0
            ? null
            : () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => HorizonEmployeeMapScreen(
                    empId: empId,
                    employeeName: name,
                  ),
                ),
              ),
      ),
    );
  }
}

class HorizonEmployeeMapScreen extends StatefulWidget {
  const HorizonEmployeeMapScreen({
    super.key,
    required this.empId,
    required this.employeeName,
  });

  final int empId;
  final String employeeName;

  @override
  State<HorizonEmployeeMapScreen> createState() =>
      _HorizonEmployeeMapScreenState();
}

class _HorizonEmployeeMapScreenState extends State<HorizonEmployeeMapScreen> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _horizonApi.getMyHubHorizonTimeline(widget.empId);
  }

  void _refresh() {
    setState(() => _future = _horizonApi.getMyHubHorizonTimeline(widget.empId));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.employeeName),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _HorizonEmpty(
              message: '${snapshot.error}',
              onRetry: _refresh,
            );
          }
          final data = snapshot.data ?? const <String, dynamic>{};
          final points = _list(data['points']);
          final halfHours = _list(data['half_hour_points']);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _MapHeader(data: data),
              const SizedBox(height: 12),
              AspectRatio(
                aspectRatio: 16 / 10,
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: points.isEmpty
                      ? const Center(
                          child: Text(
                            'No location points captured for this punch.',
                          ),
                        )
                      : _HorizonMapView(
                          points: points,
                          halfHourPoints: halfHours,
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '30 minute timeline',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              if (halfHours.isEmpty)
                const Text('No half-hour checkpoints yet.')
              else
                ...halfHours.map((point) => _TimelinePoint(point: point)),
            ],
          );
        },
      ),
    );
  }
}

class _MapHeader extends StatelessWidget {
  const _MapHeader({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final employee = data['employee'] is Map
        ? Map<String, dynamic>.from(data['employee'] as Map)
        : const <String, dynamic>{};
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${employee['name'] ?? 'Employee'} route',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MiniPill(
                  label: 'Punch in',
                  value: _shortTime(data['punch_in']),
                ),
                _MiniPill(
                  label: 'Punch out',
                  value: _shortTime(data['punch_out']),
                ),
                _MiniPill(
                  label: 'Hours',
                  value: '${data['working_hours'] ?? '--'}',
                ),
                _MiniPill(
                  label: 'Points',
                  value: '${data['point_count'] ?? 0}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HorizonMapView extends StatefulWidget {
  const _HorizonMapView({required this.points, required this.halfHourPoints});

  final List<Map<String, dynamic>> points;
  final List<Map<String, dynamic>> halfHourPoints;

  @override
  State<_HorizonMapView> createState() => _HorizonMapViewState();
}

class _HorizonMapViewState extends State<_HorizonMapView> {
  int? _manualZoom;
  Offset _panWorldOffset = Offset.zero;
  String _pointSignature = '';

  @override
  void didUpdateWidget(covariant _HorizonMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextSignature = _signature(widget.points);
    if (nextSignature != _pointSignature) {
      _manualZoom = null;
      _panWorldOffset = Offset.zero;
      _pointSignature = nextSignature;
    }
  }

  @override
  Widget build(BuildContext context) {
    final parsed = widget.points
        .map(_routePoint)
        .whereType<_RoutePoint>()
        .toList();
    if (parsed.isEmpty) {
      return const Center(child: Text('No valid map points captured.'));
    }
    _pointSignature = _signature(widget.points);
    final centerLat =
        parsed.map((p) => p.lat).reduce((a, b) => a + b) / parsed.length;
    final centerLng =
        parsed.map((p) => p.lng).reduce((a, b) => a + b) / parsed.length;
    final zoom = _manualZoom ?? _bestZoom(parsed);
    final baseWorldX = _worldX(centerLng, zoom);
    final baseWorldY = _worldY(centerLat, zoom);
    final viewWorldX = baseWorldX + _panWorldOffset.dx;
    final viewWorldY = baseWorldY + _panWorldOffset.dy;
    final centerTileX = (viewWorldX / 256).floor();
    final centerTileY = (viewWorldY / 256).floor();

    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          _setZoom(zoom + (event.scrollDelta.dy < 0 ? 1 : -1), zoom);
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          final scale = _mapScale(size);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanUpdate: (details) {
              setState(() {
                _panWorldOffset -= Offset(
                  details.delta.dx / scale,
                  details.delta.dy / scale,
                );
              });
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                for (var y = centerTileY - 2; y <= centerTileY + 2; y++)
                  for (var x = centerTileX - 2; x <= centerTileX + 2; x++)
                    Positioned(
                      left: size.width / 2 + ((x * 256.0) - viewWorldX) * scale,
                      top: size.height / 2 + ((y * 256.0) - viewWorldY) * scale,
                      width: 256 * scale,
                      height: 256 * scale,
                      child: Image.network(
                        _tileUrl(x, y, zoom),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Container(color: const Color(0xFFEFF3F9)),
                      ),
                    ),
                CustomPaint(
                  painter: _HorizonRoutePainter(
                    points: widget.points,
                    halfHourPoints: widget.halfHourPoints,
                    centerWorldX: viewWorldX,
                    centerWorldY: viewWorldY,
                    zoom: zoom,
                  ),
                  child: const SizedBox.expand(),
                ),
                const Positioned(left: 12, bottom: 12, child: _MapLegend()),
                Positioned(
                  right: 12,
                  top: 12,
                  child: _MapZoomControls(
                    zoom: zoom,
                    onZoomIn: zoom >= 18
                        ? null
                        : () => _setZoom(zoom + 1, zoom),
                    onZoomOut: zoom <= 11
                        ? null
                        : () => _setZoom(zoom - 1, zoom),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _setZoom(int zoom, int currentZoom) {
    final next = zoom.clamp(11, 18);
    if ((_manualZoom ?? currentZoom) == next) return;
    final ratio = math.pow(2, next - currentZoom).toDouble();
    setState(() {
      _manualZoom = next;
      _panWorldOffset *= ratio;
    });
  }

  String _signature(List<Map<String, dynamic>> points) => points
      .map((p) => '${p['latitude']},${p['longitude']},${p['captured_at']}')
      .join('|');
}

class _MapZoomControls extends StatelessWidget {
  const _MapZoomControls({
    required this.zoom,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  final int zoom;
  final VoidCallback? onZoomIn;
  final VoidCallback? onZoomOut;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 8)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Zoom in',
            onPressed: onZoomIn,
            icon: const Icon(Icons.add_rounded),
          ),
          Text('$zoom', style: const TextStyle(fontWeight: FontWeight.w800)),
          IconButton(
            tooltip: 'Zoom out',
            onPressed: onZoomOut,
            icon: const Icon(Icons.remove_rounded),
          ),
        ],
      ),
    );
  }
}

class _MapLegend extends StatelessWidget {
  const _MapLegend();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 8)],
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LegendDot(color: Color(0xFF16A34A), label: 'Start'),
            SizedBox(width: 10),
            _LegendDot(color: Color(0xFFFFB020), label: '30 min'),
            SizedBox(width: 10),
            _LegendDot(color: Color(0xFFEF4444), label: 'Last'),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _HorizonRoutePainter extends CustomPainter {
  _HorizonRoutePainter({
    required this.points,
    required this.halfHourPoints,
    required this.centerWorldX,
    required this.centerWorldY,
    required this.zoom,
  });

  final List<Map<String, dynamic>> points;
  final List<Map<String, dynamic>> halfHourPoints;
  final double centerWorldX;
  final double centerWorldY;
  final int zoom;

  @override
  void paint(Canvas canvas, Size size) {
    final parsed = points.map(_routePoint).whereType<_RoutePoint>().toList();
    if (parsed.isEmpty) return;
    final scale = _mapScale(size);

    Offset map(_RoutePoint p) => Offset(
      size.width / 2 + (_worldX(p.lng, zoom) - centerWorldX) * scale,
      size.height / 2 + (_worldY(p.lat, zoom) - centerWorldY) * scale,
    );

    final routePaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final casingPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.86)
      ..strokeWidth = 7
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()..moveTo(map(parsed.first).dx, map(parsed.first).dy);
    for (final point in parsed.skip(1)) {
      final offset = map(point);
      path.lineTo(offset.dx, offset.dy);
    }
    canvas.drawPath(path, casingPaint);
    canvas.drawPath(path, routePaint);

    final halfParsed = halfHourPoints
        .map(_routePoint)
        .whereType<_RoutePoint>()
        .toList();
    final checkpointPaint = Paint()..color = const Color(0xFFFFB020);
    final checkpointBorder = Paint()..color = Colors.white;
    for (final point in halfParsed) {
      final offset = map(point);
      canvas.drawCircle(offset, 7, checkpointBorder);
      canvas.drawCircle(offset, 5, checkpointPaint);
    }

    canvas.drawCircle(map(parsed.first), 11, Paint()..color = Colors.white);
    canvas.drawCircle(
      map(parsed.first),
      8,
      Paint()..color = const Color(0xFF16A34A),
    );
    canvas.drawCircle(map(parsed.last), 11, Paint()..color = Colors.white);
    canvas.drawCircle(
      map(parsed.last),
      8,
      Paint()..color = const Color(0xFFEF4444),
    );
  }

  @override
  bool shouldRepaint(covariant _HorizonRoutePainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.halfHourPoints != halfHourPoints ||
      oldDelegate.centerWorldX != centerWorldX ||
      oldDelegate.centerWorldY != centerWorldY ||
      oldDelegate.zoom != zoom;
}

class _TimelinePoint extends StatelessWidget {
  const _TimelinePoint({required this.point});

  final Map<String, dynamic> point;

  @override
  Widget build(BuildContext context) {
    final coords =
        '${_number(point['latitude']).toStringAsFixed(5)}, ${_number(point['longitude']).toStringAsFixed(5)}';
    final address = '${point['address'] ?? ''}'.trim();
    return ListTile(
      leading: const Icon(Icons.place_outlined, color: AppColors.primary),
      title: Text(
        _shortTime(
          point['checkpoint_at'] ??
              point['captured_at'] ??
              point['created_at'] ??
              point['time'],
        ),
      ),
      subtitle: Text(address.isEmpty ? coords : '$address\n$coords'),
      isThreeLine: address.isNotEmpty,
      dense: true,
    );
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: ${value.isEmpty ? '--' : value}',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _HorizonEmpty extends StatelessWidget {
  const _HorizonEmpty({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.travel_explore_rounded,
              size: 44,
              color: AppColors.muted,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RoutePoint {
  const _RoutePoint({required this.lat, required this.lng});
  final double lat;
  final double lng;
}

List<Map<String, dynamic>> _list(dynamic value) => value is List
    ? value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList()
    : <Map<String, dynamic>>[];

_RoutePoint? _routePoint(Map<String, dynamic> item) {
  final lat = _number(item['latitude']);
  final lng = _number(item['longitude']);
  if (lat == 0 && lng == 0) return null;
  return _RoutePoint(lat: lat, lng: lng);
}

double _number(dynamic value) => double.tryParse('$value') ?? 0;
double _mapScale(Size size) => math.max(size.width, size.height) / 768.0;

int _bestZoom(List<_RoutePoint> points) {
  if (points.length < 2) return 16;
  for (var zoom = 17; zoom >= 11; zoom--) {
    final xs = points.map((p) => _worldX(p.lng, zoom));
    final ys = points.map((p) => _worldY(p.lat, zoom));
    final width = xs.reduce(math.max) - xs.reduce(math.min);
    final height = ys.reduce(math.max) - ys.reduce(math.min);
    if (width <= 620 && height <= 620) return zoom;
  }
  return 11;
}

double _worldX(double longitude, int zoom) =>
    (longitude + 180.0) / 360.0 * (1 << zoom) * 256.0;

double _worldY(double latitude, int zoom) {
  final safeLat = latitude.clamp(-85.05112878, 85.05112878).toDouble();
  final latRad = safeLat * math.pi / 180.0;
  return (1.0 - math.log(math.tan(latRad) + 1.0 / math.cos(latRad)) / math.pi) /
      2.0 *
      (1 << zoom) *
      256.0;
}

String _tileUrl(int x, int y, int zoom) =>
    'https://tile.openstreetmap.org/$zoom/$x/$y.png';

String _shortTime(dynamic value) {
  final raw = '$value'.trim();
  if (raw.isEmpty || raw == '-') return '--';
  final parsed = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
  if (parsed == null) return raw.length > 16 ? raw.substring(11, 16) : raw;
  final hour = parsed.hour > 12
      ? parsed.hour - 12
      : (parsed.hour == 0 ? 12 : parsed.hour);
  final minute = parsed.minute.toString().padLeft(2, '0');
  final suffix = parsed.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $suffix';
}

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return 'H';
  if (parts.length == 1) return parts.first.characters.first.toUpperCase();
  return (parts.first.characters.first + parts.last.characters.first)
      .toUpperCase();
}
