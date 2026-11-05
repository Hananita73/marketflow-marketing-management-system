class InputValidators {
  InputValidators._();

  static final RegExp _emailPattern = RegExp(
    r"^[A-Z0-9.!#$%&'*+/=?^_`{|}~-]+@"
    r"[A-Z0-9](?:[A-Z0-9-]{0,61}[A-Z0-9])?"
    r"(?:\.[A-Z0-9](?:[A-Z0-9-]{0,61}[A-Z0-9])?)+$",
    caseSensitive: false,
  );

  static String? email(String? value, {bool required = true}) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return required ? 'Email is required' : null;
    if (email.length > 254 || !_emailPattern.hasMatch(email)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  static String? ethiopianPhone(String? value, {bool required = true}) {
    final phone = value?.trim() ?? '';
    if (phone.isEmpty) return required ? 'Phone number is required' : null;

    final compact = phone.replaceAll(RegExp(r'[\s().-]'), '');
    final local = RegExp(r'^0[79]\d{8}$');
    final international = RegExp(r'^\+251[79]\d{8}$');
    if (!local.hasMatch(compact) && !international.hasMatch(compact)) {
      return 'Use a 10-digit Ethiopian mobile number starting 09 or 07';
    }
    return null;
  }
}
