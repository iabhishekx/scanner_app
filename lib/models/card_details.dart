class CardDetails {
  final String? cardNumber;
  final String? expiryDate;
  final String? cardHolderName;
  final bool isValid;

  const CardDetails({
    this.cardNumber,
    this.expiryDate,
    this.cardHolderName,
    this.isValid = false,
  });

  /// Masked card number e.g. XXXX XXXX XXXX 1234
  String get maskedCardNumber {
    if (cardNumber == null || cardNumber!.isEmpty) return '';
    final digits = cardNumber!.replaceAll(RegExp(r'\s'), '');
    if (digits.length < 4) return digits;
    final last4 = digits.substring(digits.length - 4);
    final masked = 'XXXX XXXX XXXX $last4';
    return masked;
  }

  bool get hasData =>
      cardNumber != null || expiryDate != null || cardHolderName != null;

  @override
  String toString() =>
      'CardDetails(cardNumber: $cardNumber, expiry: $expiryDate, name: $cardHolderName, valid: $isValid)';
}
