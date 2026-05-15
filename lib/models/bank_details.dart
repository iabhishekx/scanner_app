class BankDetails {
  final String? accountHolderName;
  final String? accountNumber;
  final String? ifscCode;
  final String? bankName;

  const BankDetails({
    this.accountHolderName,
    this.accountNumber,
    this.ifscCode,
    this.bankName,
  });

  bool get hasData =>
      accountHolderName != null ||
      accountNumber != null ||
      ifscCode != null ||
      bankName != null;

  @override
  String toString() =>
      'BankDetails(name: $accountHolderName, account: $accountNumber, ifsc: $ifscCode, bank: $bankName)';
}
