import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../map/world_map_data.dart';
import '../models/station.dart';
import '../theme.dart';
import '../widgets/brut.dart';
import '../widgets/station_widgets.dart';
import 'discover_page.dart';

/// Line-drawn world map. Pinch or use +/- to zoom, drag to pan,
/// tap a dot (or a country) to pick a station.
class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with SingleTickerProviderStateMixin {
  final _tc = TransformationController();
  late final AnimationController _anim =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 280));
  Animation<Matrix4>? _zoomAnim;

  WorldMapData? _map;
  MapCountry? _selected;
  Size _viewport = Size.zero;
  bool _placedInitialView = false;

  static const _minScale = 1.0;
  static const _maxScale = 80.0;

  @override
  void initState() {
    super.initState();
    WorldMapData.load().then((m) {
      if (mounted) setState(() => _map = m);
    });
    geoStations.load();
    _anim.addListener(() {
      if (_zoomAnim != null) _tc.value = _zoomAnim!.value;
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    _tc.dispose();
    super.dispose();
  }

  // ---- geometry: map units (degrees) <-> viewport child pixels ----

  double get _unit => _viewport.width / WorldMapData.width; // px per degree at scale 1
  Offset get _origin =>
      Offset(0, (_viewport.height - WorldMapData.height * _unit) / 2); // map centered vertically

  Offset _toChild(Offset mapUnits) => _origin + mapUnits * _unit;
  Offset _toMap(Offset child) => (child - _origin) / _unit;

  double get _scale => _tc.value.getMaxScaleOnAxis();

  /// Starting view: Europe / Türkiye / Middle East.
  Matrix4 _homeMatrix() => _matrixFor(WorldMapData.project(28, 44), 3.2);

  Matrix4 _matrixFor(Offset mapCenter, double scale) {
    final c = _toChild(mapCenter);
    final v = Offset(_viewport.width / 2, _viewport.height / 2);
    return Matrix4.identity()
      ..translateByDouble(v.dx - c.dx * scale, v.dy - c.dy * scale, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  void _animateTo(Matrix4 target) {
    _zoomAnim = Matrix4Tween(begin: _tc.value, end: target)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
    _anim.forward(from: 0);
  }

  void _zoomBy(double factor) {
    final center = _toMap(_tc.toScene(Offset(_viewport.width / 2, _viewport.height / 2)));
    final s = (_scale * factor).clamp(_minScale, _maxScale);
    _animateTo(_matrixFor(center, s));
  }

  // ---- tapping ----

  void _onTap(Offset childPos) {
    final map = _map;
    if (map == null) return;
    final s = _scale;
    final hitRadius = 22 / s; // ~22 screen px
    final near = <(double, Station)>[];
    for (final st in geoStations.stations) {
      final p = _toChild(WorldMapData.project(st.lon!, st.lat!));
      final d = (p - childPos).distance;
      if (d <= hitRadius) near.add((d, st));
    }
    near.sort((a, b) => a.$1.compareTo(b.$1));
    final (lon, lat) = WorldMapData.unproject(_toMap(childPos));
    final country = map.countryAt(lon, lat);
    if (near.isEmpty && country == null) {
      setState(() => _selected = null);
      return;
    }
    setState(() => _selected = country);
    _showNearby(country, near.map((e) => e.$2).take(40).toList());
  }

  Future<void> _showNearby(MapCountry? country, List<Station> stations) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _NearbySheet(country: country, stations: stations),
    );
    if (mounted) setState(() => _selected = null);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        Positioned.fill(
          child: LayoutBuilder(builder: (context, c) {
            _viewport = c.biggest;
            if (!_placedInitialView && _viewport.width > 0) {
              _placedInitialView = true;
              _tc.value = _homeMatrix();
            }
            return InteractiveViewer(
              transformationController: _tc,
              minScale: _minScale,
              maxScale: _maxScale,
              boundaryMargin: EdgeInsets.symmetric(
                  horizontal: _viewport.width * 0.2, vertical: _viewport.height * 0.5),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) => _onTap(d.localPosition),
                child: CustomPaint(
                  size: _viewport,
                  painter: _map == null
                      ? null
                      : _MapPainter(
                          map: _map!,
                          stations: geoStations,
                          transform: _tc,
                          origin: _origin,
                          unit: _unit,
                          ink: scheme.onSurface,
                          selected: _selected,
                          playing: player,
                        ),
                ),
              ),
            );
          }),
        ),
        // Header
        Positioned(
          left: 16,
          right: 16,
          top: 12,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      color: scheme.surface,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text('DÜNYA\nRADYO', style: display(context, size: 30)),
                    ),
                    const SizedBox(height: 6),
                    ListenableBuilder(
                      listenable: geoStations,
                      builder: (context, _) => Container(
                        color: scheme.surface,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          upper(geoStations.error ??
                              (geoStations.stations.isEmpty
                                  ? 'İstasyonlar yükleniyor…'
                                  : '${geoStations.stations.length} istasyon · dokun ve dinle')),
                          style: mono(context, size: 11, spacing: 1),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ListenableBuilder(
                listenable: settings,
                builder: (context, _) =>
                    ThemeButton(label: settings.themeLabel, onTap: settings.cycleTheme),
              ),
            ],
          ),
        ),
        // Zoom controls
        Positioned(
          right: 16,
          bottom: 16,
          child: Column(
            children: [
              BrutIconButton(Icons.add, tooltip: 'Yakınlaştır', onTap: () => _zoomBy(2)),
              const SizedBox(height: 8),
              BrutIconButton(Icons.remove, tooltip: 'Uzaklaştır', onTap: () => _zoomBy(0.5)),
              const SizedBox(height: 8),
              BrutIconButton(Icons.public, tooltip: 'Tüm dünya', onTap: () => _animateTo(Matrix4.identity())),
              const SizedBox(height: 8),
              BrutIconButton(Icons.my_location, tooltip: 'Başlangıç', onTap: () => _animateTo(_homeMatrix())),
            ],
          ),
        ),
        Positioned(
          left: 16,
          bottom: 16,
          child: ListenableBuilder(
            listenable: geoStations,
            builder: (context, _) => geoStations.error == null
                ? const SizedBox.shrink()
                : BrutBox(onTap: () => geoStations.load(force: true), child: const Text('TEKRAR DENE')),
          ),
        ),
      ],
    );
  }
}

class _MapPainter extends CustomPainter {
  _MapPainter({
    required this.map,
    required this.stations,
    required this.transform,
    required this.origin,
    required this.unit,
    required this.ink,
    required this.selected,
    required this.playing,
  }) : super(repaint: Listenable.merge([transform, stations, playing]));

  final WorldMapData map;
  final Listenable stations;
  final TransformationController transform;
  final Offset origin;
  final double unit;
  final Color ink;
  final MapCountry? selected;
  final Listenable playing;

  Float32List? _points;
  int _pointsFor = -1;

  @override
  void paint(Canvas canvas, Size size) {
    final s = transform.value.getMaxScaleOnAxis();

    // Outlines: drawn in degree units, line width kept ~1 screen px at any zoom.
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.scale(unit);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..color = ink
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 1.0 / (unit * s);
    canvas.drawPath(map.path, line);
    if (selected != null) {
      canvas.drawPath(selected!.path, line..strokeWidth = 3.0 / (unit * s));
    }
    canvas.restore();

    // Station dots: squares of constant screen size.
    final list = geoStations.stations;
    if (list.isEmpty) return;
    if (_points == null || _pointsFor != list.length) {
      final pts = Float32List(list.length * 2);
      for (var i = 0; i < list.length; i++) {
        final p = origin + WorldMapData.project(list[i].lon!, list[i].lat!) * unit;
        pts[i * 2] = p.dx;
        pts[i * 2 + 1] = p.dy;
      }
      _points = pts;
      _pointsFor = list.length;
    }
    final dot = math.min(6.0, 2.5 + s * 0.35) / s;
    canvas.drawRawPoints(
      ui.PointMode.points,
      _points!,
      Paint()
        ..color = ink
        ..strokeWidth = dot
        ..strokeCap = StrokeCap.butt,
    );

    // Current station: hollow square with a gap around it.
    final cur = player.station;
    if (cur != null && cur.hasGeo) {
      final p = origin + WorldMapData.project(cur.lon!, cur.lat!) * unit;
      canvas.drawRect(
        Rect.fromCenter(center: p, width: 16 / s, height: 16 / s),
        Paint()
          ..style = PaintingStyle.stroke
          ..color = ink
          ..strokeWidth = 2 / s,
      );
    }
  }

  @override
  bool shouldRepaint(_MapPainter old) =>
      old.map != map || old.ink != ink || old.selected != selected || old.unit != unit || old.origin != origin;
}

/// Bottom sheet after tapping the map: nearby stations + the whole country.
class _NearbySheet extends StatelessWidget {
  const _NearbySheet({required this.country, required this.stations});

  final MapCountry? country;
  final List<Station> stations;

  @override
  Widget build(BuildContext context) {
    final c = country;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c == null ? 'YAKINDAKİLER' : '${flagEmoji(c.iso)}  ${c.iso}',
                            style: mono(context, size: 12, weight: FontWeight.w700, spacing: 2)),
                        const SizedBox(height: 4),
                        Text(upper(c?.name ?? 'Bu bölge'), style: display(context, size: 28)),
                      ],
                    ),
                  ),
                  BrutIconButton(Icons.close, size: 40, onTap: () => Navigator.pop(context)),
                ],
              ),
            ),
            if (c != null && c.iso.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: BrutBox(
                  inverted: true,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(builder: (_) => CountryStationsPage(code: c.iso, name: c.name)),
                    );
                  },
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text('${upper(c.name)} — TÜM İSTASYONLAR →'),
                ),
              ),
            if (stations.isNotEmpty) const SectionLabel('Dokunduğun yerde'),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [for (final s in stations) StationTile(s)],
              ),
            ),
            if (stations.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Bu noktada işaretli istasyon yok. Yakınlaştırıp bir noktaya dokun '
                    'ya da ülkenin tüm istasyonlarını aç.',
                    style: mono(context, size: 12)),
              ),
          ],
        ),
      ),
    );
  }
}
