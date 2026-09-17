class MonthlySaving {
  final String id;
  final String groupId;
  final String memberId;
  final String? memberName;
  final String? memberCode;
  final String? mobileNumber;
  final String? photoUrl;
  final String? savingPlanId;
  final int month; // 1-12
  final int year; // e.g. 2026
  final String dueDate; // YYYY-MM-DD
  final double expectedAmount;
  final double paidAmount;
  final double lateFee;
  final double balanceAmount;
  final String paymentMode; // cash, upi, bank, other
  final String? transactionId;
  final String? receiptNumber; // SAV-2026-000125
  final String? paymentDate;
  final String? collectedBy;
  final String status; // paid, partial, pending, overdue
  final String? remarks;

  MonthlySaving({
    required this.id,
    required this.groupId,
    required this.memberId,
    this.memberName,
    this.memberCode,
    this.mobileNumber,
    this.photoUrl,
    this.savingPlanId,
    required this.month,
    required this.year,
    required this.dueDate,
    this.expectedAmount = 500.0,
    this.paidAmount = 0.0,
    this.lateFee = 0.0,
    this.balanceAmount = 0.0,
    this.paymentMode = 'cash',
    this.transactionId,
    this.receiptNumber,
    this.paymentDate,
    this.collectedBy,
    this.status = 'pending',
    this.remarks,
  });

  bool get isPaid => status == 'paid' || (paidAmount >= expectedAmount && paidAmount > 0);
  bool get isPartial => !isPaid && (status == 'partial' || (paidAmount > 0 && paidAmount < expectedAmount));
  bool get isPending => !isPaid && !isPartial && (status == 'pending' || paidAmount == 0);
  bool get isOverdue => !isPaid && !isPartial && (status == 'overdue' || (isPending && _isPastDueDate));

  bool get _isPastDueDate {
    try {
      final due = DateTime.parse(dueDate);
      return DateTime.now().isAfter(due);
    } catch (_) {
      return false;
    }
  }

  static const List<String> monthNamesMr = [
    'जानेवारी', 'फेब्रुवारी', 'मार्च', 'एप्रिल', 'मे', 'जून',
    'जुलै', 'ऑगस्ट', 'सप्टेंबर', 'ऑक्टोबर', 'नोव्हेंबर', 'डिसेंबर'
  ];

  static const List<String> monthNamesEn = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  String get monthNameMr => month >= 1 && month <= 12 ? monthNamesMr[month - 1] : '$month';
  String get monthNameEn => month >= 1 && month <= 12 ? monthNamesEn[month - 1] : '$month';

  factory MonthlySaving.fromJson(Map<String, dynamic> json) {
    return MonthlySaving(
      id: json['id']?.toString() ?? '',
      groupId: json['group_id']?.toString() ?? '',
      memberId: json['member_id']?.toString() ?? '',
      memberName: json['members'] != null ? json['members']['full_name'] : json['member_name'],
      memberCode: json['members'] != null ? json['members']['member_code'] : json['member_code'],
      mobileNumber: json['members'] != null ? json['members']['mobile_number'] : json['mobile_number'],
      photoUrl: json['members'] != null ? json['members']['photo_url'] : json['photo_url'],
      savingPlanId: json['saving_plan_id']?.toString(),
      month: (json['month'] as num?)?.toInt() ?? 1,
      year: (json['year'] as num?)?.toInt() ?? DateTime.now().year,
      dueDate: json['due_date'] ?? '',
      expectedAmount: (json['expected_amount'] as num?)?.toDouble() ?? 500.0,
      paidAmount: (json['paid_amount'] as num?)?.toDouble() ?? 0.0,
      lateFee: (json['late_fee'] as num?)?.toDouble() ?? 0.0,
      balanceAmount: (json['balance_amount'] as num?)?.toDouble() ?? 0.0,
      paymentMode: json['payment_mode'] ?? 'cash',
      transactionId: json['transaction_id'],
      receiptNumber: json['receipt_number'],
      paymentDate: json['payment_date'],
      collectedBy: json['collected_by'],
      status: json['status'] ?? 'pending',
      remarks: json['remarks'],
    );
  }

  Map<String, dynamic> toJson() => {
    'group_id': groupId,
    'member_id': memberId,
    'saving_plan_id': savingPlanId,
    'month': month,
    'year': year,
    'due_date': dueDate,
    'expected_amount': expectedAmount,
    'paid_amount': paidAmount,
    'late_fee': lateFee,
    'balance_amount': balanceAmount,
    'payment_mode': paymentMode,
    'transaction_id': transactionId,
    'receipt_number': receiptNumber,
    'payment_date': paymentDate,
    'collected_by': collectedBy,
    'status': status,
    'remarks': remarks,
  };

  MonthlySaving copyWith({
    String? id,
    String? groupId,
    String? memberId,
    String? memberName,
    String? memberCode,
    String? mobileNumber,
    String? photoUrl,
    String? savingPlanId,
    int? month,
    int? year,
    String? dueDate,
    double? expectedAmount,
    double? paidAmount,
    double? lateFee,
    double? balanceAmount,
    String? paymentMode,
    String? transactionId,
    String? receiptNumber,
    String? paymentDate,
    String? collectedBy,
    String? status,
    String? remarks,
  }) {
    return MonthlySaving(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      memberId: memberId ?? this.memberId,
      memberName: memberName ?? this.memberName,
      memberCode: memberCode ?? this.memberCode,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      photoUrl: photoUrl ?? this.photoUrl,
      savingPlanId: savingPlanId ?? this.savingPlanId,
      month: month ?? this.month,
      year: year ?? this.year,
      dueDate: dueDate ?? this.dueDate,
      expectedAmount: expectedAmount ?? this.expectedAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      lateFee: lateFee ?? this.lateFee,
      balanceAmount: balanceAmount ?? this.balanceAmount,
      paymentMode: paymentMode ?? this.paymentMode,
      transactionId: transactionId ?? this.transactionId,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      paymentDate: paymentDate ?? this.paymentDate,
      collectedBy: collectedBy ?? this.collectedBy,
      status: status ?? this.status,
      remarks: remarks ?? this.remarks,
    );
  }
}
