import 'package:flutter/foundation.dart';
import '../models/member.dart';
import '../models/monthly_saving.dart';
import '../models/saving_plan.dart';
import 'supabase_service.dart';

class MonthlySavingsService {
  final SupabaseService _service = SupabaseService();

  // --- 1. GET / CREATE SAVING PLAN ---
  Future<SavingPlan> getActivePlan(String groupId, {double defaultAmount = 500.0}) async {
    try {
      final res = await _service.client
          .from('saving_plans')
          .select()
          .eq('group_id', groupId)
          .eq('status', 'active')
          .maybeSingle();

      if (res != null) {
        return SavingPlan.fromJson(res);
      }
    } catch (e) {
      debugPrint('saving_plans table check: $e');
    }

    // Default Fallback Plan
    return SavingPlan(
      id: 'default-plan',
      groupId: groupId,
      planName: 'Regular Monthly Saving (नियमित मासिक बचत)',
      monthlyAmount: defaultAmount > 0 ? defaultAmount : 500.0,
      dueDay: 10,
      gracePeriodDays: 5,
      lateFee: 20.0,
      status: 'active',
    );
  }

  // --- 2. SAVE PLAN ---
  Future<void> savePlan(SavingPlan plan) async {
    try {
      if (plan.id == 'default-plan' || plan.id.isEmpty) {
        await _service.client.from('saving_plans').insert(plan.toJson());
      } else {
        await _service.client.from('saving_plans').update(plan.toJson()).eq('id', plan.id);
      }
    } catch (e) {
      debugPrint('Error saving saving_plan: $e');
    }
  }

  // --- 3. GET MONTHLY SAVINGS FOR SELECTED MONTH & YEAR ---
  Future<List<MonthlySaving>> getMonthlySavingsForMonth({
    required String groupId,
    required int month,
    required int year,
    required List<Member> allMembers,
    required SavingPlan plan,
  }) async {
    final Map<String, MonthlySaving> existingRecords = {};
    final monthStr = month.toString().padLeft(2, '0');
    final dueDayStr = plan.dueDay.toString().padLeft(2, '0');
    final defaultDueDate = '$year-$monthStr-$dueDayStr';

    // Safe calendar days calculation (prevents Postgres "date/time out of range" error on 30-day months)
    final firstDayStr = '$year-$monthStr-01';
    final lastDayInt = DateTime(year, month + 1, 0).day; // e.g. 30 for Sep, 31 for Aug, 28 for Feb
    final lastDayStr = '$year-$monthStr-${lastDayInt.toString().padLeft(2, '0')}';

    // A. Query primary savings table (guaranteed to exist in Supabase schema)
    try {
      final res = await _service.client
          .from('savings')
          .select('*, members(full_name, member_code, mobile_number, photo_url)')
          .eq('group_id', groupId)
          .gte('savings_date', firstDayStr)
          .lte('savings_date', lastDayStr);

      for (var row in (res as List)) {
        final memberId = row['member_id']?.toString() ?? '';
        if (memberId.isEmpty) continue;

        final amt = (row['amount'] as num?)?.toDouble() ?? 0.0;
        final exp = plan.monthlyAmount;
        final status = amt >= exp ? 'paid' : (amt > 0 ? 'partial' : 'pending');

        final memberData = row['members'] as Map<String, dynamic>?;
        final memberName = memberData != null ? memberData['full_name'] : null;
        final memberCode = memberData != null ? memberData['member_code'] : null;
        final mobileNumber = memberData != null ? memberData['mobile_number'] : null;
        final photoUrl = memberData != null ? memberData['photo_url'] : null;

        existingRecords[memberId] = MonthlySaving(
          id: row['id']?.toString() ?? '',
          groupId: groupId,
          memberId: memberId,
          memberName: memberName,
          memberCode: memberCode,
          mobileNumber: mobileNumber,
          photoUrl: photoUrl,
          savingPlanId: plan.id,
          month: month,
          year: year,
          dueDate: defaultDueDate,
          expectedAmount: exp,
          paidAmount: amt,
          lateFee: 0.0,
          balanceAmount: (exp - amt) > 0 ? (exp - amt) : 0.0,
          paymentMode: row['payment_mode'] ?? 'cash',
          transactionId: row['transaction_number'],
          receiptNumber: row['receipt_number'] ?? 'SAV-$year-$memberId',
          paymentDate: row['savings_date'],
          collectedBy: row['remarks'],
          status: status,
          remarks: row['remarks'],
        );
      }
    } catch (e) {
      debugPrint('Savings table query note: $e');
    }

    // B. Also merge with monthly_savings table if available
    try {
      final res = await _service.client
          .from('monthly_savings')
          .select('*, members(full_name, member_code, mobile_number, photo_url)')
          .eq('group_id', groupId)
          .eq('month', month)
          .eq('year', year);

      for (var row in (res as List)) {
        final item = MonthlySaving.fromJson(row);
        existingRecords[item.memberId] = item;
      }
    } catch (_) {}

    // C. Merge with allMembers:
    final List<MonthlySaving> result = [];
    final now = DateTime.now();
    DateTime? dueDateParsed;
    try {
      dueDateParsed = DateTime.parse(defaultDueDate).add(Duration(days: plan.gracePeriodDays));
    } catch (_) {}

    final bool isCurrentMonth = (month == now.month && year == now.year);
    final bool isPastMonth = (year < now.year) || (year == now.year && month < now.month);

    if (isPastMonth) {
      // For past months: Only display actual savings history if collected!
      // If no savings were collected in this past month (like July 2026), result remains empty.
      for (var member in allMembers) {
        if (existingRecords.containsKey(member.id)) {
          result.add(existingRecords[member.id]!);
        }
      }
    } else if (isCurrentMonth) {
      // For the active current collection month:
      for (var member in allMembers) {
        // Exclude members who joined after this month
        if (member.joiningDate != null && member.joiningDate!.isNotEmpty) {
          try {
            final jDate = DateTime.parse(member.joiningDate!);
            if (jDate.year > year || (jDate.year == year && jDate.month > month)) {
              continue;
            }
          } catch (_) {}
        }

        if (existingRecords.containsKey(member.id)) {
          result.add(existingRecords[member.id]!);
        } else {
          // Virtual pending / overdue row for active collection
          final isPastGrace = dueDateParsed != null && now.isAfter(dueDateParsed);
          final status = isPastGrace ? 'overdue' : 'pending';
          final lateFee = isPastGrace ? plan.lateFee : 0.0;

          result.add(
            MonthlySaving(
              id: 'virtual-${member.id}-$month-$year',
              groupId: groupId,
              memberId: member.id,
              memberName: member.fullName,
              memberCode: member.memberCode,
              mobileNumber: member.mobileNumber,
              photoUrl: member.photoUrl,
              savingPlanId: plan.id,
              month: month,
              year: year,
              dueDate: defaultDueDate,
              expectedAmount: plan.monthlyAmount,
              paidAmount: 0.0,
              lateFee: lateFee,
              balanceAmount: plan.monthlyAmount + lateFee,
              paymentMode: 'cash',
              status: status,
            ),
          );
        }
      }
    } else {
      // For future months: Only display advance payment records if any exist
      for (var member in allMembers) {
        if (existingRecords.containsKey(member.id)) {
          result.add(existingRecords[member.id]!);
        }
      }
    }

    return result;
  }

  // --- 4. PREVIOUS PENDING CALCULATION ---
  Future<double> getMemberPreviousPending({
    required String groupId,
    required String memberId,
    required int currentMonth,
    required int currentYear,
    required double expectedPerMonth,
    Member? member,
  }) async {
    double totalPending = 0.0;
    try {
      int startMonth = 1;
      if (member?.joiningDate != null && member!.joiningDate!.isNotEmpty) {
        try {
          final jDate = DateTime.parse(member.joiningDate!);
          if (jDate.year == currentYear) {
            startMonth = jDate.month;
          } else if (jDate.year > currentYear) {
            return 0.0;
          }
        } catch (_) {}
      }

      if (currentMonth <= startMonth) return 0.0;

      final res = await _service.client
          .from('savings')
          .select('amount, savings_date')
          .eq('group_id', groupId)
          .eq('member_id', memberId)
          .gte('savings_date', '$currentYear-01-01')
          .lt('savings_date', '$currentYear-${currentMonth.toString().padLeft(2, '0')}-01');

      final Map<int, double> paidPerMonth = {};
      for (var r in (res as List)) {
        final dateStr = r['savings_date']?.toString() ?? '';
        final dt = DateTime.tryParse(dateStr);
        if (dt != null && dt.year == currentYear) {
          final m = dt.month;
          final paid = (r['amount'] as num?)?.toDouble() ?? 0.0;
          paidPerMonth[m] = (paidPerMonth[m] ?? 0.0) + paid;
        }
      }

      for (int m = startMonth; m < currentMonth; m++) {
        final paid = paidPerMonth[m] ?? 0.0;
        if (paid < expectedPerMonth) {
          totalPending += (expectedPerMonth - paid);
        }
      }
    } catch (_) {}

    return totalPending;
  }

  // --- 5. RECORD PAYMENT (COLLECT MONTHLY SAVING) ---
  Future<MonthlySaving> recordPayment({
    required String groupId,
    required String memberId,
    required int month,
    required int year,
    required double expectedAmount,
    required double paidAmount,
    required double lateFee,
    required String paymentMode,
    String? bankAccountId,
    String? transactionId,
    required String paymentDate,
    required String collectedBy,
    String? remarks,
    required SavingPlan plan,
    Member? member,
  }) async {
    final receiptNumber = 'SAV-$year-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    final monthStr = month.toString().padLeft(2, '0');
    final dueDayStr = plan.dueDay.toString().padLeft(2, '0');
    final dueDate = '$year-$monthStr-$dueDayStr';

    final totalDue = expectedAmount + lateFee;
    final balance = (totalDue - paidAmount) > 0 ? (totalDue - paidAmount) : 0.0;
    final status = (paidAmount >= expectedAmount)
        ? 'paid'
        : (paidAmount > 0 ? 'partial' : (balance > 0 ? 'overdue' : 'pending'));

    // Normalize payment mode for database enum ('cash', 'bank_transfer', 'cheque', 'upi', 'other')
    String mode = paymentMode.toLowerCase().trim();
    if (mode == 'bank' || mode == 'bank transfer') mode = 'bank_transfer';
    if (mode != 'cash' && mode != 'bank_transfer' && mode != 'cheque' && mode != 'upi' && mode != 'other') {
      mode = 'cash';
    }

    // Format collector info safely into remarks
    final cleanRemarks = remarks != null && remarks.isNotEmpty ? remarks : 'मासिक बचत - महिना $month/$year';
    final fullRemarks = '$cleanRemarks (संकलक: $collectedBy)';

    // Check if collectedBy is a valid UUID
    final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    final collectedByUuid = uuidRegex.hasMatch(collectedBy.trim()) ? collectedBy.trim() : null;

    String savedId = '';

    // 1. Primary insert into savings table (guaranteed in Supabase schema)
    final savingsInsertData = <String, dynamic>{
      'group_id': groupId,
      'member_id': memberId,
      'savings_date': paymentDate,
      'savings_type': 'monthly',
      'amount': paidAmount,
      'payment_mode': mode,
      'transaction_number': transactionId,
      'receipt_number': receiptNumber,
      'remarks': fullRemarks,
    };
    if (collectedByUuid != null) {
      savingsInsertData['collected_by'] = collectedByUuid;
    }

    try {
      final res = await _service.client
          .from('savings')
          .insert(savingsInsertData)
          .select()
          .single();
      savedId = res['id']?.toString() ?? '';
    } catch (e) {
      debugPrint('Error inserting into savings table: $e');
    }

    // 2. Dual Accounting: Cash in Hand vs Bank Account
    final isBank = mode == 'bank' || mode == 'bank_transfer' || mode == 'online' || mode == 'upi' || mode == 'cheque';
    if (isBank) {
      await _service.adjustBankBalance(
        groupId: groupId,
        bankAccountId: bankAccountId,
        amount: paidAmount,
        isDeposit: true,
        purpose: 'मासिक बचत संकलन (पावती $receiptNumber) - ${member?.fullName ?? "सभासद"}',
        transactionNumber: transactionId,
      );
    } else {
      try {
        await _service.client.from('cash_book').insert({
          'group_id': groupId,
          'entry_date': paymentDate,
          'type': 'cash_in',
          'amount': paidAmount,
          'description': 'मासिक बचत संकलन (पावती $receiptNumber) - ${member?.fullName ?? "सभासद"}',
          'reference_module': 'savings',
        });
      } catch (e) {
        debugPrint('Cash book entry note: $e');
      }
    }

    // Record late fee into incomes (profit)
    if (lateFee > 0) {
      try {
        await _service.client.from('incomes').insert({
          'group_id': groupId,
          'income_date': paymentDate,
          'category': 'विलंब शुल्क (Late Fee)',
          'amount': lateFee,
          'payment_mode': isBank ? 'bank' : 'cash',
          'received_from': member?.fullName ?? 'सभासद',
          'receipt_number': receiptNumber,
          'description': 'बचत थकबाकी विलंब शुल्क (गटाचा नफा) - ${member?.fullName ?? "सभासद"}',
        });
      } catch (e) {
        debugPrint('Incomes late fee warning: $e');
      }
    }

    // 3. Also try monthly_savings table if table was created
    try {
      final data = {
        'group_id': groupId,
        'member_id': memberId,
        'saving_plan_id': plan.id != 'default-plan' ? plan.id : null,
        'month': month,
        'year': year,
        'due_date': dueDate,
        'expected_amount': expectedAmount,
        'paid_amount': paidAmount,
        'late_fee': lateFee,
        'balance_amount': balance,
        'payment_mode': mode == 'bank_transfer' ? 'bank' : mode,
        'transaction_id': transactionId,
        'receipt_number': receiptNumber,
        'payment_date': paymentDate,
        'collected_by': collectedBy,
        'status': status,
        'remarks': fullRemarks,
        'updated_at': DateTime.now().toIso8601String(),
      };
      await _service.client.from('monthly_savings').upsert(data, onConflict: 'group_id,member_id,month,year');
    } catch (_) {}

    return MonthlySaving(
      id: savedId.isNotEmpty ? savedId : 'SAV-$receiptNumber',
      groupId: groupId,
      memberId: memberId,
      memberName: member?.fullName ?? 'सभासद',
      memberCode: member?.memberCode ?? 'MB-001',
      mobileNumber: member?.mobileNumber,
      photoUrl: member?.photoUrl,
      savingPlanId: plan.id,
      month: month,
      year: year,
      dueDate: dueDate,
      expectedAmount: expectedAmount,
      paidAmount: paidAmount,
      lateFee: lateFee,
      balanceAmount: balance,
      paymentMode: paymentMode,
      transactionId: transactionId,
      receiptNumber: receiptNumber,
      paymentDate: paymentDate,
      collectedBy: collectedBy,
      status: status,
      remarks: remarks,
    );
  }

  // --- 6. GET MEMBER-WISE 12-MONTH LEDGER ---
  Future<List<MonthlySaving>> getMemberYearLedger({
    required String groupId,
    required String memberId,
    required int year,
    required Member member,
    required SavingPlan plan,
  }) async {
    final Map<int, MonthlySaving> monthRecords = {};

    try {
      final res = await _service.client
          .from('monthly_savings')
          .select()
          .eq('group_id', groupId)
          .eq('member_id', memberId)
          .eq('year', year);

      for (var r in (res as List)) {
        final item = MonthlySaving.fromJson(r);
        monthRecords[item.month] = item;
      }
    } catch (_) {}

    // Also check savings table for primary/legacy entries for this member
    try {
      final sRes = await _service.client
          .from('savings')
          .select()
          .eq('group_id', groupId)
          .eq('member_id', memberId);

      for (var row in (sRes as List)) {
        final dateStr = row['savings_date']?.toString();
        if (dateStr != null) {
          final dt = DateTime.tryParse(dateStr);
          if (dt != null && dt.year == year) {
            final amt = (row['amount'] as num?)?.toDouble() ?? 0.0;
            if (!monthRecords.containsKey(dt.month)) {
              monthRecords[dt.month] = MonthlySaving(
                id: row['id']?.toString() ?? '',
                groupId: groupId,
                memberId: memberId,
                memberName: member.fullName,
                memberCode: member.memberCode,
                mobileNumber: member.mobileNumber,
                month: dt.month,
                year: year,
                dueDate: dateStr,
                expectedAmount: plan.monthlyAmount,
                paidAmount: amt,
                lateFee: 0.0,
                balanceAmount: (plan.monthlyAmount - amt) > 0 ? (plan.monthlyAmount - amt) : 0.0,
                paymentMode: row['payment_mode'] ?? 'cash',
                receiptNumber: row['receipt_number'],
                paymentDate: dateStr,
                status: amt >= plan.monthlyAmount ? 'paid' : (amt > 0 ? 'partial' : 'pending'),
              );
            }
          }
        }
      }
    } catch (_) {}

    final List<MonthlySaving> ledger = [];
    final now = DateTime.now();

    // Determine starting month for this member in the specified year
    int startMonth = 1;
    if (member.joiningDate != null && member.joiningDate!.isNotEmpty) {
      try {
        final jDate = DateTime.parse(member.joiningDate!);
        if (jDate.year == year) {
          // Member joined during this year (e.g. May 2026 -> startMonth = 5)
          startMonth = jDate.month;
        } else if (jDate.year > year) {
          // Member joined in a future year
          startMonth = 13;
        } else {
          // Member joined in a prior year -> full year active
          startMonth = 1;
        }
      } catch (_) {}
    }

    // If there are recorded savings for any earlier month, ensure they are also included
    for (var m in monthRecords.keys) {
      if (m < startMonth) {
        startMonth = m;
      }
    }

    // Determine ending month: Only display up to the current month in the current year
    int endMonth;
    if (year < now.year) {
      endMonth = 12;
    } else if (year == now.year) {
      endMonth = now.month;
      // If member paid in advance for any future month in this year, include it
      for (var m in monthRecords.keys) {
        if (m > endMonth && m <= 12) {
          endMonth = m;
        }
      }
    } else {
      // Future year: only display months that have actual payment records
      endMonth = 0;
      for (var m in monthRecords.keys) {
        if (m > endMonth) endMonth = m;
      }
    }

    if (startMonth <= endMonth) {
      for (int m = startMonth; m <= endMonth; m++) {
        if (monthRecords.containsKey(m)) {
          ledger.add(monthRecords[m]!);
        } else {
          final monthStr = m.toString().padLeft(2, '0');
          final dueDate = '$year-$monthStr-${plan.dueDay.toString().padLeft(2, '0')}';
          final isPast = DateTime(year, m, plan.dueDay).isBefore(now);
          final status = isPast ? 'overdue' : 'pending';

          ledger.add(
            MonthlySaving(
              id: 'ledger-$m-$year',
              groupId: groupId,
              memberId: memberId,
              memberName: member.fullName,
              memberCode: member.memberCode,
              mobileNumber: member.mobileNumber,
              photoUrl: member.photoUrl,
              month: m,
              year: year,
              dueDate: dueDate,
              expectedAmount: plan.monthlyAmount,
              paidAmount: 0.0,
              lateFee: isPast ? plan.lateFee : 0.0,
              balanceAmount: plan.monthlyAmount + (isPast ? plan.lateFee : 0.0),
              status: status,
            ),
          );
        }
      }
    }

    return ledger;
  }

  // --- 7. GET SAVINGS HISTORY (BY SINGLE DATE, DATE RANGE, OR ALL) ---
  Future<List<MonthlySaving>> getSavingsHistory({
    required String groupId,
    DateTime? singleDate,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final List<MonthlySaving> results = [];
    final Set<String> seenReceipts = {};

    String? singleDateStr;
    if (singleDate != null) {
      singleDateStr =
          "${singleDate.year.toString().padLeft(4, '0')}-${singleDate.month.toString().padLeft(2, '0')}-${singleDate.day.toString().padLeft(2, '0')}";
    }

    String? startStr;
    String? endStr;
    if (startDate != null && endDate != null) {
      startStr =
          "${startDate.year.toString().padLeft(4, '0')}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}";
      endStr =
          "${endDate.year.toString().padLeft(4, '0')}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}";
    }

    // A. Query monthly_savings where paid_amount > 0
    try {
      var query = _service.client
          .from('monthly_savings')
          .select('*, members(full_name, member_code, mobile_number, photo_url)')
          .eq('group_id', groupId)
          .gt('paid_amount', 0);

      if (singleDateStr != null) {
        query = query.eq('payment_date', singleDateStr);
      } else if (startStr != null && endStr != null) {
        query = query.gte('payment_date', startStr).lte('payment_date', endStr);
      }

      final res = await query.order('payment_date', ascending: false);

      for (var row in (res as List)) {
        final item = MonthlySaving.fromJson(row);
        results.add(item);
        if (item.receiptNumber != null && item.receiptNumber!.isNotEmpty) {
          seenReceipts.add(item.receiptNumber!);
        }
      }
    } catch (e) {
      debugPrint('monthly_savings history query note: $e');
    }

    // B. Also fallback / merge with legacy savings table
    try {
      var legacyQuery = _service.client
          .from('savings')
          .select('*, members(full_name, member_code, mobile_number, photo_url)')
          .eq('group_id', groupId);

      if (singleDateStr != null) {
        legacyQuery = legacyQuery.eq('savings_date', singleDateStr);
      } else if (startStr != null && endStr != null) {
        legacyQuery = legacyQuery.gte('savings_date', startStr).lte('savings_date', endStr);
      }

      final legacyRes = await legacyQuery.order('savings_date', ascending: false);

      for (var row in (legacyRes as List)) {
        final receipt = row['receipt_number']?.toString();
        if (receipt != null && seenReceipts.contains(receipt)) {
          continue;
        }

        final memberData = row['members'] as Map<String, dynamic>?;
        final dateStr = row['savings_date']?.toString() ?? '';
        final dt = DateTime.tryParse(dateStr);
        final amt = (row['amount'] as num?)?.toDouble() ?? 0.0;

        results.add(
          MonthlySaving(
            id: row['id']?.toString() ?? 'SAV-${row['id']}',
            groupId: groupId,
            memberId: row['member_id']?.toString() ?? '',
            memberName: memberData != null ? memberData['full_name'] : row['member_name'],
            memberCode: memberData != null ? memberData['member_code'] : null,
            mobileNumber: memberData != null ? memberData['mobile_number'] : null,
            photoUrl: memberData != null ? memberData['photo_url'] : null,
            month: dt?.month ?? DateTime.now().month,
            year: dt?.year ?? DateTime.now().year,
            dueDate: dateStr,
            expectedAmount: amt,
            paidAmount: amt,
            lateFee: 0.0,
            balanceAmount: 0.0,
            paymentMode: row['payment_mode']?.toString() ?? 'cash',
            transactionId: row['transaction_number']?.toString(),
            receiptNumber: receipt ?? 'SAV-${dt?.year ?? 2026}-${row['id'] ?? '001'}',
            paymentDate: dateStr,
            collectedBy: row['collected_by']?.toString() ?? 'व्यवस्थापक',
            status: 'paid',
            remarks: row['remarks']?.toString(),
          ),
        );
      }
    } catch (e) {
      debugPrint('Legacy savings history note: $e');
    }

    // Sort descending by payment date
    results.sort((a, b) {
      final da = a.paymentDate ?? a.dueDate;
      final db = b.paymentDate ?? b.dueDate;
      return db.compareTo(da);
    });

    return results;
  }

  // --- 8. UPDATE SAVING PAYMENT ---
  Future<MonthlySaving> updatePayment({
    required String savingId,
    required String groupId,
    required String memberId,
    required int month,
    required int year,
    required double expectedAmount,
    required double paidAmount,
    required double lateFee,
    required String paymentMode,
    String? transactionId,
    required String paymentDate,
    required String collectedBy,
    String? remarks,
    String? receiptNumber,
    required SavingPlan plan,
    Member? member,
  }) async {
    final cleanReceipt = receiptNumber != null && receiptNumber.isNotEmpty
        ? receiptNumber
        : 'SAV-$year-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    final monthStr = month.toString().padLeft(2, '0');
    final dueDayStr = plan.dueDay.toString().padLeft(2, '0');
    final dueDate = '$year-$monthStr-$dueDayStr';

    final totalDue = expectedAmount + lateFee;
    final balance = (totalDue - paidAmount) > 0 ? (totalDue - paidAmount) : 0.0;
    final status = (paidAmount >= expectedAmount)
        ? 'paid'
        : (paidAmount > 0 ? 'partial' : (balance > 0 ? 'overdue' : 'pending'));

    String mode = paymentMode.toLowerCase().trim();
    if (mode == 'bank' || mode == 'bank transfer') mode = 'bank_transfer';
    if (mode != 'cash' && mode != 'bank_transfer' && mode != 'cheque' && mode != 'upi' && mode != 'other') {
      mode = 'cash';
    }

    final cleanRemarks = remarks != null && remarks.isNotEmpty ? remarks : 'मासिक बचत - महिना $month/$year';
    final fullRemarks = '$cleanRemarks (संकलक: $collectedBy)';

    // 1. Update savings table
    try {
      final updateData = <String, dynamic>{
        'savings_date': paymentDate,
        'amount': paidAmount,
        'payment_mode': mode,
        'transaction_number': transactionId,
        'receipt_number': cleanReceipt,
        'remarks': fullRemarks,
      };
      if (savingId.isNotEmpty && !savingId.startsWith('SAV-') && !savingId.startsWith('ledger-')) {
        await _service.client.from('savings').update(updateData).eq('id', savingId);
      } else {
        await _service.client
            .from('savings')
            .update(updateData)
            .eq('group_id', groupId)
            .eq('receipt_number', cleanReceipt);
      }
    } catch (e) {
      debugPrint('Error updating savings table: $e');
    }

    // 2. Update cash_book
    try {
      await _service.client.from('cash_book').update({
        'amount': paidAmount,
        'balance_after': paidAmount,
        'entry_date': paymentDate,
        'description': 'मासिक बचत संकलन (पावती $cleanReceipt) - ${member?.fullName ?? "सभासद"}',
      }).eq('group_id', groupId).like('description', '%$cleanReceipt%');
    } catch (_) {}

    // 3. Update monthly_savings
    try {
      final msData = {
        'group_id': groupId,
        'member_id': memberId,
        'saving_plan_id': plan.id != 'default-plan' ? plan.id : null,
        'month': month,
        'year': year,
        'due_date': dueDate,
        'expected_amount': expectedAmount,
        'paid_amount': paidAmount,
        'late_fee': lateFee,
        'balance_amount': balance,
        'payment_mode': mode == 'bank_transfer' ? 'bank' : mode,
        'transaction_id': transactionId,
        'receipt_number': cleanReceipt,
        'payment_date': paymentDate,
        'collected_by': collectedBy,
        'status': status,
        'remarks': fullRemarks,
        'updated_at': DateTime.now().toIso8601String(),
      };
      await _service.client.from('monthly_savings').upsert(msData, onConflict: 'group_id,member_id,month,year');
    } catch (_) {}

    return MonthlySaving(
      id: savingId.isNotEmpty ? savingId : 'SAV-$cleanReceipt',
      groupId: groupId,
      memberId: memberId,
      memberName: member?.fullName ?? 'सभासद',
      memberCode: member?.memberCode ?? 'MB-001',
      mobileNumber: member?.mobileNumber,
      photoUrl: member?.photoUrl,
      savingPlanId: plan.id,
      month: month,
      year: year,
      dueDate: dueDate,
      expectedAmount: expectedAmount,
      paidAmount: paidAmount,
      lateFee: lateFee,
      balanceAmount: balance,
      paymentMode: mode,
      transactionId: transactionId,
      receiptNumber: cleanReceipt,
      paymentDate: paymentDate,
      collectedBy: collectedBy,
      status: status,
      remarks: fullRemarks,
    );
  }

  // --- 9. DELETE SAVING PAYMENT ---
  Future<bool> deletePayment({
    required String savingId,
    required String groupId,
    required String memberId,
    required int month,
    required int year,
    String? receiptNumber,
  }) async {
    bool success = false;
    // 1. Delete from savings table
    try {
      String cleanId = savingId.trim();
      if (cleanId.startsWith('SAV-')) {
        cleanId = cleanId.substring(4);
      }
      if (cleanId.startsWith('ledger-')) {
        cleanId = cleanId.substring(7);
      }

      if (cleanId.isNotEmpty) {
        await _service.client.from('savings').delete().eq('id', cleanId);
        success = true;
      }
      // Also try original savingId if different
      if (savingId.isNotEmpty && savingId != cleanId) {
        await _service.client.from('savings').delete().eq('id', savingId);
        success = true;
      }
      if (receiptNumber != null && receiptNumber.isNotEmpty) {
        await _service.client.from('savings').delete().eq('group_id', groupId).eq('receipt_number', receiptNumber);
        success = true;
      }
    } catch (e) {
      debugPrint('Error deleting from savings table: $e');
    }

    // 2. Delete / reset in monthly_savings table
    try {
      if (receiptNumber != null && receiptNumber.isNotEmpty) {
        await _service.client
            .from('monthly_savings')
            .delete()
            .eq('group_id', groupId)
            .eq('receipt_number', receiptNumber);
        success = true;
      }
      await _service.client
          .from('monthly_savings')
          .delete()
          .eq('group_id', groupId)
          .eq('member_id', memberId)
          .eq('month', month)
          .eq('year', year);
      success = true;
    } catch (e) {
      debugPrint('Error deleting from monthly_savings table: $e');
    }

    // 3. Delete from cash_book
    if (receiptNumber != null && receiptNumber.isNotEmpty) {
      try {
        await _service.client
            .from('cash_book')
            .delete()
            .eq('group_id', groupId)
            .like('description', '%$receiptNumber%');
      } catch (_) {}
    }

    return success;
  }
}

