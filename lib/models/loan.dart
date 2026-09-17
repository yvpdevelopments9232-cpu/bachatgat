import 'dart:math' as math;

class Loan {
  final String id;
  final String groupId;
  final String memberId;
  final String? memberName;
  final String loanCode; // L001
  final String applicationDate;
  final String loanType;
  final String interestType; // 'fixed' / 'flat' or 'decreasing' / 'reducing'
  final double requestedAmount;
  final double approvedAmount;
  final String? purpose;
  final double interestRate;
  final int loanPeriodMonths;
  final double emiAmount;
  final int numberOfEmis;
  final String firstEmiDate;
  final double outstandingPrincipal;
  final double totalRepaid;
  final String status;

  Loan({
    required this.id,
    required this.groupId,
    required this.memberId,
    this.memberName,
    required this.loanCode,
    required this.applicationDate,
    this.loanType = 'personal',
    this.interestType = 'fixed',
    required this.requestedAmount,
    required this.approvedAmount,
    this.purpose,
    required this.interestRate,
    required this.loanPeriodMonths,
    required this.emiAmount,
    required this.numberOfEmis,
    required this.firstEmiDate,
    this.outstandingPrincipal = 0.0,
    this.totalRepaid = 0.0,
    this.status = 'disbursed',
  });

  Loan copyWith({
    String? id,
    String? groupId,
    String? memberId,
    String? memberName,
    String? loanCode,
    String? applicationDate,
    String? loanType,
    String? interestType,
    double? requestedAmount,
    double? approvedAmount,
    String? purpose,
    double? interestRate,
    int? loanPeriodMonths,
    double? emiAmount,
    int? numberOfEmis,
    String? firstEmiDate,
    double? outstandingPrincipal,
    double? totalRepaid,
    String? status,
  }) {
    return Loan(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      memberId: memberId ?? this.memberId,
      memberName: memberName ?? this.memberName,
      loanCode: loanCode ?? this.loanCode,
      applicationDate: applicationDate ?? this.applicationDate,
      loanType: loanType ?? this.loanType,
      interestType: interestType ?? this.interestType,
      requestedAmount: requestedAmount ?? this.requestedAmount,
      approvedAmount: approvedAmount ?? this.approvedAmount,
      purpose: purpose ?? this.purpose,
      interestRate: interestRate ?? this.interestRate,
      loanPeriodMonths: loanPeriodMonths ?? this.loanPeriodMonths,
      emiAmount: emiAmount ?? this.emiAmount,
      numberOfEmis: numberOfEmis ?? this.numberOfEmis,
      firstEmiDate: firstEmiDate ?? this.firstEmiDate,
      outstandingPrincipal: outstandingPrincipal ?? this.outstandingPrincipal,
      totalRepaid: totalRepaid ?? this.totalRepaid,
      status: status ?? this.status,
    );
  }

  bool get isActive => status == 'active' || status == 'disbursed' || status == 'approved';
  bool get isClosed => status == 'closed' || status == 'completed';
  bool get isOverdue => status == 'overdue' || status == 'defaulted';

  bool get isFixedEmi {
    final t = interestType.toLowerCase().trim();
    return t == 'fixed' || t == 'flat' || t.isEmpty;
  }

  bool get isDecreasingEmi {
    final t = interestType.toLowerCase().trim();
    return t == 'decreasing' || t == 'reducing';
  }
  String get emiTypeDisplay => isDecreasingEmi ? 'घटता हप्ता (Decreasing EMI)' : 'स्थिर हप्ता (Fixed EMI)';

  String get calculatedEndDate {
    try {
      final start = DateTime.tryParse(firstEmiDate) ?? DateTime.tryParse(applicationDate);
      if (start != null && loanPeriodMonths > 0) {
        final targetMonth = start.month + loanPeriodMonths - 1;
        final maxDays = DateTime(start.year, targetMonth + 1, 0).day;
        final d = start.day > maxDays ? maxDays : start.day;
        final end = DateTime(start.year, targetMonth, d);
        return "${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}";
      }
    } catch (_) {}
    return '';
  }

  factory Loan.fromJson(Map<String, dynamic> json) {
    return Loan(
      id: json['id'],
      groupId: json['group_id'] ?? '',
      memberId: json['member_id'] ?? '',
      memberName: json['members'] != null ? json['members']['full_name'] : null,
      loanCode: json['loan_code'] ?? '',
      applicationDate: json['application_date'] ?? '',
      loanType: json['loan_type'] ?? 'personal',
      interestType: json['interest_type'] ?? 'fixed',
      requestedAmount: (json['requested_amount'] as num?)?.toDouble() ?? 0.0,
      approvedAmount: (json['approved_amount'] as num?)?.toDouble() ?? 0.0,
      purpose: json['purpose'],
      interestRate: (json['interest_rate'] as num?)?.toDouble() ?? 12.0,
      loanPeriodMonths: (json['loan_period_months'] as num?)?.toInt() ?? 12,
      emiAmount: (json['emi_amount'] as num?)?.toDouble() ?? 0.0,
      numberOfEmis: (json['number_of_emis'] as num?)?.toInt() ?? 12,
      firstEmiDate: json['first_emi_date'] ?? '',
      outstandingPrincipal: (json['outstanding_principal'] as num?)?.toDouble() ?? 0.0,
      totalRepaid: (json['total_repaid'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] ?? 'disbursed',
    );
  }

  Map<String, dynamic> toJson() => {
    'group_id': groupId,
    'member_id': memberId,
    'loan_code': loanCode,
    'application_date': applicationDate,
    'loan_type': loanType,
    'interest_type': interestType,
    'requested_amount': requestedAmount,
    'approved_amount': approvedAmount,
    'purpose': purpose,
    'interest_rate': interestRate,
    'loan_period_months': loanPeriodMonths,
    'emi_amount': emiAmount,
    'number_of_emis': numberOfEmis,
    'first_emi_date': firstEmiDate,
    'outstanding_principal': outstandingPrincipal,
    'total_repaid': totalRepaid,
    'status': status,
  };
}

/// Calculates the standard fixed reducing balance EMI:
/// EMI = [P * r * (1+r)^N] / [(1+r)^N - 1]
double calculateFixedEmi({
  required double principal,
  required double annualRate,
  required int months,
}) {
  if (principal <= 0 || months <= 0) return 0.0;
  if (annualRate <= 0) return double.parse((principal / months).toStringAsFixed(2));

  final monthlyRate = (annualRate / 100.0) / 12.0;
  final factor = math.pow(1.0 + monthlyRate, months).toDouble();
  final emi = (principal * monthlyRate * factor) / (factor - 1.0);
  return double.parse(emi.toStringAsFixed(2));
}

/// Calculates installment details for Decreasing EMI:
/// Principal repayment is constant (P / N).
/// Interest decreases as outstanding principal decreases.
/// Month m interest = (P - (m-1)*(P/N)) * (annualRate/100)/12.
double calculateDecreasingEmi({
  required double principal,
  required double annualRate,
  required int months,
  int monthIndex = 1,
}) {
  if (principal <= 0 || months <= 0) return 0.0;
  final monthlyPrincipal = principal / months;
  final paidPrincipalBefore = (monthIndex - 1) * monthlyPrincipal;
  final remainingPrincipal = math.max(0.0, principal - paidPrincipalBefore);
  final monthlyRate = (annualRate / 100.0) / 12.0;
  final monthInterest = remainingPrincipal * monthlyRate;
  final totalEmi = monthlyPrincipal + monthInterest;
  return double.parse(totalEmi.toStringAsFixed(2));
}

/// Calculates total interest paid across all months in a Decreasing EMI schedule
double calculateTotalDecreasingInterest({
  required double principal,
  required double annualRate,
  required int months,
}) {
  if (principal <= 0 || months <= 0) return 0.0;
  final monthlyPrincipal = principal / months;
  final monthlyRate = (annualRate / 100.0) / 12.0;
  double totalInterest = 0.0;
  for (int m = 1; m <= months; m++) {
    final paidPrincipalBefore = (m - 1) * monthlyPrincipal;
    final remainingPrincipal = math.max(0.0, principal - paidPrincipalBefore);
    totalInterest += remainingPrincipal * monthlyRate;
  }
  return double.parse(totalInterest.toStringAsFixed(2));
}

class LoanEmi {
  final String id;
  final String loanId;
  final int emiNumber;
  final String dueDate;
  final double principal;
  final double interest;
  final double emiAmount;
  final double lateFee;
  final double paidAmount;
  final String? paymentDate;
  final String? paymentMode;
  final String? transactionId;
  final String? receiptNumber;
  final double balance;
  final String status;
  final String? remarks;

  LoanEmi({
    required this.id,
    required this.loanId,
    required this.emiNumber,
    required this.dueDate,
    required this.principal,
    required this.interest,
    required this.emiAmount,
    this.lateFee = 0.0,
    this.paidAmount = 0.0,
    this.paymentDate,
    this.paymentMode,
    this.transactionId,
    this.receiptNumber,
    this.balance = 0.0,
    this.status = 'pending',
    this.remarks,
  });

  factory LoanEmi.fromJson(Map<String, dynamic> json) {
    return LoanEmi(
      id: json['id'],
      loanId: json['loan_id'],
      emiNumber: json['emi_number'] ?? 1,
      dueDate: json['due_date'] ?? '',
      principal: (json['principal'] as num?)?.toDouble() ?? 0.0,
      interest: (json['interest'] as num?)?.toDouble() ?? 0.0,
      emiAmount: (json['emi_amount'] as num?)?.toDouble() ?? 0.0,
      lateFee: (json['late_fee'] as num?)?.toDouble() ?? 0.0,
      paidAmount: (json['paid_amount'] as num?)?.toDouble() ?? 0.0,
      paymentDate: json['payment_date'],
      paymentMode: json['payment_mode'],
      transactionId: json['transaction_id'],
      receiptNumber: json['receipt_number'],
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] ?? 'pending',
      remarks: json['remarks'],
    );
  }
}

class LoanSettings {
  final double interestRate; // e.g. 24.0% per annum (2.0% per month)
  final int overdueDays; // Grace period / threshold days (e.g. 0, 5, 10 days)
  final double lateFeePercentage; // e.g. 18.0% annual penalty rate
  final String interestType; // 'yearly' or 'monthly'

  const LoanSettings({
    this.interestRate = 24.0,
    this.overdueDays = 0,
    this.lateFeePercentage = 18.0,
    this.interestType = 'yearly',
  });

  factory LoanSettings.fromJson(Map<String, dynamic> json) {
    final rawDays = (json['overdue_days'] as num?)?.toInt() ?? 0;
    // If overdue_days >= 28, it was entered thinking of monthly cycle, not grace period! Treat as 0 grace days.
    final effectiveOverdueDays = rawDays >= 28 ? 0 : rawDays;
    return LoanSettings(
      interestRate: (json['interest_rate'] as num?)?.toDouble() ?? 24.0,
      overdueDays: effectiveOverdueDays,
      lateFeePercentage: (json['late_fee_percentage'] as num?)?.toDouble() ?? 18.0,
      interestType: json['interest_type']?.toString() ?? 'yearly',
    );
  }

  Map<String, dynamic> toJson() => {
    'interest_rate': interestRate,
    'overdue_days': overdueDays,
    'late_fee_percentage': lateFeePercentage,
    'interest_type': interestType,
  };

  /// Calculates late fee based on the formula:
  /// Late Fee = (pending_principal * rate / 100) * (overdue_days / 365)
  /// Fallback: if fee is 0, late_fee = overdue_days * rate (e.g. ₹5 per day)
  double calculateLateFee({
    required double pendingPrincipal,
    required int actualLateDays,
  }) {
    final grace = overdueDays >= 28 ? 0 : overdueDays;
    if (actualLateDays <= grace || pendingPrincipal <= 0) {
      return 0.0;
    }
    double fee = 0.0;
    if (lateFeePercentage > 0) {
      fee = (pendingPrincipal * (lateFeePercentage / 100.0)) * (actualLateDays / 365.0);
    }
    if (fee <= 0 && lateFeePercentage > 0) {
      fee = actualLateDays * lateFeePercentage;
    }
    return fee > 0 ? double.parse(fee.toStringAsFixed(2)) : 0.0;
  }
}

/// Comprehensive model for real-time overdue loan calculation.
/// Separates past-due missed EMIs (e.g. 2 months = ₹3,000) from total remaining principal (₹18,333).
class LoanOverdueInfo {
  final Loan loan;
  final int overdueMonths; // Number of unpaid EMIs whose due dates have passed
  final int overdueDays; // Days elapsed since the oldest unpaid due date
  final double overdueAmount; // Sum of unpaid past-due EMIs (NOT full principal!)
  final double emiAmount; // Monthly scheduled EMI
  final double totalOutstanding; // Total remaining principal across full tenure
  final DateTime? oldestUnpaidDueDate;
  final DateTime? nextDueDate;
  final int totalPaidEmis;
  final int totalEmis;

  const LoanOverdueInfo({
    required this.loan,
    required this.overdueMonths,
    required this.overdueDays,
    required this.overdueAmount,
    required this.emiAmount,
    required this.totalOutstanding,
    this.oldestUnpaidDueDate,
    this.nextDueDate,
    required this.totalPaidEmis,
    required this.totalEmis,
  });

  bool get isOverdue => overdueMonths > 0 && overdueAmount > 0;
}

/// Calculates overdue status for a loan dynamically based on scheduled due dates and payment records.
LoanOverdueInfo calculateLoanOverdue(Loan loan, List<LoanEmi> groupEmis, [DateTime? asOfDate]) {
  final today = asOfDate ?? DateTime.now();
  final todayOnly = DateTime(today.year, today.month, today.day);

  // 1. Gather all recorded payments/EMIs for this loan
  final loanEmis = groupEmis.where((e) => e.loanId == loan.id).toList();

  // EMIs that are marked fully paid
  final paidEmiNumbers = loanEmis
      .where((e) => e.status == 'paid' || (e.paidAmount >= e.emiAmount && e.emiAmount > 0))
      .map((e) => e.emiNumber)
      .toSet();

  // Map of partial payments per EMI number
  final Map<int, double> partialPaidMap = {};
  for (var e in loanEmis) {
    partialPaidMap[e.emiNumber] = (partialPaidMap[e.emiNumber] ?? 0.0) + e.paidAmount;
  }

  // 2. Start date of the loan / first EMI
  final start = DateTime.tryParse(loan.firstEmiDate) ??
      DateTime.tryParse(loan.applicationDate) ??
      todayOnly;

  final totalMonths = loan.loanPeriodMonths > 0
      ? loan.loanPeriodMonths
      : (loanEmis.isNotEmpty ? loanEmis.length : 12);

  // Default Monthly EMI amount (Principal + Interest)
  double monthlyEmi = loan.emiAmount;
  if (monthlyEmi <= 0) {
    final monthlyPrincipal = loan.approvedAmount / totalMonths;
    final monthlyInterest = (loan.approvedAmount * (loan.interestRate / 100.0)) / 12.0;
    monthlyEmi = monthlyPrincipal + monthlyInterest;
  }

  int overdueMonths = 0;
  double overdueAmount = 0.0;
  DateTime? oldestUnpaidDueDate;
  DateTime? nextDueDate;
  int maxLateDays = 0;

  for (int i = 1; i <= totalMonths; i++) {
    // If loanEmis has a record for this EMI number, use its date and amount
    final existingEmi = loanEmis.where((e) => e.emiNumber == i).firstOrNull;
    DateTime emiDueDateOnly;
    if (existingEmi != null && existingEmi.dueDate.isNotEmpty && DateTime.tryParse(existingEmi.dueDate) != null) {
      final parsed = DateTime.parse(existingEmi.dueDate);
      emiDueDateOnly = DateTime(parsed.year, parsed.month, parsed.day);
    } else {
      final tMonth = start.month + (i - 1);
      final maxDays = DateTime(start.year, tMonth + 1, 0).day;
      final day = start.day > maxDays ? maxDays : start.day;
      final emiDueDate = DateTime(start.year, tMonth, day);
      emiDueDateOnly = DateTime(emiDueDate.year, emiDueDate.month, emiDueDate.day);
    }

    final double expectedEmiAmt = (existingEmi != null && existingEmi.emiAmount > 0)
        ? existingEmi.emiAmount
        : (loan.isDecreasingEmi
            ? calculateDecreasingEmi(
                principal: loan.approvedAmount,
                annualRate: loan.interestRate,
                months: totalMonths,
                monthIndex: i,
              )
            : monthlyEmi);

    final isPaid = paidEmiNumbers.contains(i);
    final paidAmt = partialPaidMap[i] ?? (existingEmi?.paidAmount ?? 0.0);

    if (isPaid) {
      continue; // This EMI was paid
    }

    // Check if this unpaid EMI is due on or before today
    if (emiDueDateOnly.isBefore(todayOnly) || emiDueDateOnly.isAtSameMomentAs(todayOnly)) {
      overdueMonths++;
      final emiDueRemaining = expectedEmiAmt - paidAmt;
      if (emiDueRemaining > 0) {
        overdueAmount += emiDueRemaining;
      }
      oldestUnpaidDueDate ??= emiDueDateOnly;
      final lateDays = todayOnly.difference(emiDueDateOnly).inDays;
      if (lateDays > maxLateDays) {
        maxLateDays = lateDays;
      }
    } else {
      // Future EMI: records the earliest upcoming due date
      nextDueDate ??= emiDueDateOnly;
    }
  }

  return LoanOverdueInfo(
    loan: loan,
    overdueMonths: overdueMonths,
    overdueDays: maxLateDays,
    overdueAmount: overdueAmount > 0 ? double.parse(overdueAmount.toStringAsFixed(2)) : 0.0,
    emiAmount: monthlyEmi,
    totalOutstanding: loan.outstandingPrincipal > 0 ? loan.outstandingPrincipal : loan.approvedAmount,
    oldestUnpaidDueDate: oldestUnpaidDueDate,
    nextDueDate: nextDueDate,
    totalPaidEmis: paidEmiNumbers.length,
    totalEmis: totalMonths,
  );
}
