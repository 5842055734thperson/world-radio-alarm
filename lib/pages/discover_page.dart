import 'dart:async';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/station.dart';
import '../theme.dart';
import '../widgets/brut.dart';
import '../widgets/station_widgets.dart';

class DiscoverPage extends StatelessWidget {
  const DiscoverPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageTitle('Ara'),
        Expanded(child: StationSearch()),
      ],
    );
  }
}

/// All stations of one country (opened from the map).
class CountryStationsPage extends StatelessWidget {
  const CountryStationsPage({super.key, required this.code, required this.name});

  final String code;
  final String name;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${flagEmoji(code)}  ${upper(name)}')),
      body: StationSearch(fixedCountry: code),
    );
  }
}

/// Search box + country + genre filters + endless station list.
/// Used on the search tab, country pages and the alarm station picker ([onSelect]).
class StationSearch extends StatefulWidget {
  const StationSearch({super.key, this.onSelect, this.fixedCountry});

  final ValueChanged<Station>? onSelect;

  /// Locks the list to one country and hides the country picker.
  final String? fixedCountry;

  @override
  State<StationSearch> createState() => _StationSearchState();
}

class _StationSearchState extends State<StationSearch> {
  static const _genres = [
    ('', 'Tümü'),
    ('pop', 'Pop'),
    ('rock', 'Rock'),
    ('news', 'Haber'),
    ('talk', 'Sohbet'),
    ('jazz', 'Caz'),
    ('classical', 'Klasik'),
    ('turkish folk', 'Türk halk'),
    ('arabesk', 'Arabesk'),
    ('dance', 'Dans'),
    ('electronic', 'Elektronik'),
    ('hip-hop', 'Hip-hop'),
    ('chillout', 'Chillout'),
    ('sports', 'Spor'),
    ('religious', 'Dini'),
    ('80s', '80\'ler'),
    ('90s', '90\'lar'),
    ('oldies', 'Nostalji'),
    ('lounge', 'Lounge'),
    ('kids', 'Çocuk'),
  ];

  final _controller = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;

  String _query = '';
  String _genre = '';
  final List<Station> _stations = [];
  bool _loading = false;
  bool _hasMore = true;
  String? _error;
  int _requestId = 0;

  String get _country => widget.fixedCountry ?? favorites.countryCode;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 600) _load();
    });
    _reload();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _reload() {
    _requestId++;
    setState(() {
      _stations.clear();
      _hasMore = true;
      _loading = false;
      _error = null;
    });
    _load();
  }

  Future<void> _load() async {
    if (_loading || !_hasMore) return;
    final id = _requestId;
    setState(() => _loading = true);
    try {
      final page = await api.search(
        name: _query,
        countryCode: _country,
        tag: _genre,
        offset: _stations.length,
      );
      if (id != _requestId || !mounted) return;
      setState(() {
        // Radio Browser has many duplicates (same stream listed twice).
        final seen = _stations.map((s) => s.url).toSet();
        _stations.addAll(page.where((s) => seen.add(s.url)));
        _hasMore = page.length >= 50;
      });
    } catch (e) {
      if (id != _requestId || !mounted) return;
      setState(() => _error = 'İnternet bağlantısını kontrol edin.');
    } finally {
      if (id == _requestId && mounted) setState(() => _loading = false);
    }
  }

  void _onQueryChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _query = q.trim();
      _reload();
    });
  }

  Future<void> _pickCountry() async {
    final picked = await showModalBottomSheet<Country>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CountryPicker(),
    );
    if (picked != null) {
      favorites.setCountry(picked.code, picked.name);
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = favorites.countryCode;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: mono(context, size: 15),
                  decoration: InputDecoration(
                    hintText: 'İSTASYON ADI',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _controller.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _controller.clear();
                              _onQueryChanged('');
                              setState(() {});
                            },
                          ),
                  ),
                  onChanged: (v) {
                    setState(() {});
                    _onQueryChanged(v);
                  },
                ),
              ),
              if (widget.fixedCountry == null) ...[
                const SizedBox(width: 8),
                BrutBox(
                  height: 52,
                  onTap: _pickCountry,
                  tooltip: 'Ülke seç',
                  child: Text(code.isEmpty ? '🌍 TÜMÜ' : '${flagEmoji(code)} $code'),
                ),
              ],
            ],
          ),
        ),
        SizedBox(
          height: 56,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            itemCount: _genres.length,
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (_, i) => BrutChip(
              _genres[i].$2,
              selected: _genre == _genres[i].$1,
              onTap: () {
                _genre = _genres[i].$1;
                _reload();
              },
            ),
          ),
        ),
        Divider(height: kBorder, thickness: kBorder, color: Theme.of(context).colorScheme.onSurface),
        Expanded(child: _buildList()),
      ],
    );
  }

  Widget _buildList() {
    if (_stations.isEmpty) {
      if (_loading) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(upper(_error ?? 'İstasyon bulunamadı.'),
                  textAlign: TextAlign.center, style: mono(context, size: 13)),
              const SizedBox(height: 16),
              if (_error != null) BrutBox(onTap: _reload, inverted: true, child: const Text('TEKRAR DENE')),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: ListView.builder(
        controller: _scroll,
        itemCount: _stations.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == _stations.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          final s = _stations[i];
          final onSelect = widget.onSelect;
          return StationTile(s, onTap: onSelect == null ? null : () => onSelect(s));
        },
      ),
    );
  }
}

class _CountryPicker extends StatefulWidget {
  const _CountryPicker();

  @override
  State<_CountryPicker> createState() => _CountryPickerState();
}

class _CountryPickerState extends State<_CountryPicker> {
  static List<Country>? _cache;
  List<Country>? _countries = _cache;
  String _filter = '';
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    if (_countries == null) _fetch();
  }

  Future<void> _fetch() async {
    try {
      final list = await api.countries();
      _cache = list;
      if (mounted) setState(() => _countries = list);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = _filter.toLowerCase();
    final list = _countries
        ?.where((c) => f.isEmpty || c.name.toLowerCase().contains(f) || c.code.toLowerCase() == f)
        .toList();
    final scheme = Theme.of(context).colorScheme;
    Widget row(String flag, String name, String trailing, VoidCallback onTap) => InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: scheme.onSurface.withValues(alpha: 0.2))),
            ),
            child: Row(
              children: [
                Text(flag, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 12),
                Expanded(child: Text(upper(name), style: const TextStyle(fontWeight: FontWeight.w700))),
                Text(trailing, style: mono(context, size: 11, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        );
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(child: Text('ÜLKE', style: display(context, size: 28))),
                  BrutIconButton(Icons.close, size: 40, onTap: () => Navigator.pop(context)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                style: mono(context, size: 15),
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'ÜLKE ARA (TURKEY, GERMANY…)'),
                onChanged: (v) => setState(() => _filter = v),
              ),
            ),
            row('🌍', 'Tüm dünya', '', () => Navigator.pop(context, const Country('', 'Tüm dünya', 0))),
            Expanded(
              child: list == null
                  ? Center(
                      child: _failed
                          ? Text('ÜLKE LİSTESİ YÜKLENEMEDİ', style: mono(context))
                          : const CircularProgressIndicator(strokeWidth: 2),
                    )
                  : ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (context, i) {
                        final c = list[i];
                        return row(flagEmoji(c.code), c.name, '${c.stationCount}', () => Navigator.pop(context, c));
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
