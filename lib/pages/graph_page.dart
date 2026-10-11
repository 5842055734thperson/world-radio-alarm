import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/station.dart';
import '../theme.dart';
import '../widgets/brut.dart';
import '../widgets/station_widgets.dart';

/// Discovery tree, inspired by everynoise.com: start from one station, tap a
/// station to play it and branch out to related stations — some from the same
/// country (solid lines), some from other countries (dashed lines).
class GraphPage extends StatefulWidget {
  const GraphPage({super.key});

  @override
  State<GraphPage> createState() => _GraphPageState();
}

class _Node {
  _Node(this.station, this.pos, this.parent);

  final Station station;
  Offset pos;
  final _Node? parent;
  final List<_Node> children = [];
  bool expanded = false;
  bool loading = false;
  bool empty = false;

  bool get crossCountry => parent != null && parent!.station.countryCode != station.countryCode;
}

class _GraphPageState extends State<GraphPage> with SingleTickerProviderStateMixin {
  static const _canvas = 4000.0;
  static const _center = Offset(_canvas / 2, _canvas / 2);
  static const _nodeW = 136.0;
  static const _nodeH = 62.0;

  final _tc = TransformationController();
  late final AnimationController _anim =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
  Animation<Matrix4>? _move;
  Size _viewport = Size.zero;

  _Node? _root;
  final List<_Node> _nodes = [];

  /// Centering requested before the viewport was measured.
  (_Node, double)? _pendingCenter;

  @override
  void initState() {
    super.initState();
    _anim.addListener(() {
      if (_move != null) _tc.value = _move!.value;
    });
    graphSeed.addListener(_onSeed);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onSeed());
  }

  @override
  void dispose() {
    graphSeed.removeListener(_onSeed);
    _anim.dispose();
    _tc.dispose();
    super.dispose();
  }

  void _onSeed() {
    final seed = graphSeed.value;
    if (seed == null || seed == _root?.station) return;
    final root = _Node(seed, _center, null);
    setState(() {
      _root = root;
      _nodes
        ..clear()
        ..add(root);
    });
    _centerOn(root, scale: 0.85, animate: false);
    _expand(root);
  }

  // ---- tree operations ----

  Future<void> _expand(_Node n) async {
    if (n.expanded || n.loading) return;
    setState(() => n.loading = true);
    final related = await similar.related(
      n.station,
      exclude: {for (final x in _nodes) x.station.uuid},
    );
    if (!mounted || !_nodes.contains(n)) return;
    setState(() {
      n.loading = false;
      n.expanded = true;
      n.empty = related.isEmpty;
      _place(n, related);
    });
  }

  /// Fans children out around [n], away from its parent, avoiding overlaps.
  void _place(_Node n, List<Station> stations) {
    if (stations.isEmpty) return;
    final count = stations.length;
    final double base, spread, radius;
    if (n.parent == null) {
      base = -math.pi / 2;
      spread = 2 * math.pi * (count - 1) / count;
      radius = 210;
    } else {
      final d = n.pos - n.parent!.pos;
      base = math.atan2(d.dy, d.dx);
      spread = math.min(2.0, 0.45 * (count - 1));
      radius = 190;
    }
    for (var i = 0; i < count; i++) {
      final a = count == 1 ? base : base - spread / 2 + spread * i / (count - 1);
      var r = radius;
      var pos = n.pos + Offset(math.cos(a), math.sin(a)) * r;
      for (var tries = 0; tries < 4 && _crowded(pos); tries++) {
        r += 90;
        pos = n.pos + Offset(math.cos(a), math.sin(a)) * r;
      }
      final child = _Node(stations[i], _clamp(pos), n);
      n.children.add(child);
      _nodes.add(child);
    }
  }

  bool _crowded(Offset p) => _nodes.any((o) => (o.pos.dx - p.dx).abs() < _nodeW + 12 && (o.pos.dy - p.dy).abs() < _nodeH + 16);

  Offset _clamp(Offset p) => Offset(
        p.dx.clamp(_nodeW, _canvas - _nodeW),
        p.dy.clamp(_nodeH, _canvas - _nodeH),
      );

  void _collapse(_Node n) {
    void remove(_Node x) {
      for (final c in x.children) {
        remove(c);
      }
      _nodes.remove(x);
    }

    setState(() {
      for (final c in n.children) {
        remove(c);
      }
      n.children.clear();
      n.expanded = false;
      n.empty = false;
    });
  }

  void _onTapNode(_Node n) {
    if (player.station != n.station || !player.playing) player.play(n.station);
    _expand(n);
    _centerOn(n);
  }

  // ---- camera ----

  void _centerOn(_Node n, {double? scale, bool animate = true}) {
    final s = scale ?? _tc.value.getMaxScaleOnAxis();
    if (_viewport == Size.zero) {
      _pendingCenter = (n, s);
      return;
    }
    final target = Matrix4.identity()
      ..translateByDouble(_viewport.width / 2 - n.pos.dx * s, _viewport.height / 2 - n.pos.dy * s, 0, 1)
      ..scaleByDouble(s, s, 1, 1);
    if (!animate) {
      _tc.value = target;
      return;
    }
    _move = Matrix4Tween(begin: _tc.value, end: target)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
    _anim.forward(from: 0);
  }

  // ---- UI ----

  @override
  Widget build(BuildContext context) {
    final root = _root;
    if (root == null) return const _SeedPicker();
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        Positioned.fill(
          child: LayoutBuilder(builder: (context, c) {
            _viewport = c.biggest;
            final pending = _pendingCenter;
            if (pending != null && _viewport != Size.zero) {
              _pendingCenter = null;
              WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _centerOn(pending.$1, scale: pending.$2, animate: false));
            }
            return InteractiveViewer(
              transformationController: _tc,
              constrained: false,
              minScale: 0.3,
              maxScale: 2.5,
              boundaryMargin: const EdgeInsets.all(400),
              child: SizedBox(
                width: _canvas,
                height: _canvas,
                child: ListenableBuilder(
                  listenable: player,
                  builder: (context, _) => Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(painter: _EdgePainter(_nodes, scheme.onSurface)),
                      ),
                      for (final n in _nodes)
                        Positioned(
                          left: n.pos.dx - _nodeW / 2,
                          top: n.pos.dy - _nodeH / 2,
                          width: _nodeW,
                          height: _nodeH,
                          child: _NodeBox(
                            node: n,
                            isRoot: n == root,
                            playing: player.station == n.station,
                            onTap: () => _onTapNode(n),
                            onLongPress: () => _collapse(n),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
        Positioned(
          left: 16,
          right: 16,
          top: 12,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  color: scheme.surface,
                  padding: const EdgeInsets.all(4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('AĞ', style: display(context, size: 30)),
                      const SizedBox(height: 6),
                      Text('━━ AYNI ÜLKE   ┅┅ BAŞKA ÜLKE', style: mono(context, size: 10, spacing: 1)),
                      const SizedBox(height: 2),
                      Text('DOKUN: ÇAL + DALLAN · BASILI TUT: KAPAT',
                          style: mono(context, size: 10, spacing: 1, color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ),
              BrutIconButton(Icons.center_focus_strong,
                  size: 40, tooltip: 'Başa dön', onTap: () => _centerOn(root, scale: 0.85)),
              const SizedBox(width: 8),
              BrutIconButton(Icons.refresh, size: 40, tooltip: 'Yeni başlangıç', onTap: () {
                graphSeed.value = null;
                setState(() {
                  _root = null;
                  _nodes.clear();
                });
              }),
            ],
          ),
        ),
      ],
    );
  }
}

class _NodeBox extends StatelessWidget {
  const _NodeBox({
    required this.node,
    required this.isRoot,
    required this.playing,
    required this.onTap,
    required this.onLongPress,
  });

  final _Node node;
  final bool isRoot;
  final bool playing;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = playing ? scheme.surface : scheme.onSurface;
    final s = node.station;
    final status = node.loading
        ? '…'
        : node.empty
            ? '∅'
            : node.expanded
                ? '−'
                : '+';
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        decoration: BoxDecoration(
          color: playing ? scheme.onSurface : scheme.surface,
          border: Border.all(color: scheme.onSurface, width: isRoot ? 4 : kBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('${flagEmoji(s.countryCode)} ${s.countryCode}',
                    style: mono(context, size: 10, weight: FontWeight.w700, color: fg)),
                const Spacer(),
                Text(status, style: mono(context, size: 12, weight: FontWeight.w700, color: fg)),
              ],
            ),
            const SizedBox(height: 2),
            Expanded(
              child: Text(
                upper(s.name),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, height: 1.1, color: fg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EdgePainter extends CustomPainter {
  _EdgePainter(this.nodes, this.ink);

  final List<_Node> nodes;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final solid = Paint()
      ..color = ink
      ..strokeWidth = 2;
    final thin = Paint()
      ..color = ink
      ..strokeWidth = 1.5;
    for (final n in nodes) {
      final p = n.parent;
      if (p == null) continue;
      if (n.crossCountry) {
        _dashed(canvas, p.pos, n.pos, thin);
      } else {
        canvas.drawLine(p.pos, n.pos, solid);
      }
    }
  }

  static void _dashed(Canvas canvas, Offset a, Offset b, Paint paint) {
    final d = b - a;
    final len = d.distance;
    final dir = d / len;
    const dash = 8.0, gap = 6.0;
    for (var t = 0.0; t < len; t += dash + gap) {
      canvas.drawLine(a + dir * t, a + dir * math.min(t + dash, len), paint);
    }
  }

  @override
  bool shouldRepaint(_EdgePainter old) => true;
}

/// Shown until a starting station is chosen.
class _SeedPicker extends StatelessWidget {
  const _SeedPicker();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([player, favorites]),
      builder: (context, _) {
        final current = player.station;
        final mine = [
          ...favorites.stations,
          ...favorites.recent.where((s) => !favorites.contains(s)),
        ].where((s) => s != current).take(12).toList();
        return ListView(
          children: [
            const PageTitle('Ağ'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                upper('Bir istasyondan başla. Dokundukça benzer istasyonlara dallanır: '
                    'aynı ülkeden ve başka ülkelerden.'),
                style: mono(context, size: 12),
              ),
            ),
            if (current != null) ...[
              const SectionLabel('Şimdi çalan'),
              StationTile(current, onTap: () => exploreFrom(current)),
            ],
            if (mine.isNotEmpty) ...[
              const SectionLabel('Kitaplığından'),
              for (final s in mine) StationTile(s, onTap: () => exploreFrom(s)),
            ],
            if (current == null && mine.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: BrutBox(
                  inverted: true,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  onTap: () => homeTab.value = 2,
                  child: const Text('İSTASYON ARA →'),
                ),
              ),
          ],
        );
      },
    );
  }
}
