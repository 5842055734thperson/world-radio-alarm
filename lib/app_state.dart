import 'services/alarms.dart';
import 'services/favorites.dart';
import 'services/geo_stations.dart';
import 'services/player.dart';
import 'services/radio_browser.dart';
import 'services/settings.dart';

// App-wide singletons. The app is small enough that this beats a DI framework.
final RadioBrowser api = RadioBrowser();
late final Favorites favorites;
late final RadioPlayer player;
late final Settings settings;
final GeoStations geoStations = GeoStations(api);
final Alarms alarms = Alarms();

Future<void> initAppState() async {
  favorites = await Favorites.load();
  settings = await Settings.load();
  player = RadioPlayer(api, favorites);
  await alarms.refresh();
}
