import 'package:flutter/material.dart';

/// Holds the app's current theme mode and notifies listeners when it changes.
class ThemeController {
  static final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.system);

  /// Switch between light and dark based on what is ACTUALLY on screen now
  /// (the old version did nothing on the first tap when the phone was in dark mode).
  static void toggle([BuildContext? context]) {
    final dark = context != null ? isDarkNow(context) : mode.value == ThemeMode.dark;
    mode.value = dark ? ThemeMode.light : ThemeMode.dark;
  }

  static void setDark(bool dark) => mode.value = dark ? ThemeMode.dark : ThemeMode.light;

  static bool isDarkNow(BuildContext context) =>
      mode.value == ThemeMode.dark ||
      (mode.value == ThemeMode.system &&
          MediaQuery.platformBrightnessOf(context) == Brightness.dark);

  static bool get isDark => mode.value == ThemeMode.dark;
}
