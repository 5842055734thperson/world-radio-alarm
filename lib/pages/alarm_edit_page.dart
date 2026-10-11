import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/radio_alarm.dart';
import '../models/station.dart';
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
    _days = {...?a?.days};
    if (a == null) _days = {1, 2, 3, 4, 5};
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
      content: Text(next == null ? 'Alarm kaydedildi.' : 'Alarm ${untilText(next)} çalacak.'),
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
      content: Text('Alarm 5 saniye içinde çalacak. Denemek için ekranı kilitleyebilirsiniz.'),
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
        title: Text(widget.alarm == null ? 'Yeni alarm' : 'Alarmı düzenle'),
        actions: [
          if (widget.alarm != null)
            IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'Sil', onPressed: _delete),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: TextButton(
              onPressed: _pickTime,
              child: Text(
                '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(color: scheme.primary),
              ),
            ),
          ),
          if (preview != null)
            Center(child: Text('${untilText(preview)} çalacak')),
          const SizedBox(height: 24),
          Text('Tekrar', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var d = 1; d <= 7; d++)
                FilterChip(
                  label: Text(RadioAlarm.dayShort[d - 1]),
                  selected: _days.contains(d),
                  onSelected: (on) => setState(() => on ? _days.add(d) : _days.remove(d)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _days.isEmpty ? 'Gün seçilmezse alarm bir kez çalar.' : RadioAlarm(id: 0, hour: 0, minute: 0, days: _days.toList()).daysText,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          Text('Radyo', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: StationLogo(_station),
              title: Text(_station?.name ?? 'Radyo seçilmedi (alarm sesi çalar)'),
              subtitle: Text(_station?.subtitle ?? ''),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickStation,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'İnternet yoksa veya radyo açılmazsa telefonun alarm sesi çalar. '
            'Ses 30 saniyede yavaşça yükselir.',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            icon: const Icon(Icons.check),
            label: const Text('Kaydet'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: _save,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.play_circle_outline),
            label: const Text('5 saniye sonra dene'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: _test,
          ),
        ],
      ),
    );
  }
}

/// Pick the alarm station: favorites, recently played, or search all stations.
class _StationPickerPage extends StatelessWidget {
  const _StationPickerPage();

  @override
  Widget build(BuildContext context) {
    final mine = [
      ...favorites.stations,
      ...favorites.recent.where((s) => !favorites.contains(s)),
    ];
    void pick(Station s) => Navigator.pop(context, s);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Alarm radyosu'),
          bottom: const TabBar(tabs: [Tab(text: 'Favoriler'), Tab(text: 'Tüm istasyonlar')]),
        ),
        body: TabBarView(
          children: [
            mine.isEmpty
                ? const Center(child: Text('Favori veya son dinlenen istasyon yok.'))
                : ListView(
                    children: [for (final s in mine) StationTile(s, onTap: () => pick(s))],
                  ),
            StationSearch(onSelect: pick),
          ],
        ),
      ),
    );
  }
}
