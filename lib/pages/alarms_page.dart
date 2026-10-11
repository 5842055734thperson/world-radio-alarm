import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/radio_alarm.dart';
import '../widgets/station_widgets.dart';
import 'alarm_edit_page.dart';

class AlarmsPage extends StatelessWidget {
  const AlarmsPage({super.key});

  Future<void> _edit(BuildContext context, RadioAlarm? alarm) async {
    // First alarm: ask for the notification permission (Android 13+).
    if (!alarms.notificationsAllowed) await alarms.requestNotifications();
    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => AlarmEditPage(alarm: alarm)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_alarm),
        label: const Text('Alarm ekle'),
        onPressed: () => _edit(context, null),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: alarms,
          builder: (context, _) {
            final list = alarms.alarms;
            final next = list
                .map((a) => a.nextTrigger())
                .whereType<DateTime>()
                .fold<DateTime?>(null, (m, d) => m == null || d.isBefore(m) ? d : m);
            return ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Text('Alarmlar', style: Theme.of(context).textTheme.headlineSmall),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Text(next == null
                      ? 'Kurulu alarm yok.'
                      : 'Sıradaki alarm ${untilText(next)}.'),
                ),
                if (alarms.needsSetup) const _SetupCard(),
                for (final a in list) _AlarmCard(a, onTap: () => _edit(context, a)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AlarmCard extends StatelessWidget {
  const _AlarmCard(this.alarm, {required this.onTap});

  final RadioAlarm alarm;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final on = alarm.enabled;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alarm.timeText,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            color: on ? null : scheme.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                    ),
                    Text(alarm.daysText),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        StationLogo(alarm.station, size: 24),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            alarm.station?.name ?? 'Alarm sesi',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Switch(value: on, onChanged: (v) => alarms.setEnabled(alarm, v)),
            ],
          ),
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
    final scheme = Theme.of(context).colorScheme;
    Widget item(String text, String button, VoidCallback onPressed) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Expanded(child: Text(text)),
              const SizedBox(width: 8),
              FilledButton.tonal(onPressed: onPressed, child: Text(button)),
            ],
          ),
        );
    return Card(
      color: scheme.errorContainer,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: scheme.onErrorContainer),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Alarmların güvenle çalması için:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              if (!alarms.notificationsAllowed)
                item('Bildirim izni kapalı', 'İzin ver', alarms.requestNotifications),
              if (!alarms.canScheduleExact)
                item('Tam zamanlı alarm izni kapalı', 'Aç', alarms.openExactAlarmSettings),
              if (!alarms.canFullScreen)
                item('Kilit ekranında alarm ekranı izni kapalı', 'Aç',
                    alarms.openFullScreenSettings),
              if (!alarms.ignoringBattery)
                item('Pil tasarrufu alarmı geciktirebilir', 'Muaf tut',
                    alarms.requestIgnoreBattery),
            ],
          ),
        ),
      ),
    );
  }
}
