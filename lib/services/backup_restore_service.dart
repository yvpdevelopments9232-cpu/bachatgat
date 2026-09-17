import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_config.dart';
import 'offline_db_helper.dart';
import 'sync_service.dart';

class BackupInspectionResult {
  final bool isValid;
  final String? errorMessage;
  final String? originalGroupName;
  final String? originalGroupId;
  final DateTime? exportedAt;
  final String? sourceEdition;
  final String? sourcePlatform;
  final Map<String, int> tableCounts;
  final int totalRecords;
  final String filePath;
  final int fileSizeBytes;

  const BackupInspectionResult({
    required this.isValid,
    this.errorMessage,
    this.originalGroupName,
    this.originalGroupId,
    this.exportedAt,
    this.sourceEdition,
    this.sourcePlatform,
    this.tableCounts = const {},
    this.totalRecords = 0,
    required this.filePath,
    this.fileSizeBytes = 0,
  });
}

class BackupOperationResult {
  final bool success;
  final String? filePath;
  final String? message;
  final int totalRecords;
  final Map<String, int> tableCounts;

  const BackupOperationResult({
    required this.success,
    this.filePath,
    this.message,
    this.totalRecords = 0,
    this.tableCounts = const {},
  });
}

class BackupRestoreService {
  static final BackupRestoreService instance = BackupRestoreService._();
  BackupRestoreService._();

  /// All 41 tables included in backup/restore in exact topological dependency order
  static const List<String> allBackupTables = [
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
    'bonus_settings',
    'bonuses',
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
  ];

  // -------------------------------------------------------------
  // 1. INSPECT BACKUP FILE (.db)
  // -------------------------------------------------------------
  Future<BackupInspectionResult> inspectBackupFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return BackupInspectionResult(
          isValid: false,
          errorMessage: 'फाइल अस्तित्वात नाही (File does not exist).',
          filePath: filePath,
        );
      }

      final fileSizeBytes = await file.length();
      if (fileSizeBytes < 1024) {
        return BackupInspectionResult(
          isValid: false,
          errorMessage: 'अवैध फाईल! फाईलचा आकार खूप लहान आहे (File too small).',
          filePath: filePath,
        );
      }

      // Initialize FFI for Windows if needed
      OfflineDbHelper.initializeFfi();

      final effectivePath = await _resolveDatabasePath(filePath);
      Database? db;
      try {
        db = await openDatabase(effectivePath, readOnly: true);
      } catch (e) {
        if (effectivePath != filePath) {
          try {
            await File(effectivePath).delete();
          } catch (_) {}
        }
        return BackupInspectionResult(
          isValid: false,
          errorMessage: 'डेटाबेस उघडताना त्रुटी: $e (Corrupt or unreadable SQLite file)',
          filePath: filePath,
        );
      }

      // Check for core tables
      final tableRows = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
      );
      final existingTables = tableRows.map((r) => r['name']?.toString() ?? '').toSet();

      if (!existingTables.contains('members') && !existingTables.contains('savings') && !existingTables.contains('groups')) {
        await db.close();
        return BackupInspectionResult(
          isValid: false,
          errorMessage: 'अवैध बॅकअप फाइल! ही सखी बचत गट ॲपची मूळ डेटाबेस फाईल नाही (Missing core tables).',
          filePath: filePath,
        );
      }

      // Read metadata if available
      String? originalGroupName;
      String? originalGroupId;
      DateTime? exportedAt;
      String? sourceEdition;
      String? sourcePlatform;

      if (existingTables.contains('backup_metadata')) {
        try {
          final metaRows = await db.query('backup_metadata');
          final metaMap = {for (var r in metaRows) r['key']?.toString(): r['value']?.toString()};
          originalGroupName = metaMap['group_name'];
          originalGroupId = metaMap['group_id'];
          sourceEdition = metaMap['source_edition'];
          sourcePlatform = metaMap['source_platform'];
          if (metaMap['exported_at'] != null) {
            exportedAt = DateTime.tryParse(metaMap['exported_at']!);
          }
        } catch (_) {}
      }

      if (originalGroupName == null && existingTables.contains('groups')) {
        try {
          final gRows = await db.query('groups', limit: 1);
          if (gRows.isNotEmpty) {
            originalGroupName = gRows.first['group_name']?.toString();
            originalGroupId = gRows.first['id']?.toString();
          }
        } catch (_) {}
      }

      // Count records across all tables
      final tableCounts = <String, int>{};
      int totalRecords = 0;

      for (var table in allBackupTables) {
        if (existingTables.contains(table)) {
          try {
            final countRes = await db.rawQuery('SELECT COUNT(*) AS c FROM $table');
            final c = (countRes.first['c'] as num?)?.toInt() ?? 0;
            if (c > 0) {
              tableCounts[table] = c;
              totalRecords += c;
            }
          } catch (_) {}
        }
      }

      await db.close();
      if (effectivePath != filePath) {
        try {
          await File(effectivePath).delete();
        } catch (_) {}
      }

      return BackupInspectionResult(
        isValid: true,
        originalGroupName: originalGroupName ?? 'सखी महिला बचत गट',
        originalGroupId: originalGroupId,
        exportedAt: exportedAt ?? DateTime.now(),
        sourceEdition: sourceEdition ?? 'Unknown',
        sourcePlatform: sourcePlatform ?? 'Unknown',
        tableCounts: tableCounts,
        totalRecords: totalRecords,
        filePath: filePath,
        fileSizeBytes: fileSizeBytes,
      );
    } catch (e) {
      return BackupInspectionResult(
        isValid: false,
        errorMessage: 'तपासणी करताना त्रुटी आली: $e',
        filePath: filePath,
      );
    }
  }

  // -------------------------------------------------------------
  // 2. EXPORT BACKUP (.db)
  // -------------------------------------------------------------
  Future<BackupOperationResult> exportBackup({
    required String groupId,
    required String groupName,
    void Function(double progress, String status)? onProgress,
  }) async {
    try {
      final now = DateTime.now();
      final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
          '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      final cleanName = groupName.replaceAll(RegExp(r'[^a-zA-Z0-9\u0900-\u097F_-]'), '_');
      final targetFileName = 'BachatGat_Backup_${cleanName}_$dateStr.db';

      OfflineDbHelper.initializeFfi();

      final tempDir = await getTemporaryDirectory();
      final tempExportPath = p.join(tempDir.path, targetFileName);

      final tableCounts = <String, int>{};
      int totalRecords = 0;

      if (AppConfig.isOfflineOnly || AppConfig.isHybridMode) {
        // --- HYBRID MODE: Pull all cloud tables for group into SQLite first so backup has 100% data ---
        if (AppConfig.isHybridMode) {
          onProgress?.call(0.1, 'क्लाउडवरून सर्व तक्ते समक्रमित करत आहे (Syncing all tables)...');
          try {
            await SyncService.instance.pullAllTablesForGroup(groupId);
          } catch (e) {
            debugPrint('Hybrid export pre-pull note: $e');
          }
        }

        // --- OFFLINE & HYBRID: Copy local SQLite with WAL checkpoint ---
        onProgress?.call(0.2, 'स्थानिक डेटाबेस तयार करत आहे (Flushing SQLite)...');
        final localDb = await OfflineDbHelper.instance.database;
        try {
          await localDb.rawQuery('PRAGMA wal_checkpoint(FULL);');
        } catch (_) {}

        // Ensure backup_metadata table exists
        await _writeMetadataTable(localDb, groupId, groupName, now);

        // Calculate record counts
        for (var t in allBackupTables) {
          try {
            final res = await localDb.rawQuery('SELECT COUNT(*) AS c FROM $t');
            final c = (res.first['c'] as num?)?.toInt() ?? 0;
            if (c > 0) {
              tableCounts[t] = c;
              totalRecords += c;
            }
          } catch (_) {}
        }

        onProgress?.call(0.5, 'बॅकअप फाइल कॉपी करत आहे...');
        final sourcePath = await OfflineDbHelper.instance.getDatabasePath();
        final sourceFile = File(sourcePath);
        if (await sourceFile.exists()) {
          await sourceFile.copy(tempExportPath);
        } else {
          return const BackupOperationResult(
            success: false,
            message: 'स्थानिक डेटाबेस फाईल सापडली नाही (Database file not found).',
          );
        }
      } else {
        // --- ONLINE EDITION: Fetch from Supabase Cloud and generate standard .db file ---
        onProgress?.call(0.1, 'क्लाउडवरून डेटा गोळा करत आहे (Fetching Supabase Cloud)...');
        final client = Supabase.instance.client;

        final tempFile = File(tempExportPath);
        if (await tempFile.exists()) await tempFile.delete();

        final tempDb = await openDatabase(tempExportPath, version: 1);
        await OfflineDbHelper.instance.createAllTables(tempDb);
        await _writeMetadataTable(tempDb, groupId, groupName, now);

        int processedTables = 0;
        for (var table in allBackupTables) {
          processedTables++;
          final progress = 0.1 + (0.7 * (processedTables / allBackupTables.length));
          onProgress?.call(progress, '$table डेटा गोळा करत आहे ($processedTables/${allBackupTables.length})...');

          try {
            dynamic query = client.from(table).select();
            if (table == 'groups') {
              query = query.eq('id', groupId);
            } else if (table == 'sale_items') {
              // sale_items does not have group_id; query by matching sales
              final salesRes = await client.from('sales').select('id').eq('group_id', groupId);
              final saleIds = (salesRes as List).map((s) => s['id'].toString()).toList();
              if (saleIds.isNotEmpty) {
                query = query.inFilter('sale_id', saleIds);
              } else {
                continue;
              }
            } else {
              query = query.eq('group_id', groupId);
            }

            final dynamic res = await query.timeout(const Duration(seconds: 15));
            if (res is List && res.isNotEmpty) {
              tableCounts[table] = res.length;
              totalRecords += res.length;

              final cols = await _getTableColumns(tempDb, table);
              await tempDb.transaction((txn) async {
                for (var r in res) {
                  final row = Map<String, dynamic>.from(r as Map);
                  final sanitized = _sanitizeRowForSqlite(row, cols);
                  await txn.insert(table, sanitized, conflictAlgorithm: ConflictAlgorithm.replace);
                }
              });
            }
          } catch (e) {
            debugPrint('Online export table note for $table: $e');
          }
        }

        await tempDb.close();
      }

      onProgress?.call(0.9, 'फाइल सेव्ह करत आहे (Saving File)...');

      // Save to user destination
      String? finalSavedPath;
      if (!kIsWeb && Platform.isWindows) {
        final selectedPath = await FilePicker.platform.saveFile(
          dialogTitle: 'बॅकअप (.db) फाइल कुठे सेव्ह करायची ते निवडा',
          fileName: targetFileName,
          type: FileType.custom,
          allowedExtensions: ['db'],
        );

        if (selectedPath != null && selectedPath.isNotEmpty) {
          String dest = selectedPath;
          if (!dest.toLowerCase().endsWith('.db')) {
            dest = '$dest.db';
          }
          await File(tempExportPath).copy(dest);
          finalSavedPath = dest;
        } else {
          return const BackupOperationResult(
            success: false,
            message: 'बॅकअप सेव्ह करणे रद्द केले (Export cancelled by user).',
          );
        }
      } else {
        // Mobile (Android)
        String? selectedDir;
        try {
          selectedDir = await FilePicker.platform.getDirectoryPath(
            dialogTitle: 'बॅकअप फाइल सेव्ह करण्यासाठी फोल्डर निवडा',
          );
        } catch (_) {}

        if (selectedDir != null && selectedDir.isNotEmpty) {
          final dest = p.join(selectedDir, targetFileName);
          await File(tempExportPath).copy(dest);
          finalSavedPath = dest;
        } else {
          // Fallback to Downloads directory
          Directory? destDir;
          try {
            final downloadPath = Directory('/storage/emulated/0/Download');
            if (await downloadPath.exists()) {
              destDir = downloadPath;
            }
          } catch (_) {}

          destDir ??= await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
          final dest = p.join(destDir.path, targetFileName);
          await File(tempExportPath).copy(dest);
          finalSavedPath = dest;
        }
      }

      onProgress?.call(1.0, 'बॅकअप यशस्वीरित्या पूर्ण झाला!');

      return BackupOperationResult(
        success: true,
        filePath: finalSavedPath,
        message: 'बॅकअप यशस्वी! ($totalRecords नोंदी सेव्ह केल्या)',
        totalRecords: totalRecords,
        tableCounts: tableCounts,
      );
    } catch (e) {
      return BackupOperationResult(
        success: false,
        message: 'बॅकअप एक्सपोर्ट करताना त्रुटी आली: $e',
      );
    }
  }

  // -------------------------------------------------------------
  // 3. RESTORE BACKUP (.db) WITH GROUP REMAPPING & CLOUD BUNCH UPLOAD
  // -------------------------------------------------------------
  Future<BackupOperationResult> restoreBackup({
    required String backupFilePath,
    required String targetGroupId,
    required String? targetUserId,
    void Function(double progress, String status)? onProgress,
  }) async {
    try {
      OfflineDbHelper.initializeFfi();

      final sourceFile = File(backupFilePath);
      if (!await sourceFile.exists()) {
        return const BackupOperationResult(
          success: false,
          message: 'निवडलेली बॅकअप फाइल सापडली नाही (Selected file missing).',
        );
      }

      // SAFEGUARD 1: Create a Pre-Import Safety Snapshot first!
      onProgress?.call(0.05, 'सुरक्षिततेसाठी सध्याचा स्नॅपशॉट घेत आहे (Safety Backup)...');
      await _createSafetySnapshot();

      // Open source backup database
      onProgress?.call(0.15, 'बॅकअप फाईलमधील डेटा वाचत आहे...');
      final effectivePath = await _resolveDatabasePath(backupFilePath);
      final Database sourceDb;
      try {
        sourceDb = await openDatabase(effectivePath, readOnly: true);
      } catch (openErr) {
        if (effectivePath != backupFilePath) {
          try {
            await File(effectivePath).delete();
          } catch (_) {}
        }
        return BackupOperationResult(
          success: false,
          message: 'बॅकअप फाईल उघडताना त्रुटी: $openErr',
        );
      }

      final tableRows = await sourceDb.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
      );
      final existingTables = tableRows.map((r) => r['name']?.toString() ?? '').toSet();

      final tableCounts = <String, int>{};
      int totalRestored = 0;

      // SAFEGUARD 2: Remap & Restore table by table in dependency order
      if (AppConfig.isOfflineOnly || AppConfig.isHybridMode) {
        // --- RESTORE INTO LOCAL SQLITE ---
        final localDb = await OfflineDbHelper.instance.database;

        int processed = 0;
        for (var table in allBackupTables) {
          processed++;
          final progress = 0.15 + (0.5 * (processed / allBackupTables.length));
          onProgress?.call(progress, '$table रिस्टोअर होत आहे ($processed/${allBackupTables.length})...');

          if (existingTables.contains(table)) {
            final rows = await sourceDb.query(table);
            if (rows.isNotEmpty) {
              final validCols = await _getTableColumns(localDb, table);

              await localDb.transaction((txn) async {
                for (var r in rows) {
                  final row = Map<String, dynamic>.from(r);

                  // Group ID Remapping
                  if (row.containsKey('group_id')) {
                    row['group_id'] = targetGroupId;
                  }
                  if (table == 'groups') {
                    row['id'] = targetGroupId;
                  }
                  if (row.containsKey('created_by') && targetUserId != null && targetUserId.isNotEmpty) {
                    row['created_by'] = targetUserId;
                  }

                  final sanitized = _sanitizeRowForSqlite(row, validCols);
                  await txn.insert(table, sanitized, conflictAlgorithm: ConflictAlgorithm.replace);

                  // In Hybrid mode: enqueue into sync_queue for cloud sync
                  if (AppConfig.isHybridMode && table != 'sync_queue' && table != 'sync_metadata') {
                    await txn.insert('sync_queue', {
                      'table_name': table,
                      'row_id': row['id']?.toString() ?? '',
                      'action': 'UPSERT',
                      'payload': jsonEncode(sanitized),
                      'created_at': DateTime.now().toIso8601String(),
                      'status': 'pending',
                    });
                  }
                }
              });

              tableCounts[table] = rows.length;
              totalRestored += rows.length;
            }
          }
        }

        // In Hybrid mode: push all restored records to Supabase in bunches immediately!
        if (AppConfig.isHybridMode) {
          onProgress?.call(0.75, 'सर्व डेटा क्लाउडवर बंचमध्ये अपलोड करत आहे (Cloud Batch Upload)...');
          try {
            await SyncService.instance.pushBatchSync();
          } catch (syncErr) {
            debugPrint('Hybrid post-restore sync note: $syncErr');
          }
        }
      } else {
        // --- RESTORE INTO ONLINE SUPABASE DIRECTLY ---
        final client = Supabase.instance.client;

        int processed = 0;
        for (var table in allBackupTables) {
          processed++;
          final progress = 0.15 + (0.8 * (processed / allBackupTables.length));
          onProgress?.call(progress, '$table क्लाउडवर बंचमध्ये अपलोड करत आहे ($processed/${allBackupTables.length})...');

          if (existingTables.contains(table)) {
            final rows = await sourceDb.query(table);
            if (rows.isNotEmpty) {
              final bunches = <List<Map<String, dynamic>>>[];
              List<Map<String, dynamic>> currentBunch = [];

              for (var r in rows) {
                final row = Map<String, dynamic>.from(r);

                // Group ID Remapping
                if (row.containsKey('group_id')) {
                  row['group_id'] = targetGroupId;
                }
                if (table == 'groups') {
                  row['id'] = targetGroupId;
                }
                if (row.containsKey('created_by') && targetUserId != null && targetUserId.isNotEmpty) {
                  row['created_by'] = targetUserId;
                }

                final formatted = SyncService.formatRowForSupabase(table, row);
                currentBunch.add(formatted);

                if (currentBunch.length >= 50) {
                  bunches.add(currentBunch);
                  currentBunch = [];
                }
              }
              if (currentBunch.isNotEmpty) {
                bunches.add(currentBunch);
              }

              // Upload bunches of 50
              for (var bunch in bunches) {
                try {
                  await client.from(table).upsert(bunch).timeout(const Duration(seconds: 40));
                } catch (bunchErr) {
                  // Fallback item by item if single row clashes
                  for (var singleRow in bunch) {
                    try {
                      await client.from(table).upsert(singleRow).timeout(const Duration(seconds: 15));
                    } catch (singleErr) {
                      debugPrint('Online restore single row clash in $table: $singleErr');
                    }
                  }
                }
              }

              tableCounts[table] = rows.length;
              totalRestored += rows.length;
            }
          }
        }
      }

      await sourceDb.close();
      if (effectivePath != backupFilePath) {
        try {
          await File(effectivePath).delete();
        } catch (_) {}
      }

      onProgress?.call(1.0, 'डेटा यशस्वीरित्या रिस्टोअर झाला!');

      return BackupOperationResult(
        success: true,
        filePath: backupFilePath,
        message: 'यशस्वी रिस्टोअर! एकूण $totalRestored नोंदी पुनर्प्राप्त केल्या.',
        totalRecords: totalRestored,
        tableCounts: tableCounts,
      );
    } catch (e) {
      return BackupOperationResult(
        success: false,
        message: 'रिस्टोअर करताना त्रुटी आली: $e',
      );
    }
  }

  // -------------------------------------------------------------
  // HELPERS & SAFEGUARDS
  // -------------------------------------------------------------
  Future<void> _writeMetadataTable(Database db, String groupId, String groupName, DateTime now) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS backup_metadata (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    final meta = {
      'group_id': groupId,
      'group_name': groupName,
      'exported_at': now.toIso8601String(),
      'source_edition': AppConfig.edition,
      'source_platform': Platform.operatingSystem,
      'app_version': '2.0.0',
      'format': 'sakhi_bachatgat_standard_db',
    };

    for (var entry in meta.entries) {
      await db.insert(
        'backup_metadata',
        {'key': entry.key, 'value': entry.value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<void> _createSafetySnapshot() async {
    try {
      if (AppConfig.isOfflineOnly || AppConfig.isHybridMode) {
        final sourcePath = await OfflineDbHelper.instance.getDatabasePath();
        final sourceFile = File(sourcePath);
        if (await sourceFile.exists()) {
          final docsDir = await getApplicationDocumentsDirectory();
          final safetyPath = p.join(
            docsDir.path,
            'pre_restore_safety_backup_${DateTime.now().millisecondsSinceEpoch}.db',
          );
          await sourceFile.copy(safetyPath);
        }
      }
    } catch (e) {
      debugPrint('Safety snapshot warning: $e');
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

  Future<String> _resolveDatabasePath(String path) async {
    if (path.toLowerCase().endsWith('.gz')) {
      final gzFile = File(path);
      final gzBytes = await gzFile.readAsBytes();
      final decompressed = gzip.decode(gzBytes);
      final tempDir = await getTemporaryDirectory();
      final tempDbPath = p.join(
        tempDir.path,
        'restored_decompressed_${DateTime.now().millisecondsSinceEpoch}.db',
      );
      await File(tempDbPath).writeAsBytes(decompressed, flush: true);
      return tempDbPath;
    }
    return path;
  }
}
