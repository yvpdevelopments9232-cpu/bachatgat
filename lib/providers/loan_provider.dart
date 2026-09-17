import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/loan.dart';
import '../models/member.dart';
import '../services/loan_service.dart';

class LoanProvider extends ChangeNotifier {
  final LoanService _service = LoanService();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<Loan> _loans = [];
  List<Loan> get loans => _loans;

  List<LoanEmi> _emis = [];
  List<LoanEmi> get emis => _emis;

  // Selected Loan for Details / EMI schedule
  Loan? _selectedLoan;
  Loan? get selectedLoan => _selectedLoan;

  List<LoanEmi> _selectedLoanEmis = [];
  List<LoanEmi> get selectedLoanEmis => _selectedLoanEmis;
  bool _isLoadingEmis = false;
  bool get isLoadingEmis => _isLoadingEmis;

  // Loan Settings (Interest Rate, Overdue Days, Late Fee %)
  LoanSettings _loanSettings = const LoanSettings();
  LoanSettings get loanSettings => _loanSettings;

  // Filter & Search
  String _statusFilter = 'all'; // 'all', 'active', 'closed', 'overdue'
  String get statusFilter => _statusFilter;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  // Filtered Loans
  List<Loan> get filteredLoans {
    return _loans.where((l) {
      if (_statusFilter != 'all') {
        if (_statusFilter == 'active' && !l.isActive) return false;
        if (_statusFilter == 'closed' && !l.isClosed) return false;
        if (_statusFilter == 'overdue' && !l.isOverdue) return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final nameMatch = l.memberName?.toLowerCase().contains(q) ?? false;
        final codeMatch = l.loanCode.toLowerCase().contains(q);
        final purposeMatch = l.purpose?.toLowerCase().contains(q) ?? false;
        if (!nameMatch && !codeMatch && !purposeMatch) return false;
      }
      return true;
    }).toList();
  }

  // --- KPI METRICS ---
  List<Loan> get activeLoans => _loans.where((l) => l.isActive).toList();
  List<Loan> get closedLoans => _loans.where((l) => l.isClosed).toList();
  List<Loan> get overdueLoans => _loans.where((l) => l.isOverdue).toList();

  List<Loan> get fixedEmiLoans => activeLoans.where((l) => l.isFixedEmi).toList();
  List<Loan> get decreasingEmiLoans => activeLoans.where((l) => l.isDecreasingEmi).toList();

  double get totalDisbursed => _loans.fold(0.0, (s, l) => s + l.approvedAmount);
  double get totalOutstanding => activeLoans.fold(0.0, (s, l) => s + l.outstandingPrincipal);
  double get totalRepaid => _loans.fold(0.0, (s, l) => s + l.totalRepaid);
  int get activeBorrowersCount => activeLoans.map((l) => l.memberId).toSet().length;

  // --- REAL-TIME DYNAMIC OVERDUE COMPUTATIONS ---
  /// Computes real-time overdue information for all active loans.
  List<LoanOverdueInfo> getAllLoansOverdueInfo({DateTime? asOfDate}) {
    return activeLoans.map((l) => calculateLoanOverdue(l, _emis, asOfDate)).toList();
  }

  /// Returns only the loans that have at least 1 overdue EMI past due date.
  List<LoanOverdueInfo> getOverdueLoansInfo({DateTime? asOfDate}) {
    return getAllLoansOverdueInfo(asOfDate: asOfDate).where((info) => info.isOverdue).toList();
  }

  /// Total sum of past-due missed EMIs (NOT total loan principal!).
  double getTotalOverdueAmount({DateTime? asOfDate}) {
    return getOverdueLoansInfo(asOfDate: asOfDate).fold(0.0, (s, i) => s + i.overdueAmount);
  }

  /// Number of members with past-due missed EMIs.
  int getDefaultersCount({DateTime? asOfDate}) {
    return getOverdueLoansInfo(asOfDate: asOfDate).length;
  }

  void setStatusFilter(String filter) {
    _statusFilter = filter;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void selectLoan(Loan? loan) {
    _selectedLoan = loan;
    if (loan != null) {
      loadEmisForLoan(loan.id);
    } else {
      _selectedLoanEmis = [];
      notifyListeners();
    }
  }

  Future<void> loadLoans(String groupId) => fetchLoans(groupId);

  // 1. FETCH ALL LOANS
  Future<void> fetchLoans(String groupId, [List<Member>? members]) async {
    _isLoading = true;
    notifyListeners();

    try {
      _loans = await _service.fetchLoans(groupId, members);

      // Also pre-fetch all EMIs for the group
      _emis = await _service.fetchAllGroupEmis(groupId);

      // Auto-reconcile loan outstanding principal and total repaid with actual paid EMIs
      final Map<String, List<LoanEmi>> emisByLoan = {};
      for (var emi in _emis) {
        if (emi.status == 'paid') {
          emisByLoan.putIfAbsent(emi.loanId, () => []).add(emi);
        }
      }

      _loans = _loans.map((loan) {
        final paidEmis = emisByLoan[loan.id] ?? [];
        if (paidEmis.isNotEmpty) {
          final principalPaid = paidEmis.fold(0.0, (s, e) => s + e.principal);
          final totalPaid = paidEmis.fold(0.0, (s, e) => s + (e.paidAmount > 0 ? e.paidAmount : (e.principal + e.interest)));
          final realOutstanding = math.max(0.0, loan.approvedAmount - principalPaid);
          final isClosed = realOutstanding <= 0.01;

          if ((loan.outstandingPrincipal - realOutstanding).abs() > 0.01 ||
              (loan.totalRepaid - totalPaid).abs() > 0.01) {
            _service.reconcileLoanBalance(
              loanId: loan.id,
              outstandingPrincipal: realOutstanding,
              totalRepaid: totalPaid,
              status: isClosed ? 'closed' : loan.status,
            );
            return loan.copyWith(
              outstandingPrincipal: realOutstanding,
              totalRepaid: totalPaid,
              status: isClosed ? 'closed' : loan.status,
            );
          }
        }
        return loan;
      }).toList();

      // Load group loan settings (interest rate, overdue days, late fee %)
      try {
        _loanSettings = await _service.fetchLoanSettings(groupId);
      } catch (lse) {
        debugPrint('Loan settings fetch warning: $lse');
      }

      if (_selectedLoan != null) {
        final refreshed = _loans.firstWhere((l) => l.id == _selectedLoan!.id, orElse: () => _selectedLoan!);
        _selectedLoan = refreshed;
        await loadEmisForLoan(refreshed.id);
      }
    } catch (e) {
      debugPrint('Error in LoanProvider.fetchLoans: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // LOAD LOAN SETTINGS EXPLICITLY
  Future<void> loadLoanSettings(String groupId) async {
    try {
      _loanSettings = await _service.fetchLoanSettings(groupId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error in LoanProvider.loadLoanSettings: $e');
    }
  }

  // UPDATE LOAN SETTINGS
  Future<bool> updateLoanSettings(String groupId, LoanSettings newSettings) async {
    try {
      final ok = await _service.saveLoanSettings(groupId, newSettings);
      if (ok) {
        _loanSettings = newSettings;
        notifyListeners();
      }
      return ok;
    } catch (e) {
      debugPrint('Error in LoanProvider.updateLoanSettings: $e');
      return false;
    }
  }

  // 2. LOAD EMIS FOR SPECIFIC LOAN (Supports Dynamic In-Memory Virtual Schedule)
  Future<void> loadEmisForLoan(String loanId) async {
    _isLoadingEmis = true;
    notifyListeners();

    try {
      Loan? matchedLoan;
      try {
        matchedLoan = _loans.firstWhere((l) => l.id == loanId);
      } catch (_) {
        matchedLoan = _selectedLoan;
      }
      _selectedLoanEmis = await _service.fetchEmisForLoan(loanId, matchedLoan);
    } catch (e) {
      debugPrint('Error loading EMIs for loan: $e');
    } finally {
      _isLoadingEmis = false;
      notifyListeners();
    }
  }

  // 3. DISBURSE NEW LOAN
  Future<Loan?> disburseLoan({
    required String groupId,
    required Member member,
    required double amount,
    required double interestRateAnnual,
    required int periodMonths,
    required String purpose,
    String? guarantor1Id,
    String? guarantor2Id,
    required String disbursementDate,
    required String paymentMode,
    String? bankAccountId,
    String interestType = 'flat',
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final loan = await _service.disburseLoan(
        groupId: groupId,
        member: member,
        amount: amount,
        interestRateAnnual: interestRateAnnual,
        periodMonths: periodMonths,
        purpose: purpose,
        guarantor1Id: guarantor1Id,
        guarantor2Id: guarantor2Id,
        disbursementDate: disbursementDate,
        paymentMode: paymentMode,
        bankAccountId: bankAccountId,
        interestType: interestType,
      );

      if (loan != null) {
        _loans.removeWhere((l) => l.id == loan.id);
        _loans.insert(0, loan);
        _selectedLoan = loan;
        notifyListeners();

        // Background reload to sync related EMIs and references
        await fetchLoans(groupId, [member]);
        selectLoan(loan);
      }
      return loan;
    } catch (e) {
      debugPrint('Error disbursing loan in provider: $e');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 4. RECORD EMI PAYMENT
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
    _isLoading = true;
    notifyListeners();

    try {
      final success = await _service.recordEmiPayment(
        groupId: groupId,
        loanId: loanId,
        emiId: emiId,
        emiNumber: emiNumber,
        principalPaid: principalPaid,
        interestPaid: interestPaid,
        lateFee: lateFee,
        totalPaid: totalPaid,
        paymentMode: paymentMode,
        bankAccountId: bankAccountId,
        transactionId: transactionId,
        paymentDate: paymentDate,
        collectedBy: collectedBy,
        borrowerName: borrowerName,
        loanCode: loanCode,
        remarks: remarks,
      );

      if (success) {
        // 0ms Optimistic UI update for Tab 3 (repayment history)
        final newEmi = LoanEmi(
          id: emiId.startsWith('virtual') ? 'paid-$loanId-$emiNumber' : emiId,
          loanId: loanId,
          emiNumber: emiNumber,
          dueDate: paymentDate,
          paymentDate: paymentDate,
          principal: principalPaid,
          interest: interestPaid,
          lateFee: lateFee,
          emiAmount: totalPaid,
          paidAmount: totalPaid,
          balance: 0.0,
          status: 'paid',
          paymentMode: paymentMode,
          remarks: remarks ?? 'हप्ता क्र. $emiNumber भरणा केला',
        );
        _emis.removeWhere((e) => e.loanId == loanId && e.emiNumber == emiNumber);
        _emis.insert(0, newEmi);

        await fetchLoans(groupId);
        if (_selectedLoan != null && _selectedLoan!.id == loanId) {
          await loadEmisForLoan(loanId);
        }
      }
      return success;
    } catch (e) {
      debugPrint('Error paying EMI in provider: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 4a. DELETE EMI PAYMENT (हप्ता नोंद डिलीट व शिल्लक पूर्ववत)
  Future<bool> deleteEmi({
    required String groupId,
    required String loanId,
    required String emiId,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final success = await _service.deleteEmiPayment(
        groupId: groupId,
        loanId: loanId,
        emiId: emiId,
      );

      if (success) {
        _emis.removeWhere((e) => e.id == emiId);
        await fetchLoans(groupId);
        await loadEmisForLoan(loanId);
      }
      return success;
    } catch (e) {
      debugPrint('Error deleting EMI in provider: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 4a-2. UPDATE EMI PAYMENT (हप्ता नोंद दुरुस्त)
  Future<bool> updateEmi({
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
    _isLoading = true;
    notifyListeners();

    try {
      final success = await _service.updateEmiPayment(
        groupId: groupId,
        loanId: loanId,
        emiId: emiId,
        newPrincipal: newPrincipal,
        newInterest: newInterest,
        newLateFee: newLateFee,
        newTotalPaid: newTotalPaid,
        paymentMode: paymentMode,
        bankAccountId: bankAccountId,
        transactionId: transactionId,
        paymentDate: paymentDate,
        collectedBy: collectedBy,
        remarks: remarks,
      );

      if (success) {
        await fetchLoans(groupId);
        await loadEmisForLoan(loanId);
      }
      return success;
    } catch (e) {
      debugPrint('Error updating EMI in provider: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 4b. COLLECT LOAN EMI WITH DYNAMIC PROFIT ACCRUAL
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
    _isLoading = true;
    notifyListeners();

    try {
      final success = await _service.collectLoanEmiWithProfit(
        groupId: groupId,
        loanId: loanId,
        memberId: memberId,
        memberName: memberName,
        loanCode: loanCode,
        paymentDate: paymentDate,
        collectionAmount: collectionAmount,
        interest: interest,
        overdueAmount: overdueAmount,
        reducePrincipal: reducePrincipal,
        newOutstandingPrincipal: newOutstandingPrincipal,
        overdueDays: overdueDays,
        paymentMode: paymentMode,
        bankAccountId: bankAccountId,
        transactionId: transactionId,
        collectedBy: collectedBy,
        remarks: remarks,
      );

      if (success) {
        final newEmi = LoanEmi(
          id: 'paid-$loanId-${DateTime.now().millisecondsSinceEpoch}',
          loanId: loanId,
          emiNumber: _emis.where((e) => e.loanId == loanId && e.status == 'paid').length + 1,
          dueDate: paymentDate,
          paymentDate: paymentDate,
          principal: reducePrincipal,
          interest: interest,
          lateFee: overdueAmount,
          emiAmount: collectionAmount,
          paidAmount: collectionAmount,
          balance: 0.0,
          status: 'paid',
          paymentMode: paymentMode,
          remarks: remarks ?? 'हप्ता भरणा केला',
        );
        _emis.insert(0, newEmi);

        await fetchLoans(groupId);
        await loadEmisForLoan(loanId);
      }
      return success;
    } catch (e) {
      debugPrint('Error in LoanProvider.collectLoanEmiWithProfit: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 5. PRE-CLOSE LOAN (FULL SETTLEMENT)
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
    _isLoading = true;
    notifyListeners();

    try {
      final success = await _service.precloseLoan(
        groupId: groupId,
        loanId: loanId,
        loanCode: loanCode,
        borrowerName: borrowerName,
        settlementAmount: settlementAmount,
        paymentMode: paymentMode,
        bankAccountId: bankAccountId,
        paymentDate: paymentDate,
        collectedBy: collectedBy,
      );

      if (success) {
        await fetchLoans(groupId);
        if (_selectedLoan != null && _selectedLoan!.id == loanId) {
          await loadEmisForLoan(loanId);
        }
      }
      return success;
    } catch (e) {
      debugPrint('Error preclosing loan in provider: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Legacy fallback
  Future<bool> payEmi(String emiId, double amount) async {
    final idx = _emis.indexWhere((e) => e.id == emiId);
    if (idx != -1) {
      _emis[idx] = LoanEmi(
        id: _emis[idx].id,
        loanId: _emis[idx].loanId,
        emiNumber: _emis[idx].emiNumber,
        dueDate: _emis[idx].dueDate,
        principal: _emis[idx].principal,
        interest: _emis[idx].interest,
        emiAmount: _emis[idx].emiAmount,
        paidAmount: amount,
        status: 'paid',
        paymentDate: DateTime.now().toIso8601String().split('T').first,
      );
      notifyListeners();
    }
    return true;
  }
}
