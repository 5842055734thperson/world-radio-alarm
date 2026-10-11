import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/station.dart';
import '../theme.dart';

const _grayscale = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0,
]);

/// Square, grayscale station logo with a bordered initials fallback.
class StationLogo extends StatelessWidget {
  const StationLogo(this.station, {super.key, this.size = 52});

  final Station? station;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fg = Theme.of(context).colorScheme.onSurface;
    final initials = Center(
      child: Text(
        _initials(station?.name ?? ''),
        style: label(context, size: size * 0.28, weight: FontWeight.w700),
      ),
    );
    final url = station?.favicon ?? '';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(border: Border.all(color: fg, width: kBorder)),
      child: url.startsWith('http')
          ? ColorFiltered(
              colorFilter: _grayscale,
              child: Image.network(url, fit: BoxFit.cover, errorBuilder: (_, _, _) => initials),
            )
          : initials,
    );
  }

  static String _initials(String name) {
    final words = name.split(RegExp(r'[\s\-_.]+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '◉';
    final s = words.length == 1
        ? words.first.substring(0, words.first.length < 2 ? words.first.length : 2)
        : words[0][0] + words[1][0];
    return upper(s);
  }
}

/// List row: logo, name, mono metadata, favorite toggle.
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
        final scheme = Theme.of(context).colorScheme;
        final current = player.station == station;
        final fav = favorites.contains(station);
        return InkWell(
          onTap: onTap ?? () => player.play(station),
          // Long press: open the Discover feed from this station.
          onLongPress: () => exploreFrom(station),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 4, 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: scheme.onSurface.withValues(alpha: 0.2))),
            ),
            child: Row(
              children: [
                StationLogo(station),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (current) ...[
                            Container(width: 8, height: 8, color: kAccent),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: Text(
                              station.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        upper(stationMeta(station)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: label(context, size: 11, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                trailing ??
                    IconButton(
                      icon: Icon(fav ? Icons.favorite : Icons.favorite_border, size: 22),
                      tooltip: fav ? 'Remove from library' : 'Add to library',
                      onPressed: () => favorites.toggle(station),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// "TR · POP, ROCK · 128K"
String stationMeta(Station s) {
  final parts = <String>[];
  if (s.countryCode.isNotEmpty) parts.add(s.countryCode);
  final t = s.tags.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).take(2).join(', ');
  if (t.isNotEmpty) parts.add(t);
  if (s.bitrate > 0) parts.add('${s.bitrate}K');
  return parts.join(' · ');
}
