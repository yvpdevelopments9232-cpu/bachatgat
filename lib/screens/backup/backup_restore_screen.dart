import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/app_config.dart';
import '../../services/backup_restore_service.dart';
import '../../services/offline_db_helper.dart';
import '../../widgets/desktop_wrapper.dart';

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  bool _isExporting = false;
  bool _isImporting = false;
  bool _isCompressing = false;
  double _operationProgress = 0.0;
  String _operationStatus = '';

  // -------------------------------------------------------------
  // EXPORT BACKUP ACTION
  // -------------------------------------------------------------
  Future<void> _handleExportBackup() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final group = auth.currentGroup;
    final groupId = group?.id ?? 'group_offline_001';
    final groupName = group?.groupName ?? 'सखी महिला बचत गट';

    setState(() {
      _isExporting = true;
      _operationProgress = 0.0;
      _operationStatus = 'तयारी करत आहे...';
    });

    try {
      final result = await BackupRestoreService.instance.exportBackup(
        groupId: groupId,
        groupName: groupName,
        onProgress: (prog, status) {
          if (mounted) {
            setState(() {
              _operationProgress = prog;
              _operationStatus = status;
            });
          }
        },
      );

      if (!mounted) return;

      if (result.success) {
        _showSuccessExportDialog(result);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message ?? 'बॅकअप अयशस्वी झाला.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('त्रुटी: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _showSuccessExportDialog(BackupOperationResult result) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.success.withOpacity(0.15), shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 28),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'बॅकअप फाईल यशस्वी!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'सर्व ${result.totalRecords} नोंदी एका प्रमाणित .db डेटाबेस फाइलमध्ये सेव्ह झाल्या आहेत.',
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            const Text(
              'सेव्ह केलेले ठिकाण (Saved Location):',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: SelectableText(
                result.filePath ?? 'Downloads Folder',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 12),
            if (result.tableCounts.isNotEmpty) ...[
              const Text('नोंदींचा तपशील:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: result.tableCounts.entries.take(6).map((e) {
                  return Chip(
                    label: Text('${e.key}: ${e.value}', style: const TextStyle(fontSize: 11)),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    backgroundColor: AppColors.primary.withOpacity(0.08),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
        actions: [
          if (result.filePath != null)
            TextButton.icon(
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('पाथ कॉपी करा'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: result.filePath!));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('पाथ कॉपी केला!'), duration: Duration(seconds: 2)),
                );
              },
            ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ठीक आहे (OK)'),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // IMPORT BACKUP ACTION
  // -------------------------------------------------------------
  Future<void> _handleImportBackup() async {
    try {
      // 1. Pick .db file from location chosen by user
      final pickRes = await FilePicker.platform.pickFiles(
        dialogTitle: 'इम्पोर्ट करण्यासाठी .db किंवा .sqlite बॅकअप फाइल निवडा',
        type: FileType.any,
      );

      if (pickRes == null || pickRes.files.isEmpty || pickRes.files.first.path == null) {
        return; // User cancelled
      }

      final chosenFilePath = pickRes.files.first.path!;

      // 2. Inspect the chosen file
      setState(() {
        _isImporting = true;
        _operationProgress = 0.05;
        _operationStatus = 'फाईलची तपासणी करत आहे (Inspecting file)...';
      });

      final inspection = await BackupRestoreService.instance.inspectBackupFile(chosenFilePath);

      setState(() => _isImporting = false);

      if (!mounted) return;

      if (!inspection.isValid) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 28),
                const SizedBox(width: 8),
                const Text('अवैध फाईल (Invalid File)'),
              ],
            ),
            content: Text(inspection.errorMessage ?? 'ही फाईल योग्य बॅकअप फाईल नाही.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('बंद करा')),
            ],
          ),
        );
        return;
      }

      // 3. Show Pre-Import Confirmation Modal with record preview
      _showPreImportModal(inspection);
    } catch (e) {
      if (mounted) {
        setState(() => _isImporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('त्रुटी: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  void _showPreImportModal(BackupInspectionResult inspection) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final targetGroupId = auth.currentGroup?.id ?? 'group_offline_001';
    final targetUserId = auth.currentUser?.id ?? auth.currentProfile?.id;
    final targetGroupName = auth.currentGroup?.groupName ?? 'सखी महिला बचत गट';

    final isOfflineMigratingToOnline =
        ((inspection.sourceEdition?.toLowerCase().contains('offline') ?? false) || inspection.originalGroupId == 'group_offline_001') &&
            !AppConfig.isOfflineOnly;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final isMobileDialog = MediaQuery.of(ctx).size.width < 550;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding: EdgeInsets.symmetric(
            horizontal: isMobileDialog ? 12 : 40,
            vertical: 24,
          ),
          actionsOverflowButtonSpacing: 8,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), shape: BoxShape.circle),
                child: const Icon(Icons.restore_page_rounded, color: AppColors.primary, size: 26),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'बॅकअप इम्पोर्ट खातरजमा',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: isMobileDialog ? double.maxFinite : 480,
            child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.file_present_rounded, color: Colors.blue, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              inspection.originalGroupName ?? 'बचत गट बॅकअप',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'फाईल: ${p.basename(inspection.filePath)} (${(inspection.fileSizeBytes / 1024).toStringAsFixed(1)} KB)',
                        style: const TextStyle(fontSize: 12, color: Colors.black87),
                      ),
                      Text(
                        'तयार केलेली तारीख: ${inspection.exportedAt?.day}-${inspection.exportedAt?.month}-${inspection.exportedAt?.year}',
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (isOfflineMigratingToOnline) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.cloud_upload_rounded, color: Colors.amber, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'ऑफलाइन ते ऑनलाइन मायग्रेशन: हा डेटा आपोआप तुमच्या नवीन "$targetGroupName" खात्याशी जोडला जाईल आणि क्लाउडवर बंचमध्ये सुरक्षित सेव्ह होईल.',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF78350F)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                const Text('आढळलेल्या नोंदींचा तपशील:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    children: [
                      _buildPreviewRow('एकूण सर्व नोंदी (Total Records)', '${inspection.totalRecords}', isBold: true),
                      const Divider(height: 12),
                      _buildPreviewRow('सदस्य संख्या (Members)', '${inspection.tableCounts['members'] ?? 0}'),
                      _buildPreviewRow('बचत जमा नोंदी (Savings)', '${(inspection.tableCounts['savings'] ?? 0) + (inspection.tableCounts['monthly_savings'] ?? 0)}'),
                      _buildPreviewRow('कर्ज नोंदी (Loans & EMIs)', '${(inspection.tableCounts['loans'] ?? 0) + (inspection.tableCounts['loan_emis'] ?? 0)}'),
                      _buildPreviewRow('जमा व खर्च (Income/Expense)', '${(inspection.tableCounts['incomes'] ?? 0) + (inspection.tableCounts['expenses'] ?? 0)}'),
                      _buildPreviewRow('रोख वही व बँक (Cash/Bank)', '${(inspection.tableCounts['cash_book'] ?? 0) + (inspection.tableCounts['bank_transactions'] ?? 0)}'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Row(
                  children: [
                    Icon(Icons.shield_rounded, color: AppColors.success, size: 16),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'सुरक्षा हमी: जुन्या डेटाचा सेफ्टी स्नॅपशॉट आधी आपोआप घेतला जाईल.',
                        style: TextStyle(fontSize: 11, color: Colors.black54),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('रद्द करा (Cancel)'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            icon: const Icon(Icons.check, size: 18),
            label: const Text('होय, रिस्टोअर करा (RESTORE NOW)', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.pop(ctx);
              _executeRestore(inspection.filePath, targetGroupId, targetUserId);
            },
          ),
        ],
      );
    },
  );
}

  Widget _buildPreviewRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isBold ? AppColors.textPrimary : Colors.black87,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isBold ? AppColors.primary : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _executeRestore(String filePath, String targetGroupId, String? targetUserId) async {
    setState(() {
      _isImporting = true;
      _operationProgress = 0.1;
      _operationStatus = 'रिस्टोअर प्रक्रिया सुरू करत आहे...';
    });

    try {
      final result = await BackupRestoreService.instance.restoreBackup(
        backupFilePath: filePath,
        targetGroupId: targetGroupId,
        targetUserId: targetUserId,
        onProgress: (prog, status) {
          if (mounted) {
            setState(() {
              _operationProgress = prog;
              _operationStatus = status;
            });
          }
        },
      );

      if (!mounted) return;

      if (result.success) {
        // Refresh AuthProvider so UI shows new counts
        final auth = Provider.of<AuthProvider>(context, listen: false);
        await auth.fetchGroups();

        _showSuccessImportDialog(result);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message ?? 'रिस्टोअर अयशस्वी झाले.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('रिस्टोअर त्रुटी: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  void _showSuccessImportDialog(BackupOperationResult result) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.success.withOpacity(0.15), shape: BoxShape.circle),
              child: const Icon(Icons.done_all_rounded, color: AppColors.success, size: 28),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'रिस्टोअर यशस्वी झाला!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              result.message ?? 'सर्व नोंदी यशस्वीरित्या पुनर्प्राप्त झाल्या आहेत.',
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.success.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cloud_done_rounded, color: AppColors.success, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      AppConfig.isOfflineOnly
                          ? 'डेटा स्थानिक डेटाबेसमध्ये सुरक्षित सेव्ह झाला आहे.'
                          : 'डेटा स्थानिक तसेच Supabase क्लाउडवर बंचमध्ये सुरक्षित सेव्ह झाला आहे.',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.success),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('उत्कृष्ट (Done)'),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // BUILD SCREEN UI
  // -------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final group = auth.currentGroup;

    return DesktopWrapper(
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            'बॅकअप व रिस्टोअर (.db)',
            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          backgroundColor: Colors.white,
          elevation: 1,
          foregroundColor: AppColors.primary,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 850),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Current Status & Edition Banner
                  _buildStatusBanner(group),
                  const SizedBox(height: 20),

                  // 2. Active Operation Progress Bar (if running)
                  if (_isExporting || _isImporting) ...[
                    _buildProgressCard(),
                    const SizedBox(height: 20),
                  ],

                  // 3. Two Main Action Cards (Export & Import)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 600;
                      if (isWide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildExportCard()),
                            const SizedBox(width: 16),
                            Expanded(child: _buildImportCard()),
                          ],
                        );
                      } else {
                        return Column(
                          children: [
                            _buildExportCard(),
                            const SizedBox(height: 16),
                            _buildImportCard(),
                          ],
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 20),

                  // 3. Database Compression & Optimization Card
                  _buildCompressCard(),
                  const SizedBox(height: 24),

                  // 4. Instructions & Migration Guide
                  _buildInstructionsCard(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBanner(dynamic group) {
    String editionText;
    Color editionColor;
    IconData editionIcon;

    if (AppConfig.isOfflineOnly) {
      editionText = 'ऑफलाइन आवृत्ती (100% Offline Edition)';
      editionColor = const Color(0xFF0284C7);
      editionIcon = Icons.offline_bolt_rounded;
    } else if (AppConfig.isHybridMode) {
      editionText = 'हायब्रिड आवृत्ती (Hybrid Offline + Cloud)';
      editionColor = const Color(0xFFD97706);
      editionIcon = Icons.sync_alt_rounded;
    } else {
      editionText = 'ऑनलाइन आवृत्ती (100% Online Supabase Cloud)';
      editionColor = const Color(0xFF059669);
      editionIcon = Icons.cloud_done_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withBlue(160)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: AppColors.primary.withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: editionColor.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(editionIcon, color: Colors.white, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      editionText,
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              const Icon(Icons.security_rounded, color: Colors.white70, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            group?.groupName ?? 'सखी महिला बचत गट',
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'प्रमाणित .db फॉरमॅट: ही फाईल ऑफलाइन, हायब्रिड किंवा ऑनलाइन कोणत्याही ॲपमध्ये वापरता येते.',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  value: _operationProgress > 0 ? _operationProgress : null,
                  strokeWidth: 2.5,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _operationStatus,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
              Text(
                '${(_operationProgress * 100).toInt()}%',
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _operationProgress,
              backgroundColor: Colors.grey.shade200,
              color: AppColors.primary,
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.file_download_rounded, color: Color(0xFF2563EB), size: 32),
          ),
          const SizedBox(height: 16),
          const Text(
            '१. डेटा बॅकअप एक्सपोर्ट करा',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          const Text(
            'सर्व सदस्य, बचत, कर्जे, वह्या व अहवालांची एक संपूर्ण .db फाईल तयार करा आणि तुमच्या कॉम्प्युटर किंवा फोनमध्ये सेव्ह करा.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 16),
          const Row(
            children: [
              Icon(Icons.folder_open_rounded, size: 16, color: Colors.blueGrey),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'क्लिक केल्यावर सेव्ह करण्यासाठी फोल्डर निवडता येईल.',
                  style: TextStyle(fontSize: 11, color: Colors.blueGrey),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 2,
              ),
              icon: _isExporting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.download_rounded, size: 20),
              label: Text(
                _isExporting ? 'एक्सपोर्ट होत आहे...' : 'बॅकअप फाइल सेव्ह करा (EXPORT .DB)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              onPressed: (_isExporting || _isImporting) ? null : _handleExportBackup,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImportCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.file_upload_rounded, color: Color(0xFF16A34A), size: 32),
          ),
          const SizedBox(height: 16),
          const Text(
            '२. डेटा बॅकअप इम्पोर्ट / रिस्टोअर करा',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          const Text(
            'तुमची .db फाईल निवडून सर्व डेटा त्वरित रिस्टोअर करा. ऑफलाइन मधून ऑनलाइन मध्ये जाताना ही फाईल निवडून सर्व डेटा थेट क्लाउडवर बंचमध्ये अपलोड करा.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 16),
          const Row(
            children: [
              Icon(Icons.search_rounded, size: 16, color: Colors.blueGrey),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'क्लिक केल्यावर फाईल ब्राउझ करून निवडता येईल.',
                  style: TextStyle(fontSize: 11, color: Colors.blueGrey),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 2,
              ),
              icon: _isImporting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.upload_file_rounded, size: 20),
              label: Text(
                _isImporting ? 'तपासणी सुरू आहे...' : 'बॅकअप फाईल निवडा (IMPORT .DB)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              onPressed: (_isExporting || _isImporting) ? null : _handleImportBackup,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'ऑफलाइन ते ऑनलाइन मायग्रेशन पद्धत (How to Migrate)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildStep(
            '१',
            'ऑफलाइन ॲपमध्ये "बॅकअप फाइल सेव्ह करा" वर क्लिक करा आणि `.db` फाईल तुमच्या पेन ड्राइव्ह, डाउनलोड्स किंवा फोनमध्ये सेव्ह करा.',
          ),
          _buildStep(
            '२',
            'त्यानंतर ऑनलाइन किंवा हायब्रिड ॲप उघडा व तुमच्या नवीन खात्यात लॉगिन / साइन अप करा.',
          ),
          _buildStep(
            '३',
            'याच बॅकअप व रिस्टोअर मेनूमध्ये येऊन "बॅकअप फाईल निवडा" वर क्लिक करा व सेव्ह केलेली `.db` फाईल सिलेक्ट करा.',
          ),
          _buildStep(
            '४',
            'सिस्टम फाईल तपासून सर्व नोंदी आपोआप नवीन खात्याशी जोडेल व Supabase वर बंचमध्ये अपलोड करेल!',
          ),
        ],
      ),
    );
  }

  Widget _buildStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 10,
            backgroundColor: AppColors.primary.withOpacity(0.12),
            child: Text(
              number,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompressCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.teal.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.compress_rounded, color: Colors.teal.shade700, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'डेटाबेस कॉम्प्रेस करा (Compress & Optimize)',
                      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal.shade900),
                    ),
                    Text(
                      'कोणताही डेटा न गमावता फाईलचा आकार लहान करा (100% Lossless)',
                      style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'डेटाबेस वापरताना साचलेली अनावश्यक रिकामी जागा (Free space) काढून SQLite डेटाबेस संकुचित केला जाईल. यामुळे ॲपचा वेग वाढतो आणि BachatDatabase फोल्डरमध्ये .db.gz कॉम्प्रेस्ड बॅकअप सुरक्षित राहतो.',
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700, height: 1.4),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isCompressing ? null : _handleCompressDatabase,
              icon: _isCompressing
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.cleaning_services_rounded, size: 18),
              label: Text(
                _isCompressing ? 'कॉम्प्रेस करत आहे...' : 'आता कॉम्प्रेस करा (Compress Database Now)',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleCompressDatabase() async {
    setState(() => _isCompressing = true);
    try {
      final res = await OfflineDbHelper.instance.compactAndCompressDatabase();
      if (!mounted) return;
      if (res['success'] == true) {
        final origKb = ((res['originalSize'] as int? ?? 0) / 1024).toStringAsFixed(1);
        final vacKb = ((res['vacuumedSize'] as int? ?? 0) / 1024).toStringAsFixed(1);
        final gzKb = ((res['compressedSize'] as int? ?? 0) / 1024).toStringAsFixed(1);
        final savedKb = ((res['savedBytes'] as int? ?? 0) / 1024).toStringAsFixed(1);

        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('डेटाबेस यशस्वीरित्या कॉम्प्रेस झाला!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('सर्व नोंदी आणि डेटा १००% सुरक्षित ठेवून डेटाबेस आकार लहान करण्यात आला आहे.', style: GoogleFonts.poppins(fontSize: 13)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(10)),
                  child: Column(
                    children: [
                      _buildSizeRow('आधीचा आकार (Original):', '$origKb KB'),
                      _buildSizeRow('सध्याचा डिस्क आकार (Vacuumed):', '$vacKb KB'),
                      _buildSizeRow('बचत झालेली जागा (Space Saved):', '$savedKb KB'),
                      const Divider(height: 16),
                      _buildSizeRow('कॉम्प्रेस्ड आर्काइव्ह (.db.gz):', '$gzKb KB'),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700, foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('ठीक आहे (Done)'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('कॉम्प्रेशन त्रुटी: ${res['error']}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('त्रुटी: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isCompressing = false);
    }
  }

  Widget _buildSizeRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.poppins(fontSize: 12, color: Colors.black87)),
          Text(val, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal.shade900)),
        ],
      ),
    );
  }
}
