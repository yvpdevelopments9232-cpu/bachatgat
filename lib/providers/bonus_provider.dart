import 'package:flutter/material.dart';
import '../models/bonus.dart';
import '../models/bonus_setting.dart';
import '../models/member.dart';
import '../services/bonus_service.dart';

class BonusProvider extends ChangeNotifier {
  final BonusService _service = BonusService();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isCalculating = false;
  bool get isCalculating => _isCalculating;

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  List<Bonus> _bonuses = [];
  List<Bonus> get bonuses => _bonuses;

  List<Bonus> _calculatedBatch = [];
  List<Bonus> get calculatedBatch => _calculatedBatch;

  BonusSetting? _settings;
  BonusSetting? get settings => _settings;

  String _financialYear = '2025 - 2026';
  String get financialYear => _financialYear;

  String _fromDate = '2025-04-01';
  String get fromDate => _fromDate;

  String _toDate = '2026-03-31';
  String get toDate => _toDate;

  String _selectedBonusType = 'All Types';
  String get selectedBonusType => _selectedBonusType;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  // Selected for bulk approval
  final Set<String> _selectedBonusIds = {};
  Set<String> get selectedBonusIds => _selectedBonusIds;

  // Cache of member savings amounts for quick UI preview
  final Map<String, double> _memberSavingsCache = {};
  Map<String, double> get memberSavingsCache => _memberSavingsCache;

  // --- COMPUTED KPIS ---
  int get totalMembers {
    final set = _bonuses.map((b) => b.memberId).toSet();
    return set.length;
  }

  double get totalBonus =>
      _bonuses.where((b) => !b.isCancelled).fold(0.0, (sum, b) => sum + b.bonusAmount);

  double get paidBonus =>
      _bonuses.where((b) => b.isPaid).fold(0.0, (sum, b) => sum + b.paidAmount);

  double get pendingBonus =>
      _bonuses.where((b) => b.isPending).fold(0.0, (sum, b) => sum + b.balanceAmount);

  List<Bonus> get filteredBonuses {
    var list = List<Bonus>.from(_bonuses);

    if (_selectedBonusType != 'All Types' && _selectedBonusType != 'सर्व' && _selectedBonusType != 'All') {
      list = list.where((b) {
        final bType = b.bonusType.toLowerCase();
        final filter = _selectedBonusType.toLowerCase();
        return bType.contains(filter) || filter.contains(bType);
      }).toList();
    }

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list.where((b) {
        final mName = (b.memberName ?? '').toLowerCase();
        return mName.contains(q);
      }).toList();
    }

    return list;
  }

  void setFinancialYear(String fy) {
    _financialYear = fy;
    final parts = fy.split('-');
    if (parts.length >= 2) {
      final y1 = int.tryParse(parts[0].trim());
      final y2 = int.tryParse(parts[1].trim());
      if (y1 != null && y2 != null) {
        _fromDate = '$y1-04-01';
        _toDate = '$y2-03-31';
      }
    }
    notifyListeners();
  }

  void setDateRange(String from, String to) {
    _fromDate = from;
    _toDate = to;
    notifyListeners();
  }

  void setBonusType(String type) {
    _selectedBonusType = type;
    notifyListeners();
  }

  void setSearchQuery(String q) {
    _searchQuery = q;
    notifyListeners();
  }

  void toggleSelectBonus(String id) {
    if (_selectedBonusIds.contains(id)) {
      _selectedBonusIds.remove(id);
    } else {
      _selectedBonusIds.add(id);
    }
    notifyListeners();
  }

  void selectAllBonuses(List<String> ids) {
    if (_selectedBonusIds.length == ids.length) {
      _selectedBonusIds.clear();
    } else {
      _selectedBonusIds.addAll(ids);
    }
    notifyListeners();
  }

  void clearSelection() {
    _selectedBonusIds.clear();
    notifyListeners();
  }

  /// Load all data for group
  Future<void> loadBonusData(String groupId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _settings = await _service.fetchBonusSettings(groupId);
      _bonuses = await _service.fetchBonuses(
        groupId,
        financialYear: _financialYear,
      );
    } catch (e) {
      debugPrint('Error loading bonus data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Auto fetch member savings directly from database (NEVER manually entered!)
  Future<double> getMemberSavings(
    String groupId,
    String memberId, {
    String? from,
    String? to,
  }) async {
    final f = from ?? _fromDate;
    final t = to ?? _toDate;
    final cacheKey = '$memberId-$f-$t';

    if (_memberSavingsCache.containsKey(cacheKey)) {
      return _memberSavingsCache[cacheKey]!;
    }

    final amt = await _service.fetchMemberSavingsAmount(
      groupId,
      memberId,
      fromDate: f,
      toDate: t,
    );

    _memberSavingsCache[cacheKey] = amt;
    notifyListeners();
    return amt;
  }

  /// Batch calculate bonuses
  Future<void> runBatchCalculation(
    String groupId, {
    required List<Member> members,
    required String bonusType,
    required double rate,
    double? fixedAmount,
    double? minEligibility,
    double? maxBonus,
  }) async {
    _isCalculating = true;
    notifyListeners();

    try {
      _calculatedBatch = await _service.calculateBonusesForGroup(
        groupId,
        members: members,
        fromDate: _fromDate,
        toDate: _toDate,
        financialYear: _financialYear,
        bonusType: bonusType,
        rate: rate,
        fixedAmount: fixedAmount,
        minEligibility: minEligibility ?? _settings?.minEligibility,
        maxBonus: maxBonus ?? _settings?.maxBonus,
      );
    } catch (e) {
      debugPrint('Error running batch calculation: $e');
    } finally {
      _isCalculating = false;
      notifyListeners();
    }
  }

  /// Save calculated batch
  Future<bool> saveCalculatedBatch(String groupId) async {
    if (_calculatedBatch.isEmpty) return false;
    _isSaving = true;
    notifyListeners();

    try {
      final success = await _service.saveCalculatedBonuses(_calculatedBatch);
      if (success) {
        _calculatedBatch.clear();
        await loadBonusData(groupId);
        return true;
      }
    } catch (e) {
      debugPrint('Error saving calculated batch: $e');
    } finally {
      _isSaving = false;
      notifyListeners();
    }
    return false;
  }

  /// Create single bonus
  Future<bool> createBonus(Bonus bonus) async {
    _isSaving = true;
    notifyListeners();

    try {
      final created = await _service.createBonus(bonus);
      if (created != null) {
        final toInsert = created.copyWith(
          memberName: bonus.memberName ?? created.memberName,
        );
        _bonuses.insert(0, toInsert);
        notifyListeners();
        await loadBonusData(bonus.groupId);
        return true;
      }
    } catch (e) {
      debugPrint('Error creating bonus: $e');
    } finally {
      _isSaving = false;
      notifyListeners();
    }
    return false;
  }

  /// Update bonus
  Future<bool> updateBonus(Bonus bonus) async {
    _isSaving = true;
    notifyListeners();

    try {
      final success = await _service.updateBonus(bonus);
      if (success) {
        final idx = _bonuses.indexWhere((b) => b.id == bonus.id);
        if (idx >= 0) {
          _bonuses[idx] = bonus;
        }
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Error updating bonus: $e');
    } finally {
      _isSaving = false;
      notifyListeners();
    }
    return false;
  }

  /// Delete bonus
  Future<bool> deleteBonus(String id, String groupId) async {
    try {
      final success = await _service.deleteBonus(id, groupId);
      if (success) {
        _bonuses.removeWhere((b) => b.id == id);
        _selectedBonusIds.remove(id);
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Error deleting bonus: $e');
    }
    return false;
  }

  /// Approve selected bonuses
  Future<bool> approveSelected(String groupId, String approvedBy) async {
    if (_selectedBonusIds.isEmpty) return false;
    _isSaving = true;
    notifyListeners();

    try {
      final success = await _service.approveBonuses(
        _selectedBonusIds.toList(),
        approvedBy,
      );
      if (success) {
        _selectedBonusIds.clear();
        await loadBonusData(groupId);
        return true;
      }
    } catch (e) {
      debugPrint('Error approving selected bonuses: $e');
    } finally {
      _isSaving = false;
      notifyListeners();
    }
    return false;
  }

  /// Reject selected bonuses
  Future<bool> rejectSelected(String groupId) async {
    if (_selectedBonusIds.isEmpty) return false;
    _isSaving = true;
    notifyListeners();

    try {
      final success = await _service.rejectBonuses(_selectedBonusIds.toList());
      if (success) {
        _selectedBonusIds.clear();
        await loadBonusData(groupId);
        return true;
      }
    } catch (e) {
      debugPrint('Error rejecting selected bonuses: $e');
    } finally {
      _isSaving = false;
      notifyListeners();
    }
    return false;
  }

  /// Pay bonus with cash/bank sync
  Future<bool> payBonus(
    Bonus bonus, {
    required String paymentMode,
    required double amount,
    String? bankAccountId,
    String? transactionRef,
    String? paymentDate,
    String? remarks,
  }) async {
    _isSaving = true;
    notifyListeners();

    try {
      final success = await _service.payBonus(
        bonus,
        paymentMode: paymentMode,
        amount: amount,
        bankAccountId: bankAccountId,
        transactionRef: transactionRef,
        paymentDate: paymentDate,
        remarks: remarks,
      );
      if (success) {
        await loadBonusData(bonus.groupId);
        return true;
      }
    } catch (e) {
      debugPrint('Error paying bonus: $e');
    } finally {
      _isSaving = false;
      notifyListeners();
    }
    return false;
  }

  /// Save bonus settings
  Future<bool> saveSettings(BonusSetting setting) async {
    _isSaving = true;
    notifyListeners();

    try {
      final success = await _service.saveBonusSetting(setting);
      if (success) {
        _settings = setting;
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Error saving settings: $e');
    } finally {
      _isSaving = false;
      notifyListeners();
    }
    return false;
  }
}
