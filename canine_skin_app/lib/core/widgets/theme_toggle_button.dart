import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import '../localization/app_strings.dart';

/// Sun / moon pill switch for light and dark mode (as in the dashboard mockups).
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.mode,
      builder: (context, mode, _) {
        final isDark = ThemeController.isDarkNow(context);
        final track = isDark ? const Color(0xFF232A35) : const Color(0xFFE9EDF5);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Tooltip(
            message: isDark ? context.tr('switch_to_light') : context.tr('switch_to_dark'),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => ThemeController.setDark(!isDark),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(color: track, borderRadius: BorderRadius.circular(20)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _half(Icons.light_mode_rounded, !isDark, Colors.amber[700]!),
                    _half(Icons.dark_mode_rounded, isDark, AppColors.primaryBlue),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _half(IconData icon, bool active, Color activeColor) {
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
      child: Icon(icon, size: 18, color: active ? activeColor : Colors.grey),
    );
  }
}
