import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets/brut.dart';
import '../widgets/station_widgets.dart';

void showPlayer(BuildContext context) {
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, _, _) => const PlayerPage(),
      transitionsBuilder: (_, a, _, child) => SlideTransition(
        position: Tween(begin: const Offset(0, 1), end: Offset.zero)
            .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
        child: child,
      ),
    ),
  );
}

/// Full-screen "now playing": big square artwork, huge title, square controls.
class PlayerPage extends StatelessWidget {
  const PlayerPage({super.key});

  static const _sleepOptions = [15, 30, 45, 60, 90, 120];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([player, favorites]),
          builder: (context, _) {
            final s = player.station;
            if (s == null) return const SizedBox.shrink();
            final scheme = Theme.of(context).colorScheme;
            final fav = favorites.contains(s);
            final sleepAt = player.sleepAt;
            return LayoutBuilder(builder: (context, c) {
              final art = (c.maxWidth - 32).clamp(120.0, c.maxHeight * 0.42);
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        BrutIconButton(Icons.keyboard_arrow_down,
                            size: 40, tooltip: 'Close', onTap: () => Navigator.pop(context)),
                        const Spacer(),
                        Text(
                            !player.playing
                                ? (player.canTimeshift ? '❙❙ PAUSED' : '○ STOPPED')
                                : player.isLive
                                    ? '● LIVE'
                                    : '◀ ${formatBehind(player.behindSeconds)}',
                            style: label(context,
                                size: 12,
                                weight: FontWeight.w700,
                                spacing: 2,
                                color: player.playing && player.isLive ? kAccent : null)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Center(child: StationLogo(s, size: art)),
                    const SizedBox(height: 20),
                    Text(
                      upper(s.name),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: display(context, size: 34),
                    ),
                    const SizedBox(height: 8),
                    Text(upper([s.country, stationMeta(s)].where((e) => e.isNotEmpty).join(' · ')),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: label(context, size: 11, color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 12),
                    if (player.error != null)
                      Text(upper(player.error!), style: label(context, size: 12, color: scheme.error))
                    else if (player.nowPlaying != null)
                      Text('NOW: ${upper(player.nowPlaying!)}',
                          maxLines: 2, overflow: TextOverflow.ellipsis, style: label(context, size: 13)),
                    const Spacer(),
                    if (player.canTimeshift) ...[
                      const TimeshiftBar(),
                      const SizedBox(height: 16),
                    ],
                    Row(
                      children: [
                        BrutIconButton(
                          fav ? Icons.favorite : Icons.favorite_border,
                          size: 56,
                          tooltip: fav ? 'Remove from library' : 'Add to library',
                          onTap: () => favorites.toggle(s),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: BrutBox(
                            height: 72,
                            accent: true,
                            onTap: player.loading ? null : player.toggle,
                            child: player.loading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(player.playing ? Icons.stop : Icons.play_arrow, size: 32),
                                      const SizedBox(width: 8),
                                      Text(player.playing ? 'STOP' : 'PLAY', style: const TextStyle(fontSize: 18)),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _SleepButton(sleepAt: sleepAt),
                      ],
                    ),
                    const SizedBox(height: 12),
                    BrutBox(
                      height: 52,
                      onTap: () {
                        Navigator.pop(context);
                        exploreFrom(s);
                      },
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.hub_outlined, size: 20),
                          SizedBox(width: 8),
                          Text('DISCOVER SIMILAR STATIONS →'),
                        ],
                      ),
                    ),
                    if (sleepAt != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        'SLEEP TIMER · ${sleepAt.difference(DateTime.now()).inMinutes + 1} MIN',
                        style: label(context, size: 12, weight: FontWeight.w700),
                      ),
                    ],
                  ],
                ),
              );
            });
          },
        ),
      ),
    );
  }
}

class _SleepButton extends StatelessWidget {
  const _SleepButton({required this.sleepAt});

  final DateTime? sleepAt;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: 'Sleep timer',
      onSelected: (m) => player.setSleepTimer(m == 0 ? null : m),
      itemBuilder: (_) => [
        if (sleepAt != null) const PopupMenuItem(value: 0, child: Text('OFF')),
        for (final m in PlayerPage._sleepOptions) PopupMenuItem(value: m, child: Text('IN $m MIN')),
      ],
      child: BrutBox(
        width: 56,
        height: 56,
        padding: EdgeInsets.zero,
        inverted: sleepAt != null,
        child: const Icon(Icons.bedtime_outlined, size: 26),
      ),
    );
  }
}


/// "−04:12" for seconds behind live.
String formatBehind(double seconds) {
  final s = seconds.round();
  return '−${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
}

/// Rewind bar for the timeshift buffer: drag along the line, or use the
/// buttons. The right end is the live broadcast.
class TimeshiftBar extends StatefulWidget {
  const TimeshiftBar({super.key});

  @override
  State<TimeshiftBar> createState() => _TimeshiftBarState();
}

class _TimeshiftBarState extends State<TimeshiftBar> {
  double? _drag; // seconds behind while dragging

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final window = settings.timeshiftMinutes * 60.0;
    final buffered = player.bufferedSeconds;
    final behind = _drag ?? player.behindSeconds;
    double toX(double secsBehind, double w) => w * (1 - secsBehind / window);
    double fromX(double x, double w) => ((1 - x / w) * window).clamp(0.0, buffered);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('TIMESHIFT · ${settings.timeshiftMinutes} MIN',
                style: label(context, size: 11, weight: FontWeight.w700, spacing: 1)),
            const Spacer(),
            Text(behind < 8 ? 'LIVE' : formatBehind(behind),
                style: label(context, size: 11, weight: FontWeight.w700, spacing: 1)),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(builder: (context, c) {
          final w = c.maxWidth;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (d) => setState(() => _drag = fromX(d.localPosition.dx, w)),
            onHorizontalDragUpdate: (d) => setState(() => _drag = fromX(d.localPosition.dx, w)),
            onHorizontalDragEnd: (_) {
              final target = _drag;
              setState(() => _drag = null);
              if (target != null) player.seekBehind(target);
            },
            onTapUp: (d) => player.seekBehind(fromX(d.localPosition.dx, w)),
            child: SizedBox(
              height: 36,
              child: CustomPaint(
                painter: _TimeshiftPainter(
                  ink: scheme.onSurface,
                  muted: scheme.onSurfaceVariant,
                  bufferedFromX: toX(buffered, w),
                  markerX: toX(behind, w),
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 4),
        Row(
          children: [
            Text('−${settings.timeshiftMinutes}:00', style: label(context, size: 10, color: scheme.onSurfaceVariant)),
            const Spacer(),
            Text('NOW', style: label(context, size: 10, color: scheme.onSurfaceVariant)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: BrutBox(onTap: () => player.skip(-30), child: const Text('−30S'))),
            const SizedBox(width: 8),
            Expanded(child: BrutBox(onTap: () => player.skip(30), child: const Text('+30S'))),
            const SizedBox(width: 8),
            Expanded(
              child: BrutBox(
                accent: player.isLive && player.playing,
                onTap: player.goLive,
                child: const Text('● LIVE'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TimeshiftPainter extends CustomPainter {
  _TimeshiftPainter({required this.ink, required this.muted, required this.bufferedFromX, required this.markerX});

  final Color ink;
  final Color muted;
  final double bufferedFromX;
  final double markerX;

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height / 2;
    // Not yet recorded: dotted. Recorded: solid. Played-through part: thick.
    final dot = Paint()..color = muted;
    for (var x = 0.0; x < bufferedFromX; x += 6) {
      canvas.drawRect(Rect.fromLTWH(x, mid - 1, 2, 2), dot);
    }
    canvas.drawRect(Rect.fromLTRB(bufferedFromX, mid - 1, size.width, mid + 1), Paint()..color = ink);
    final accent = Paint()..color = kAccent;
    canvas.drawRect(Rect.fromLTRB(bufferedFromX, mid - 3, markerX, mid + 3), accent);
    // Live end tick and position marker.
    canvas.drawRect(Rect.fromLTWH(size.width - 2, mid - 10, 2, 20), Paint()..color = ink);
    final m = markerX.clamp(7.0, size.width - 7.0);
    final marker = Rect.fromCenter(center: Offset(m, mid), width: 14, height: 22);
    canvas.drawRect(marker, accent);
    canvas.drawRect(
        marker,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = ink
          ..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(_TimeshiftPainter old) =>
      old.bufferedFromX != bufferedFromX || old.markerX != markerX || old.ink != ink;
}
