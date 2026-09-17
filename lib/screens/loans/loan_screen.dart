import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_strings.dart';
import '../../models/loan.dart';
import '../../providers/auth_provider.dart';
import '../../providers/loan_provider.dart';
import '../../providers/member_provider.dart';
import '../../providers/bank_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../services/pdf_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/status_badge.dart';
import 'widgets/collect_emi_dialog.dart';
import 'widgets/disburse_loan_dialog.dart';
import 'widgets/loan_details_dialog.dart';
import 'widgets/loan_voucher_dialog.dart';
import 'collect_emi_screen.dart';

class LoanScreen extends StatefulWidget {
  const LoanScreen({super.key});

  @override
  State<LoanScreen> createState() => _LoanScreenState();
}

class _LoanScreenState extends State<LoanScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();

  final TextEditingController _settingRateCtrl = TextEditingController();
  final TextEditingController _settingOverdueDaysCtrl = TextEditingController();
  final TextEditingController _settingLateFeePctCtrl = TextEditingController();
  bool _isSavingSettings = false;
  bool _settingsInitialized = false;
  String _loanTypeFilter = 'all'; // 'all', 'fixed', 'decreasing'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final memberProv = Provider.of<MemberProvider>(context, listen: false);
    final loanProv = Provider.of<LoanProvider>(context, listen: false);

    if (auth.currentGroup != null) {
      await memberProv.fetchMembers(auth.currentGroup!.id);
      await loanProv.fetchLoans(auth.currentGroup!.id, memberProv.members);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    _settingRateCtrl.dispose();
    _settingOverdueDaysCtrl.dispose();
    _settingLateFeePctCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final memberProv = Provider.of<MemberProvider>(context);
    final loanProv = Provider.of<LoanProvider>(context);

    if (!_settingsInitialized && !loanProv.isLoading) {
      final s = loanProv.loanSettings;
      _settingRateCtrl.text = s.interestRate > 0
          ? (s.interestRate.truncateToDouble() == s.interestRate ? s.interestRate.toStringAsFixed(0) : s.interestRate.toStringAsFixed(1))
          : '24';
      _settingOverdueDaysCtrl.text = s.overdueDays.toString();
      _settingLateFeePctCtrl.text = s.lateFeePercentage > 0
          ? (s.lateFeePercentage.truncateToDouble() == s.lateFeePercentage ? s.lateFeePercentage.toStringAsFixed(0) : s.lateFeePercentage.toStringAsFixed(1))
          : '18';
      _settingsInitialized = true;
    }

    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          AppStrings.tr('अंतर्गत कर्ज वाटप व वसुली', 'Internal Loans Management'),
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: isMobile ? 15 : 18),
        ),
        actions: !auth.canWrite
            ? const []
            : isMobile
                ? [
                    IconButton(
                      tooltip: 'स्थिर हप्ता (Fixed EMI)',
                      icon: const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF1E88E5)),
                      onPressed: () => _openFixedEmiSelector(context, auth, memberProv, loanProv),
                    ),
                    IconButton(
                      tooltip: 'घटता हप्ता (Decreasing EMI)',
                      icon: const Icon(Icons.trending_down_rounded, color: AppColors.primary),
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CollectEmiScreen()),
                        );
                        if (mounted) _loadData();
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.tune_rounded, color: AppColors.primary),
                      tooltip: 'कर्ज सेटिंग्ज (Loan Settings)',
                      onPressed: () => _tabController.animateTo(4),
                    ),
                  ]
                : [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E88E5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.account_balance_wallet_outlined, size: 15, color: Colors.white),
                      label: const Text(
                        '💰 स्थिर हप्ता (Fixed)',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => _openFixedEmiSelector(context, auth, memberProv, loanProv),
                    ),
                    const SizedBox(width: 6),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.trending_down_rounded, size: 15, color: Colors.white),
                      label: const Text(
                        '📉 घटता हप्ता (Decreasing)',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CollectEmiScreen()),
                        );
                        if (mounted) _loadData();
                      },
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.tune_rounded, color: AppColors.primary),
                      tooltip: 'कर्ज सेटिंग्ज (Loan Settings)',
                      onPressed: () => _tabController.animateTo(4),
                    ),
                    const SizedBox(width: 8),
                  ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.monetization_on_rounded, size: 20), text: '१. सक्रिय कर्जे (Active)'),
            Tab(icon: Icon(Icons.add_circle_outline_rounded, size: 20), text: '२. नवीन कर्ज वाटप (Disburse)'),
            Tab(icon: Icon(Icons.history_rounded, size: 20), text: '३. हप्ता वसुली इतिहास (EMI History)'),
            Tab(icon: Icon(Icons.check_circle_outline_rounded, size: 20), text: '४. बंद कर्जे (Closed)'),
            Tab(icon: Icon(Icons.tune_rounded, size: 20), text: '५. कर्ज सेटिंग्ज व नियम (Settings)'),
          ],
        ),
      ),
      body: loanProv.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildActiveLoansTab(context, auth, memberProv, loanProv),
                _buildDisburseTab(context, auth, memberProv, loanProv),
                _buildEmiHistoryTab(context, auth, loanProv),
                _buildClosedLoansTab(context, auth, loanProv),
                _buildLoanSettingsTab(context, auth, loanProv),
              ],
            ),
    );
  }

  // ===========================================================================
  // TAB 1: 📋 ACTIVE LOANS
  // ===========================================================================
  Widget _buildActiveLoansTab(
    BuildContext context,
    AuthProvider auth,
    MemberProvider memberProv,
    LoanProvider loanProv,
  ) {
    final activeLoans = loanProv.activeLoans.where((l) {
      if (_loanTypeFilter == 'fixed' && !l.isFixedEmi) return false;
      if (_loanTypeFilter == 'decreasing' && !l.isDecreasingEmi) return false;
      if (_searchCtrl.text.isNotEmpty) {
        final q = _searchCtrl.text.toLowerCase();
        final name = l.memberName?.toLowerCase() ?? '';
        final code = l.loanCode.toLowerCase();
        final purpose = l.purpose?.toLowerCase() ?? '';
        if (!name.contains(q) && !code.contains(q) && !purpose.contains(q)) return false;
      }
      return true;
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KPI Summary Cards
            _buildKpiMetrics(loanProv),
            const SizedBox(height: 16),

            // Search Bar & Disburse Action Button
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 600;
                final searchField = TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'कर्जदार किंवा कर्ज कोड शोधा...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(icon: const Icon(Icons.clear_rounded, size: 18), onPressed: () => setState(() => _searchCtrl.clear()))
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                  ),
                  onChanged: (_) => setState(() {}),
                );

                final disburseBtn = ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                  label: const Text('नवीन कर्ज वाटप', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    _openDisburseDialog(context, auth, memberProv, loanProv);
                  },
                );

                final refreshBtn = AppButton(
                  icon: Icons.refresh_rounded,
                  text: 'रिफ्रेश',
                  onPressed: _loadData,
                );

                if (isNarrow) {
                  return Column(
                    children: [
                      searchField,
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (auth.canAdd) ...[
                            Expanded(child: disburseBtn),
                            const SizedBox(width: 8),
                          ],
                          refreshBtn,
                        ],
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: searchField),
                    if (auth.canAdd) ...[
                      const SizedBox(width: 10),
                      disburseBtn,
                    ],
                    const SizedBox(width: 8),
                    refreshBtn,
                  ],
                );
              },
            ),
            const SizedBox(height: 12),

            // Loan Type Filter Chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: Text('सर्व (${loanProv.activeLoans.length})'),
                  selected: _loanTypeFilter == 'all',
                  onSelected: (val) {
                    if (val) setState(() => _loanTypeFilter = 'all');
                  },
                ),
                ChoiceChip(
                  avatar: const Icon(Icons.account_balance_wallet_outlined, size: 15, color: Color(0xFF1E88E5)),
                  label: Text('💰 स्थिर हप्ता (${loanProv.fixedEmiLoans.length})'),
                  selected: _loanTypeFilter == 'fixed',
                  selectedColor: const Color(0xFF1E88E5).withOpacity(0.18),
                  onSelected: (val) {
                    if (val) setState(() => _loanTypeFilter = 'fixed');
                  },
                ),
                ChoiceChip(
                  avatar: const Icon(Icons.trending_down_rounded, size: 15, color: Colors.deepOrange),
                  label: Text('📉 घटता हप्ता (${loanProv.decreasingEmiLoans.length})'),
                  selected: _loanTypeFilter == 'decreasing',
                  selectedColor: Colors.deepOrange.withOpacity(0.18),
                  onSelected: (val) {
                    if (val) setState(() => _loanTypeFilter = 'decreasing');
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Active Loans List
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('सक्रिय कर्ज यादी (${activeLoans.length})', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700)),
                Text(
                  'डिफॉल्ट सेटिंग: ${loanProv.loanSettings.interestRate.toStringAsFixed(0)}% वार्षिक (नवीन कर्जांसाठी)',
                  style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (activeLoans.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(36),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.monetization_on_outlined, size: 48, color: AppColors.textMuted),
                    const SizedBox(height: 12),
                    Text(
                      'या बचत गटामध्ये अद्याप कोणतेही सक्रिय अंतर्गत कर्ज नाही.',
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text('गटाच्या अंतर्गत निधीतून सभासदांना कर्ज वाटप करण्यासाठी वरील बटण वापरा.', style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textMuted)),
                    if (auth.canAdd) ...[
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                        icon: const Icon(Icons.add_rounded, color: Colors.white),
                        label: const Text('नवीन कर्ज वाटप करा', style: TextStyle(color: Colors.white)),
                        onPressed: () => _openDisburseDialog(context, auth, memberProv, loanProv),
                      ),
                    ],
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: activeLoans.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (ctx, i) {
                  final loan = activeLoans[i];
                  return _buildLoanCard(context, loan, auth, loanProv);
                },
              ),
          ],
        ),
      ),
    );
  }

  // KPI Metrics Banner
  Widget _buildKpiMetrics(LoanProvider loanProv) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    final card1 = _buildMiniKpiCard(
      title: 'एकूण वाटप कर्ज',
      value: '₹ ${loanProv.totalDisbursed.toStringAsFixed(0)}',
      subtext: '${loanProv.loans.length} एकूण कर्जे',
      color: const Color(0xFF2575FC),
      icon: Icons.account_balance_wallet_rounded,
    );
    final card2 = _buildMiniKpiCard(
      title: 'येणे शिल्लक मुद्दल',
      value: '₹ ${loanProv.totalOutstanding.toStringAsFixed(0)}',
      subtext: '${loanProv.activeLoans.length} सक्रिय कर्जे',
      color: AppColors.danger,
      icon: Icons.pending_actions_rounded,
    );
    final card3 = _buildMiniKpiCard(
      title: 'परतफेड रक्कम',
      value: '₹ ${loanProv.totalRepaid.toStringAsFixed(0)}',
      subtext: 'मुद्दल + व्याज जमा',
      color: AppColors.success,
      icon: Icons.check_circle_rounded,
    );
    final card4 = _buildMiniKpiCard(
      title: 'सक्रिय कर्जदार',
      value: '${loanProv.activeBorrowersCount}',
      subtext: 'सभासद संख्या',
      color: const Color(0xFF6A11CB),
      icon: Icons.people_alt_rounded,
    );

    return isMobile
        ? Column(
            children: [
              Row(
                children: [
                  Expanded(child: card1),
                  const SizedBox(width: 8),
                  Expanded(child: card2),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: card3),
                  const SizedBox(width: 8),
                  Expanded(child: card4),
                ],
              ),
            ],
          )
        : Column(
            children: [
              Row(
                children: [
                  Expanded(child: card1),
                  const SizedBox(width: 10),
                  Expanded(child: card2),
                  const SizedBox(width: 10),
                  Expanded(child: card3),
                  const SizedBox(width: 10),
                  Expanded(child: card4),
                ],
              ),
            ],
          );
  }

  Widget _buildMiniKpiCard({
    required String title,
    required String value,
    required String subtext,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(width: 4),
              Icon(icon, color: color, size: 18),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
          Text(subtext, style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textMuted)),
        ],
      ),
    );
  }

  // Individual Loan Card
  Widget _buildLoanCard(BuildContext context, Loan loan, AuthProvider auth, LoanProvider loanProv) {
    final progress = loan.approvedAmount > 0 ? (loan.totalRepaid / loan.approvedAmount).clamp(0.0, 1.0) : 0.0;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primary.withOpacity(0.12),
                child: Text(
                  loan.memberName?.isNotEmpty == true ? loan.memberName![0] : 'L',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: AppColors.primary, fontSize: 16),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            loan.memberName ?? 'अनामिक सभासद',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(loan.loanCode, style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary)),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: loan.isDecreasingEmi ? Colors.orange.withOpacity(0.12) : const Color(0xFF1E88E5).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: loan.isDecreasingEmi ? Colors.orange.shade700 : const Color(0xFF1E88E5),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            loan.isDecreasingEmi ? '📉 घटता हप्ता' : '💰 स्थिर हप्ता',
                            style: GoogleFonts.poppins(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: loan.isDecreasingEmi ? Colors.orange.shade900 : const Color(0xFF1565C0),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'वाटप तारीख: ${loan.applicationDate}${loan.purpose != null ? " • हेतू: ${loan.purpose}" : ""}',
                      style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              StatusBadge(status: loan.status),
            ],
          ),
          const Divider(height: 18),

          // Loan Details Grid
          isMobile
              ? Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildDetailCol('मंजूर मुद्दल', '₹ ${loan.approvedAmount.toStringAsFixed(0)}', AppColors.textPrimary),
                        _buildDetailCol('मासिक हप्ता (EMI)', '₹ ${loan.emiAmount.toStringAsFixed(0)}', AppColors.primary),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildDetailCol('शिल्लक मुद्दल', '₹ ${loan.outstandingPrincipal.toStringAsFixed(0)}', loan.outstandingPrincipal > 0 ? AppColors.danger : AppColors.success),
                        _buildDetailCol('परतफेड रक्कम', '₹ ${loan.totalRepaid.toStringAsFixed(0)}', AppColors.success),
                      ],
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildDetailCol('मंजूर मुद्दल', '₹ ${loan.approvedAmount.toStringAsFixed(0)}', AppColors.textPrimary),
                    _buildDetailCol('मासिक हप्ता (EMI)', '₹ ${loan.emiAmount.toStringAsFixed(0)}', AppColors.primary),
                    _buildDetailCol('शिल्लक मुद्दल', '₹ ${loan.outstandingPrincipal.toStringAsFixed(0)}', loan.outstandingPrincipal > 0 ? AppColors.danger : AppColors.success),
                    _buildDetailCol('परतफेड रक्कम', '₹ ${loan.totalRepaid.toStringAsFixed(0)}', AppColors.success),
                  ],
                ),
          const SizedBox(height: 10),

          // Repayment Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.background,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.success),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('परतफेड प्रगती: ${(progress * 100).toStringAsFixed(0)}%', style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textSecondary)),
              Text('मुदत: ${loan.loanPeriodMonths} महिने (${(loan.interestRate / 12).toStringAsFixed(1)}% दरमहा)', style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 12),

          // Actions Row: [ Pay EMI ] [ View Schedule ] [ Print Voucher ]
          isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (auth.canWrite) ...[
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 9),
                        ),
                        icon: const Icon(Icons.payments_rounded, size: 16, color: Colors.white),
                        label: const Text('हप्ता भरा (Pay EMI)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                        onPressed: () => _openPayEmi(context, loan, auth, loanProv),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 8)),
                            icon: const Icon(Icons.calendar_month_rounded, size: 15, color: AppColors.primary),
                            label: const Text('वेळापत्रक', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (c) => LoanDetailsDialog(loan: loan, auth: auth, loanProv: loanProv),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 8)),
                            icon: const Icon(Icons.print_rounded, size: 15),
                            label: const Text('व्हाउचर', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (c) => LoanVoucherDialog(
                                  loan: loan,
                                  groupName: auth.currentGroup?.groupName ?? 'Sakhi Bachat Gat',
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              : Row(
                  children: [
                    // Pay EMI Button (Only for Admin)
                    if (auth.canWrite) ...[
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          icon: const Icon(Icons.payments_rounded, size: 15, color: Colors.white),
                          label: const Text('हप्ता भरा (Pay EMI)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                          onPressed: () => _openPayEmi(context, loan, auth, loanProv),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],

                    // View Full Schedule Dialog
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                      icon: const Icon(Icons.calendar_month_rounded, size: 15, color: AppColors.primary),
                      label: const Text('वेळापत्रक', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (c) => LoanDetailsDialog(loan: loan, auth: auth, loanProv: loanProv),
                        );
                      },
                    ),
                    const SizedBox(width: 8),

                    // Voucher Slip Print
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                      icon: const Icon(Icons.print_rounded, size: 15),
                      label: const Text('व्हाउचर', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (c) => LoanVoucherDialog(
                            loan: loan,
                            groupName: auth.currentGroup?.groupName ?? 'Sakhi Bachat Gat',
                          ),
                        );
                      },
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildDetailCol(String label, String val, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textSecondary)),
        Text(val, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }

  // ===========================================================================
  // TAB 2: ➕ DISBURSE NEW LOAN FORM
  // ===========================================================================
  Widget _buildDisburseTab(
    BuildContext context,
    AuthProvider auth,
    MemberProvider memberProv,
    LoanProvider loanProv,
  ) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        padding: const EdgeInsets.all(20),
        child: AppCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add_card_rounded, color: AppColors.primary, size: 40),
              ),
              const SizedBox(height: 16),
              Text(
                'नवीन अंतर्गत कर्ज वाटप (Disburse Internal Loan)',
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                'बचत गटातील गरजू सभासदांना अंतर्गत निधीतून वाजवी दरात कर्ज वाटप करा. हप्ता निश्चिती व वेळापत्रक आपोआप तयार होईल.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
                icon: const Icon(Icons.open_in_new_rounded, color: Colors.white),
                label: const Text(
                  'कर्ज वाटप फॉर्म उघडा (Open Disbursement Form)',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                onPressed: () => _openDisburseDialog(context, auth, memberProv, loanProv),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 3: 📜 EMI REPAYMENT HISTORY
  // ===========================================================================
  Widget _buildEmiHistoryTab(BuildContext context, AuthProvider auth, LoanProvider loanProv) {
    final paidEmis = loanProv.emis.where((e) => e.status == 'paid').toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('हप्ता परतफेड इतिहास (${paidEmis.length} नोंदी)', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700)),
              AppButton(icon: Icons.refresh_rounded, text: 'रिफ्रेश', onPressed: _loadData),
            ],
          ),
          const SizedBox(height: 12),

          if (paidEmis.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(36),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                children: [
                  const Icon(Icons.history_toggle_off_rounded, size: 48, color: AppColors.textMuted),
                  const SizedBox(height: 12),
                  Text('अद्याप कोणत्याही हप्त्याची भरणा नोंद आढळली नाही.', style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textSecondary)),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: paidEmis.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final emi = paidEmis[i];
                Loan? matchedLoan;
                try {
                  matchedLoan = loanProv.loans.firstWhere((l) => l.id == emi.loanId);
                } catch (_) {}

                return AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppColors.success.withOpacity(0.12),
                        child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${matchedLoan?.memberName ?? "सदस्य"} • हप्ता #${emi.emiNumber}',
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                            Text(
                              'कर्ज क्र: ${matchedLoan?.loanCode ?? "-"} • भरणा तारीख: ${emi.paymentDate ?? emi.dueDate}',
                              style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('₹ ${(emi.paidAmount > 0 ? emi.paidAmount : emi.emiAmount).toStringAsFixed(0)}', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.success)),
                          Text('मुद्दल: ₹${emi.principal.toStringAsFixed(0)} + व्याज: ₹${emi.interest.toStringAsFixed(0)}', style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textSecondary)),
                        ],
                      ),
                      const SizedBox(width: 6),
                      if (matchedLoan != null)
                        IconButton(
                          icon: const Icon(Icons.print_rounded, size: 18, color: AppColors.primary),
                          tooltip: 'पावती प्रिंट',
                          onPressed: () {
                            PdfService.printLoanEmiReceipt(
                              loan: matchedLoan!,
                              emi: emi,
                              groupName: auth.currentGroup?.groupName ?? 'Sakhi Bachat Gat',
                            );
                          },
                        ),
                      IconButton(
                        icon: const Icon(Icons.edit_note_rounded, size: 20, color: Color(0xFF1E88E5)),
                        tooltip: 'हप्ता नोंद दुरुस्त करा (Edit EMI)',
                        onPressed: () => _showEditEmiDialog(context, emi, matchedLoan, auth, loanProv),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.danger),
                        tooltip: 'हप्ता नोंद डिलीट करा (Delete EMI)',
                        onPressed: () => _confirmDeleteEmi(context, emi, matchedLoan, auth, loanProv),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 4: 🔒 CLOSED LOANS
  // ===========================================================================
  Widget _buildClosedLoansTab(BuildContext context, AuthProvider auth, LoanProvider loanProv) {
    final closedLoans = loanProv.closedLoans;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('पूर्ण परतफेड झालेली कर्जे (${closedLoans.length})', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),

          if (closedLoans.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(36),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                children: [
                  const Icon(Icons.check_circle_outline_rounded, size: 48, color: AppColors.textMuted),
                  const SizedBox(height: 12),
                  Text('अद्याप कोणतेही कर्ज पूर्ण बंद झालेले नाही.', style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textSecondary)),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: closedLoans.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final loan = closedLoans[i];
                return AppCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppColors.success.withOpacity(0.12),
                        child: const Icon(Icons.verified_rounded, color: AppColors.success, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(loan.memberName ?? 'सदस्य', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14)),
                            Text('कर्ज कोड: ${loan.loanCode} • वाटप: ₹${loan.approvedAmount.toStringAsFixed(0)}', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const StatusBadge(status: 'closed'),
                          const SizedBox(height: 2),
                          Text('पूर्ण परतफेड: ₹${loan.totalRepaid.toStringAsFixed(0)}', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.success)),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 5: ⚙️ LOAN SETTINGS & POLICIES
  // ===========================================================================
  Widget _buildLoanSettingsTab(BuildContext context, AuthProvider auth, LoanProvider loanProv) {
    final currentRate = double.tryParse(_settingRateCtrl.text) ?? 24.0;
    final currentOverdueDays = int.tryParse(_settingOverdueDaysCtrl.text) ?? 0;
    final currentLateFeePct = double.tryParse(_settingLateFeePctCtrl.text) ?? 18.0;

    // Preview calculation with sample ₹3000 and 10 late days (matching user's requirement!)
    const samplePrincipal = 3000.0;
    const sampleDays = 10;
    final sampleLateFee = (samplePrincipal * (currentLateFeePct / 100.0)) * (sampleDays / 365.0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card 1: Loan Configuration Card
              AppCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [AppColors.primary, AppColors.secondary]),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.tune_rounded, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'कर्ज व्याजदर व विलंब शुल्क सेटिंग्ज (Loan Settings)',
                                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                              ),
                              Text(
                                'नवीन कर्ज वाटप करताना हा व्याज दर आपोआप घेतला जाईल व हप्ता उशिरा भरल्यास लेट फी आपोआप मोजली जाईल.',
                                style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    // Field 1: Default Interest Rate
                    Text(
                      '१. नवीन कर्जाचा डीफॉल्ट व्याज दर (Default Interest Rate %)*',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _settingRateCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.percent_rounded, size: 18, color: AppColors.primary),
                        suffixText: '% वार्षिक (p.a.)',
                        hintText: '24 (२% दरमहा)',
                        helperText: 'उदा. २४% वार्षिक = २% दरमहा. नवीन कर्ज वाटप फॉर्म उघडताच हा दर आपोआप येईल.',
                        helperStyle: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),

                    // Field 2: Overdue Grace Days
                    Text(
                      '२. ओव्हरड्यू सूट दिवस (Overdue Grace Days)*',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _settingOverdueDaysCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.primary),
                        suffixText: 'दिवस (Days)',
                        hintText: '0 किंवा 5 किंवा 10',
                        helperText: 'नियत तारखेनंतर किती दिवसांपर्यंत दंड आकारला जाऊ नये (उदा. ० दिवस = १ल्या दिवसापासून उशीर लागू).',
                        helperStyle: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),

                    // Field 3: Overdue Late Fee Percentage
                    Text(
                      '३. ओव्हरड्यू लेट फी टक्केवारी (Overdue Late Fee Rate %)*',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _settingLateFeePctCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.trending_up_rounded, size: 18, color: AppColors.primary),
                        suffixText: '% वार्षिक (p.a.)',
                        hintText: '18 किंवा 24',
                        helperText: 'थकीत मुद्दलावर आकारली जाणारी वार्षिक टक्केवारी (हप्ता वसुलीवेळी आपोआप मोजली जाईल).',
                        helperStyle: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),

                    // Live Calculation Preview Box
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6F3FA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary.withOpacity(0.15)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.calculate_rounded, color: AppColors.primary, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'थेट हिशोब पडताळणी (Live Late Fee Formula Preview):',
                                style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.primary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'सूत्र: लेट फी = (थकीत मुद्दल × $currentLateFeePct% ÷ १००) × (उशीर दिवस ÷ ३६५)',
                            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'उदा. जर सदस्याचे थकीत मुद्दल ₹३,००० असेल आणि हप्ता १० दिवस उशिरा भरला, तर:\n(₹३,००० × $currentLateFeePct% ÷ १००) × (१० ÷ ३६५) = ₹${sampleLateFee.toStringAsFixed(0)} विलंब शुल्क.',
                            style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF6B21A8), height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 2,
                        ),
                        icon: _isSavingSettings
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.save_rounded, color: Colors.white),
                        label: Text(
                          _isSavingSettings ? 'जतन होत आहे...' : 'कर्ज सेटिंग्ज जतन करा (Save Loan Settings)',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.white),
                        ),
                        onPressed: _isSavingSettings
                            ? null
                            : () async {
                                final groupId = auth.currentGroup?.id;
                                if (groupId == null) return;

                                setState(() => _isSavingSettings = true);
                                final newSettings = LoanSettings(
                                  interestRate: currentRate,
                                  overdueDays: currentOverdueDays,
                                  lateFeePercentage: currentLateFeePct,
                                  interestType: 'yearly',
                                );

                                final messenger = ScaffoldMessenger.of(context);
                                final ok = await loanProv.updateLoanSettings(groupId, newSettings);
                                if (!mounted) return;
                                setState(() => _isSavingSettings = false);

                                if (ok) {
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text('कर्ज सेटिंग्ज यशस्वीरीत्या सुपाबेसवर जतन झाल्या! नवीन कर्जांमध्ये हा दर आपोआप लागू होईल.'),
                                      backgroundColor: AppColors.success,
                                    ),
                                  );
                                } else {
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text('सेटिंग्ज जतन करताना त्रुटी आली. कृपया पुन्हा प्रयत्न करा.'),
                                      backgroundColor: AppColors.danger,
                                    ),
                                  );
                                }
                              },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Card 2: Group Policy Reference
              AppCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.rule_folder_rounded, color: AppColors.primary, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          'बचत गट अंतर्गत कर्ज मार्गदर्शक नियमावली',
                          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    _buildRuleItem('१. कर्ज व्याज दर:', 'गटाच्या ठरावानुसार $currentRate% वार्षिक (${(currentRate / 12).toStringAsFixed(1)}% दरमहा) व्याज आकारले जाते.'),
                    _buildRuleItem('२. परतफेड मुदत:', 'कर्जाची मुदत साधारणपणे ६ महिने ते २४ महिन्यांपर्यंत निश्चित केली जाते.'),
                    _buildRuleItem('३. हप्ता नियत तारीख:', 'प्रत्येक महिन्याच्या १० तारखेला किंवा मासिक बैठकीदिवशी हप्ता भरणे आवश्यक राहील.'),
                    _buildRuleItem('४. जामीनदार नियम:', 'प्रत्येक कर्जासाठी बचत गटातील किमान १ किंवा २ सभासद जामीनदार असणे बंधनकारक आहे.'),
                    _buildRuleItem('५. विलंब शुल्क:', 'नियत तारखेनंतर $currentOverdueDays दिवसांची सवलत असून, त्यानंतर $currentLateFeePct% वार्षिक दराने उशिराच्या दिवसांनुसार लेट फी आकारली जाईल.'),
                    _buildRuleItem('६. नवीन कर्ज पात्रता:', 'ज्या सदस्याचे जुने कर्ज शिल्लक नाही आणि नियमित बचत जमा आहे, अशा सदस्यालाच नवीन कर्ज मंजूर केले जाईल.'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRuleItem(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.primary)),
          const SizedBox(height: 2),
          Text(desc, style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  // Dialog opener helper
  void _openDisburseDialog(BuildContext context, AuthProvider auth, MemberProvider memberProv, LoanProvider loanProv) async {
    if (memberProv.members.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('कृपया प्रथम सभासद जोडा! (Add members first)')));
      return;
    }
    final res = await showDialog<Loan>(
      context: context,
      builder: (ctx) => DisburseLoanDialog(
        auth: auth,
        loanProv: loanProv,
        members: memberProv.members,
      ),
    );
    if (res != null && mounted) {
      await _loadData();
    }
  }

  Future<void> _openPayEmi(BuildContext context, Loan loan, AuthProvider auth, LoanProvider loanProv) async {
    if (loan.isDecreasingEmi) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CollectEmiScreen(
            preSelectedLoanId: loan.id,
            preSelectedMemberId: loan.memberId,
          ),
        ),
      );
      if (mounted) {
        await _loadData();
      }
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
      if (mounted) {
        await _loadData();
      }
    }
  }

  Future<void> _openFixedEmiSelector(
    BuildContext context,
    AuthProvider auth,
    MemberProvider memberProv,
    LoanProvider loanProv,
  ) async {
    final fixedLoans = loanProv.fixedEmiLoans
        .where((l) => (l.status == 'active' || l.status == 'disbursed') && l.outstandingPrincipal > 0)
        .toList();
    if (fixedLoans.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('सध्या कोणताही स्थिर हप्ता (Fixed EMI) कर्ज उपलब्ध नाही. (No active Fixed EMI loans found)'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (fixedLoans.length == 1) {
      await _openPayEmi(context, fixedLoans.first, auth, loanProv);
      return;
    }

    await showDialog(
      context: context,
      builder: (ctx) {
        final isMobileDialog = MediaQuery.of(ctx).size.width < 500;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding: EdgeInsets.symmetric(
            horizontal: isMobileDialog ? 12 : 40,
            vertical: 24,
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E88E5).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF1E88E5), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'स्थिर हप्ता वसुली (Fixed EMI)',
                  style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: isMobileDialog ? double.maxFinite : 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'हप्ता जमा करण्यासाठी सभासद निवडा:',
                  style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: fixedLoans.length,
                    separatorBuilder: (ctx, index) => const Divider(height: 8),
                    itemBuilder: (context, i) {
                      final l = fixedLoans[i];
                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: const Color(0xFF1E88E5).withOpacity(0.12),
                          child: Text(
                            l.memberName?.isNotEmpty == true ? l.memberName![0] : 'L',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E88E5)),
                          ),
                        ),
                        title: Text(
                          l.memberName ?? 'सभासद',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        subtitle: Text(
                          'कर्ज कोड: ${l.loanCode} • मासिक हप्ता: ₹ ${l.emiAmount.toStringAsFixed(0)}',
                          style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
                        ),
                        trailing: const Icon(Icons.chevron_right, size: 20, color: Color(0xFF1E88E5)),
                        onTap: () {
                          Navigator.pop(ctx);
                          _openPayEmi(context, l, auth, loanProv);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('रद्द करा (Cancel)'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteEmi(
    BuildContext context,
    LoanEmi emi,
    Loan? matchedLoan,
    AuthProvider auth,
    LoanProvider loanProv,
  ) {
    final loanCode = matchedLoan?.loanCode ?? '-';
    final memberName = matchedLoan?.memberName ?? 'सदस्य';
    final dashProv = Provider.of<DashboardProvider>(context, listen: false);
    final bankProv = Provider.of<BankProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.danger),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'हप्ता डिलीट करा?',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Text(
          '$memberName यांच्या कर्ज ($loanCode) चा हप्ता क्र. ${emi.emiNumber} (रक्कम: ₹${emi.paidAmount.toStringAsFixed(0)}) डिलीट करायचा आहे का?\n\n'
          'टीप: भरलेली मुद्दल (₹${emi.principal.toStringAsFixed(0)}) कर्जाच्या उर्वरित मुद्दलात पूर्ववत जोडली जाईल आणि बँक/कॅश शिल्लक आपोआप दुरुस्त होईल.',
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('रद्द करा'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              Navigator.pop(ctx);
              final groupId = auth.currentGroup?.id;
              if (groupId == null) return;

              final success = await loanProv.deleteEmi(
                groupId: groupId,
                loanId: emi.loanId,
                emiId: emi.id,
              );
              if (success && mounted) {
                try {
                  await dashProv.loadDashboardMetrics(groupId);
                  await bankProv.loadBanks(groupId);
                } catch (_) {}
                if (mounted) {
                  await _loadData();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('हप्ता क्र. ${emi.emiNumber} यशस्वीरीत्या डिलीट झाला! शिल्लक अपडेट केली आहे.'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              }
            },
            child: const Text('डिलीट करा', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showEditEmiDialog(
    BuildContext context,
    LoanEmi emi,
    Loan? matchedLoan,
    AuthProvider auth,
    LoanProvider loanProv,
  ) {
    final dashProv = Provider.of<DashboardProvider>(context, listen: false);
    final bankProv = Provider.of<BankProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);

    final principalCtrl = TextEditingController(text: emi.principal.toStringAsFixed(0));
    final interestCtrl = TextEditingController(text: emi.interest.toStringAsFixed(0));
    final lateFeeCtrl = TextEditingController(text: emi.lateFee.toStringAsFixed(0));
    final totalPaidCtrl = TextEditingController(text: (emi.paidAmount > 0 ? emi.paidAmount : emi.emiAmount).toStringAsFixed(0));
    final dateCtrl = TextEditingController(text: emi.paymentDate ?? emi.dueDate);
    final remarksCtrl = TextEditingController(text: emi.remarks ?? '');
    String mode = (emi.paymentMode != null && emi.paymentMode!.isNotEmpty) ? emi.paymentMode! : 'cash';

    void recalc() {
      final p = double.tryParse(principalCtrl.text) ?? 0.0;
      final i = double.tryParse(interestCtrl.text) ?? 0.0;
      final lf = double.tryParse(lateFeeCtrl.text) ?? 0.0;
      totalPaidCtrl.text = (p + i + lf).toStringAsFixed(0);
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            '${matchedLoan?.memberName ?? "सदस्य"} - हप्ता क्र. ${emi.emiNumber} दुरुस्त करा (Edit EMI)',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: principalCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'मुद्दल (Principal)*', prefixText: '₹ '),
                  onChanged: (_) => setDlgState(() => recalc()),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: interestCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'व्याज (Interest)*', prefixText: '₹ '),
                  onChanged: (_) => setDlgState(() => recalc()),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: lateFeeCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'विलंब शुल्क / दंड (Late Fee)', prefixText: '₹ '),
                  onChanged: (_) => setDlgState(() => recalc()),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: totalPaidCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'एकूण भरलेली रक्कम (Total Paid)*', prefixText: '₹ '),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: dateCtrl,
                  decoration: const InputDecoration(labelText: 'भरणा तारीख (Payment Date)*', hintText: 'YYYY-MM-DD'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: remarksCtrl,
                  decoration: const InputDecoration(labelText: 'शेरा (Remarks)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('रद्द करा')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () async {
                final p = double.tryParse(principalCtrl.text) ?? 0.0;
                final i = double.tryParse(interestCtrl.text) ?? 0.0;
                final lf = double.tryParse(lateFeeCtrl.text) ?? 0.0;
                final total = double.tryParse(totalPaidCtrl.text) ?? (p + i + lf);

                Navigator.pop(ctx);
                final groupId = auth.currentGroup?.id;
                if (groupId == null) return;

                final success = await loanProv.updateEmi(
                  groupId: groupId,
                  loanId: emi.loanId,
                  emiId: emi.id,
                  newPrincipal: p,
                  newInterest: i,
                  newLateFee: lf,
                  newTotalPaid: total,
                  paymentMode: mode,
                  paymentDate: dateCtrl.text.trim(),
                  collectedBy: auth.currentProfile?.fullName ?? 'व्यवस्थापक',
                  remarks: remarksCtrl.text.trim(),
                );

                if (success && mounted) {
                  try {
                    await dashProv.loadDashboardMetrics(groupId);
                    await bankProv.loadBanks(groupId);
                  } catch (_) {}
                  if (mounted) {
                    await _loadData();
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('हप्ता क्र. ${emi.emiNumber} यशस्वीरीत्या दुरुस्त झाला! सर्व मूल्ये अपडेट झाली.'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                }
              },
              child: const Text('अपडेट करा', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

