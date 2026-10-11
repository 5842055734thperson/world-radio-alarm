import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';
import 'brut.dart';

/// Gear button for the top-right corner; opens [SettingsPanel] floating there.
class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key});

  @override
  Widget build(BuildContext context) => BrutIconButton(
        Icons.tune,
        size: 44,
        tooltip: 'Settings',
        onTap: () => showGeneralDialog<void>(
          context: context,
          barrierDismissible: true,
          barrierLabel: 'Close settings',
          barrierColor: Colors.transparent,
          transitionDuration: const Duration(milliseconds: 180),
          pageBuilder: (_, _, _) => const SettingsPanel(),
          transitionBuilder: (_, a, _, child) => FadeTransition(
            opacity: a,
            child: ScaleTransition(
              alignment: Alignment.topRight,
              scale: Tween(begin: 0.9, end: 1.0).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
              child: child,
            ),
          ),
        ),
      );
}

/// Small floating card in the top-right corner with the app settings.
class SettingsPanel extends StatelessWidget {
  const SettingsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 300,
              decoration: BoxDecoration(
                color: scheme.surface,
                border: Border.all(color: scheme.onSurface, width: kBorder),
                boxShadow: [BoxShadow(color: scheme.onSurface, offset: const Offset(6, 6))],
              ),
              padding: const EdgeInsets.all(16),
              child: ListenableBuilder(
                listenable: settings,
                builder: (context, _) => Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text('SETTINGS', style: display(context, size: 22))),
                        BrutIconButton(Icons.close, size: 36, tooltip: 'Close', onTap: () => Navigator.pop(context)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text('THEME', style: label(context, size: 12, weight: FontWeight.w700, spacing: 1)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (final (mode, name) in const [
                          (ThemeMode.system, 'Auto'),
                          (ThemeMode.light, 'Light'),
                          (ThemeMode.dark, 'Dark'),
                        ]) ...[
                          Expanded(
                            child: BrutChip(name,
                                selected: settings.themeMode == mode, onTap: () => settings.setThemeMode(mode)),
                          ),
                          if (mode != ThemeMode.dark) const SizedBox(width: 6),
                        ],
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text('TIMESHIFT BUFFER', style: label(context, size: 12, weight: FontWeight.w700, spacing: 1)),
                    const SizedBox(height: 4),
                    Text(
                      upper('Keeps the last minutes of live radio so you can pause and rewind.'),
                      style: label(context, size: 10, color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (final m in const [0, 15, 30]) ...[
                          Expanded(
                            child: BrutChip(m == 0 ? 'Off' : '$m min',
                                selected: settings.timeshiftMinutes == m, onTap: () => settings.setTimeshiftMinutes(m)),
                          ),
                          if (m != 30) const SizedBox(width: 6),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
