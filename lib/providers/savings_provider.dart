import 'package:flutter/material.dart';
import '../models/saving.dart';
import '../services/supabase_service.dart';

class SavingsProvider extends ChangeNotifier {
  final SupabaseService _service = SupabaseService();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<Saving> _savings = [];
  List<Saving> get savings => _savings;

  Future<void> fetchSavings(String groupId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final res = await _service.client
          .from('savings')
          .select('*, members(full_name)')
          .eq('group_id', groupId)
          .order('savings_date', ascending: false);

      _savings = (res as List).map((e) => Saving.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error fetching savings: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addSaving(Saving saving) async {
    try {
      final res = await _service.client.from('savings').insert(saving.toJson()).select().single();
      _savings.insert(0, Saving.fromJson(res));
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error adding saving to Supabase: $e');
      return false;
    }
  }
}
