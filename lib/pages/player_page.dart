import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets/brut.dart';
import '../widgets/station_widgets.dart';

void showPlayer(BuildContext context) {
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, _, _) => const PlayerPage(),
      transitionsBuilder: (_, a, _, child) => SlideTransition(
        position: Tween(begin: const Offset(0, 1), end: Offset.zero)
            .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
        child: child,
      ),
    ),
  );
}

/// Full-screen "now playing": big square artwork, huge title, square controls.
class PlayerPage extends StatelessWidget {
  const PlayerPage({super.key});

  static const _sleepOptions = [15, 30, 45, 60, 90, 120];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([player, favorites]),
          builder: (context, _) {
            final s = player.station;
            if (s == null) return const SizedBox.shrink();
            final scheme = Theme.of(context).colorScheme;
            final fav = favorites.contains(s);
            final sleepAt = player.sleepAt;
            return LayoutBuilder(builder: (context, c) {
              final art = (c.maxWidth - 32).clamp(120.0, c.maxHeight * 0.42);
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        BrutIconButton(Icons.keyboard_arrow_down,
                            size: 40, tooltip: 'Close', onTap: () => Navigator.pop(context)),
                        const Spacer(),
                        Text(player.playing ? '● LIVE' : '○ STOPPED',
                            style: mono(context, size: 12, weight: FontWeight.w700, spacing: 2)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Center(child: StationLogo(s, size: art)),
                    const SizedBox(height: 20),
                    Text(
                      upper(s.name),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: display(context, size: 34),
                    ),
                    const SizedBox(height: 8),
                    Text(upper([s.country, stationMeta(s)].where((e) => e.isNotEmpty).join(' · ')),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: mono(context, size: 11, color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 12),
                    if (player.error != null)
                      Text(upper(player.error!), style: mono(context, size: 12, color: scheme.error))
                    else if (player.nowPlaying != null)
                      Text('NOW: ${upper(player.nowPlaying!)}',
                          maxLines: 2, overflow: TextOverflow.ellipsis, style: mono(context, size: 13)),
                    const Spacer(),
                    Row(
                      children: [
                        BrutIconButton(
                          fav ? Icons.favorite : Icons.favorite_border,
                          size: 56,
                          tooltip: fav ? 'Remove from library' : 'Add to library',
                          onTap: () => favorites.toggle(s),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: BrutBox(
                            height: 72,
                            inverted: true,
                            onTap: player.loading ? null : player.toggle,
                            child: player.loading
                                ? SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: scheme.surface),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(player.playing ? Icons.stop : Icons.play_arrow, size: 32),
                                      const SizedBox(width: 8),
                                      Text(player.playing ? 'STOP' : 'PLAY', style: const TextStyle(fontSize: 18)),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _SleepButton(sleepAt: sleepAt),
                      ],
                    ),
                    const SizedBox(height: 12),
                    BrutBox(
                      height: 52,
                      onTap: () {
                        Navigator.pop(context);
                        exploreFrom(s);
                      },
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.hub_outlined, size: 20),
                          SizedBox(width: 8),
                          Text('DISCOVER SIMILAR STATIONS →'),
                        ],
                      ),
                    ),
                    if (sleepAt != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        'SLEEP TIMER · ${sleepAt.difference(DateTime.now()).inMinutes + 1} MIN',
                        style: mono(context, size: 12, weight: FontWeight.w700),
                      ),
                    ],
                  ],
                ),
              );
            });
          },
        ),
      ),
    );
  }
}

class _SleepButton extends StatelessWidget {
  const _SleepButton({required this.sleepAt});

  final DateTime? sleepAt;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: 'Sleep timer',
      onSelected: (m) => player.setSleepTimer(m == 0 ? null : m),
      itemBuilder: (_) => [
        if (sleepAt != null) const PopupMenuItem(value: 0, child: Text('OFF')),
        for (final m in PlayerPage._sleepOptions) PopupMenuItem(value: m, child: Text('IN $m MIN')),
      ],
      child: BrutBox(
        width: 56,
        height: 56,
        padding: EdgeInsets.zero,
        inverted: sleepAt != null,
        child: const Icon(Icons.bedtime_outlined, size: 26),
      ),
    );
  }
}
