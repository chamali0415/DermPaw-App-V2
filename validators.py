import re

# Sri Lankan numbers: 10 digits locally (0 + 9 digits, e.g. 0771234567),
# or +94 followed by the same 9 digits without the leading 0 (+94771234567).
_SL_PHONE = re.compile(r"^(?:\+94|0094|94|0)?([1-9]\d{8})$")


def normalize_sl_phone(raw):
    """
    Returns the number in the standard form +94XXXXXXXXX, or None if invalid.
    Accepts: 0771234567, 771234567, +94771234567, 94771234567,
             "+94 77 123 4567", "077-123-4567"
    """
    if raw is None:
        return None
    cleaned = re.sub(r"[\s\-()]", "", str(raw))
    match = _SL_PHONE.match(cleaned)
    if not match:
        return None
    return "+94" + match.group(1)


PHONE_ERROR = "Enter a valid Sri Lankan phone number, e.g. +94 77 123 4567 (10 digits: 0771234567)"
