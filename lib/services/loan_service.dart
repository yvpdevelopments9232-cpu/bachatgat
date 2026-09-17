import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/loan.dart';
import '../models/member.dart';
import 'supabase_service.dart';

class LoanService {
  final SupabaseService _service = SupabaseService();

  // 1. FETCH ALL LOANS FOR GROUP
  Future<List<Loan>> fetchLoans(String groupId, [List<Member>? allMembers]) async {
    try {
      // Auto-repair erroneously closed loans with remaining principal
      try {
        await _service.client
            .from('loans')
            .update({
              'status': 'disbursed',
              'settlement_date': null,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('group_id', groupId)
            .eq('status', 'closed')
            .gt('outstanding_principal', 0.01);
      } catch (_) {}

      dynamic res;
      try {
        res = await _service.client
            .from('loans')
            .select('*, member:members!loans_member_id_fkey(full_name, member_code, mobile_number)')
            .eq('group_id', groupId)
            .order('application_date', ascending: false);
      } catch (relError) {
        debugPrint('LoanService relation embedding notice: $relError');
        // Robust fallback: fetch without join and map member details in-memory
        res = await _service.client
            .from('loans')
            .select()
            .eq('group_id', groupId)
            .order('application_date', ascending: false);
      }

      final Map<String, Member> memberMap = {
        for (var m in (allMembers ?? [])) m.id: m
      };

      final List<Loan> list = [];
      for (var row in (res as List)) {
        final memberId = row['member_id']?.toString() ?? '';
        final memberData = (row['member'] ?? row['members']) as Map<String, dynamic>?;

        String? memberName = memberData?['full_name'] ?? row['member_name'];
        if ((memberName == null || memberName.isEmpty) && memberMap.containsKey(memberId)) {
          memberName = memberMap[memberId]!.fullName;
        }

        String? memberCode = memberData?['member_code'];
        if ((memberCode == null || memberCode.isEmpty) && memberMap.containsKey(memberId)) {
          memberCode = memberMap[memberId]!.memberCode;
        }

        final outstanding = (row['outstanding_principal'] as num?)?.toDouble() ?? 0.0;
        var loanStatus = row['status']?.toString() ?? 'disbursed';
        if (loanStatus == 'closed' && outstanding > 0.01) {
          loanStatus = 'disbursed';
        }

        final loan = Loan(
          id: row['id']?.toString() ?? '',
          groupId: row['group_id']?.toString() ?? '',
          memberId: memberId,
          memberName: memberName,
          loanCode: row['loan_code']?.toString() ?? 'LN-001',
          applicationDate: row['application_date']?.toString() ?? '',
          loanType: row['loan_type']?.toString() ?? 'personal',
          interestType: row['interest_type']?.toString() ?? 'fixed',
          requestedAmount: (row['requested_amount'] as num?)?.toDouble() ?? 0.0,
          approvedAmount: (row['approved_amount'] as num?)?.toDouble() ?? 0.0,
          purpose: row['purpose']?.toString(),
          interestRate: (row['interest_rate'] as num?)?.toDouble() ?? 24.0,
          loanPeriodMonths: (row['loan_period_months'] as num?)?.toInt() ?? 12,
          emiAmount: (row['emi_amount'] as num?)?.toDouble() ?? 0.0,
          numberOfEmis: (row['number_of_emis'] as num?)?.toInt() ?? 12,
          firstEmiDate: row['first_emi_date']?.toString() ?? '',
          outstandingPrincipal: outstanding,
          totalRepaid: (row['total_repaid'] as num?)?.toDouble() ?? 0.0,
          status: loanStatus,
        );
        list.add(loan);
      }
      return list;
    } catch (e) {
      debugPrint('Error fetching loans in LoanService: $e');
      return [];
    }
  }

  // 2. FETCH EMIS FOR A SPECIFIC LOAN (Supports On-Demand In-Memory Virtual Schedule)
  Future<List<LoanEmi>> fetchEmisForLoan(String loanId, [Loan? loan]) async {
    try {
      final res = await _service.client
          .from('loan_emis')
          .select()
          .eq('loan_id', loanId)
          .order('emi_number', ascending: true);

      final List<LoanEmi> actualEmis = (res as List).map((e) => LoanEmi.fromJson(e)).toList();

      // If loan metadata is available, dynamically synthesize the remaining schedule in-memory
      // (WITHOUT saving 50 empty rows in Supabase!)
      if (loan != null && loan.loanPeriodMonths > 0) {
        final Map<int, LoanEmi> paidMap = {
          for (var emi in actualEmis) emi.emiNumber: emi
        };

        DateTime disbDate = DateTime.tryParse(loan.firstEmiDate) ??
            DateTime.tryParse(loan.applicationDate) ??
            DateTime.now();

        final monthlyPrincipal = loan.approvedAmount / loan.loanPeriodMonths;
        final monthlyInterest = (loan.approvedAmount * (loan.interestRate / 100)) / 12;
        final emiAmount = monthlyPrincipal + monthlyInterest;

        final List<LoanEmi> fullSchedule = [];
        for (int i = 1; i <= loan.loanPeriodMonths; i++) {
          if (paidMap.containsKey(i)) {
            fullSchedule.add(paidMap[i]!);
          } else {
            // Virtual in-memory pending EMI for UI display only (costs ZERO Supabase storage rows!)
            final tMonth = disbDate.month + (i - 1);
            final mDays = DateTime(disbDate.year, tMonth + 1, 0).day;
            final d = disbDate.day > mDays ? mDays : disbDate.day;
            final emiDate = DateTime(disbDate.year, tMonth, d);
            final emiDateStr =
                "${emiDate.year}-${emiDate.month.toString().padLeft(2, '0')}-${emiDate.day.toString().padLeft(2, '0')}";

            final double schedInterest;
            final double schedEmi;
            if (loan.isDecreasingEmi) {
              final paidPrincipalBefore = (i - 1) * monthlyPrincipal;
              final remainingPrincipal = math.max(0.0, loan.approvedAmount - paidPrincipalBefore);
              schedInterest = (remainingPrincipal * (loan.interestRate / 100)) / 12;
              schedEmi = monthlyPrincipal + schedInterest;
            } else {
              schedInterest = monthlyInterest;
              schedEmi = emiAmount;
            }

            fullSchedule.add(LoanEmi(
              id: 'virtual-$loanId-$i',
              loanId: loanId,
              emiNumber: i,
              dueDate: emiDateStr,
              principal: monthlyPrincipal,
              interest: schedInterest,
              emiAmount: schedEmi,
              paidAmount: 0.0,
              lateFee: 0.0,
              balance: schedEmi,
              status: 'pending',
              remarks: 'हप्ता क्र. $i/${loan.loanPeriodMonths}',
            ));
          }
        }
        return fullSchedule;
      }

      return actualEmis;
    } catch (e) {
      debugPrint('Error fetching loan emis: $e');
      return [];
    }
  }

  // 3. FETCH ALL EMIS FOR A GROUP (FOR REPAYMENT HISTORY)
  Future<List<LoanEmi>> fetchAllGroupEmis(String groupId) async {
    try {
      dynamic res;
      try {
        res = await _service.client
            .from('loan_emis')
            .select('*, loans(loan_code, member_id, member:members!loans_member_id_fkey(full_name, member_code))')
            .eq('group_id', groupId)
            .order('due_date', ascending: true);
      } catch (relError) {
        debugPrint('LoanService EMI relation embedding notice: $relError');
        res = await _service.client
            .from('loan_emis')
            .select()
            .eq('group_id', groupId)
            .order('due_date', ascending: true);
      }

      return (res as List).map((e) => LoanEmi.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error fetching group emis: $e');
      return [];
    }
  }

  // 4. DISBURSE A NEW INTERNAL LOAN (नवीन कर्ज वाटप)
  Future<Loan?> disburseLoan({
    required String groupId,
    required Member member,
    required double amount,
    required double interestRateAnnual, // e.g. 24.0% per annum (2% per month)
    required int periodMonths,
    required String purpose,
    String? guarantor1Id,
    String? guarantor2Id,
    required String disbursementDate,
    required String paymentMode,
    String? bankAccountId,
    String interestType = 'flat',
  }) async {
    try {
      final year = DateTime.now().year;
      final randomSuffix = DateTime.now().millisecondsSinceEpoch.toString().substring(8);
      final loanCode = 'LN-$year-$randomSuffix';

      // EMI Calculation
      final double emiAmount;
      final double totalInterest;
      if (interestType == 'decreasing' || interestType == 'reducing') {
        // Decreasing EMI: initial Month 1 EMI
        emiAmount = calculateDecreasingEmi(
          principal: amount,
          annualRate: interestRateAnnual,
          months: periodMonths,
          monthIndex: 1,
        );
        totalInterest = calculateTotalDecreasingInterest(
          principal: amount,
          annualRate: interestRateAnnual,
          months: periodMonths,
        );
      } else {
        // Flat EMI
        final monthlyRate = (interestRateAnnual / 12) / 100;
        final totalFlatInterest = amount * monthlyRate * periodMonths;
        emiAmount = (amount + totalFlatInterest) / periodMonths;
        totalInterest = totalFlatInterest;
      }

      // Calculate First EMI Date: 1 month after disbursement date on the same day
      DateTime disbDate = DateTime.tryParse(disbursementDate) ?? DateTime.now();
      int nextMonth = disbDate.month + 1;
      int nextYear = disbDate.year;
      if (nextMonth > 12) {
        nextMonth = 1;
        nextYear++;
      }
      final firstEmiDate = "$nextYear-${nextMonth.toString().padLeft(2, '0')}-${disbDate.day.toString().padLeft(2, '0')}";

      final createdLoanId = const Uuid().v4();

      // A. Insert Loan record into loans table
      await _service.client.from('loans').insert({
        'id': createdLoanId,
        'group_id': groupId,
        'member_id': member.id,
        'loan_code': loanCode,
        'loan_type': 'internal',
        'requested_amount': amount,
        'approved_amount': amount,
        'outstanding_principal': amount,
        'outstanding_interest': totalInterest,
        'interest_rate': interestRateAnnual,
        'interest_type': interestType,
        'loan_period_months': periodMonths,
        'number_of_emis': periodMonths,
        'emi_amount': emiAmount,
        'purpose': purpose,
        'guarantor_1_id': guarantor1Id,
        'guarantor_2_id': guarantor2Id,
        'application_date': disbursementDate,
        'approval_date': disbursementDate,
        'disbursement_date': disbursementDate,
        'first_emi_date': firstEmiDate,
        'status': 'disbursed',
        'total_repaid': 0.0,
        'remarks': 'वाटप केले ($paymentMode)',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // B. Storage Optimization:
      // We deliberately do NOT insert 50 dummy pending rows into loan_emis table.
      // Real repayment ledger rows are created on-demand ONLY when payments are collected.
      // This eliminates database storage bloat and protects Supabase row limits.

      // C. Record disbursement in Cash Book or Bank Account
      final isBank = paymentMode.toLowerCase() == 'bank' || paymentMode.toLowerCase() == 'online';
      if (isBank) {
        await _service.adjustBankBalance(
          groupId: groupId,
          bankAccountId: bankAccountId,
          amount: amount,
          isDeposit: false,
          purpose: 'अंतर्गत कर्ज वाटप - ${member.fullName} ($loanCode)',
          remarks: 'कर्ज वाटप ($purpose)',
          transactionDate: disbursementDate,
        );
      } else {
        try {
          await _service.client.from('cash_book').insert({
            'group_id': groupId,
            'entry_date': disbursementDate,
            'type': 'cash_out',
            'amount': amount,
            'description': 'अंतर्गत कर्ज वाटप - ${member.fullName} ($loanCode)',
            'reference_module': 'loans',
          });
        } catch (e) {
          debugPrint('Cash book loan expense entry warning: $e');
        }
      }

      return Loan(
        id: createdLoanId,
        groupId: groupId,
        memberId: member.id,
        memberName: member.fullName,
        loanCode: loanCode,
        applicationDate: disbursementDate,
        loanType: 'internal',
        interestType: interestType,
        requestedAmount: amount,
        approvedAmount: amount,
        purpose: purpose,
        interestRate: interestRateAnnual,
        loanPeriodMonths: periodMonths,
        emiAmount: emiAmount,
        numberOfEmis: periodMonths,
        firstEmiDate: firstEmiDate,
        outstandingPrincipal: amount,
        totalRepaid: 0.0,
        status: 'disbursed',
      );
    } catch (e) {
      debugPrint('Error disbursing loan: $e');
      return null;
    }
  }

  // 5. RECORD EMI PAYMENT (हप्ता वसुली नोंद)
  Future<bool> recordEmiPayment({
    required String groupId,
    required String loanId,
    required String emiId,
    required int emiNumber,
    required double principalPaid,
    required double interestPaid,
    required double lateFee,
    required double totalPaid,
    required String paymentMode,
    String? bankAccountId,
    String? transactionId,
    required String paymentDate,
    required String collectedBy,
    String? borrowerName,
    String? loanCode,
    String? remarks,
  }) async {
    try {
      final receiptNumber = 'EMI-$loanCode-$emiNumber';

      // A. Update or Insert EMI record in loan_emis table
      // If emiId is virtual or record doesn't exist, INSERT a new row
      bool updated = false;
      if (!emiId.startsWith('virtual') && emiId.isNotEmpty) {
        try {
          final updateRes = await _service.client.from('loan_emis').update({
            'paid_amount': totalPaid,
            'principal': principalPaid,
            'interest': interestPaid,
            'late_fee': lateFee,
            'payment_date': paymentDate,
            'payment_mode': paymentMode.toLowerCase(),
            'transaction_id': transactionId,
            'receipt_number': receiptNumber,
            'balance': 0.0,
            'status': 'paid',
            'remarks': remarks ?? 'हप्ता क्र. $emiNumber भरणा केला',
            'collected_by': collectedBy,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', emiId).select();
          if ((updateRes as List).isNotEmpty) {
            updated = true;
          }
        } catch (_) {}
      }

      if (!updated) {
        final newEmiId = const Uuid().v4();
        await _service.client.from('loan_emis').insert({
          'id': newEmiId,
          'group_id': groupId,
          'loan_id': loanId,
          'emi_number': emiNumber,
          'emi_amount': totalPaid,
          'due_date': paymentDate,
          'principal': principalPaid,
          'interest': interestPaid,
          'late_fee': lateFee,
          'paid_amount': totalPaid,
          'balance': 0.0,
          'status': 'paid',
          'payment_date': paymentDate,
          'payment_mode': paymentMode.toLowerCase(),
          'transaction_id': transactionId,
          'receipt_number': receiptNumber,
          'collected_by': collectedBy,
          'remarks': remarks ?? 'हप्ता क्र. $emiNumber भरणा केला',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }

      // B. Update Loan Table Outstanding Balances
      final loanRes = await _service.client.from('loans').select('outstanding_principal, total_repaid').eq('id', loanId).single();
      final currentOutstanding = (loanRes['outstanding_principal'] as num?)?.toDouble() ?? 0.0;
      final currentTotalRepaid = (loanRes['total_repaid'] as num?)?.toDouble() ?? 0.0;

      final newOutstanding = (currentOutstanding - principalPaid) > 0 ? (currentOutstanding - principalPaid) : 0.0;
      final newTotalRepaid = currentTotalRepaid + totalPaid;

      // CRITICAL FIX: Loan is ONLY settled when remaining principal is <= 0.01
      final isFullySettled = newOutstanding <= 0.01;

      await _service.client.from('loans').update({
        'outstanding_principal': newOutstanding,
        'total_repaid': newTotalRepaid,
        'status': isFullySettled ? 'closed' : 'disbursed',
        if (isFullySettled) 'settlement_date': paymentDate,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', loanId);

      // C. Dual Accounting: Cash in Hand vs Bank Account
      final isBank = paymentMode.toLowerCase() == 'bank' || paymentMode.toLowerCase() == 'online';
      if (isBank) {
        await _service.adjustBankBalance(
          groupId: groupId,
          bankAccountId: bankAccountId,
          amount: totalPaid,
          isDeposit: true,
          purpose: 'कर्ज हप्ता वसुली - ${borrowerName ?? "सदस्य"} (हप्ता $emiNumber, $loanCode)',
          performedBy: collectedBy,
          transactionNumber: transactionId,
          remarks: 'मुद्दल: ₹${principalPaid.toStringAsFixed(0)}, व्याज: ₹${interestPaid.toStringAsFixed(0)}, विलंब: ₹${lateFee.toStringAsFixed(0)}',
          transactionDate: paymentDate,
        );
      } else {
        try {
          await _service.client.from('cash_book').insert({
            'group_id': groupId,
            'entry_date': paymentDate,
            'type': 'cash_in',
            'amount': totalPaid,
            'description': 'कर्ज हप्ता वसुली - ${borrowerName ?? "सदस्य"} (हप्ता $emiNumber, $loanCode)',
            'reference_module': 'loans',
          });
        } catch (e) {
          debugPrint('Cash book loan receipt entry warning: $e');
        }
      }

      // D. Record Interest & Late Fee into Incomes (Directly boosts Bachatgat Profit!)
      if (interestPaid > 0) {
        try {
          await _service.client.from('incomes').insert({
            'group_id': groupId,
            'income_date': paymentDate,
            'category': 'कर्ज व्याज (Loan Interest)',
            'amount': interestPaid,
            'payment_mode': isBank ? 'bank' : 'cash',
            'received_from': borrowerName ?? 'सदस्य',
            'receipt_number': receiptNumber,
            'description': 'कर्ज व्याज वसुली (गटाचा नफा) - ${borrowerName ?? "सदस्य"} (हप्ता $emiNumber, $loanCode)',
          });
        } catch (e) {
          debugPrint('Incomes loan interest entry warning: $e');
        }
      }

      if (lateFee > 0) {
        try {
          await _service.client.from('incomes').insert({
            'group_id': groupId,
            'income_date': paymentDate,
            'category': 'विलंब शुल्क (Late Fee)',
            'amount': lateFee,
            'payment_mode': isBank ? 'bank' : 'cash',
            'received_from': borrowerName ?? 'सदस्य',
            'receipt_number': receiptNumber,
            'description': 'कर्ज थकबाकी विलंब शुल्क (गटाचा नफा) - ${borrowerName ?? "सदस्य"} (हप्ता $emiNumber, $loanCode)',
          });
        } catch (e) {
          debugPrint('Incomes late fee entry warning: $e');
        }
      }

      return true;
    } catch (e) {
      debugPrint('Error recording EMI payment: $e');
      return false;
    }
  }

  // 5a. DELETE EMI PAYMENT (हप्ता नोंद रद्द करणे व शिल्लक परत करणे)
  Future<bool> deleteEmiPayment({
    required String groupId,
    required String loanId,
    required String emiId,
  }) async {
    try {
      final emiRes = await _service.client.from('loan_emis').select().eq('id', emiId).maybeSingle();
      if (emiRes == null) return false;

      final principal = (emiRes['principal'] as num?)?.toDouble() ?? 0.0;
      final paidAmount = (emiRes['paid_amount'] as num?)?.toDouble() ?? principal;
      final paymentMode = emiRes['payment_mode']?.toString().toLowerCase() ?? 'cash';
      final receiptNumber = emiRes['receipt_number']?.toString();

      final loanRes = await _service.client.from('loans').select('outstanding_principal, total_repaid').eq('id', loanId).single();
      final currentOutstanding = (loanRes['outstanding_principal'] as num?)?.toDouble() ?? 0.0;
      final currentTotalRepaid = (loanRes['total_repaid'] as num?)?.toDouble() ?? 0.0;

      final newOutstanding = currentOutstanding + principal;
      final newTotalRepaid = math.max(0.0, currentTotalRepaid - paidAmount);

      await _service.client.from('loans').update({
        'outstanding_principal': newOutstanding,
        'total_repaid': newTotalRepaid,
        'status': 'disbursed',
        'settlement_date': null,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', loanId);

      final isBank = paymentMode == 'bank' || paymentMode == 'online' || paymentMode == 'upi';
      if (isBank) {
        await _service.adjustBankBalance(
          groupId: groupId,
          amount: paidAmount,
          isDeposit: false,
          purpose: 'हप्ता वसुली रद्द (रद्द पावती: $receiptNumber)',
          remarks: 'EMI payment deletion reversal',
        );
      } else {
        try {
          await _service.client.from('cash_book').insert({
            'group_id': groupId,
            'entry_date': DateTime.now().toString().split(' ').first,
            'type': 'cash_out',
            'amount': paidAmount,
            'description': 'हप्ता वसुली रद्द (रद्द पावती: $receiptNumber)',
            'reference_module': 'loans',
          });
        } catch (_) {}
      }

      if (receiptNumber != null && receiptNumber.isNotEmpty) {
        try {
          await _service.client.from('incomes').delete().eq('receipt_number', receiptNumber);
        } catch (_) {}
      }

      await _service.client.from('loan_emis').delete().eq('id', emiId);
      return true;
    } catch (e) {
      debugPrint('Error deleting EMI payment: $e');
      return false;
    }
  }

  // 5a. UPDATE EMI PAYMENT (हप्ता नोंद दुरुस्त करणे)
  Future<bool> updateEmiPayment({
    required String groupId,
    required String loanId,
    required String emiId,
    required double newPrincipal,
    required double newInterest,
    required double newLateFee,
    required double newTotalPaid,
    required String paymentMode,
    String? bankAccountId,
    String? transactionId,
    required String paymentDate,
    required String collectedBy,
    String? remarks,
  }) async {
    try {
      final emiRes = await _service.client.from('loan_emis').select().eq('id', emiId).maybeSingle();
      if (emiRes == null) return false;

      final oldPrincipal = (emiRes['principal'] as num?)?.toDouble() ?? 0.0;
      final oldPaid = (emiRes['paid_amount'] as num?)?.toDouble() ?? oldPrincipal;
      final receiptNumber = emiRes['receipt_number']?.toString() ?? 'EMI-REC';

      final principalDiff = newPrincipal - oldPrincipal;
      final paidDiff = newTotalPaid - oldPaid;

      final loanRes = await _service.client.from('loans').select('outstanding_principal, total_repaid').eq('id', loanId).single();
      final curOutstanding = (loanRes['outstanding_principal'] as num?)?.toDouble() ?? 0.0;
      final curRepaid = (loanRes['total_repaid'] as num?)?.toDouble() ?? 0.0;

      final newOutstanding = math.max(0.0, curOutstanding - principalDiff);
      final newTotalRepaid = math.max(0.0, curRepaid + paidDiff);

      await _service.client.from('loans').update({
        'outstanding_principal': newOutstanding,
        'total_repaid': newTotalRepaid,
        'status': newOutstanding <= 0.01 ? 'closed' : 'disbursed',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', loanId);

      final isNewBank = paymentMode.toLowerCase() == 'bank' || paymentMode.toLowerCase() == 'online' || paymentMode.toLowerCase() == 'upi';
      if (isNewBank && paidDiff != 0) {
        await _service.adjustBankBalance(
          groupId: groupId,
          bankAccountId: bankAccountId,
          amount: paidDiff.abs(),
          isDeposit: paidDiff > 0,
          purpose: 'हप्ता दुरुस्ती फरक ($receiptNumber)',
        );
      }

      await _service.client.from('loan_emis').update({
        'principal': newPrincipal,
        'interest': newInterest,
        'late_fee': newLateFee,
        'paid_amount': newTotalPaid,
        'emi_amount': newTotalPaid,
        'payment_mode': paymentMode.toLowerCase(),
        'transaction_id': transactionId,
        'payment_date': paymentDate,
        'collected_by': collectedBy,
        'remarks': remarks,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', emiId);

      return true;
    } catch (e) {
      debugPrint('Error updating EMI payment: $e');
      return false;
    }
  }

  // 5b. COLLECT LOAN EMI WITH DYNAMIC PROFIT ACCRUAL (नवीन हप्ता वसुली व नफा जमा)
  Future<bool> collectLoanEmiWithProfit({
    required String groupId,
    required String loanId,
    required String memberId,
    required String memberName,
    required String loanCode,
    required String paymentDate,
    required double collectionAmount,
    required double interest,
    required double overdueAmount,
    required double reducePrincipal,
    required double newOutstandingPrincipal,
    required int overdueDays,
    required String paymentMode,
    String? bankAccountId,
    String? transactionId,
    required String collectedBy,
    String? remarks,
  }) async {
    try {
      // 1. Fetch actual DB records for this loan
      final res = await _service.client
          .from('loan_emis')
          .select()
          .eq('loan_id', loanId)
          .order('emi_number', ascending: true);
      final actualEmis = (res as List).map((e) => LoanEmi.fromJson(e)).toList();
      final paidEmis = actualEmis.where((e) => e.status == 'paid').toList();
      final realPending = actualEmis.where((e) => e.status != 'paid').toList();

      int emiNumber = paidEmis.length + 1;
      String? emiId = realPending.isNotEmpty ? realPending.first.id : null;

      final receiptNumber = 'EMI-$loanCode-$emiNumber';

      // 2. Update existing pending EMI or insert a new EMI row
      if (emiId != null) {
        await _service.client.from('loan_emis').update({
          'paid_amount': collectionAmount,
          'principal': reducePrincipal,
          'interest': interest,
          'late_fee': overdueAmount,
          'payment_date': paymentDate,
          'payment_mode': paymentMode.toLowerCase(),
          'transaction_id': transactionId,
          'receipt_number': receiptNumber,
          'balance': 0.0,
          'status': 'paid',
          'remarks': remarks ?? 'हप्ता क्र. $emiNumber भरणा केला (मुद्दल: ₹$reducePrincipal, व्याज: ₹$interest, विलंब: ₹$overdueAmount)',
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', emiId);
      } else {
        await _service.client.from('loan_emis').insert({
          'id': const Uuid().v4(),
          'group_id': groupId,
          'loan_id': loanId,
          'emi_number': emiNumber,
          'due_date': paymentDate,
          'principal': reducePrincipal,
          'interest': interest,
          'emi_amount': collectionAmount,
          'paid_amount': collectionAmount,
          'late_fee': overdueAmount,
          'payment_date': paymentDate,
          'payment_mode': paymentMode.toLowerCase(),
          'transaction_id': transactionId,
          'receipt_number': receiptNumber,
          'balance': 0.0,
          'status': 'paid',
          'remarks': remarks ?? 'हप्ता क्र. $emiNumber भरणा केला (मुद्दल: ₹$reducePrincipal, व्याज: ₹$interest, विलंब: ₹$overdueAmount)',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }

      // 3. Update Loan principal and status
      final loanRes = await _service.client
          .from('loans')
          .select('outstanding_principal, total_repaid, approved_amount')
          .eq('id', loanId)
          .single();

      final currentRepaid = (loanRes['total_repaid'] as num?)?.toDouble() ?? 0.0;
      final newTotalRepaid = currentRepaid + collectionAmount;
      final isFullySettled = newOutstandingPrincipal <= 0.01;

      await _service.client.from('loans').update({
        'outstanding_principal': newOutstandingPrincipal > 0.01 ? newOutstandingPrincipal : 0.0,
        'total_repaid': newTotalRepaid,
        'status': isFullySettled ? 'closed' : 'disbursed',
        if (isFullySettled) 'settlement_date': paymentDate,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', loanId);

      // 4. Record Cash Book or Bank Entry
      final isBank = paymentMode.toLowerCase() == 'bank' || paymentMode.toLowerCase() == 'online';
      if (isBank) {
        await _service.adjustBankBalance(
          groupId: groupId,
          bankAccountId: bankAccountId,
          amount: collectionAmount,
          isDeposit: true,
          purpose: 'कर्ज हप्ता वसुली - $memberName ($loanCode, मुद्दल: ₹${reducePrincipal.toStringAsFixed(0)}, व्याज: ₹${interest.toStringAsFixed(0)}, विलंब: ₹${overdueAmount.toStringAsFixed(0)})',
          performedBy: collectedBy,
          transactionNumber: transactionId,
        );
      } else {
        try {
          await _service.client.from('cash_book').insert({
            'group_id': groupId,
            'entry_date': paymentDate,
            'type': 'cash_in',
            'amount': collectionAmount,
            'description': 'कर्ज हप्ता वसुली - $memberName ($loanCode, मुद्दल: ₹${reducePrincipal.toStringAsFixed(0)}, व्याज: ₹${interest.toStringAsFixed(0)}, विलंब: ₹${overdueAmount.toStringAsFixed(0)})',
            'reference_module': 'loans',
          });
        } catch (e) {
          debugPrint('Cash book loan receipt entry warning: $e');
        }
      }

      // 5. CRITICAL: RECORD INTEREST & OVERDUE INTO INCOMES (Directly boosts Bachatgat Profit!)
      if (interest > 0) {
        try {
          await _service.client.from('incomes').insert({
            'group_id': groupId,
            'income_date': paymentDate,
            'category': 'कर्ज व्याज (Loan Interest)',
            'amount': interest,
            'payment_mode': isBank ? 'bank' : 'cash',
            'received_from': memberName,
            'receipt_number': receiptNumber,
            'description': 'कर्ज व्याज वसुली (गटाचा नफा) - $memberName ($loanCode)',
          });
        } catch (e) {
          debugPrint('Incomes loan interest profit warning: $e');
        }
      }

      if (overdueAmount > 0) {
        try {
          await _service.client.from('incomes').insert({
            'group_id': groupId,
            'income_date': paymentDate,
            'category': 'विलंब शुल्क (Late Fee)',
            'amount': overdueAmount,
            'payment_mode': isBank ? 'bank' : 'cash',
            'received_from': memberName,
            'receipt_number': receiptNumber,
            'description': 'कर्ज थकबाकी विलंब शुल्क (गटाचा नफा) - $memberName ($loanCode, $overdueDays दिवस उशीर)',
          });
        } catch (e) {
          debugPrint('Incomes overdue fee profit warning: $e');
        }
      }

      return true;
    } catch (e) {
      debugPrint('Error in collectLoanEmiWithProfit: $e');
      return false;
    }
  }

  // 6. PRE-CLOSE / FULL SETTLEMENT OF LOAN (कर्ज पूर्ण परतफेड)
  Future<bool> precloseLoan({
    required String groupId,
    required String loanId,
    required String loanCode,
    required String borrowerName,
    required double settlementAmount,
    required String paymentMode,
    String? bankAccountId,
    required String paymentDate,
    required String collectedBy,
  }) async {
    try {
      // Mark all pending EMIs as paid
      await _service.client.from('loan_emis').update({
        'status': 'paid',
        'payment_date': paymentDate,
        'payment_mode': paymentMode.toLowerCase(),
        'balance': 0.0,
        'remarks': 'कर्ज पूर्ण परतफेड (Pre-closed)',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('loan_id', loanId).eq('status', 'pending');

      // Update Loan status to closed
      await _service.client.from('loans').update({
        'outstanding_principal': 0.0,
        'status': 'closed',
        'settlement_date': paymentDate,
        'remarks': 'कर्ज पूर्ण परतफेड करून खाते बंद केले ($paymentDate)',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', loanId);

      // Insert Cash Book or Bank entry
      final isBank = paymentMode.toLowerCase() == 'bank' || paymentMode.toLowerCase() == 'online';
      if (isBank) {
        await _service.adjustBankBalance(
          groupId: groupId,
          bankAccountId: bankAccountId,
          amount: settlementAmount,
          isDeposit: true,
          purpose: 'कर्ज पूर्ण परतफेड (Full Settlement) - $borrowerName ($loanCode)',
          performedBy: collectedBy,
        );
      } else {
        try {
          await _service.client.from('cash_book').insert({
            'group_id': groupId,
            'entry_date': paymentDate,
            'type': 'cash_in',
            'amount': settlementAmount,
            'description': 'कर्ज पूर्ण परतफेड (Full Settlement) - $borrowerName ($loanCode)',
            'reference_module': 'loans',
          });
        } catch (e) {
          debugPrint('Cash book pre-closure warning: $e');
        }
      }

      return true;
    } catch (e) {
      debugPrint('Error pre-closing loan: $e');
      return false;
    }
  }

  // 6. FETCH LOAN SETTINGS
  Future<LoanSettings> fetchLoanSettings(String groupId) async {
    try {
      // 1. Check settings table for customized JSON config
      final setRes = await _service.client
          .from('settings')
          .select('receipt_footer_note')
          .eq('group_id', groupId)
          .maybeSingle();

      if (setRes != null && setRes['receipt_footer_note'] != null) {
        final raw = setRes['receipt_footer_note'].toString();
        if (raw.startsWith('{') && raw.contains('interest_rate')) {
          final map = jsonDecode(raw) as Map<String, dynamic>;
          return LoanSettings.fromJson(map);
        }
      }

      // 2. Fallback to groups table columns
      final grpRes = await _service.client
          .from('groups')
          .select('default_loan_interest_rate, late_fee_per_day')
          .eq('id', groupId)
          .maybeSingle();

      if (grpRes != null) {
        final rate = (grpRes['default_loan_interest_rate'] as num?)?.toDouble() ?? 24.0;
        final lateFee = (grpRes['late_fee_per_day'] as num?)?.toDouble() ?? 18.0;
        return LoanSettings(
          interestRate: rate,
          overdueDays: 0,
          lateFeePercentage: lateFee,
          interestType: 'yearly',
        );
      }
    } catch (e) {
      debugPrint('Error fetching loan settings: $e');
    }
    return const LoanSettings();
  }

  // 7. SAVE LOAN SETTINGS
  Future<bool> saveLoanSettings(String groupId, LoanSettings settings) async {
    try {
      // 1. Update groups table
      try {
        await _service.client.from('groups').update({
          'default_loan_interest_rate': settings.interestRate,
          'late_fee_per_day': settings.lateFeePercentage,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', groupId);
      } catch (ge) {
        debugPrint('Warning updating groups loan rate: $ge');
      }

      // 2. Update or insert in settings table with full JSON config
      final jsonPayload = jsonEncode(settings.toJson());
      try {
        final existing = await _service.client
            .from('settings')
            .select('id')
            .eq('group_id', groupId)
            .maybeSingle();

        if (existing != null) {
          await _service.client.from('settings').update({
            'receipt_footer_note': jsonPayload,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('group_id', groupId);
        } else {
          await _service.client.from('settings').insert({
            'group_id': groupId,
            'receipt_footer_note': jsonPayload,
          });
        }
      } catch (se) {
        debugPrint('Warning saving settings JSON: $se');
      }

      return true;
    } catch (e) {
      debugPrint('Error saving loan settings: $e');
      return false;
    }
  }

  // 8. CLEANUP DUMMY PENDING ROWS (Supabase Row & Storage Optimization)
  Future<int> cleanupDummyPendingEmis(String groupId) async {
    try {
      final res = await _service.client
          .from('loan_emis')
          .delete()
          .eq('group_id', groupId)
          .eq('status', 'pending')
          .eq('paid_amount', 0.0)
          .select('id');
      return (res as List).length;
    } catch (e) {
      debugPrint('Cleanup note: $e');
      return 0;
    }
  }

  // 9. RECONCILE LOAN BALANCE WITH EMIS
  Future<void> reconcileLoanBalance({
    required String loanId,
    required double outstandingPrincipal,
    required double totalRepaid,
    required String status,
  }) async {
    try {
      await _service.client.from('loans').update({
        'outstanding_principal': outstandingPrincipal,
        'total_repaid': totalRepaid,
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', loanId);
    } catch (e) {
      debugPrint('reconcileLoanBalance note: $e');
    }
  }
}
