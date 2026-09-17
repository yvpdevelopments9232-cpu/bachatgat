class SavingPlan {
  final String id;
  final String groupId;
  final String planName;
  final double monthlyAmount;
  final String? effectiveFrom;
  final String? effectiveTo;
  final int dueDay; // e.g. 10 (10th of every month)
  final int gracePeriodDays; // e.g. 5 days
  final double lateFee; // e.g. 20
  final String status; // active, inactive

  SavingPlan({
    required this.id,
    required this.groupId,
    required this.planName,
    required this.monthlyAmount,
    this.effectiveFrom,
    this.effectiveTo,
    this.dueDay = 10,
    this.gracePeriodDays = 5,
    this.lateFee = 20.0,
    this.status = 'active',
  });

  factory SavingPlan.fromJson(Map<String, dynamic> json) {
    return SavingPlan(
      id: json['id']?.toString() ?? '',
      groupId: json['group_id']?.toString() ?? '',
      planName: json['plan_name'] ?? 'Regular Monthly Saving',
      monthlyAmount: (json['monthly_amount'] as num?)?.toDouble() ?? 500.0,
      effectiveFrom: json['effective_from'],
      effectiveTo: json['effective_to'],
      dueDay: (json['due_day'] as num?)?.toInt() ?? 10,
      gracePeriodDays: (json['grace_period_days'] as num?)?.toInt() ?? 5,
      lateFee: (json['late_fee'] as num?)?.toDouble() ?? 20.0,
      status: json['status'] ?? 'active',
    );
  }

  Map<String, dynamic> toJson() => {
    'group_id': groupId,
    'plan_name': planName,
    'monthly_amount': monthlyAmount,
    'effective_from': effectiveFrom,
    'effective_to': effectiveTo,
    'due_day': dueDay,
    'grace_period_days': gracePeriodDays,
    'late_fee': lateFee,
    'status': status,
  };

  SavingPlan copyWith({
    String? planName,
    double? monthlyAmount,
    int? dueDay,
    int? gracePeriodDays,
    double? lateFee,
    String? status,
  }) {
    return SavingPlan(
      id: id,
      groupId: groupId,
      planName: planName ?? this.planName,
      monthlyAmount: monthlyAmount ?? this.monthlyAmount,
      effectiveFrom: effectiveFrom,
      effectiveTo: effectiveTo,
      dueDay: dueDay ?? this.dueDay,
      gracePeriodDays: gracePeriodDays ?? this.gracePeriodDays,
      lateFee: lateFee ?? this.lateFee,
      status: status ?? this.status,
    );
  }
}
