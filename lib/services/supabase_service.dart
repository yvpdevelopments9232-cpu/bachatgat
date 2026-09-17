import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../core/constants/supabase_config.dart';
import 'app_config.dart';
import 'offline_db_client.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  dynamic get client => AppConfig.isOfflineMode ? OfflineDbClient.instance : Supabase.instance.client;

  static Future<void> initialize() async {
    if (AppConfig.isOfflineMode && !AppConfig.isHybridMode) {
      return;
    }
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        anonKey: SupabaseConfig.anonKey,
      );
    } catch (e) {
      debugPrint('Supabase initialize note: $e');
    }
  }

  // Dashboard Metrics with Date Range support
  Future<Map<String, dynamic>> fetchDashboardMetrics(
    String groupId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final startStr = startDate != null
        ? '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}'
        : null;
    final endStr = endDate != null
        ? '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}'
        : null;

    // If no date range is specified, attempt RPC call
    if (startDate == null && endDate == null) {
      try {
        final response = await client.rpc('get_dashboard_metrics', params: {
          'p_group_id': groupId,
        });
        if (response != null && response is Map && response.isNotEmpty) {
          final resMap = Map<String, dynamic>.from(response);
          // Overwrite pending_emis with strict overdue count (due_date <= today)
          try {
            final today = DateTime.now();
            final todayStr = "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
            final emisRes = await client
                .from('loan_emis')
                .select('id')
                .eq('group_id', groupId)
                .eq('status', 'pending')
                .lte('due_date', todayStr);
            resMap['pending_emis'] = (emisRes as List).length;
          } catch (_) {}

          // Ensure bank_balance is strictly calculated as the sum of all bank accounts' current balances
          try {
            final bankRes = await client.from('bank_accounts').select('current_balance').eq('group_id', groupId);
            double totalBankBal = 0.0;
            for (var row in (bankRes as List)) {
              totalBankBal += (row['current_balance'] as num?)?.toDouble() ?? 0.0;
            }
            resMap['bank_balance'] = totalBankBal;
          } catch (_) {}

          return resMap;
        }
      } catch (e) {
        debugPrint('RPC fallback to direct table calculation: $e');
      }
    }

    // Direct table calculation with optional date range filters
    int totalMembers = 0;
    double totalSavings = 0;
    double activeLoans = 0;
    int pendingEmis = 0;
    double bankBal = 0;
    double cashInHand = 0;
    double totalIncome = 0;
    double totalExpenses = 0;

    // 1. Members
    try {
      var membersQuery = client.from('members').select('id, created_at').eq('group_id', groupId);
      if (endStr != null) {
        membersQuery = membersQuery.lte('created_at', '${endStr}T23:59:59');
      }
      final membersRes = await membersQuery;
      totalMembers = (membersRes as List).length;
    } catch (e) {
      debugPrint('Error calculating members metric: $e');
      // Fallback: count all members in group
      try {
        final fallback = await client.from('members').select('id').eq('group_id', groupId);
        totalMembers = (fallback as List).length;
      } catch (_) {}
    }

    // 2. Savings
    try {
      var savingsQuery = client.from('savings').select('amount, savings_date').eq('group_id', groupId);
      if (startStr != null) savingsQuery = savingsQuery.gte('savings_date', startStr);
      if (endStr != null) savingsQuery = savingsQuery.lte('savings_date', endStr);
      final savingsRes = await savingsQuery;
      for (var row in (savingsRes as List)) {
        totalSavings += (row['amount'] as num?)?.toDouble() ?? 0.0;
      }
    } catch (e) {
      debugPrint('Error calculating savings metric: $e');
    }

    // 3. Loans
    try {
      var loansQuery = client.from('loans').select('outstanding_principal, approved_amount, application_date, status').eq('group_id', groupId);
      if (startStr != null) loansQuery = loansQuery.gte('application_date', startStr);
      if (endStr != null) loansQuery = loansQuery.lte('application_date', endStr);
      final loansRes = await loansQuery;
      for (var row in (loansRes as List)) {
        final outstanding = (row['outstanding_principal'] as num?)?.toDouble();
        final approved = (row['approved_amount'] as num?)?.toDouble() ?? 0.0;
        activeLoans += (outstanding != null && outstanding > 0) ? outstanding : approved;
      }
    } catch (e) {
      debugPrint('Error calculating loans metric: $e');
    }

    // 4. Pending EMIs / Active Loans with balance (strictly up to today)
    try {
      final today = DateTime.now();
      final todayStr = "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
      var emisQuery = client.from('loan_emis').select('id, due_date').eq('group_id', groupId).eq('status', 'pending');
      if (startStr != null) emisQuery = emisQuery.gte('due_date', startStr);
      if (endStr != null) {
        emisQuery = emisQuery.lte('due_date', endStr);
      } else {
        emisQuery = emisQuery.lte('due_date', todayStr);
      }
      final emisRes = await emisQuery;
      final count = (emisRes as List).length;
      if (count > 0) {
        pendingEmis = count;
      } else {
        // Fallback: virtual overdue count up to today for active loans
        final activeLoansRes = await client
            .from('loans')
            .select('id, first_emi_date, application_date, emi_amount, loan_period_months, total_repaid, outstanding_principal')
            .eq('group_id', groupId)
            .inFilter('status', ['active', 'disbursed'])
            .gt('outstanding_principal', 0);
        
        int overdueCount = 0;
        for (var l in (activeLoansRes as List)) {
          final firstEmi = l['first_emi_date'] ?? l['application_date'];
          if (firstEmi != null) {
            final start = DateTime.tryParse(firstEmi.toString());
            if (start != null) {
              final emiAmt = (l['emi_amount'] as num?)?.toDouble() ?? 0.0;
              final repaid = (l['total_repaid'] as num?)?.toDouble() ?? 0.0;
              final paidCount = emiAmt > 0 ? (repaid / emiAmt).floor() : 0;
              
              int expected = 0;
              final totalMonths = (l['loan_period_months'] as num?)?.toInt() ?? 12;
              for (int m = 0; m < totalMonths; m++) {
                final d = DateTime(start.year, start.month + m, start.day);
                if (d.isBefore(today) || d.isAtSameMomentAs(today)) {
                  expected++;
                } else {
                  break;
                }
              }
              final diff = expected - paidCount;
              if (diff > 0) overdueCount += diff;
            }
          }
        }
        pendingEmis = overdueCount;
      }
    } catch (e) {
      debugPrint('Error calculating EMIs metric: $e');
    }

    // 5. Bank Accounts
    try {
      final bankRes = await client.from('bank_accounts').select('current_balance').eq('group_id', groupId);
      for (var row in (bankRes as List)) {
        bankBal += (row['current_balance'] as num?)?.toDouble() ?? 0.0;
      }
    } catch (e) {
      debugPrint('Error calculating bank balance metric: $e');
    }

    // 6. Cash in Hand (Live net cash across all modules, matching Cash Book Ledger)
    try {
      double liveCashInHand = 0.0;
      try {
        final savRes = await client.from('savings').select('amount, payment_mode').eq('group_id', groupId);
        final emiRes = await client.from('loan_emis').select('principal, interest, late_fee, paid_amount, payment_mode').eq('group_id', groupId);
        final incRes = await client.from('incomes').select('amount, payment_mode').eq('group_id', groupId);
        final expRes = await client.from('expenses').select('amount, payment_mode').eq('group_id', groupId);

        double sCash = 0.0;
        for (var r in (savRes as List)) {
          final m = r['payment_mode']?.toString().toLowerCase() ?? 'cash';
          if (m == 'cash' || m.isEmpty || m == 'रोख') sCash += (r['amount'] as num?)?.toDouble() ?? 0.0;
        }

        double eCash = 0.0;
        for (var r in (emiRes as List)) {
          final m = r['payment_mode']?.toString().toLowerCase() ?? 'cash';
          if (m == 'cash' || m.isEmpty || m == 'रोख') {
            final paid = (r['paid_amount'] as num?)?.toDouble();
            final p = (r['principal'] as num?)?.toDouble() ?? 0.0;
            final i = (r['interest'] as num?)?.toDouble() ?? 0.0;
            final f = (r['late_fee'] as num?)?.toDouble() ?? 0.0;
            eCash += paid ?? (p + i + f);
          }
        }

        double iCash = 0.0;
        for (var r in (incRes as List)) {
          final m = r['payment_mode']?.toString().toLowerCase() ?? 'cash';
          if (m == 'cash' || m.isEmpty || m == 'रोख') iCash += (r['amount'] as num?)?.toDouble() ?? 0.0;
        }

        double exCash = 0.0;
        for (var r in (expRes as List)) {
          final m = r['payment_mode']?.toString().toLowerCase() ?? 'cash';
          if (m == 'cash' || m.isEmpty || m == 'रोख') exCash += (r['amount'] as num?)?.toDouble() ?? 0.0;
        }

        double lCash = 0.0;
        try {
          final loanRes = await client.from('loans').select('approved_amount, remarks, status').eq('group_id', groupId);
          for (var r in (loanRes as List)) {
            final st = r['status']?.toString().toLowerCase() ?? '';
            if (st == 'active' || st == 'disbursed') {
              final rem = r['remarks']?.toString().toLowerCase() ?? '';
              if (rem.contains('cash') || rem.contains('रोख')) {
                lCash += (r['approved_amount'] as num?)?.toDouble() ?? 0.0;
              }
            }
          }
        } catch (_) {}

        double bcoCash = 0.0;
        double bciCash = 0.0;
        try {
          final cbBankRes = await client.from('cash_book').select('amount, type, reference_module').eq('group_id', groupId);
          for (var r in (cbBankRes as List)) {
            final ty = r['type']?.toString().toLowerCase() ?? '';
            final amt = (r['amount'] as num?)?.toDouble() ?? 0.0;
            if (ty == 'cash_out' || ty == 'payment' || ty == 'expense' || ty.contains('नावे')) {
              bcoCash += amt;
            } else if (ty == 'cash_in' || ty == 'receipt' || ty == 'income' || ty.contains('जमा')) {
              if (r['reference_module'] == 'bank') bciCash += amt;
            }
          }
        } catch (_) {}

        final liveCash = sCash + eCash + iCash + bciCash - exCash - lCash - bcoCash;
        if (liveCash > 0) {
          liveCashInHand = liveCash;
        } else if (sCash + eCash + iCash + bciCash > 0) {
          final collected = sCash + eCash + iCash + bciCash - exCash - bcoCash;
          if (collected > 0) liveCashInHand = collected;
        }
      } catch (_) {}

      if (liveCashInHand > 0) {
        cashInHand = liveCashInHand;
      } else {
        var cashQuery = client.from('cash_book').select('amount, type, entry_date, balance_after').eq('group_id', groupId);
        if (startStr != null) cashQuery = cashQuery.gte('entry_date', startStr);
        if (endStr != null) cashQuery = cashQuery.lte('entry_date', endStr);
        final cashRes = await cashQuery.order('entry_date', ascending: false);

        if ((cashRes as List).isNotEmpty) {
          cashInHand = (cashRes.first['balance_after'] as num?)?.toDouble() ?? 0.0;
        }
      }
    } catch (e) {
      debugPrint('Error calculating cash_book metric: $e');
    }

    // 7. Income
    try {
      var incQuery = client.from('incomes').select('amount, income_date').eq('group_id', groupId);
      if (startStr != null) incQuery = incQuery.gte('income_date', startStr);
      if (endStr != null) incQuery = incQuery.lte('income_date', endStr);
      final incRes = await incQuery;
      for (var row in (incRes as List)) {
        totalIncome += (row['amount'] as num?)?.toDouble() ?? 0.0;
      }
    } catch (e) {
      debugPrint('Error calculating income metric: $e');
    }

    // 8. Expenses
    try {
      var expQuery = client.from('expenses').select('amount, expense_date').eq('group_id', groupId);
      if (startStr != null) expQuery = expQuery.gte('expense_date', startStr);
      if (endStr != null) expQuery = expQuery.lte('expense_date', endStr);
      final expRes = await expQuery;
      for (var row in (expRes as List)) {
        totalExpenses += (row['amount'] as num?)?.toDouble() ?? 0.0;
      }
    } catch (e) {
      debugPrint('Error calculating expenses metric: $e');
    }

    double totalProfit = totalIncome - totalExpenses;
    if (totalProfit < 0) totalProfit = 0;

    return {
      'total_members': totalMembers,
      'total_savings': totalSavings,
      'active_loans': activeLoans,
      'pending_emis': pendingEmis,
      'bank_balance': bankBal,
      'cash_in_hand': cashInHand,
      'total_income': totalIncome,
      'total_expenses': totalExpenses,
      'total_sales': 0.0,
      'total_profit': totalProfit,
    };
  }

  // Ensure a primary bank account exists for the group
  Future<String> ensurePrimaryBankAccount(String groupId) async {
    try {
      final res = await client
          .from('bank_accounts')
          .select('id')
          .eq('group_id', groupId)
          .order('is_primary', ascending: false)
          .limit(1);
      if ((res as List).isNotEmpty) {
        return res.first['id'].toString();
      }
    } catch (_) {}

    final newId = const Uuid().v4();
    final now = DateTime.now().toIso8601String();
    try {
      await client.from('bank_accounts').insert({
        'id': newId,
        'group_id': groupId,
        'bank_name': 'बचत गट बँक खाते (Bank Account)',
        'branch': 'मुख्य शाखा',
        'account_number': 'PRIMARY-001',
        'account_type': 'savings',
        'account_holder': 'बचत गट (Self Help Group)',
        'opening_balance': 0.0,
        'current_balance': 0.0,
        'is_primary': 1,
        'status': 'active',
        'created_at': now,
        'updated_at': now,
      });
      return newId;
    } catch (e) {
      debugPrint('ensurePrimaryBankAccount note: $e');
      return newId;
    }
  }

  // Adjust Bank Account balance (deposit / withdrawal)
  Future<void> adjustBankBalance({
    required String groupId,
    String? bankAccountId,
    required double amount,
    required bool isDeposit,
    required String purpose,
    String? performedBy,
    String? remarks,
    String? transactionNumber,
    String? transactionDate,
  }) async {
    try {
      final accountId = (bankAccountId != null && bankAccountId.isNotEmpty)
          ? bankAccountId
          : await ensurePrimaryBankAccount(groupId);
      final now = DateTime.now();
      final dateStr = (transactionDate != null && transactionDate.trim().isNotEmpty)
          ? transactionDate.trim().split('T').first
          : '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      double currentBalance = 0.0;
      try {
        final accRes = await client.from('bank_accounts').select('current_balance, opening_balance').eq('id', accountId).maybeSingle();
        if (accRes != null) {
          final cb = (accRes['current_balance'] as num?)?.toDouble() ?? 0.0;
          final ob = (accRes['opening_balance'] as num?)?.toDouble() ?? 0.0;
          currentBalance = (cb != 0.0) ? cb : ob;
        }
      } catch (_) {}
      final updated = isDeposit ? (currentBalance + amount) : (currentBalance - amount);

      await client.from('bank_transactions').insert({
        'id': const Uuid().v4(),
        'group_id': groupId,
        'bank_account_id': accountId,
        'transaction_date': dateStr,
        'type': isDeposit ? 'deposit' : 'withdrawal',
        'amount': amount,
        'balance_after': updated,
        'purpose': purpose,
        'performed_by': performedBy ?? 'System',
        'remarks': remarks,
        'transaction_number': transactionNumber,
        'created_at': now.toIso8601String(),
      });

      try {
        await client.from('bank_accounts').update({
          'current_balance': updated,
          'updated_at': now.toIso8601String(),
        }).eq('id', accountId);
      } catch (e) {
        debugPrint('Error updating bank_accounts current_balance: $e');
      }
    } catch (e) {
      debugPrint('adjustBankBalance note: $e');
    }
  }
}
