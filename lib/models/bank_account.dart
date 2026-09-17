class BankAccount {
  final String id;
  final String groupId;
  final String bankName;
  final String branch;
  final String accountNumber;
  final String ifsc;
  final String accountType; // 'savings', 'current'
  final String accountHolder;
  final double openingBalance;
  final String? openingBalanceDate;
  final double currentBalance;
  final int isPrimary; // 1 or 0
  final String status; // 'active', 'inactive'
  final String? bankAddress;
  final String? mobileNumber;
  final String? email;
  final String? notes;
  final String? createdAt;
  final String? updatedAt;

  BankAccount({
    required this.id,
    required this.groupId,
    required this.bankName,
    this.branch = '',
    required this.accountNumber,
    this.ifsc = '',
    this.accountType = 'savings',
    required this.accountHolder,
    this.openingBalance = 0.0,
    this.openingBalanceDate,
    this.currentBalance = 0.0,
    this.isPrimary = 0,
    this.status = 'active',
    this.bankAddress,
    this.mobileNumber,
    this.email,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  bool get isActive => status.toLowerCase() == 'active';

  /// Returns masked account number showing only last 4 digits (e.g. XXXX1234)
  String get maskedAccountNumber {
    final clean = accountNumber.trim();
    if (clean.length <= 4) return clean;
    final last4 = clean.substring(clean.length - 4);
    return 'XXXX$last4';
  }

  factory BankAccount.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0.0;
    }

    int primaryVal = 0;
    final rawPrimary = json['is_primary'];
    if (rawPrimary is bool) {
      primaryVal = rawPrimary ? 1 : 0;
    } else if (rawPrimary is num) {
      primaryVal = rawPrimary.toInt();
    } else if (rawPrimary != null) {
      final s = rawPrimary.toString().toLowerCase().trim();
      primaryVal = (s == '1' || s == 'true') ? 1 : 0;
    }

    return BankAccount(
      id: json['id']?.toString() ?? '',
      groupId: json['group_id']?.toString() ?? '',
      bankName: json['bank_name']?.toString() ?? '',
      branch: json['branch']?.toString() ?? '',
      accountNumber: json['account_number']?.toString() ?? '',
      ifsc: json['ifsc']?.toString() ?? '',
      accountType: json['account_type']?.toString() ?? 'savings',
      accountHolder: json['account_holder']?.toString() ?? '',
      openingBalance: parseDouble(json['opening_balance']),
      openingBalanceDate: json['opening_balance_date']?.toString(),
      currentBalance: parseDouble(json['current_balance']),
      isPrimary: primaryVal,
      status: json['status']?.toString() ?? 'active',
      bankAddress: json['bank_address']?.toString(),
      mobileNumber: json['mobile_number']?.toString(),
      email: json['email']?.toString(),
      notes: json['notes']?.toString(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'group_id': groupId,
    'bank_name': bankName,
    'branch': branch,
    'account_number': accountNumber,
    'ifsc': ifsc,
    'account_type': accountType,
    'account_holder': accountHolder,
    'opening_balance': openingBalance,
    'opening_balance_date': openingBalanceDate,
    'current_balance': currentBalance,
    'is_primary': isPrimary,
    'status': status,
    'bank_address': bankAddress,
    'mobile_number': mobileNumber,
    'email': email,
    'notes': notes,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };

  BankAccount copyWith({
    String? bankName,
    String? branch,
    String? accountNumber,
    String? ifsc,
    String? accountType,
    String? accountHolder,
    double? openingBalance,
    String? openingBalanceDate,
    double? currentBalance,
    int? isPrimary,
    String? status,
    String? bankAddress,
    String? mobileNumber,
    String? email,
    String? notes,
    String? updatedAt,
  }) {
    return BankAccount(
      id: id,
      groupId: groupId,
      bankName: bankName ?? this.bankName,
      branch: branch ?? this.branch,
      accountNumber: accountNumber ?? this.accountNumber,
      ifsc: ifsc ?? this.ifsc,
      accountType: accountType ?? this.accountType,
      accountHolder: accountHolder ?? this.accountHolder,
      openingBalance: openingBalance ?? this.openingBalance,
      openingBalanceDate: openingBalanceDate ?? this.openingBalanceDate,
      currentBalance: currentBalance ?? this.currentBalance,
      isPrimary: isPrimary ?? this.isPrimary,
      status: status ?? this.status,
      bankAddress: bankAddress ?? this.bankAddress,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      email: email ?? this.email,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
