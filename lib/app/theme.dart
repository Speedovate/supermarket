import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

ThemeData buildAppTheme() {
  const primary = AppColors.logoBlue;
  const primaryDark = AppColors.logoBlueDark;
  const accent = Color(0xFFE31E24);
  const bg = Color(0xFFF7F8FC);
  const text = Color(0xFF172033);
  const secondary = Color(0xFF667085);
  const border = Color(0xFFE4E7EC);
  const selection = Color(0xFFBFD7FF);

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      secondary: accent,
      surface: Colors.white,
      error: accent,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: bg,
  );

  Color? resolvePrimaryButtonOverlay(Set<WidgetState> states) {
    return Colors.transparent;
  }

  Color resolvePrimaryButtonBackground(Set<WidgetState> states) {
    return AppColors.brandingBlueInteractiveBackground(
      states,
      baseColor: primary,
    );
  }

  Color? resolveSecondaryButtonOverlay(Set<WidgetState> states) {
    if (states.contains(WidgetState.pressed)) {
      return Colors.black.withValues(
        alpha: AppColors.neutralPressedOverlayAlpha,
      );
    }
    if (states.contains(WidgetState.hovered)) {
      return Colors.black.withValues(
        alpha: AppColors.neutralHoverOverlayAlpha,
      );
    }
    if (states.contains(WidgetState.focused)) {
      return Colors.black.withValues(
        alpha: AppColors.neutralFocusOverlayAlpha,
      );
    }
    return null;
  }

  return base.copyWith(
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    splashColor: Colors.transparent,
    hoverColor: Colors.transparent,
    textSelectionTheme: const TextSelectionThemeData(
      selectionColor: selection,
      cursorColor: primaryDark,
      selectionHandleColor: primaryDark,
    ),
    textTheme: base.textTheme
        .apply(
          fontFamily: 'Poppins',
          bodyColor: text,
          displayColor: text,
        )
        .copyWith(),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      hintStyle: const TextStyle(color: secondary),
      labelStyle: const TextStyle(color: text),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: primaryDark, width: 1.4),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      side: const BorderSide(color: border),
      selectedColor: primary,
      secondarySelectedColor: primary,
      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        splashFactory: NoSplash.splashFactory,
        enableFeedback: false,
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ).copyWith(
        animationDuration: Duration.zero,
        backgroundColor: WidgetStateProperty.resolveWith(
          resolvePrimaryButtonBackground,
        ),
        overlayColor: WidgetStateProperty.resolveWith(resolvePrimaryButtonOverlay),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 52),
        foregroundColor: primaryDark,
        side: const BorderSide(color: border),
        splashFactory: NoSplash.splashFactory,
        enableFeedback: false,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ).copyWith(
        animationDuration: Duration.zero,
        overlayColor: WidgetStateProperty.resolveWith(resolveSecondaryButtonOverlay),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryDark,
        splashFactory: NoSplash.splashFactory,
        enableFeedback: false,
      ).copyWith(
        animationDuration: Duration.zero,
        overlayColor: WidgetStateProperty.resolveWith(resolveSecondaryButtonOverlay),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        splashFactory: NoSplash.splashFactory,
        foregroundColor: text,
      ).copyWith(
        overlayColor: WidgetStateProperty.resolveWith(resolveSecondaryButtonOverlay),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: text,
      elevation: 0,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shadowColor: Colors.black12,
      dividerColor: border,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      headerBackgroundColor: Colors.white,
      headerForegroundColor: text,
      dayForegroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return Colors.white;
        }
        return text;
      }),
      dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primary;
        }
        return Colors.white;
      }),
      todayForegroundColor: const WidgetStatePropertyAll(primaryDark),
      todayBackgroundColor: const WidgetStatePropertyAll(Colors.white),
      yearForegroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return Colors.white;
        }
        return text;
      }),
      yearBackgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primary;
        }
        return Colors.white;
      }),
      rangePickerBackgroundColor: Colors.white,
      rangePickerSurfaceTintColor: Colors.white,
    ),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: Colors.white,
      dialBackgroundColor: Colors.white,
      dayPeriodColor: Colors.white,
      dayPeriodTextColor: text,
      hourMinuteColor: Colors.white,
      hourMinuteTextColor: text,
      dialHandColor: primary,
      dialTextColor: text,
      entryModeIconColor: text,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
    ),
  );
}
