import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../models/station.dart';

/// Minimal client for the free Radio Browser API (https://www.radio-browser.info).
/// Tries several mirror servers so one being down does not break the app.
class RadioBrowser {
  RadioBrowser() {
    _servers.shuffle(Random());
  }

  final List<String> _servers = [
    'https://de1.api.radio-browser.info',
    'https://de2.api.radio-browser.info',
    'https://fi1.api.radio-browser.info',
    'https://nl1.api.radio-browser.info',
    'https://at1.api.radio-browser.info',
  ];

  static const _headers = {'User-Agent': 'WorldRadioAlarm/1.0'};

  Future<dynamic> _get(
    String path, [
    Map<String, String>? query,
    Duration timeout = const Duration(seconds: 10),
  ]) async {
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
          return jsonDecode(utf8.decode(res.bodyBytes));
        }
        lastError = 'HTTP ${res.statusCode}';
      } catch (e) {
        lastError = e;
      }
    }
    throw Exception('Radyo sunucularına ulaşılamadı ($lastError)');
  }

  Future<List<Station>> search({
    String name = '',
    String countryCode = '',
    String tag = '',
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
    final data = await _get('/json/stations/search', q) as List;
    return data
        .map((e) => Station.fromApi((e as Map).cast<String, dynamic>()))
        .where((s) => s.url.isNotEmpty && s.name.isNotEmpty)
        .toList();
  }

  /// The most popular stations that have coordinates, for the map.
  Future<List<Station>> geoStations({int limit = 4000}) async {
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
  }

  Future<List<Country>> countries() async {
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
  }

  /// Tells Radio Browser a station was played (keeps popularity ranking useful).
  Future<void> registerClick(String uuid) async {
    try {
      await _get('/json/url/$uuid');
    } catch (_) {}
  }
}
