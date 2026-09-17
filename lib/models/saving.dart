class Saving {
  final String id;
  final String groupId;
  final String memberId;
  final String? memberName;
  final String savingsDate;
  final String savingsType;
  final double amount;
  final String paymentMode;
  final String? receiptNumber;
  final String? remarks;

  Saving({
    required this.id,
    required this.groupId,
    required this.memberId,
    this.memberName,
    required this.savingsDate,
    this.savingsType = 'monthly',
    required this.amount,
    this.paymentMode = 'cash',
    this.receiptNumber,
    this.remarks,
  });

  factory Saving.fromJson(Map<String, dynamic> json) {
    return Saving(
      id: json['id'],
      groupId: json['group_id'] ?? '',
      memberId: json['member_id'] ?? '',
      memberName: json['members'] != null ? json['members']['full_name'] : json['member_name'],
      savingsDate: json['savings_date'] ?? '',
      savingsType: json['savings_type'] ?? 'monthly',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      paymentMode: json['payment_mode'] ?? 'cash',
      receiptNumber: json['receipt_number'],
      remarks: json['remarks'],
    );
  }

  Map<String, dynamic> toJson() => {
    'group_id': groupId,
    'member_id': memberId,
    'savings_date': savingsDate,
    'savings_type': savingsType,
    'amount': amount,
    'payment_mode': paymentMode,
    'receipt_number': receiptNumber,
    'remarks': remarks,
  };
}
