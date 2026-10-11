import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/radio_alarm.dart';
import '../theme.dart';
import '../widgets/brut.dart';
import 'alarm_edit_page.dart';

class AlarmsPage extends StatelessWidget {
  const AlarmsPage({super.key});

  Future<void> _edit(BuildContext context, RadioAlarm? alarm) async {
    // First alarm: ask for the notification permission (Android 13+).
    if (!alarms.notificationsAllowed) {
      try {
        await alarms.requestNotifications();
      } catch (_) {}
    }
    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => AlarmEditPage(alarm: alarm)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: alarms,
      builder: (context, _) {
        final list = alarms.alarms;
        final next = list
            .map((a) => a.nextTrigger())
            .whereType<DateTime>()
            .fold<DateTime?>(null, (m, d) => m == null || d.isBefore(m) ? d : m);
        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            PageTitle(
              'Alarm',
              trailing: BrutIconButton(Icons.add, inverted: true, tooltip: 'Alarm ekle', onTap: () => _edit(context, null)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                upper(next == null ? 'Kurulu alarm yok' : 'Sıradaki: ${untilText(next)}'),
                style: mono(context, size: 12, spacing: 1),
              ),
            ),
            if (alarms.needsSetup) const _SetupCard(),
            for (final a in list) _AlarmRow(a, onTap: () => _edit(context, a)),
            if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: BrutBox(
                  onTap: () => _edit(context, null),
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: const Text('+ RADYOLU ALARM KUR'),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AlarmRow extends StatelessWidget {
  const _AlarmRow(this.alarm, {required this.onTap});

  final RadioAlarm alarm;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final on = alarm.enabled;
    final color = on ? scheme.onSurface : scheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: scheme.onSurface, width: 1)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(alarm.timeText,
                      style: TextStyle(fontFamily: kMono, fontSize: 52, fontWeight: FontWeight.w700, height: 1, color: color)),
                  const SizedBox(height: 6),
                  Text(
                    upper('${alarm.daysText} · ${alarm.station?.name ?? 'Alarm sesi'}'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: mono(context, size: 11, color: color),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            BrutToggle(value: on, onChanged: (v) => alarms.setEnabled(alarm, v)),
          ],
        ),
      ),
    );
  }
}

/// Explains and fixes settings that would stop alarms from ringing.
class _SetupCard extends StatelessWidget {
  const _SetupCard();

  @override
  Widget build(BuildContext context) {
    Widget item(String text, String button, VoidCallback onPressed) => Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(
            children: [
              Expanded(child: Text(upper(text), style: mono(context, size: 12))),
              const SizedBox(width: 8),
              BrutBox(inverted: true, onTap: onPressed, child: Text(upper(button), style: const TextStyle(fontSize: 12))),
            ],
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: BrutBox(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('! ALARMLARIN ÇALMASI İÇİN'),
            if (!alarms.notificationsAllowed) item('Bildirim izni kapalı', 'İzin ver', alarms.requestNotifications),
            if (!alarms.canScheduleExact) item('Tam zamanlı alarm izni kapalı', 'Aç', alarms.openExactAlarmSettings),
            if (!alarms.canFullScreen)
              item('Kilit ekranı alarm izni kapalı', 'Aç', alarms.openFullScreenSettings),
            if (!alarms.ignoringBattery)
              item('Pil tasarrufu alarmı geciktirebilir', 'Muaf tut', alarms.requestIgnoreBattery),
          ],
        ),
      ),
    );
  }
}
