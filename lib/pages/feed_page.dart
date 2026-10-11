import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/station.dart';
import '../services/similar.dart';
import '../theme.dart';
import '../widgets/brut.dart';
import '../widgets/station_widgets.dart';

/// Discovery feed, inspired by everynoise.com: an endless stack of station
/// "catalogue cards". Swipe up for the next related station; each card says
/// which station it came from and what they share. The path keeps branching:
/// related stations of the card you are on are appended as you go, alternating
/// the same country and other countries.
class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

/// One catalogue card: a station plus how we got to it.
class _Card {
  _Card(this.station, {this.via, this.shared = const {}});

  final Station station;
  final Station? via;
  final Set<String> shared;

  bool get abroad => via != null && via!.countryCode != station.countryCode;
}

class _FeedPageState extends State<FeedPage> {
  final _pages = PageController();
  final List<_Card> _cards = [];
  final Set<String> _expanded = {};
  bool _loading = false;
  int _current = 0;
  Timer? _autoplay;

  @override
  void initState() {
    super.initState();
    discoverSeed.addListener(_onSeed);
    _onSeed();
  }

  @override
  void dispose() {
    discoverSeed.removeListener(_onSeed);
    _autoplay?.cancel();
    _pages.dispose();
    super.dispose();
  }

  void _onSeed() {
    final seed = discoverSeed.value;
    if (seed == null) {
      setState(_cards.clear);
      return;
    }
    if (_cards.isNotEmpty && _cards.first.station == seed) return;
    setState(() {
      _cards
        ..clear()
        ..add(_Card(seed));
      _expanded.clear();
      _current = 0;
    });
    if (_pages.hasClients) _pages.jumpToPage(0);
    _more(0);
  }

  /// Appends stations related to the card at [index] (or the next card that
  /// has not been branched from yet).
  Future<void> _more(int index) async {
    if (_loading || _cards.isEmpty) return;
    var i = index.clamp(0, _cards.length - 1);
    while (i < _cards.length && _expanded.contains(_cards[i].station.uuid)) {
      i++;
    }
    if (i >= _cards.length) return;
    final source = _cards[i].station;
    _expanded.add(source.uuid);
    setState(() => _loading = true);
    final related = await similar.related(source, exclude: {for (final c in _cards) c.station.uuid});
    if (!mounted || discoverSeed.value != _cards.firstOrNull?.station) return;
    // Alternate home country / abroad so the path keeps crossing borders.
    final same = related.where((s) => s.countryCode == source.countryCode).toList();
    final other = related.where((s) => s.countryCode != source.countryCode).toList();
    final mixed = <Station>[];
    for (var k = 0; k < math.max(same.length, other.length); k++) {
      if (k < same.length) mixed.add(same[k]);
      if (k < other.length) mixed.add(other[k]);
    }
    final seedTags = source.tagSet;
    setState(() {
      _loading = false;
      _cards.addAll(mixed.map((s) => _Card(s, via: source, shared: seedTags.intersection(s.tagSet))));
    });
    // Nothing related: branch from the next card instead.
    if (mixed.isEmpty) _more(i + 1);
  }

  void _onPage(int i) {
    _current = i;
    if (i >= _cards.length - 3) _more(i);
    _autoplay?.cancel();
    if (i < _cards.length) {
      // Play once the user stops on a card.
      _autoplay = Timer(const Duration(milliseconds: 550), () {
        if (mounted && _current == i) player.play(_cards[i].station);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cards.isEmpty) return const _SeedPicker();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageTitle(
          'Discover',
          trailing: BrutIconButton(Icons.refresh, size: 40, tooltip: 'New start', onTap: () => discoverSeed.value = null),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Text(upper('From ${_cards.first.station.name} · swipe ↑ for the next station'),
              maxLines: 1, overflow: TextOverflow.ellipsis, style: mono(context, size: 11, spacing: 1)),
        ),
        Expanded(
          child: PageView.builder(
            controller: _pages,
            scrollDirection: Axis.vertical,
            onPageChanged: _onPage,
            itemCount: _cards.length + 1,
            itemBuilder: (context, i) => _CatalogueTransition(
              controller: _pages,
              index: i,
              child: i < _cards.length
                  ? _CatalogueCard(card: _cards[i], number: i + 1)
                  : _EndCard(loading: _loading, onRetry: () => _more(_cards.length - 1)),
            ),
          ),
        ),
      ],
    );
  }
}

/// Card-catalogue drawer motion: the card you leave sinks back and stays put,
/// the next one flips up from below like a card in an index drawer.
class _CatalogueTransition extends StatelessWidget {
  const _CatalogueTransition({required this.controller, required this.index, required this.child});

  final PageController controller;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (context, child) {
        var page = index.toDouble();
        if (controller.hasClients && controller.position.haveDimensions) {
          page = controller.page ?? page;
        }
        final delta = (index - page).clamp(-1.0, 1.0); // <0 leaving upward, >0 coming in
        return LayoutBuilder(builder: (context, c) {
          final h = c.maxHeight;
          final Matrix4 m;
          double opacity = 1;
          if (delta < 0) {
            // Leaving: pin in place, shrink and lift slightly, fade.
            final t = -delta;
            m = Matrix4.identity()
              ..translateByDouble(0, h * t - 28 * t, 0, 1)
              ..translateByDouble(c.maxWidth / 2, h / 2, 0, 1)
              ..scaleByDouble(1 - 0.12 * t, 1 - 0.12 * t, 1, 1)
              ..translateByDouble(-c.maxWidth / 2, -h / 2, 0, 1);
            opacity = 1 - 0.75 * t;
          } else {
            // Arriving: tilt back around its top edge and straighten as it rises.
            final t = delta;
            m = Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateX(-0.9 * Curves.easeIn.transform(t));
          }
          return Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Transform(
              transform: m,
              alignment: delta < 0 ? Alignment.topLeft : Alignment.topCenter,
              child: child,
            ),
          );
        });
      },
    );
  }
}

/// A station's "künye": catalogue card with its credits.
class _CatalogueCard extends StatelessWidget {
  const _CatalogueCard({required this.card, required this.number});

  final _Card card;
  final int number;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = card.station;
    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 92, child: Text(label, style: mono(context, size: 11, color: scheme.onSurfaceVariant, spacing: 1))),
              Expanded(
                child: Text(upper(value.isEmpty ? '—' : value),
                    maxLines: 2, overflow: TextOverflow.ellipsis, style: mono(context, size: 12, weight: FontWeight.w700)),
              ),
            ],
          ),
        );
    final tags = Similar.displayTags(s);
    final format = [if (s.codec.isNotEmpty) s.codec, if (s.bitrate > 0) '${s.bitrate} kbps'].join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 22, 22),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border.all(color: scheme.onSurface, width: kBorder),
          boxShadow: [BoxShadow(color: scheme.onSurface, offset: const Offset(6, 6))],
        ),
        padding: const EdgeInsets.all(16),
        child: ListenableBuilder(
          listenable: Listenable.merge([player, favorites]),
          builder: (context, _) {
            final current = player.station == s;
            final fav = favorites.contains(s);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('No. ${number.toString().padLeft(3, '0')}',
                        style: mono(context, size: 12, weight: FontWeight.w700, spacing: 1)),
                    const Spacer(),
                    Text(
                      current ? (player.loading ? '◌ TUNING' : player.playing ? '● ON AIR' : '○ PAUSED') : '',
                      style: mono(context, size: 12, weight: FontWeight.w700, spacing: 1),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    StationLogo(s, size: 72),
                    const Spacer(),
                    Text(flagEmoji(s.countryCode), style: const TextStyle(fontSize: 36)),
                  ],
                ),
                const SizedBox(height: 14),
                Text(upper(s.name), maxLines: 3, overflow: TextOverflow.ellipsis, style: display(context, size: 34)),
                const SizedBox(height: 12),
                Divider(color: scheme.onSurface, thickness: kBorder, height: kBorder),
                const SizedBox(height: 6),
                row('COUNTRY', s.country),
                row('LANGUAGE', s.language.replaceAll(',', ', ')),
                row('GENRE', tags.join(' · ')),
                row('FORMAT', format),
                if (card.via != null) ...[
                  const SizedBox(height: 6),
                  Divider(color: scheme.onSurface, thickness: 1, height: 1),
                  const SizedBox(height: 6),
                  row('VIA', '${card.via!.name} (${card.via!.countryCode})'),
                  row('LINK', [
                    card.abroad ? 'Abroad' : 'Same country',
                    if (card.shared.isNotEmpty) 'shares ${card.shared.take(3).join(', ')}',
                  ].join(' · ')),
                ],
                const Spacer(),
                Row(
                  children: [
                    BrutIconButton(fav ? Icons.favorite : Icons.favorite_border,
                        size: 52, tooltip: fav ? 'Remove from library' : 'Add to library', onTap: () => favorites.toggle(s)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: BrutBox(
                        height: 52,
                        inverted: true,
                        onTap: () => current && player.playing ? player.stop() : player.play(s),
                        child: Text(current && player.playing ? '■ STOP' : '▶ PLAY'),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _EndCard extends StatelessWidget {
  const _EndCard({required this.loading, required this.onRetry});

  final bool loading;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 22, 22),
      child: Container(
        decoration: BoxDecoration(border: Border.all(color: scheme.onSurface, width: kBorder)),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: loading
            ? Text('PULLING THE NEXT CARDS…', style: mono(context, size: 12, spacing: 1))
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('END OF THE DRAWER', style: mono(context, size: 12, spacing: 1)),
                  const SizedBox(height: 16),
                  BrutBox(onTap: onRetry, child: const Text('FIND MORE')),
                ],
              ),
      ),
    );
  }
}

/// Shown until a starting station is chosen.
class _SeedPicker extends StatelessWidget {
  const _SeedPicker();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([player, favorites]),
      builder: (context, _) {
        final current = player.station;
        final mine = [
          ...favorites.stations,
          ...favorites.recent.where((s) => !favorites.contains(s)),
        ].where((s) => s != current).take(12).toList();
        return ListView(
          children: [
            const PageTitle('Discover'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                upper('Pick a starting station. Swipe through related stations — '
                    'from the same country and from abroad.'),
                style: mono(context, size: 12),
              ),
            ),
            if (current != null) ...[
              const SectionLabel('Now playing'),
              StationTile(current, onTap: () => exploreFrom(current)),
            ],
            if (mine.isNotEmpty) ...[
              const SectionLabel('From your library'),
              for (final s in mine) StationTile(s, onTap: () => exploreFrom(s)),
            ],
            if (current == null && mine.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: BrutBox(
                  inverted: true,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  onTap: () => homeTab.value = 2,
                  child: const Text('SEARCH STATIONS →'),
                ),
              ),
          ],
        );
      },
    );
  }
}
