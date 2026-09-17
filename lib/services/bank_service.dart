import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/bank_account.dart';
import '../models/bank_transaction.dart';
import 'supabase_service.dart';

class BankMetrics {
  final double currentBalance;
  final double periodDeposit;
  final double periodWithdraw;
  final double netChange;

  const BankMetrics({
    required this.currentBalance,
    required this.periodDeposit,
    required this.periodWithdraw,
    required this.netChange,
  });
}

class BankService {
  static final BankService _instance = BankService._internal();
  factory BankService() => _instance;
  BankService._internal();

  final SupabaseService _supabase = SupabaseService();

  /// Fetch all bank accounts for a group, calculating actual live balances
  Future<List<BankAccount>> fetchBankAccounts(String groupId) async {
    try {
      final res = await _supabase.client
          .from('bank_accounts')
          .select()
          .eq('group_id', groupId)
          .order('created_at', ascending: true);

      final List<BankAccount> accounts = (res as List)
          .map((item) => BankAccount.fromJson(Map<String, dynamic>.from(item)))
          .toList();

      // Ensure live current_balance for each bank account from latest transaction or database balance
      final List<BankAccount> updatedAccounts = [];
      for (final acc in accounts) {
        try {
          final txRes = await _supabase.client
              .from('bank_transactions')
              .select('balance_after, transaction_date, created_at')
              .eq('bank_account_id', acc.id)
              .order('transaction_date', ascending: false)
              .order('created_at', ascending: false)
              .limit(1);

          if ((txRes as List).isNotEmpty) {
            final latestBal = (txRes.first['balance_after'] as num?)?.toDouble();
            if (latestBal != null) {
              updatedAccounts.add(acc.copyWith(currentBalance: latestBal));
              try {
                await _supabase.client
                    .from('bank_accounts')
                    .update({'current_balance': latestBal})
                    .eq('id', acc.id);
              } catch (_) {}
              continue;
            }
          }
          updatedAccounts.add(acc);
        } catch (_) {
          updatedAccounts.add(acc);
        }
      }

      return updatedAccounts;
    } catch (e) {
      debugPrint('Error fetching bank accounts: $e');
      return [];
    }
  }

  /// Create a new bank account
  Future<BankAccount?> createBankAccount(BankAccount account) async {
    try {
      final id = account.id.isNotEmpty ? account.id : const Uuid().v4();
      final now = DateTime.now().toIso8601String();
      final dateStr = account.openingBalanceDate ?? now.split('T').first;

      final data = account.toJson();
      data['id'] = id;
      data['created_at'] = now;
      data['updated_at'] = now;
      data['current_balance'] = account.openingBalance;
      data['opening_balance_date'] = dateStr;

      await _supabase.client.from('bank_accounts').insert(data);

      return account.copyWith(
        currentBalance: account.openingBalance,
        openingBalanceDate: dateStr,
      );
    } catch (e) {
      debugPrint('Error creating bank account: $e');
      return null;
    }
  }

  /// Update existing bank account details
  Future<bool> updateBankAccount(BankAccount account) async {
    try {
      final now = DateTime.now().toIso8601String();
      final data = {
        'bank_name': account.bankName,
        'branch': account.branch,
        'account_number': account.accountNumber,
        'ifsc': account.ifsc,
        'account_type': account.accountType,
        'account_holder': account.accountHolder,
        'opening_balance': account.openingBalance,
        'opening_balance_date': account.openingBalanceDate,
        'status': account.status,
        'bank_address': account.bankAddress,
        'mobile_number': account.mobileNumber,
        'email': account.email,
        'notes': account.notes,
        'updated_at': now,
      };

      await _supabase.client
          .from('bank_accounts')
          .update(data)
          .eq('id', account.id);

      return true;
    } catch (e) {
      debugPrint('Error updating bank account: $e');
      return false;
    }
  }

  /// Toggle active/inactive status
  Future<bool> toggleBankStatus(String bankId, String newStatus) async {
    try {
      final now = DateTime.now().toIso8601String();
      await _supabase.client
          .from('bank_accounts')
          .update({'status': newStatus, 'updated_at': now})
          .eq('id', bankId);
      return true;
    } catch (e) {
      debugPrint('Error toggling bank status: $e');
      return false;
    }
  }

  /// Check whether an account has any transactions recorded
  Future<int> getTransactionCount(String bankId) async {
    try {
      final res = await _supabase.client
          .from('bank_transactions')
          .select('id')
          .eq('bank_account_id', bankId);
      return (res as List).length;
    } catch (e) {
      return 0;
    }
  }

  /// Delete bank account if no transactions exist
  Future<bool> deleteBankAccount(String bankId) async {
    try {
      final count = await getTransactionCount(bankId);
      if (count > 0) {
        throw Exception('Cannot delete bank account with existing transactions');
      }

      await _supabase.client.from('bank_accounts').delete().eq('id', bankId);
      return true;
    } catch (e) {
      debugPrint('Error deleting bank account: $e');
      return false;
    }
  }

  /// Fetch bank transactions with filters
  Future<List<BankTransaction>> fetchBankTransactions({
    required String groupId,
    String? bankAccountId,
    DateTime? fromDate,
    DateTime? toDate,
    String? typeFilter, // 'all', 'deposit', 'withdraw'
    String? searchQuery,
  }) async {
    try {
      var query = _supabase.client
          .from('bank_transactions')
          .select()
          .eq('group_id', groupId);

      if (bankAccountId != null && bankAccountId.isNotEmpty && bankAccountId != 'all') {
        query = query.eq('bank_account_id', bankAccountId);
      }

      if (fromDate != null) {
        final fStr = "${fromDate.year}-${fromDate.month.toString().padLeft(2, '0')}-${fromDate.day.toString().padLeft(2, '0')}";
        query = query.gte('transaction_date', fStr);
      }

      if (toDate != null) {
        final tStr = "${toDate.year}-${toDate.month.toString().padLeft(2, '0')}-${toDate.day.toString().padLeft(2, '0')}";
        query = query.lte('transaction_date', '$tStr\uffff');
      }

      final res = await query.order('transaction_date', ascending: false);

      List<BankTransaction> list = (res as List)
          .map((item) => BankTransaction.fromJson(Map<String, dynamic>.from(item)))
          .toList();

      // Apply in-memory filters for type and search query
      if (typeFilter != null && typeFilter != 'all') {
        final isDep = typeFilter.toLowerCase() == 'deposit';
        list = list.where((t) => t.isDeposit == isDep).toList();
      }

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.toLowerCase().trim();
        list = list.where((t) {
          final p = (t.purpose ?? '').toLowerCase();
          final r = (t.remarks ?? '').toLowerCase();
          final ref = (t.transactionNumber ?? t.depositSlipOrChequeNo ?? '').toLowerCase();
          final pb = (t.performedBy ?? '').toLowerCase();
          return p.contains(q) || r.contains(q) || ref.contains(q) || pb.contains(q);
        }).toList();
      }

      return list;
    } catch (e) {
      debugPrint('Error fetching bank transactions: $e');
      return [];
    }
  }

  /// Record a manual deposit or withdrawal
  Future<bool> recordBankTransaction({
    required String groupId,
    required String bankAccountId,
    required String transactionDate,
    required String type, // 'deposit' or 'withdrawal'
    required double amount,
    String? referenceNumber,
    String? purpose,
    String? performedBy,
    String? remarks,
  }) async {
    try {
      final isDeposit = type.toLowerCase() == 'deposit' || type.toLowerCase() == 'credit';
      await _supabase.adjustBankBalance(
        groupId: groupId,
        bankAccountId: bankAccountId,
        amount: amount,
        isDeposit: isDeposit,
        purpose: purpose ?? (isDeposit ? 'बँक ठेव जमा' : 'बँक रक्कम काढली'),
        performedBy: performedBy,
        remarks: remarks,
        transactionNumber: referenceNumber,
        transactionDate: transactionDate,
      );
      return true;
    } catch (e) {
      debugPrint('Error recording bank transaction: $e');
      return false;
    }
  }

  /// Calculate Dashboard Metrics:
  /// 1. Current Bank Balance (All-time unrestricted: Opening Balance + All Deposits - All Withdrawals)
  /// 2. Period Deposit (Deposits between fromDate and toDate)
  /// 3. Period Withdraw (Withdrawals between fromDate and toDate)
  /// 4. Net Change (Period Deposit - Period Withdraw)
  Future<BankMetrics> calculateMetrics({
    required String groupId,
    String? bankAccountId,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      // 1. Fetch relevant accounts with synchronized live balances
      final allAccounts = await fetchBankAccounts(groupId);
      final accounts = (bankAccountId != null && bankAccountId.isNotEmpty && bankAccountId != 'all')
          ? allAccounts.where((a) => a.id == bankAccountId).toList()
          : allAccounts;

      // 2. Fetch transactions for these accounts to calculate period metrics
      var allTxQuery = _supabase.client.from('bank_transactions').select().eq('group_id', groupId);
      if (bankAccountId != null && bankAccountId.isNotEmpty && bankAccountId != 'all') {
        allTxQuery = allTxQuery.eq('bank_account_id', bankAccountId);
      }
      final allTxRes = await allTxQuery;

      double periodDeposits = 0.0;
      double periodWithdrawals = 0.0;

      final fStr = fromDate != null
          ? "${fromDate.year}-${fromDate.month.toString().padLeft(2, '0')}-${fromDate.day.toString().padLeft(2, '0')}"
          : null;
      final tStr = toDate != null
          ? "${toDate.year}-${toDate.month.toString().padLeft(2, '0')}-${toDate.day.toString().padLeft(2, '0')}"
          : null;

      for (final item in (allTxRes as List)) {
        final t = BankTransaction.fromJson(Map<String, dynamic>.from(item));
        final amt = t.amount;
        final isDep = t.isDeposit;

        // Check if within period filter
        bool inPeriod = true;
        final datePart = t.transactionDate.split('T').first.split(' ').first;
        if (fStr != null && datePart.compareTo(fStr) < 0) inPeriod = false;
        if (tStr != null && datePart.compareTo(tStr) > 0) inPeriod = false;

        if (inPeriod) {
          if (isDep) {
            periodDeposits += amt;
          } else {
            periodWithdrawals += amt;
          }
        }
      }

      double currentBal = accounts.fold(0.0, (sum, a) => sum + a.currentBalance);
      final netChange = periodDeposits - periodWithdrawals;

      return BankMetrics(
        currentBalance: currentBal,
        periodDeposit: periodDeposits,
        periodWithdraw: periodWithdrawals,
        netChange: netChange,
      );
    } catch (e) {
      debugPrint('Error calculating bank metrics: $e');
      return const BankMetrics(
        currentBalance: 0.0,
        periodDeposit: 0.0,
        periodWithdraw: 0.0,
        netChange: 0.0,
      );
    }
  }
}
