import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Sri Lankan phone number helpers.
/// The user types the local number (0771234567 = 10 digits, or 771234567);
/// the "+94" prefix is shown in the field and added automatically.
class PhoneUtils {
  static const String errorText = "Enter a valid 10-digit number, e.g. 0771234567";

  /// Returns "+94XXXXXXXXX" or null if invalid. Empty input returns "".
  static String? normalize(String input) {
    final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return "";
    String local;
    if (digits.length == 10 && digits.startsWith('0')) {
      local = digits.substring(1);
    } else if (digits.length == 9 && !digits.startsWith('0')) {
      local = digits;
    } else if (digits.length == 11 && digits.startsWith('94')) {
      local = digits.substring(2);
    } else {
      return null;
    }
    if (local.startsWith('0')) return null;
    return "+94$local";
  }

  /// Converts a stored "+94771234567" back to "0771234567" for editing.
  static String toLocal(String? stored) {
    if (stored == null || stored.isEmpty) return "";
    final digits = stored.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 11 && digits.startsWith('94')) return "0${digits.substring(2)}";
    return digits;
  }

  /// Text field with a fixed +94 prefix that only accepts 10 digits.
  static TextField field({
    required TextEditingController controller,
    String? errorText,
    String? labelText,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.phone,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(10),
      ],
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: "0771234567",
        prefixText: "+94  ",
        counterText: "",
        errorText: errorText,
      ),
    );
  }
}
