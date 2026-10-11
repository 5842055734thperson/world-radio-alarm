import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/station.dart';
import 'radio_browser.dart';

/// Popular stations with coordinates, shown as dots on the map.
/// Cached on disk for a few days so the map opens instantly.
class GeoStations extends ChangeNotifier {
  GeoStations(this._api);

  final RadioBrowser _api;
  static const _maxAge = Duration(days: 3);

  List<Station> stations = const [];
  bool loading = false;
  String? error;

  Future<File> _file() async =>
      File('${(await getApplicationSupportDirectory()).path}/geo_stations.json');

  Future<void> load({bool force = false}) async {
    if (loading) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final file = await _file();
      final fresh = await file.exists() &&
          DateTime.now().difference(await file.lastModified()) < _maxAge;
      if (fresh && !force) {
        stations = _decode(await file.readAsString());
      } else {
        // Show the stale cache while the fresh list downloads.
        if (stations.isEmpty && await file.exists()) {
          stations = _decode(await file.readAsString());
          notifyListeners();
        }
        final list = await _api.geoStations();
        stations = list;
        await file.writeAsString(jsonEncode(list.map((s) => s.toJson()).toList()));
      }
    } catch (e) {
      if (stations.isEmpty) error = 'Radio directory unreachable.';
    }
    _api.addToCatalog(stations);
    loading = false;
    notifyListeners();
  }

  static List<Station> _decode(String raw) => (jsonDecode(raw) as List)
      .map((e) => Station.fromJson((e as Map).cast<String, dynamic>()))
      .toList();
}
