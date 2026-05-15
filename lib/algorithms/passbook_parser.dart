import '../models/bank_details.dart';

/// Manual passbook/bank-document parser — no third-party parsing library used.
/// Parses raw OCR text to extract account number, IFSC code, and account holder name.
class PassbookParser {
  const PassbookParser._();

  /// Entry point: parses raw OCR text and returns [BankDetails].
  static BankDetails parsePassbook(String rawText) {
    if (rawText.trim().isEmpty) return const BankDetails();

    final corrected = _correctOcrMisreads(rawText);

    final ifsc = _extractIfsc(corrected);
    final accountNumber = _extractAccountNumber(corrected);
    final bankName = _extractBankName(corrected);
    final accountHolderName = _extractName(corrected, accountNumber);

    return BankDetails(
      accountHolderName: accountHolderName,
      accountNumber: accountNumber,
      ifscCode: ifsc,
      bankName: bankName,
    );
  }

  // ---------------------------------------------------------------------------
  // OCR correction
  // ---------------------------------------------------------------------------

  static String _correctOcrMisreads(String text) {
    // Only apply digit corrections in sections that look numeric
    return text;
  }

  /// Digit-context OCR correction.
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
  // IFSC Code extraction
  // ---------------------------------------------------------------------------

  /// IFSC format: 4 alpha + 0 + 6 alphanumeric, e.g. SBIN0001234
  static String? _extractIfsc(String text) {
    // Look for labeled IFSC first
    final labeledPattern = RegExp(
      r'(?:ifsc|ifsc\s*code|rtgs)[:\s]*([A-Z]{4}0[A-Z0-9]{6})',
      caseSensitive: false,
    );
    final lm = labeledPattern.firstMatch(text.toUpperCase());
    if (lm != null) return lm.group(1)!.toUpperCase();

    // Scan all lines for bare IFSC pattern
    final ifscPattern = RegExp(r'\b([A-Z]{4}0[A-Z0-9]{6})\b');
    for (final line in text.split('\n')) {
      final m = ifscPattern.firstMatch(line.toUpperCase());
      if (m != null) return m.group(1)!.toUpperCase();
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // Account number extraction
  // ---------------------------------------------------------------------------

  static String? _extractAccountNumber(String text) {
    final lines = text.split('\n');

    // Strategy 1: Look for labeled account number
    final labelPattern = RegExp(
      r'(?:account\s*(?:no|number|num)|a/c\s*(?:no)?)[:\s]*([0-9\s]{9,20})',
      caseSensitive: false,
    );
    for (final line in lines) {
      final m = labelPattern.firstMatch(line);
      if (m != null) {
        final candidate = _digitCorrect(m.group(1)!).replaceAll(' ', '');
        if (candidate.length >= 9 && candidate.length <= 18) {
          return candidate;
        }
      }
    }

    // Strategy 2: Find all digit-sequence candidates (9-18 digits)
    // and pick the most likely one (not a phone, pin, or IFSC-adjacent number)
    final digitSeq = RegExp(r'\b(\d[\d\s]{8,17}\d)\b');
    final candidates = <String>[];

    for (final line in lines) {
      final correctedLine = _digitCorrect(line);
      for (final m in digitSeq.allMatches(correctedLine)) {
        final raw = m.group(1)!.replaceAll(' ', '');
        if (raw.length >= 9 && raw.length <= 18) {
          // Exclude patterns that look like phone numbers (10 digits starting with 6-9)
          if (raw.length == 10 && RegExp(r'^[6-9]').hasMatch(raw)) continue;
          // Exclude pin codes (6 digits)
          if (raw.length == 6) continue;
          candidates.add(raw);
        }
      }
    }

    // Pick the candidate that appears most isolated (not part of IFSC context)
    if (candidates.isNotEmpty) {
      // Prefer longer candidates (bank account numbers are typically 11-16 digits)
      candidates.sort((a, b) {
        final aScore = _accountNumberScore(a);
        final bScore = _accountNumberScore(b);
        return bScore.compareTo(aScore);
      });
      return candidates.first;
    }

    return null;
  }

  /// Scores how likely a digit string is a bank account number.
  static int _accountNumberScore(String digits) {
    int score = 0;
    // Prefer 11-16 digit range (most Indian banks)
    if (digits.length >= 11 && digits.length <= 16) score += 10;
    // Penalise round numbers (unlikely to be account numbers)
    if (RegExp(r'^0+$').hasMatch(digits)) score -= 20;
    // Penalise all same digits
    if (digits.split('').toSet().length <= 2) score -= 10;
    return score;
  }

  // ---------------------------------------------------------------------------
  // Bank name extraction
  // ---------------------------------------------------------------------------

  static String? _extractBankName(String text) {
    final knownBanks = [
      'State Bank of India',
      'SBI',
      'HDFC Bank',
      'HDFC',
      'ICICI Bank',
      'ICICI',
      'Axis Bank',
      'Axis',
      'Punjab National Bank',
      'PNB',
      'Bank of Baroda',
      'BOB',
      'Kotak Mahindra Bank',
      'Kotak',
      'Yes Bank',
      'Canara Bank',
      'Union Bank',
      'IndusInd Bank',
      'Bank of India',
      'Central Bank',
      'Indian Bank',
      'UCO Bank',
      'Federal Bank',
      'South Indian Bank',
      'Karnataka Bank',
    ];

    for (final bank in knownBanks) {
      if (text.toLowerCase().contains(bank.toLowerCase())) {
        return bank;
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Account holder name extraction
  // ---------------------------------------------------------------------------

  static String? _extractName(String text, String? accountNumber) {
    final lines = text.split('\n');

    // Strategy 1: Look for labeled name
    final labelPattern = RegExp(
      r'(?:name|account\s*holder|a/c\s*holder|customer\s*name)[:\s]+([A-Za-z][A-Za-z\s\.]{3,40})',
      caseSensitive: false,
    );
    for (final line in lines) {
      final m = labelPattern.firstMatch(line);
      if (m != null) {
        final name = m.group(1)!.trim();
        if (_isLikelyName(name)) return _cleanName(name);
      }
    }

    // Strategy 2: Heuristic — find lines that look like proper names
    final skipKeywords = RegExp(
      r'\b(account|number|ifsc|balance|branch|date|bank|debit|credit|transaction|passbook|statement|opening|closing|savings|current|deposit)\b',
      caseSensitive: false,
    );
    final accountDigits = accountNumber ?? '';

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (skipKeywords.hasMatch(trimmed)) continue;
      if (trimmed.contains(accountDigits) && accountDigits.isNotEmpty) continue;

      // Count digit ratio
      final digits = RegExp(r'\d').allMatches(trimmed).length;
      if (digits > 2) continue;

      final words = trimmed.split(RegExp(r'\s+'));
      final alphaWords = words.where((w) {
        if (w.length < 2) return false;
        final letters = RegExp(r'[a-zA-Z]').allMatches(w).length;
        return letters / w.length >= 0.8;
      }).toList();

      if (alphaWords.length >= 2 && alphaWords.length <= 5) {
        final candidate = alphaWords.map((w) => _toTitleCase(w)).join(' ');
        if (_isLikelyName(candidate)) return candidate;
      }
    }

    return null;
  }

  static bool _isLikelyName(String s) {
    if (s.length < 4 || s.length > 50) return false;
    // Must be mostly letters
    final letters = RegExp(r'[a-zA-Z]').allMatches(s).length;
    return letters / s.length >= 0.7;
  }

  static String _cleanName(String name) {
    return name
        .trim()
        .split(RegExp(r'\s+'))
        .map(_toTitleCase)
        .join(' ');
  }

  static String _toTitleCase(String word) {
    if (word.isEmpty) return word;
    return word[0].toUpperCase() + word.substring(1).toLowerCase();
  }
}
