/// Centralised, reusable input validation.
///
/// Every validation rule is deliberately conservative: institutional emails
/// only, sanitised free text, length-bounded inputs. This mirrors the
/// server-side validation the API layer enforces (defence in depth).
library;

abstract final class Validators {
  static final RegExp _email = RegExp(r'^[\w.+-]+@([\w-]+\.)+[A-Za-z]{2,}$');
  static final RegExp _avitEmail = RegExp(
    r'^[\w.+-]+@avit\.ac\.in$',
    caseSensitive: false,
  );
  static final RegExp _studentId = RegExp(r'^AVIT\d{4}[A-Z]{2,4}\d{2,4}$');
  static final RegExp _phone = RegExp(r'^[6-9]\d{9}$');
  static final RegExp _alphanumeric = RegExp(
    r'''^[A-Za-z0-9\s\-.,/&()'"?@:]+$''',
  );
  static final RegExp _nameOnly = RegExp(r"""^[A-Za-z\s.'-]{2,60}$""");

  /// Blocks markup / script payloads in free-text fields.
  static final RegExp _unsafe = RegExp(
    r'[<>`\\$]|\$\{|%00|javascript:|onerror\s*=|<script',
    caseSensitive: false,
  );

  static String? email(String? value) {
    final String v = (value ?? '').trim();
    if (v.isEmpty) return 'Email is required';
    if (v.length > 120) return 'Email is too long';
    if (!_email.hasMatch(v)) return 'Enter a valid email address';
    return null;
  }

  /// Accepts either an institutional email or a student ID.
  static String? userIdOrEmail(String? value) {
    final String v = (value ?? '').trim();
    if (v.isEmpty) return 'Student ID or email is required';
    if (v.contains('@')) return email(v);
    if (!_studentId.hasMatch(v.toUpperCase())) {
      return 'Enter a valid student ID or email';
    }
    return null;
  }

  /// Only `@avit.ac.in` addresses may register a student account.
  static String? institutionalEmail(String? value) {
    final String? basic = email(value);
    if (basic != null) return basic;
    if (!_avitEmail.hasMatch((value ?? '').trim())) {
      return 'Use your institutional email (@avit.ac.in)';
    }
    return null;
  }

  static String? studentId(String? value) {
    final String v = (value ?? '').trim().toUpperCase();
    if (v.isEmpty) return 'Student ID is required';
    if (!_studentId.hasMatch(v)) {
      return 'Format: AVIT2026CS001';
    }
    return null;
  }

  static String? phone(String? value) {
    final String v = (value ?? '').trim().replaceAll(RegExp(r'[\s-]'), '');
    if (v.isEmpty) return 'Phone number is required';
    if (!_phone.hasMatch(v)) return 'Enter a valid 10-digit mobile number';
    return null;
  }

  static String? password(String? value) {
    final String v = value ?? '';
    if (v.isEmpty) return 'Password is required';
    if (v.length < 8) return 'Use at least 8 characters';
    if (v.length > 72) return 'Password is too long';
    final bool hasUpper = v.contains(RegExp(r'[A-Z]'));
    final bool hasLower = v.contains(RegExp(r'[a-z]'));
    final bool hasDigit = v.contains(RegExp(r'\d'));
    final bool hasSymbol = v.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'));
    if (!(hasUpper && hasLower && hasDigit && hasSymbol)) {
      return 'Include upper, lower, number and symbol';
    }
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    if ((value ?? '').isEmpty) return 'Please confirm your password';
    if (value != password) return 'Passwords do not match';
    return null;
  }

  static String? name(String? value) {
    final String v = (value ?? '').trim();
    if (v.isEmpty) return 'Name is required';
    if (!_nameOnly.hasMatch(v)) return 'Enter a valid name';
    return null;
  }

  static String? otp(String? value) {
    final String v = (value ?? '').trim();
    if (v.length != 6) return 'Enter the 6-digit code';
    if (!v.contains(RegExp(r'^\d{6}$'))) return 'Digits only';
    return null;
  }

  /// Generic sanitised single-line text (reasons, destinations, comments).
  static String? safeText(
    String? value, {
    String field = 'This field',
    int minLength = 1,
    int maxLength = 240,
    bool required = true,
  }) {
    final String v = (value ?? '').trim();
    if (v.isEmpty) {
      return required ? '$field is required' : null;
    }
    if (v.length < minLength) return 'Enter at least $minLength characters';
    if (v.length > maxLength) return 'Maximum $maxLength characters';
    if (_unsafe.hasMatch(v)) return 'Special characters are not allowed';
    if (!_alphanumeric.hasMatch(v)) return 'Only letters and numbers allowed';
    return null;
  }

  static String? required(String? value, {String field = 'This field'}) {
    if ((value ?? '').trim().isEmpty) return '$field is required';
    return null;
  }

  /// Not-after / not-before style date sanity checks.
  static String? futureDate(DateTime? value, {String field = 'Date'}) {
    if (value == null) return 'Select a $field';
    final DateTime now = DateTime.now();
    if (value.year < now.year - 1) return '$field is too far in the past';
    return null;
  }

  static bool isSafeQuery(String query) => !_unsafe.hasMatch(query);
}
