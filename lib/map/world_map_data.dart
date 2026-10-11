import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/services.dart';

/// World map from assets/world.json (Natural Earth, public domain) in the
/// Equal Earth projection (Šavrič, Patterson & Jenny 2018), an equal-area
/// alternative to Mercator that keeps continents at their true relative size.
///
/// Map units: x in [0, width], y in [0, height], origin top-left.
class WorldMapData {
  WorldMapData._(this.land, this.borders, this.frame, this.countries);

  /// Coastlines: always drawn.
  final Path land;

  /// Country borders: faded in when zooming.
  final Path borders;

  /// Outline of the whole projected globe.
  final Path frame;

  /// Country shapes for hit testing only (projected).
  final List<MapCountry> countries;

  static final double _xMax = EqualEarth.project(math.pi, 0).dx;
  static final double _yMax = EqualEarth.project(0, math.pi / 2).dy;
  static final double width = 2 * _xMax;
  static final double height = 2 * _yMax;

  static WorldMapData? _cache;

  static Future<WorldMapData> load() async {
    if (_cache != null) return _cache!;
    final raw = jsonDecode(await rootBundle.loadString('assets/world.json')) as Map;

    Float32List ring(List r) {
      final ints = r.cast<int>();
      final out = Float32List(ints.length);
      for (var i = 0; i < ints.length; i += 2) {
        final p = project(ints[i] / 100.0, ints[i + 1] / 100.0);
        out[i] = p.dx;
        out[i + 1] = p.dy;
      }
      return out;
    }

    void addTo(Path path, Float32List pts, {required bool close}) {
      path.moveTo(pts[0], pts[1]);
      for (var i = 2; i < pts.length; i += 2) {
        path.lineTo(pts[i], pts[i + 1]);
      }
      if (close) path.close();
    }

    final land = Path();
    for (final r in raw['land'] as List) {
      addTo(land, ring(r as List), close: true);
    }
    final borders = Path();
    for (final r in raw['borders'] as List) {
      addTo(borders, ring(r as List), close: false);
    }
    final frame = Path();
    final edge = <Offset>[
      for (var lat = -90; lat <= 90; lat += 2) project(180, lat.toDouble()),
      for (var lat = 90; lat >= -90; lat -= 2) project(-180, lat.toDouble()),
    ];
    frame.addPolygon(edge, true);

    final countries = <MapCountry>[];
    for (final c in raw['c'] as List) {
      final rings = [for (final r in c['r'] as List) ring(r as List)];
      countries.add(MapCountry(iso: c['i'] as String, name: c['n'] as String, rings: rings));
    }
    return _cache = WorldMapData._(land, borders, frame, countries);
  }

  /// lon/lat (degrees) -> map units.
  static Offset project(double lon, double lat) {
    final p = EqualEarth.project(lon * math.pi / 180, lat * math.pi / 180);
    return Offset(p.dx + _xMax, _yMax - p.dy);
  }

  /// Country containing a point given in map units, if any.
  MapCountry? countryAt(Offset p) {
    for (final c in countries) {
      if (c.contains(p)) return c;
    }
    return null;
  }
}

/// Equal Earth projection on the unit sphere.
abstract final class EqualEarth {
  static const _a1 = 1.340264, _a2 = -0.081106, _a3 = 0.000893, _a4 = 0.003796;
  static final _m = math.sqrt(3) / 2;

  /// (lambda, phi) in radians -> (x, y), y pointing north.
  static Offset project(double lambda, double phi) {
    final t = math.asin(_m * math.sin(phi));
    final t2 = t * t, t6 = t2 * t2 * t2;
    final x = lambda * math.cos(t) / (_m * (_a1 + 3 * _a2 * t2 + t6 * (7 * _a3 + 9 * _a4 * t2)));
    final y = t * (_a1 + _a2 * t2 + t6 * (_a3 + _a4 * t2));
    return Offset(x, y);
  }
}

class MapCountry {
  MapCountry({required this.iso, required this.name, required this.rings}) {
    final path = Path();
    var l = double.infinity, t = double.infinity, r = -double.infinity, b = -double.infinity;
    for (final ring in rings) {
      path.moveTo(ring[0], ring[1]);
      for (var i = 0; i < ring.length; i += 2) {
        final x = ring[i], y = ring[i + 1];
        if (i > 0) path.lineTo(x, y);
        l = math.min(l, x);
        r = math.max(r, x);
        t = math.min(t, y);
        b = math.max(b, y);
      }
      path.close();
    }
    this.path = path;
    bounds = Rect.fromLTRB(l, t, r, b);
  }

  /// ISO 3166-1 alpha-2 code ('' for disputed areas).
  final String iso;
  final String name;

  /// Projected outer rings (flattened x, y pairs in map units).
  final List<Float32List> rings;
  late final Path path;
  late final Rect bounds;

  /// Ray-casting point-in-polygon in map units.
  bool contains(Offset p) {
    if (!bounds.contains(p)) return false;
    for (final r in rings) {
      var inside = false;
      for (var i = 0, j = r.length - 2; i < r.length; j = i, i += 2) {
        final xi = r[i], yi = r[i + 1], xj = r[j], yj = r[j + 1];
        if ((yi > p.dy) != (yj > p.dy) && p.dx < (xj - xi) * (p.dy - yi) / (yj - yi) + xi) {
          inside = !inside;
        }
      }
      if (inside) return true;
    }
    return false;
  }
}
