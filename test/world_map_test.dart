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

  test('Mercator projection', () {
    // equator is symmetric, poles are stretched
    expect(Mercator.y(0), closeTo(0, 1e-9));
    expect(Mercator.y(45), closeTo(-Mercator.y(-45), 1e-9));
    expect(Mercator.y(60), greaterThan(60));
    // map units start at the top-left corner and longitude is linear
    expect(WorldMapData.project(-180, WorldMapData.maxLat).dx, closeTo(0, 1e-9));
    expect(WorldMapData.project(-180, WorldMapData.maxLat).dy, closeTo(0, 1e-9));
    expect(WorldMapData.project(0, 0).dx, 180);
    expect(WorldMapData.project(10, 0).dx - WorldMapData.project(0, 0).dx, closeTo(10, 1e-9));
  });

  test('label upper case', () {
    expect(upper('world radio'), 'WORLD RADIO');
  });
}
