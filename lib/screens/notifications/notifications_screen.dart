import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_strings.dart';
import '../../providers/auth_provider.dart';
import '../../providers/loan_provider.dart';
import '../../services/supabase_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final SupabaseService _service = SupabaseService();
  bool _isLoading = false;

  List<Map<String, dynamic>> _alerts = [];

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final loanProv = Provider.of<LoanProvider>(context, listen: false);

    if (auth.currentGroup != null) {
      final groupId = auth.currentGroup!.id;
      final List<Map<String, dynamic>> generated = [];

      try {
        // 1. Pending/Active loans check
        await loanProv.fetchLoans(groupId);
        for (var loan in loanProv.loans.where((l) => l.isActive && l.outstandingPrincipal > 0)) {
          generated.add({
            'type': 'emi_due',
            'title': 'कर्ज हप्ता देय स्मरणपत्र',
            'message': '${loan.memberName} यांचा कर्ज हप्ता देय आहे. शिल्लक मुद्दल: ₹${loan.outstandingPrincipal.toStringAsFixed(0)}',
            'badge': 'हप्ता प्रलंबित',
            'color': AppColors.danger,
            'icon': Icons.monetization_on_rounded,
          });
        }

        // 2. Upcoming meeting check
        final meetRes = await _service.client
            .from('meetings')
            .select()
            .eq('group_id', groupId)
            .gte('meeting_date', DateFormat('yyyy-MM-dd').format(DateTime.now()))
            .order('meeting_date', ascending: true)
            .limit(1);

        if ((meetRes as List).isNotEmpty) {
          final m = meetRes.first;
          generated.add({
            'type': 'meeting',
            'title': 'आगामी मासिक बैठक स्मरणपत्र',
            'message': 'तारीख: ${m['meeting_date']} • वेळ: ${m['meeting_time'] ?? "१०:००"} • स्थळ: ${m['location']}',
            'badge': 'बैठक उद्या / लवकरच',
            'color': AppColors.primary,
            'icon': Icons.calendar_month_rounded,
          });
        }

        // 3. Document / General Group Reminders
        generated.add({
          'type': 'document',
          'title': 'बचत नोंद व मासिक ताळेबंद वेळ',
          'message': 'चालू महिन्याची बचत जमा करून रोख वही (Cash Book) ताळमेळ पूर्ण करा.',
          'badge': 'नियमित तपासणी',
          'color': AppColors.secondary,
          'icon': Icons.fact_check_rounded,
        });

        setState(() {
          _alerts = generated;
        });
      } catch (e) {
        debugPrint('Error generating alerts: $e');
      }
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;

          return SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? 14 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isMobile)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.tr('२३. सूचना व स्मरणपत्रे केंद्र', '23. Notifications & Reminders'),
                        style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        AppStrings.tr('हप्ते थकबाकी, आगामी बैठका व महत्त्वाच्या सूचना', 'EMI alerts, upcoming meetings & critical reminders'),
                        style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      AppButton(
                        icon: Icons.refresh_rounded,
                        text: AppStrings.tr('रिफ्रेश (Refresh)', 'Refresh'),
                        isOutlined: true,
                        onPressed: _loadAlerts,
                      ),
                    ],
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppStrings.tr('२३. सूचना व स्मरणपत्रे केंद्र', '23. Notifications & Reminders'),
                              style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                            ),
                            Text(
                              AppStrings.tr('हप्ते थकबाकी, आगामी बैठका व महत्त्वाच्या सूचना', 'EMI alerts, upcoming meetings & critical reminders'),
                              style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      AppButton(
                        icon: Icons.refresh_rounded,
                        text: AppStrings.tr('रिफ्रेश (Refresh)', 'Refresh'),
                        isOutlined: true,
                        onPressed: _loadAlerts,
                      ),
                    ],
                  ),
                const SizedBox(height: 20),

                if (_isLoading)
                  const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
                else if (_alerts.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        children: [
                          const Icon(Icons.notifications_off_rounded, size: 60, color: Colors.grey),
                          const SizedBox(height: 12),
                          Text('सध्या कोणतीही प्रलंबित सूचना किंवा स्मरणपत्र नाही.', style: GoogleFonts.poppins(color: Colors.grey)),
                        ],
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _alerts.length,
                    separatorBuilder: (ctx, idx) => const SizedBox(height: 12),
                    itemBuilder: (ctx, i) {
                      final a = _alerts[i];
                      final Color c = a['color'] as Color;

                      return AppCard(
                        padding: EdgeInsets.all(isMobile ? 12 : 16),
                        child: isMobile
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(color: c.withOpacity(0.12), shape: BoxShape.circle),
                                        child: Icon(a['icon'] as IconData, color: c, size: 22),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Wrap(
                                              crossAxisAlignment: WrapCrossAlignment.center,
                                              spacing: 8,
                                              runSpacing: 4,
                                              children: [
                                                Text(
                                                  a['title'] ?? '',
                                                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                                                  child: Text(
                                                    a['badge'] ?? '',
                                                    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: c),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              a['message'] ?? '',
                                              style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                        side: BorderSide(color: AppColors.primary.withOpacity(0.35)),
                                      ),
                                      icon: const Icon(Icons.share_rounded, size: 14),
                                      label: const Text('WhatsApp स्मरणपत्र'),
                                      onPressed: () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('स्मरणपत्र पाठवले: ${a['title']}')),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(color: c.withOpacity(0.12), shape: BoxShape.circle),
                                    child: Icon(a['icon'] as IconData, color: c, size: 24),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              a['title'] ?? '',
                                              style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                            ),
                                            const SizedBox(width: 10),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                                              child: Text(
                                                a['badge'] ?? '',
                                                style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: c),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(a['message'] ?? '', style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                                    icon: const Icon(Icons.share_rounded, size: 14),
                                    label: const Text('WhatsApp स्मरणपत्र'),
                                    onPressed: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('स्मरणपत्र पाठवले: ${a['title']}')),
                                      );
                                    },
                                  ),
                                ],
                              ),
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
