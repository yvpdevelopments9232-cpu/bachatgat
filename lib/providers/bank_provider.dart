import 'package:flutter/material.dart';
import '../models/bank_account.dart';
import '../models/bank_transaction.dart';
import '../services/bank_service.dart';

class BankProvider extends ChangeNotifier {
  final BankService _service = BankService();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<BankAccount> _banks = [];
  List<BankAccount> get banks => _banks;
  List<BankAccount> get activeBanks => _banks.where((b) => b.isActive).toList();

  List<BankTransaction> _transactions = [];
  List<BankTransaction> get transactions => _transactions;

  BankAccount? _selectedBank; // null means 'All Banks'
  BankAccount? get selectedBank => _selectedBank;

  DateTime? _fromDate;
  DateTime? _toDate;
  DateTime? get fromDate => _fromDate;
  DateTime? get toDate => _toDate;

  String _typeFilter = 'all'; // 'all', 'deposit', 'withdraw'
  String get typeFilter => _typeFilter;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  BankMetrics _metrics = const BankMetrics(
    currentBalance: 0.0,
    periodDeposit: 0.0,
    periodWithdraw: 0.0,
    netChange: 0.0,
  );
  BankMetrics get metrics => _metrics;

  /// Alias for loadData
  Future<void> loadBanks(String groupId) => loadData(groupId);

  /// Initialize or refresh bank data
  Future<void> loadData(String groupId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _banks = await _service.fetchBankAccounts(groupId);

      // If selected bank was deleted or no longer exists, reset to all
      if (_selectedBank != null && !_banks.any((b) => b.id == _selectedBank!.id)) {
        _selectedBank = null;
      }

      await _refreshMetricsAndTransactions(groupId);
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('BankProvider loadData error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Internal helper to calculate metrics and fetch filtered transactions
  Future<void> _refreshMetricsAndTransactions(String groupId) async {
    final bankId = _selectedBank?.id;

    _metrics = await _service.calculateMetrics(
      groupId: groupId,
      bankAccountId: bankId,
      fromDate: _fromDate,
      toDate: _toDate,
    );

    _transactions = await _service.fetchBankTransactions(
      groupId: groupId,
      bankAccountId: bankId,
      fromDate: _fromDate,
      toDate: _toDate,
      typeFilter: _typeFilter,
      searchQuery: _searchQuery,
    );
  }

  /// Update selected bank
  void setSelectedBank(BankAccount? bank, String groupId) {
    _selectedBank = bank;
    applyFilters(groupId);
  }

  /// Update date range filters
  void setDateRange(DateTime? from, DateTime? to, String groupId) {
    _fromDate = from;
    _toDate = to;
    applyFilters(groupId);
  }

  /// Update multiple filters at once and apply
  void applyAllFilters({
    required String groupId,
    BankAccount? selectedBank,
    DateTime? fromDate,
    DateTime? toDate,
  }) {
    _selectedBank = selectedBank;
    _fromDate = fromDate;
    _toDate = toDate;
    applyFilters(groupId);
  }

  /// Update transaction type filter
  void setTypeFilter(String type, String groupId) {
    _typeFilter = type;
    applyFilters(groupId);
  }

  /// Update search query
  void setSearchQuery(String query, String groupId) {
    _searchQuery = query;
    applyFilters(groupId);
  }

  /// Apply current filters
  Future<void> applyFilters(String groupId) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _refreshMetricsAndTransactions(groupId);
    } catch (e) {
      debugPrint('BankProvider applyFilters error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Reset all filters to default
  Future<void> resetFilters(String groupId) async {
    _selectedBank = null;
    _fromDate = null;
    _toDate = null;
    _typeFilter = 'all';
    _searchQuery = '';
    await loadData(groupId);
  }

  /// Add a new bank account
  Future<bool> addBankAccount(BankAccount account, String groupId) async {
    _isLoading = true;
    notifyListeners();

    final created = await _service.createBankAccount(account);
    if (created != null) {
      await loadData(groupId);
      return true;
    } else {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Update an existing bank account
  Future<bool> updateBankAccount(BankAccount account, String groupId) async {
    _isLoading = true;
    notifyListeners();

    final success = await _service.updateBankAccount(account);
    if (success) {
      await loadData(groupId);
      return true;
    } else {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Toggle account active / inactive status
  Future<bool> toggleBankStatus(String bankId, String newStatus, String groupId) async {
    final success = await _service.toggleBankStatus(bankId, newStatus);
    if (success) {
      await loadData(groupId);
      return true;
    }
    return false;
  }

  /// Delete bank account
  Future<bool> deleteBankAccount(String bankId, String groupId) async {
    final success = await _service.deleteBankAccount(bankId);
    if (success) {
      await loadData(groupId);
      return true;
    }
    return false;
  }

  /// Record a manual deposit or withdrawal
  Future<bool> addTransaction({
    required String groupId,
    required String bankAccountId,
    required String transactionDate,
    required String type,
    required double amount,
    String? referenceNumber,
    String? purpose,
    String? performedBy,
    String? remarks,
  }) async {
    _isLoading = true;
    notifyListeners();

    final success = await _service.recordBankTransaction(
      groupId: groupId,
      bankAccountId: bankAccountId,
      transactionDate: transactionDate,
      type: type,
      amount: amount,
      referenceNumber: referenceNumber,
      purpose: purpose,
      performedBy: performedBy,
      remarks: remarks,
    );

    if (success) {
      await loadData(groupId);
      return true;
    } else {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
