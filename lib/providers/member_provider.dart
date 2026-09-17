import 'package:flutter/material.dart';
import '../models/member.dart';
import '../services/app_config.dart';
import '../services/supabase_service.dart';

class MemberProvider extends ChangeNotifier {
  final SupabaseService _service = SupabaseService();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<Member> _members = [];
  List<Member> get members => _searchQuery.isEmpty
      ? _members
      : _members.where((m) =>
          m.fullName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          m.memberCode.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          m.mobileNumber.contains(_searchQuery)).toList();

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<void> fetchMembers(String groupId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final res = await _service.client
          .from('members')
          .select()
          .eq('group_id', groupId)
          .order('member_code', ascending: true);

      _members = (res as List).map((e) => Member.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error fetching members: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addMember(Member member) async {
    _lastError = null;
    try {
      final payload = AppConfig.isOfflineMode ? member.toJson() : member.toCloudJson();
      final res = await _service.client.from('members').insert(payload).select().maybeSingle();
      if (res != null) {
        _members.add(Member.fromJson(res));
      } else {
        _members.add(member);
      }
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error adding member: $e');
      _lastError = e.toString();
      return false;
    }
  }

  String? _lastError;
  String? get lastError => _lastError;

  Future<bool> updateMember(Member member) async {
    _lastError = null;
    try {
      final payload = AppConfig.isOfflineMode ? member.toJson() : member.toCloudJson();
      final res = await _service.client
          .from('members')
          .update(payload)
          .eq('id', member.id)
          .select()
          .maybeSingle();
      final index = _members.indexWhere((m) => m.id == member.id);
      if (index != -1) {
        if (res != null) {
          _members[index] = Member.fromJson(res);
        } else {
          _members[index] = member;
        }
        notifyListeners();
      }
      return true;
    } catch (e) {
      debugPrint('Error updating member: $e');
      _lastError = e.toString();
      return false;
    }
  }

  Future<bool> deleteMember(String id) async {
    _lastError = null;
    final existingIndex = _members.indexWhere((m) => m.id == id);
    final Member? removedMember = existingIndex != -1 ? _members[existingIndex] : null;

    // 1. Instant optimistic removal from list (0ms UI feedback)
    if (existingIndex != -1) {
      _members.removeAt(existingIndex);
      notifyListeners();
    }

    try {
      await _service.client.from('members').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error deleting member: $e');
      // Rollback optimistic removal on error
      if (removedMember != null && !_members.any((m) => m.id == id)) {
        _members.insert(existingIndex.clamp(0, _members.length), removedMember);
        notifyListeners();
      }
      final errStr = e.toString();
      if (errStr.contains('foreign key') || errStr.contains('violates') || errStr.contains('constraint')) {
        _lastError = 'या सभासदाच्या नावावर बचत, कर्ज किंवा व्यवहारांच्या नोंदी असल्यामुळे थेट हटवता येत नाही. आपण या सभासदाची स्थिती "निष्क्रिय (Inactive)" करू शकता.';
      } else {
        _lastError = 'सभासद हटवताना त्रुटी आली: $e';
      }
      return false;
    }
  }
}
