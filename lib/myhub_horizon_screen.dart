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
  Map<String, dynamic>? _selectedEmployee;
  Future<Map<String, dynamic>>? _selectedTimelineFuture;

  @override
  void initState() {
    super.initState();
    _future = _horizonApi.getMyHubHorizon();
  }

  void _refresh() {
    setState(() {
      _future = _horizonApi.getMyHubHorizon();
      if (_selectedEmployee != null) {
        final empId = _employeeEmpId(_selectedEmployee!);
        if (empId > 0) {
          _selectedTimelineFuture = _horizonApi.getMyHubHorizonTimeline(empId);
        }
      }
    });
  }

  void _selectEmployee(Map<String, dynamic> employee) {
    final empId = _employeeEmpId(employee);
    setState(() {
      _selectedEmployee = employee;
      _selectedTimelineFuture = empId > 0
          ? _horizonApi.getMyHubHorizonTimeline(empId)
          : null;
    });
  }

  void _syncSelectedEmployee(List<Map<String, dynamic>> employees) {
    if (employees.isEmpty) return;
    final currentId = _selectedEmployee == null
        ? 0
        : _employeeEmpId(_selectedEmployee!);
    final match = employees.cast<Map<String, dynamic>?>().firstWhere(
      (item) => item != null && _employeeEmpId(item) == currentId,
      orElse: () => null,
    );
    if (match != null) {
      _selectedEmployee = match;
      return;
    }
    final fallback = employees.firstWhere(
      (item) => _employeeEmpId(item) > 0,
      orElse: () => employees.first,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_selectedEmployee == null ||
          _employeeEmpId(_selectedEmployee!) != _employeeEmpId(fallback)) {
        _selectEmployee(fallback);
      }
    });
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
          _syncSelectedEmployee(employees);
          final selectedEmployee = _selectedEmployee;
          final selectedEmpId = selectedEmployee == null
              ? 0
              : _employeeEmpId(selectedEmployee);
          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _HorizonSummary(data: data),
                const SizedBox(height: 12),
                _HorizonOverviewSection(
                  employees: employees,
                  selectedEmpId: selectedEmpId,
                  onSelected: _selectEmployee,
                ),
                const SizedBox(height: 12),
                if (selectedEmployee != null && _selectedTimelineFuture != null)
                  _SelectedEmployeeTimelineSection(
                    employee: selectedEmployee,
                    future: _selectedTimelineFuture!,
                    onRefresh: () => _selectEmployee(selectedEmployee),
                    onOpenFullscreen: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => HorizonEmployeeMapScreen(
                            empId: _employeeEmpId(selectedEmployee),
                            employeeName: _employeeName(selectedEmployee),
                          ),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 12),
                Text(
                  'Today attendance list',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                ...employees.map(
                  (item) => _HorizonEmployeeTile(
                    employee: item,
                    isSelected: _employeeEmpId(item) == selectedEmpId,
                    onTap: () => _selectEmployee(item),
                    onOpenFullscreen: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => HorizonEmployeeMapScreen(
                            empId: _employeeEmpId(item),
                            employeeName: _employeeName(item),
                          ),
                        ),
                      );
                    },
                  ),
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

class _HorizonOverviewSection extends StatelessWidget {
  const _HorizonOverviewSection({
    required this.employees,
    required this.selectedEmpId,
    required this.onSelected,
  });

  final List<Map<String, dynamic>> employees;
  final int selectedEmpId;
  final ValueChanged<Map<String, dynamic>> onSelected;

  @override
  Widget build(BuildContext context) {
    final markers = employees
        .map(_employeeMarker)
        .whereType<_EmployeeMarker>()
        .toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'All employees live view',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Last known punched-in position for every visible employee. Click a pin or a name to open that user'
              's full-day route.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: markers.isEmpty
                    ? const ColoredBox(
                        color: Color(0xFFF4F7FB),
                        child: Center(
                          child: Text(
                            'No valid employee coordinates available.',
                          ),
                        ),
                      )
                    : _HorizonEmployeesOverviewMap(
                        markers: markers,
                        selectedEmpId: selectedEmpId,
                        onSelected: onSelected,
                      ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, index) {
                  final employee = employees[index];
                  final selected = _employeeEmpId(employee) == selectedEmpId;
                  return ChoiceChip(
                    selected: selected,
                    label: Text(_employeeName(employee)),
                    onSelected: (_) => onSelected(employee),
                  );
                },
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemCount: employees.length,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedEmployeeTimelineSection extends StatelessWidget {
  const _SelectedEmployeeTimelineSection({
    required this.employee,
    required this.future,
    required this.onRefresh,
    required this.onOpenFullscreen,
  });

  final Map<String, dynamic> employee;
  final Future<Map<String, dynamic>> future;
  final VoidCallback onRefresh;
  final VoidCallback onOpenFullscreen;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        if (snapshot.hasError) {
          return _HorizonEmpty(
            message: '${snapshot.error}',
            onRetry: onRefresh,
          );
        }
        final data = snapshot.data ?? const <String, dynamic>{};
        return _HorizonTimelineDetail(
          employeeName: _employeeName(employee),
          data: data,
          onRefresh: onRefresh,
          onOpenFullscreen: onOpenFullscreen,
        );
      },
    );
  }
}

class _HorizonEmployeeTile extends StatelessWidget {
  const _HorizonEmployeeTile({
    required this.employee,
    required this.isSelected,
    required this.onTap,
    required this.onOpenFullscreen,
  });

  final Map<String, dynamic> employee;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onOpenFullscreen;

  @override
  Widget build(BuildContext context) {
    final name = _employeeName(employee);
    final designation = '${employee['designation'] ?? ''}'.trim();
    final status = '${employee['status'] ?? ''}';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: isSelected ? AppColors.primary.withValues(alpha: 0.06) : null,
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
        trailing: IconButton(
          tooltip: 'Open full route',
          onPressed: onOpenFullscreen,
          icon: const Icon(Icons.open_in_full_rounded),
        ),
        onTap: onTap,
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
          return _HorizonTimelineDetail(
            employeeName: widget.employeeName,
            data: snapshot.data ?? const <String, dynamic>{},
            onRefresh: _refresh,
          );
        },
      ),
    );
  }
}

class _HorizonTimelineDetail extends StatelessWidget {
  const _HorizonTimelineDetail({
    required this.employeeName,
    required this.data,
    required this.onRefresh,
    this.onOpenFullscreen,
  });

  final String employeeName;
  final Map<String, dynamic> data;
  final VoidCallback onRefresh;
  final VoidCallback? onOpenFullscreen;

  @override
  Widget build(BuildContext context) {
    final points = _list(data['points']);
    final halfHours = _list(data['half_hour_points']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MapHeader(
          data: data,
          employeeName: employeeName,
          onRefresh: onRefresh,
          onOpenFullscreen: onOpenFullscreen,
        ),
        const SizedBox(height: 12),
        AspectRatio(
          aspectRatio: 16 / 10,
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: points.isEmpty
                ? const Center(
                    child: Text('No location points captured for this punch.'),
                  )
                : _HorizonMapView(points: points, halfHourPoints: halfHours),
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
  }
}

class _MapHeader extends StatelessWidget {
  const _MapHeader({
    required this.data,
    required this.employeeName,
    required this.onRefresh,
    this.onOpenFullscreen,
  });

  final Map<String, dynamic> data;
  final String employeeName;
  final VoidCallback onRefresh;
  final VoidCallback? onOpenFullscreen;

  @override
  Widget build(BuildContext context) {
    final employee = data['employee'] is Map
        ? Map<String, dynamic>.from(data['employee'] as Map)
        : const <String, dynamic>{};
    final title = '${employee['name'] ?? employeeName}'.trim();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${title.isEmpty ? employeeName : title} route',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (onOpenFullscreen != null)
                  TextButton.icon(
                    onPressed: onOpenFullscreen,
                    icon: const Icon(Icons.open_in_full_rounded),
                    label: const Text('Full view'),
                  ),
                IconButton(
                  tooltip: 'Refresh timeline',
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
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

class _HorizonEmployeesOverviewMap extends StatefulWidget {
  const _HorizonEmployeesOverviewMap({
    required this.markers,
    required this.selectedEmpId,
    required this.onSelected,
  });

  final List<_EmployeeMarker> markers;
  final int selectedEmpId;
  final ValueChanged<Map<String, dynamic>> onSelected;

  @override
  State<_HorizonEmployeesOverviewMap> createState() =>
      _HorizonEmployeesOverviewMapState();
}

class _HorizonEmployeesOverviewMapState
    extends State<_HorizonEmployeesOverviewMap> {
  int? _manualZoom;
  Offset _panWorldOffset = Offset.zero;
  String _signature = '';

  @override
  void didUpdateWidget(covariant _HorizonEmployeesOverviewMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextSignature = widget.markers
        .map((item) => '${item.empId}:${item.lat}:${item.lng}')
        .join('|');
    if (nextSignature != _signature) {
      _manualZoom = null;
      _panWorldOffset = Offset.zero;
      _signature = nextSignature;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.markers.isEmpty) {
      return const Center(
        child: Text('No valid employee coordinates available.'),
      );
    }
    _signature = widget.markers
        .map((item) => '${item.empId}:${item.lat}:${item.lng}')
        .join('|');
    final centerLat =
        widget.markers.map((p) => p.lat).reduce((a, b) => a + b) /
        widget.markers.length;
    final centerLng =
        widget.markers.map((p) => p.lng).reduce((a, b) => a + b) /
        widget.markers.length;
    final zoom = _manualZoom ?? _bestZoomForEmployees(widget.markers);
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
                ...widget.markers.map((marker) {
                  final dx =
                      size.width / 2 +
                      (_worldX(marker.lng, zoom) - viewWorldX) * scale;
                  final dy =
                      size.height / 2 +
                      (_worldY(marker.lat, zoom) - viewWorldY) * scale;
                  final selected = marker.empId == widget.selectedEmpId;
                  return Positioned(
                    left: dx - 20,
                    top: dy - (selected ? 58 : 46),
                    child: GestureDetector(
                      onTap: () => widget.onSelected(marker.employee),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (selected)
                            Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(999),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x22000000),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: Text(
                                marker.name,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          Container(
                            width: selected ? 22 : 18,
                            height: selected ? 22 : 18,
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.primary
                                  : const Color(0xFFEF4444),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x22000000),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
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

    final firstOffset = map(parsed.first);
    final path = Path()..moveTo(firstOffset.dx, firstOffset.dy);
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

class _EmployeeMarker {
  const _EmployeeMarker({
    required this.employee,
    required this.empId,
    required this.name,
    required this.lat,
    required this.lng,
  });

  final Map<String, dynamic> employee;
  final int empId;
  final String name;
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

_EmployeeMarker? _employeeMarker(Map<String, dynamic> employee) {
  final lat = _firstNumber(employee, const [
    'latitude',
    'last_latitude',
    'lat',
    'last_lat',
  ]);
  final lng = _firstNumber(employee, const [
    'longitude',
    'last_longitude',
    'lng',
    'long',
    'last_lng',
  ]);
  if (lat == 0 && lng == 0) return null;
  return _EmployeeMarker(
    employee: employee,
    empId: _employeeEmpId(employee),
    name: _employeeName(employee),
    lat: lat,
    lng: lng,
  );
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

int _bestZoomForEmployees(List<_EmployeeMarker> points) {
  if (points.length < 2) return 15;
  for (var zoom = 17; zoom >= 11; zoom--) {
    final xs = points.map((p) => _worldX(p.lng, zoom));
    final ys = points.map((p) => _worldY(p.lat, zoom));
    final width = xs.reduce(math.max) - xs.reduce(math.min);
    final height = ys.reduce(math.max) - ys.reduce(math.min);
    if (width <= 680 && height <= 680) return zoom;
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

int _employeeEmpId(Map<String, dynamic> employee) =>
    int.tryParse('${employee['emp_id'] ?? employee['employee_id'] ?? 0}') ?? 0;

String _employeeName(Map<String, dynamic> employee) {
  final value = '${employee['name'] ?? employee['username'] ?? 'Employee'}'
      .trim();
  return value.isEmpty ? 'Employee' : value;
}

double _firstNumber(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = _number(data[key]);
    if (value != 0) return value;
  }
  return 0;
}
