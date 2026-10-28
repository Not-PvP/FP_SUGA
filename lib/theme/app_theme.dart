import 'package:flutter/material.dart';

// SUGA's design tokens. Screens use these instead of typing hex values, so a
// colour or size only ever changes in one place.

class AppColors {
  AppColors._();

  static const ink = Color(0xFF070A0F); // app background
  static const surface = Color(0xFF111720); // cards
  static const surfaceRaised = Color(0xFF18202B); // unread cards, menus, snackbars
  static const chip = Color(0xFF1A212C); // feeder chips, neutral icon tiles
  static const line = Color(0xFF292F38); // card borders and dividers
  static const lineStrong = Color(0xFF3A424E); // outlined buttons

  static const text = Colors.white;
  static const textSoft = Color(0xFFD1D5DB);
  static const textMuted = Color(0xFF9CA3AF);

  // Brand and actions only. Status colours below are kept separate from it.
  static const amber = Color(0xFFFFBF00);
  static const amberSoft = Color(0xFF292315);

  // Power states.
  static const outage = Color(0xFFF87171);
  static const outageSoft = Color(0xFF231417);
  static const powerOn = Color(0xFF4ADE80);
  static const planned = Color(0xFF93C5FD);
}

class AppRadius {
  AppRadius._();

  static const double chip = 8;
  static const double card = 16;
  static const double pill = 999;
}

class AppText {
  AppText._();

  static const font = 'PlusJakartaSans';

  static const screenTitle = TextStyle(
    fontFamily: font,
    color: AppColors.text,
    fontSize: 26,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );
  static const headline = TextStyle(
    fontFamily: font,
    color: AppColors.text,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.15,
  );
  static const section = TextStyle(
    fontFamily: font,
    color: AppColors.text,
    fontSize: 16,
    fontWeight: FontWeight.w700,
  );
  static const cardTitle = TextStyle(
    fontFamily: font,
    color: AppColors.text,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );
  static const body = TextStyle(
    fontFamily: font,
    color: AppColors.textSoft,
    fontSize: 14,
    height: 1.5,
  );
  static const muted = TextStyle(
    fontFamily: font,
    color: AppColors.textMuted,
    fontSize: 13,
    height: 1.4,
  );
  static const small = TextStyle(
    fontFamily: font,
    color: AppColors.textMuted,
    fontSize: 12,
    height: 1.3,
  );
  static const label = TextStyle(
    fontFamily: font,
    color: AppColors.textMuted,
    fontSize: 13,
    fontWeight: FontWeight.w600,
  );
}

// The app-wide dark theme. Because the defaults are set here, plain Material
// widgets (spinners, dialogs, snackbars, buttons) match SUGA without extra styling.
ThemeData buildSugaTheme() {
  const scheme = ColorScheme.dark(
    primary: AppColors.amber,
    onPrimary: AppColors.ink,
    secondary: AppColors.amber,
    onSecondary: AppColors.ink,
    surface: AppColors.surface,
    onSurface: AppColors.text,
    onSurfaceVariant: AppColors.textMuted,
    error: AppColors.outage,
    onError: AppColors.ink,
    outline: AppColors.lineStrong,
    outlineVariant: AppColors.line,
  );

  final cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadius.card),
  );
  const buttonText = TextStyle(
    fontFamily: AppText.font,
    fontSize: 15,
    fontWeight: FontWeight.w700,
  );

  OutlineInputBorder inputBorder(Color color, [double width = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        borderSide: BorderSide(color: color, width: width),
      );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.ink,
    fontFamily: AppText.font,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.ink,
      foregroundColor: AppColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: AppText.font,
        color: AppColors.text,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.amber),
    dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1, space: 1),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.surfaceRaised,
      contentTextStyle: const TextStyle(fontFamily: AppText.font, color: AppColors.text, fontSize: 14),
      actionTextColor: AppColors.amber,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.line),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.amber,
        foregroundColor: AppColors.ink,
        disabledBackgroundColor: AppColors.chip,
        disabledForegroundColor: AppColors.textMuted,
        elevation: 0,
        minimumSize: const Size(64, 52),
        shape: cardShape,
        textStyle: buttonText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.text,
        disabledForegroundColor: AppColors.textMuted,
        side: const BorderSide(color: AppColors.lineStrong),
        minimumSize: const Size(64, 48),
        shape: cardShape,
        textStyle: buttonText.copyWith(fontSize: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.amber,
        minimumSize: const Size(48, 48),
        textStyle: buttonText.copyWith(fontSize: 14),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? AppColors.ink : AppColors.textMuted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? AppColors.amber : AppColors.lineStrong,
      ),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      hintStyle: AppText.muted.copyWith(fontSize: 14),
      prefixIconColor: AppColors.amber,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: inputBorder(AppColors.line),
      enabledBorder: inputBorder(AppColors.line),
      focusedBorder: inputBorder(AppColors.amber, 1.5),
      errorBorder: inputBorder(AppColors.outage),
      focusedErrorBorder: inputBorder(AppColors.outage, 1.5),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      shape: cardShape,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.surfaceRaised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.line),
      ),
    ),
  );
}
