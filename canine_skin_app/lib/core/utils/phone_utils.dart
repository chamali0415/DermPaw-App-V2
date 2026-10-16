import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Sri Lankan phone number helpers.
/// The field shows a fixed "+94" and the user types the 9 digits after it
/// (e.g. 771234567). A leading 0 is not allowed, because +94 replaces it.
class PhoneUtils {
  static const String errorText = "Enter 9 digits after +94, e.g. 771234567";

  /// Returns "+94XXXXXXXXX" or null if invalid. Empty input returns "".
  static String? normalize(String input) {
    final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return "";
    if (digits.length != 9 || digits.startsWith('0')) return null;
    return "+94$digits";
  }

  /// Converts a stored "+94771234567" (or an old "0771234567") to the
  /// 9 digits shown in the field: "771234567".
  static String toLocal(String? stored) {
    if (stored == null || stored.isEmpty) return "";
    var digits = stored.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 11 && digits.startsWith('94')) digits = digits.substring(2);
    if (digits.length == 10 && digits.startsWith('0')) digits = digits.substring(1);
    return digits;
  }

  /// Text field with a fixed +94 prefix that accepts exactly 9 digits
  /// and refuses a leading 0.
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
        _NoLeadingZeroFormatter(),
        LengthLimitingTextInputFormatter(9),
      ],
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: "771234567",
        prefixText: "+94  ",
        prefixIcon: const Icon(Icons.phone_outlined),
        helperText: "9 digits, without the first 0",
        counterText: "",
        errorText: errorText,
      ),
    );
  }
}

/// Removes zeros typed at the start (the 0 of 077... is replaced by +94).
class _NoLeadingZeroFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text.replaceFirst(RegExp(r'^0+'), '');
    if (text == newValue.text) return newValue;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
