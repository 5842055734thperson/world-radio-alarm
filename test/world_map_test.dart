import 'package:flutter_test/flutter_test.dart';
import 'package:world_radio/map/world_map_data.dart';
import 'package:world_radio/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('finds the country under a point', () async {
    final map = await WorldMapData.load();
    expect(map.countryAt(32.85, 39.93)?.iso, 'TR'); // Ankara
    expect(map.countryAt(13.40, 52.52)?.iso, 'DE'); // Berlin
    expect(map.countryAt(-30.0, 30.0), isNull); // Atlantic
  });

  test('projection round trip', () {
    final p = WorldMapData.project(29.0, 41.0);
    final (lon, lat) = WorldMapData.unproject(p);
    expect(lon, closeTo(29.0, 1e-9));
    expect(lat, closeTo(41.0, 1e-9));
  });

  test('Turkish upper case', () {
    expect(upper('istanbul ışık'), 'İSTANBUL IŞIK');
  });
}
