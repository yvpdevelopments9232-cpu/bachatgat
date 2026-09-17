import 'package:flutter/material.dart';

class Bonus {
  final String id;
  final String groupId;
  final String memberId;
  final String? memberName;
  final String financialYear;
  final String fromDate;
  final String toDate;
  final String bonusType; // 'savings', 'profit', 'attendance', 'fixed', 'custom'
  final double basisAmount; // Auto-fetched from Savings database!
  final double bonusRate; // Percentage or multiplier
  final double bonusAmount; // Calculated: basisAmount * bonusRate / 100
  final double paidAmount;
  final String status; // 'draft', 'calculated', 'approved', 'paid', 'cancelled'
  final String? approvedBy;
  final String? approvedAt;
  final String? paymentDate;
  final String? paymentMode; // 'cash', 'bank', 'upi'
  final String? bankAccountId;
  final String? transactionRef;
  final String? remarks;
  final String? createdAt;
  final String? updatedAt;

  Bonus({
    required this.id,
    required this.groupId,
    required this.memberId,
    this.memberName,
    this.financialYear = '2025 - 2026',
    required this.fromDate,
    required this.toDate,
    this.bonusType = 'savings',
    required this.basisAmount,
    this.bonusRate = 5.0,
    required this.bonusAmount,
    this.paidAmount = 0.0,
    this.status = 'draft',
    this.approvedBy,
    this.approvedAt,
    this.paymentDate,
    this.paymentMode,
    this.bankAccountId,
    this.transactionRef,
    this.remarks,
    this.createdAt,
    this.updatedAt,
  });

  bool get isDraft => status.toLowerCase() == 'draft';
  bool get isCalculated => status.toLowerCase() == 'calculated';
  bool get isApproved => status.toLowerCase() == 'approved';
  bool get isPaid => status.toLowerCase() == 'paid';
  bool get isCancelled => status.toLowerCase() == 'cancelled';
  bool get isPending => !isPaid && !isCancelled;

  double get balanceAmount => (bonusAmount - paidAmount) > 0 ? (bonusAmount - paidAmount) : 0.0;

  String get statusLabelMr {
    switch (status.toLowerCase()) {
      case 'paid':
        return 'भरले (Paid)';
      case 'approved':
        return 'मंजूर (Approved)';
      case 'calculated':
        return 'गणना केली (Calculated)';
      case 'pending':
        return 'प्रलंबित (Pending)';
      case 'cancelled':
        return 'रद्द (Cancelled)';
      case 'draft':
      default:
        return 'मसुदा (Draft)';
    }
  }

  String get statusLabelEn {
    switch (status.toLowerCase()) {
      case 'paid':
        return 'Paid';
      case 'approved':
        return 'Approved';
      case 'calculated':
        return 'Calculated';
      case 'pending':
        return 'Pending';
      case 'cancelled':
        return 'Cancelled';
      case 'draft':
      default:
        return 'Draft';
    }
  }

  Color get statusColor {
    switch (status.toLowerCase()) {
      case 'paid':
        return const Color(0xFF10B981); // Emerald Green
      case 'approved':
        return const Color(0xFF8B5CF6); // Purple
      case 'calculated':
        return const Color(0xFF3B82F6); // Blue
      case 'pending':
        return const Color(0xFFF59E0B); // Amber/Orange
      case 'cancelled':
        return const Color(0xFFEF4444); // Red
      case 'draft':
      default:
        return const Color(0xFF6B7280); // Gray
    }
  }

  Color get statusBgColor => statusColor.withOpacity(0.12);

  String get bonusTypeLabelMr {
    switch (bonusType.toLowerCase()) {
      case 'savings':
      case 'percentage_of_savings':
        return 'बचत टक्केवारी (Savings)';
      case 'profit':
      case 'percentage_of_profit':
        return 'नफा टक्केवारी (Profit)';
      case 'attendance':
      case 'attendance_based':
        return 'हजेरी आधारित (Attendance)';
      case 'fixed':
      case 'fixed_amount':
        return 'निश्चित रक्कम (Fixed)';
      case 'custom':
      case 'custom_manual':
      default:
        return 'इतर / सानुकूल (Custom)';
    }
  }

  factory Bonus.fromJson(Map<String, dynamic> json) {
    String? resolvedName = json['member_name']?.toString();
    if (resolvedName == null && json['members'] != null) {
      resolvedName = json['members']['full_name']?.toString();
    }

    return Bonus(
      id: json['id']?.toString() ?? '',
      groupId: json['group_id']?.toString() ?? '',
      memberId: json['member_id']?.toString() ?? '',
      memberName: resolvedName,
      financialYear: json['financial_year']?.toString() ?? '2025 - 2026',
      fromDate: json['from_date']?.toString() ?? '',
      toDate: json['to_date']?.toString() ?? '',
      bonusType: json['bonus_type']?.toString() ?? 'savings',
      basisAmount: (json['basis_amount'] as num?)?.toDouble() ?? 0.0,
      bonusRate: (json['bonus_rate'] as num?)?.toDouble() ?? 0.0,
      bonusAmount: (json['bonus_amount'] as num?)?.toDouble() ?? 0.0,
      paidAmount: (json['paid_amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status']?.toString() ?? 'draft',
      approvedBy: json['approved_by']?.toString(),
      approvedAt: json['approved_at']?.toString(),
      paymentDate: json['payment_date']?.toString(),
      paymentMode: json['payment_mode']?.toString(),
      bankAccountId: json['bank_account_id']?.toString(),
      transactionRef: json['transaction_ref']?.toString(),
      remarks: json['remarks']?.toString(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'group_id': groupId,
      'member_id': memberId,
      'financial_year': financialYear,
      'from_date': fromDate,
      'to_date': toDate,
      'bonus_type': bonusType,
      'basis_amount': basisAmount,
      'bonus_rate': bonusRate,
      'bonus_amount': bonusAmount,
      'paid_amount': paidAmount,
      'status': status,
      'approved_by': approvedBy,
      'approved_at': approvedAt,
      'payment_date': paymentDate,
      'payment_mode': paymentMode,
      'bank_account_id': bankAccountId,
      'transaction_ref': transactionRef,
      'remarks': remarks,
      'created_at': createdAt ?? DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  Bonus copyWith({
    String? id,
    String? groupId,
    String? memberId,
    String? memberName,
    String? financialYear,
    String? fromDate,
    String? toDate,
    String? bonusType,
    double? basisAmount,
    double? bonusRate,
    double? bonusAmount,
    double? paidAmount,
    String? status,
    String? approvedBy,
    String? approvedAt,
    String? paymentDate,
    String? paymentMode,
    String? bankAccountId,
    String? transactionRef,
    String? remarks,
  }) {
    return Bonus(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      memberId: memberId ?? this.memberId,
      memberName: memberName ?? this.memberName,
      financialYear: financialYear ?? this.financialYear,
      fromDate: fromDate ?? this.fromDate,
      toDate: toDate ?? this.toDate,
      bonusType: bonusType ?? this.bonusType,
      basisAmount: basisAmount ?? this.basisAmount,
      bonusRate: bonusRate ?? this.bonusRate,
      bonusAmount: bonusAmount ?? this.bonusAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      status: status ?? this.status,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      paymentDate: paymentDate ?? this.paymentDate,
      paymentMode: paymentMode ?? this.paymentMode,
      bankAccountId: bankAccountId ?? this.bankAccountId,
      transactionRef: transactionRef ?? this.transactionRef,
      remarks: remarks ?? this.remarks,
      createdAt: createdAt,
      updatedAt: DateTime.now().toIso8601String(),
    );
  }
}
