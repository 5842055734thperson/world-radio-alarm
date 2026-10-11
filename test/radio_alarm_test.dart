import 'package:flutter_test/flutter_test.dart';
import 'package:world_radio/models/radio_alarm.dart';
import 'package:world_radio/models/station.dart';

void main() {
  // 2026-10-12 is a Monday.
  final mondayMorning = DateTime(2026, 10, 12, 6, 0);

  test('one-shot alarm rings later today', () {
    final a = RadioAlarm(id: 1, hour: 7, minute: 30);
    expect(a.nextTrigger(mondayMorning), DateTime(2026, 10, 12, 7, 30));
  });

  test('one-shot alarm already passed rings tomorrow', () {
    final a = RadioAlarm(id: 1, hour: 5, minute: 0);
    expect(a.nextTrigger(mondayMorning), DateTime(2026, 10, 13, 5, 0));
  });

  test('weekend alarm skips to Saturday', () {
    final a = RadioAlarm(id: 1, hour: 9, minute: 0, days: [6, 7]);
    expect(a.nextTrigger(mondayMorning), DateTime(2026, 10, 17, 9, 0));
    expect(a.daysText, 'Hafta sonu');
  });

  test('disabled alarm never rings', () {
    final a = RadioAlarm(id: 1, hour: 7, minute: 0, enabled: false);
    expect(a.nextTrigger(mondayMorning), isNull);
  });

  test('alarm JSON round trip keeps station and native fields', () {
    const s = Station(uuid: 'u', name: 'TRT FM', url: 'http://x/stream');
    final a = RadioAlarm(id: 3, hour: 6, minute: 45, days: [1, 2, 3, 4, 5], station: s);
    final j = a.toJson();
    expect(j['streamUrl'], 'http://x/stream');
    final b = RadioAlarm.fromJson(j);
    expect(b.station?.name, 'TRT FM');
    expect(b.daysText, 'Hafta içi');
  });

  test('flag emoji', () {
    expect(flagEmoji('TR'), '🇹🇷');
  });
}
