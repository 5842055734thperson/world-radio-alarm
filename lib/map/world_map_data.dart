import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/services.dart';

/// World map from assets/world.json (Natural Earth, public domain) in the
/// Mercator projection, which tiles seamlessly when the map repeats sideways.
/// Latitudes are cut at [minLat] (Antarctica is left out) and [maxLat].
///
/// Map units: degrees of longitude; x in [0, width], y in [0, height], origin top-left.
class WorldMapData {
  WorldMapData._(this.land, this.borders, this.countries);

  /// Coastlines: always drawn.
  final Path land;

  /// Country borders: faded in when zooming.
  final Path borders;

  /// Country shapes for hit testing only (projected).
  final List<MapCountry> countries;

  static const maxLat = 84.0;
  static const minLat = -58.0;
  static const width = 360.0;
  static final double _top = Mercator.y(maxLat);
  static final double height = _top - Mercator.y(minLat);

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

    // Lines entirely south of the cut (Antarctica) are skipped.
    bool southOfMap(List r) {
      for (var i = 1; i < r.length; i += 2) {
        if ((r[i] as int) / 100.0 > minLat) return false;
      }
      return true;
    }

    final land = Path();
    for (final r in raw['land'] as List) {
      if (southOfMap(r as List)) continue;
      addTo(land, ring(r), close: false);
    }
    final borders = Path();
    for (final r in raw['borders'] as List) {
      addTo(borders, ring(r as List), close: false);
    }
    final countries = <MapCountry>[];
    for (final c in raw['c'] as List) {
      final rings = [for (final r in c['r'] as List) ring(r as List)];
      countries.add(MapCountry(iso: c['i'] as String, name: c['n'] as String, rings: rings));
    }
    return _cache = WorldMapData._(land, borders, countries);
  }

  /// lon/lat (degrees) -> map units.
  static Offset project(double lon, double lat) => Offset(lon + 180, _top - Mercator.y(lat));

  /// Country containing a point given in map units, if any.
  MapCountry? countryAt(Offset p) {
    for (final c in countries) {
      if (c.contains(p)) return c;
    }
    return null;
  }
}

/// Spherical Mercator, scaled so one unit of y equals one degree of longitude
/// at the equator.
abstract final class Mercator {
  /// Northing of [lat] (degrees), clamped to ±85° where the projection explodes.
  static double y(double lat) {
    final phi = lat.clamp(-85.0, 85.0) * math.pi / 180;
    return math.log(math.tan(math.pi / 4 + phi / 2)) * 180 / math.pi;
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
