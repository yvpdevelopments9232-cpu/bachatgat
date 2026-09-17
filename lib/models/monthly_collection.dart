class MonthlyCollection {
  final String id;
  final String groupId;
  final String memberId;
  final String? loanId;
  final String? bankAccountId;
  final String collectionDate; // YYYY-MM-DD
  final double monthlySaving;
  final double requiredEmi;
  final double paidEmi;
  final double principalAmount;
  final double interestAmount;
  final double remainingEmi;
  final double totalCollection;
  final String paymentStatus; // 'paid', 'partial', 'pending'
  final String paymentMode; // 'cash', 'bank', 'online'
  final String? referenceNo;
  final String? notes;
  final String? createdBy;
  final String? createdAt;
  final String? updatedAt;

  // Transient display helpers
  final String? memberName;
  final String? memberCode;
  final String? loanNumber;
  final String? bankAccountName;

  MonthlyCollection({
    required this.id,
    required this.groupId,
    required this.memberId,
    this.loanId,
    this.bankAccountId,
    required this.collectionDate,
    this.monthlySaving = 0.0,
    this.requiredEmi = 0.0,
    this.paidEmi = 0.0,
    this.principalAmount = 0.0,
    this.interestAmount = 0.0,
    this.remainingEmi = 0.0,
    this.totalCollection = 0.0,
    this.paymentStatus = 'paid',
    this.paymentMode = 'cash',
    this.referenceNo,
    this.notes,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.memberName,
    this.memberCode,
    this.loanNumber,
    this.bankAccountName,
  });

  factory MonthlyCollection.fromMap(Map<String, dynamic> map) {
    return MonthlyCollection(
      id: map['id']?.toString() ?? '',
      groupId: map['group_id']?.toString() ?? '',
      memberId: map['member_id']?.toString() ?? '',
      loanId: map['loan_id']?.toString(),
      bankAccountId: map['bank_account_id']?.toString(),
      collectionDate: map['collection_date']?.toString().split('T').first ?? '',
      monthlySaving: (map['monthly_saving'] as num?)?.toDouble() ?? 0.0,
      requiredEmi: (map['required_emi'] as num?)?.toDouble() ?? 0.0,
      paidEmi: (map['paid_emi'] as num?)?.toDouble() ?? 0.0,
      principalAmount: (map['principal_amount'] as num?)?.toDouble() ?? 0.0,
      interestAmount: (map['interest_amount'] as num?)?.toDouble() ?? 0.0,
      remainingEmi: (map['remaining_emi'] as num?)?.toDouble() ?? 0.0,
      totalCollection: (map['total_collection'] as num?)?.toDouble() ?? 0.0,
      paymentStatus: map['payment_status']?.toString() ?? 'paid',
      paymentMode: map['payment_mode']?.toString() ?? 'cash',
      referenceNo: map['reference_no']?.toString(),
      notes: map['notes']?.toString(),
      createdBy: map['created_by']?.toString(),
      createdAt: map['created_at']?.toString(),
      updatedAt: map['updated_at']?.toString(),
      memberName: map['member_name']?.toString() ?? map['members']?['full_name']?.toString(),
      memberCode: map['member_code']?.toString() ?? map['members']?['member_code']?.toString(),
      loanNumber: map['loan_number']?.toString() ?? map['loans']?['loan_code']?.toString(),
      bankAccountName: map['bank_account_name']?.toString() ?? map['bank_accounts']?['bank_name']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'group_id': groupId,
      'member_id': memberId,
      'loan_id': loanId,
      'bank_account_id': bankAccountId,
      'collection_date': collectionDate,
      'monthly_saving': monthlySaving,
      'required_emi': requiredEmi,
      'paid_emi': paidEmi,
      'principal_amount': principalAmount,
      'interest_amount': interestAmount,
      'remaining_emi': remainingEmi,
      'total_collection': totalCollection,
      'payment_status': paymentStatus,
      'payment_mode': paymentMode,
      'reference_no': referenceNo,
      'notes': notes,
      'created_by': createdBy,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  MonthlyCollection copyWith({
    String? id,
    String? groupId,
    String? memberId,
    String? loanId,
    String? bankAccountId,
    String? collectionDate,
    double? monthlySaving,
    double? requiredEmi,
    double? paidEmi,
    double? principalAmount,
    double? interestAmount,
    double? remainingEmi,
    double? totalCollection,
    String? paymentStatus,
    String? paymentMode,
    String? referenceNo,
    String? notes,
    String? createdBy,
    String? createdAt,
    String? updatedAt,
    String? memberName,
    String? memberCode,
    String? loanNumber,
    String? bankAccountName,
  }) {
    return MonthlyCollection(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      memberId: memberId ?? this.memberId,
      loanId: loanId ?? this.loanId,
      bankAccountId: bankAccountId ?? this.bankAccountId,
      collectionDate: collectionDate ?? this.collectionDate,
      monthlySaving: monthlySaving ?? this.monthlySaving,
      requiredEmi: requiredEmi ?? this.requiredEmi,
      paidEmi: paidEmi ?? this.paidEmi,
      principalAmount: principalAmount ?? this.principalAmount,
      interestAmount: interestAmount ?? this.interestAmount,
      remainingEmi: remainingEmi ?? this.remainingEmi,
      totalCollection: totalCollection ?? this.totalCollection,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentMode: paymentMode ?? this.paymentMode,
      referenceNo: referenceNo ?? this.referenceNo,
      notes: notes ?? this.notes,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      memberName: memberName ?? this.memberName,
      memberCode: memberCode ?? this.memberCode,
      loanNumber: loanNumber ?? this.loanNumber,
      bankAccountName: bankAccountName ?? this.bankAccountName,
    );
  }
}
