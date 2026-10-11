import 'package:flutter/material.dart';

/// Minimal brutalist look: pure black/white, square corners, hard 2px borders,
/// Space Grotesk for titles and JetBrains Mono for data.
const kBorder = 2.0;
const kSans = 'SpaceGrotesk';
const kMono = 'JetBrainsMono';

ThemeData brutalTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final fg = dark ? Colors.white : Colors.black;
  final bg = dark ? Colors.black : Colors.white;
  final muted = dark ? const Color(0xFF8C8C8C) : const Color(0xFF6E6E6E);
  const square = RoundedRectangleBorder(borderRadius: BorderRadius.zero);
  final side = BorderSide(color: fg, width: kBorder);

  final scheme = ColorScheme(
    brightness: brightness,
    primary: fg,
    onPrimary: bg,
    secondary: fg,
    onSecondary: bg,
    error: const Color(0xFFFF2D20),
    onError: Colors.white,
    surface: bg,
    onSurface: fg,
    onSurfaceVariant: muted,
    outline: fg,
    outlineVariant: muted,
    surfaceContainerLowest: bg,
    surfaceContainerLow: bg,
    surfaceContainer: bg,
    surfaceContainerHigh: bg,
    surfaceContainerHighest: bg,
    inverseSurface: fg,
    onInverseSurface: bg,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: brightness,
    fontFamily: kSans,
    scaffoldBackgroundColor: bg,
    canvasColor: bg,
    splashFactory: NoSplash.splashFactory,
    highlightColor: fg.withValues(alpha: 0.08),
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: fg, displayColor: fg),
    dividerTheme: DividerThemeData(color: fg, thickness: 1, space: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      foregroundColor: fg,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: kSans, fontWeight: FontWeight.w700, fontSize: 20, color: fg, letterSpacing: 1),
      shape: Border(bottom: side),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: bg,
      modalBackgroundColor: bg,
      shape: Border(top: side),
      showDragHandle: false,
      elevation: 0,
    ),
    dialogTheme: DialogThemeData(backgroundColor: bg, shape: square.copyWith(side: side)),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: fg,
      contentTextStyle: TextStyle(fontFamily: kMono, color: bg, fontSize: 13),
      shape: square,
      behavior: SnackBarBehavior.floating,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: fg,
        foregroundColor: bg,
        shape: square,
        textStyle: const TextStyle(fontFamily: kMono, fontWeight: FontWeight.w700, letterSpacing: 1),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: fg,
        side: side,
        shape: square,
        textStyle: const TextStyle(fontFamily: kMono, fontWeight: FontWeight.w700, letterSpacing: 1),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: fg, shape: square),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: fg, shape: square),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: fg, linearTrackColor: muted),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: side),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: side),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero, borderSide: side.copyWith(width: 3)),
      hintStyle: TextStyle(fontFamily: kMono, color: muted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    ),
    textSelectionTheme: TextSelectionThemeData(cursorColor: fg, selectionHandleColor: fg),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: bg,
      shape: square.copyWith(side: side),
      hourMinuteShape: square,
      dayPeriodShape: square,
      dialHandColor: fg,
      dialBackgroundColor: bg,
      hourMinuteColor: WidgetStateColor.resolveWith(
          (s) => s.contains(WidgetState.selected) ? fg : bg),
      hourMinuteTextColor: WidgetStateColor.resolveWith(
          (s) => s.contains(WidgetState.selected) ? bg : fg),
      dialTextColor: WidgetStateColor.resolveWith(
          (s) => s.contains(WidgetState.selected) ? bg : fg),
      hourMinuteTextStyle: const TextStyle(fontFamily: kMono, fontSize: 48),
      helpTextStyle: const TextStyle(fontFamily: kMono, letterSpacing: 1),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: bg,
      shape: square.copyWith(side: side),
      textStyle: TextStyle(fontFamily: kMono, color: fg),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: fg),
      textStyle: TextStyle(fontFamily: kMono, color: bg, fontSize: 12),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(fg),
      radius: Radius.zero,
    ),
  );
}

/// Monospaced data text ("TR · POP · 128 KBPS").
TextStyle mono(BuildContext context,
    {double size = 12, FontWeight weight = FontWeight.w400, Color? color, double spacing = 0.5}) {
  final scheme = Theme.of(context).colorScheme;
  return TextStyle(
    fontFamily: kMono,
    fontSize: size,
    fontWeight: weight,
    letterSpacing: spacing,
    color: color ?? scheme.onSurface,
  );
}

/// Big bold display title.
TextStyle display(BuildContext context, {double size = 32, Color? color}) => TextStyle(
      fontFamily: kSans,
      fontWeight: FontWeight.w700,
      fontSize: size,
      height: 1.0,
      letterSpacing: -0.5,
      color: color ?? Theme.of(context).colorScheme.onSurface,
    );

/// Turkish-aware upper case ("istanbul" -> "İSTANBUL").
String upper(String s) => s.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();
