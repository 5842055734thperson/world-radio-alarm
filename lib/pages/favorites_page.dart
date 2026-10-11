import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets/brut.dart';
import '../widgets/station_widgets.dart';

/// Library (under Discover): favorites (drag to reorder) and recently played.
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
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        );
      },
    );
  }
}
