import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/station.dart';

/// Station favicon with a radio icon fallback (many favicons are missing or broken).
class StationLogo extends StatelessWidget {
  const StationLogo(this.station, {super.key, this.size = 48});

  final Station? station;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fallback = Container(
      width: size,
      height: size,
      color: scheme.primaryContainer,
      child: Icon(Icons.radio, size: size * 0.55, color: scheme.onPrimaryContainer),
    );
    final url = station?.favicon ?? '';
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.2),
      child: url.startsWith('http')
          ? Image.network(
              url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback,
            )
          : fallback,
    );
  }
}

/// List row for a station: tap to play, star to (un)favorite.
class StationTile extends StatelessWidget {
  const StationTile(this.station, {super.key, this.onTap, this.trailing});

  final Station station;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([player, favorites]),
      builder: (context, _) {
        final isCurrent = player.station == station;
        final fav = favorites.contains(station);
        return ListTile(
          leading: StationLogo(station),
          title: Text(
            station.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: isCurrent
                ? TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  )
                : null,
          ),
          subtitle: Text(station.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: onTap ?? () => player.play(station),
          trailing: trailing ??
              IconButton(
                icon: Icon(fav ? Icons.star : Icons.star_border),
                color: fav ? Colors.amber : null,
                tooltip: fav ? 'Favorilerden çıkar' : 'Favorilere ekle',
                onPressed: () => favorites.toggle(station),
              ),
        );
      },
    );
  }
}
