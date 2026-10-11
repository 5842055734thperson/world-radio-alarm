import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../models/station.dart';

/// Client for the free Radio Browser API (https://www.radio-browser.info).
///
/// The service has outages, so every query falls back to an offline catalog:
/// a snapshot of popular stations bundled into the app at build time
/// (assets/stations.json) plus any stations cached on the device. [offline]
/// tells whether the last answer came from that catalog.
class RadioBrowser {
  RadioBrowser() {
    _servers.shuffle(Random());
    _servers.add('https://all.api.radio-browser.info'); // DNS round robin, last resort
  }

  final List<String> _servers = [
    'https://de1.api.radio-browser.info',
    'https://de2.api.radio-browser.info',
  ];

  /// True when the radio directory could not be reached and results come from
  /// the offline catalog.
  bool offline = false;

  final Map<String, Station> _catalog = {};
  DateTime? _downUntil;

  /// Adds stations to the offline catalog (bundled snapshot, cached map data).
  void addToCatalog(Iterable<Station> stations) {
    for (final s in stations) {
      if (s.uuid.isNotEmpty && s.url.isNotEmpty) _catalog.putIfAbsent(s.uuid, () => s);
    }
  }

  /// Loads the snapshot bundled at build time. Safe to call without awaiting.
  Future<void> loadSnapshot() async {
    try {
      final raw = jsonDecode(await rootBundle.loadString('assets/stations.json')) as List;
      addToCatalog(raw.map((e) => Station.fromApi((e as Map).cast<String, dynamic>())));
    } catch (_) {}
  }

  int get catalogSize => _catalog.length;

  static const _headers = {'User-Agent': 'WorldRadioAlarm/1.0'};

  Future<dynamic> _get(
    String path, [
    Map<String, String>? query,
    Duration timeout = const Duration(seconds: 8),
  ]) async {
    // After a full failure, don't make every screen wait for timeouts again.
    final down = _downUntil;
    if (down != null && DateTime.now().isBefore(down)) {
      throw Exception('radio directory unreachable');
    }
    Object? lastError;
    for (final server in List.of(_servers)) {
      try {
        final uri = Uri.parse('$server$path').replace(queryParameters: query);
        final res = await http
            .get(uri, headers: _headers)
            .timeout(timeout);
        if (res.statusCode == 200) {
          // Prefer the server that worked next time.
          _servers
            ..remove(server)
            ..insert(0, server);
          _downUntil = null;
          offline = false;
          return jsonDecode(utf8.decode(res.bodyBytes));
        }
        lastError = 'HTTP ${res.statusCode}';
      } catch (e) {
        lastError = e;
      }
    }
    _downUntil = DateTime.now().add(const Duration(minutes: 1));
    throw Exception('Could not reach the radio directory ($lastError)');
  }

  /// Runs [online]; if the directory is unreachable, answers from the catalog.
  Future<T> _orOffline<T>(Future<T> Function() online, T Function(List<Station> catalog) fallback) async {
    try {
      return await online();
    } catch (_) {
      if (_catalog.isEmpty) rethrow;
      offline = true;
      return fallback(_catalog.values.toList());
    }
  }

  Future<List<Station>> search({
    String name = '',
    String countryCode = '',
    String tag = '',
    String language = '',
    int offset = 0,
    int limit = 50,
  }) async {
    final q = <String, String>{
      'hidebroken': 'true',
      'order': 'clickcount',
      'reverse': 'true',
      'offset': '$offset',
      'limit': '$limit',
    };
    if (name.isNotEmpty) q['name'] = name;
    if (countryCode.isNotEmpty) q['countrycode'] = countryCode;
    if (tag.isNotEmpty) q['tag'] = tag;
    if (language.isNotEmpty) q['language'] = language;
    return _orOffline(() async {
      final data = await _get('/json/stations/search', q) as List;
      return data
          .map((e) => Station.fromApi((e as Map).cast<String, dynamic>()))
          .where((s) => s.url.isNotEmpty && s.name.isNotEmpty)
          .toList();
    }, (catalog) {
      final n = name.toLowerCase(), t = tag.toLowerCase(), l = language.toLowerCase();
      // The snapshot is stored most-popular first, like the API's ordering.
      return catalog
          .where((s) =>
              (n.isEmpty || s.name.toLowerCase().contains(n)) &&
              (countryCode.isEmpty || s.countryCode == countryCode) &&
              (t.isEmpty || s.tags.toLowerCase().contains(t)) &&
              (l.isEmpty || s.language.toLowerCase().contains(l)))
          .skip(offset)
          .take(limit)
          .toList();
    });
  }

  /// The most popular stations that have coordinates, for the map.
  Future<List<Station>> geoStations({int limit = 4000}) => _orOffline(() async {
    final data = await _get('/json/stations/search', {
      'has_geo_info': 'true',
      'hidebroken': 'true',
      'order': 'clickcount',
      'reverse': 'true',
      'limit': '$limit',
    }, const Duration(seconds: 40)) as List;
    return data
        .map((e) => Station.fromApi((e as Map).cast<String, dynamic>()))
        .where((s) => s.url.isNotEmpty && s.name.isNotEmpty && s.hasGeo)
        .toList();
  }, (catalog) => catalog.where((s) => s.hasGeo).take(limit).toList());

  Future<List<Country>> countries() => _orOffline(() async {
    final data = await _get('/json/countries', {'hidebroken': 'true'}) as List;
    final list = data
        .map((e) => Country(
              (e['iso_3166_1'] ?? '').toString(),
              (e['name'] ?? '').toString(),
              (e['stationcount'] ?? 0) as int,
            ))
        .where((c) => c.code.length == 2 && c.stationCount > 0)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return list;
  }, (catalog) {
    final counts = <String, int>{};
    final names = <String, String>{};
    for (final s in catalog) {
      if (s.countryCode.length != 2) continue;
      counts[s.countryCode] = (counts[s.countryCode] ?? 0) + 1;
      names.putIfAbsent(s.countryCode, () => s.country.isEmpty ? s.countryCode : s.country);
    }
    return [for (final e in counts.entries) Country(e.key, names[e.key]!, e.value)]
      ..sort((a, b) => a.name.compareTo(b.name));
  });

  /// Tells Radio Browser a station was played (keeps popularity ranking useful).
  Future<void> registerClick(String uuid) async {
    if (offline) return;
    try {
      await _get('/json/url/$uuid');
    } catch (_) {}
  }
}
