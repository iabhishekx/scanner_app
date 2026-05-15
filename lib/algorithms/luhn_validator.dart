/// Luhn Algorithm implementation — validates credit/debit card numbers.
/// Implemented manually as per assignment requirements.
class LuhnValidator {
  const LuhnValidator._();

  /// Returns true if the card number passes the Luhn check.
  /// [cardNumber] may contain spaces or dashes — they are stripped first.
  static bool isValidCard(String cardNumber) {
    // 1. Strip all non-digit characters (spaces, dashes, etc.)
    final digits = cardNumber.replaceAll(RegExp(r'[^0-9]'), '');

    // 2. Must have between 13 and 19 digits (standard card range)
    if (digits.length < 13 || digits.length > 19) return false;

    int sum = 0;
    bool alternate = false;

    // 3. Iterate from right to left
    for (int i = digits.length - 1; i >= 0; i--) {
      int n = int.parse(digits[i]);

      if (alternate) {
        n *= 2;
        // If doubling results in two digits, sum them (e.g. 16 → 1+6 = 7)
        if (n > 9) n -= 9;
      }

      sum += n;
      alternate = !alternate;
    }

    // 4. Valid if total is divisible by 10
    return sum % 10 == 0;
  }
}
