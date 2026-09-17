class BankTransaction {
  final String id;
  final String groupId;
  final String bankAccountId;
  final String? bankName;
  final String transactionDate;
  final String type; // 'deposit' or 'withdrawal'
  final double amount;
  final String? depositSlipOrChequeNo;
  final String? transactionNumber;
  final String? purpose;
  final String? performedBy;
  final String? approvedBy;
  final double balanceAfter;
  final String? remarks;
  final String? createdBy;
  final String? createdAt;

  BankTransaction({
    required this.id,
    required this.groupId,
    required this.bankAccountId,
    this.bankName,
    required this.transactionDate,
    required this.type,
    required this.amount,
    this.depositSlipOrChequeNo,
    this.transactionNumber,
    this.purpose,
    this.performedBy,
    this.approvedBy,
    this.balanceAfter = 0.0,
    this.remarks,
    this.createdBy,
    this.createdAt,
  });

  bool get isDeposit =>
      type.toLowerCase() == 'deposit' ||
      type.toLowerCase() == 'credit' ||
      type.contains('जमा');

  factory BankTransaction.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0.0;
    }

    return BankTransaction(
      id: json['id']?.toString() ?? '',
      groupId: json['group_id']?.toString() ?? '',
      bankAccountId: json['bank_account_id']?.toString() ?? '',
      bankName: json['bank_name']?.toString() ??
          (json['bank_accounts'] != null ? json['bank_accounts']['bank_name']?.toString() : null),
      transactionDate: json['transaction_date']?.toString() ?? '',
      type: json['type']?.toString() ?? 'deposit',
      amount: parseDouble(json['amount']),
      depositSlipOrChequeNo: json['deposit_slip_or_cheque_no']?.toString(),
      transactionNumber: json['transaction_number']?.toString(),
      purpose: json['purpose']?.toString(),
      performedBy: json['performed_by']?.toString(),
      approvedBy: json['approved_by']?.toString(),
      balanceAfter: parseDouble(json['balance_after']),
      remarks: json['remarks']?.toString(),
      createdBy: json['created_by']?.toString(),
      createdAt: json['created_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'group_id': groupId,
    'bank_account_id': bankAccountId,
    'transaction_date': transactionDate,
    'type': type,
    'amount': amount,
    'deposit_slip_or_cheque_no': depositSlipOrChequeNo,
    'transaction_number': transactionNumber,
    'purpose': purpose,
    'performed_by': performedBy,
    'approved_by': approvedBy,
    'balance_after': balanceAfter,
    'remarks': remarks,
    'created_by': createdBy,
    'created_at': createdAt,
  };
}
