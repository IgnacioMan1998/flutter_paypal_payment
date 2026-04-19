import 'package:http/http.dart' as http;
import 'dart:convert';

/// Utility functions for PayPal operations.
///
/// Follows Interface Segregation: only pure, stateless helpers.
abstract final class PaypalUtils {
  /// Luhn algorithm — validates a card number checksum.
  static bool luhnCheck(String number) {
    int sum = 0;
    bool alternate = false;
    for (int i = number.length - 1; i >= 0; i--) {
      int digit = int.parse(number[i]);
      if (alternate) {
        digit *= 2;
        if (digit > 9) digit -= 9;
      }
      sum += digit;
      alternate = !alternate;
    }
    return sum % 10 == 0;
  }

  /// Extracts a safe, sanitized error message from a PayPal API response.
  /// Never exposes the raw response body.
  static String safeErrorMessage(http.Response response) {
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final name = data['name'] ?? '';
      final message = data['message'] ?? '';
      final debugId = data['debug_id'] ?? '';
      return 'PayPal error: $name – $message (debug_id: $debugId)';
    } catch (_) {
      return 'PayPal API error (HTTP ${response.statusCode})';
    }
  }
}
