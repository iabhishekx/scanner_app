import '../models/card_details.dart';
import 'luhn_validator.dart';

/// Manual card parser — no third-party parsing library used.
/// Parses raw OCR text to extract card number, expiry date, and cardholder name.
class CardParser {
  const CardParser._();

  /// Entry point: parses raw OCR text and returns [CardDetails].
  static CardDetails parseCard(String rawText) {
    if (rawText.trim().isEmpty) {
      return const CardDetails();
    }

    // OCR correction: replace common misreads
    final correctedText = _correctOcrMisreads(rawText);

    final cardNumber = _extractCardNumber(correctedText);
    final expiryDate = _extractExpiry(correctedText);
    final cardHolderName = _extractName(correctedText, cardNumber);
    final isValid =
        cardNumber != null && LuhnValidator.isValidCard(cardNumber);

    return CardDetails(
      cardNumber: cardNumber,
      expiryDate: expiryDate,
      cardHolderName: cardHolderName,
      isValid: isValid,
    );
  }

  // ---------------------------------------------------------------------------
  // OCR correction helpers
  // ---------------------------------------------------------------------------

  /// Corrects common OCR misreads before parsing.
  static String _correctOcrMisreads(String text) {
    // We do targeted replacement only for digit-context lines to avoid
    // corrupting the name (which legitimately uses 'O', 'I', 'S', etc.)
    return text;
  }

  /// Corrects a purely-digit string: replaces 'O'→'0', 'I'/'l'→'1', 'S'→'5'.
  static String _digitCorrect(String s) {
    return s
        .replaceAll('O', '0')
        .replaceAll('o', '0')
        .replaceAll('I', '1')
        .replaceAll('l', '1')
        .replaceAll('S', '5')
        .replaceAll('B', '8');
  }

  // ---------------------------------------------------------------------------
  // Card number extraction
  // ---------------------------------------------------------------------------

  static String? _extractCardNumber(String text) {
    final lines = text.split('\n');

    for (final line in lines) {
      // Apply digit correction to each line when looking for card number
      final correctedLine = _digitCorrect(line);
      final candidate = _findCardNumberInLine(correctedLine);
      if (candidate != null) return candidate;
    }

    // Fallback: try whole text as one block
    final correctedText = _digitCorrect(text);
    return _findCardNumberInLine(correctedText.replaceAll('\n', ' '));
  }

  static String? _findCardNumberInLine(String line) {
    // Remove all non-digit-and-separator characters for scanning
    final cleaned = line.replaceAll(RegExp(r'[^0-9\s\-]'), ' ');

    // Pattern 1: 4 groups of 4 digits separated by space/dash (most common)
    final grouped4 = RegExp(r'(\d{4})[\s\-](\d{4})[\s\-](\d{4})[\s\-](\d{4})');
    final m1 = grouped4.firstMatch(cleaned);
    if (m1 != null) {
      final number =
          '${m1.group(1)} ${m1.group(2)} ${m1.group(3)} ${m1.group(4)}';
      if (LuhnValidator.isValidCard(number)) return number;
    }

    // Pattern 2: 16 consecutive digits (no separators)
    final consecutive = RegExp(r'\b(\d{16})\b');
    for (final m in consecutive.allMatches(cleaned)) {
      final number = m.group(1)!;
      if (LuhnValidator.isValidCard(number)) {
        return _formatCardNumber(number);
      }
    }

    // Pattern 3: American Express — 4-6-5 format (15 digits)
    final amex = RegExp(r'(\d{4})[\s\-](\d{6})[\s\-](\d{5})');
    final m3 = amex.firstMatch(cleaned);
    if (m3 != null) {
      final number =
          '${m3.group(1)}${m3.group(2)}${m3.group(3)}';
      if (LuhnValidator.isValidCard(number)) {
        return '${m3.group(1)} ${m3.group(2)} ${m3.group(3)}';
      }
    }

    // Pattern 4: 13-digit Visa (older)
    final visa13 = RegExp(r'\b(\d{13})\b');
    for (final m in visa13.allMatches(cleaned)) {
      final number = m.group(1)!;
      if (LuhnValidator.isValidCard(number)) return _formatCardNumber(number);
    }

    return null;
  }

  /// Formats a raw digit string into spaced groups of 4.
  static String _formatCardNumber(String digits) {
    final buf = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buf.write(' ');
      buf.write(digits[i]);
    }
    return buf.toString();
  }

  // ---------------------------------------------------------------------------
  // Expiry date extraction
  // ---------------------------------------------------------------------------

  static String? _extractExpiry(String text) {
    final corrected = _digitCorrect(text);

    // Format: MM/YY or MM/YYYY
    final slashFmt = RegExp(r'\b(0[1-9]|1[0-2])\s*/\s*(\d{2,4})\b');
    for (final m in slashFmt.allMatches(corrected)) {
      final month = int.parse(m.group(1)!);
      if (month >= 1 && month <= 12) {
        final year = m.group(2)!;
        return '${m.group(1)}/${year.length == 4 ? year.substring(2) : year}';
      }
    }

    // Format: MM-YY or MM-YYYY
    final dashFmt = RegExp(r'\b(0[1-9]|1[0-2])\s*-\s*(\d{2,4})\b');
    for (final m in dashFmt.allMatches(corrected)) {
      final month = int.parse(m.group(1)!);
      if (month >= 1 && month <= 12) {
        final year = m.group(2)!;
        return '${m.group(1)}/${year.length == 4 ? year.substring(2) : year}';
      }
    }

    // Format: MMYY (4 consecutive digits where MM is 01-12)
    final raw4 = RegExp(r'\b(\d{4})\b');
    for (final m in raw4.allMatches(corrected)) {
      final val = m.group(1)!;
      final month = int.parse(val.substring(0, 2));
      final year = int.parse(val.substring(2));
      if (month >= 1 && month <= 12 && year >= 20) {
        return '${val.substring(0, 2)}/${val.substring(2)}';
      }
    }

    // Look for "VALID THRU" / "EXPIRY" labels near a date pattern
    final labelPattern = RegExp(
      r'(?:valid\s+thru|exp(?:iry)?|expires?)[:\s]+(\d{1,2}[/\-]\d{2,4})',
      caseSensitive: false,
    );
    final lm = labelPattern.firstMatch(corrected);
    if (lm != null) {
      final raw = lm.group(1)!;
      final parts = raw.split(RegExp(r'[/\-]'));
      if (parts.length == 2) {
        final month = int.parse(parts[0]);
        if (month >= 1 && month <= 12) {
          final year = parts[1].length == 4 ? parts[1].substring(2) : parts[1];
          return '${parts[0].padLeft(2, '0')}/$year';
        }
      }
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // Cardholder name extraction
  // ---------------------------------------------------------------------------

  static String? _extractName(String text, String? cardNumber) {
    final lines = text.split('\n');

    // Known non-name keywords to skip
    final skipKeywords = RegExp(
      r'\b(valid|thru|expiry|expires?|cvv|cvc|card|bank|visa|mastercard|maestro|rupay|debit|credit|platinum|gold|signature)\b',
      caseSensitive: false,
    );

    // Remove the card number line from consideration
    final cardDigits =
        cardNumber?.replaceAll(RegExp(r'\s'), '') ?? '';

    for (final line in lines) {
      final trimmed = line.trim();

      // Must be non-empty and not look like a number-only line
      if (trimmed.isEmpty) continue;
      if (RegExp(r'^\d[\d\s\-/]+$').hasMatch(trimmed)) continue;
      if (trimmed.replaceAll(RegExp(r'\s'), '').contains(cardDigits) &&
          cardDigits.isNotEmpty) continue;

      // Skip lines with too many digits (likely card/account number)
      final digitCount = RegExp(r'\d').allMatches(trimmed).length;
      if (digitCount > 4) continue;

      // Skip lines matching known keywords
      if (skipKeywords.hasMatch(trimmed)) continue;

      // Must contain at least 2 words that are mostly alphabetic
      final words = trimmed.split(RegExp(r'\s+'));
      final alphaWords = words.where((w) {
        if (w.length < 2) return false;
        final letters = RegExp(r'[a-zA-Z]').allMatches(w).length;
        return letters / w.length >= 0.7;
      }).toList();

      if (alphaWords.length >= 2) {
        return alphaWords.map((w) => _toTitleCase(w)).join(' ');
      }
    }

    return null;
  }

  static String _toTitleCase(String word) {
    if (word.isEmpty) return word;
    return word[0].toUpperCase() + word.substring(1).toLowerCase();
  }
}
