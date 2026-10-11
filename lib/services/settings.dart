import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User preferences: light / dark / follow the system.
class Settings extends ChangeNotifier {
  Settings._(this._prefs);

  static Future<Settings> load() async => Settings._(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;

  ThemeMode get themeMode => switch (_prefs.getString('theme')) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  /// system -> light -> dark -> system
  void cycleTheme() {
    final next = switch (themeMode) {
      ThemeMode.system => 'light',
      ThemeMode.light => 'dark',
      ThemeMode.dark => 'system',
    };
    _prefs.setString('theme', next);
    notifyListeners();
  }

  String get themeLabel => switch (themeMode) {
        ThemeMode.system => 'OTO',
        ThemeMode.light => 'AÇIK',
        ThemeMode.dark => 'KOYU',
      };
}
