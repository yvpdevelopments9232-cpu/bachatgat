import 'package:flutter/material.dart';
import '../models/member.dart';
import '../models/monthly_saving.dart';
import '../models/saving_plan.dart';
import '../services/monthly_savings_service.dart';

class MonthlySavingsProvider extends ChangeNotifier {
  final MonthlySavingsService _service = MonthlySavingsService();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  int _selectedMonth = DateTime.now().month;
  int get selectedMonth => _selectedMonth;

  int _selectedYear = DateTime.now().year;
  int get selectedYear => _selectedYear;

  SavingPlan? _activePlan;
  SavingPlan? get activePlan => _activePlan;

  List<MonthlySaving> _monthlySavings = [];
  List<MonthlySaving> get monthlySavings => _monthlySavings;

  MonthlySaving? _lastSavedReceipt;
  MonthlySaving? get lastSavedReceipt => _lastSavedReceipt;

  // Member 12-Month Ledger cache
  List<MonthlySaving> _memberYearLedger = [];
  List<MonthlySaving> get memberYearLedger => _memberYearLedger;

  // --- COMPUTED KPIS FOR SELECTED MONTH ---
  int get totalMembers => _monthlySavings.length;
  double get totalExpected => _monthlySavings.fold(0.0, (s, m) => s + m.expectedAmount);
  double get totalActual => _monthlySavings.fold(0.0, (s, m) => s + m.paidAmount);
  double get totalPending => _monthlySavings.fold(0.0, (s, m) => s + m.balanceAmount);

  double get collectionRate =>
      totalExpected > 0 ? ((totalActual / totalExpected) * 100).clamp(0.0, 100.0) : 0.0;

  double get cashCollection => _monthlySavings
      .where((m) => m.paymentMode.toLowerCase() == 'cash')
      .fold(0.0, (s, m) => s + m.paidAmount);

  double get upiCollection => _monthlySavings
      .where((m) => m.paymentMode.toLowerCase() == 'upi')
      .fold(0.0, (s, m) => s + m.paidAmount);

  double get bankCollection => _monthlySavings
      .where((m) => m.paymentMode.toLowerCase() == 'bank' || m.paymentMode.toLowerCase() == 'bank transfer')
      .fold(0.0, (s, m) => s + m.paidAmount);

  List<MonthlySaving> get pendingMembers =>
      _monthlySavings.where((m) => !m.isPaid).toList();

  String get selectedMonthNameMr =>
      _selectedMonth >= 1 && _selectedMonth <= 12 ? MonthlySaving.monthNamesMr[_selectedMonth - 1] : '$_selectedMonth';

  String get selectedMonthNameEn =>
      _selectedMonth >= 1 && _selectedMonth <= 12 ? MonthlySaving.monthNamesEn[_selectedMonth - 1] : '$_selectedMonth';

  // --- ACTIONS ---

  void changeMonth(int delta, String groupId, List<Member> members) {
    var newMonth = _selectedMonth + delta;
    var newYear = _selectedYear;

    if (newMonth > 12) {
      newMonth = 1;
      newYear++;
    } else if (newMonth < 1) {
      newMonth = 12;
      newYear--;
    }

    setMonthAndYear(newMonth, newYear, groupId, members);
  }

  Future<void> setMonthAndYear(int month, int year, String groupId, List<Member> members) async {
    _selectedMonth = month;
    _selectedYear = year;
    await loadMonthlySavings(groupId, members);
  }

  Future<void> loadMonthlySavings(
    String groupId,
    List<Member> members, {
    int? month,
    int? year,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      _activePlan = await _service.getActivePlan(groupId);
      _monthlySavings = await _service.getMonthlySavingsForMonth(
        groupId: groupId,
        month: month ?? _selectedMonth,
        year: year ?? _selectedYear,
        allMembers: members,
        plan: _activePlan!,
      );
    } catch (e) {
      debugPrint('Error loading monthly savings: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<double> getPreviousPendingForMember({
    required String groupId,
    required String memberId,
    Member? member,
  }) async {
    if (_activePlan == null) return 0.0;
    return await _service.getMemberPreviousPending(
      groupId: groupId,
      memberId: memberId,
      currentMonth: _selectedMonth,
      currentYear: _selectedYear,
      expectedPerMonth: _activePlan!.monthlyAmount,
      member: member,
    );
  }

  Future<MonthlySaving?> recordPayment({
    required String groupId,
    required String memberId,
    int? month,
    int? year,
    required double expectedAmount,
    required double paidAmount,
    required double lateFee,
    required String paymentMode,
    String? bankAccountId,
    String? transactionId,
    required String paymentDate,
    required String collectedBy,
    String? remarks,
    required List<Member> members,
  }) async {
    try {
      Member? member;
      try {
        member = members.firstWhere((m) => m.id == memberId);
      } catch (_) {}

      final targetMonth = month ?? _selectedMonth;
      final targetYear = year ?? _selectedYear;

      final saved = await _service.recordPayment(
        groupId: groupId,
        memberId: memberId,
        month: targetMonth,
        year: targetYear,
        expectedAmount: expectedAmount,
        paidAmount: paidAmount,
        lateFee: lateFee,
        paymentMode: paymentMode,
        bankAccountId: bankAccountId,
        transactionId: transactionId,
        paymentDate: paymentDate,
        collectedBy: collectedBy,
        remarks: remarks,
        plan: _activePlan ??
            SavingPlan(
              id: 'default',
              groupId: groupId,
              planName: 'Regular',
              monthlyAmount: expectedAmount,
            ),
        member: member,
      );

      final isPaidPayment = (paidAmount >= expectedAmount) || saved.status == 'paid';
      final optimisticSaved = saved.copyWith(
        status: isPaidPayment ? 'paid' : saved.status,
      );
      _lastSavedReceipt = optimisticSaved;

      // Immediately update in-memory list for seamless UI feedback (0ms optimistic)
      final idx = _monthlySavings.indexWhere((m) =>
          m.memberId == memberId &&
          (m.month == targetMonth || m.id.contains(memberId) || m.id.contains('virtual-$memberId')));
      if (idx != -1) {
        _monthlySavings[idx] = optimisticSaved;
      } else {
        _monthlySavings.insert(0, optimisticSaved);
      }

      // 🚀 0ms OPTIMISTIC UPDATE FOR TAB 3 (BACHAT HISTORY):
      // Instantly insert into history list so it displays immediately when user opens history tab
      _historySavings.removeWhere((h) =>
          h.id == optimisticSaved.id ||
          (optimisticSaved.receiptNumber != null &&
              optimisticSaved.receiptNumber!.isNotEmpty &&
              h.receiptNumber == optimisticSaved.receiptNumber));
      _historySavings.insert(0, optimisticSaved);

      notifyListeners();

      // Background refresh to ensure complete state
      _service.getMonthlySavingsForMonth(
        groupId: groupId,
        month: targetMonth,
        year: targetYear,
        allMembers: members,
        plan: _activePlan ?? SavingPlan(id: 'default', groupId: groupId, planName: 'Regular', monthlyAmount: expectedAmount),
      ).then((freshList) {
        final mergedList = List<MonthlySaving>.from(freshList);
        for (var i = 0; i < mergedList.length; i++) {
          if (mergedList[i].memberId == memberId && !mergedList[i].isPaid) {
            mergedList[i] = optimisticSaved;
          }
        }
        _monthlySavings = mergedList;
        notifyListeners();
      }).catchError((_) {});

      loadSavingsHistory(groupId: groupId).catchError((_) {});

      return optimisticSaved;
    } catch (e) {
      debugPrint('Error recording payment: $e');
      return null;
    }
  }

  Future<MonthlySaving?> updatePayment({
    required String savingId,
    required String groupId,
    required String memberId,
    int? month,
    int? year,
    required double expectedAmount,
    required double paidAmount,
    required double lateFee,
    required String paymentMode,
    String? transactionId,
    required String paymentDate,
    required String collectedBy,
    String? remarks,
    String? receiptNumber,
    required List<Member> members,
  }) async {
    try {
      Member? member;
      try {
        member = members.firstWhere((m) => m.id == memberId);
      } catch (_) {}

      final targetMonth = month ?? _selectedMonth;
      final targetYear = year ?? _selectedYear;

      final updated = await _service.updatePayment(
        savingId: savingId,
        groupId: groupId,
        memberId: memberId,
        month: targetMonth,
        year: targetYear,
        expectedAmount: expectedAmount,
        paidAmount: paidAmount,
        lateFee: lateFee,
        paymentMode: paymentMode,
        transactionId: transactionId,
        paymentDate: paymentDate,
        collectedBy: collectedBy,
        remarks: remarks,
        receiptNumber: receiptNumber,
        plan: _activePlan ??
            SavingPlan(
              id: 'default',
              groupId: groupId,
              planName: 'Regular',
              monthlyAmount: expectedAmount,
            ),
        member: member,
      );

      _lastSavedReceipt = updated;

      // Update in _monthlySavings list if matches member
      final idx = _monthlySavings.indexWhere((m) => m.memberId == memberId && m.month == targetMonth && m.year == targetYear);
      if (idx != -1) {
        _monthlySavings[idx] = updated;
      }

      // 🚀 Update in _historySavings list (or insert at top if not present)
      final hIdx = _historySavings.indexWhere((h) => h.id == savingId || (receiptNumber != null && receiptNumber.isNotEmpty && h.receiptNumber == receiptNumber));
      if (hIdx != -1) {
        _historySavings[hIdx] = updated;
      } else {
        _historySavings.insert(0, updated);
      }

      notifyListeners();

      // Background refresh without wiping UI loading state
      _service.getMonthlySavingsForMonth(
        groupId: groupId,
        month: targetMonth,
        year: targetYear,
        allMembers: members,
        plan: _activePlan ?? SavingPlan(id: 'default', groupId: groupId, planName: 'Regular', monthlyAmount: expectedAmount),
      ).then((freshList) {
        final mergedList = List<MonthlySaving>.from(freshList);
        for (var i = 0; i < mergedList.length; i++) {
          if (mergedList[i].memberId == memberId && !mergedList[i].isPaid) {
            mergedList[i] = updated;
          }
        }
        _monthlySavings = mergedList;
        notifyListeners();
      }).catchError((_) {});
      loadSavingsHistory(groupId: groupId).catchError((_) {});

      return updated;
    } catch (e) {
      debugPrint('Error updating saving payment: $e');
      return null;
    }
  }

  Future<bool> deletePayment({
    required String savingId,
    required String groupId,
    required String memberId,
    required int month,
    required int year,
    String? receiptNumber,
    required List<Member> members,
  }) async {
    // 1. INSTANT OPTIMISTIC UI REMOVAL (0 milliseconds!):
    _historySavings.removeWhere((h) {
      if (h.id == savingId) return true;
      if (receiptNumber != null && receiptNumber.isNotEmpty && h.receiptNumber == receiptNumber) return true;
      if (savingId.isNotEmpty && (h.id.contains(savingId) || savingId.contains(h.id))) return true;
      return false;
    });
    notifyListeners();

    try {
      // 2. Perform database deletion
      final success = await _service.deletePayment(
        savingId: savingId,
        groupId: groupId,
        memberId: memberId,
        month: month,
        year: year,
        receiptNumber: receiptNumber,
      );

      // 3. Reload monthly savings for this month to restore member as unpaid/pending
      await loadMonthlySavings(groupId, members, month: month, year: year);

      // 4. Reload full savings history to ensure database integrity
      await loadSavingsHistory(groupId: groupId);

      notifyListeners();
      return success;
    } catch (e) {
      debugPrint('Error deleting saving payment: $e');
      await loadSavingsHistory(groupId: groupId);
      notifyListeners();
      return false;
    }
  }

  Future<void> savePlan(SavingPlan plan, String groupId, List<Member> members) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _service.savePlan(plan);
      _activePlan = plan;
      await loadMonthlySavings(groupId, members);
    } catch (e) {
      debugPrint('Error saving plan: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<MonthlySaving>> loadMemberYearLedger({
    required String groupId,
    required String memberId,
    required int year,
    required Member member,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      _memberYearLedger = await _service.getMemberYearLedger(
        groupId: groupId,
        memberId: memberId,
        year: year,
        member: member,
        plan: _activePlan ??
            SavingPlan(
              id: 'default',
              groupId: groupId,
              planName: 'Regular',
              monthlyAmount: 500.0,
            ),
      );
      return _memberYearLedger;
    } catch (e) {
      debugPrint('Error loading member ledger: $e');
      return [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- 8. SAVINGS HISTORY WITH SINGLE DATE & DATE RANGE (2 DATES) ---
  List<MonthlySaving> _historySavings = [];
  List<MonthlySaving> get historySavings => _historySavings;

  bool _historyLoading = false;
  bool get historyLoading => _historyLoading;

  String _historyFilterType = 'all'; // Default 'all' so any newly added or past entry is instantly visible
  String get historyFilterType => _historyFilterType;

  int _historySelectedMonth = DateTime.now().month;
  int get historySelectedMonth => _historySelectedMonth;

  int _historySelectedYear = DateTime.now().year;
  int get historySelectedYear => _historySelectedYear;

  DateTime _historySingleDate = DateTime.now();
  DateTime get historySingleDate => _historySingleDate;

  DateTime _historyStartDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime get historyStartDate => _historyStartDate;

  DateTime _historyEndDate = DateTime.now();
  DateTime get historyEndDate => _historyEndDate;

  String _historyPaymentMode = 'all';
  String get historyPaymentMode => _historyPaymentMode;

  String _historySearchQuery = '';
  String get historySearchQuery => _historySearchQuery;

  List<MonthlySaving> get filteredHistorySavings {
    return _historySavings.where((item) {
      if (_historyPaymentMode != 'all') {
        final mode = item.paymentMode.toLowerCase();
        final filter = _historyPaymentMode.toLowerCase();
        if (filter == 'bank') {
          if (mode != 'bank' && mode != 'bank_transfer' && mode != 'cheque') return false;
        } else if (mode != filter) {
          return false;
        }
      }
      if (_historySearchQuery.isNotEmpty) {
        final q = _historySearchQuery.toLowerCase();
        final nameMatch = item.memberName?.toLowerCase().contains(q) ?? false;
        final codeMatch = item.memberCode?.toLowerCase().contains(q) ?? false;
        final receiptMatch = item.receiptNumber?.toLowerCase().contains(q) ?? false;
        if (!nameMatch && !codeMatch && !receiptMatch) return false;
      }
      return true;
    }).toList();
  }

  double get historyTotalAmount => filteredHistorySavings.fold(0.0, (s, m) => s + m.paidAmount);
  double get historyTotalLateFee => filteredHistorySavings.fold(0.0, (s, m) => s + m.lateFee);
  int get historyCount => filteredHistorySavings.length;

  void setHistorySearch(String q) {
    _historySearchQuery = q;
    notifyListeners();
  }

  void setHistoryPaymentMode(String mode) {
    _historyPaymentMode = mode;
    notifyListeners();
  }

  Future<void> setHistoryFilterType(String type, String groupId) async {
    _historyFilterType = type;
    final now = DateTime.now();
    if (type == 'today') {
      _historySingleDate = now;
      await loadSavingsHistory(groupId: groupId, singleDate: now);
    } else if (type == 'month') {
      _historyStartDate = DateTime(_historySelectedYear, _historySelectedMonth, 1);
      _historyEndDate = DateTime(_historySelectedYear, _historySelectedMonth + 1, 0);
      await loadSavingsHistory(groupId: groupId, startDate: _historyStartDate, endDate: _historyEndDate);
    } else if (type == 'this_month') {
      _historyStartDate = DateTime(now.year, now.month, 1);
      _historyEndDate = DateTime(now.year, now.month + 1, 0);
      await loadSavingsHistory(groupId: groupId, startDate: _historyStartDate, endDate: _historyEndDate);
    } else if (type == 'all') {
      await loadSavingsHistory(groupId: groupId);
    } else if (type == 'single') {
      await loadSavingsHistory(groupId: groupId, singleDate: _historySingleDate);
    } else if (type == 'range') {
      await loadSavingsHistory(groupId: groupId, startDate: _historyStartDate, endDate: _historyEndDate);
    }
  }

  Future<void> setHistoryMonth(int month, int year, String groupId) async {
    _historySelectedMonth = month;
    _historySelectedYear = year;
    _historyFilterType = 'month';
    _historyStartDate = DateTime(year, month, 1);
    _historyEndDate = DateTime(year, month + 1, 0);
    await loadSavingsHistory(groupId: groupId, startDate: _historyStartDate, endDate: _historyEndDate);
  }

  Future<void> setHistorySingleDate(DateTime date, String groupId) async {
    _historySingleDate = date;
    _historyFilterType = 'single';
    await loadSavingsHistory(groupId: groupId, singleDate: date);
  }

  Future<void> setHistoryDateRange(DateTime start, DateTime end, String groupId) async {
    _historyStartDate = start;
    _historyEndDate = end;
    _historyFilterType = 'range';
    await loadSavingsHistory(groupId: groupId, startDate: start, endDate: end);
  }

  Future<void> loadSavingsHistory({
    required String groupId,
    DateTime? singleDate,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    _historyLoading = true;
    notifyListeners();

    try {
      DateTime? sDate = singleDate;
      DateTime? stDate = startDate;
      DateTime? enDate = endDate;

      if (_historyFilterType == 'single') {
        sDate = singleDate ?? _historySingleDate;
      } else if (_historyFilterType == 'today') {
        sDate = singleDate ?? DateTime.now();
      } else if (_historyFilterType == 'range') {
        stDate = startDate ?? _historyStartDate;
        enDate = endDate ?? _historyEndDate;
      } else if (_historyFilterType == 'this_month') {
        final now = DateTime.now();
        stDate = startDate ?? DateTime(now.year, now.month, 1);
        enDate = endDate ?? DateTime(now.year, now.month + 1, 0);
      } else if (_historyFilterType == 'month') {
        stDate = startDate ?? DateTime(_historySelectedYear, _historySelectedMonth, 1);
        enDate = endDate ?? DateTime(_historySelectedYear, _historySelectedMonth + 1, 0);
      } else if (_historyFilterType == 'all') {
        sDate = null;
        stDate = null;
        enDate = null;
      }

      _historySavings = await _service.getSavingsHistory(
        groupId: groupId,
        singleDate: sDate,
        startDate: stDate,
        endDate: enDate,
      );
    } catch (e) {
      debugPrint('Error loading savings history: $e');
    } finally {
      _historyLoading = false;
      notifyListeners();
    }
  }
}

