import 'package:flutter/material.dart';

import '../app_state.dart';
import '../widgets/station_widgets.dart';

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListenableBuilder(
        listenable: favorites,
        builder: (context, _) {
          final favs = favorites.stations;
          final recent = favorites.recent.where((s) => !favorites.contains(s)).take(10).toList();
          final header = Theme.of(context).textTheme.titleMedium;
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text('Favoriler', style: Theme.of(context).textTheme.headlineSmall),
                ),
              ),
              if (favs.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Henüz favori yok. Keşfet sekmesinde bir istasyonun yanındaki ☆ işaretine dokunun.',
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
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
                    child: Text('Son dinlenenler', style: header),
                  ),
                ),
                SliverList.builder(
                  itemCount: recent.length,
                  itemBuilder: (context, i) => StationTile(recent[i]),
                ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ],
          );
        },
      ),
    );
  }
}
