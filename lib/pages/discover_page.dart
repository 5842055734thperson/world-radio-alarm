import 'dart:async';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/station.dart';
import '../widgets/station_widgets.dart';

class DiscoverPage extends StatelessWidget {
  const DiscoverPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SafeArea(child: StationSearch());
  }
}

/// Search box + country + genre filters + endless station list.
/// Used on the Discover tab and in the alarm station picker ([onSelect]).
class StationSearch extends StatefulWidget {
  const StationSearch({super.key, this.onSelect});

  final ValueChanged<Station>? onSelect;

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
        countryCode: favorites.countryCode,
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
      showDragHandle: true,
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
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: SearchBar(
                  controller: _controller,
                  hintText: 'İstasyon ara',
                  leading: const Icon(Icons.search),
                  trailing: [
                    if (_controller.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _controller.clear();
                          _onQueryChanged('');
                        },
                      ),
                  ],
                  onChanged: _onQueryChanged,
                ),
              ),
              const SizedBox(width: 8),
              ActionChip(
                avatar: Text(code.isEmpty ? '🌍' : flagEmoji(code)),
                label: Text(code.isEmpty ? 'Dünya' : code),
                onPressed: _pickCountry,
              ),
            ],
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final (tag, label) in _genres)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(label),
                    selected: _genre == tag,
                    onSelected: (_) {
                      _genre = tag;
                      _reload();
                    },
                  ),
                ),
            ],
          ),
        ),
        Expanded(child: _buildList()),
      ],
    );
  }

  Widget _buildList() {
    if (_stations.isEmpty) {
      if (_loading) return const Center(child: CircularProgressIndicator());
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error ?? 'İstasyon bulunamadı.', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              if (_error != null)
                FilledButton(onPressed: _reload, child: const Text('Tekrar dene')),
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
              child: Center(child: CircularProgressIndicator()),
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
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.8,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Ülke ara (ör. Turkey, Germany)',
              ),
              onChanged: (v) => setState(() => _filter = v),
            ),
          ),
          ListTile(
            leading: const Text('🌍', style: TextStyle(fontSize: 24)),
            title: const Text('Tüm dünya'),
            onTap: () => Navigator.pop(context, const Country('', 'Tüm dünya', 0)),
          ),
          const Divider(height: 1),
          Expanded(
            child: list == null
                ? Center(
                    child: _failed
                        ? const Text('Ülke listesi yüklenemedi.')
                        : const CircularProgressIndicator(),
                  )
                : ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final c = list[i];
                      return ListTile(
                        leading: Text(flagEmoji(c.code), style: const TextStyle(fontSize: 24)),
                        title: Text(c.name),
                        trailing: Text('${c.stationCount}'),
                        onTap: () => Navigator.pop(context, c),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
