import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import '../localization/language_controller.dart';
import '../localization/app_strings.dart';

/// EN / සිං pill switch, placed next to the light/dark ThemeToggleButton.
class LanguageToggleButton extends StatelessWidget {
  const LanguageToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: LanguageController.locale,
      builder: (context, locale, _) {
        final isSi = locale.languageCode == 'si';
        final isDark = ThemeController.isDarkNow(context);
        final track = isDark ? const Color(0xFF232A35) : const Color(0xFFE9EDF5);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Tooltip(
            message: context.tr('change_language'),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: LanguageController.toggle,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(color: track, borderRadius: BorderRadius.circular(20)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _half('EN', !isSi),
                    _half('සිං', isSi),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _half(String label, bool active) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: active ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        boxShadow: active
            ? [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 4, offset: const Offset(0, 1))]
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: active ? AppColors.primaryBlue : Colors.grey,
        ),
      ),
    );
  }
}