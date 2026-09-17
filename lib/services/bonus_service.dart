import 'package:flutter/foundation.dart';
import '../models/bonus.dart';
import '../models/bonus_setting.dart';
import '../models/member.dart';
import 'offline_db_helper.dart';
import 'supabase_service.dart';

class BonusService {
  final SupabaseService _service = SupabaseService();

  /// 1. Fetch group bonus settings (or create default)
  Future<BonusSetting> fetchBonusSettings(String groupId) async {
    try {
      final res = await _service.client
          .from('bonus_settings')
          .select()
          .eq('group_id', groupId)
          .eq('is_active', 1)
          .limit(1);

      if ((res as List).isNotEmpty) {
        return BonusSetting.fromJson(res.first);
      }
    } catch (e) {
      debugPrint('Error fetching bonus settings: $e');
    }

    // Default configuration
    return BonusSetting(
      id: OfflineDbHelper.generateId(),
      groupId: groupId,
      settingName: 'बचत लाभांश व बोनस (Savings Bonus)',
      bonusType: 'percentage_of_savings',
      calculationMethod: 'percentage',
      bonusPercentage: 5.0,
      fixedAmount: 0.0,
      minEligibility: 0.0,
      maxBonus: 5000.0,
    );
  }

  /// Save or update bonus settings
  Future<bool> saveBonusSetting(BonusSetting setting) async {
    try {
      final data = setting.toJson();
      final res = await _service.client
          .from('bonus_settings')
          .select('id')
          .eq('group_id', setting.groupId)
          .limit(1);

      if ((res as List).isNotEmpty) {
        final existingId = res.first['id']?.toString() ?? setting.id;
        await _service.client
            .from('bonus_settings')
            .update(data)
            .eq('id', existingId);
      } else {
        await _service.client.from('bonus_settings').insert(data);
      }
      return true;
    } catch (e) {
      debugPrint('Error saving bonus settings: $e');
      return false;
    }
  }

  /// 2. Fetch member savings amount directly from database (NEVER manually entered!)
  Future<double> fetchMemberSavingsAmount(
    String groupId,
    String memberId, {
    String? fromDate,
    String? toDate,
  }) async {
    double total = 0.0;

    // A. Query primary savings table
    try {
      var query = _service.client
          .from('savings')
          .select('amount, savings_date')
          .eq('group_id', groupId)
          .eq('member_id', memberId);

      if (fromDate != null && fromDate.isNotEmpty) {
        query = query.gte('savings_date', fromDate);
      }
      if (toDate != null && toDate.isNotEmpty) {
        query = query.lte('savings_date', toDate);
      }

      final res = await query;
      if (res is List && res.isNotEmpty) {
        total = res.fold(
          0.0,
          (sum, row) => sum + ((row['amount'] as num?)?.toDouble() ?? 0.0),
        );
      }
    } catch (e) {
      debugPrint('Error querying savings table for member $memberId: $e');
    }

    // B. Fallback to monthly_savings if savings table has no entries
    if (total == 0.0) {
      try {
        var mquery = _service.client
            .from('monthly_savings')
            .select('paid_amount, payment_date')
            .eq('group_id', groupId)
            .eq('member_id', memberId);

        if (fromDate != null && fromDate.isNotEmpty) {
          mquery = mquery.gte('payment_date', fromDate);
        }
        if (toDate != null && toDate.isNotEmpty) {
          mquery = mquery.lte('payment_date', toDate);
        }

        final mres = await mquery;
        if (mres is List && mres.isNotEmpty) {
          total = mres.fold(
            0.0,
            (sum, row) => sum + ((row['paid_amount'] as num?)?.toDouble() ?? 0.0),
          );
        }
      } catch (e) {
        debugPrint('Fallback monthly_savings query note: $e');
      }
    }

    return total;
  }

  /// 3. Fetch bonuses with filtering
  Future<List<Bonus>> fetchBonuses(
    String groupId, {
    String? financialYear,
    String? bonusType,
    String? status,
    String? searchQuery,
  }) async {
    try {
      var query = _service.client
          .from('bonuses')
          .select('*, members(full_name)')
          .eq('group_id', groupId);

      if (financialYear != null && financialYear.isNotEmpty && financialYear != 'सर्व' && financialYear != 'All') {
        query = query.eq('financial_year', financialYear);
      }

      if (bonusType != null && bonusType.isNotEmpty && bonusType != 'सर्व' && bonusType != 'All Types' && bonusType != 'All') {
        query = query.eq('bonus_type', bonusType);
      }

      if (status != null && status.isNotEmpty && status != 'सर्व' && status != 'All') {
        query = query.eq('status', status.toLowerCase());
      }

      final res = await query.order('created_at', ascending: false);

      List<Bonus> list = (res as List).map((e) => Bonus.fromJson(e)).toList();

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim().toLowerCase();
        list = list.where((b) {
          final mName = (b.memberName ?? '').toLowerCase();
          return mName.contains(q);
        }).toList();
      }

      return list;
    } catch (e) {
      debugPrint('Error fetching bonuses: $e');
      return [];
    }
  }

  /// 4. Batch Calculate bonuses for all active members
  Future<List<Bonus>> calculateBonusesForGroup(
    String groupId, {
    required List<Member> members,
    required String fromDate,
    required String toDate,
    required String financialYear,
    required String bonusType,
    required double rate,
    double? fixedAmount,
    double? minEligibility,
    double? maxBonus,
  }) async {
    final List<Bonus> calculatedList = [];

    for (var member in members) {
      // Auto fetch member savings for the exact period
      final double basisAmount = await fetchMemberSavingsAmount(
        groupId,
        member.id,
        fromDate: fromDate,
        toDate: toDate,
      );

      // Check min eligibility
      if (minEligibility != null && minEligibility > 0 && basisAmount < minEligibility) {
        continue;
      }

      double bonusAmt = 0.0;
      if (bonusType == 'fixed' || bonusType == 'fixed_amount') {
        bonusAmt = fixedAmount ?? 0.0;
      } else {
        // Bonus Amount = Basic Amount * Bonus Percentage / 100
        bonusAmt = (basisAmount * rate / 100.0).roundToDouble();
      }

      // Cap at max bonus if configured
      if (maxBonus != null && maxBonus > 0 && bonusAmt > maxBonus) {
        bonusAmt = maxBonus;
      }

      calculatedList.add(
        Bonus(
          id: OfflineDbHelper.generateId(),
          groupId: groupId,
          memberId: member.id,
          memberName: member.fullName,
          financialYear: financialYear,
          fromDate: fromDate,
          toDate: toDate,
          bonusType: bonusType,
          basisAmount: basisAmount,
          bonusRate: rate,
          bonusAmount: bonusAmt,
          paidAmount: 0.0,
          status: 'calculated',
          createdAt: DateTime.now().toIso8601String(),
        ),
      );
    }

    return calculatedList;
  }

  /// 5. Save batch calculated bonuses
  Future<bool> saveCalculatedBonuses(List<Bonus> bonuses) async {
    try {
      for (var b in bonuses) {
        await _service.client.from('bonuses').insert(b.toJson());
      }
      return true;
    } catch (e) {
      debugPrint('Error saving calculated bonuses: $e');
      return false;
    }
  }

  /// 6. Create single bonus record
  Future<Bonus?> createBonus(Bonus bonus) async {
    try {
      final res = await _service.client
          .from('bonuses')
          .insert(bonus.toJson())
          .select('*, members(full_name)')
          .single();
      return Bonus.fromJson(res);
    } catch (e) {
      debugPrint('Error creating bonus: $e');
      return null;
    }
  }

  /// 7. Update bonus record
  Future<bool> updateBonus(Bonus bonus) async {
    try {
      await _service.client
          .from('bonuses')
          .update(bonus.toJson())
          .eq('id', bonus.id);
      return true;
    } catch (e) {
      debugPrint('Error updating bonus: $e');
      return false;
    }
  }

  /// 8. Delete bonus record
  Future<bool> deleteBonus(String id, String groupId) async {
    try {
      await _service.client
          .from('bonuses')
          .delete()
          .eq('id', id)
          .eq('group_id', groupId);
      return true;
    } catch (e) {
      debugPrint('Error deleting bonus: $e');
      return false;
    }
  }

  /// 9. Approve bonuses
  Future<bool> approveBonuses(List<String> bonusIds, String approvedBy) async {
    try {
      final nowStr = DateTime.now().toIso8601String();
      for (var id in bonusIds) {
        await _service.client.from('bonuses').update({
          'status': 'approved',
          'approved_by': approvedBy,
          'approved_at': nowStr,
          'updated_at': nowStr,
        }).eq('id', id);
      }
      return true;
    } catch (e) {
      debugPrint('Error approving bonuses: $e');
      return false;
    }
  }

  /// 10. Reject / Cancel bonuses
  Future<bool> rejectBonuses(List<String> bonusIds) async {
    try {
      final nowStr = DateTime.now().toIso8601String();
      for (var id in bonusIds) {
        await _service.client.from('bonuses').update({
          'status': 'cancelled',
          'updated_at': nowStr,
        }).eq('id', id);
      }
      return true;
    } catch (e) {
      debugPrint('Error rejecting bonuses: $e');
      return false;
    }
  }

  /// 11. Pay bonus with Cash / Bank integration
  Future<bool> payBonus(
    Bonus bonus, {
    required String paymentMode,
    required double amount,
    String? bankAccountId,
    String? transactionRef,
    String? paymentDate,
    String? remarks,
  }) async {
    try {
      final pDate = paymentDate ?? DateTime.now().toIso8601String().substring(0, 10);
      final nowStr = DateTime.now().toIso8601String();
      final mode = paymentMode.toLowerCase();

      // 1. Update bonus record to 'paid'
      await _service.client.from('bonuses').update({
        'status': 'paid',
        'paid_amount': amount,
        'payment_mode': mode,
        'payment_date': pDate,
        'bank_account_id': bankAccountId,
        'transaction_ref': transactionRef,
        'remarks': remarks ?? 'लाभांश व बोनस वाटप',
        'updated_at': nowStr,
      }).eq('id', bonus.id);

      // 2. Financial Integration
      final memberName = bonus.memberName ?? 'सभासद';
      final desc = 'बोनस वाटप - $memberName (${bonus.financialYear})';

      if (mode == 'cash') {
        // Outflow from Cash in Hand
        await _service.client.from('cash_book').insert({
          'group_id': bonus.groupId,
          'entry_date': pDate,
          'type': 'cash_out',
          'amount': amount,
          'description': desc,
          'reference_module': 'bonus',
          'reference_id': bonus.id,
          'created_at': nowStr,
        });
      } else if (mode == 'bank' || mode == 'upi') {
        // Outflow from Bank Account
        if (bankAccountId != null && bankAccountId.isNotEmpty) {
          await _service.adjustBankBalance(
            groupId: bonus.groupId,
            bankAccountId: bankAccountId,
            amount: amount,
            isDeposit: false, // Withdrawal
            purpose: desc,
            transactionNumber: transactionRef,
          );
        }
      }

      return true;
    } catch (e) {
      debugPrint('Error paying bonus: $e');
      return false;
    }
  }
}
