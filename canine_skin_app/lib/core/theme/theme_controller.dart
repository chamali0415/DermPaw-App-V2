import 'package:flutter/material.dart';

/// Holds the app's current theme mode and notifies listeners when it changes.
class ThemeController {
  static final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.system);

  static void toggle() {
    mode.value = mode.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
  }

  static bool get isDark => mode.value == ThemeMode.dark;
}