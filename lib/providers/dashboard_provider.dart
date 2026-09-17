import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../models/meeting.dart';

class DashboardProvider extends ChangeNotifier {
  final SupabaseService _service = SupabaseService();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  int totalMembers = 0;
  double totalSavings = 0.0;
  double activeLoans = 0.0;
  int pendingEmis = 0;
  double bankBalance = 0.0;
  double cashInHand = 0.0;
  double totalIncome = 0.0;
  double totalExpenses = 0.0;
  double totalProfit = 0.0;

  DateTime? startDate;
  DateTime? endDate;
  String selectedFilter = 'all'; // 'all', 'this_month', 'last_month', 'this_year', 'custom'

  Meeting? upcomingMeeting;

  Future<void> setDateFilter({
    required String groupId,
    required String filterType,
    DateTime? customStart,
    DateTime? customEnd,
  }) async {
    selectedFilter = filterType;
    final now = DateTime.now();

    if (filterType == 'this_month') {
      startDate = DateTime(now.year, now.month, 1);
      endDate = DateTime(now.year, now.month + 1, 0);
    } else if (filterType == 'last_month') {
      startDate = DateTime(now.year, now.month - 1, 1);
      endDate = DateTime(now.year, now.month, 0);
    } else if (filterType == 'this_year') {
      final fyStartYear = now.month >= 4 ? now.year : now.year - 1;
      startDate = DateTime(fyStartYear, 4, 1);
      endDate = DateTime(fyStartYear + 1, 3, 31);
    } else if (filterType == 'custom') {
      startDate = customStart;
      endDate = customEnd;
    } else {
      startDate = null;
      endDate = null;
    }

    await loadDashboardMetrics(groupId, start: startDate, end: endDate);
  }

  Future<void> loadDashboardMetrics(
    String groupId, {
    DateTime? start,
    DateTime? end,
  }) async {
    _isLoading = true;
    notifyListeners();

    if (start != null || end != null) {
      startDate = start;
      endDate = end;
    }

    try {
      final metrics = await _service.fetchDashboardMetrics(
        groupId,
        startDate: startDate,
        endDate: endDate,
      );
      totalMembers = (metrics['total_members'] as num?)?.toInt() ?? 0;
      totalSavings = (metrics['total_savings'] as num?)?.toDouble() ?? 0.0;
      activeLoans = (metrics['active_loans'] as num?)?.toDouble() ?? 0.0;
      pendingEmis = (metrics['pending_emis'] as num?)?.toInt() ?? 0;
      bankBalance = (metrics['bank_balance'] as num?)?.toDouble() ?? 0.0;
      cashInHand = (metrics['cash_in_hand'] as num?)?.toDouble() ?? 0.0;
      totalIncome = (metrics['total_income'] as num?)?.toDouble() ?? 0.0;
      totalExpenses = (metrics['total_expenses'] as num?)?.toDouble() ?? 0.0;
      totalProfit = (metrics['total_profit'] as num?)?.toDouble() ?? 0.0;

      // Fetch upcoming meeting
      final meetRes = await _service.client
          .from('meetings')
          .select()
          .eq('group_id', groupId)
          .order('meeting_date', ascending: true)
          .limit(1);

      if ((meetRes as List).isNotEmpty) {
        upcomingMeeting = Meeting.fromJson(meetRes.first);
      } else {
        upcomingMeeting = null;
      }
    } catch (e) {
      debugPrint('Error loading dashboard metrics: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
