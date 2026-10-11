import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/station.dart';

/// Favorite stations, recently played stations and the last chosen country.
class Favorites extends ChangeNotifier {
  Favorites._(this._prefs) {
    _favorites = _readList('favorites');
    _recent = _readList('recent');
  }

  static Future<Favorites> load() async =>
      Favorites._(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;
  late List<Station> _favorites;
  late List<Station> _recent;

  List<Station> get stations => List.unmodifiable(_favorites);
  List<Station> get recent => List.unmodifiable(_recent);

  bool contains(Station s) => _favorites.contains(s);

  void toggle(Station s) {
    if (!_favorites.remove(s)) _favorites.add(s);
    _write('favorites', _favorites);
  }

  /// [newIndex] is already adjusted for the removed item (onReorderItem).
  void reorder(int oldIndex, int newIndex) {
    _favorites.insert(newIndex, _favorites.removeAt(oldIndex));
    _write('favorites', _favorites);
  }

  void addRecent(Station s) {
    _recent
      ..remove(s)
      ..insert(0, s);
    if (_recent.length > 20) _recent = _recent.sublist(0, 20);
    _write('recent', _recent);
  }

  /// '' means "whole world". Defaults to Turkey on first start.
  String get countryCode => _prefs.getString('country') ?? 'TR';
  String get countryName => _prefs.getString('countryName') ?? 'Turkey';

  void setCountry(String code, String name) {
    _prefs.setString('country', code);
    _prefs.setString('countryName', name);
    notifyListeners();
  }

  List<Station> _readList(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => Station.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return [];
    }
  }

  void _write(String key, List<Station> list) {
    _prefs.setString(key, jsonEncode(list.map((s) => s.toJson()).toList()));
    notifyListeners();
  }
}
