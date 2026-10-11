import 'services/alarms.dart';
import 'services/favorites.dart';
import 'services/player.dart';
import 'services/radio_browser.dart';

// App-wide singletons. The app is small enough that this beats a DI framework.
final RadioBrowser api = RadioBrowser();
late final Favorites favorites;
late final RadioPlayer player;
final Alarms alarms = Alarms();

Future<void> initAppState() async {
  favorites = await Favorites.load();
  player = RadioPlayer(api, favorites);
  await alarms.refresh();
}
