import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User preferences: theme and timeshift buffer length.
class Settings extends ChangeNotifier {
  Settings._(this._prefs);

  static Future<Settings> load() async => Settings._(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;

  ThemeMode get themeMode => switch (_prefs.getString('theme')) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  void setThemeMode(ThemeMode m) {
    _prefs.setString('theme', switch (m) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    });
    notifyListeners();
  }

  /// Minutes of live audio kept for rewinding (0 = off).
  int get timeshiftMinutes => _prefs.getInt('timeshift') ?? 15;

  void setTimeshiftMinutes(int m) {
    _prefs.setInt('timeshift', m);
    notifyListeners();
  }
}
