import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sqflite/sqflite.dart';
import '../core/constants/supabase_config.dart';
import 'app_config.dart';
import 'offline_db_helper.dart';

enum SyncStatus { idle, syncing, offline, error }

class SyncState {
  final bool isOnline;
  final SyncStatus status;
  final int pendingCount;
  final String? message;
  final DateTime? lastSyncTime;

  const SyncState({
    required this.isOnline,
    required this.status,
    required this.pendingCount,
    this.message,
    this.lastSyncTime,
  });

  SyncState copyWith({
    bool? isOnline,
    SyncStatus? status,
    int? pendingCount,
    String? message,
    DateTime? lastSyncTime,
  }) {
    return SyncState(
      isOnline: isOnline ?? this.isOnline,
      status: status ?? this.status,
      pendingCount: pendingCount ?? this.pendingCount,
      message: message ?? this.message,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
    );
  }
}

class SyncService {
  static final SyncService instance = SyncService._();
  SyncService._();

  final ValueNotifier<SyncState> state = ValueNotifier<SyncState>(
    const SyncState(
      isOnline: false,
      status: SyncStatus.idle,
      pendingCount: 0,
    ),
  );

  /// Incremented after every successful cloud sync to notify UI providers to refresh
  final ValueNotifier<int> syncVersion = ValueNotifier<int>(0);

  StreamSubscription? _connectivitySub;
  Timer? _dynamicTimer;
  Timer? _debounceTimer;
  Timer? _reconnectTimer;
  bool _isSyncRunning = false;
  bool _initialized = false;

  /// Start monitoring and sync service
  Future<void> start() async {
    if (_initialized) return;
    _initialized = true;

    await refreshPendingCount();

    // Listen to network changes (works on Android / iOS platforms)
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(const Duration(milliseconds: 800), () async {
        final isOnline = await _hasInternetConnection();
        if (isOnline) {
          await _onInternetRestored();
        }
      });
    });

    // Check connectivity and sync quickly on app launch
    _quickLaunchSync();

    // Dynamic rapid heartbeat: polls every 2.5s if offline or pending items exist,
    // immediately detecting reconnection and syncing to cloud!
    _startDynamicHeartbeat();
  }

  void _startDynamicHeartbeat() {
    _dynamicTimer?.cancel();
    _scheduleNextHeartbeat();
  }

  void _scheduleNextHeartbeat() {
    if (!_initialized || !AppConfig.isHybridMode) return;

    final hasPendingOrOffline = !state.value.isOnline || state.value.pendingCount > 0;
    final delay = hasPendingOrOffline
        ? const Duration(milliseconds: 2500)
        : const Duration(seconds: 25);

    _dynamicTimer = Timer(delay, () async {
      if (!_initialized || !AppConfig.isHybridMode) return;
      await _checkAndSyncHeartbeat();
      _scheduleNextHeartbeat();
    });
  }

  Future<void> _checkAndSyncHeartbeat() async {
    if (_isSyncRunning) return;

    final wasOnline = state.value.isOnline;
    final isOnline = await _hasInternetConnection();
    final count = await refreshPendingCount();

    if (!isOnline) {
      if (wasOnline) {
        state.value = state.value.copyWith(
          isOnline: false,
          status: SyncStatus.offline,
          pendingCount: count,
          message: count > 0 ? '$count items pending sync' : 'Offline',
        );
      }
      return;
    }

    // Currently online
    if (!wasOnline) {
      debugPrint('⚡ Dynamic heartbeat detected internet restored! Syncing immediately...');
      state.value = state.value.copyWith(
        isOnline: true,
        message: count > 0 ? 'Internet restored. Syncing $count items...' : 'Online',
      );
      await _onInternetRestored();
    } else if (count > 0) {
      await pushBatchSync();
    }
  }

  /// Triggered immediately when internet connection is restored
  Future<void> _onInternetRestored() async {
    if (!AppConfig.isHybridMode) return;
    final count = await refreshPendingCount();
    if (count > 0) {
      // Prioritize uploading the bunches of offline entries immediately!
      await pushBatchSync();
    }
    // Then run a full sync
    await syncAll();
  }

  Future<void> _quickLaunchSync() async {
    if (!AppConfig.isHybridMode) return;
    final isConnected = await _hasInternetConnection();
    final count = await refreshPendingCount();

    if (!isConnected) {
      state.value = state.value.copyWith(
        isOnline: false,
        status: SyncStatus.offline,
        pendingCount: count,
        message: count > 0 ? '$count items pending sync' : 'Offline',
      );
      return;
    }

    await syncAll();
  }

  void stop() {
    _connectivitySub?.cancel();
    _dynamicTimer?.cancel();
    _debounceTimer?.cancel();
    _reconnectTimer?.cancel();
    _initialized = false;
  }

  /// Refreshes the pending items count from SQLite
  Future<int> refreshPendingCount() async {
    try {
      final count = await OfflineDbHelper.instance.getPendingSyncCount();
      state.value = state.value.copyWith(pendingCount: count);
      return count;
    } catch (_) {
      return 0;
    }
  }

  /// Debounced trigger called after local mutations.
  /// Debounced by 2 seconds so entries upload quickly without delay.
  void triggerSync() {
    if (!AppConfig.isHybridMode) return;
    refreshPendingCount();

    // Re-schedule heartbeat to rapid mode immediately
    _startDynamicHeartbeat();

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), () {
      pushBatchSync();
    });
  }

  /// Push only pending items in batch without pulling or disrupting UI
  Future<void> pushBatchSync() async {
    if (_isSyncRunning) return;
    final isConnected = await _hasInternetConnection();
    if (!isConnected) return;

    _isSyncRunning = true;
    try {
      final count = await refreshPendingCount();
      if (count == 0) return;

      state.value = state.value.copyWith(
        isOnline: true,
        status: SyncStatus.syncing,
        message: 'Uploading $count entries...',
      );

      await _ensureCloudAuth();
      await _pushPendingQueue();

      final remaining = await refreshPendingCount();
      state.value = state.value.copyWith(
        isOnline: true,
        status: SyncStatus.idle,
        pendingCount: remaining,
        lastSyncTime: DateTime.now(),
        message: remaining == 0 ? 'All synced' : '$remaining pending',
      );
      // We deliberately do not bump syncVersion here to avoid screen flickering/reloads while user works
    } catch (e) {
      debugPrint('pushBatchSync error: $e');
      final remaining = await refreshPendingCount();
      state.value = state.value.copyWith(
        status: SyncStatus.idle,
        pendingCount: remaining,
        message: remaining == 0 ? 'All synced' : '$remaining pending',
      );
    } finally {
      _isSyncRunning = false;
    }
  }

  /// Check connectivity and execute sync if online
  Future<void> checkConnectivityAndSync() async {
    if (!AppConfig.isHybridMode) return;

    final isConnected = await _hasInternetConnection();
    final count = await refreshPendingCount();

    if (!isConnected) {
      state.value = state.value.copyWith(
        isOnline: false,
        status: SyncStatus.offline,
        pendingCount: count,
        message: count > 0 ? '$count items pending sync' : 'Offline',
      );
      return;
    }

    await syncAll();
  }

  /// Tests if Supabase cloud is reachable
  Future<bool> _hasInternetConnection() async {
    try {
      // On mobile (Android/iOS), check connectivity_plus first to save battery.
      // On desktop (Windows/Linux/macOS), connectivity_plus is unreliable, so test reachability directly.
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        final results = await Connectivity().checkConnectivity();
        if (results.isEmpty || (results.length == 1 && results.first == ConnectivityResult.none)) {
          return false;
        }
      }

      final host = Uri.tryParse(SupabaseConfig.url)?.host ?? 'google.com';
      try {
        final res = await InternetAddress.lookup(host)
            .timeout(const Duration(milliseconds: 2000));
        if (res.isNotEmpty && res[0].rawAddress.isNotEmpty) {
          return true;
        }
      } catch (_) {
        if (host != 'google.com') {
          final res2 = await InternetAddress.lookup('google.com')
              .timeout(const Duration(milliseconds: 2000));
          if (res2.isNotEmpty && res2[0].rawAddress.isNotEmpty) {
            return true;
          }
        }
      }
    } catch (_) {}
    return false;
  }

  /// Ensures Cloud Authentication Session is active and valid
  Future<bool> _ensureCloudAuth() async {
    final client = Supabase.instance.client;
    try {
      final session = client.auth.currentSession;
      if (session != null && !session.isExpired && client.auth.currentUser != null) {
        return true;
      }

      // Try refreshing existing session first
      if (session != null) {
        try {
          final res = await client.auth.refreshSession().timeout(const Duration(seconds: 4));
          if (res.session != null && !res.session!.isExpired) {
            return true;
          }
        } catch (_) {}
      }

      // If refresh failed or no session, re-login with saved credentials
      final prefs = await SharedPreferences.getInstance();
      var savedEmail = prefs.getString(AppConfig.prefKey('logged_in_email')) ??
          prefs.getString('logged_in_email');
      var savedPin = prefs.getString(AppConfig.prefKey('admin_pin')) ??
          prefs.getString('admin_pin');

      // If saved email does not contain @, resolve from offline_users
      if (savedEmail != null && !savedEmail.contains('@')) {
        try {
          final db = await OfflineDbHelper.instance.database;
          final uRows = await db.query(
            'offline_users',
            where: 'mobile = ? OR LOWER(email) = ?',
            whereArgs: [savedEmail, savedEmail.toLowerCase()],
            limit: 1,
          );
          if (uRows.isNotEmpty) {
            final cloudMail = uRows.first['email']?.toString();
            final cloudPwd = uRows.first['password']?.toString();
            if (cloudMail != null && cloudMail.contains('@')) {
              savedEmail = cloudMail;
            }
            if (cloudPwd != null && cloudPwd.isNotEmpty) {
              savedPin = cloudPwd;
            }
          }
        } catch (_) {}
      }

      if (savedEmail != null && savedPin != null && savedEmail.contains('@')) {
        final authRes = await client.auth.signInWithPassword(
          email: savedEmail.trim().toLowerCase(),
          password: savedPin.trim(),
        ).timeout(const Duration(seconds: 5));
        return authRes.user != null;
      }
    } catch (e) {
      debugPrint('Cloud auth note: $e');
    }
    return client.auth.currentUser != null;
  }

  /// Perform full Push & Pull sync with data protection
  Future<void> syncAll() async {
    if (_isSyncRunning) return;
    _isSyncRunning = true;

    try {
      final count = await refreshPendingCount();
      state.value = state.value.copyWith(
        isOnline: true,
        status: SyncStatus.syncing,
        message: 'Syncing $count pending items...',
      );

      // 1. Ensure Cloud Auth is established
      await _ensureCloudAuth();

      // 2. Push pending local changes to Supabase Cloud FIRST
      await _pushPendingQueue();

      // 3. Pull cloud updates to Local SQLite (safely shielded from overwriting pending edits)
      await _pullCloudUpdates();

      final remaining = await refreshPendingCount();
      state.value = state.value.copyWith(
        isOnline: true,
        status: SyncStatus.idle,
        pendingCount: remaining,
        lastSyncTime: DateTime.now(),
        message: remaining == 0 ? 'All synced' : '$remaining items pending',
      );
      syncVersion.value++;
    } catch (e) {
      state.value = state.value.copyWith(
        status: SyncStatus.error,
        message: 'Sync error: $e',
      );
    } finally {
      _isSyncRunning = false;
    }
  }

  /// Supabase Cloud Table Schema Whitelist
  static const Map<String, Set<String>> cloudTableColumns = {
    'audit_logs': {'action', 'created_at', 'group_id', 'id', 'ip_address', 'user_id', 'user_name'},
    'bank_accounts': {'account_holder', 'account_number', 'account_type', 'bank_address', 'bank_name', 'branch', 'created_at', 'current_balance', 'email', 'group_id', 'id', 'ifsc', 'is_primary', 'mobile_number', 'notes', 'opening_balance', 'opening_balance_date', 'status', 'updated_at'},
    'bank_loans': {'account_number', 'bank_name', 'created_at', 'group_id', 'id', 'interest_rate', 'loan_amount', 'status', 'tenure_months', 'updated_at'},
    'bank_reconciliations': {'bank_account_id', 'created_at', 'difference', 'group_id', 'id', 'reconciliation_date', 'remarks', 'status'},
    'bank_transactions': {'amount', 'balance_after', 'bank_account_id', 'created_at', 'deposit_slip_or_cheque_no', 'description', 'group_id', 'id', 'payment_mode', 'performed_by', 'reference_number', 'transaction_date', 'transaction_number', 'type'},
    'bonus_settings': {'bonus_percentage', 'bonus_type', 'calculation_method', 'created_at', 'effective_from', 'effective_to', 'fixed_amount', 'group_id', 'id', 'is_active', 'max_bonus', 'min_eligibility', 'setting_name', 'updated_at'},
    'bonuses': {'approved_at', 'approved_by', 'bank_account_id', 'basis_amount', 'bonus_amount', 'bonus_rate', 'bonus_type', 'created_at', 'financial_year', 'from_date', 'group_id', 'id', 'member_id', 'paid_amount', 'payment_date', 'payment_mode', 'remarks', 'status', 'to_date', 'transaction_ref', 'updated_at'},
    'cash_book': {'amount', 'balance_after', 'created_at', 'description', 'entry_date', 'group_id', 'id', 'reference_id', 'reference_module', 'type'},
    'contributions': {'amount', 'contribution_date', 'created_at', 'group_id', 'id', 'member_id', 'payment_mode', 'receipt_number'},
    'customers': {'address', 'created_at', 'group_id', 'id', 'mobile'},
    'documents': {'created_at', 'expiry_date', 'file_url', 'group_id', 'id', 'member_id', 'verification_status', 'verified_at', 'verified_by'},
    'dues': {'created_at', 'due_amount', 'due_date', 'group_id', 'id', 'member_id', 'paid_amount', 'payment_type', 'remaining_amount', 'status', 'updated_at'},
    'event_participants': {'attended', 'event_id', 'id', 'member_id'},
    'events': {'budget', 'created_at', 'description', 'event_date', 'group_id', 'id'},
    'expenses': {'amount', 'bank_account_id', 'bill_number', 'category', 'created_at', 'description', 'expense_date', 'group_id', 'id', 'paid_to', 'payment_mode', 'receipt_doc_url', 'updated_at'},
    'fines': {'amount', 'created_at', 'fine_date', 'group_id', 'id', 'member_id', 'paid_date', 'reason'},
    'government_schemes': {'created_at', 'department', 'description', 'group_id', 'id', 'scheme_name'},
    'groups': {'address', 'created_at', 'default_loan_interest_rate', 'district', 'email', 'formation_date', 'group_name', 'id', 'late_fee_per_day', 'logo_url', 'meeting_absence_fine', 'mobile', 'monthly_savings_amount', 'pincode', 'president_name', 'registration_number', 'savings_due_day', 'secretary_name', 'status', 'taluka', 'treasurer_name', 'updated_at', 'village'},
    'incomes': {'amount', 'bank_account_id', 'category', 'created_at', 'description', 'group_id', 'id', 'income_date', 'payment_mode', 'receipt_number', 'received_from', 'updated_at'},
    'loan_emis': {'bank_account_id', 'collected_by', 'created_at', 'due_date', 'emi_amount', 'emi_number', 'group_id', 'id', 'interest', 'late_fee', 'loan_id', 'paid_amount', 'payment_date', 'payment_mode', 'principal', 'receipt_number', 'remarks', 'status', 'transaction_id', 'updated_at'},
    'loans': {'application_date', 'approval_date', 'approved_amount', 'bank_account_id', 'created_at', 'disbursed_by_mode', 'disbursement_date', 'disbursement_ref', 'emi_amount', 'first_emi_date', 'group_id', 'guarantor_member_id', 'guarantor_mobile', 'guarantor_name', 'id', 'interest_rate', 'interest_type', 'loan_code', 'loan_period_months', 'loan_type', 'member_id', 'number_of_emis', 'outstanding_principal', 'purpose', 'remarks', 'requested_amount', 'settlement_date', 'status', 'total_repaid', 'updated_at'},
    'meeting_attendance': {'created_at', 'group_id', 'id', 'meeting_id', 'member_id', 'remarks', 'status'},
    'meetings': {'agenda', 'created_at', 'description', 'group_id', 'id', 'location', 'meeting_date', 'meeting_time', 'meeting_type', 'minutes_of_meeting', 'status', 'updated_at'},
    'member_businesses': {'business_name', 'business_type', 'created_at', 'group_id', 'id', 'member_id'},
    'members': {'aadhaar_doc_url', 'aadhaar_number', 'account_holder_name', 'account_number', 'address', 'alternate_mobile', 'annual_income', 'bank_name', 'branch_name', 'created_at', 'date_of_birth', 'district', 'education', 'full_name', 'gender', 'group_id', 'id', 'ifsc', 'joining_date', 'member_code', 'mobile_number', 'nominee_age', 'nominee_mobile', 'nominee_name', 'nominee_relation', 'occupation', 'pan_doc_url', 'pan_number', 'passbook_doc_url', 'photo_url', 'pincode', 'role_in_group', 'signature_url', 'status', 'taluka', 'updated_at', 'village'},
    'monthly_collections': {'bank_account_id', 'collection_date', 'created_at', 'created_by', 'group_id', 'id', 'interest_amount', 'loan_id', 'monthly_saving', 'notes', 'paid_emi', 'payment_mode', 'payment_status', 'principal_amount', 'reference_no', 'remaining_emi', 'required_emi', 'total_collection', 'updated_at'},
    'monthly_savings': {'balance_amount', 'collected_by', 'created_at', 'due_date', 'expected_amount', 'group_id', 'id', 'late_fee', 'member_id', 'month', 'paid_amount', 'payment_date', 'payment_mode', 'receipt_number', 'remarks', 'saving_plan_id', 'status', 'transaction_id', 'updated_at', 'year'},
    'notifications': {'created_at', 'due_date', 'group_id', 'id', 'is_read', 'member_id', 'message', 'priority', 'title', 'type'},
    'product_categories': {'created_at', 'description', 'group_id', 'id', 'name'},
    'products': {'category_id', 'category_name', 'created_at', 'current_stock', 'description', 'group_id', 'id', 'minimum_stock', 'product_code', 'product_name', 'production_cost', 'purchase_cost', 'selling_price', 'status', 'unit', 'updated_at'},
    'profiles': {'created_at', 'email', 'full_name', 'group_id', 'id', 'is_main_admin', 'joining_date', 'last_login_at', 'mobile', 'profile_photo_url', 'role', 'status', 'updated_at'},
    'resolution_votes': {'group_id', 'id', 'member_id', 'resolution_id', 'vote'},
    'resolutions': {'created_at', 'description', 'group_id', 'id', 'meeting_id', 'proposed_by', 'status', 'title', 'updated_at'},
    'sale_items': {'id', 'product_id', 'quantity', 'sale_id', 'total_price', 'unit_price'},
    'sales': {'created_at', 'customer_id', 'discount', 'group_id', 'id', 'invoice_number', 'paid_amount', 'payment_mode', 'payment_status', 'sale_date', 'subtotal', 'total_amount'},
    'saving_plans': {'created_at', 'due_day', 'grace_period_days', 'group_id', 'id', 'interest_rate', 'is_active', 'late_fee', 'monthly_amount', 'plan_name', 'status', 'updated_at'},
    'savings': {'amount', 'collected_by', 'created_at', 'fine_amount', 'group_id', 'id', 'member_id', 'payment_mode', 'receipt_number', 'reference_number', 'remarks', 'savings_date', 'savings_type', 'updated_at'},
    'scheme_applications': {'application_date', 'created_at', 'group_id', 'id', 'remarks', 'scheme_id', 'status'},
    'settings': {'group_id', 'id', 'updated_at'},
    'stock_transactions': {'created_at', 'group_id', 'id', 'product_id', 'quantity', 'supplier_id', 'transaction_date', 'transaction_type'},
    'suppliers': {'address', 'created_at', 'group_id', 'id', 'mobile'},
    'training_attendances': {'created_at', 'id', 'member_id', 'training_id'},
    'trainings': {'created_at', 'end_date', 'group_id', 'id', 'start_date'},
    'user_permissions': {'can_delete', 'can_edit', 'can_export', 'can_view', 'created_at', 'group_id', 'id', 'updated_at'},
  };

  /// Table priority for pushing dependencies first
  static const Map<String, int> _tablePriority = {
    'groups': 1,
    'profiles': 2,
    'settings': 3,
    'saving_plans': 4,
    'bank_accounts': 5,
    'product_categories': 6,
    'products': 7,
    'suppliers': 8,
    'customers': 9,
    'members': 10,
    'member_businesses': 11,
    'user_permissions': 12,
    'meetings': 13,
    'meeting_attendance': 14,
    'resolutions': 15,
    'resolution_votes': 16,
    'savings': 17,
    'monthly_savings': 18,
    'loans': 19,
    'loan_emis': 20,
    'monthly_collections': 21,
    'bank_loans': 22,
    'incomes': 22,
    'expenses': 23,
    'bank_transactions': 24,
    'cash_book': 25,
    'bank_reconciliations': 26,
    'stock_transactions': 27,
    'sales': 28,
    'sale_items': 29,
    'contributions': 30,
    'fines': 31,
    'dues': 32,
    'government_schemes': 33,
    'scheme_applications': 34,
    'documents': 35,
    'trainings': 36,
    'training_attendances': 37,
    'events': 38,
    'event_participants': 39,
    'notifications': 40,
    'audit_logs': 41,
    'bonus_settings': 42,
    'bonuses': 43,
  };

  /// Pushes items from SQLite sync_queue to Supabase Cloud in bunches (batches) with high performance
  Future<void> _pushPendingQueue() async {
    final client = Supabase.instance.client;
    await _ensureCloudAuth();
    final db = await OfflineDbHelper.instance.database;

    // Loop up to 10 iterations to process large backlogs (e.g. 100+ members added offline)
    for (int iteration = 0; iteration < 10; iteration++) {
      final rawItems = await OfflineDbHelper.instance.getPendingSyncItems(limit: 200);
      if (rawItems.isEmpty) break;
      final items = List<Map<String, dynamic>>.from(rawItems);

      // Sort items by dependency hierarchy (Parents first, children later)
      items.sort((a, b) {
        final pA = _tablePriority[a['table_name']] ?? 99;
        final pB = _tablePriority[b['table_name']] ?? 99;
        if (pA != pB) return pA.compareTo(pB);
        return (a['id'] as int).compareTo(b['id'] as int);
      });

      // Group consecutive items into bunches by (table_name, action)
      int idx = 0;
      bool networkBroken = false;

      while (idx < items.length) {
        final first = items[idx];
        final currentTable = first['table_name'] as String;
        final currentAction = first['action'] as String;

        final bunch = <Map<String, dynamic>>[];
        while (idx < items.length &&
            items[idx]['table_name'] == currentTable &&
            items[idx]['action'] == currentAction &&
            bunch.length < 50) {
          bunch.add(items[idx]);
          idx++;
        }

        try {
          if (currentAction == 'UPSERT') {
            await _pushUpsertBunch(client, db, currentTable, bunch);
          } else if (currentAction == 'DELETE') {
            await _pushDeleteBunch(client, db, currentTable, bunch);
          }
        } catch (err) {
          final errStr = err.toString().toLowerCase();
          if (errStr.contains('socketexception') ||
              errStr.contains('clientexception') ||
              errStr.contains('timeout') ||
              errStr.contains('network is unreachable')) {
            networkBroken = true;
            break;
          }
        }
      }

      if (networkBroken) break;
    }
  }

  /// Pushes a bunch of UPSERT items in a single batch call to Supabase
  Future<void> _pushUpsertBunch(
    SupabaseClient client,
    Database db,
    String table,
    List<Map<String, dynamic>> bunch,
  ) async {
    final rowsToUpsert = <Map<String, dynamic>>[];
    final bunchItemIds = <int>[];

    for (var item in bunch) {
      final id = item['id'] as int;
      final payloadRaw = item['payload'] as String?;
      if (payloadRaw != null) {
        try {
          final row = jsonDecode(payloadRaw) as Map<String, dynamic>;
          final formatted = _formatRowForSupabase(table, row);
          rowsToUpsert.add(formatted);
          bunchItemIds.add(id);
        } catch (e) {
          await OfflineDbHelper.instance.markSyncItemFailed(id, 'JSON error: $e');
        }
      } else {
        await OfflineDbHelper.instance.markSyncItemCompleted(id);
      }
    }

    if (rowsToUpsert.isEmpty) return;

    try {
      // 🚀 BUNCH UPLOAD: All rows uploaded together in ONE single HTTP request!
      await client.from(table).upsert(rowsToUpsert).timeout(const Duration(seconds: 45));
      await OfflineDbHelper.instance.markSyncItemsCompleted(bunchItemIds);
    } catch (bunchErr) {
      final errLower = bunchErr.toString().toLowerCase();
      // If network broke, propagate to stop queue processing
      if (errLower.contains('socketexception') ||
          errLower.contains('clientexception') ||
          errLower.contains('timeout')) {
        rethrow;
      }

      // If batch failed due to constraint or single bad row, gracefully fall back item-by-item
      for (int i = 0; i < rowsToUpsert.length; i++) {
        final row = rowsToUpsert[i];
        final itemId = bunchItemIds[i];
        final rowId = row['id']?.toString() ?? '';

        try {
          await client.from(table).upsert(row).timeout(const Duration(seconds: 15));
          await OfflineDbHelper.instance.markSyncItemCompleted(itemId);
        } catch (singleErr) {
          final sErrLower = singleErr.toString().toLowerCase();
          // Safeguard 1: Auto-resolve unique code clashes on member_code or loan_code
          if (sErrLower.contains('duplicate key') || sErrLower.contains('23505') || sErrLower.contains('unique constraint')) {
            bool renumbered = false;
            if (table == 'members' && row.containsKey('member_code')) {
              final newCode = '${row['member_code']}-${DateTime.now().millisecondsSinceEpoch % 1000}';
              row['member_code'] = newCode;
              await db.update('members', {'member_code': newCode}, where: 'id = ?', whereArgs: [rowId]);
              try {
                await client.from(table).upsert(row).timeout(const Duration(seconds: 15));
                await OfflineDbHelper.instance.markSyncItemCompleted(itemId);
                renumbered = true;
              } catch (_) {}
            } else if (table == 'loans' && row.containsKey('loan_code')) {
              final newCode = '${row['loan_code']}-${DateTime.now().millisecondsSinceEpoch % 1000}';
              row['loan_code'] = newCode;
              await db.update('loans', {'loan_code': newCode}, where: 'id = ?', whereArgs: [rowId]);
              try {
                await client.from(table).upsert(row).timeout(const Duration(seconds: 15));
                await OfflineDbHelper.instance.markSyncItemCompleted(itemId);
                renumbered = true;
              } catch (_) {}
            }

            if (!renumbered) {
              await OfflineDbHelper.instance.markSyncItemFailed(itemId, singleErr.toString());
            }
          } else {
            await OfflineDbHelper.instance.markSyncItemFailed(itemId, singleErr.toString());
          }
        }
      }
    }
  }

  /// Pushes a bunch of DELETE items in a single batch call to Supabase
  Future<void> _pushDeleteBunch(
    SupabaseClient client,
    Database db,
    String table,
    List<Map<String, dynamic>> bunch,
  ) async {
    final rowIds = bunch.map((b) => b['row_id'] as String).toList();
    final itemIds = bunch.map((b) => b['id'] as int).toList();

    try {
      await client.from(table).delete().inFilter('id', rowIds).timeout(const Duration(seconds: 30));
      await OfflineDbHelper.instance.markSyncItemsCompleted(itemIds);
    } catch (e) {
      // Fallback to one-by-one delete if inFilter fails
      for (var item in bunch) {
        final id = item['id'] as int;
        final rowId = item['row_id'] as String;
        try {
          await client.from(table).delete().eq('id', rowId).timeout(const Duration(seconds: 10));
          await OfflineDbHelper.instance.markSyncItemCompleted(id);
        } catch (singleErr) {
          await OfflineDbHelper.instance.markSyncItemFailed(id, singleErr.toString());
        }
      }
    }
  }

  /// Pulls master tables and transaction records from Supabase Cloud to Local SQLite
  /// Protected against multi-tenant data leaks and shielded from overwriting unsynced local rows
  Future<void> _pullCloudUpdates() async {
    final client = Supabase.instance.client;
    final db = await OfflineDbHelper.instance.database;

    // Resolve current group ID for multi-tenant data isolation
    String? currentGroupId;
    try {
      final prefs = await SharedPreferences.getInstance();
      currentGroupId = prefs.getString(AppConfig.prefKey('active_group_id')) ??
          prefs.getString('active_group_id');
    } catch (_) {}

    // CRITICAL: If authenticated to Supabase Cloud, pull the logged-in user's profile FIRST
    // to discover their real multi-tenant group_id directly from the cloud!
    if (client.auth.currentUser != null) {
      try {
        final authUserId = client.auth.currentUser!.id;
        final profRes = await client
            .from('profiles')
            .select()
            .eq('id', authUserId)
            .maybeSingle()
            .timeout(const Duration(seconds: 15));

        if (profRes != null) {
          final pMap = Map<String, dynamic>.from(profRes);
          final cloudGroupId = pMap['group_id']?.toString();

          // Save profile to local SQLite
          final profCols = await _getTableColumns(db, 'profiles');
          final sanitizedProf = _sanitizeRowForSqlite(pMap, profCols);
          await db.insert('profiles', sanitizedProf, conflictAlgorithm: ConflictAlgorithm.replace);

          if (cloudGroupId != null && cloudGroupId.isNotEmpty) {
            currentGroupId = cloudGroupId;
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(AppConfig.prefKey('active_group_id'), cloudGroupId);
            await prefs.setString('active_group_id', cloudGroupId);

            // Pull the user's cloud group record
            final gRes = await client
                .from('groups')
                .select()
                .eq('id', cloudGroupId)
                .maybeSingle()
                .timeout(const Duration(seconds: 15));

            if (gRes != null) {
              final gMap = Map<String, dynamic>.from(gRes);
              final gCols = await _getTableColumns(db, 'groups');
              final sanitizedG = _sanitizeRowForSqlite(gMap, gCols);
              await db.insert('groups', sanitizedG, conflictAlgorithm: ConflictAlgorithm.replace);

              // Clean up dummy seed group if present
              await db.delete('groups', where: "id = 'group_offline_001'");
              await db.delete('profiles', where: "group_id = 'group_offline_001'");
            }
          }
        }
      } catch (e) {
        debugPrint('Cloud pull profile discovery note: $e');
      }
    }

    if (currentGroupId == null || currentGroupId.isEmpty) {
      final gRows = await db.query('groups', where: "id != 'group_offline_001'", limit: 1);
      if (gRows.isNotEmpty && gRows.first['id'] != null) {
        currentGroupId = gRows.first['id'].toString();
      } else {
        final anyG = await db.query('groups', limit: 1);
        if (anyG.isNotEmpty && anyG.first['id'] != null) {
          currentGroupId = anyG.first['id'].toString();
        }
      }
    }

    final cloudTables = [
      'groups',
      'profiles',
      'settings',
      'saving_plans',
      'bank_accounts',
      'product_categories',
      'products',
      'suppliers',
      'customers',
      'members',
      'member_businesses',
      'user_permissions',
      'meetings',
      'meeting_attendance',
      'resolutions',
      'resolution_votes',
      'savings',
      'monthly_savings',
      'loans',
      'loan_emis',
      'monthly_collections',
      'bank_loans',
      'incomes',
      'expenses',
      'bank_transactions',
      'cash_book',
      'bank_reconciliations',
      'stock_transactions',
      'sales',
      'sale_items',
      'contributions',
      'fines',
      'dues',
      'government_schemes',
      'scheme_applications',
      'documents',
      'trainings',
      'training_attendances',
      'events',
      'event_participants',
      'notifications',
      'audit_logs',
      'bonus_settings',
      'bonuses'
    ];

    // Concurrently pull tables in parallel batches of 6 for lightning-fast sync
    const batchSize = 6;
    for (var i = 0; i < cloudTables.length; i += batchSize) {
      final chunk = cloudTables.skip(i).take(batchSize).toList();
      await Future.wait(chunk.map((table) => _pullTable(client, db, table, currentGroupId)));
    }
  }

  /// Public method to pull all cloud data for a specific group (used during new-device onboarding or manual sync)
  Future<void> pullAllTablesForGroup(String groupId) async {
    try {
      final client = Supabase.instance.client;
      final db = await OfflineDbHelper.instance.database;

      final cloudTables = [
        'groups',
        'profiles',
        'settings',
        'saving_plans',
        'bank_accounts',
        'product_categories',
        'products',
        'suppliers',
        'customers',
        'members',
        'member_businesses',
        'user_permissions',
        'meetings',
        'meeting_attendance',
        'resolutions',
        'resolution_votes',
        'savings',
        'monthly_savings',
        'loans',
        'loan_emis',
        'monthly_collections',
        'bank_loans',
        'incomes',
        'expenses',
        'bank_transactions',
        'cash_book',
        'bank_reconciliations',
        'stock_transactions',
        'sales',
        'sale_items',
        'contributions',
        'fines',
        'dues',
        'government_schemes',
        'scheme_applications',
        'documents',
        'trainings',
        'training_attendances',
        'events',
        'event_participants',
        'notifications',
        'audit_logs',
        'bonus_settings',
        'bonuses'
      ];

      const batchSize = 6;
      for (var i = 0; i < cloudTables.length; i += batchSize) {
        final chunk = cloudTables.skip(i).take(batchSize).toList();
        await Future.wait(chunk.map((table) => _pullTable(client, db, table, groupId)));
      }

      // Clean up dummy seed group if present
      try {
        await db.delete('groups', where: "id = 'group_offline_001'");
        await db.delete('profiles', where: "group_id = 'group_offline_001'");
      } catch (_) {}

      // Bump syncVersion so all UI providers reload their data
      syncVersion.value++;
    } catch (e) {
      debugPrint('pullAllTablesForGroup note: $e');
    }
  }

  /// Pull a single table from Supabase Cloud with group isolation and pending shield
  Future<void> _pullTable(
    SupabaseClient client,
    Database db,
    String table,
    String? currentGroupId,
  ) async {
    try {
      final validCols = await _getTableColumns(db, table);
      if (validCols.isEmpty) return;

      // Safeguard 2: Multi-Tenant Filter: Strictly pull records for active group only
      dynamic query = client.from(table).select();
      if (currentGroupId != null && currentGroupId.isNotEmpty) {
        if (table == 'groups') {
          query = query.eq('id', currentGroupId);
        } else if (validCols.contains('group_id')) {
          query = query.eq('group_id', currentGroupId);
        }
      }

      final dynamic response = await query.timeout(const Duration(seconds: 15));

      if (response is List && response.isNotEmpty) {
        // Safeguard 3: Shielding: Never overwrite locally edited rows that are currently pending in sync_queue!
        final pendingRes = await db.query(
          'sync_queue',
          columns: ['row_id'],
          where: "table_name = ? AND status IN ('pending', 'failed')",
          whereArgs: [table],
        );
        final pendingIds = pendingRes.map((r) => r['row_id'].toString()).toSet();

        // Use a single database transaction for ultra fast bulk insertion
        await db.transaction((txn) async {
          for (var r in response) {
            final row = Map<String, dynamic>.from(r as Map);
            final rowId = row['id']?.toString() ?? '';

            if (rowId.isNotEmpty && pendingIds.contains(rowId)) {
              // Skip incoming cloud row; user has newer unsynced local edits on this device!
              continue;
            }

            final sanitized = _sanitizeRowForSqlite(row, validCols);
            await txn.insert(
              table,
              sanitized,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        });
      }
    } catch (err) {
      debugPrint('Cloud pull note for $table: $err');
    }
  }

  Future<Set<String>> _getTableColumns(Database db, String table) async {
    try {
      final info = await db.rawQuery('PRAGMA table_info($table)');
      return info.map((r) => r['name'].toString()).toSet();
    } catch (_) {
      return {};
    }
  }

  /// Converts SQLite formatted row back to Supabase PostgreSQL types
  /// Safeguard 4: Complete boolean conversion to avoid PostgreSQL integer type rejection
  static Map<String, dynamic> formatRowForSupabase(String table, Map<String, dynamic> row) {
    final copy = Map<String, dynamic>.from(row);

    const boolCols = {
      'is_main_admin', 'can_view', 'can_add', 'can_edit', 'can_delete',
      'can_approve', 'can_export', 'can_print', 'attended', 'certificate_available',
      'is_completed', 'is_primary', 'is_read', 'biometric_enabled',
      'otp_login_enabled', 'pin_lock_enabled', 'is_verified', 'is_disbursed',
      'is_closed', 'is_paid', 'is_active',
    };

    for (var col in boolCols) {
      if (copy.containsKey(col)) {
        if (copy[col] is int) {
          copy[col] = (copy[col] == 1);
        } else if (copy[col] is String) {
          copy[col] = (copy[col] == '1' || copy[col].toLowerCase() == 'true');
        }
      }
    }

    // Global payment_mode enum converter (for all tables that use public.payment_mode_type)
    if (copy.containsKey('payment_mode') && copy['payment_mode'] != null) {
      final pm = copy['payment_mode'].toString().toLowerCase().trim();
      if (pm == 'bank' || pm == 'transfer' || pm == 'bank_transfer' || pm == 'बँक') {
        copy['payment_mode'] = 'bank_transfer';
      } else if (pm == 'online' || pm == 'upi' || pm == 'gpay' || pm == 'phonepe' || pm == 'ऑनलाइन') {
        copy['payment_mode'] = 'upi';
      } else if (pm == 'cheque' || pm == 'check' || pm == 'धनादेश') {
        copy['payment_mode'] = 'cheque';
      } else if (pm == 'cash' || pm == 'रोख') {
        copy['payment_mode'] = 'cash';
      } else if (['cash', 'bank_transfer', 'upi', 'cheque', 'neft_rtgs', 'credit', 'other'].contains(pm)) {
        copy['payment_mode'] = pm;
      } else {
        copy['payment_mode'] = 'bank_transfer';
      }
    }

    // Table-specific column mappings & removals
    if (table == 'savings') {
      if (copy.containsKey('transaction_number') && !copy.containsKey('reference_number')) {
        copy['reference_number'] = copy['transaction_number'];
      }
      copy.remove('transaction_number');
      copy.remove('created_by');

      if (copy.containsKey('savings_type') && copy['savings_type'] != null) {
        final st = copy['savings_type'].toString().toLowerCase().trim();
        if (st == 'regular' || st == 'compulsory' || st == 'standard' || st == 'नियमित') {
          copy['savings_type'] = 'monthly';
        } else if (!['monthly', 'weekly', 'special', 'festival', 'other'].contains(st)) {
          copy['savings_type'] = 'monthly';
        }
      }
    } else if (table == 'members') {
      copy.remove('created_by');
      copy.remove('updated_by');
      copy.remove('aadhaar_last_four');
      copy.remove('remarks');
    } else if (table == 'loans') {
      copy.remove('guarantor_1_id');
      copy.remove('guarantor_2_id');
      copy.remove('approved_by');
      copy.remove('created_by');
      copy.remove('outstanding_interest');
    } else if (table == 'loan_emis') {
      copy.remove('balance');
    } else if (table == 'incomes') {
      copy.remove('attachment_url');
      copy.remove('entered_by');
      copy.remove('transaction_number');
    } else if (table == 'expenses') {
      copy.remove('approved_by');
      copy.remove('attachment_url');
      copy.remove('entered_by');
    } else if (table == 'cash_book') {
      copy.remove('entered_by');
    } else if (table == 'bank_transactions') {
      if (!copy.containsKey('description') || copy['description'] == null || copy['description'].toString().trim().isEmpty) {
        copy['description'] = copy['purpose'] ?? copy['remarks'] ?? 'बँक व्यवहार';
      }
      if (!copy.containsKey('reference_number') || copy['reference_number'] == null || copy['reference_number'].toString().trim().isEmpty) {
        copy['reference_number'] = copy['transaction_number'] ?? copy['deposit_slip_or_cheque_no'];
      }
      if (!copy.containsKey('performed_by') || copy['performed_by'] == null || copy['performed_by'].toString().trim().isEmpty) {
        copy['performed_by'] = copy['created_by'] ?? 'System';
      }
      copy.remove('purpose');
      copy.remove('remarks');
      copy.remove('created_by');
      copy.remove('approved_by');
    }

    // Whitelist filter: Remove any column not in Supabase cloud schema
    final validCols = cloudTableColumns[table];
    if (validCols != null) {
      copy.removeWhere((k, _) => !validCols.contains(k));
    }

    // Remove any join prefixes
    copy.removeWhere((k, _) => k.startsWith('_'));

    return copy;
  }

  Map<String, dynamic> _formatRowForSupabase(String table, Map<String, dynamic> row) =>
      formatRowForSupabase(table, row);

  /// Converts Supabase PostgreSQL row to SQLite types
  Map<String, dynamic> _sanitizeRowForSqlite(Map<String, dynamic> raw, Set<String> validCols) {
    final sanitized = <String, dynamic>{};
    raw.forEach((k, v) {
      if (validCols.isEmpty || validCols.contains(k)) {
        if (v is bool) {
          sanitized[k] = v ? 1 : 0;
        } else if (v is Map || v is List) {
          sanitized[k] = jsonEncode(v);
        } else {
          sanitized[k] = v;
        }
      }
    });

    return sanitized;
  }
}
