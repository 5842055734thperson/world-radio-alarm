import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets/brut.dart';
import '../widgets/station_widgets.dart';

/// Library (under Discover): favorites (drag to reorder), recently played, settings.
class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: favorites,
      builder: (context, _) {
        final favs = favorites.stations;
        final recent = favorites.recent.where((s) => !favorites.contains(s)).take(10).toList();
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: SectionLabel('Favorites · ${favs.length}')),
            if (favs.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    upper('No favorites yet. Tap ♡ next to a station.'),
                    style: label(context, size: 12),
                  ),
                ),
              )
            else
              SliverReorderableList(
                itemCount: favs.length,
                onReorderItem: favorites.reorder,
                itemBuilder: (context, i) => ReorderableDelayedDragStartListener(
                  key: ValueKey(favs[i].uuid),
                  index: i,
                  child: StationTile(favs[i]),
                ),
              ),
            if (recent.isNotEmpty) ...[
              const SliverToBoxAdapter(child: SectionLabel('Recently played')),
              SliverList.builder(
                itemCount: recent.length,
                itemBuilder: (context, i) => StationTile(recent[i]),
              ),
            ],
            const SliverToBoxAdapter(child: SectionLabel('Settings')),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ListenableBuilder(
                  listenable: settings,
                  builder: (context, _) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('THEME', style: label(context, size: 12, weight: FontWeight.w700, spacing: 1)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          for (final (mode, name) in const [
                            (ThemeMode.system, 'Auto'),
                            (ThemeMode.light, 'Light'),
                            (ThemeMode.dark, 'Dark'),
                          ]) ...[
                            BrutChip(name, selected: settings.themeMode == mode, onTap: () => settings.setThemeMode(mode)),
                            const SizedBox(width: 8),
                          ],
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text('TIMESHIFT BUFFER', style: label(context, size: 12, weight: FontWeight.w700, spacing: 1)),
                      const SizedBox(height: 4),
                      Text(
                        upper('Keeps the last minutes of the live stream so you can pause and rewind. '
                            'Uses up to ~30 MB of memory for 30 minutes at 128 kbps.'),
                        style: label(context, size: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          for (final m in const [0, 15, 30]) ...[
                            BrutChip(m == 0 ? 'Off' : '$m min',
                                selected: settings.timeshiftMinutes == m, onTap: () => settings.setTimeshiftMinutes(m)),
                            const SizedBox(width: 8),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        );
      },
    );
  }
}
