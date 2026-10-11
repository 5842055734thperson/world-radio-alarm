import 'package:flutter/material.dart';

import '../app_state.dart';
import '../widgets/station_widgets.dart';
import 'alarms_page.dart';
import 'discover_page.dart';
import 'favorites_page.dart';
import 'player_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  // Start on favorites once the user has some; otherwise on discovery.
  late int _tab = favorites.stations.isEmpty ? 0 : 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // One-shot alarms switch themselves off natively; permissions may change in Settings.
    if (state == AppLifecycleState.resumed) alarms.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: const [DiscoverPage(), FavoritesPage(), AlarmsPage()],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniPlayer(),
          NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.public), label: 'Keşfet'),
              NavigationDestination(
                icon: Icon(Icons.star_border),
                selectedIcon: Icon(Icons.star),
                label: 'Favoriler',
              ),
              NavigationDestination(
                icon: Icon(Icons.alarm_outlined),
                selectedIcon: Icon(Icons.alarm),
                label: 'Alarmlar',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Small "now playing" bar above the navigation; tap for the full player.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        final s = player.station;
        if (s == null) return const SizedBox.shrink();
        final scheme = Theme.of(context).colorScheme;
        return Material(
          color: scheme.surfaceContainerHigh,
          child: InkWell(
            onTap: () => showPlayer(context),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
              child: Row(
                children: [
                  StationLogo(s, size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                          player.error ??
                              (player.loading
                                  ? 'Bağlanıyor…'
                                  : player.nowPlaying ?? s.country),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: player.error != null ? scheme.error : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (player.loading)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                          width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  else
                    IconButton(
                      iconSize: 32,
                      icon: Icon(player.playing ? Icons.stop_rounded : Icons.play_arrow_rounded),
                      onPressed: player.toggle,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
