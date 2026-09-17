import 'package:flutter/material.dart';

class ReportColumn {
  final String key;
  final String labelMr;
  final String labelEn;
  final bool isNumeric;
  final bool isCurrency;
  final double flex;

  const ReportColumn({
    required this.key,
    required this.labelMr,
    required this.labelEn,
    this.isNumeric = false,
    this.isCurrency = false,
    this.flex = 1.0,
  });
}

enum ReportCategory {
  members,
  savings,
  loans,
  financial,
  bankCash,
  business,
  meetings,
  governance,
  management,
}

extension ReportCategoryExtension on ReportCategory {
  String get titleMr {
    switch (this) {
      case ReportCategory.members:
        return 'सदस्य अहवाल (Members)';
      case ReportCategory.savings:
        return 'बचत अहवाल (Savings)';
      case ReportCategory.loans:
        return 'कर्ज अहवाल (Loans)';
      case ReportCategory.financial:
        return 'आर्थिक अहवाल (Financial)';
      case ReportCategory.bankCash:
        return 'बँक व रोख अहवाल (Bank & Cash)';
      case ReportCategory.business:
        return 'व्यवसाय व विक्री (Business)';
      case ReportCategory.meetings:
        return 'बैठका अहवाल (Meetings)';
      case ReportCategory.governance:
        return 'प्रशासन व योजना (Governance)';
      case ReportCategory.management:
        return 'वार्षिक व व्यवस्थापन (Management)';
    }
  }

  IconData get icon {
    switch (this) {
      case ReportCategory.members:
        return Icons.people_alt_rounded;
      case ReportCategory.savings:
        return Icons.savings_rounded;
      case ReportCategory.loans:
        return Icons.monetization_on_rounded;
      case ReportCategory.financial:
        return Icons.trending_up_rounded;
      case ReportCategory.bankCash:
        return Icons.account_balance_wallet_rounded;
      case ReportCategory.business:
        return Icons.storefront_rounded;
      case ReportCategory.meetings:
        return Icons.groups_rounded;
      case ReportCategory.governance:
        return Icons.gavel_rounded;
      case ReportCategory.management:
        return Icons.assignment_rounded;
    }
  }
}

class ReportDefinition {
  final String id;
  final String titleMr;
  final String titleEn;
  final String subtitle;
  final ReportCategory category;
  final IconData icon;
  final String supabaseTable;
  final String dateField;
  final List<ReportColumn> columns;
  final bool isLandscape;
  final List<String>? secondaryFilters;

  const ReportDefinition({
    required this.id,
    required this.titleMr,
    required this.titleEn,
    required this.subtitle,
    required this.category,
    required this.icon,
    required this.supabaseTable,
    required this.dateField,
    required this.columns,
    this.isLandscape = false,
    this.secondaryFilters,
  });
}
