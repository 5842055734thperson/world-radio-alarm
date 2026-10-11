import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/services.dart';

/// Country outlines from assets/world.json (Natural Earth, public domain),
/// in a plain equirectangular projection: x = lon + 180, y = maxLat - lat.
class WorldMapData {
  WorldMapData._(this.countries, this.path);

  /// Latitude range shown (Antarctica and the far Arctic are cut off).
  static const maxLat = 84.0;
  static const minLat = -58.0;
  static const width = 360.0;
  static const height = maxLat - minLat;

  final List<MapCountry> countries;

  /// All outlines in one path, in degree units (see [project]).
  final Path path;

  static WorldMapData? _cache;

  static Future<WorldMapData> load() async {
    if (_cache != null) return _cache!;
    final raw = jsonDecode(await rootBundle.loadString('assets/world.json')) as Map;
    final countries = <MapCountry>[];
    final all = Path();
    for (final c in raw['c'] as List) {
      final rings = <Float32List>[];
      final countryPath = Path();
      var bounds = Rect.zero;
      for (final r in c['r'] as List) {
        final ints = (r as List).cast<int>();
        final ring = Float32List(ints.length);
        for (var i = 0; i < ints.length; i += 2) {
          ring[i] = ints[i] / 100.0; // lon
          ring[i + 1] = ints[i + 1] / 100.0; // lat
        }
        rings.add(ring);
        final pts = <Offset>[
          for (var i = 0; i < ring.length; i += 2) project(ring[i], ring[i + 1]),
        ];
        countryPath.addPolygon(pts, true);
        final b = countryPathBounds(pts);
        bounds = bounds == Rect.zero ? b : bounds.expandToInclude(b);
      }
      all.addPath(countryPath, Offset.zero);
      countries.add(MapCountry(
        iso: c['i'] as String,
        name: c['n'] as String,
        rings: rings,
        path: countryPath,
        bounds: bounds,
      ));
    }
    return _cache = WorldMapData._(countries, all);
  }

  static Rect countryPathBounds(List<Offset> pts) {
    var l = pts.first.dx, t = pts.first.dy, r = l, b = t;
    for (final p in pts) {
      if (p.dx < l) l = p.dx;
      if (p.dx > r) r = p.dx;
      if (p.dy < t) t = p.dy;
      if (p.dy > b) b = p.dy;
    }
    return Rect.fromLTRB(l, t, r, b);
  }

  /// lon/lat (degrees) -> map units.
  static Offset project(double lon, double lat) => Offset(lon + 180, maxLat - lat);

  /// Map units -> (lon, lat).
  static (double, double) unproject(Offset p) => (p.dx - 180, maxLat - p.dy);

  MapCountry? countryAt(double lon, double lat) {
    final p = project(lon, lat);
    for (final c in countries) {
      if (c.bounds.contains(p) && c.contains(lon, lat)) return c;
    }
    return null;
  }
}

class MapCountry {
  MapCountry({
    required this.iso,
    required this.name,
    required this.rings,
    required this.path,
    required this.bounds,
  });

  /// ISO 3166-1 alpha-2 code ('' for disputed areas).
  final String iso;
  final String name;
  final List<Float32List> rings;
  final Path path;
  final Rect bounds;

  /// Ray-casting point-in-polygon over all outer rings.
  bool contains(double lon, double lat) {
    for (final r in rings) {
      var inside = false;
      for (var i = 0, j = r.length - 2; i < r.length; j = i, i += 2) {
        final xi = r[i], yi = r[i + 1], xj = r[j], yj = r[j + 1];
        if ((yi > lat) != (yj > lat) && lon < (xj - xi) * (lat - yi) / (yj - yi) + xi) {
          inside = !inside;
        }
      }
      if (inside) return true;
    }
    return false;
  }
}
