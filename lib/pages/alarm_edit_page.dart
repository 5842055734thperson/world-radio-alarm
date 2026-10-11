import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/radio_alarm.dart';
import '../models/station.dart';
import '../theme.dart';
import '../widgets/brut.dart';
import '../widgets/station_widgets.dart';
import 'discover_page.dart';

class AlarmEditPage extends StatefulWidget {
  const AlarmEditPage({super.key, this.alarm});

  /// null = new alarm.
  final RadioAlarm? alarm;

  @override
  State<AlarmEditPage> createState() => _AlarmEditPageState();
}

class _AlarmEditPageState extends State<AlarmEditPage> {
  late TimeOfDay _time;
  late Set<int> _days;
  Station? _station;

  @override
  void initState() {
    super.initState();
    final a = widget.alarm;
    _time = a == null ? const TimeOfDay(hour: 7, minute: 0) : TimeOfDay(hour: a.hour, minute: a.minute);
    _days = a == null ? {1, 2, 3, 4, 5} : {...a.days};
    _station = a?.station ??
        player.station ??
        (favorites.stations.isNotEmpty ? favorites.stations.first : null);
  }

  RadioAlarm _build() => RadioAlarm(
        id: widget.alarm?.id ?? alarms.newId(),
        hour: _time.hour,
        minute: _time.minute,
        days: _days.toList()..sort(),
        station: _station,
      );

  Future<void> _save() async {
    final alarm = _build();
    await alarms.upsert(alarm);
    if (!mounted) return;
    final next = alarm.nextTrigger();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(upper(next == null ? 'Alarm saved' : 'Alarm rings ${untilText(next)}')),
    ));
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    await alarms.remove(widget.alarm!);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _test() async {
    await player.stop();
    await alarms.test(_build());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('ALARM RINGS IN 5 SECONDS. YOU CAN LOCK THE SCREEN.'),
    ));
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _time,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (t != null) setState(() => _time = t);
  }

  Future<void> _pickStation() async {
    final s = await Navigator.push<Station>(
      context,
      MaterialPageRoute(builder: (_) => const _StationPickerPage()),
    );
    if (s != null) setState(() => _station = s);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final preview = _build().nextTrigger();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.alarm == null ? 'NEW ALARM' : 'EDIT ALARM'),
        actions: [
          if (widget.alarm != null)
            IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'Delete', onPressed: _delete),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GestureDetector(
            onTap: _pickTime,
            child: Text(
              '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: kDigits, fontSize: 96, fontWeight: FontWeight.w700, height: 1.1),
            ),
          ),
          Text(
            upper(preview == null ? 'Tap the time to change it' : 'Rings ${untilText(preview)}'),
            textAlign: TextAlign.center,
            style: label(context, size: 12, color: scheme.onSurfaceVariant),
          ),
          const SectionLabel('Repeat'),
          Row(
            children: [
              for (var d = 1; d <= 7; d++) ...[
                Expanded(
                  child: BrutBox(
                    inverted: _days.contains(d),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    onTap: () => setState(() => _days.contains(d) ? _days.remove(d) : _days.add(d)),
                    child: Text(upper(RadioAlarm.dayShort[d - 1]), style: const TextStyle(fontSize: 11)),
                  ),
                ),
                if (d < 7) const SizedBox(width: 4),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            upper(_days.isEmpty
                ? 'No days selected: rings once'
                : RadioAlarm(id: 0, hour: 0, minute: 0, days: _days.toList()).daysText),
            style: label(context, size: 11, color: scheme.onSurfaceVariant),
          ),
          const SectionLabel('Radio'),
          BrutBox(
            onTap: _pickStation,
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                StationLogo(_station, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    upper(_station?.name ?? 'Choose a station (or alarm tone)'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            upper('Without internet, or if the stream fails, the phone alarm tone plays. '
                'Volume fades in over 30 seconds.'),
            style: label(context, size: 11, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 28),
          BrutBox(
            inverted: true,
            onTap: _save,
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: const Text('SAVE', style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(height: 10),
          BrutBox(
            onTap: _test,
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: const Text('TEST IN 5 SECONDS'),
          ),
        ],
      ),
    );
  }
}

/// Pick the alarm station: library, or search all stations.
class _StationPickerPage extends StatefulWidget {
  const _StationPickerPage();

  @override
  State<_StationPickerPage> createState() => _StationPickerPageState();
}

class _StationPickerPageState extends State<_StationPickerPage> {
  bool _searchAll = false;

  @override
  Widget build(BuildContext context) {
    final mine = [
      ...favorites.stations,
      ...favorites.recent.where((s) => !favorites.contains(s)),
    ];
    void pick(Station s) => Navigator.pop(context, s);
    return Scaffold(
      appBar: AppBar(title: const Text('ALARM STATION')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: BrutBox(
                    inverted: !_searchAll,
                    onTap: () => setState(() => _searchAll = false),
                    child: const Text('LIBRARY'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: BrutBox(
                    inverted: _searchAll,
                    onTap: () => setState(() => _searchAll = true),
                    child: const Text('ALL STATIONS'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _searchAll
                ? StationSearch(onSelect: pick)
                : mine.isEmpty
                    ? Center(child: Text('LIBRARY IS EMPTY', style: label(context)))
                    : ListView(children: [for (final s in mine) StationTile(s, onTap: () => pick(s))]),
          ),
        ],
      ),
    );
  }
}
