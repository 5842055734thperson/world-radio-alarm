import 'package:flutter/material.dart';

import '../app_state.dart';
import '../widgets/station_widgets.dart';

void showPlayer(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const PlayerSheet(),
  );
}

/// Full player: logo, current song, play/stop, favorite and sleep timer.
class PlayerSheet extends StatelessWidget {
  const PlayerSheet({super.key});

  static const _sleepOptions = [15, 30, 45, 60, 90, 120];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([player, favorites]),
      builder: (context, _) {
        final s = player.station;
        if (s == null) return const SizedBox(height: 200);
        final scheme = Theme.of(context).colorScheme;
        final fav = favorites.contains(s);
        final sleepAt = player.sleepAt;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                StationLogo(s, size: 160),
                const SizedBox(height: 20),
                Text(s.name,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text(s.subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.onSurfaceVariant)),
                const SizedBox(height: 16),
                if (player.error != null)
                  Text(player.error!, style: TextStyle(color: scheme.error))
                else if (player.nowPlaying != null)
                  Text('♪ ${player.nowPlaying}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      iconSize: 32,
                      icon: Icon(fav ? Icons.star : Icons.star_border),
                      color: fav ? Colors.amber : null,
                      onPressed: () => favorites.toggle(s),
                    ),
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: player.loading
                          ? const Padding(
                              padding: EdgeInsets.all(20),
                              child: CircularProgressIndicator(),
                            )
                          : IconButton.filled(
                              iconSize: 48,
                              icon: Icon(player.playing
                                  ? Icons.stop_rounded
                                  : Icons.play_arrow_rounded),
                              onPressed: player.toggle,
                            ),
                    ),
                    PopupMenuButton<int>(
                      tooltip: 'Uyku zamanlayıcısı',
                      icon: Icon(
                        sleepAt == null ? Icons.bedtime_outlined : Icons.bedtime,
                        size: 32,
                        color: sleepAt == null ? null : scheme.primary,
                      ),
                      onSelected: (m) => player.setSleepTimer(m == 0 ? null : m),
                      itemBuilder: (_) => [
                        if (sleepAt != null)
                          const PopupMenuItem(value: 0, child: Text('Zamanlayıcıyı kapat')),
                        for (final m in _sleepOptions)
                          PopupMenuItem(value: m, child: Text('$m dakika sonra kapat')),
                      ],
                    ),
                  ],
                ),
                if (sleepAt != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Uyku zamanlayıcısı: ${sleepAt.difference(DateTime.now()).inMinutes + 1} dk sonra kapanacak',
                    style: TextStyle(color: scheme.primary),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
