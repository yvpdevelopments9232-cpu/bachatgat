import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_strings.dart';
import '../../models/loan.dart';
import '../../models/member.dart';
import '../../providers/auth_provider.dart';
import '../../providers/loan_provider.dart';
import '../../providers/member_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../loans/collect_emi_screen.dart';
import '../loans/widgets/collect_emi_dialog.dart';

class DuesScreen extends StatefulWidget {
  const DuesScreen({super.key});

  @override
  State<DuesScreen> createState() => _DuesScreenState();
}

class _DuesScreenState extends State<DuesScreen> {
  String _filterMode = 'overdue_only'; // 'overdue_only' or 'all_active'
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
    });
  }

  void _refreshData() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.currentGroup != null) {
      Provider.of<MemberProvider>(context, listen: false).fetchMembers(auth.currentGroup!.id);
      Provider.of<LoanProvider>(context, listen: false).fetchLoans(auth.currentGroup!.id);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final memberProv = Provider.of<MemberProvider>(context);
    final loanProv = Provider.of<LoanProvider>(context);

    // Dynamic real-time calculation of overdue status per loan
    final allLoanInfos = loanProv.getAllLoansOverdueInfo();
    final overdueInfos = allLoanInfos.where((i) => i.isOverdue).toList();

    final totalOverdueAmount = overdueInfos.fold<double>(0.0, (s, i) => s + i.overdueAmount);
    final totalOutstandingPrincipal = allLoanInfos.fold<double>(0.0, (s, i) => s + i.totalOutstanding);

    // Filter displayed list according to selected tab and search
    final displayedList = (_filterMode == 'overdue_only' ? overdueInfos : allLoanInfos).where((info) {
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.toLowerCase().trim();
      final member = _findMember(info.loan.memberId, memberProv.members);
      final memberName = (member?.fullName ?? info.loan.memberName ?? '').toLowerCase();
      final loanCode = info.loan.loanCode.toLowerCase();
      final phone = (member?.mobileNumber ?? '').toLowerCase();
      return memberName.contains(q) || loanCode.contains(q) || phone.contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;

          // Helper widget for metric cards
          Widget buildMetricCards() {
            final card1 = AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 18),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          AppStrings.tr('सक्रिय थकबाकीदार', 'Overdue Defaulters'),
                          style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${overdueInfos.length}',
                    style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.danger),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'एकूण ${allLoanInfos.length} चालू कर्जांपैकी',
                    style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            );

            final card2 = AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.deepOrange.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.event_busy_rounded, color: Colors.deepOrange, size: 18),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          AppStrings.tr('एकूण थकीत हप्ता रक्कम', 'Total Overdue EMIs'),
                          style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '₹ ${totalOverdueAmount.toStringAsFixed(0)}',
                    style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.deepOrange),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'तारीख उलटून गेलेले हप्ते',
                    style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            );

            final card3 = AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.primary, size: 18),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          AppStrings.tr('एकूण येणे मुद्दल', 'Total Pending Principal'),
                          style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '₹ ${totalOutstandingPrincipal.toStringAsFixed(0)}',
                    style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.primary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'चालू कर्जांची उर्वरित मुद्दल',
                    style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            );

            if (isMobile) {
              return Column(
                children: [
                  card1,
                  const SizedBox(height: 10),
                  card2,
                  const SizedBox(height: 10),
                  card3,
                ],
              );
            } else {
              return Row(
                children: [
                  Expanded(child: card1),
                  const SizedBox(width: 14),
                  Expanded(child: card2),
                  const SizedBox(width: 14),
                  Expanded(child: card3),
                ],
              );
            }
          }

          // Filter tab widgets
          final tabOverdue = InkWell(
            onTap: () => setState(() => _filterMode = 'overdue_only'),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _filterMode == 'overdue_only' ? AppColors.danger : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _filterMode == 'overdue_only' ? AppColors.danger : AppColors.cardBorder,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 16,
                    color: _filterMode == 'overdue_only' ? Colors.white : AppColors.danger,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'फक्त थकबाकीदार (${overdueInfos.length})',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _filterMode == 'overdue_only' ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );

          final tabAllActive = InkWell(
            onTap: () => setState(() => _filterMode = 'all_active'),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _filterMode == 'all_active' ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _filterMode == 'all_active' ? AppColors.primary : AppColors.cardBorder,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.list_alt_rounded,
                    size: 16,
                    color: _filterMode == 'all_active' ? Colors.white : AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'सर्व चालू कर्जे (${allLoanInfos.length})',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _filterMode == 'all_active' ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );

          final searchWidget = SizedBox(
            width: isMobile ? double.infinity : 240,
            height: 38,
            child: TextField(
              controller: _searchCtrl,
              onChanged: (val) => setState(() => _searchQuery = val),
              style: GoogleFonts.poppins(fontSize: 12),
              decoration: InputDecoration(
                hintText: 'नाव किंवा कर्ज क्र. शोधा...',
                hintStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade400),
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.cardBorder),
                ),
              ),
            ),
          );

          return RefreshIndicator(
            onRefresh: () async => _refreshData(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(isMobile ? 14 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  if (isMobile)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.tr('थकबाकी व वसुली नोंद (Dues Register)', 'Central Dues & Recovery Register'),
                          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppStrings.tr('तारीख उलटून गेलेले थकीत हप्ते व वसुली व्यवस्थापन', 'Overdue EMIs, Missed Installments & Recovery Tracker'),
                          style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: AppButton(
                            icon: Icons.send_rounded,
                            text: AppStrings.tr('स्मरणपत्र सूचना (Reminders)', 'Send Reminders'),
                            onPressed: overdueInfos.isEmpty
                                ? null
                                : () => _showAllRemindersDialog(context, overdueInfos, memberProv.members),
                          ),
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
                                AppStrings.tr('थकबाकी व वसुली नोंद (Dues Register)', 'Central Dues & Recovery Register'),
                                style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                AppStrings.tr('तारीख उलटून गेलेले थकीत हप्ते व वसुली व्यवस्थापन', 'Overdue EMIs, Missed Installments & Recovery Tracker'),
                                style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        AppButton(
                          icon: Icons.send_rounded,
                          text: AppStrings.tr('स्मरणपत्र सूचना (Reminders)', 'Send Reminders'),
                          onPressed: overdueInfos.isEmpty
                              ? null
                              : () => _showAllRemindersDialog(context, overdueInfos, memberProv.members),
                        ),
                      ],
                    ),
                  const SizedBox(height: 20),

                  // Dues Metrics (3 Cards)
                  buildMetricCards(),
                  const SizedBox(height: 20),

                  // Filter Tabs & Search Bar
                  if (isMobile)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              tabOverdue,
                              const SizedBox(width: 10),
                              tabAllActive,
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        searchWidget,
                      ],
                    )
                  else
                    Row(
                      children: [
                        tabOverdue,
                        const SizedBox(width: 10),
                        tabAllActive,
                        const Spacer(),
                        searchWidget,
                      ],
                    ),
                  const SizedBox(height: 16),

                  // Loan List / Overdue Cards
                  if (displayedList.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            _filterMode == 'overdue_only' ? Icons.check_circle_outline_rounded : Icons.inbox_outlined,
                            size: 56,
                            color: _filterMode == 'overdue_only' ? AppColors.success : Colors.grey.shade400,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _filterMode == 'overdue_only'
                                ? AppStrings.tr('अभिनंदन! एकही सभासदाचा हप्ता थकीत नाही.', 'All members are up to date! No overdue EMIs.')
                                : AppStrings.tr('कोणतेही कर्ज आढळले नाही.', 'No loans found.'),
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: _filterMode == 'overdue_only' ? AppColors.success : AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (_filterMode == 'overdue_only') ...[
                            const SizedBox(height: 6),
                            Text(
                              'सर्व सभासदांचे मासिक कर्ज हप्ते वेळेवर भरले गेले आहेत.',
                              style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ],
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: displayedList.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (ctx, i) {
                        final info = displayedList[i];
                        final member = _findMember(info.loan.memberId, memberProv.members);
                        final memberDisplayName = member?.fullName ?? info.loan.memberName ?? 'सदस्य';

                        return _buildLoanCard(
                          info: info,
                          member: member,
                          memberDisplayName: memberDisplayName,
                          loanProv: loanProv,
                          isMobile: isMobile,
                        );
                      },
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoanCard({
    required LoanOverdueInfo info,
    required Member? member,
    required String memberDisplayName,
    required LoanProvider loanProv,
    required bool isMobile,
  }) {
    final loan = info.loan;
    final isOverdue = info.isOverdue;

    final badgeWidgets = [
      if (isOverdue) ...[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.danger.withOpacity(0.1),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: AppColors.danger.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.timer_outlined, size: 13, color: AppColors.danger),
              const SizedBox(width: 4),
              Text(
                '${info.overdueMonths} महिने थकबाकी (${info.overdueDays} दिवस उशीर)',
                style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.danger),
              ),
            ],
          ),
        ),
        if (info.oldestUnpaidDueDate != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              'थकीत दिनांक: ${_formatDate(info.oldestUnpaidDueDate!)}',
              style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade700),
            ),
          ),
      ] else ...[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.1),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: AppColors.success.withOpacity(0.3)),
          ),
          child: Text(
            'हप्ते नियमित (Up to date)',
            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.success),
          ),
        ),
        if (info.nextDueDate != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              'पुढील देय दिनांक: ${_formatDate(info.nextDueDate!)}',
              style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade700),
            ),
          ),
      ],
    ];

    if (isMobile) {
      return AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: isOverdue ? AppColors.danger.withOpacity(0.12) : AppColors.success.withOpacity(0.12),
                  radius: 20,
                  child: Icon(
                    isOverdue ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
                    color: isOverdue ? AppColors.danger : AppColors.success,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        memberDisplayName,
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'कर्ज क्र: ${loan.loanCode.isNotEmpty ? loan.loanCode : loan.id.substring(0, 8)}',
                        style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (member?.mobileNumber != null && member!.mobileNumber.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)),
                    child: Text('📞 ${member.mobileNumber}', style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey.shade700)),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: badgeWidgets,
            ),
            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isOverdue ? AppColors.danger.withOpacity(0.06) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isOverdue ? AppColors.danger.withOpacity(0.2) : AppColors.cardBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isOverdue ? 'थकबाकी हप्ता रक्कम' : 'थकबाकी',
                        style: GoogleFonts.poppins(fontSize: 10, color: isOverdue ? AppColors.danger : AppColors.success, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        '₹ ${info.overdueAmount.toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 16, color: isOverdue ? AppColors.danger : AppColors.success),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'हप्ता: ₹ ${info.emiAmount.toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                      Text(
                        'शिल्लक मुद्दल: ₹ ${info.totalOutstanding.toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isOverdue) ...[
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange.shade800,
                      side: BorderSide(color: Colors.orange.shade300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    icon: const Icon(Icons.share_outlined, size: 14),
                    label: Text('स्मरणपत्र', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                    onPressed: () => _showSingleReminderDialog(context, info, memberDisplayName, member?.mobileNumber),
                  ),
                  const SizedBox(width: 8),
                ],
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  ),
                  icon: const Icon(Icons.payments_outlined, size: 14, color: Colors.white),
                  label: Text(
                    'हप्ता जमा करा',
                    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                  onPressed: () => _handleCollectEmi(context, loan),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Avatar
              CircleAvatar(
                backgroundColor: isOverdue ? AppColors.danger.withOpacity(0.12) : AppColors.success.withOpacity(0.12),
                radius: 24,
                child: Icon(
                  isOverdue ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
                  color: isOverdue ? AppColors.danger : AppColors.success,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),

              // Borrower Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          memberDisplayName,
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary),
                        ),
                        if (member?.mobileNumber != null && member!.mobileNumber.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '📞 ${member.mobileNumber}',
                              style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade700),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'कर्ज क्र: ${loan.loanCode.isNotEmpty ? loan.loanCode : loan.id.substring(0, 8)} • मासिक हप्ता: ₹ ${info.emiAmount.toStringAsFixed(0)}',
                      style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 6),

                    // Badges and Dates
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: badgeWidgets,
                    ),
                  ],
                ),
              ),

              // Amounts Block (Right Side)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (isOverdue) ...[
                    Text(
                      'थकबाकी हप्ता रक्कम',
                      style: GoogleFonts.poppins(fontSize: 11, color: AppColors.danger, fontWeight: FontWeight.w500),
                    ),
                    Text(
                      '₹ ${info.overdueAmount.toStringAsFixed(0)}',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 19, color: AppColors.danger),
                    ),
                  ] else ...[
                    Text(
                      'थकबाकी',
                      style: GoogleFonts.poppins(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.w500),
                    ),
                    Text(
                      '₹ 0',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.success),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    'शिल्लक मुद्दल: ₹ ${info.totalOutstanding.toStringAsFixed(0)}',
                    style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Actions Footer
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Send Reminder button
              if (isOverdue)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange.shade800,
                    side: BorderSide(color: Colors.orange.shade300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  icon: const Icon(Icons.share_outlined, size: 16),
                  label: Text('स्मरणपत्र (Share)', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                  onPressed: () => _showSingleReminderDialog(context, info, memberDisplayName, member?.mobileNumber),
                ),
              if (isOverdue) const SizedBox(width: 10),

              // Collect EMI Button
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                ),
                icon: const Icon(Icons.payments_outlined, size: 16, color: Colors.white),
                label: Text(
                  'हप्ता जमा करा (Collect EMI)',
                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                ),
                onPressed: () => _handleCollectEmi(context, loan),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleCollectEmi(BuildContext context, Loan loan) async {
    final loanProv = Provider.of<LoanProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);

    if (loan.isDecreasingEmi) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CollectEmiScreen(
            preSelectedLoanId: loan.id,
            preSelectedMemberId: loan.memberId,
          ),
        ),
      );
      if (mounted) _refreshData();
      return;
    }

    // Fixed EMI loan: find next pending EMI and open CollectEmiDialog
    await loanProv.loadEmisForLoan(loan.id);
    final emis = loanProv.selectedLoanEmis;
    LoanEmi? pendingEmi;
    try {
      pendingEmi = emis.firstWhere((e) => e.status == 'pending' || e.status == 'overdue');
    } catch (_) {}

    if (pendingEmi == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('या कर्जाचे सर्व हप्ते पूर्ण भरले आहेत! (All EMIs already paid)')),
        );
      }
      return;
    }

    if (context.mounted) {
      await showDialog(
        context: context,
        builder: (ctx) => CollectEmiDialog(
          loan: loan,
          emi: pendingEmi!,
          auth: auth,
          loanProv: loanProv,
        ),
      );
      if (mounted) _refreshData();
    }
  }

  Member? _findMember(String memberId, List<Member> members) {
    try {
      return members.firstWhere((m) => m.id == memberId);
    } catch (_) {
      return null;
    }
  }

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';
  }

  void _showSingleReminderDialog(BuildContext context, LoanOverdueInfo info, String memberName, String? phone) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final groupName = auth.currentGroup?.groupName ?? 'महिला बचत गट';

    final message = '''
नमस्कार $memberName ताई / बंधू,
आपल्या "$groupName" मधील कर्ज क्र. ${info.loan.loanCode} चे मागील ${info.overdueMonths} महिन्यांचे हप्ते (रक्कम ₹ ${info.overdueAmount.toStringAsFixed(0)}) थकीत आहेत.

कृपया लवकरात लवकर हप्ता जमा करावा ही विनंती.
- व्यवस्थापक, $groupName
'''.trim();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            const Icon(Icons.notifications_active_outlined, color: Colors.orange),
            const SizedBox(width: 8),
            Text('थकबाकी स्मरणपत्र', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('खालील मेसेज कॉपी करून व्हॉट्सॲपवर पाठवू शकता:', style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: SelectableText(
                message,
                style: GoogleFonts.poppins(fontSize: 12, height: 1.4),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('बंद करा'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.white),
            label: const Text('मेसेज कॉपी करा', style: TextStyle(color: Colors.white)),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: message));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('स्मरणपत्र मेसेज क्लिपबोर्डवर कॉपी झाला! WhatsApp वर पाठवू शकता.')),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showAllRemindersDialog(BuildContext context, List<LoanOverdueInfo> overdueInfos, List<Member> members) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        insetPadding: EdgeInsets.symmetric(
          horizontal: MediaQuery.of(ctx).size.width < 500 ? 12 : 40,
          vertical: 24,
        ),
        title: Row(
          children: [
            const Icon(Icons.mark_email_read_outlined, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'सर्व थकबाकीदार सदस्यांना स्मरणपत्र',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'एकूण ${overdueInfos.length} थकबाकीदार सदस्यांना स्मरणपत्र पाठवले जाईल.',
              style: GoogleFonts.poppins(fontSize: 13),
            ),
            const SizedBox(height: 10),
            Text(
              'सर्व सदस्यांच्या मोबाईलवर त्यांच्या थकीत हप्त्यांचे व रकमेचे तपशील एसएमएस/व्हॉट्सॲप द्वारे पाठवले जातील.',
              style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('रद्द करा'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            icon: const Icon(Icons.send_rounded, size: 16, color: Colors.white),
            label: const Text('स्मरणपत्रे पाठवा', style: TextStyle(color: Colors.white)),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${overdueInfos.length} थकबाकीदार सदस्यांना स्मरणपत्रे यशस्वीरित्या पाठवली!'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
