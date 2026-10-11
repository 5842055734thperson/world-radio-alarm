import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets/brut.dart';
import '../widgets/station_widgets.dart';
import 'alarms_page.dart';
import 'discover_page.dart';
import 'discover_hub.dart';
import 'map_page.dart';
import 'player_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  static const _tabs = [
    (Icons.public, 'MAP'),
    (Icons.hub_outlined, 'DISCOVER'),
    (Icons.search, 'SEARCH'),
    (Icons.alarm, 'ALARM'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    homeTab.addListener(_onTab);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    homeTab.removeListener(_onTab);
    super.dispose();
  }

  void _onTab() => setState(() {});

  int get _tab => homeTab.value;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // One-shot alarms switch themselves off natively; permissions may change in Settings.
    if (state == AppLifecycleState.resumed) alarms.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _tab,
          children: const [MapPage(), DiscoverHub(), DiscoverPage(), AlarmsPage()],
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniPlayer(),
          Container(
            decoration: BoxDecoration(
              color: scheme.surface,
              border: Border(top: BorderSide(color: scheme.onSurface, width: kBorder)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  for (var i = 0; i < _tabs.length; i++)
                    Expanded(
                      child: InkWell(
                        onTap: () => homeTab.value = i,
                        child: Container(
                          height: 60,
                          color: i == _tab ? scheme.onSurface : null,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(_tabs[i].$1,
                                  size: 20, color: i == _tab ? scheme.surface : scheme.onSurface),
                              const SizedBox(height: 4),
                              Text(
                                _tabs[i].$2,
                                style: label(context,
                                    size: 10,
                                    weight: FontWeight.w700,
                                    spacing: 1,
                                    color: i == _tab ? scheme.surface : scheme.onSurface),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Now playing" bar above the tabs; tap for the full player.
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
        final behind = player.canTimeshift && !player.isLive ? '${formatBehind(player.behindSeconds)} · ' : '';
        final status = player.error ??
            (player.loading
                ? 'CONNECTING…'
                : behind + (player.nowPlaying ?? (player.playing ? 'LIVE' : player.canTimeshift ? 'PAUSED' : 'STOPPED')));
        return Material(
          color: scheme.surface,
          child: InkWell(
            onTap: () => showPlayer(context),
            child: Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: scheme.onSurface, width: kBorder)),
              ),
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  StationLogo(s, size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                        const SizedBox(height: 2),
                        Text(
                          upper(status),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: label(context,
                              size: 11, color: player.error != null ? scheme.error : scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  player.loading
                      ? const SizedBox(
                          width: 44,
                          height: 44,
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : BrutIconButton(
                          player.playing ? Icons.stop : Icons.play_arrow,
                          accent: true,
                          tooltip: player.playing ? 'Stop' : 'Play',
                          onTap: player.toggle,
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
