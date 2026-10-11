import 'station.dart';

/// An alarm that wakes the user up with a radio station.
///
/// Stored natively (Android SharedPreferences) so that alarms keep working
/// after reboot and while the Flutter UI is closed.
class RadioAlarm {
  RadioAlarm({
    required this.id,
    required this.hour,
    required this.minute,
    this.days = const [],
    this.enabled = true,
    this.station,
  });

  final int id;
  int hour;
  int minute;

  /// ISO weekdays (1 = Monday … 7 = Sunday). Empty = ring once.
  List<int> days;
  bool enabled;
  Station? station;

  factory RadioAlarm.fromJson(Map<String, dynamic> j) => RadioAlarm(
        id: j['id'] as int,
        hour: j['hour'] as int,
        minute: j['minute'] as int,
        days: (j['days'] as List? ?? []).cast<int>(),
        enabled: j['enabled'] as bool? ?? true,
        station: j['station'] == null
            ? null
            : Station.fromJson((j['station'] as Map).cast<String, dynamic>()),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'hour': hour,
        'minute': minute,
        'days': days,
        'enabled': enabled,
        // Flat copies for the native side.
        'streamUrl': station?.url ?? '',
        'stationName': station?.name ?? '',
        'station': station?.toJson(),
      };

  String get timeText =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  static const dayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  String get daysText {
    if (days.isEmpty) return 'Once';
    final s = days.toSet();
    if (s.length == 7) return 'Every day';
    if (s.length == 5 && s.containsAll([1, 2, 3, 4, 5]) && !s.contains(6)) {
      return 'Weekdays';
    }
    if (s.length == 2 && s.containsAll([6, 7])) return 'Weekends';
    final sorted = s.toList()..sort();
    return sorted.map((d) => dayShort[d - 1]).join(' ');
  }

  /// Next time this alarm rings, or null when it is disabled.
  /// Mirrors AlarmScheduler.nextTrigger on the Kotlin side.
  DateTime? nextTrigger([DateTime? from]) {
    if (!enabled) return null;
    final now = from ?? DateTime.now();
    for (var i = 0; i <= 7; i++) {
      final day = DateTime(now.year, now.month, now.day + i, hour, minute);
      if (!day.isAfter(now)) continue;
      if (days.isEmpty || days.contains(day.weekday)) return day;
    }
    return null;
  }
}

/// "in 7 h 20 min" style text.
String untilText(DateTime target) {
  final d = target.difference(DateTime.now());
  final h = d.inHours;
  final m = d.inMinutes.remainder(60) + (d.inSeconds.remainder(60) > 0 ? 1 : 0);
  if (h >= 24) return 'in ${d.inDays} d ${h - d.inDays * 24} h';
  if (h == 0) return 'in $m min';
  return 'in $h h $m min';
}
