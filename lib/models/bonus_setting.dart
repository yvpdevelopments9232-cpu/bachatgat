class BonusSetting {
  final String id;
  final String groupId;
  final String settingName;
  final String bonusType; // 'percentage_of_savings', 'percentage_of_profit', 'fixed_amount', 'attendance_based', 'custom_manual'
  final String calculationMethod; // 'percentage', 'fixed'
  final double bonusPercentage;
  final double fixedAmount;
  final double minEligibility;
  final double maxBonus;
  final String? effectiveFrom;
  final String? effectiveTo;
  final bool isActive;
  final String? createdAt;
  final String? updatedAt;

  BonusSetting({
    required this.id,
    required this.groupId,
    this.settingName = 'Savings Bonus',
    this.bonusType = 'percentage_of_savings',
    this.calculationMethod = 'percentage',
    this.bonusPercentage = 5.0,
    this.fixedAmount = 0.0,
    this.minEligibility = 0.0,
    this.maxBonus = 5000.0,
    this.effectiveFrom,
    this.effectiveTo,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  factory BonusSetting.fromJson(Map<String, dynamic> json) {
    return BonusSetting(
      id: json['id']?.toString() ?? '',
      groupId: json['group_id']?.toString() ?? '',
      settingName: json['setting_name']?.toString() ?? 'Savings Bonus',
      bonusType: json['bonus_type']?.toString() ?? 'percentage_of_savings',
      calculationMethod: json['calculation_method']?.toString() ?? 'percentage',
      bonusPercentage: (json['bonus_percentage'] as num?)?.toDouble() ?? 5.0,
      fixedAmount: (json['fixed_amount'] as num?)?.toDouble() ?? 0.0,
      minEligibility: (json['min_eligibility'] as num?)?.toDouble() ?? 0.0,
      maxBonus: (json['max_bonus'] as num?)?.toDouble() ?? 5000.0,
      effectiveFrom: json['effective_from']?.toString(),
      effectiveTo: json['effective_to']?.toString(),
      isActive: json['is_active'] == 1 || json['is_active'] == true || json['is_active'] == 'true',
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'group_id': groupId,
      'setting_name': settingName,
      'bonus_type': bonusType,
      'calculation_method': calculationMethod,
      'bonus_percentage': bonusPercentage,
      'fixed_amount': fixedAmount,
      'min_eligibility': minEligibility,
      'max_bonus': maxBonus,
      'effective_from': effectiveFrom,
      'effective_to': effectiveTo,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt ?? DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  BonusSetting copyWith({
    String? id,
    String? groupId,
    String? settingName,
    String? bonusType,
    String? calculationMethod,
    double? bonusPercentage,
    double? fixedAmount,
    double? minEligibility,
    double? maxBonus,
    String? effectiveFrom,
    String? effectiveTo,
    bool? isActive,
  }) {
    return BonusSetting(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      settingName: settingName ?? this.settingName,
      bonusType: bonusType ?? this.bonusType,
      calculationMethod: calculationMethod ?? this.calculationMethod,
      bonusPercentage: bonusPercentage ?? this.bonusPercentage,
      fixedAmount: fixedAmount ?? this.fixedAmount,
      minEligibility: minEligibility ?? this.minEligibility,
      maxBonus: maxBonus ?? this.maxBonus,
      effectiveFrom: effectiveFrom ?? this.effectiveFrom,
      effectiveTo: effectiveTo ?? this.effectiveTo,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: DateTime.now().toIso8601String(),
    );
  }
}
