import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../models/member.dart';
import '../models/monthly_bachatgat_report_model.dart';
import 'supabase_service.dart';

import '../models/bachat_group.dart';

class MonthlyBachatgatReportService {
  final SupabaseService _service = SupabaseService();

  Future<MonthlyBachatgatReportData> fetchReportData({
    required String groupId,
    required String groupName,
    required int month,
    required int year,
    BachatGroup? group,
  }) async {
    final monthStr = month.toString().padLeft(2, '0');
    final lastDayInt = DateTime(year, month + 1, 0).day;
    final lastDayOfMonth = '$year-$monthStr-${lastDayInt.toString().padLeft(2, '0')}';
    final firstDate = DateTime(year, month, 1);
    final lastDate = DateTime(year, month, lastDayInt, 23, 59, 59);

    BachatGroup? effectiveGroup = group;
    if (effectiveGroup == null) {
      try {
        final gRes = await _service.client.from('groups').select().eq('id', groupId).single();
        if (gRes != null) {
          effectiveGroup = BachatGroup.fromJson(gRes as Map<String, dynamic>);
        }
      } catch (_) {}
    }

    // 1. Fetch all members
    List<Member> members = [];
    try {
      final mRes = await _service.client
          .from('members')
          .select()
          .eq('group_id', groupId)
          .order('member_code', ascending: true);
      members = (mRes as List).map((r) => Member.fromJson(r)).toList();
    } catch (e) {
      debugPrint('Error fetching members for monthly report: $e');
    }

    // 2. Fetch all loans for this group
    List<Map<String, dynamic>> allLoans = [];
    try {
      final lRes = await _service.client
          .from('loans')
          .select()
          .eq('group_id', groupId);
      allLoans = List<Map<String, dynamic>>.from(lRes as List);
    } catch (e) {
      debugPrint('Error fetching loans for monthly report: $e');
    }

    // 4. Fetch all loan EMI repayments for this group
    List<Map<String, dynamic>> allEmis = [];
    try {
      final eRes = await _service.client
          .from('loan_emis')
          .select()
          .eq('group_id', groupId);
      allEmis = List<Map<String, dynamic>>.from(eRes as List);
    } catch (e) {
      debugPrint('Error fetching loan emis for monthly report: $e');
    }

    // 5. Fetch all savings records up to end of selected month
    List<Map<String, dynamic>> allSavings = [];
    try {
      final sRes = await _service.client
          .from('savings')
          .select()
          .eq('group_id', groupId)
          .lte('savings_date', lastDayOfMonth);
      allSavings = List<Map<String, dynamic>>.from(sRes as List);
    } catch (e) {
      debugPrint('Error fetching savings for monthly report: $e');
    }

    // Group loans by member
    final Map<String, List<Map<String, dynamic>>> loansByMember = {};
    final Map<String, String> loanToMember = {};
    for (var l in allLoans) {
      final mId = l['member_id']?.toString() ?? '';
      final lId = l['id']?.toString() ?? '';
      if (mId.isNotEmpty) {
        loansByMember.putIfAbsent(mId, () => []).add(l);
      }
      if (lId.isNotEmpty && mId.isNotEmpty) {
        loanToMember[lId] = mId;
      }
    }

    // Group EMIs by member using direct member_id or loanToMember lookup
    final Map<String, List<Map<String, dynamic>>> emisByMember = {};
    for (var emi in allEmis) {
      final lId = emi['loan_id']?.toString() ?? '';
      final directMid = emi['member_id']?.toString() ?? '';
      final mId = directMid.isNotEmpty ? directMid : (loanToMember[lId] ?? '');
      if (mId.isNotEmpty) {
        emisByMember.putIfAbsent(mId, () => []).add(emi);
      }
    }

    // Group savings by member
    final Map<String, List<Map<String, dynamic>>> savingsByMember = {};
    for (var s in allSavings) {
      final mId = s['member_id']?.toString() ?? '';
      if (mId.isNotEmpty) {
        savingsByMember.putIfAbsent(mId, () => []).add(s);
      }
    }

    final List<MonthlyBachatgatReportRow> rows = [];
    final List<BorrowerNote> newBorrowers = [];

    int srNo = 1;
    for (var member in members) {
      final memberLoans = loansByMember[member.id] ?? [];
      final memberEmis = emisByMember[member.id] ?? [];
      final memberSavings = savingsByMember[member.id] ?? [];

      // A. दिलेले कर्ज (New Loan Disbursed during month)
      double newLoan = 0.0;
      for (var loan in memberLoans) {
        final disb = _parseDate(loan['disbursement_date']) ??
            _parseDate(loan['approval_date']) ??
            _parseDate(loan['created_at']);
        if (disb != null && !disb.isBefore(firstDate) && !disb.isAfter(lastDate)) {
          final amt = (loan['approved_amount'] as num?)?.toDouble() ?? (loan['requested_amount'] as num?)?.toDouble() ?? 0.0;
          newLoan += amt;
        }
      }

      if (newLoan > 0) {
        newBorrowers.add(BorrowerNote(
          memberName: member.fullName,
          amount: newLoan,
        ));
      }

      // B. कर्ज आजअखेर (Opening Loan Balance before this month)
      double openingLoan = 0.0;
      for (var loan in memberLoans) {
        final disb = _parseDate(loan['disbursement_date']) ??
            _parseDate(loan['approval_date']) ??
            _parseDate(loan['created_at']);
        final loanId = loan['id']?.toString() ?? '';
        final approved = (loan['approved_amount'] as num?)?.toDouble() ?? (loan['requested_amount'] as num?)?.toDouble() ?? 0.0;

        if (disb != null && disb.isBefore(firstDate)) {
          // Find repayments made strictly before this month for this loan
          double principalRepaidBefore = 0.0;
          for (var emi in memberEmis) {
            if (emi['loan_id']?.toString() == loanId) {
              final pDate = _parseDate(emi['payment_date']) ?? _parseDate(emi['created_at']);
              if (pDate != null && pDate.isBefore(firstDate)) {
                final paid = (emi['paid_amount'] as num?)?.toDouble() ?? 0.0;
                final pr = (emi['principal'] as num?)?.toDouble() ?? paid;
                principalRepaidBefore += pr;
              }
            }
          }
          final remainingBefore = math.max(0.0, approved - principalRepaidBefore);
          openingLoan += remainingBefore;
        }
      }

      // Fallback: If opening loan is 0, new loan is 0, but loan was disbursed before month or has outstanding principal
      if (openingLoan == 0.0 && newLoan == 0.0) {
        for (var loan in memberLoans) {
          final status = loan['status']?.toString() ?? '';
          if (status == 'disbursed' || status == 'active') {
            final disb = _parseDate(loan['disbursement_date']) ?? _parseDate(loan['created_at']);
            if (disb == null || disb.isBefore(firstDate)) {
              final approved = (loan['approved_amount'] as num?)?.toDouble() ?? (loan['requested_amount'] as num?)?.toDouble() ?? 0.0;
              final loanId = loan['id']?.toString() ?? '';
              double principalRepaidBefore = 0.0;
              for (var emi in memberEmis) {
                if (emi['loan_id']?.toString() == loanId) {
                  final pDate = _parseDate(emi['payment_date']) ?? _parseDate(emi['created_at']);
                  if (pDate != null && pDate.isBefore(firstDate)) {
                    final pr = (emi['principal'] as num?)?.toDouble() ?? (emi['paid_amount'] as num?)?.toDouble() ?? 0.0;
                    principalRepaidBefore += pr;
                  }
                }
              }
              final remaining = math.max(0.0, approved - principalRepaidBefore);
              if (remaining > 0) {
                openingLoan += remaining;
              } else {
                final outstanding = (loan['outstanding_principal'] as num?)?.toDouble() ?? 0.0;
                if (outstanding > 0) openingLoan += outstanding;
              }
            }
          }
        }
      }

      // C. महिना बचत (Monthly Saving in selected month)
      double monthlySaving = 0.0;
      for (var s in memberSavings) {
        final sDate = _parseDate(s['savings_date']) ?? _parseDate(s['created_at']);
        if (sDate != null && !sDate.isBefore(firstDate) && !sDate.isAfter(lastDate)) {
          monthlySaving += (s['amount'] as num?)?.toDouble() ?? 0.0;
        }
      }

      // D. एकूण बचत आजअखेर (Cumulative Savings up to end of selected month)
      double cumulativeSavings = 0.0;
      for (var s in memberSavings) {
        final sDate = _parseDate(s['savings_date']) ?? _parseDate(s['created_at']);
        if (sDate == null || !sDate.isAfter(lastDate)) {
          cumulativeSavings += (s['amount'] as num?)?.toDouble() ?? 0.0;
        }
      }

      // E. हप्ता (Loan Installment Principal paid during month)
      double installment = 0.0;
      double recordedInterest = 0.0;
      for (var emi in memberEmis) {
        final pDate = _parseDate(emi['payment_date']) ?? _parseDate(emi['created_at']);
        if (pDate != null && !pDate.isBefore(firstDate) && !pDate.isAfter(lastDate)) {
          final p = (emi['principal'] as num?)?.toDouble();
          final paid = (emi['paid_amount'] as num?)?.toDouble() ?? 0.0;
          final intr = (emi['interest'] as num?)?.toDouble() ?? 0.0;
          installment += (p != null && p > 0) ? p : math.max(0.0, paid - intr);
          recordedInterest += intr;
        }
      }

      // F. व्याज (Interest paid during selected month)
      // Only show interest if actually paid by member in this month, otherwise 0.
      final double interest = recordedInterest;

      // G. आजची एकूण (Today's Total = महिना बचत + हप्ता + व्याज)
      final double todayTotal = monthlySaving + installment + interest;

      // H. या महिन्यात अखेर शिल्लक कर्ज (Closing Loan = कर्ज आजअखेर + दिलेले कर्ज - हप्ता)
      final double closingLoan = math.max(0.0, openingLoan + newLoan - installment);

      rows.add(
        MonthlyBachatgatReportRow(
          srNo: srNo++,
          memberId: member.id,
          memberName: member.fullName,
          memberCode: member.memberCode,
          openingLoan: openingLoan,
          newLoan: newLoan,
          monthlySaving: monthlySaving,
          cumulativeSavings: cumulativeSavings,
          installment: installment,
          interest: interest,
          todayTotal: todayTotal,
          closingLoan: closingLoan,
        ),
      );
    }

    return MonthlyBachatgatReportData(
      groupId: groupId,
      groupName: groupName,
      month: month,
      year: year,
      rows: rows,
      newBorrowers: newBorrowers,
      group: effectiveGroup,
    );
  }
  
  DateTime? _parseDate(dynamic val) {
    if (val == null) return null;
    final str = val.toString().trim();
    if (str.isEmpty) return null;
    final parsed = DateTime.tryParse(str);
    if (parsed != null) return parsed;
    final clean = str.contains('T') ? str.split('T').first : str.split(' ').first;
    final parts = clean.contains('-') ? clean.split('-') : clean.split('/');
    if (parts.length == 3) {
      if (parts[0].length == 4) {
        final y = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        final d = int.tryParse(parts[2]);
        if (y != null && m != null && d != null) return DateTime(y, m, d);
      } else {
        final d = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        final y = int.tryParse(parts[2]);
        if (y != null && m != null && d != null) return DateTime(y, m, d);
      }
    }
    return null;
  }
}
