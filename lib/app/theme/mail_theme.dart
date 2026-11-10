import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import '../motion/mail_motion.dart';

/// The shared blue-flow palette. Brand blue stays pinned in both themes;
/// night mode swaps the surfaces and small-text accent instead of tinting the
/// whole app.
abstract final class MailColors {
  static const Color brandBlue = Color(0xFF002FA7);
  static const Color brandBluePressed = Color(0xFF001F70);
  static const Color ivory = Color(0xFFF7F7F2);
  static const Color white = Color(0xFFFFFFFF);
  static const Color ink = Color(0xFF17213B);

  static const Color _lightAvatar = Color(0xFFE9EEF9);
  static const Color _darkAvatar = Color(0xFF1C2D4E);
  static const Color _lightTrack = Color(0xFFE9ECF3);
  static const Color _darkTrack = Color(0xFF1B2A45);
  static const Color _lightField = Color(0xFFF4F5F1);
  static const Color _darkField = Color(0xFF111D35);
  static const Color _lightSuccess = Color(0xFF1D6B4A);
  static const Color _darkSuccess = Color(0xFF7EDDB2);
  static const Color _lightWarning = Color(0xFF8A5300);
  static const Color _darkWarning = Color(0xFFFFC46B);
  static const Color _lightDanger = Color(0xFFB3261E);
  static const Color _darkDanger = Color(0xFFFFB4AB);

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color toolbar(Brightness brightness) => brandBlue;

  static Color toolbarForeground(Brightness brightness) =>
      brightness == Brightness.dark ? const Color(0xFFF3F6FF) : white;

  static Color toolbarMuted(Brightness brightness) =>
      brightness == Brightness.dark
      ? const Color(0xFFD3DDF8)
      : const Color(0xFFD4DEF6);

  static Color panel(BuildContext context) => isDark(context)
      ? Theme.of(context).colorScheme.surfaceContainerLow
      : white;

  static Color field(BuildContext context) =>
      fieldFor(Theme.of(context).brightness);

  static Color fieldFor(Brightness brightness) =>
      brightness == Brightness.dark ? _darkField : _lightField;

  static Color track(BuildContext context) =>
      isDark(context) ? _darkTrack : _lightTrack;

  static Color avatarTint(BuildContext context) =>
      isDark(context) ? _darkAvatar : _lightAvatar;

  static Color avatarInk(BuildContext context) =>
      isDark(context) ? const Color(0xFFB8CBFF) : brandBlue;

  static Color muted(BuildContext context) =>
      Theme.of(context).colorScheme.onSurfaceVariant;

  static Color success(BuildContext context) =>
      isDark(context) ? _darkSuccess : _lightSuccess;

  static Color warning(BuildContext context) =>
      isDark(context) ? _darkWarning : _lightWarning;

  static Color danger(BuildContext context) =>
      isDark(context) ? _darkDanger : _lightDanger;
}

/// App-wide control geometry. Every field, button, card, dialog and sheet uses
/// one of these rounded families so secondary screens do not drift.
abstract final class MailShapes {
  static const double control = 14;
  static const double card = 18;
  static const double dialog = 24;
  static const double sheet = 28;
  static const double compose = 22;
  static const BorderRadius panelTop = BorderRadius.vertical(
    top: Radius.circular(28),
  );
}

/// Small shared control styles used by widgets that need Material defaults
/// outside a Theme lookup (for example selection overlays).
abstract final class MailControlStyle {
  static const EdgeInsets fieldPadding = EdgeInsets.symmetric(
    horizontal: 14,
    vertical: 14,
  );
}

/// Builds the one shared light/dark theme family for the app and preview tests.
ThemeData buildMailTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    visualDensity: VisualDensity.standard,
  );
  final scheme = _scheme(brightness);
  final textTheme = _textTheme(base.textTheme, scheme);

  final outline = OutlineInputBorder(
    borderRadius: BorderRadius.circular(MailShapes.control),
    borderSide: BorderSide(color: scheme.outlineVariant),
  );
  final focusedOutline = OutlineInputBorder(
    borderRadius: BorderRadius.circular(MailShapes.control),
    borderSide: BorderSide(color: scheme.primary, width: 1.6),
  );

  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    canvasColor: scheme.surface,
    textTheme: textTheme,
    primaryTextTheme: textTheme.apply(
      bodyColor: MailColors.toolbarForeground(brightness),
      displayColor: MailColors.toolbarForeground(brightness),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w700,
      ),
      iconTheme: IconThemeData(color: scheme.onSurface),
      actionsIconTheme: IconThemeData(color: scheme.onSurface),
    ),
    cardTheme: CardThemeData(
      color: isDark ? scheme.surfaceContainerLow : MailColors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MailShapes.card),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: isDark ? scheme.surfaceContainer : MailColors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MailShapes.dialog),
      ),
      titleTextStyle: textTheme.titleLarge?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w700,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: isDark ? scheme.surfaceContainer : MailColors.white,
      modalBackgroundColor: isDark ? scheme.surfaceContainer : MailColors.white,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: scheme.outline,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(MailShapes.sheet),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: MailColors.fieldFor(brightness),
      contentPadding: MailControlStyle.fieldPadding,
      border: outline,
      enabledBorder: outline,
      focusedBorder: focusedOutline,
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MailShapes.control),
        borderSide: BorderSide(color: scheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MailShapes.control),
        borderSide: BorderSide(color: scheme.error, width: 1.6),
      ),
      labelStyle: TextStyle(color: scheme.onSurfaceVariant),
      hintStyle: TextStyle(color: scheme.onSurfaceVariant),
      helperStyle: textTheme.bodySmall?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
      prefixIconColor: scheme.onSurfaceVariant,
      suffixIconColor: scheme.onSurfaceVariant,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MailShapes.control),
        ),
        textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MailShapes.control),
        ),
        textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MailShapes.control),
        ),
        textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
        tapTargetSize: MaterialTapTargetSize.padded,
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MailShapes.control),
          ),
        ),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: MailColors.brandBlue,
      foregroundColor: MailColors.white,
      elevation: 3,
      focusElevation: 3,
      hoverElevation: 3,
      highlightElevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MailShapes.compose),
      ),
      extendedTextStyle: textTheme.labelLarge?.copyWith(
        color: MailColors.white,
        fontWeight: FontWeight.w600,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surfaceContainer,
      selectedColor: scheme.primaryContainer,
      disabledColor: scheme.surfaceContainerHigh,
      side: BorderSide(color: scheme.outlineVariant),
      shape: const StadiumBorder(),
      labelStyle: textTheme.labelLarge?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w500,
      ),
      secondaryLabelStyle: textTheme.labelLarge?.copyWith(
        color: scheme.onPrimaryContainer,
        fontWeight: FontWeight.w600,
      ),
      checkmarkColor: scheme.onPrimaryContainer,
      showCheckmark: false,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MailShapes.control),
          ),
        ),
        side: WidgetStatePropertyAll(BorderSide(color: scheme.outlineVariant)),
        textStyle: WidgetStatePropertyAll(
          textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: scheme.onSurfaceVariant,
      textColor: scheme.onSurface,
      selectedColor: isDark
          ? scheme.onPrimaryContainer
          : scheme.onPrimaryContainer,
      selectedTileColor: scheme.primaryContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MailShapes.control),
      ),
      minVerticalPadding: 10,
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: isDark ? scheme.surfaceContainerHighest : MailColors.ink,
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: isDark ? scheme.onSurface : MailColors.white,
      ),
      actionTextColor: isDark ? scheme.primary : const Color(0xFFB8CBFF),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MailShapes.control),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: scheme.surfaceContainerHighest,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: scheme.primary,
      selectionColor: scheme.primaryContainer,
      selectionHandleColor: scheme.primary,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? scheme.onPrimary
            : scheme.outline,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? scheme.primary
            : scheme.surfaceContainerHighest,
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: isDark ? scheme.surfaceContainerHigh : MailColors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MailShapes.control),
      ),
    ),
    drawerTheme: DrawerThemeData(
      backgroundColor: isDark ? scheme.surfaceContainerLow : MailColors.white,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        // Android keeps the platform predictive-back transition; iOS and macOS
        // keep the native edge-swipe stack. Desktop gets the restrained
        // blue-flow fade/slide.
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        TargetPlatform.fuchsia: MailPageTransitionsBuilder(),
        TargetPlatform.linux: MailPageTransitionsBuilder(),
        TargetPlatform.windows: MailPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}

ColorScheme _scheme(Brightness brightness) {
  final base = ColorScheme.fromSeed(
    seedColor: MailColors.brandBlue,
    brightness: brightness,
  );
  if (brightness == Brightness.light) {
    return base.copyWith(
      primary: MailColors.brandBlue,
      onPrimary: MailColors.white,
      primaryContainer: const Color(0xFFE4EBFF),
      onPrimaryContainer: const Color(0xFF00164D),
      secondary: const Color(0xFF4C5B77),
      onSecondary: MailColors.white,
      secondaryContainer: const Color(0xFFE9EEF9),
      onSecondaryContainer: const Color(0xFF15213A),
      tertiary: const Color(0xFF5C5F6B),
      onTertiary: MailColors.white,
      tertiaryContainer: const Color(0xFFF0F1F4),
      onTertiaryContainer: MailColors.ink,
      surface: MailColors.ivory,
      onSurface: MailColors.ink,
      onSurfaceVariant: const Color(0xFF5A6478),
      surfaceContainerLowest: MailColors.white,
      surfaceContainerLow: const Color(0xFFFBFBF7),
      surfaceContainer: const Color(0xFFF1F2ED),
      surfaceContainerHigh: const Color(0xFFECEDE8),
      surfaceContainerHighest: const Color(0xFFE6E7E2),
      outline: const Color(0xFFC7CBD2),
      outlineVariant: const Color(0xFFE3E4DF),
      error: const Color(0xFFB3261E),
      onError: MailColors.white,
      errorContainer: const Color(0xFFF9DEDC),
      onErrorContainer: const Color(0xFF410E0B),
      inverseSurface: MailColors.ink,
      onInverseSurface: const Color(0xFFF2F4FA),
      inversePrimary: const Color(0xFFB8CBFF),
    );
  }
  return base.copyWith(
    primary: const Color(0xFFA9C3FF),
    onPrimary: const Color(0xFF00164D),
    primaryContainer: MailColors.brandBlue,
    onPrimaryContainer: const Color(0xFFF0F4FF),
    secondary: const Color(0xFFB9C6E4),
    onSecondary: const Color(0xFF1B2942),
    secondaryContainer: const Color(0xFF243758),
    onSecondaryContainer: const Color(0xFFE4ECFF),
    tertiary: const Color(0xFFC4C6D0),
    onTertiary: const Color(0xFF1A1C22),
    tertiaryContainer: const Color(0xFF2A2D36),
    onTertiaryContainer: const Color(0xFFE6E8F0),
    surface: const Color(0xFF0B1328),
    onSurface: const Color(0xFFE9EDF7),
    onSurfaceVariant: const Color(0xFFB2BDD4),
    surfaceContainerLowest: const Color(0xFF070E1F),
    surfaceContainerLow: const Color(0xFF0F1A31),
    surfaceContainer: const Color(0xFF14213B),
    surfaceContainerHigh: const Color(0xFF192845),
    surfaceContainerHighest: const Color(0xFF1F3050),
    outline: const Color(0xFF5A6880),
    outlineVariant: const Color(0xFF2A3A56),
    error: const Color(0xFFFFB4AB),
    onError: const Color(0xFF690005),
    errorContainer: const Color(0xFF93000A),
    onErrorContainer: const Color(0xFFFFDAD6),
    inverseSurface: const Color(0xFFE9EDF7),
    onInverseSurface: const Color(0xFF17213B),
    inversePrimary: MailColors.brandBlue,
  );
}

TextTheme _textTheme(TextTheme base, ColorScheme scheme) {
  return base
      .copyWith(
        displaySmall: base.displaySmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.8,
          height: 1.16,
        ),
        headlineMedium: base.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          height: 1.22,
        ),
        headlineSmall: base.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        titleLarge: base.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        bodyLarge: base.bodyLarge?.copyWith(height: 1.45),
        bodyMedium: base.bodyMedium?.copyWith(height: 1.45),
        bodySmall: base.bodySmall?.copyWith(height: 1.4),
        labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      )
      .apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
        decorationColor: scheme.onSurface,
      );
}
