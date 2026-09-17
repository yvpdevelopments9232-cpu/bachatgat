import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/monthly_collection.dart';
import '../models/member.dart';
import '../models/loan.dart';
import '../models/bank_account.dart';
import '../services/supabase_service.dart';
import '../services/offline_db_helper.dart';
import '../services/app_config.dart';
import '../services/sync_service.dart';

class MonthlyCollectionProvider extends ChangeNotifier {
  final SupabaseService _service = SupabaseService();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<MonthlyCollection> _collections = [];
  List<MonthlyCollection> get collections => _collections;

  // Filters
  DateTime? _fromDate;
  DateTime? _toDate;
  String? _filterMemberId; // null or empty means All Members

  DateTime? get fromDate => _fromDate;
  DateTime? get toDate => _toDate;
  String? get filterMemberId => _filterMemberId;

  // Active Entry Form State
  DateTime _entryDate = DateTime.now();
  Member? _selectedMember;
  Loan? _activeLoan;
  List<Loan> _availableMemberLoans = [];
  List<Member> _membersList = [];
  List<Loan> _loansList = [];
  List<BankAccount> _banksList = [];
  double _monthlySaving = 200.0;
  bool _isSavingPaid = true;

  // Loan breakdown state
  double _previousPrincipal = 0.0;
  double _monthlyInterest = 0.0;
  double _requiredPrincipalPortion = 0.0;
  double _requiredEmi = 0.0;
  double _paidEmi = 0.0;
  double _principalAmount = 0.0;
  double _interestAmount = 0.0;
  double _remainingPrincipal = 0.0;
  double _remainingEmi = 0.0;

  // Payment Mode & Bank Selection
  String _paymentMode = 'cash'; // 'cash' (हातातील रोख शिल्लक), 'bank' (बँक खात्यात जमा), 'online' (UPI / ऑनलाइन)
  String? _selectedBankAccountId;
  String? _selectedBankAccountName;
  String _referenceNo = '';
  String _notes = '';

  // Getters
  DateTime get entryDate => _entryDate;
  Member? get selectedMember => _selectedMember;
  Loan? get activeLoan => _activeLoan;
  List<Loan> get availableMemberLoans => _availableMemberLoans;
  List<Member> get membersList => _membersList;
  List<Loan> get loansList => _loansList;
  List<BankAccount> get banksList => _banksList;
  double get monthlySaving => _monthlySaving;
  bool get isSavingPaid => _isSavingPaid;

  double get previousPrincipal => _previousPrincipal;
  double get monthlyInterest => _monthlyInterest;
  double get requiredPrincipalPortion => _requiredPrincipalPortion;
  double get requiredEmi => _requiredEmi;
  double get paidEmi => _paidEmi;
  double get principalAmount => _principalAmount;
  double get interestAmount => _interestAmount;
  double get remainingPrincipal => _remainingPrincipal;
  double get remainingEmi => _remainingEmi;

  String get paymentMode => _paymentMode;
  String? get selectedBankAccountId => _selectedBankAccountId;
  String? get selectedBankAccountName => _selectedBankAccountName;
  String get referenceNo => _referenceNo;
  String get notes => _notes;

  // Live total calculation: Saving (if checked) + Paid EMI
  // Accounting rule: NEVER double count principal & interest with EMI!
  double get calculatedTotal => (_isSavingPaid ? _monthlySaving : 0.0) + _paidEmi;

  // Overview Metrics based on filtered list
  List<MonthlyCollection> get filteredCollections {
    return _collections.where((c) {
      if (_filterMemberId != null &&
          _filterMemberId!.isNotEmpty &&
          _filterMemberId != 'all') {
        if (c.memberId != _filterMemberId) return false;
      }
      if (_fromDate != null) {
        final cDate = DateTime.tryParse(c.collectionDate);
        if (cDate != null &&
            cDate.isBefore(DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day))) {
          return false;
        }
      }
      if (_toDate != null) {
        final cDate = DateTime.tryParse(c.collectionDate);
        if (cDate != null &&
            cDate.isAfter(DateTime(_toDate!.year, _toDate!.month, _toDate!.day, 23, 59, 59))) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  double get totalMonthlySaving {
    if (filteredCollections.isNotEmpty) {
      return filteredCollections.fold(0.0, (sum, item) => sum + item.monthlySaving);
    }
    // Dynamic fallback when collection history is empty:
    // If viewing a specific member, display their monthly saving amount!
    if (_selectedMember != null) {
      return _monthlySaving;
    }
    // If viewing all members, display sum of expected monthly savings
    if (_membersList.isNotEmpty) {
      return _membersList.length * _monthlySaving;
    }
    return 0.0;
  }

  double get totalLoanPrincipal {
    if (filteredCollections.isNotEmpty) {
      return filteredCollections.fold(0.0, (sum, item) => sum + item.principalAmount);
    }
    // Dynamic fallback:
    // If viewing a specific member, display their active loan outstanding principal!
    if (_selectedMember != null) {
      return _previousPrincipal > 0
          ? _previousPrincipal
          : (_activeLoan?.outstandingPrincipal ?? 0.0);
    }
    // If viewing all members, sum all active loan principals in group
    if (_loansList.isNotEmpty) {
      return _loansList
          .where((l) => l.isActive)
          .fold(0.0, (sum, l) => sum + l.outstandingPrincipal);
    }
    return 0.0;
  }

  double get totalInterest {
    if (filteredCollections.isNotEmpty) {
      return filteredCollections.fold(0.0, (sum, item) => sum + item.interestAmount);
    }
    // Dynamic fallback:
    // If viewing a specific member, display their calculated active loan monthly interest!
    if (_selectedMember != null) {
      return _monthlyInterest;
    }
    // If viewing all members, sum active loan monthly interests in group
    if (_loansList.isNotEmpty) {
      return _loansList.where((l) => l.isActive).fold(0.0, (sum, l) {
        final rate = l.interestRate > 0 ? l.interestRate : 12.0;
        final monthlyRate = (rate / 100.0) / 12.0;
        return sum + (l.outstandingPrincipal * monthlyRate).roundToDouble();
      });
    }
    return 0.0;
  }

  double get totalEmiPaid {
    if (filteredCollections.isNotEmpty) {
      return filteredCollections.fold(0.0, (sum, item) => sum + item.paidEmi);
    }
    // Dynamic fallback:
    // If viewing a specific member, display their expected EMI amount!
    if (_selectedMember != null) {
      return _paidEmi > 0 ? _paidEmi : _requiredEmi;
    }
    // If viewing all members, sum active loan EMIs
    if (_loansList.isNotEmpty) {
      return _loansList.where((l) => l.isActive).fold(0.0, (sum, l) => sum + l.emiAmount);
    }
    return 0.0;
  }

  double get totalCollection {
    if (filteredCollections.isNotEmpty) {
      return filteredCollections.fold(0.0, (sum, item) => sum + item.totalCollection);
    }
    return totalMonthlySaving + totalEmiPaid;
  }

  // Filter setters
  void setDateFilter(DateTime? from, DateTime? to) {
    _fromDate = from;
    _toDate = to;
    notifyListeners();
  }

  void setFilterMember(String? memberId) {
    _filterMemberId = (memberId == null || memberId == 'all') ? null : memberId;
    notifyListeners();
  }

  void clearFilters() {
    _fromDate = null;
    _toDate = null;
    _filterMemberId = null;
    notifyListeners();
  }

  // Form manipulation methods
  void setEntryDate(DateTime date) {
    _entryDate = date;
    notifyListeners();
  }

  void onMemberChanged(Member? member, List<Loan> loansList, double defaultGroupSaving) {
    _selectedMember = member;
    if (loansList.isNotEmpty) {
      _loansList = loansList;
    }

    if (member == null) {
      _activeLoan = null;
      _availableMemberLoans = [];
      _previousPrincipal = 0.0;
      _monthlyInterest = 0.0;
      _requiredPrincipalPortion = 0.0;
      _requiredEmi = 0.0;
      _paidEmi = 0.0;
      _principalAmount = 0.0;
      _interestAmount = 0.0;
      _remainingPrincipal = 0.0;
      _remainingEmi = 0.0;
      _monthlySaving = defaultGroupSaving > 0 ? defaultGroupSaving : 200.0;
      notifyListeners();
      return;
    }

    _monthlySaving = defaultGroupSaving > 0 ? defaultGroupSaving : 200.0;
    _isSavingPaid = true;

    // Find active loans for this member from passed list or stored provider list
    final sourceLoans = loansList.isNotEmpty ? loansList : _loansList;
    _availableMemberLoans = sourceLoans.where((l) => l.memberId == member.id && l.isActive).toList();

    if (_availableMemberLoans.isNotEmpty) {
      selectActiveLoan(_availableMemberLoans.first);
    } else {
      // Async fallback to SQLite in case memory loans list wasn't populated yet
      _activeLoan = null;
      _previousPrincipal = 0.0;
      _monthlyInterest = 0.0;
      _requiredPrincipalPortion = 0.0;
      _requiredEmi = 0.0;
      _paidEmi = 0.0;
      _principalAmount = 0.0;
      _interestAmount = 0.0;
      _remainingPrincipal = 0.0;
      _remainingEmi = 0.0;
      notifyListeners();

      _loadMemberLoansFromDb(member.id, defaultGroupSaving);
    }
  }

  void selectActiveLoan(Loan loan) {
    _activeLoan = loan;
    _previousPrincipal = (loan.outstandingPrincipal > 0 || loan.totalRepaid > 0)
        ? loan.outstandingPrincipal
        : loan.approvedAmount;

    // Calculate monthly interest based on annual rate
    final rate = loan.interestRate > 0 ? loan.interestRate : 12.0;
    final monthlyRate = (rate / 100.0) / 12.0;
    _monthlyInterest = (_previousPrincipal * monthlyRate).roundToDouble();

    // Required EMI from loan or calculated
    if (loan.emiAmount > 0) {
      _requiredEmi = loan.emiAmount;
    } else {
      final tenure = max(1, loan.loanPeriodMonths > 0 ? loan.loanPeriodMonths : 12);
      _requiredEmi = (_previousPrincipal / tenure + _monthlyInterest).roundToDouble();
    }

    _requiredPrincipalPortion = max(0.0, _requiredEmi - _monthlyInterest);

    // Default paid EMI to full required EMI
    _paidEmi = _requiredEmi;
    _recalculateBreakdown();
    notifyListeners();
  }

  Future<void> _loadMemberLoansFromDb(String memberId, double defaultGroupSaving) async {
    try {
      final db = await OfflineDbHelper.instance.database;
      final rows = await db.query(
        'loans',
        where: "member_id = ? AND status IN ('active', 'disbursed', 'approved')",
        whereArgs: [memberId],
      );
      if (rows.isNotEmpty) {
        _availableMemberLoans = rows.map((r) => Loan.fromJson(r)).toList();
        if (_availableMemberLoans.isNotEmpty && _selectedMember?.id == memberId) {
          selectActiveLoan(_availableMemberLoans.first);
        }
      }
    } catch (e) {
      debugPrint('Error looking up member loans: $e');
    }
  }

  void setIsSavingPaid(bool value) {
    _isSavingPaid = value;
    notifyListeners();
  }

  void setMonthlySaving(double value) {
    _monthlySaving = max(0.0, value);
    notifyListeners();
  }

  void setPaidEmi(double value) {
    _paidEmi = max(0.0, value);
    _recalculateBreakdown();
    notifyListeners();
  }

  void setPaymentMode(String mode) {
    _paymentMode = mode;
    if ((mode == 'bank' || mode == 'online') && (_selectedBankAccountId == null || _selectedBankAccountId!.isEmpty) && _banksList.isNotEmpty) {
      final primary = _banksList.firstWhere((b) => b.isPrimary == 1, orElse: () => _banksList.first);
      _selectedBankAccountId = primary.id;
      _selectedBankAccountName = '${primary.bankName} (${primary.maskedAccountNumber})';
    }
    notifyListeners();
  }

  void setSelectedBankAccount(String? bankId, String? bankName) {
    _selectedBankAccountId = bankId;
    _selectedBankAccountName = bankName;
    notifyListeners();
  }

  void setReferenceNo(String ref) {
    _referenceNo = ref;
    notifyListeners();
  }

  void setNotes(String val) {
    _notes = val;
    notifyListeners();
  }

  void _recalculateBreakdown() {
    _remainingEmi = max(0.0, _requiredEmi - _paidEmi);
    if (_activeLoan != null && _previousPrincipal > 0) {
      if (_paidEmi <= 0) {
        _interestAmount = 0.0;
        _principalAmount = 0.0;
        _remainingPrincipal = _previousPrincipal;
      } else if (_paidEmi <= _monthlyInterest) {
        _interestAmount = _paidEmi;
        _principalAmount = 0.0;
        _remainingPrincipal = _previousPrincipal;
      } else {
        _interestAmount = _monthlyInterest;
        _principalAmount = _paidEmi - _monthlyInterest;
        _remainingPrincipal = max(0.0, _previousPrincipal - _principalAmount);
      }
    } else {
      _principalAmount = 0.0;
      _interestAmount = 0.0;
      _remainingPrincipal = 0.0;
    }
  }

  void resetForm(double defaultGroupSaving) {
    _entryDate = DateTime.now();
    _selectedMember = null;
    _activeLoan = null;
    _previousPrincipal = 0.0;
    _monthlyInterest = 0.0;
    _requiredPrincipalPortion = 0.0;
    _monthlySaving = defaultGroupSaving > 0 ? defaultGroupSaving : 200.0;
    _isSavingPaid = true;
    _requiredEmi = 0.0;
    _paidEmi = 0.0;
    _principalAmount = 0.0;
    _interestAmount = 0.0;
    _remainingPrincipal = 0.0;
    _remainingEmi = 0.0;
    _paymentMode = 'cash';
    _selectedBankAccountId = null;
    _selectedBankAccountName = null;
    _referenceNo = '';
    _notes = '';
    notifyListeners();
  }

  // Load collections with member, loan & bank details
  Future<void> fetchCollections({
    required String groupId,
    List<Member> membersList = const [],
    List<Loan> loansList = const [],
    List<BankAccount> banksList = const [],
  }) async {
    if (groupId.isEmpty) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      List<Map<String, dynamic>> rawData = [];

      final db = await OfflineDbHelper.instance.database;

      // Ensure memberMap has all members
      final Map<String, Member> memberMap = {for (var m in membersList) m.id: m};
      if (memberMap.isEmpty) {
        final mRows = await db.query('members', where: 'group_id = ?', whereArgs: [groupId]);
        for (var r in mRows) {
          final m = Member.fromJson(r);
          memberMap[m.id] = m;
        }
      }

      // Ensure loanMap has all loans
      final Map<String, Loan> loanMap = {for (var l in loansList) l.id: l};
      if (loanMap.isEmpty) {
        final lRows = await db.query('loans', where: 'group_id = ?', whereArgs: [groupId]);
        for (var r in lRows) {
          final l = Loan.fromJson(r);
          loanMap[l.id] = l;
        }
      }

      // Ensure bankMap has all banks
      final Map<String, BankAccount> bankMap = {for (var b in banksList) b.id: b};
      if (bankMap.isEmpty) {
        final bRows = await db.query('bank_accounts', where: 'group_id = ?', whereArgs: [groupId]);
        for (var r in bRows) {
          final b = BankAccount.fromJson(r);
          bankMap[b.id] = b;
        }
      }

      _membersList = memberMap.values.toList();
      _loansList = loanMap.values.toList();
      _banksList = bankMap.values.toList();

      if (AppConfig.isOfflineMode) {
        rawData = await db.query(
          'monthly_collections',
          where: 'group_id = ?',
          whereArgs: [groupId],
          orderBy: 'collection_date DESC, created_at DESC',
        );
      } else {
        try {
          final res = await _service.client
              .from('monthly_collections')
              .select('*, members(id, full_name, member_code), loans(id, loan_code), bank_accounts(id, bank_name, account_number)')
              .eq('group_id', groupId)
              .order('collection_date', ascending: false);
          rawData = List<Map<String, dynamic>>.from(res as List);
        } catch (e) {
          debugPrint('Supabase fetch failed, falling back to local: $e');
          rawData = await db.query(
            'monthly_collections',
            where: 'group_id = ?',
            whereArgs: [groupId],
            orderBy: 'collection_date DESC, created_at DESC',
          );
        }
      }

      _collections = rawData.map((map) {
        final col = MonthlyCollection.fromMap(map);
        final mem = memberMap[col.memberId];
        final loan = col.loanId != null ? loanMap[col.loanId] : null;
        final bank = col.bankAccountId != null ? bankMap[col.bankAccountId] : null;

        return col.copyWith(
          memberName: col.memberName ?? mem?.fullName ?? 'सभासद',
          memberCode: col.memberCode ?? mem?.memberCode ?? '-',
          loanNumber: col.loanNumber ?? loan?.loanCode ?? '-',
          bankAccountName: col.bankAccountName ?? (bank != null ? '${bank.bankName} (${bank.maskedAccountNumber})' : null),
        );
      }).toList();
    } catch (e) {
      _errorMessage = 'Error loading monthly collections: $e';
      debugPrint(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Save new Monthly Collection and update Savings, Loans, EMIs, Cash in Hand & Bank Balances!
  Future<bool> saveCurrentEntry({
    required String groupId,
    required String createdBy,
    List<Member> membersList = const [],
    List<Loan> loansList = const [],
    List<BankAccount> banksList = const [],
  }) async {
    if (_selectedMember == null) {
      _errorMessage = 'कृपया सदस्य निवडा / Please select a member';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final nowStr = DateTime.now().toIso8601String();
      final dateStr = _entryDate.toIso8601String().split('T').first;
      final id = OfflineDbHelper.generateId();

      final savingAmount = _isSavingPaid ? _monthlySaving : 0.0;
      final total = savingAmount + _paidEmi;

      final newRecord = MonthlyCollection(
        id: id,
        groupId: groupId,
        memberId: _selectedMember!.id,
        loanId: _activeLoan?.id,
        bankAccountId: (_paymentMode == 'bank' || _paymentMode == 'online') ? _selectedBankAccountId : null,
        collectionDate: dateStr,
        monthlySaving: savingAmount,
        requiredEmi: _requiredEmi,
        paidEmi: _paidEmi,
        principalAmount: _principalAmount,
        interestAmount: _interestAmount,
        remainingEmi: _remainingEmi,
        totalCollection: total,
        paymentStatus: _remainingEmi > 0 && _paidEmi > 0
            ? 'partial'
            : (_paidEmi == 0 && _requiredEmi > 0 ? 'pending' : 'paid'),
        paymentMode: _paymentMode,
        referenceNo: _referenceNo.isNotEmpty ? _referenceNo : null,
        notes: _notes.isNotEmpty ? _notes : null,
        createdBy: createdBy,
        createdAt: nowStr,
        updatedAt: nowStr,
        memberName: _selectedMember!.fullName,
        memberCode: _selectedMember!.memberCode,
        loanNumber: _activeLoan?.loanCode,
        bankAccountName: _selectedBankAccountName,
      );

      final rowData = newRecord.toMap();
      final db = await OfflineDbHelper.instance.database;

      // 1. Insert into monthly_collections
      await db.insert('monthly_collections', rowData);

      // 2. If savings paid, record in savings table so dashboard savings update immediately!
      if (savingAmount > 0) {
        final savingId = OfflineDbHelper.generateId();
        final savingData = {
          'id': savingId,
          'group_id': groupId,
          'member_id': _selectedMember!.id,
          'savings_date': dateStr,
          'amount': savingAmount,
          'savings_type': 'regular',
          'payment_mode': _paymentMode,
          'receipt_number': _referenceNo.isNotEmpty ? _referenceNo : 'MC-$id',
          'transaction_number': _referenceNo.isNotEmpty ? _referenceNo : null,
          'reference_number': _referenceNo.isNotEmpty ? _referenceNo : 'MC-$id',
          'collected_by': createdBy,
          'remarks': 'मासिक संकलन बचत नोंद',
          'created_by': createdBy,
          'created_at': nowStr,
          'updated_at': nowStr,
        };
        await db.insert('savings', savingData);
        if (!AppConfig.isOfflineOnly) {
          await OfflineDbHelper.instance.enqueueSync(
            tableName: 'savings',
            rowId: savingId,
            action: 'INSERT',
            payload: jsonEncode(savingData),
          );
        }
        if (AppConfig.isOnlineMode) {
          try {
            await _service.client.from('savings').insert(
              SyncService.formatRowForSupabase('savings', savingData),
            );
          } catch (e) {
            debugPrint('Cloud savings direct insert error: $e');
          }
        }
      }

      // 3. If loan EMI paid, update loans table and insert into loan_emis!
      if (_activeLoan != null && _paidEmi > 0) {
        final newOutstanding = max(0.0, _activeLoan!.outstandingPrincipal - _principalAmount);
        final newRepaid = _activeLoan!.totalRepaid + _paidEmi;
        final newStatus = newOutstanding <= 0.01 ? 'closed' : 'active';

        final loanUpdateData = {
          'outstanding_principal': newOutstanding,
          'total_repaid': newRepaid,
          'status': newStatus,
          'updated_at': nowStr,
        };
        await db.update('loans', loanUpdateData, where: 'id = ?', whereArgs: [_activeLoan!.id]);

        final existingEmis = await db.query('loan_emis', where: 'loan_id = ?', whereArgs: [_activeLoan!.id]);
        final nextEmiNum = existingEmis.length + 1;

        final emiId = OfflineDbHelper.generateId();
        final emiData = {
          'id': emiId,
          'group_id': groupId,
          'loan_id': _activeLoan!.id,
          'emi_number': nextEmiNum,
          'due_date': dateStr,
          'payment_date': dateStr,
          'emi_amount': _requiredEmi,
          'principal': _principalAmount,
          'interest': _interestAmount,
          'paid_amount': _paidEmi,
          'status': 'paid',
          'payment_mode': _paymentMode,
          'receipt_number': _referenceNo.isNotEmpty ? _referenceNo : 'MC-EMI-$id',
          'transaction_id': _referenceNo.isNotEmpty ? _referenceNo : null,
          'collected_by': createdBy,
          'remarks': 'मासिक संकलन हप्ता जमा (शिल्लक मुद्दल: ₹${newOutstanding.toStringAsFixed(2)})',
          'created_at': nowStr,
          'updated_at': nowStr,
        };
        await db.insert('loan_emis', emiData);

        if (!AppConfig.isOfflineOnly) {
          await OfflineDbHelper.instance.enqueueSync(
            tableName: 'loans',
            rowId: _activeLoan!.id,
            action: 'UPDATE',
            payload: jsonEncode(loanUpdateData),
          );
          await OfflineDbHelper.instance.enqueueSync(
            tableName: 'loan_emis',
            rowId: emiId,
            action: 'INSERT',
            payload: jsonEncode(emiData),
          );
        }
        if (AppConfig.isOnlineMode) {
          try {
            await _service.client.from('loans').update(
              SyncService.formatRowForSupabase('loans', loanUpdateData),
            ).eq('id', _activeLoan!.id);

            await _service.client.from('loan_emis').insert(
              SyncService.formatRowForSupabase('loan_emis', emiData),
            );
          } catch (e) {
            debugPrint('Cloud loans/emis direct update error: $e');
          }
        }

        // Update in-memory loans list and active loan so reset/re-selection reflects updated principal immediately!
        final updatedLoan = _activeLoan!.copyWith(
          outstandingPrincipal: newOutstanding,
          totalRepaid: newRepaid,
          status: newStatus,
        );
        _activeLoan = updatedLoan;
        final loanIdx = _loansList.indexWhere((l) => l.id == updatedLoan.id);
        if (loanIdx != -1) {
          _loansList[loanIdx] = updatedLoan;
        }
        final availIdx = _availableMemberLoans.indexWhere((l) => l.id == updatedLoan.id);
        if (availIdx != -1) {
          _availableMemberLoans[availIdx] = updatedLoan;
        }
      }

      // 4. Update Cash in Hand or Bank Account!
      if (_paymentMode == 'cash') {
        // Record in cash_book
        final lastCash = await db.rawQuery(
          'SELECT balance_after FROM cash_book WHERE group_id = ? ORDER BY entry_date DESC, created_at DESC, id DESC LIMIT 1',
          [groupId],
        );
        final prevCash = lastCash.isNotEmpty ? ((lastCash.first['balance_after'] as num?)?.toDouble() ?? 0.0) : 0.0;
        final newCashBal = prevCash + total;

        final cashBookId = OfflineDbHelper.generateId();
        final cashData = {
          'id': cashBookId,
          'group_id': groupId,
          'entry_date': dateStr,
          'type': 'receipt',
          'amount': total,
          'balance_after': newCashBal,
          'description': 'मासिक संकलन - ${_selectedMember!.fullName}',
          'reference_module': 'monthly_collections',
          'reference_id': id,
          'entered_by': createdBy,
          'created_at': nowStr,
        };
        await db.insert('cash_book', cashData);
        if (!AppConfig.isOfflineOnly) {
          await OfflineDbHelper.instance.enqueueSync(
            tableName: 'cash_book',
            rowId: cashBookId,
            action: 'INSERT',
            payload: jsonEncode(cashData),
          );
        }
        if (AppConfig.isOnlineMode) {
          try {
            await _service.client.from('cash_book').insert(
              SyncService.formatRowForSupabase('cash_book', cashData),
            );
          } catch (e) {
            debugPrint('Cloud cash_book direct insert error: $e');
          }
        }
      } else if (_paymentMode == 'bank' || _paymentMode == 'online') {
        // Resolve target bank account: use selected or fallback to primary/first bank
        String? targetBankId = _selectedBankAccountId;
        if (targetBankId == null || targetBankId.isEmpty) {
          if (banksList.isNotEmpty) {
            final p = banksList.firstWhere((b) => b.isPrimary == 1, orElse: () => banksList.first);
            targetBankId = p.id;
          } else {
            final q = await db.query('bank_accounts', where: 'group_id = ?', whereArgs: [groupId], limit: 1);
            if (q.isNotEmpty) {
              targetBankId = q.first['id']?.toString();
            }
          }
        }

        if (targetBankId != null && targetBankId.isNotEmpty) {
          final bRows = await db.query('bank_accounts', where: 'id = ?', whereArgs: [targetBankId]);
          if (bRows.isNotEmpty) {
            final curBal = (bRows.first['current_balance'] as num?)?.toDouble() ?? 0.0;
            final newBal = curBal + total;
            await db.update('bank_accounts', {'current_balance': newBal, 'updated_at': nowStr},
                where: 'id = ?', whereArgs: [targetBankId]);

            // Update in-memory bank list so UI updates immediately
            final bIdx = _banksList.indexWhere((b) => b.id == targetBankId);
            if (bIdx != -1) {
              _banksList[bIdx] = _banksList[bIdx].copyWith(currentBalance: newBal);
            }

            // Insert into bank_transactions
            final txId = OfflineDbHelper.generateId();
            final txData = {
              'id': txId,
              'group_id': groupId,
              'bank_account_id': targetBankId,
              'transaction_date': dateStr,
              'type': 'deposit',
              'amount': total,
              'purpose': 'मासिक संकलन जमा',
              'remarks': 'मासिक संकलन - ${_selectedMember!.fullName}',
              'balance_after': newBal,
              'transaction_number': _referenceNo.isNotEmpty ? _referenceNo : 'MC-$id',
              'deposit_slip_or_cheque_no': _referenceNo.isNotEmpty ? _referenceNo : null,
              'performed_by': createdBy,
              'created_by': createdBy,
              'created_at': nowStr,
            };
            await db.insert('bank_transactions', txData);

            if (!AppConfig.isOfflineOnly) {
              await OfflineDbHelper.instance.enqueueSync(
                tableName: 'bank_accounts',
                rowId: targetBankId,
                action: 'UPDATE',
                payload: jsonEncode({'id': targetBankId, 'current_balance': newBal}),
              );
              await OfflineDbHelper.instance.enqueueSync(
                tableName: 'bank_transactions',
                rowId: txId,
                action: 'INSERT',
                payload: jsonEncode(txData),
              );
            }

            if (AppConfig.isOnlineMode) {
              try {
                await _service.client.from('bank_accounts').update({
                  'current_balance': newBal,
                  'updated_at': nowStr,
                }).eq('id', targetBankId);

                await _service.client.from('bank_transactions').insert({
                  'id': txId,
                  'group_id': groupId,
                  'bank_account_id': targetBankId,
                  'transaction_date': dateStr,
                  'type': 'deposit',
                  'amount': total,
                  'balance_after': newBal,
                  'payment_mode': _paymentMode == 'online' ? 'upi' : 'bank_transfer',
                  'reference_number': _referenceNo.isNotEmpty ? _referenceNo : 'MC-$id',
                  'description': 'मासिक संकलन - ${_selectedMember!.fullName}',
                  'performed_by': createdBy,
                  'created_at': nowStr,
                });
              } catch (e) {
                debugPrint('Cloud bank direct update error: $e');
              }
            }
          }
        }
      }

      // Sync monthly_collections row
      if (!AppConfig.isOfflineOnly) {
        try {
          if (!AppConfig.isOfflineMode) {
            await _service.client.from('monthly_collections').insert(rowData);
          } else {
            await OfflineDbHelper.instance.enqueueSync(
              tableName: 'monthly_collections',
              rowId: id,
              action: 'INSERT',
              payload: jsonEncode(rowData),
            );
          }
        } catch (e) {
          debugPrint('Could not insert directly to Supabase, queuing for sync: $e');
          await OfflineDbHelper.instance.enqueueSync(
            tableName: 'monthly_collections',
            rowId: id,
            action: 'INSERT',
            payload: jsonEncode(rowData),
          );
        }
        SyncService.instance.triggerSync();
      }

      _collections.insert(0, newRecord);
      resetForm(_monthlySaving);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to save collection: $e';
      debugPrint(_errorMessage);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update existing Monthly Collection
  Future<bool> updateCollection(MonthlyCollection updated) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final nowStr = DateTime.now().toIso8601String();
      final rowData = updated.copyWith(updatedAt: nowStr).toMap();

      final db = await OfflineDbHelper.instance.database;
      await db.update(
        'monthly_collections',
        rowData,
        where: 'id = ?',
        whereArgs: [updated.id],
      );

      if (!AppConfig.isOfflineOnly) {
        try {
          if (!AppConfig.isOfflineMode) {
            await _service.client
                .from('monthly_collections')
                .update(rowData)
                .eq('id', updated.id);
          } else {
            await OfflineDbHelper.instance.enqueueSync(
              tableName: 'monthly_collections',
              rowId: updated.id,
              action: 'UPDATE',
              payload: jsonEncode(rowData),
            );
          }
        } catch (e) {
          debugPrint('Update directly failed, queuing: $e');
          await OfflineDbHelper.instance.enqueueSync(
            tableName: 'monthly_collections',
            rowId: updated.id,
            action: 'UPDATE',
            payload: jsonEncode(rowData),
          );
          SyncService.instance.triggerSync();
        }
      }

      final index = _collections.indexWhere((c) => c.id == updated.id);
      if (index != -1) {
        _collections[index] = updated;
      }
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update collection: $e';
      debugPrint(_errorMessage);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Delete Monthly Collection
  Future<bool> deleteCollection(String id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final db = await OfflineDbHelper.instance.database;
      await db.delete(
        'monthly_collections',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (!AppConfig.isOfflineOnly) {
        try {
          if (!AppConfig.isOfflineMode) {
            await _service.client.from('monthly_collections').delete().eq('id', id);
          } else {
            await OfflineDbHelper.instance.enqueueSync(
              tableName: 'monthly_collections',
              rowId: id,
              action: 'DELETE',
              payload: jsonEncode({'id': id}),
            );
          }
        } catch (e) {
          debugPrint('Delete directly failed, queuing: $e');
          await OfflineDbHelper.instance.enqueueSync(
            tableName: 'monthly_collections',
            rowId: id,
            action: 'DELETE',
            payload: jsonEncode({'id': id}),
          );
          SyncService.instance.triggerSync();
        }
      }

      _collections.removeWhere((c) => c.id == id);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to delete collection: $e';
      debugPrint(_errorMessage);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
