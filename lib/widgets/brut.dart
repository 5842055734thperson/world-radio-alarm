import 'package:flutter/material.dart';

import '../theme.dart';

/// Square bordered box; [inverted] fills it with the foreground color.
/// The basic building block for buttons, chips and toggles.
class BrutBox extends StatelessWidget {
  const BrutBox({
    super.key,
    required this.child,
    this.onTap,
    this.inverted = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    this.width,
    this.height,
    this.tooltip,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool inverted;
  final EdgeInsets padding;
  final double? width;
  final double? height;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = inverted ? scheme.surface : scheme.onSurface;
    final bg = inverted ? scheme.onSurface : scheme.surface;
    Widget box = Container(
      width: width,
      height: height,
      padding: padding,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: scheme.onSurface, width: kBorder),
      ),
      child: IconTheme.merge(
        data: IconThemeData(color: fg),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: fg, fontFamily: kMono, fontWeight: FontWeight.w700, letterSpacing: 1),
          child: child,
        ),
      ),
    );
    if (onTap != null) {
      box = GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: box);
    }
    if (tooltip != null) box = Tooltip(message: tooltip!, child: box);
    return Semantics(button: onTap != null, label: tooltip, child: box);
  }
}

/// Square icon button.
class BrutIconButton extends StatelessWidget {
  const BrutIconButton(this.icon,
      {super.key, required this.onTap, this.size = 44, this.inverted = false, this.tooltip});

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final bool inverted;
  final String? tooltip;

  @override
  Widget build(BuildContext context) => BrutBox(
        width: size,
        height: size,
        padding: EdgeInsets.zero,
        inverted: inverted,
        onTap: onTap,
        tooltip: tooltip,
        child: Icon(icon, size: size * 0.5),
      );
}

/// Selectable label box (filters, weekdays).
class BrutChip extends StatelessWidget {
  const BrutChip(this.label, {super.key, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => BrutBox(
        inverted: selected,
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(upper(label), style: const TextStyle(fontSize: 12)),
      );
}

/// Square on/off switch.
class BrutToggle extends StatelessWidget {
  const BrutToggle({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final fg = Theme.of(context).colorScheme.onSurface;
    return Semantics(
      toggled: value,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: Container(
          width: 56,
          height: 30,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(border: Border.all(color: fg, width: kBorder)),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 120),
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 22,
              color: value ? fg : null,
              decoration: value ? null : BoxDecoration(border: Border.all(color: fg, width: kBorder)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small monospaced section label: "— FAVORITES".
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
        child: Row(
          children: [
            Expanded(child: Text('— ${upper(text)}', style: mono(context, size: 12, weight: FontWeight.w700, spacing: 2))),
            ?trailing,
          ],
        ),
      );
}

/// Big page title, Spotify/Tidal style.
class PageTitle extends StatelessWidget {
  const PageTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: Text(upper(text), style: display(context, size: 40))),
            ?trailing,
          ],
        ),
      );
}

/// Light/dark/auto switch shown in page headers.
class ThemeButton extends StatelessWidget {
  const ThemeButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => BrutBox(
        onTap: onTap,
        tooltip: 'Theme',
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.contrast, size: 16),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      );
}
