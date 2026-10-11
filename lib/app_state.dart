import 'package:flutter/foundation.dart';

import 'models/station.dart';
import 'services/alarms.dart';
import 'services/favorites.dart';
import 'services/geo_stations.dart';
import 'services/player.dart';
import 'services/radio_browser.dart';
import 'services/settings.dart';
import 'services/similar.dart';

// App-wide singletons. The app is small enough that this beats a DI framework.
final RadioBrowser api = RadioBrowser();
late final Favorites favorites;
late final RadioPlayer player;
late final Settings settings;
final GeoStations geoStations = GeoStations(api);
final Alarms alarms = Alarms();
final Similar similar = Similar(api);

/// Selected bottom tab (lets other screens jump to a tab).
final ValueNotifier<int> homeTab = ValueNotifier(0);

/// Starting station of the Discover feed.
final ValueNotifier<Station?> discoverSeed = ValueNotifier(null);

/// Opens the Discover feed starting from [s].
void exploreFrom(Station s) {
  discoverSeed.value = s;
  homeTab.value = 1;
}

Future<void> initAppState() async {
  favorites = await Favorites.load();
  settings = await Settings.load();
  player = RadioPlayer(api, favorites);
  await alarms.refresh();
}
