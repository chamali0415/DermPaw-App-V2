import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the app's current language and notifies listeners when it changes.
/// The choice is saved on the phone. If saving/loading ever fails,
/// the app still works - it just starts in English.
class LanguageController {
  static const String _prefKey = 'app_language';

  static final ValueNotifier<Locale> locale = ValueNotifier(const Locale('en'));

  /// Loads the saved language in the background (never blocks app start).
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 3));
      final code = prefs.getString(_prefKey);
      if (code == 'si' || code == 'en') locale.value = Locale(code!);
    } catch (e) {
      debugPrint('LanguageController.load failed: $e');
    }
  }

  static Future<void> setLanguage(String code) async {
    locale.value = Locale(code); // change the screen immediately
    try {
      final prefs = await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 3));
      await prefs.setString(_prefKey, code);
    } catch (e) {
      debugPrint('LanguageController.setLanguage failed: $e');
    }
  }

  static void toggle() => setLanguage(isSinhala ? 'en' : 'si');

  static bool get isSinhala => locale.value.languageCode == 'si';
}