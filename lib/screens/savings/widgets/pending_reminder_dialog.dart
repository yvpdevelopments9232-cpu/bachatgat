import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_strings.dart';
import '../../../models/monthly_saving.dart';

class PendingReminderDialog extends StatelessWidget {
  final List<MonthlySaving> pendingSavings;
  final String groupName;
  final String monthName;
  final int year;

  const PendingReminderDialog({
    super.key,
    required this.pendingSavings,
    required this.groupName,
    required this.monthName,
    required this.year,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 40,
        vertical: isMobile ? 16 : 24,
      ),
      child: Container(
        width: isMobile ? double.infinity : 540,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        padding: EdgeInsets.all(isMobile ? 14 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.notifications_active_rounded, color: AppColors.danger, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'बचत थकबाकी सूचना (Pending)',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700,
                                fontSize: isMobile ? 14 : 16,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              '$monthName $year चे प्रलंबित (${pendingSavings.length})',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(fontSize: 12, color: AppColors.danger, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 24),

            if (pendingSavings.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 54),
                      const SizedBox(height: 12),
                      Text(
                        'या महिन्यात सर्व सदस्यांची बचत जमा झाली आहे!',
                        style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.success),
                      ),
                      Text(
                        'No pending savings for $monthName $year',
                        style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: pendingSavings.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final item = pendingSavings[i];
                    final dueAmount = item.balanceAmount > 0 ? item.balanceAmount : item.expectedAmount;

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.danger.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: AppColors.danger.withOpacity(0.12),
                            child: const Icon(Icons.person_rounded, color: AppColors.danger),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.memberName ?? 'सदस्य',
                                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14),
                                ),
                                Text(
                                  'आयडी: ${item.memberCode ?? "-"} • मो: ${item.mobileNumber ?? "-"}',
                                  style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'देय तारीख: ${item.dueDate}',
                                  style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '₹ ${dueAmount.toStringAsFixed(0)}',
                                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.danger),
                              ),
                              const SizedBox(height: 6),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  minimumSize: Size.zero,
                                ),
                                icon: const Icon(Icons.send_rounded, size: 14, color: Colors.white),
                                label: const Text('सूचना पाठवा', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                                onPressed: () {
                                  final msg = '''
🔔 *${groupName.toUpperCase()} बचत सूचना*
नमस्कार ${item.memberName},
आपली *$monthName $year* ची मासिक बचत रक्कम *₹${dueAmount.toStringAsFixed(0)}* प्रलंबित आहे.
कृपया दिनांक ${item.dueDate} पर्यंत भरणा करावा.
धन्यवाद!
''';
                                  Clipboard.setData(ClipboardData(text: msg));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('${item.memberName} साठी सूचना मेसेज कॉपी झाला! (SMS copied)')),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 14),
            isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (pendingSavings.isNotEmpty) ...[
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.danger,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          icon: const Icon(Icons.campaign_rounded, color: Colors.white, size: 18),
                          label: const Text(
                            'सर्व सदस्यांना मेसेज पाठवा (Copy All)',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                          ),
                          onPressed: () {
                            final buffer = StringBuffer();
                            buffer.writeln('🔔 *$groupName - $monthName $year बचत थकबाकी यादी*');
                            for (var item in pendingSavings) {
                              buffer.writeln('• ${item.memberName} (${item.memberCode}): ₹${item.balanceAmount.toStringAsFixed(0)}');
                            }
                            buffer.writeln('कृपया लवकरात लवकर भरणा करावा.');
                            Clipboard.setData(ClipboardData(text: buffer.toString()));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('सर्व थकबाकीदारांची यादी कॉपी झाली! (All pending copied!)')),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                      ],
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(AppStrings.cancel),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(AppStrings.cancel),
                      ),
                      if (pendingSavings.isNotEmpty)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                          icon: const Icon(Icons.campaign_rounded, color: Colors.white, size: 18),
                          label: const Text('सर्व सदस्यांना मेसेज पाठवा (Copy All)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                          onPressed: () {
                            final buffer = StringBuffer();
                            buffer.writeln('🔔 *$groupName - $monthName $year बचत थकबाकी यादी*');
                            for (var item in pendingSavings) {
                              buffer.writeln('• ${item.memberName} (${item.memberCode}): ₹${item.balanceAmount.toStringAsFixed(0)}');
                            }
                            buffer.writeln('कृपया लवकरात लवकर भरणा करावा.');
                            Clipboard.setData(ClipboardData(text: buffer.toString()));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('सर्व थकबाकीदारांची यादी कॉपी झाली! (All pending copied!)')),
                            );
                          },
                        ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }
}
