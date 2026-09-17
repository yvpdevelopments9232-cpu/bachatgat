import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'app_config.dart';

class OfflineDbHelper {
  static final OfflineDbHelper instance = OfflineDbHelper._init();
  static Database? _database;
  static bool _ffiInitialized = false;

  OfflineDbHelper._init();

  static void initializeFfi() {
    if (_ffiInitialized) return;
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      if (Platform.isWindows) {
        // Load sqlite3.dll into process memory so Dart FFI fallback lookup resolves symbols
        final exeDir = File(Platform.resolvedExecutable).parent.path;
        final candidatePaths = [
          p.join(exeDir, 'sqlite3.dll'),
          p.join(Directory.current.path, 'sqlite3.dll'),
          p.join(Directory.current.path, 'dist', 'Windows_Offline', 'sqlite3.dll'),
          p.join(Directory.current.path, 'dist', 'Windows_Hybrid', 'sqlite3.dll'),
          'sqlite3.dll',
        ];
        bool loaded = false;
        for (final dllPath in candidatePaths) {
          try {
            if (File(dllPath).existsSync()) {
              DynamicLibrary.open(dllPath);
              loaded = true;
              debugPrint('Loaded sqlite3.dll from: $dllPath');
              break;
            }
          } catch (e) {
            debugPrint('Failed loading sqlite3 from $dllPath: $e');
          }
        }
        if (!loaded) {
          try {
            DynamicLibrary.open('sqlite3.dll');
          } catch (e) {
            debugPrint('Fallback dynamic open sqlite3.dll: $e');
          }
        }
      }
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      _ffiInitialized = true;
    }
  }

  static String generateId() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(256));
    values[6] = (values[6] & 0x0f) | 0x40; // version 4
    values[8] = (values[8] & 0x3f) | 0x80; // variant 1
    final hexChars = [
      for (int i = 0; i < 16; i++) values[i].toRadixString(16).padLeft(2, '0')
    ].join('');
    return '${hexChars.substring(0, 8)}-${hexChars.substring(8, 12)}-${hexChars.substring(12, 16)}-${hexChars.substring(16, 20)}-${hexChars.substring(20)}';
  }

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) return _database!;
    final String dbName;
    if (AppConfig.isHybridMode) {
      dbName = 'bachat_hybrid.db';
    } else if (AppConfig.isOfflineMode) {
      dbName = 'bachat_offline.db';
    } else {
      dbName = 'bachat_online.db';
    }
    _database = await _initDB(dbName);
    return _database!;
  }

  static void setDatabaseForTesting(Database? db) {
    _database = db;
  }

  Future<void> close() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }
  }

  Future<void> createAllTables(Database db) async {
    await _createDB(db, 1);
  }

  Future<String> getDatabasePath() async {
    final String dbName;
    if (AppConfig.isHybridMode) {
      dbName = 'bachat_hybrid.db';
    } else if (AppConfig.isOfflineMode) {
      dbName = 'bachat_offline.db';
    } else {
      dbName = 'bachat_online.db';
    }

    if (!kIsWeb && Platform.isWindows) {
      Directory? dbFolder;
      // 1. First priority: Create 'BachatDatabase' next to executable (portable folder on desktop/custom drive)
      try {
        final exeDir = File(Platform.resolvedExecutable).parent.path;
        final candidate = Directory(p.join(exeDir, 'BachatDatabase'));
        if (!await candidate.exists()) {
          await candidate.create(recursive: true);
        }
        // Test write permission to ensure it's not a read-only directory
        final testFile = File(p.join(candidate.path, '.test_write'));
        await testFile.writeAsString('ok');
        await testFile.delete();
        dbFolder = candidate;
      } catch (_) {
        dbFolder = null;
      }

      // 2. Fallback: If exe directory is not writable (e.g. Program Files), use %APPDATA%\BachatDatabase
      if (dbFolder == null) {
        final appData = Platform.environment['APPDATA'] ?? 
                        Platform.environment['USERPROFILE'] ?? 
                        Directory.current.path;
        dbFolder = Directory(p.join(appData, 'BachatDatabase'));
        if (!await dbFolder.exists()) {
          await dbFolder.create(recursive: true);
        }
      }

      final targetPath = p.join(dbFolder.path, dbName);

      // Automatic Migration: If target file doesn't exist yet, but legacy %APPDATA%\BachatGatManagement\dbName exists, copy it over!
      try {
        final targetFile = File(targetPath);
        if (!await targetFile.exists()) {
          final legacyAppData = Platform.environment['APPDATA'] ?? '';
          if (legacyAppData.isNotEmpty) {
            final legacyFile = File(p.join(legacyAppData, 'BachatGatManagement', dbName));
            if (await legacyFile.exists()) {
              await legacyFile.copy(targetPath);
              debugPrint('Migrated legacy database from ${legacyFile.path} to $targetPath');
            }
          }
        }
      } catch (e) {
        debugPrint('Legacy DB migration note: $e');
      }

      return targetPath;
    } else {
      // Android / iOS / Linux: Store inside 'BachatDatabase' folder
      Directory dbFolder;
      try {
        final databasesPath = await getDatabasesPath();
        dbFolder = Directory(p.join(databasesPath, 'BachatDatabase'));
        if (!await dbFolder.exists()) {
          await dbFolder.create(recursive: true);
        }
      } catch (e) {
        try {
          final docsDir = await getApplicationDocumentsDirectory();
          dbFolder = Directory(p.join(docsDir.path, 'BachatDatabase'));
          if (!await dbFolder.exists()) {
            await dbFolder.create(recursive: true);
          }
        } catch (_) {
          return dbName;
        }
      }

      final targetPath = p.join(dbFolder.path, dbName);

      // Automatic Migration on Android if legacy database exists directly in databasesPath
      try {
        final targetFile = File(targetPath);
        if (!await targetFile.exists()) {
          final databasesPath = await getDatabasesPath();
          final legacyFile = File(p.join(databasesPath, dbName));
          if (await legacyFile.exists()) {
            await legacyFile.copy(targetPath);
            debugPrint('Migrated legacy Android database to $targetPath');
          }
        }
      } catch (_) {}

      return targetPath;
    }
  }

  Future<Database> _initDB(String filePath) async {
    initializeFfi();

    final path = await getDatabasePath();

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
      onOpen: (db) async {
        try {
          // 1. Flush any pending WAL transactions into the main database file
          await db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE);');
          // 2. Set journal_mode to DELETE so SQLite strictly keeps ONLY 1 SINGLE .db file
          // (removes .db-wal and .db-shm files automatically)
          await db.execute('PRAGMA journal_mode = DELETE;');
          await db.execute('PRAGMA synchronous = NORMAL;');
        } catch (_) {}
        await _ensureSystemTables(db);
        await _ensureMemberColumns(db);
        await _ensureBankAccountColumns(db);
        await _ensureSavingsColumns(db);
        await _ensureBonusTables(db);
        await _ensureMonthlyCollectionTable(db);
        await _repairMissingLoanEmisFromCollections(db);
        await _repairMissingBankAndCashFromCollections(db);
        await _reconcileAllLoanBalances(db);
        try {
          // Reset previously failed items caused by schema cache column mismatches so they retry cleanly
          await db.rawUpdate("UPDATE sync_queue SET status = 'pending', retry_count = 0 WHERE status = 'failed' AND (error_message LIKE '%purpose%' OR error_message LIKE '%guarantor%' OR error_message LIKE '%approved_by%' OR error_message LIKE '%payment_mode%' OR error_message LIKE '%savings_category%' OR error_message LIKE '%balance%' OR error_message LIKE '%schema cache%')");
        } catch (_) {}
        await _seedDefaultData(db);

        // Extra cleanup: ensure no orphaned .db-wal or .db-shm files remain in folder
        try {
          final walFile = File('$path-wal');
          if (await walFile.exists()) await walFile.delete();
          final shmFile = File('$path-shm');
          if (await shmFile.exists()) await shmFile.delete();
        } catch (_) {}
      },
    );
  }

  Future<void> _ensureSystemTables(Database db) async {
    // 1. Offline Users Table (local authentication)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS offline_users (
        id TEXT PRIMARY KEY,
        group_id TEXT,
        email TEXT UNIQUE,
        mobile TEXT,
        password TEXT NOT NULL,
        name TEXT,
        role TEXT DEFAULT 'admin',
        created_at TEXT
      )
    ''');

    // 2. Hybrid Sync Queue Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL,
        row_id TEXT NOT NULL,
        action TEXT NOT NULL,
        payload TEXT,
        created_at TEXT NOT NULL,
        status TEXT DEFAULT 'pending',
        error_message TEXT,
        retry_count INTEGER DEFAULT 0
      )
    ''');

    try {
      await db.execute('ALTER TABLE sync_queue ADD COLUMN retry_count INTEGER DEFAULT 0');
    } catch (_) {}

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_sync_queue_status ON sync_queue (status)
    ''');

    // 3. Sync Metadata Table (tracks last sync timestamp per table)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_metadata (
        table_name TEXT PRIMARY KEY,
        last_pulled_at TEXT
      )
    ''');
  }

  Future<void> _ensureMemberColumns(Database db) async {
    try {
      final info = await db.rawQuery("PRAGMA table_info('members')");
      final existingCols = info.map((r) => r['name'].toString().toLowerCase()).toSet();

      final newCols = {
        'aadhaar_number': 'TEXT',
        'pan_number': 'TEXT',
        'annual_income': 'REAL',
        'nominee_age': 'INTEGER',
        'branch_name': 'TEXT',
        'role_in_group': "TEXT DEFAULT 'सदस्य'",
        'signature_url': 'TEXT',
        'aadhaar_doc_url': 'TEXT',
        'pan_doc_url': 'TEXT',
        'passbook_doc_url': 'TEXT',
        'remarks': 'TEXT',
        'account_holder_name': 'TEXT',
        'aadhaar_last_four': 'TEXT',
      };

      for (var entry in newCols.entries) {
        if (!existingCols.contains(entry.key.toLowerCase())) {
          try {
            await db.execute('ALTER TABLE members ADD COLUMN ${entry.key} ${entry.value}');
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  Future<void> _ensureBankAccountColumns(Database db) async {
    try {
      final info = await db.rawQuery("PRAGMA table_info('bank_accounts')");
      final existingCols = info.map((r) => r['name'].toString().toLowerCase()).toSet();

      final newCols = {
        'opening_balance_date': 'TEXT',
        'bank_address': 'TEXT',
        'mobile_number': 'TEXT',
        'email': 'TEXT',
        'notes': 'TEXT',
      };

      for (var entry in newCols.entries) {
        if (!existingCols.contains(entry.key.toLowerCase())) {
          try {
            await db.execute('ALTER TABLE bank_accounts ADD COLUMN ${entry.key} ${entry.value}');
          } catch (_) {}
        }
      }

      final txInfo = await db.rawQuery("PRAGMA table_info('bank_transactions')");
      final existingTxCols = txInfo.map((r) => r['name'].toString().toLowerCase()).toSet();
      for (var col in ['payment_mode', 'reference_number', 'description']) {
        if (!existingTxCols.contains(col)) {
          try {
            await db.execute('ALTER TABLE bank_transactions ADD COLUMN $col TEXT');
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  Future<void> ensureBonusTables(Database db) => _ensureBonusTables(db);

  Future<void> _ensureBonusTables(Database db) async {
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS bonus_settings (
          id TEXT PRIMARY KEY,
          group_id TEXT,
          setting_name TEXT DEFAULT 'Savings Bonus',
          bonus_type TEXT DEFAULT 'percentage_of_savings',
          calculation_method TEXT DEFAULT 'percentage',
          bonus_percentage REAL DEFAULT 5.0,
          fixed_amount REAL DEFAULT 0.0,
          min_eligibility REAL DEFAULT 0.0,
          max_bonus REAL DEFAULT 5000.0,
          effective_from TEXT,
          effective_to TEXT,
          is_active INTEGER DEFAULT 1,
          created_at TEXT,
          updated_at TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS bonuses (
          id TEXT PRIMARY KEY,
          group_id TEXT,
          member_id TEXT,
          financial_year TEXT DEFAULT '2025 - 2026',
          from_date TEXT,
          to_date TEXT,
          bonus_type TEXT DEFAULT 'savings',
          basis_amount REAL DEFAULT 0.0,
          bonus_rate REAL DEFAULT 5.0,
          bonus_amount REAL DEFAULT 0.0,
          paid_amount REAL DEFAULT 0.0,
          status TEXT DEFAULT 'draft',
          approved_by TEXT,
          approved_at TEXT,
          payment_date TEXT,
          payment_mode TEXT,
          bank_account_id TEXT,
          transaction_ref TEXT,
          remarks TEXT,
          created_at TEXT,
          updated_at TEXT
        )
      ''');

      await db.execute('CREATE INDEX IF NOT EXISTS idx_bonuses_group_id ON bonuses(group_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_bonuses_member_id ON bonuses(member_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_bonuses_status ON bonuses(status)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_bonus_settings_group_id ON bonus_settings(group_id)');
    } catch (e) {
      debugPrint('Error ensuring bonus tables: $e');
    }
  }

  Future<void> ensureMonthlyCollectionTable(Database db) => _ensureMonthlyCollectionTable(db);

  Future<void> _ensureMonthlyCollectionTable(Database db) async {
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS monthly_collections (
          id TEXT PRIMARY KEY,
          group_id TEXT,
          member_id TEXT NOT NULL,
          loan_id TEXT,
          bank_account_id TEXT,
          collection_date TEXT NOT NULL,
          monthly_saving REAL DEFAULT 0.0,
          required_emi REAL DEFAULT 0.0,
          paid_emi REAL DEFAULT 0.0,
          principal_amount REAL DEFAULT 0.0,
          interest_amount REAL DEFAULT 0.0,
          remaining_emi REAL DEFAULT 0.0,
          total_collection REAL DEFAULT 0.0,
          payment_status TEXT DEFAULT 'paid',
          payment_mode TEXT DEFAULT 'cash',
          reference_no TEXT,
          notes TEXT,
          created_by TEXT,
          created_at TEXT,
          updated_at TEXT
        )
      ''');

      try {
        await db.execute('ALTER TABLE monthly_collections ADD COLUMN bank_account_id TEXT');
      } catch (_) {}

      await db.execute('CREATE INDEX IF NOT EXISTS idx_monthly_collections_group ON monthly_collections(group_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_monthly_collections_member ON monthly_collections(member_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_monthly_collections_date ON monthly_collections(collection_date)');
    } catch (e) {
      debugPrint('Error ensuring monthly_collections table: $e');
    }
  }

  Future<void> _ensureSavingsColumns(Database db) async {
    try {
      final info = await db.rawQuery("PRAGMA table_info('savings')");
      final existingCols = info.map((r) => r['name'].toString().toLowerCase()).toSet();
      if (!existingCols.contains('reference_number')) {
        try {
          await db.execute('ALTER TABLE savings ADD COLUMN reference_number TEXT');
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error ensuring savings columns: $e');
    }
  }

  Future<void> repairMissingLoanEmis() async {
    final db = await database;
    await _repairMissingLoanEmisFromCollections(db);
  }

  Future<void> _repairMissingLoanEmisFromCollections(Database db) async {
    try {
      final mcRows = await db.query(
        'monthly_collections',
        where: "loan_id IS NOT NULL AND loan_id != '' AND paid_emi > 0",
      );

      for (var mc in mcRows) {
        final mcId = mc['id']?.toString() ?? '';
        final loanId = mc['loan_id']?.toString() ?? '';
        final groupId = mc['group_id']?.toString() ?? '';
        final paidEmi = (mc['paid_emi'] as num?)?.toDouble() ?? 0.0;
        final principal = (mc['principal_amount'] as num?)?.toDouble() ?? 0.0;
        final interest = (mc['interest_amount'] as num?)?.toDouble() ?? 0.0;
        final dateStr = mc['collection_date']?.toString() ?? '';
        final paymentMode = mc['payment_mode']?.toString() ?? 'cash';
        final refNo = mc['reference_no']?.toString() ?? '';
        final createdBy = mc['created_by']?.toString() ?? 'admin';
        final nowStr = DateTime.now().toIso8601String();

        if (loanId.isEmpty || paidEmi <= 0) continue;

        final loanRows = await db.query('loans', where: 'id = ?', whereArgs: [loanId]);
        if (loanRows.isEmpty) continue;
        final loan = loanRows.first;

        final emiCheck = await db.query(
          'loan_emis',
          where: "loan_id = ? AND (receipt_number LIKE ? OR remarks LIKE ?)",
          whereArgs: [loanId, '%$mcId%', '%$mcId%'],
        );

        if (emiCheck.isEmpty) {
          final curOutstanding = (loan['outstanding_principal'] as num?)?.toDouble() ?? 0.0;
          final curRepaid = (loan['total_repaid'] as num?)?.toDouble() ?? 0.0;

          final newOutstanding = (curOutstanding - principal) > 0 ? (curOutstanding - principal) : 0.0;
          final newRepaid = curRepaid + paidEmi;
          final newStatus = newOutstanding <= 0.01 ? 'closed' : 'active';

          await db.update('loans', {
            'outstanding_principal': newOutstanding,
            'total_repaid': newRepaid,
            'status': newStatus,
            'updated_at': nowStr,
          }, where: 'id = ?', whereArgs: [loanId]);

          final existingEmis = await db.query('loan_emis', where: 'loan_id = ?', whereArgs: [loanId]);
          final nextEmiNum = existingEmis.length + 1;

          final emiId = generateId();
          final emiData = {
            'id': emiId,
            'group_id': groupId,
            'loan_id': loanId,
            'emi_number': nextEmiNum,
            'due_date': dateStr,
            'payment_date': dateStr,
            'emi_amount': (mc['required_emi'] as num?)?.toDouble() ?? paidEmi,
            'principal': principal,
            'interest': interest,
            'paid_amount': paidEmi,
            'status': 'paid',
            'payment_mode': paymentMode,
            'receipt_number': refNo.isNotEmpty ? refNo : 'MC-EMI-$mcId',
            'remarks': 'मासिक संकलन हप्ता जमा (शिल्लक मुद्दल: ₹${newOutstanding.toStringAsFixed(2)}) [MC-$mcId]',
            'collected_by': createdBy,
            'created_at': nowStr,
            'updated_at': nowStr,
          };
          await db.insert('loan_emis', emiData);

          if (!AppConfig.isOfflineOnly) {
            await enqueueSync(
              tableName: 'loans',
              rowId: loanId,
              action: 'UPDATE',
              payload: jsonEncode({
                'id': loanId,
                'outstanding_principal': newOutstanding,
                'total_repaid': newRepaid,
                'status': newStatus,
                'updated_at': nowStr,
              }),
            );
            await enqueueSync(
              tableName: 'loan_emis',
              rowId: emiId,
              action: 'INSERT',
              payload: jsonEncode(emiData),
            );
          }
          debugPrint('Auto-repaired missing loan EMI for collection $mcId on loan $loanId');
        }
      }
    } catch (e) {
      debugPrint('Error repairing missing loan EMIs: $e');
    }
  }

  Future<void> reconcileAllLoanBalances() async {
    final db = await database;
    await _reconcileAllLoanBalances(db);
  }

  Future<void> _reconcileAllLoanBalances(Database db) async {
    try {
      final loans = await db.query('loans');
      for (var loan in loans) {
        final loanId = loan['id']?.toString() ?? '';
        if (loanId.isEmpty) continue;
        final approvedAmount = (loan['approved_amount'] as num?)?.toDouble() ?? 0.0;
        final curOutstanding = (loan['outstanding_principal'] as num?)?.toDouble() ?? approvedAmount;
        final curRepaid = (loan['total_repaid'] as num?)?.toDouble() ?? 0.0;

        final emiSum = await db.rawQuery('''
          SELECT 
            COALESCE(SUM(principal), 0.0) AS total_principal,
            COALESCE(SUM(CASE WHEN paid_amount > 0 THEN paid_amount ELSE (principal + interest) END), 0.0) AS total_repaid
          FROM loan_emis
          WHERE loan_id = ? AND status = 'paid'
        ''', [loanId]);

        if (emiSum.isEmpty) continue;
        final paidPrincipal = (emiSum.first['total_principal'] as num?)?.toDouble() ?? 0.0;
        final paidTotal = (emiSum.first['total_repaid'] as num?)?.toDouble() ?? 0.0;

        if (paidPrincipal > 0 || paidTotal > 0) {
          final realOutstanding = max(0.0, approvedAmount - paidPrincipal);
          final newStatus = realOutstanding <= 0.01 ? 'closed' : (loan['status']?.toString() ?? 'disbursed');

          if ((curOutstanding - realOutstanding).abs() > 0.01 || (curRepaid - paidTotal).abs() > 0.01) {
            final nowStr = DateTime.now().toIso8601String();
            await db.update('loans', {
              'outstanding_principal': realOutstanding,
              'total_repaid': paidTotal,
              'status': newStatus,
              'updated_at': nowStr,
            }, where: 'id = ?', whereArgs: [loanId]);

            if (!AppConfig.isOfflineOnly) {
              await enqueueSync(
                tableName: 'loans',
                rowId: loanId,
                action: 'UPDATE',
                payload: jsonEncode({
                  'id': loanId,
                  'outstanding_principal': realOutstanding,
                  'total_repaid': paidTotal,
                  'status': newStatus,
                  'updated_at': nowStr,
                }),
              );
            }
            debugPrint('Auto-reconciled loan $loanId: outstanding $curOutstanding -> $realOutstanding, repaid $curRepaid -> $paidTotal');
          }
        }
      }
    } catch (e) {
      debugPrint('Error reconciling loan balances: $e');
    }
  }

  Future<void> _repairMissingBankAndCashFromCollections(Database db) async {
    try {
      final tableCheck = await db.rawQuery(
        "SELECT count(*) AS c FROM sqlite_master WHERE type='table' AND name='monthly_collections'",
      );
      if ((tableCheck.first['c'] as num?)?.toInt() == 0) return;

      final mcRows = await db.query('monthly_collections');
      for (var mc in mcRows) {
        final mcId = mc['id']?.toString() ?? '';
        final groupId = mc['group_id']?.toString() ?? '';
        final memberId = mc['member_id']?.toString() ?? '';
        final bankAccountId = mc['bank_account_id']?.toString();
        final paymentMode = (mc['payment_mode']?.toString() ?? 'cash').toLowerCase();
        final totalCollection = (mc['total_collection'] as num?)?.toDouble() ?? 0.0;
        final monthlySaving = (mc['monthly_saving'] as num?)?.toDouble() ?? 0.0;
        final dateStr = mc['collection_date']?.toString() ?? '';
        final refNo = mc['reference_no']?.toString() ?? '';
        final createdBy = mc['created_by']?.toString() ?? 'admin';
        final nowStr = DateTime.now().toIso8601String();

        if (totalCollection <= 0 || mcId.isEmpty) continue;

        // 1. Repair Bank Account and Bank Transactions if bank / online payment
        if ((paymentMode == 'bank' || paymentMode == 'online') && bankAccountId != null && bankAccountId.isNotEmpty) {
          final txCheck = await db.query(
            'bank_transactions',
            where: 'bank_account_id = ? AND (remarks LIKE ? OR transaction_number LIKE ?)',
            whereArgs: [bankAccountId, '%$mcId%', '%$mcId%'],
          );

          if (txCheck.isEmpty) {
            final bRows = await db.query('bank_accounts', where: 'id = ?', whereArgs: [bankAccountId]);
            if (bRows.isNotEmpty) {
              final curBal = (bRows.first['current_balance'] as num?)?.toDouble() ?? 0.0;
              final newBal = curBal + totalCollection;
              await db.update('bank_accounts', {'current_balance': newBal, 'updated_at': nowStr},
                  where: 'id = ?', whereArgs: [bankAccountId]);

              final txId = generateId();
              final txData = {
                'id': txId,
                'group_id': groupId,
                'bank_account_id': bankAccountId,
                'transaction_date': dateStr,
                'type': 'deposit',
                'amount': totalCollection,
                'purpose': 'मासिक संकलन जमा',
                'remarks': 'मासिक संकलन [MC-$mcId]',
                'balance_after': newBal,
                'transaction_number': refNo.isNotEmpty ? refNo : 'MC-$mcId',
                'deposit_slip_or_cheque_no': refNo.isNotEmpty ? refNo : null,
                'performed_by': createdBy,
                'created_by': createdBy,
                'created_at': nowStr,
              };
              await db.insert('bank_transactions', txData);

              if (!AppConfig.isOfflineOnly) {
                await enqueueSync(
                  tableName: 'bank_accounts',
                  rowId: bankAccountId,
                  action: 'UPDATE',
                  payload: jsonEncode({'id': bankAccountId, 'current_balance': newBal}),
                );
                await enqueueSync(
                  tableName: 'bank_transactions',
                  rowId: txId,
                  action: 'INSERT',
                  payload: jsonEncode(txData),
                );
              }
              debugPrint('Auto-repaired missing bank deposit for collection $mcId on bank $bankAccountId (+₹$totalCollection)');
            }
          }
        }

        // 2. Repair Cash Book if cash payment
        if (paymentMode == 'cash') {
          final cashCheck = await db.query(
            'cash_book',
            where: "reference_module = 'monthly_collections' AND reference_id = ?",
            whereArgs: [mcId],
          );

          if (cashCheck.isEmpty) {
            final lastCash = await db.rawQuery(
              'SELECT balance_after FROM cash_book WHERE group_id = ? ORDER BY entry_date DESC, created_at DESC, id DESC LIMIT 1',
              [groupId],
            );
            final prevCash = lastCash.isNotEmpty ? ((lastCash.first['balance_after'] as num?)?.toDouble() ?? 0.0) : 0.0;
            final newCashBal = prevCash + totalCollection;

            final cashBookId = generateId();
            final cashData = {
              'id': cashBookId,
              'group_id': groupId,
              'entry_date': dateStr,
              'type': 'receipt',
              'amount': totalCollection,
              'balance_after': newCashBal,
              'description': 'मासिक संकलन [MC-$mcId]',
              'reference_module': 'monthly_collections',
              'reference_id': mcId,
              'entered_by': createdBy,
              'created_at': nowStr,
            };
            await db.insert('cash_book', cashData);

            if (!AppConfig.isOfflineOnly) {
              await enqueueSync(
                tableName: 'cash_book',
                rowId: cashBookId,
                action: 'INSERT',
                payload: jsonEncode(cashData),
              );
            }
            debugPrint('Auto-repaired missing cash_book for collection $mcId (+₹$totalCollection)');
          }
        }

        // 3. Repair Savings record if savings paid
        if (monthlySaving > 0) {
          final savCheck = await db.query(
            'savings',
            where: 'member_id = ? AND (receipt_number LIKE ? OR reference_number LIKE ? OR remarks LIKE ?)',
            whereArgs: [memberId, '%$mcId%', '%$mcId%', '%$mcId%'],
          );

          if (savCheck.isEmpty) {
            final savId = generateId();
            final savData = {
              'id': savId,
              'group_id': groupId,
              'member_id': memberId,
              'savings_date': dateStr,
              'amount': monthlySaving,
              'savings_type': 'regular',
              'payment_mode': paymentMode,
              'receipt_number': refNo.isNotEmpty ? refNo : 'MC-$mcId',
              'reference_number': refNo.isNotEmpty ? refNo : 'MC-$mcId',
              'transaction_number': refNo.isNotEmpty ? refNo : 'MC-$mcId',
              'collected_by': createdBy,
              'remarks': 'मासिक संकलन बचत नोंद [MC-$mcId]',
              'created_by': createdBy,
              'created_at': nowStr,
              'updated_at': nowStr,
            };
            await db.insert('savings', savData);

            if (!AppConfig.isOfflineOnly) {
              await enqueueSync(
                tableName: 'savings',
                rowId: savId,
                action: 'INSERT',
                payload: jsonEncode(savData),
              );
            }
            debugPrint('Auto-repaired missing savings for collection $mcId (+₹$monthlySaving)');
          }
        }
      }
    } catch (e) {
      debugPrint('Error repairing missing bank and cash from collections: $e');
    }
  }

  Future<void> _seedDefaultData(Database db) async {
    try {
      // Ensure groups table exists before seeding
      final groupTableCheck = await db.rawQuery(
        "SELECT count(*) AS c FROM sqlite_master WHERE type='table' AND name='groups'",
      );
      final hasGroupsTable = (groupTableCheck.first['c'] as num?)?.toInt() ?? 0;
      if (hasGroupsTable == 0) return;

      final countRes = await db.rawQuery('SELECT COUNT(*) AS c FROM offline_users');
      final count = (countRes.first['c'] as num?)?.toInt() ?? 0;
      if (count == 0) {
        final defaultGroupId = generateId();
        final defaultUserId = generateId();
        final nowStr = DateTime.now().toIso8601String();

        // Insert default offline group
        await db.insert('groups', {
          'id': defaultGroupId,
          'group_name': 'सखी महिला बचत गट (Offline)',
          'village': 'पुणे',
          'taluka': 'हवेली',
          'district': 'पुणे',
          'mobile': '9876543210',
          'email': 'admin@bachatgat.local',
          'president_name': 'अध्यक्षा',
          'secretary_name': 'सचिवा',
          'treasurer_name': 'खजिनदार',
          'monthly_savings_amount': 200.0,
          'savings_due_day': 10,
          'default_loan_interest_rate': 12.0,
          'late_fee_per_day': 5.0,
          'meeting_absence_fine': 50.0,
          'status': 'active',
          'created_at': nowStr,
          'updated_at': nowStr,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);

        // Insert default offline user
        await db.insert('offline_users', {
          'id': defaultUserId,
          'group_id': defaultGroupId,
          'email': 'admin@gmail.com',
          'mobile': '9876543210',
          'password': '1234',
          'name': 'प्रशासक (Admin)',
          'role': 'admin',
          'created_at': nowStr,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);

        // Insert corresponding profile
        await db.insert('profiles', {
          'id': defaultUserId,
          'group_id': defaultGroupId,
          'full_name': 'प्रशासक (Admin)',
          'mobile': '9876543210',
          'email': 'admin@gmail.com',
          'role': 'admin',
          'status': 'active',
          'is_main_admin': 1,
          'created_at': nowStr,
          'updated_at': nowStr,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);

        // Insert default settings
        await db.insert('settings', {
          'id': generateId(),
          'group_id': defaultGroupId,
          'language': 'mr',
          'currency': 'INR',
          'currency_symbol': '₹',
          'date_format': 'dd-MM-yyyy',
          'receipt_prefix': 'REC',
          'invoice_prefix': 'INV',
          'voucher_prefix': 'VCH',
          'created_at': nowStr,
          'updated_at': nowStr,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    } catch (e) {
      debugPrint('Seed data note: $e');
    }
  }

  Future<void> _createDB(Database db, int version) async {
    await _ensureSystemTables(db);
    await _ensureBonusTables(db);
    await _ensureMonthlyCollectionTable(db);

    // Table: groups
    await db.execute('''
      CREATE TABLE IF NOT EXISTS groups (
        id TEXT PRIMARY KEY,
        group_name TEXT,
        registration_number TEXT,
        formation_date TEXT,
        address TEXT,
        village TEXT,
        taluka TEXT,
        district TEXT,
        pincode TEXT,
        mobile TEXT,
        email TEXT,
        president_name TEXT,
        secretary_name TEXT,
        treasurer_name TEXT,
        logo_url TEXT,
        monthly_savings_amount REAL DEFAULT 200.00,
        savings_due_day INTEGER DEFAULT 10,
        default_loan_interest_rate REAL DEFAULT 12.00,
        late_fee_per_day REAL DEFAULT 5.00,
        meeting_absence_fine REAL DEFAULT 50.00,
        status TEXT DEFAULT 'active',
        created_at TEXT,
        updated_at TEXT
      )
    ''');
    // Table: profiles
    await db.execute('''
      CREATE TABLE IF NOT EXISTS profiles (
        id TEXT PRIMARY KEY,
        group_id TEXT,
        full_name TEXT,
        mobile TEXT,
        email TEXT,
        profile_photo_url TEXT,
        role TEXT DEFAULT 'employee',
        status TEXT DEFAULT 'active',
        joining_date TEXT,
        is_main_admin INTEGER DEFAULT 0,
        last_login_at TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');
    // Table: user_permissions
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_permissions (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        group_id TEXT,
        module TEXT,
        can_view INTEGER DEFAULT 0,
        can_add INTEGER DEFAULT 0,
        can_edit INTEGER DEFAULT 0,
        can_delete INTEGER DEFAULT 0,
        can_approve INTEGER DEFAULT 0,
        can_print INTEGER DEFAULT 0,
        can_export INTEGER DEFAULT 0,
        created_at TEXT,
        updated_at TEXT
      )
    ''');
    // Table: members
    await db.execute('''
      CREATE TABLE IF NOT EXISTS members (
        id TEXT PRIMARY KEY,
        group_id TEXT,
        member_code TEXT,
        full_name TEXT,
        photo_url TEXT,
        mobile_number TEXT,
        alternate_mobile TEXT,
        date_of_birth TEXT,
        gender TEXT DEFAULT 'Female',
        address TEXT,
        village TEXT,
        taluka TEXT,
        district TEXT,
        pincode TEXT,
        aadhaar_number TEXT,
        aadhaar_last_four TEXT,
        pan_number TEXT,
        joining_date TEXT,
        occupation TEXT,
        education TEXT,
        annual_income REAL,
        nominee_name TEXT,
        nominee_relation TEXT,
        nominee_mobile TEXT,
        nominee_age INTEGER,
        bank_name TEXT,
        branch_name TEXT,
        account_number TEXT,
        ifsc TEXT,
        account_holder_name TEXT,
        role_in_group TEXT DEFAULT 'सदस्य',
        status TEXT DEFAULT 'active',
        remarks TEXT,
        signature_url TEXT,
        aadhaar_doc_url TEXT,
        pan_doc_url TEXT,
        passbook_doc_url TEXT,
        created_by TEXT,
        updated_by TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');
    // Table: savings
    await db.execute('''
      CREATE TABLE IF NOT EXISTS savings (
        id TEXT PRIMARY KEY,
        group_id TEXT,
        member_id TEXT,
        savings_date TEXT,
        savings_type TEXT DEFAULT 'monthly',
        amount REAL,
        payment_mode TEXT DEFAULT 'cash',
        transaction_number TEXT,
        receipt_number TEXT,
        reference_number TEXT,
        collected_by TEXT,
        remarks TEXT,
        created_by TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');
    // Table: loans
    await db.execute('''
      CREATE TABLE IF NOT EXISTS loans (
        id TEXT PRIMARY KEY,
        group_id TEXT,
        member_id TEXT,
        loan_code TEXT,
        application_date TEXT,
        loan_type TEXT DEFAULT 'personal',
        requested_amount REAL,
        approved_amount REAL,
        purpose TEXT,
        interest_rate REAL,
        interest_type TEXT DEFAULT 'reducing',
        loan_period_months INTEGER,
        emi_amount REAL,
        number_of_emis INTEGER,
        first_emi_date TEXT,
        approval_date TEXT,
        disbursement_date TEXT,
        approved_by TEXT,
        guarantor_1_id TEXT,
        guarantor_2_id TEXT,
        outstanding_principal REAL DEFAULT 0,
        outstanding_interest REAL DEFAULT 0,
        total_repaid REAL DEFAULT 0,
        settlement_date TEXT,
        status TEXT DEFAULT 'applied',
        remarks TEXT,
        created_by TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');
    // Table: loan_emis
    await db.execute('''
      CREATE TABLE IF NOT EXISTS loan_emis (
        id TEXT PRIMARY KEY,
        group_id TEXT,
        loan_id TEXT,
        emi_number INTEGER,
        due_date TEXT,
        principal REAL DEFAULT 0,
        interest REAL DEFAULT 0,
        emi_amount REAL,
        late_fee REAL DEFAULT 0,
        paid_amount REAL DEFAULT 0,
        payment_date TEXT,
        payment_mode TEXT,
        transaction_id TEXT,
        receipt_number TEXT,
        balance REAL DEFAULT 0,
        status TEXT DEFAULT 'pending',
        collected_by TEXT,
        remarks TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');
    // Table: meetings
    await db.execute('''
      CREATE TABLE IF NOT EXISTS meetings (
        id TEXT PRIMARY KEY,
        group_id TEXT,
        meeting_date TEXT,
        meeting_time TEXT,
        location TEXT,
        meeting_type TEXT DEFAULT 'monthly',
        agenda TEXT,
        organizer_id TEXT,
        description TEXT,
        minutes_of_meeting TEXT,
        status TEXT DEFAULT 'scheduled',
        created_by TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');
    // Table: meeting_attendance
    await db.execute('''
      CREATE TABLE IF NOT EXISTS meeting_attendance (
        id TEXT PRIMARY KEY,
        group_id TEXT,
        meeting_id TEXT,
        member_id TEXT,
        status TEXT DEFAULT 'present',
        arrival_time TEXT,
        remarks TEXT,
        marked_by TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');
    // Table: resolutions
    await db.execute('''
      CREATE TABLE IF NOT EXISTS resolutions (
        id TEXT PRIMARY KEY,
        group_id TEXT,
        meeting_id TEXT,
        title TEXT,
        description TEXT,
        proposed_by TEXT,
        resolution_date TEXT,
        status TEXT DEFAULT 'proposed',
        votes_yes INTEGER DEFAULT 0,
        votes_no INTEGER DEFAULT 0,
        votes_abstain INTEGER DEFAULT 0,
        created_by TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');
    // Table: resolution_votes
    await db.execute('''
      CREATE TABLE IF NOT EXISTS resolution_votes (
        id TEXT PRIMARY KEY,
        group_id TEXT,
        resolution_id TEXT,
        member_id TEXT,
        vote TEXT,
        voted_at TEXT
      )
    ''');
    // Table: incomes
    await db.execute('''
      CREATE TABLE IF NOT EXISTS incomes (
        id TEXT PRIMARY KEY,
        group_id TEXT,
        income_date TEXT,
        category TEXT,
        amount REAL,
        payment_mode TEXT DEFAULT 'cash',
        received_from TEXT,
        transaction_number TEXT,
        receipt_number TEXT,
        description TEXT,
        attachment_url TEXT,
        entered_by TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');
    // Table: expenses
    await db.execute('''
      CREATE TABLE IF NOT EXISTS expenses (
        id TEXT PRIMARY KEY,
        group_id TEXT,
        expense_date TEXT,
        category TEXT,
        amount REAL,
        payment_mode TEXT DEFAULT 'cash',
        paid_to TEXT,
        bill_number TEXT,
        description TEXT,
        attachment_url TEXT,
        approved_by TEXT,
        entered_by TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');
    // Table: bank_accounts
    await db.execute('''
      CREATE TABLE IF NOT EXISTS bank_accounts (
        id TEXT PRIMARY KEY,
        group_id TEXT,
        bank_name TEXT,
        branch TEXT,
        account_number TEXT,
        ifsc TEXT,
        account_type TEXT DEFAULT 'savings',
        account_holder TEXT,
        opening_balance REAL DEFAULT 0.00,
        opening_balance_date TEXT,
        current_balance REAL DEFAULT 0.00,
        is_primary INTEGER DEFAULT 0,
        status TEXT DEFAULT 'active',
        bank_address TEXT,
        mobile_number TEXT,
        email TEXT,
        notes TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');
    // Table: bank_transactions
    await db.execute('''
      CREATE TABLE IF NOT EXISTS bank_transactions (
        id TEXT PRIMARY KEY,
        group_id TEXT,
        bank_account_id TEXT,
        transaction_date TEXT,
        type TEXT,
        amount REAL,
        deposit_slip_or_cheque_no TEXT,
        transaction_number TEXT,
        purpose TEXT,
        performed_by TEXT,
        approved_by TEXT,
        balance_after REAL,
        remarks TEXT,
        created_by TEXT,
        created_at TEXT
      )
    ''');
    // Table: cash_book
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cash_book (
        id TEXT PRIMARY KEY,
        group_id TEXT,
        entry_date TEXT,
        type TEXT,
        amount REAL,
        balance_after REAL,
        description TEXT,
        reference_module TEXT,
        reference_id TEXT,
        entered_by TEXT,
        created_at TEXT
      )
    ''');
    // Table: bank_reconciliations
    await db.execute('''
      CREATE TABLE IF NOT EXISTS bank_reconciliations (
        id TEXT PRIMARY KEY,
        group_id TEXT,
        bank_account_id TEXT,
        reconciliation_date TEXT,
        app_balance REAL,
        bank_statement_balance REAL,
        difference REAL,
        status TEXT DEFAULT 'matched',
        remarks TEXT,
        reconciled_by TEXT,
        created_at TEXT
      )
    ''');
    // Table: product_categories
    await db.execute('''
      CREATE TABLE IF NOT EXISTS product_categories (
        id TEXT PRIMARY KEY,
        group_id TEXT,
        name TEXT,
        description TEXT,
        created_at TEXT
      )
    ''');
    // Table: products
    await db.execute('''
      CREATE TABLE IF NOT EXISTS products (
        id TEXT PRIMARY KEY,
        group_id TEXT,
        category_id TEXT,
        product_code TEXT,
        product_name TEXT,
        category_name TEXT,
        description TEXT,
        unit TEXT DEFAULT 'kg',
        purchase_cost REAL DEFAULT 0.00,
        production_cost REAL DEFAULT 0.00,
        selling_price REAL,
        minimum_stock REAL DEFAULT 5.00,
        current_stock REAL DEFAULT 0.00,
        product_image_url TEXT,
        status TEXT DEFAULT 'active',
        created_by TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');
    // Table: suppliers
    await db.execute('''
      CREATE TABLE IF NOT EXISTS suppliers (
        id TEXT PRIMARY KEY,
        group_id TEXT,
        name TEXT,
        mobile TEXT,
        email TEXT,
        address TEXT,
        gst_number TEXT,
        created_at TEXT
      )
    ''');
    // Table: stock_transactions
    await db.execute('''
      CREATE TABLE IF NOT EXISTS stock_transactions (
        id TEXT PRIMARY KEY,
        group_id TEXT,
        product_id TEXT,
        supplier_id TEXT,
        transaction_type TEXT,
        transaction_date TEXT,
        quantity REAL,
        unit TEXT,
        purchase_rate REAL,
        total_amount REAL,
        batch_number TEXT,
        expiry_date TEXT,
        invoice_number TEXT,
        reason TEXT,
        authorized_by TEXT,
        created_at TEXT
      )
    ''');
    // Table: customers
    await db.execute('''
      CREATE TABLE IF NOT EXISTS customers (
        id TEXT PRIMARY KEY,
        group_id TEXT,
        name TEXT,
        mobile TEXT,
        email TEXT,
        address TEXT,
        gst_number TEXT,
        created_at TEXT
      )
    ''');
    // Table: sales
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sales (
        id TEXT PRIMARY KEY,
        group_id TEXT,
        customer_id TEXT,
        invoice_number TEXT,
        sale_date TEXT,
        subtotal REAL DEFAULT 0.00,
        discount REAL DEFAULT 0.00,
        tax REAL DEFAULT 0.00,
        total_amount REAL,
        paid_amount REAL DEFAULT 0.00,
        remaining_amount REAL DEFAULT 0.00,
        payment_status TEXT DEFAULT 'paid',
        payment_mode TEXT DEFAULT 'cash',
        salesperson_id TEXT,
        remarks TEXT,
        created_by TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');
    // Table: sale_items
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sale_items (
        id TEXT PRIMARY KEY,
        sale_id TEXT,
        product_id TEXT,
        quantity REAL,
        unit_price REAL,
        cost_price REAL DEFAULT 0.00,
        total_price REAL,
        created_at TEXT
      )
    ''');
    // Table: member_businesses
    await db.execute('''
      CREATE TABLE IF NOT EXISTS member_businesses (
        id TEXT PRIMARY KEY,
        group_id TEXT,
        member_id TEXT,
        business_name TEXT,
        business_type TEXT,
        investment REAL DEFAULT 0.00,
        monthly_production TEXT,
        monthly_sales REAL DEFAULT 0.00,
        monthly_expenses REAL DEFAULT 0.00,
        monthly_profit REAL DEFAULT 0.00,
        start_date TEXT,
        status TEXT DEFAULT 'active',
        remarks TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');
    // Table: contributions
    await db.execute('''
      CREATE TABLE IF NOT EXISTS contributions (
        id TEXT PRIMARY KEY,
        group_id TEXT,
        member_id TEXT,
        contribution_date TEXT,
        contribution_type TEXT,
        amount REAL,
        payment_mode TEXT DEFAULT 'cash',
        receipt_number TEXT,
        purpose TEXT,
        remarks TEXT,
        collected_by TEXT,
        created_at TEXT
      )
    ''');
    // Table: fines
    await db.execute('''
      CREATE TABLE IF NOT EXISTS fines (
        id TEXT PRIMARY KEY,
        group_id TEXT,
        member_id TEXT,
        fine_date TEXT,
        fine_type TEXT,
        reason TEXT,
        amount REAL,
        paid_amount REAL DEFAULT 0.00,
        pending_amount REAL,
        status TEXT DEFAULT 'pending',
        paid_date TEXT,
        payment_mode TEXT,
        created_by TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');
    // Table: government_schemes
    await db.execute('''
      CREATE TABLE IF NOT EXISTS government_schemes (
        id TEXT PRIMARY KEY,
        group_id TEXT,
        scheme_name TEXT,
        department TEXT,
        description TEXT,
        eligibility TEXT,
        benefit_amount REAL,
        start_date TEXT,
        end_date TEXT,
        required_documents TEXT,
        status TEXT DEFAULT 'active',
        created_at TEXT,
        updated_at TEXT
      )
    ''');
    // Table: scheme_applications
    await db.execute('''
      CREATE TABLE IF NOT EXISTS scheme_applications (
        id TEXT PRIMARY KEY,
        group_id TEXT,
        scheme_id TEXT,
        member_id TEXT,
        application_number TEXT,
        application_date TEXT,
        status TEXT DEFAULT 'applied',
        approved_amount REAL,
        approval_date TEXT,
        remarks TEXT,
        submitted_by TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');
    // Table: documents
    await db.execute('''
      CREATE TABLE IF NOT EXISTS documents (
        id TEXT PRIMARY KEY,
        group_id TEXT,
        member_id TEXT,
        document_name TEXT,
        document_type TEXT DEFAULT 'other',
        document_number TEXT,
        issue_date TEXT,
        expiry_date TEXT,
        file_url TEXT,
        file_size_bytes INTEGER,
        verification_status TEXT DEFAULT 'pending',
        verified_by TEXT,
        verified_at TEXT,
        remarks TEXT,
        created_by TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');
    // Table: trainings
    await db.execute('''
      CREATE TABLE IF NOT EXISTS trainings (
        id TEXT PRIMARY KEY,
        group_id TEXT,
        training_name TEXT,
        trainer TEXT,
        organization TEXT,
        start_date TEXT,
        end_date TEXT,
        location TEXT,
        description TEXT,
        skills_taught TEXT,
        certificate_available INTEGER DEFAULT 0,
        status TEXT DEFAULT 'scheduled',
        created_at TEXT
      )
    ''');
    // Table: training_attendances
    await db.execute('''
      CREATE TABLE IF NOT EXISTS training_attendances (
        id TEXT PRIMARY KEY,
        group_id TEXT,
        training_id TEXT,
        member_id TEXT,
        is_completed INTEGER DEFAULT 0,
        skill_level TEXT,
        certificate_url TEXT,
        remarks TEXT,
        created_at TEXT
      )
    ''');
    // Table: events
    await db.execute('''
      CREATE TABLE IF NOT EXISTS events (
        id TEXT PRIMARY KEY,
        group_id TEXT,
        event_name TEXT,
        event_type TEXT,
        event_date TEXT,
        event_time TEXT,
        location TEXT,
        organizer TEXT,
        budget REAL DEFAULT 0.00,
        actual_expense REAL DEFAULT 0.00,
        description TEXT,
        status TEXT DEFAULT 'scheduled',
        created_at TEXT
      )
    ''');
    // Table: event_participants
    await db.execute('''
      CREATE TABLE IF NOT EXISTS event_participants (
        id TEXT PRIMARY KEY,
        group_id TEXT,
        event_id TEXT,
        member_id TEXT,
        attended INTEGER DEFAULT 0,
        role TEXT,
        created_at TEXT
      )
    ''');
    // Table: dues
    await db.execute('''
      CREATE TABLE IF NOT EXISTS dues (
        id TEXT PRIMARY KEY,
        group_id TEXT,
        member_id TEXT,
        customer_id TEXT,
        payment_type TEXT,
        reference_id TEXT,
        due_date TEXT,
        due_amount REAL,
        paid_amount REAL DEFAULT 0.00,
        remaining_amount REAL,
        late_fee REAL DEFAULT 0.00,
        status TEXT DEFAULT 'pending',
        created_at TEXT,
        updated_at TEXT
      )
    ''');
    // Table: notifications
    await db.execute('''
      CREATE TABLE IF NOT EXISTS notifications (
        id TEXT PRIMARY KEY,
        group_id TEXT,
        user_id TEXT,
        member_id TEXT,
        title TEXT,
        message TEXT,
        type TEXT,
        priority TEXT DEFAULT 'medium',
        due_date TEXT,
        is_read INTEGER DEFAULT 0,
        read_at TEXT,
        created_at TEXT
      )
    ''');
    // Table: audit_logs
    await db.execute('''
      CREATE TABLE IF NOT EXISTS audit_logs (
        id TEXT PRIMARY KEY,
        group_id TEXT,
        user_id TEXT,
        user_name TEXT,
        user_role TEXT,
        module TEXT,
        action TEXT,
        record_id TEXT,
        old_values TEXT,
        new_values TEXT,
        description TEXT,
        ip_address TEXT,
        created_at TEXT
      )
    ''');
    // Table: settings
    await db.execute('''
      CREATE TABLE IF NOT EXISTS settings (
        id TEXT PRIMARY KEY,
        group_id TEXT,
        language TEXT DEFAULT 'mr',
        currency TEXT DEFAULT 'INR',
        currency_symbol TEXT DEFAULT '₹',
        date_format TEXT DEFAULT 'dd-MM-yyyy',
        receipt_prefix TEXT DEFAULT 'REC',
        invoice_prefix TEXT DEFAULT 'INV',
        voucher_prefix TEXT DEFAULT 'VCH',
        receipt_footer_note TEXT,
        otp_login_enabled INTEGER DEFAULT 1,
        pin_lock_enabled INTEGER DEFAULT 0,
        biometric_enabled INTEGER DEFAULT 0,
        session_timeout_minutes INTEGER DEFAULT 30,
        created_at TEXT,
        updated_at TEXT
      )
    ''');
    // Table: bank_loans
    await db.execute('''
      CREATE TABLE IF NOT EXISTS bank_loans (
        id TEXT PRIMARY KEY,
        group_id TEXT,
        bank_name TEXT,
        account_number TEXT,
        loan_amount REAL DEFAULT 0.00,
        tenure_months INTEGER DEFAULT 24,
        interest_rate REAL DEFAULT 7.00,
        status TEXT DEFAULT 'active',
        created_at TEXT,
        updated_at TEXT
      )
    ''');
    // Table: saving_plans
    await db.execute('''
      CREATE TABLE IF NOT EXISTS saving_plans (
        id TEXT PRIMARY KEY,
        group_id TEXT,
        plan_name TEXT DEFAULT 'Regular Monthly Saving',
        monthly_amount REAL DEFAULT 200.00,
        interest_rate REAL DEFAULT 0.00,
        due_day INTEGER DEFAULT 10,
        grace_period_days INTEGER DEFAULT 5,
        late_fee REAL DEFAULT 20.00,
        is_active INTEGER DEFAULT 1,
        status TEXT DEFAULT 'active',
        created_at TEXT,
        updated_at TEXT
      )
    ''');
    // Table: monthly_savings
    await db.execute('''
      CREATE TABLE IF NOT EXISTS monthly_savings (
        id TEXT PRIMARY KEY,
        group_id TEXT,
        member_id TEXT,
        saving_plan_id TEXT,
        month INTEGER,
        year INTEGER,
        due_date TEXT,
        expected_amount REAL DEFAULT 500.0,
        paid_amount REAL DEFAULT 0.0,
        late_fee REAL DEFAULT 0.0,
        balance_amount REAL DEFAULT 0.0,
        payment_mode TEXT DEFAULT 'cash',
        transaction_id TEXT,
        receipt_number TEXT,
        payment_date TEXT,
        collected_by TEXT,
        status TEXT DEFAULT 'pending',
        remarks TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    // Seed default offline admin and group after all schema tables exist
    await _seedDefaultData(db);
  }

  /// Create a backup copy of the SQLite database
  Future<String> backupDatabase([String? destinationPath]) async {
    final dbFile = File(await getDatabasePath());
    if (!await dbFile.exists()) {
      throw Exception('Database file does not exist to backup.');
    }

    String target;
    if (destinationPath != null && destinationPath.isNotEmpty) {
      target = destinationPath;
    } else {
      final docs = await getApplicationDocumentsDirectory();
      final now = DateTime.now();
      final timeStamp = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
          '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
      target = p.join(docs.path, 'BachatDatabase', 'bachat_backup_$timeStamp.db');
    }

    final parentDir = Directory(p.dirname(target));
    if (!await parentDir.exists()) {
      await parentDir.create(recursive: true);
    }

    await dbFile.copy(target);
    return target;
  }

  /// Restore database from an external file
  Future<void> restoreDatabase(String sourcePath) async {
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw Exception('Source backup file does not exist: $sourcePath');
    }

    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }

    final dbPath = await getDatabasePath();
    await sourceFile.copy(dbPath);

    final String dbName;
    if (AppConfig.isHybridMode) {
      dbName = 'bachat_hybrid.db';
    } else if (AppConfig.isOfflineMode) {
      dbName = 'bachat_offline.db';
    } else {
      dbName = 'bachat_online.db';
    }
    _database = await _initDB(dbName);
  }

  // ==========================================
  // SYNC QUEUE HELPERS (Hybrid Edition)
  // ==========================================

  Future<void> enqueueSync({
    required String tableName,
    required String rowId,
    required String action,
    required String payload,
  }) async {
    final db = await database;
    await db.insert('sync_queue', {
      'table_name': tableName,
      'row_id': rowId,
      'action': action,
      'payload': payload,
      'created_at': DateTime.now().toIso8601String(),
      'status': 'pending',
    });
  }

  Future<int> getPendingSyncCount() async {
    final db = await database;
    final res = await db.rawQuery(
      "SELECT COUNT(*) AS c FROM sync_queue WHERE status = 'pending' OR (status = 'failed' AND (retry_count IS NULL OR retry_count < 5))",
    );
    return (res.first['c'] as num?)?.toInt() ?? 0;
  }

  Future<List<Map<String, dynamic>>> getPendingSyncItems({int limit = 50}) async {
    final db = await database;
    return await db.query(
      'sync_queue',
      where: "status = 'pending' OR (status = 'failed' AND (retry_count IS NULL OR retry_count < 5))",
      orderBy: 'id ASC',
      limit: limit,
    );
  }

  Future<void> markSyncItemCompleted(int id) async {
    final db = await database;
    await db.update(
      'sync_queue',
      {
        'status': 'synced',
        'error_message': null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markSyncItemsCompleted(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await database;
    final placeholders = List.filled(ids.length, '?').join(',');
    await db.rawUpdate(
      "UPDATE sync_queue SET status = 'synced', error_message = NULL WHERE id IN ($placeholders)",
      ids,
    );
  }

  Future<void> markSyncItemFailed(int id, String error) async {
    final db = await database;
    await db.rawUpdate('''
      UPDATE sync_queue 
      SET status = 'failed', 
          error_message = ?, 
          retry_count = COALESCE(retry_count, 0) + 1 
      WHERE id = ?
    ''', [error, id]);
  }

  Future<String?> getLastPulledAt(String table) async {
    final db = await database;
    final res = await db.query(
      'sync_metadata',
      columns: ['last_pulled_at'],
      where: 'table_name = ?',
      whereArgs: [table],
    );
    if (res.isNotEmpty) {
      return res.first['last_pulled_at'] as String?;
    }
    return null;
  }

  Future<void> setLastPulledAt(String table, String timestamp) async {
    final db = await database;
    await db.insert(
      'sync_metadata',
      {
        'table_name': table,
        'last_pulled_at': timestamp,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Compresses, defragments, and shrinks the SQLite database on disk without losing any data.
  /// 1. Runs PRAGMA wal_checkpoint(TRUNCATE) to flush pending transactions into the main .db file.
  /// 2. Runs VACUUM; to reclaim all free space and repack database pages.
  /// 3. Generates a compressed backup archive (e.g. bachatgat_offline.db.gz) in the BachatDatabase folder.
  Future<Map<String, dynamic>> compactAndCompressDatabase() async {
    try {
      final db = await database;
      final dbPath = await getDatabasePath();
      final dbFile = File(dbPath);

      int beforeBytes = 0;
      if (await dbFile.exists()) {
        beforeBytes = await dbFile.length();
      }

      // Step 1: Checkpoint WAL frames into main database file and force DELETE journal mode
      try {
        await db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE);');
        await db.execute('PRAGMA journal_mode = DELETE;');
      } catch (_) {}

      // Step 2: VACUUM defragments the database file and repacks all tables into minimal space
      await db.execute('VACUUM;');

      // Step 3: Run SQLite optimizer
      try {
        await db.execute('PRAGMA optimize;');
      } catch (_) {}

      // Clean up any stale wal/shm files
      try {
        final wal = File('$dbPath-wal');
        if (await wal.exists()) await wal.delete();
        final shm = File('$dbPath-shm');
        if (await shm.exists()) await shm.delete();
      } catch (_) {}

      int afterVacuumBytes = 0;
      if (await dbFile.exists()) {
        afterVacuumBytes = await dbFile.length();
      }

      // Step 4: Create lossless gzip compressed archive in the same BachatDatabase folder
      String? compressedPath;
      int compressedBytes = 0;
      try {
        final gzPath = '$dbPath.gz';
        final rawBytes = await dbFile.readAsBytes();
        final gzipped = gzip.encode(rawBytes);
        final gzFile = File(gzPath);
        await gzFile.writeAsBytes(gzipped, flush: true);
        compressedPath = gzPath;
        compressedBytes = gzipped.length;
      } catch (gzErr) {
        debugPrint('Gzip archive creation note: $gzErr');
      }

      debugPrint('Database compression complete: Original: $beforeBytes bytes -> Vacuumed: $afterVacuumBytes bytes -> Gzipped Archive: $compressedBytes bytes');

      return {
        'success': true,
        'originalSize': beforeBytes,
        'vacuumedSize': afterVacuumBytes,
        'compressedSize': compressedBytes,
        'compressedPath': compressedPath,
        'savedBytes': beforeBytes - afterVacuumBytes,
      };
    } catch (e) {
      debugPrint('Error compacting and compressing database: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
}
