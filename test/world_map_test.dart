import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:world_radio/map/world_map_data.dart';
import 'package:world_radio/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('finds the country under a point', () async {
    final map = await WorldMapData.load();
    expect(map.countryAt(WorldMapData.project(32.85, 39.93))?.iso, 'TR'); // Ankara
    expect(map.countryAt(WorldMapData.project(13.40, 52.52))?.iso, 'DE'); // Berlin
    expect(map.countryAt(WorldMapData.project(-30.0, 30.0)), isNull); // Atlantic
  });

  test('Equal Earth matches the published reference values', () {
    // Šavrič et al. 2018: on the unit sphere the map is 2 * 2.7066 wide, 2 * 1.3173 tall.
    final edge = EqualEarth.project(math.pi, 0);
    final pole = EqualEarth.project(0, math.pi / 2);
    expect(edge.dx, closeTo(2.7066, 1e-3));
    expect(pole.dy, closeTo(1.3173, 1e-3));
    // map units start at the top-left corner
    expect(WorldMapData.project(-180, 0).dx, closeTo(0, 1e-9));
    expect(WorldMapData.project(0, 90).dy, closeTo(0, 1e-9));
  });

  test('label upper case', () {
    expect(upper('world radio'), 'WORLD RADIO');
  });
}
