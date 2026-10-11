import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/radio_alarm.dart';

/// Bridge to the native Android alarm engine (see MainActivity.kt).
///
/// The native side stores the alarms, schedules them with
/// AlarmManager.setAlarmClock and plays the stream (with a built-in alarm
/// tone as fallback) even when this UI is closed.
class Alarms extends ChangeNotifier {
  static const _ch = MethodChannel('world_radio/alarms');

  List<RadioAlarm> alarms = [];
  bool canScheduleExact = true;
  bool ignoringBattery = true;
  bool notificationsAllowed = true;
  bool canFullScreen = true;

  /// True when something would stop alarms from ringing reliably.
  bool get needsSetup =>
      !canScheduleExact || !ignoringBattery || !notificationsAllowed || !canFullScreen;

  Future<void> refresh() async {
    try {
      final raw = await _ch.invokeMethod<String>('getAlarms') ?? '[]';
      alarms = (jsonDecode(raw) as List)
          .map((e) => RadioAlarm.fromJson((e as Map).cast<String, dynamic>()))
          .toList()
        ..sort((a, b) => (a.hour * 60 + a.minute) - (b.hour * 60 + b.minute));
      canScheduleExact =
          await _ch.invokeMethod<bool>('canScheduleExact') ?? true;
      ignoringBattery = await _ch.invokeMethod<bool>('isIgnoringBattery') ?? true;
      canFullScreen = await _ch.invokeMethod<bool>('canFullScreen') ?? true;
      notificationsAllowed = await Permission.notification.isGranted;
    } catch (e) {
      debugPrint('alarm refresh failed: $e');
    }
    notifyListeners();
  }

  Future<void> _save() async {
    await _ch.invokeMethod('saveAlarms',
        jsonEncode(alarms.map((a) => a.toJson()).toList()));
    await refresh();
  }

  int newId() => alarms.isEmpty
      ? 1
      : alarms.map((a) => a.id).reduce((a, b) => a > b ? a : b) + 1;

  Future<void> upsert(RadioAlarm alarm) async {
    alarms.removeWhere((a) => a.id == alarm.id);
    alarms.add(alarm);
    await _save();
  }

  Future<void> remove(RadioAlarm alarm) async {
    alarms.removeWhere((a) => a.id == alarm.id);
    await _save();
  }

  Future<void> setEnabled(RadioAlarm alarm, bool enabled) async {
    alarm.enabled = enabled;
    await _save();
  }

  /// Rings the given alarm in 5 seconds so the user can check it works.
  Future<void> test(RadioAlarm alarm) =>
      _ch.invokeMethod('testAlarm', jsonEncode(alarm.toJson()));

  Future<void> requestNotifications() async {
    await Permission.notification.request();
    await refresh();
  }

  Future<void> openExactAlarmSettings() =>
      _ch.invokeMethod('openExactAlarmSettings');

  Future<void> openFullScreenSettings() =>
      _ch.invokeMethod('openFullScreenSettings');

  Future<void> requestIgnoreBattery() =>
      _ch.invokeMethod('requestIgnoreBattery');
}
