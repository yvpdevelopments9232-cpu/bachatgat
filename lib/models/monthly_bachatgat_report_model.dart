import 'bachat_group.dart';

class MonthlyBachatgatReportRow {
  final int srNo;
  final String memberId;
  final String memberName;
  final String? memberCode;
  final double openingLoan; // कर्ज आजअखेर
  final double newLoan; // दिलेले कर्ज (0 if none)
  final double monthlySaving; // महिना बचत
  final double cumulativeSavings; // एकूण बचत आजअखेर
  final double installment; // हप्ता
  final double interest; // व्याज
  final double todayTotal; // आजची एकूण = महिना बचत + हप्ता + व्याज
  final double closingLoan; // या महिन्यात अखेर शिल्लक कर्ज = कर्ज आजअखेर + दिलेले कर्ज - हप्ता

  const MonthlyBachatgatReportRow({
    required this.srNo,
    required this.memberId,
    required this.memberName,
    this.memberCode,
    required this.openingLoan,
    required this.newLoan,
    required this.monthlySaving,
    required this.cumulativeSavings,
    required this.installment,
    required this.interest,
    required this.todayTotal,
    required this.closingLoan,
  });

  MonthlyBachatgatReportRow copyWith({
    int? srNo,
    String? memberId,
    String? memberName,
    String? memberCode,
    double? openingLoan,
    double? newLoan,
    double? monthlySaving,
    double? cumulativeSavings,
    double? installment,
    double? interest,
    double? todayTotal,
    double? closingLoan,
  }) {
    return MonthlyBachatgatReportRow(
      srNo: srNo ?? this.srNo,
      memberId: memberId ?? this.memberId,
      memberName: memberName ?? this.memberName,
      memberCode: memberCode ?? this.memberCode,
      openingLoan: openingLoan ?? this.openingLoan,
      newLoan: newLoan ?? this.newLoan,
      monthlySaving: monthlySaving ?? this.monthlySaving,
      cumulativeSavings: cumulativeSavings ?? this.cumulativeSavings,
      installment: installment ?? this.installment,
      interest: interest ?? this.interest,
      todayTotal: todayTotal ?? this.todayTotal,
      closingLoan: closingLoan ?? this.closingLoan,
    );
  }
}

class BorrowerNote {
  final String memberName;
  final double amount;

  const BorrowerNote({
    required this.memberName,
    required this.amount,
  });
}

class MonthlyBachatgatReportData {
  final String groupId;
  final String groupName;
  final int month;
  final int year;
  final List<MonthlyBachatgatReportRow> rows;
  final List<BorrowerNote> newBorrowers;
  final BachatGroup? group;

  const MonthlyBachatgatReportData({
    required this.groupId,
    required this.groupName,
    required this.month,
    required this.year,
    required this.rows,
    required this.newBorrowers,
    this.group,
  });

  String get monthNameMr => marathiMonths[month] ?? 'महिना $month';

  // Calculated totals for table bottom
  double get totalOpeningLoan => rows.fold(0.0, (sum, r) => sum + r.openingLoan);
  double get totalNewLoan => rows.fold(0.0, (sum, r) => sum + r.newLoan);
  double get totalMonthlySaving => rows.fold(0.0, (sum, r) => sum + r.monthlySaving);
  double get totalCumulativeSavings => rows.fold(0.0, (sum, r) => sum + r.cumulativeSavings);
  double get totalInstallment => rows.fold(0.0, (sum, r) => sum + r.installment);
  double get totalInterest => rows.fold(0.0, (sum, r) => sum + r.interest);
  double get totalTodayTotal => rows.fold(0.0, (sum, r) => sum + r.todayTotal);
  double get totalClosingLoan => rows.fold(0.0, (sum, r) => sum + r.closingLoan);

  static const Map<int, String> marathiMonths = {
    1: 'जानेवारी',
    2: 'फेब्रुवारी',
    3: 'मार्च',
    4: 'एप्रिल',
    5: 'मे',
    6: 'जून',
    7: 'जुलै',
    8: 'ऑगस्ट',
    9: 'सप्टेंबर',
    10: 'ऑक्टोबर',
    11: 'नोव्हेंबर',
    12: 'डिसेंबर',
  };
}
