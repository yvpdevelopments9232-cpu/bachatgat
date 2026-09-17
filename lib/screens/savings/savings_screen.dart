import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_strings.dart';
import '../../models/member.dart';
import '../../models/monthly_saving.dart';
import '../../models/saving_plan.dart';
import '../../providers/auth_provider.dart';
import '../../providers/member_provider.dart';
import '../../providers/monthly_savings_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../services/pdf_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import 'widgets/collect_saving_dialog.dart';
import 'widgets/member_ledger_dialog.dart';
import 'widgets/pending_reminder_dialog.dart';
import 'widgets/saving_receipt_dialog.dart';

class SavingsScreen extends StatefulWidget {
  const SavingsScreen({super.key});

  @override
  State<SavingsScreen> createState() => _SavingsScreenState();
}

class _SavingsScreenState extends State<SavingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _historySearchCtrl = TextEditingController();

  // Settings form controllers
  late TextEditingController _planNameCtrl;
  late TextEditingController _planAmountCtrl;
  late TextEditingController _dueDayCtrl;
  late TextEditingController _gracePeriodCtrl;
  late TextEditingController _lateFeeCtrl;
  String _planStatus = 'active';

  // Selected Member for Tab 2 (Member-wise)
  Member? _ledgerSelectedMember;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final memberProv = Provider.of<MemberProvider>(context, listen: false);
      final savingsProv = Provider.of<MonthlySavingsProvider>(context, listen: false);
      final gId = auth.currentGroup?.id;
      if (gId == null || gId.isEmpty) return;

      if (_tabController.index == 2) {
        // 🚀 Tab 3: History (0-indexed: 2) -> Refresh history immediately!
        savingsProv.loadSavingsHistory(groupId: gId);
      } else if (_tabController.index == 0) {
        // 🚀 Tab 1: Collection (0-indexed: 0) -> Refresh collection immediately!
        savingsProv.loadMonthlySavings(gId, memberProv.members);
      } else if (_tabController.index == 1) {
        // 🚀 Tab 2: Member Ledger (0-indexed: 1) -> Refresh selected member ledger!
        if (_ledgerSelectedMember != null) {
          savingsProv.loadMemberYearLedger(
            groupId: gId,
            memberId: _ledgerSelectedMember!.id,
            year: DateTime.now().year,
            member: _ledgerSelectedMember!,
          );
        }
      }
    });

    _planNameCtrl = TextEditingController(text: 'Regular Monthly Saving (नियमित मासिक बचत)');
    _planAmountCtrl = TextEditingController(text: '500');
    _dueDayCtrl = TextEditingController(text: '10');
    _gracePeriodCtrl = TextEditingController(text: '5');
    _lateFeeCtrl = TextEditingController(text: '20');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final memberProv = Provider.of<MemberProvider>(context, listen: false);
    final savingsProv = Provider.of<MonthlySavingsProvider>(context, listen: false);

    if (auth.currentGroup != null) {
      await memberProv.fetchMembers(auth.currentGroup!.id);
      await savingsProv.loadMonthlySavings(auth.currentGroup!.id, memberProv.members);
      await savingsProv.loadSavingsHistory(groupId: auth.currentGroup!.id);

      // Populate plan controllers if plan exists
      final plan = savingsProv.activePlan;
      if (plan != null) {
        _planNameCtrl.text = plan.planName;
        _planAmountCtrl.text = plan.monthlyAmount.toStringAsFixed(0);
        _dueDayCtrl.text = '${plan.dueDay}';
        _gracePeriodCtrl.text = '${plan.gracePeriodDays}';
        _lateFeeCtrl.text = plan.lateFee.toStringAsFixed(0);
        _planStatus = plan.status;
      }

      if (memberProv.members.isNotEmpty && _ledgerSelectedMember == null) {
        setState(() {
          _ledgerSelectedMember = memberProv.members.first;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    _historySearchCtrl.dispose();
    _planNameCtrl.dispose();
    _planAmountCtrl.dispose();
    _dueDayCtrl.dispose();
    _gracePeriodCtrl.dispose();
    _lateFeeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final memberProv = Provider.of<MemberProvider>(context);
    final savingsProv = Provider.of<MonthlySavingsProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          AppStrings.tr('मासिक बचत व्यवस्थापन', 'Monthly Savings Management'),
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18),
        ),
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
            Tab(icon: Icon(Icons.fact_check_rounded, size: 20), text: '१. मासिक संकलन (Collection)'),
            Tab(icon: Icon(Icons.person_pin_rounded, size: 20), text: '२. सदस्य खातेवही (Member Ledger)'),
            Tab(icon: Icon(Icons.history_rounded, size: 20), text: '३. बचत इतिहास (History)'),
            Tab(icon: Icon(Icons.analytics_rounded, size: 20), text: '४. मासिक अहवाल (Reports)'),
            Tab(icon: Icon(Icons.settings_suggest_rounded, size: 20), text: '५. बचत सेटिंग्ज (Settings)'),
          ],
        ),
      ),
      body: savingsProv.isLoading && savingsProv.monthlySavings.isEmpty
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildCollectionTab(context, auth, memberProv, savingsProv),
                _buildMemberLedgerTab(context, auth, memberProv, savingsProv),
                _buildHistoryTab(context, auth, memberProv, savingsProv),
                _buildReportsTab(context, auth, savingsProv),
                _buildSettingsTab(context, auth, memberProv, savingsProv),
              ],
            ),
    );
  }

  // ===========================================================================
  // TAB 1: 📋 MONTHLY COLLECTION SCREEN
  // ===========================================================================
  Widget _buildCollectionTab(
    BuildContext context,
    AuthProvider auth,
    MemberProvider memberProv,
    MonthlySavingsProvider savingsProv,
  ) {
    final members = memberProv.members;
    final savings = savingsProv.monthlySavings;
    final searchQuery = _searchCtrl.text.trim().toLowerCase();

    final filteredSavings = savings.where((s) {
      if (searchQuery.isEmpty) return true;
      final name = (s.memberName ?? '').toLowerCase();
      final code = (s.memberCode ?? '').toLowerCase();
      return name.contains(searchQuery) || code.contains(searchQuery);
    }).toList();

    return RefreshIndicator(
      onRefresh: () => _loadData(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Month Selector Bar (◀ September 2026 ▶)
            _buildMonthSelectorBar(context, auth, memberProv, savingsProv),
            const SizedBox(height: 14),

            // Top Summary KPI Cards
            _buildKpiCards(savingsProv),
            const SizedBox(height: 14),

            // Reminder Banner if pending
            if (savingsProv.pendingMembers.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.warning.withOpacity(0.4)),
                ),
                child: LayoutBuilder(
                  builder: (context, bannerConstraints) {
                    final isBannerNarrow = bannerConstraints.maxWidth < 500;
                    final reminderBtn = ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.warning,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      icon: const Icon(Icons.send_rounded, size: 14, color: Colors.white),
                      label: const Text('सूचना पाठवा (Remind)', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700)),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => PendingReminderDialog(
                            pendingSavings: savingsProv.pendingMembers,
                            groupName: auth.currentGroup?.groupName ?? 'Sakhi Bachat Gat',
                            monthName: savingsProv.selectedMonthNameMr,
                            year: savingsProv.selectedYear,
                          ),
                        );
                      },
                    );

                    if (isBannerNarrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.notifications_active_rounded, color: AppColors.warning, size: 22),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${savingsProv.pendingMembers.length} सदस्यांचे बचत संकलन बाकी आहे.',
                                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SizedBox(width: double.infinity, child: reminderBtn),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        const Icon(Icons.notifications_active_rounded, color: AppColors.warning, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${savingsProv.pendingMembers.length} सदस्यांचे या महिन्याचे बचत संकलन बाकी आहे.',
                            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          ),
                        ),
                        reminderBtn,
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Search Bar & Actions Row
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 600;
                final searchField = TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'सदस्याचे नाव किंवा कोड शोधा...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () => setState(() => _searchCtrl.clear()),
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  ),
                  onChanged: (_) => setState(() {}),
                );

                final addSavingBtn = ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                  label: const Text(
                    'नवीन बचत भरा (Add Saving)',
                    style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  onPressed: () async {
                    if (members.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('कृपया प्रथम सदस्य जोडा (Add members first)')),
                      );
                      return;
                    }
                    final target = filteredSavings.isNotEmpty
                        ? filteredSavings.first
                        : MonthlySaving(
                            id: '',
                            groupId: auth.currentGroup?.id ?? '',
                            memberId: members.first.id,
                            memberName: members.first.fullName,
                            memberCode: members.first.memberCode,
                            mobileNumber: members.first.mobileNumber,
                            month: savingsProv.selectedMonth,
                            year: savingsProv.selectedYear,
                            dueDate: DateTime.now().toString().split(' ').first,
                            expectedAmount: savingsProv.activePlan?.monthlyAmount ?? 500.0,
                            paidAmount: 0.0,
                          );
                    final res = await showDialog<MonthlySaving>(
                      context: context,
                      builder: (ctx) => CollectSavingDialog(
                        monthlySaving: target,
                        auth: auth,
                        savingsProv: savingsProv,
                        members: members,
                      ),
                    );
                    if (res != null && context.mounted) {
                      setState(() {});
                      if (auth.currentGroup != null) {
                        try {
                          final dashProv = Provider.of<DashboardProvider>(context, listen: false);
                          dashProv.loadDashboardMetrics(auth.currentGroup!.id);
                        } catch (_) {}
                      }
                      showDialog(
                        context: context,
                        builder: (ctx) => SavingReceiptDialog(
                          saving: res,
                          groupName: auth.currentGroup?.groupName ?? 'Sakhi Bachat Gat',
                        ),
                      );
                    }
                  },
                );

                final refreshBtn = AppButton(
                  icon: Icons.refresh_rounded,
                  text: 'रिफ्रेश',
                  onPressed: () => _loadData(),
                );

                if (isNarrow) {
                  return Column(
                    children: [
                      searchField,
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (auth.canAdd) ...[
                            Expanded(child: addSavingBtn),
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
                      addSavingBtn,
                    ],
                    const SizedBox(width: 8),
                    refreshBtn,
                  ],
                );
              },
            ),
            const SizedBox(height: 14),

            // Members Collection Table / Cards
            if (filteredSavings.isEmpty)
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
                    const Icon(Icons.event_busy_rounded, size: 48, color: AppColors.textMuted),
                    const SizedBox(height: 12),
                    Text(
                      members.isEmpty
                          ? 'या बचत गटामध्ये अद्याप सदस्य जोडलेले नाहीत.'
                          : (searchQuery.isNotEmpty)
                              ? 'शोध परिणामात कोणतीही नोंद आढळली नाही.'
                              : '${savingsProv.selectedMonthNameMr} ${savingsProv.selectedYear} मध्ये कोणतीही बचत जमा नोंद नाही.\n(No savings collected for ${savingsProv.selectedMonthNameEn} ${savingsProv.selectedYear})',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredSavings.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (ctx, i) {
                  final item = filteredSavings[i];
                  return _buildMemberCollectionCard(context, item, auth, savingsProv, members);
                },
              ),
          ],
        ),
      ),
    );
  }

  // Month Selector Bar (◀ September 2026 ▶)
  Widget _buildMonthSelectorBar(
    BuildContext context,
    AuthProvider auth,
    MemberProvider memberProv,
    MonthlySavingsProvider savingsProv,
  ) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, size: 18, color: AppColors.primary),
            tooltip: 'मागील महिना',
            onPressed: () {
              if (auth.currentGroup != null) {
                savingsProv.changeMonth(-1, auth.currentGroup!.id, memberProv.members);
              }
            },
          ),
          InkWell(
            onTap: () => _showMonthYearPicker(context, auth, memberProv, savingsProv),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month_rounded, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '${savingsProv.selectedMonthNameMr} ${savingsProv.selectedYear}',
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primary),
                  ),
                  Text(
                    ' (${savingsProv.selectedMonthNameEn})',
                    style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down_rounded, color: AppColors.primary),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18, color: AppColors.primary),
            tooltip: 'पुढील महिना',
            onPressed: () {
              if (auth.currentGroup != null) {
                savingsProv.changeMonth(1, auth.currentGroup!.id, memberProv.members);
              }
            },
          ),
        ],
      ),
    );
  }

  // Summary KPIs (Total Members, Expected, Actual, Pending, Rate)
  Widget _buildKpiCards(MonthlySavingsProvider savingsProv) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    final cardExpected = _buildMiniKpiCard(
      title: 'अपेक्षित संकलन',
      value: '₹ ${savingsProv.totalExpected.toStringAsFixed(0)}',
      subtext: '${savingsProv.totalMembers} सदस्य',
      color: const Color(0xFF2575FC),
      icon: Icons.assignment_outlined,
    );
    final cardPaid = _buildMiniKpiCard(
      title: 'जमा संकलन (Paid)',
      value: '₹ ${savingsProv.totalActual.toStringAsFixed(0)}',
      subtext: 'दर: ${savingsProv.collectionRate.toStringAsFixed(0)}%',
      color: AppColors.success,
      icon: Icons.check_circle_rounded,
    );
    final cardPending = _buildMiniKpiCard(
      title: 'प्रलंबित बाकी (Pending)',
      value: '₹ ${savingsProv.totalPending.toStringAsFixed(0)}',
      subtext: '${savingsProv.pendingMembers.length} सदस्य',
      color: AppColors.danger,
      icon: Icons.pending_actions_rounded,
    );

    return Column(
      children: [
        if (isMobile) ...[
          Row(
            children: [
              Expanded(child: cardPaid),
              const SizedBox(width: 8),
              Expanded(child: cardPending),
            ],
          ),
          const SizedBox(height: 8),
          cardExpected,
        ] else
          Row(
            children: [
              Expanded(child: cardExpected),
              const SizedBox(width: 10),
              Expanded(child: cardPaid),
              const SizedBox(width: 10),
              Expanded(child: cardPending),
            ],
          ),
        const SizedBox(height: 10),
        // Payment Mode breakdown
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Flexible(
                child: Text(
                  '💵 Cash: ₹${savingsProv.cashCollection.toStringAsFixed(0)}',
                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(width: 1, height: 16, color: AppColors.divider, margin: const EdgeInsets.symmetric(horizontal: 4)),
              Flexible(
                child: Text(
                  '📱 UPI: ₹${savingsProv.upiCollection.toStringAsFixed(0)}',
                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(width: 1, height: 16, color: AppColors.divider, margin: const EdgeInsets.symmetric(horizontal: 4)),
              Flexible(
                child: Text(
                  '🏦 Bank: ₹${savingsProv.bankCollection.toStringAsFixed(0)}',
                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
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
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.08), blurRadius: 6, offset: const Offset(0, 3)),
        ],
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
              Icon(icon, color: color, size: 16),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700, color: color)),
          Text(subtext, style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textMuted)),
        ],
      ),
    );
  }

  // Member Collection Row Card
  Widget _buildMemberCollectionCard(
    BuildContext context,
    MonthlySaving item,
    AuthProvider auth,
    MonthlySavingsProvider savingsProv,
    List<Member> members,
  ) {
    Color statusColor;
    String statusText;

    if (item.isPaid) {
      statusColor = AppColors.success;
      statusText = '✅ Paid';
    } else if (item.isPartial) {
      statusColor = AppColors.warning;
      statusText = '🟠 Partial';
    } else if (item.isOverdue) {
      statusColor = AppColors.danger;
      statusText = '⚠️ Overdue';
    } else {
      statusColor = AppColors.danger;
      statusText = '🔴 Pending';
    }

    final balance = item.balanceAmount > 0 ? item.balanceAmount : (item.expectedAmount - item.paidAmount);

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 20,
                backgroundColor: statusColor.withOpacity(0.12),
                child: Text(
                  (item.memberName != null && item.memberName!.isNotEmpty) ? item.memberName![0] : 'S',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: statusColor, fontSize: 16),
                ),
              ),
              const SizedBox(width: 12),

              // Member Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.memberName ?? 'सदस्य',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    Text(
                      '${item.memberCode ?? "MB-001"} • मो: ${item.mobileNumber ?? "-"}',
                      style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),

              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Text(
                  statusText,
                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor),
                ),
              ),
            ],
          ),
          const Divider(height: 16),

          // Amounts breakdown
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildAmountItem('Expected', '₹${item.expectedAmount.toStringAsFixed(0)}', AppColors.textSecondary),
              _buildAmountItem('Paid', '₹${item.paidAmount.toStringAsFixed(0)}', AppColors.success),
              _buildAmountItem('Balance', '₹${(balance > 0 ? balance : 0.0).toStringAsFixed(0)}', balance > 0 ? AppColors.danger : AppColors.textSecondary),
              if (item.lateFee > 0)
                _buildAmountItem('Late Fee', '₹${item.lateFee.toStringAsFixed(0)}', AppColors.warning),
            ],
          ),
          const SizedBox(height: 12),

          // Actions Row: [ Collect ] [ View ] [ Edit ] [ Print Receipt ]
          Row(
            children: [
              // Collect Button (Only for Admin)
              if (auth.canWrite) ...[
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: item.isPaid ? AppColors.secondary : AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    icon: const Icon(Icons.add_card_rounded, size: 14, color: Colors.white),
                    label: Text(
                      item.isPaid ? 'अधिक जमा' : 'Collect (भरा)',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                    onPressed: () async {
                      final res = await showDialog<MonthlySaving>(
                        context: context,
                        builder: (ctx) => CollectSavingDialog(
                          monthlySaving: item,
                          auth: auth,
                          savingsProv: savingsProv,
                          members: members,
                        ),
                      );
                      if (res != null && context.mounted) {
                        setState(() {});
                        if (auth.currentGroup != null) {
                          try {
                            final dashProv = Provider.of<DashboardProvider>(context, listen: false);
                            dashProv.loadDashboardMetrics(auth.currentGroup!.id);
                          } catch (_) {}
                        }
                        showDialog(
                          context: context,
                          builder: (ctx) => SavingReceiptDialog(
                            saving: res,
                            groupName: auth.currentGroup?.groupName ?? 'Sakhi Bachat Gat',
                          ),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(width: 6),
              ],

              // View Ledger
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                child: const Icon(Icons.visibility_rounded, size: 16),
                onPressed: () {
                  Member? m;
                  try {
                    m = members.firstWhere((x) => x.id == item.memberId);
                  } catch (_) {}
                  if (m != null) {
                    showDialog(
                      context: context,
                      builder: (ctx) => MemberLedgerDialog(
                        member: m!,
                        auth: auth,
                        savingsProv: savingsProv,
                      ),
                    );
                  }
                },
              ),
              const SizedBox(width: 6),

              // Print Receipt (if paid)
              if (item.paidAmount > 0)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  icon: const Icon(Icons.print_rounded, size: 16, color: AppColors.primary),
                  label: const Text('पावती', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
                  onPressed: () {
                    PdfService.printMonthlySavingReceipt(
                      saving: item,
                      groupName: auth.currentGroup?.groupName ?? 'Sakhi Bachat Gat',
                    );
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAmountItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textSecondary)),
        Text(value, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }

  // Month & Year Picker Dialog
  void _showMonthYearPicker(
    BuildContext context,
    AuthProvider auth,
    MemberProvider memberProv,
    MonthlySavingsProvider savingsProv,
  ) {
    int tempMonth = savingsProv.selectedMonth;
    int tempYear = savingsProv.selectedYear;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final maxYear = math.max(DateTime.now().year + 2, auth.globalEndDate.year + 1);
          final yearsList = {for (int y = 2020; y <= maxYear; y++) y, tempYear}.toList()..sort();

          return AlertDialog(
            title: Text(
              'महिना व वर्ष निवडा (Select Month & Year)',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  value: tempYear,
                  decoration: const InputDecoration(labelText: 'वर्ष (Year)'),
                  items: yearsList.map((y) {
                    return DropdownMenuItem(value: y, child: Text('$y'));
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) setDlgState(() => tempYear = v);
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<int>(
                  value: tempMonth,
                  decoration: const InputDecoration(labelText: 'महिना (Month)'),
                  items: List.generate(12, (index) {
                    final m = index + 1;
                    return DropdownMenuItem(
                      value: m,
                      child: Text('${MonthlySaving.monthNamesMr[index]} (${MonthlySaving.monthNamesEn[index]})'),
                    );
                  }),
                  onChanged: (v) {
                    if (v != null) setDlgState(() => tempMonth = v);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.cancel)),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: () {
                  Navigator.pop(ctx);
                  if (auth.currentGroup != null) {
                    savingsProv.setMonthAndYear(tempMonth, tempYear, auth.currentGroup!.id, memberProv.members);
                  }
                },
                child: const Text('निवडा (Select)', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  // History Month & Year Picker Dialog
  void _showHistoryMonthYearPicker(
    BuildContext context,
    AuthProvider auth,
    MonthlySavingsProvider savingsProv,
  ) {
    int tempMonth = savingsProv.historySelectedMonth;
    int tempYear = savingsProv.historySelectedYear;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final maxYear = math.max(DateTime.now().year + 2, auth.globalEndDate.year + 1);
          final yearsList = {for (int y = 2020; y <= maxYear; y++) y, tempYear}.toList()..sort();

          return AlertDialog(
            title: Text(
              'इतिहास महिना व वर्ष निवडा (Select History Month & Year)',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  value: tempYear,
                  decoration: const InputDecoration(labelText: 'वर्ष (Year)'),
                  items: yearsList.map((y) {
                    return DropdownMenuItem(value: y, child: Text('$y'));
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) setDlgState(() => tempYear = v);
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<int>(
                  value: tempMonth,
                decoration: const InputDecoration(labelText: 'महिना (Month)'),
                items: List.generate(12, (index) {
                  final m = index + 1;
                  return DropdownMenuItem(
                    value: m,
                    child: Text('${MonthlySaving.monthNamesMr[index]} (${MonthlySaving.monthNamesEn[index]})'),
                  );
                }),
                onChanged: (v) {
                  if (v != null) setDlgState(() => tempMonth = v);
                },
              ),
            ],
          ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.cancel)),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: () {
                  Navigator.pop(ctx);
                  if (auth.currentGroup != null) {
                    savingsProv.setHistoryMonth(tempMonth, tempYear, auth.currentGroup!.id);
                  }
                },
                child: const Text('निवडा (Select)', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  // ===========================================================================
  // TAB 2: 📊 MEMBER-WISE 12-MONTH SAVING LEDGER
  // ===========================================================================
  Widget _buildMemberLedgerTab(
    BuildContext context,
    AuthProvider auth,
    MemberProvider memberProv,
    MonthlySavingsProvider savingsProv,
  ) {
    final members = memberProv.members;
    if (members.isEmpty) {
      return Center(
        child: Text('या बचत गटामध्ये अद्याप सदस्य जोडलेले नाहीत.', style: GoogleFonts.poppins(color: AppColors.textSecondary)),
      );
    }

    _ledgerSelectedMember ??= members.first;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Member Selector
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('सदस्य निवडा (Select Member)', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 10),
                DropdownButtonFormField<Member>(
                  value: _ledgerSelectedMember,
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.person_rounded)),
                  items: members.map((m) {
                    return DropdownMenuItem(
                      value: m,
                      child: Text('${m.fullName} (${m.memberCode})'),
                    );
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _ledgerSelectedMember = v);
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Ledger Card with 12 Months
          if (_ledgerSelectedMember != null)
            _buildMember12MonthGrid(context, auth, _ledgerSelectedMember!, savingsProv),
        ],
      ),
    );
  }

  Widget _buildMember12MonthGrid(
    BuildContext context,
    AuthProvider auth,
    Member member,
    MonthlySavingsProvider savingsProv,
  ) {
    return FutureBuilder<List<MonthlySaving>>(
      future: auth.currentGroup != null
          ? savingsProv.loadMemberYearLedger(
              groupId: auth.currentGroup!.id,
              memberId: member.id,
              year: savingsProv.selectedYear,
              member: member,
            )
          : Future.value([]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
        }

        final ledger = snapshot.data ?? [];
        final totalExpected = ledger.fold(0.0, (s, l) => s + l.expectedAmount);
        final totalPaid = ledger.fold(0.0, (s, l) => s + l.paidAmount);
        final totalPending = (totalExpected - totalPaid) > 0 ? (totalExpected - totalPaid) : 0.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${member.fullName} - ${savingsProv.selectedYear} बचत नोंद',
                        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                      if (member.joiningDate != null && member.joiningDate!.isNotEmpty)
                        Text(
                          'प्रवेश तारीख: ${member.joiningDate}',
                          style: GoogleFonts.poppins(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600),
                        ),
                    ],
                  ),
                ),
                Text(
                  'आयडी: ${member.memberCode}',
                  style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Ledger Table / Empty State
            if (ledger.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.person_off_rounded, size: 40, color: AppColors.textMuted),
                    const SizedBox(height: 10),
                    Text(
                      'हा सदस्य ${member.joiningDate ?? ""} रोजी दाखल झाला आहे.\n${savingsProv.selectedYear} या वर्षात कोणतीही बचत नोंद उपलब्ध नाही.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              )
            else
              AppCard(
                padding: const EdgeInsets.all(12),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: ledger.length,
                  separatorBuilder: (context, index) => const Divider(height: 12),
                itemBuilder: (ctx, i) {
                  final item = ledger[i];
                  final isPaid = item.isPaid;
                  final isPartial = item.isPartial;

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isPaid
                                  ? AppColors.success.withOpacity(0.12)
                                  : (isPartial ? AppColors.warning.withOpacity(0.12) : AppColors.danger.withOpacity(0.1)),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${item.month}',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                                color: isPaid ? AppColors.success : (isPartial ? AppColors.warning : AppColors.danger),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${item.monthNameMr} (${item.monthNameEn})',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            '₹ ${item.paidAmount.toStringAsFixed(0)} / ₹ ${item.expectedAmount.toStringAsFixed(0)}',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: isPaid ? AppColors.success : (isPartial ? AppColors.warning : AppColors.textSecondary),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            isPaid ? '✅' : (isPartial ? '🟠' : '🔴'),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 14),

            // Summary Totals
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text('Total Expected', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary)),
                      Text('₹ ${totalExpected.toStringAsFixed(0)}', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  Container(width: 1, height: 28, color: AppColors.divider),
                  Column(
                    children: [
                      Text('Total Paid', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary)),
                      Text('₹ ${totalPaid.toStringAsFixed(0)}', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.success)),
                    ],
                  ),
                  Container(width: 1, height: 28, color: AppColors.divider),
                  Column(
                    children: [
                      Text('Pending (बाकी)', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary)),
                      Text('₹ ${totalPending.toStringAsFixed(0)}', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: totalPending > 0 ? AppColors.danger : AppColors.success)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // ===========================================================================
  // TAB 3: 📅 MONTHLY SAVING HISTORY & DATE SELECTORS (SINGLE & BETWEEN 2 DATES)
  // ===========================================================================
  Widget _buildHistoryTab(
    BuildContext context,
    AuthProvider auth,
    MemberProvider memberProv,
    MonthlySavingsProvider savingsProv,
  ) {
    final groupId = auth.currentGroup?.id ?? '';
    final historyList = savingsProv.filteredHistorySavings;

    String formatDate(DateTime dt) {
      return "${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. TOP DATE SELECTOR & FILTER TYPE BAR
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'बचत इतिहास व तारीख निवड (Date Selector & History)',
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
                      tooltip: 'रिफ्रेश (Refresh)',
                      onPressed: () {
                        if (groupId.isNotEmpty) {
                          savingsProv.loadSavingsHistory(groupId: groupId);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Quick Filter Preset Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildChip('☀️ आज (Today)', savingsProv.historyFilterType == 'today', () {
                        savingsProv.setHistoryFilterType('today', groupId);
                      }),
                      const SizedBox(width: 8),
                      _buildChip('📅 एक तारीख (Single Date)', savingsProv.historyFilterType == 'single', () {
                        savingsProv.setHistoryFilterType('single', groupId);
                      }),
                      const SizedBox(width: 8),
                      _buildChip('📆 २ तारखांमधील (Between 2 Dates)', savingsProv.historyFilterType == 'range', () {
                        savingsProv.setHistoryFilterType('range', groupId);
                      }),
                      const SizedBox(width: 8),
                      _buildChip('🗓️ महिना (Month & Year)', savingsProv.historyFilterType == 'month', () {
                        savingsProv.setHistoryFilterType('month', groupId);
                      }),
                      const SizedBox(width: 8),
                      _buildChip('🗓️ चालू महिना (This Month)', savingsProv.historyFilterType == 'this_month', () {
                        savingsProv.setHistoryFilterType('this_month', groupId);
                      }),
                      const SizedBox(width: 8),
                      _buildChip('🌐 सर्व इतिहास (All History)', savingsProv.historyFilterType == 'all', () {
                        savingsProv.setHistoryFilterType('all', groupId);
                      }),
                    ],
                  ),
                ),
                const Divider(height: 20),

                // ACTIVE DATE CONTROL BOX
                if (savingsProv.historyFilterType == 'single' || savingsProv.historyFilterType == 'today') ...[
                  // --- SINGLE DATE SELECTOR ---
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: savingsProv.historySingleDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2050, 12, 31),
                                helpText: 'तारीख निवडा (Select Date)',
                                cancelText: 'रद्द करा',
                                confirmText: 'निवडा',
                              );
                              if (picked != null) {
                                savingsProv.setHistorySingleDate(picked, groupId);
                              }
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.primary),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today_rounded, size: 20, color: AppColors.primary),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'निवडलेली तारीख (Selected Date):',
                                        style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textSecondary),
                                      ),
                                      Text(
                                        formatDate(savingsProv.historySingleDate),
                                        style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.primary),
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                  const Icon(Icons.edit_calendar_rounded, color: AppColors.primary),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          icon: const Icon(Icons.search_rounded, size: 18, color: Colors.white),
                          label: const Text('तारीख निवडा', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: savingsProv.historySingleDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2050, 12, 31),
                            );
                            if (picked != null) {
                              savingsProv.setHistorySingleDate(picked, groupId);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ] else if (savingsProv.historyFilterType == 'month') ...[
                  // --- SPECIFIC MONTH & YEAR SELECTOR ---
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              _showHistoryMonthYearPicker(context, auth, savingsProv);
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.primary),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_month_rounded, size: 22, color: AppColors.primary),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'निवडलेला महिना (Selected Month):',
                                        style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textSecondary),
                                      ),
                                      Text(
                                        '${MonthlySaving.monthNamesMr[savingsProv.historySelectedMonth - 1]} ${savingsProv.historySelectedYear} (${MonthlySaving.monthNamesEn[savingsProv.historySelectedMonth - 1]})',
                                        style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary),
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                  const Icon(Icons.arrow_drop_down_rounded, color: AppColors.primary, size: 28),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          ),
                          icon: const Icon(Icons.edit_calendar_rounded, size: 18, color: Colors.white),
                          label: const Text('महिना बदला', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                          onPressed: () {
                            _showHistoryMonthYearPicker(context, auth, savingsProv);
                          },
                        ),
                      ],
                    ),
                  ),
                ] else if (savingsProv.historyFilterType == 'range' || savingsProv.historyFilterType == 'this_month') ...[
                  // --- BETWEEN 2 DATES RANGE SELECTOR ---
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'दोन तारखांमधील कालावधी (Between 2 Dates):',
                          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            // Start Date Box
                            Expanded(
                              child: InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: savingsProv.historyStartDate,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2050, 12, 31),
                                    helpText: 'तारीख १ निवडा - पासून (From Date)',
                                  );
                                  if (picked != null) {
                                    savingsProv.setHistoryDateRange(picked, savingsProv.historyEndDate, groupId);
                                  }
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.cardBorder),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.date_range_rounded, size: 18, color: AppColors.primary),
                                      const SizedBox(width: 8),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('तारीख १ (पासून / From):', style: GoogleFonts.poppins(fontSize: 9, color: AppColors.textSecondary)),
                                          Text(formatDate(savingsProv.historyStartDate), style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Icon(Icons.arrow_forward_rounded, color: AppColors.textSecondary, size: 18),
                            ),
                            // End Date Box
                            Expanded(
                              child: InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: savingsProv.historyEndDate,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2050, 12, 31),
                                    helpText: 'तारीख २ निवडा - पर्यंत (To Date)',
                                  );
                                  if (picked != null) {
                                    savingsProv.setHistoryDateRange(savingsProv.historyStartDate, picked, groupId);
                                  }
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.cardBorder),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.event_available_rounded, size: 18, color: AppColors.primary),
                                      const SizedBox(width: 8),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('तारीख २ (पर्यंत / To):', style: GoogleFonts.poppins(fontSize: 9, color: AppColors.textSecondary)),
                                          Text(formatDate(savingsProv.historyEndDate), style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Pick Date Range Dialog button
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                side: const BorderSide(color: AppColors.primary),
                              ),
                              icon: const Icon(Icons.calendar_month_rounded, size: 18, color: AppColors.primary),
                              label: const Text('कॅलेंडर रेंज', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 12)),
                              onPressed: () async {
                                final picked = await showDateRangePicker(
                                  context: context,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2035),
                                  initialDateRange: DateTimeRange(
                                    start: savingsProv.historyStartDate,
                                    end: savingsProv.historyEndDate,
                                  ),
                                  helpText: '२ तारखा निवडा (Select 2 Dates)',
                                  saveText: 'निवडा',
                                );
                                if (picked != null) {
                                  savingsProv.setHistoryDateRange(picked.start, picked.end, groupId);
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // All history info banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          'या बचत गटाच्या सर्व काळातील सर्व बचत नोंदी दाखवत आहे.',
                          style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // Search & Payment Mode Filters Row
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _historySearchCtrl,
                        decoration: InputDecoration(
                          hintText: 'पावती क्रमांक किंवा नाव शोधा...',
                          prefixIcon: const Icon(Icons.search_rounded, size: 18),
                          suffixIcon: _historySearchCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 16),
                                  onPressed: () {
                                    setState(() {
                                      _historySearchCtrl.clear();
                                      savingsProv.setHistorySearch('');
                                    });
                                  },
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                        ),
                        onChanged: (v) => savingsProv.setHistorySearch(v.trim()),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildChip('सर्व (All)', savingsProv.historyPaymentMode == 'all', () {
                              savingsProv.setHistoryPaymentMode('all');
                            }),
                            const SizedBox(width: 6),
                            _buildChip('💵 Cash', savingsProv.historyPaymentMode == 'cash', () {
                              savingsProv.setHistoryPaymentMode('cash');
                            }),
                            const SizedBox(width: 6),
                            _buildChip('📱 UPI', savingsProv.historyPaymentMode == 'upi', () {
                              savingsProv.setHistoryPaymentMode('upi');
                            }),
                            const SizedBox(width: 6),
                            _buildChip('🏦 Bank', savingsProv.historyPaymentMode == 'bank', () {
                              savingsProv.setHistoryPaymentMode('bank');
                            }),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 2. LIVE SUMMARY METRICS FOR SELECTED DATE / DATES
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text('एकूण संकलन (Total Paid)', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary)),
                    const SizedBox(height: 2),
                    Text(
                      '₹ ${savingsProv.historyTotalAmount.toStringAsFixed(0)}',
                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.success),
                    ),
                  ],
                ),
                Container(width: 1, height: 32, color: AppColors.divider),
                Column(
                  children: [
                    Text('एकूण पावत्या (Receipts)', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary)),
                    const SizedBox(height: 2),
                    Text(
                      '${savingsProv.historyCount} नोंदी',
                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary),
                    ),
                  ],
                ),
                Container(width: 1, height: 32, color: AppColors.divider),
                Column(
                  children: [
                    Text('लेट फी (Late Fee)', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary)),
                    const SizedBox(height: 2),
                    Text(
                      '₹ ${savingsProv.historyTotalLateFee.toStringAsFixed(0)}',
                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.warning),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3. HISTORY RECORDS LIST
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'बचत इतिहास नोंदी (${historyList.length})',
                style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                label: const Text('नवीन बचत भरा', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                onPressed: () async {
                  if (memberProv.members.isEmpty) return;
                  final res = await showDialog<MonthlySaving>(
                    context: context,
                    builder: (ctx) => CollectSavingDialog(
                      monthlySaving: savingsProv.monthlySavings.firstOrNull ??
                          MonthlySaving(
                            id: '',
                            groupId: groupId,
                            memberId: memberProv.members.first.id,
                            memberName: memberProv.members.first.fullName,
                            month: DateTime.now().month,
                            year: DateTime.now().year,
                            dueDate: DateTime.now().toString().split(' ').first,
                            expectedAmount: savingsProv.activePlan?.monthlyAmount ?? 500.0,
                            paidAmount: 0.0,
                          ),
                      auth: auth,
                      savingsProv: savingsProv,
                      members: memberProv.members,
                    ),
                  );
                  if (res != null && context.mounted) {
                    setState(() {});
                    try {
                      final dashProv = Provider.of<DashboardProvider>(context, listen: false);
                      dashProv.loadDashboardMetrics(groupId);
                    } catch (_) {}
                    showDialog(
                      context: context,
                      builder: (ctx) => SavingReceiptDialog(
                        saving: res,
                        groupName: auth.currentGroup?.groupName ?? 'Sakhi Bachat Gat',
                      ),
                    );
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (savingsProv.historyLoading)
            const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: AppColors.primary)))
          else if (historyList.isEmpty)
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
                  const Icon(Icons.event_busy_rounded, size: 48, color: AppColors.textMuted),
                  const SizedBox(height: 12),
                  Text(
                    'निवडलेल्या तारखेसाठी / कालावधीसाठी कोणतीही बचत नोंद आढळली नाही.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'कृपया वरील कॅलेंडरमधून वेगळी तारीख निवडा किंवा सर्व इतिहास तपासा.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today_rounded, size: 16),
                    label: const Text('सर्व इतिहास पहा (View All)'),
                    onPressed: () => savingsProv.setHistoryFilterType('all', groupId),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: historyList.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final item = historyList[i];
                final pDate = item.paymentDate ?? item.dueDate;

                return AppCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: AppColors.success.withOpacity(0.12),
                            child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      item.memberName ?? 'सभासद',
                                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        item.memberCode ?? 'MB-001',
                                        style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primary),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'पावती: ${item.receiptNumber ?? "-"} • भरणा तारीख: $pDate',
                                  style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '₹ ${item.paidAmount.toStringAsFixed(0)}',
                                style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.success),
                              ),
                              if (item.lateFee > 0)
                                Text(
                                  '+ ₹${item.lateFee.toStringAsFixed(0)} लेट फी',
                                  style: GoogleFonts.poppins(fontSize: 10, color: AppColors.warning, fontWeight: FontWeight.w600),
                                ),
                              Container(
                                margin: const EdgeInsets.only(top: 2),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: AppColors.cardBorder),
                                ),
                                child: Text(
                                  item.paymentMode.toUpperCase(),
                                  style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'महिना: ${item.monthNameMr} ${item.year} • संकलक: ${item.collectedBy ?? "व्यवस्थापक"}',
                            style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  side: const BorderSide(color: AppColors.primary),
                                ),
                                icon: const Icon(Icons.receipt_rounded, size: 14, color: AppColors.primary),
                                label: const Text('पावती', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => SavingReceiptDialog(
                                      saving: item,
                                      groupName: auth.currentGroup?.groupName ?? 'Sakhi Bachat Gat',
                                    ),
                                  );
                                },
                              ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                ),
                                icon: const Icon(Icons.print_rounded, size: 14, color: Colors.white),
                                label: const Text('प्रिंट', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                                onPressed: () {
                                  PdfService.printMonthlySavingReceipt(
                                    saving: item,
                                    groupName: auth.currentGroup?.groupName ?? 'Sakhi Bachat Gat',
                                  );
                                },
                              ),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  side: const BorderSide(color: AppColors.secondary),
                                ),
                                icon: const Icon(Icons.edit_note_rounded, size: 15, color: AppColors.secondary),
                                label: const Text('एडिट (Edit)', style: TextStyle(fontSize: 11, color: AppColors.secondary, fontWeight: FontWeight.w600)),
                                onPressed: () async {
                                  final res = await showDialog<MonthlySaving>(
                                    context: context,
                                    builder: (ctx) => CollectSavingDialog(
                                      monthlySaving: item,
                                      auth: auth,
                                      savingsProv: savingsProv,
                                      members: memberProv.members,
                                      isEdit: true,
                                    ),
                                  );
                                  if (res != null && context.mounted) {
                                    final scaffoldMessenger = ScaffoldMessenger.of(context);
                                    setState(() {});
                                    try {
                                      final dashProv = Provider.of<DashboardProvider>(context, listen: false);
                                      dashProv.loadDashboardMetrics(groupId);
                                    } catch (_) {}
                                    scaffoldMessenger.showSnackBar(
                                      const SnackBar(
                                        content: Text('बचत नोंद यशस्वीरित्या अपडेट केली! (Saving updated successfully)'),
                                        backgroundColor: AppColors.success,
                                      ),
                                    );
                                  }
                                },
                              ),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  side: const BorderSide(color: AppColors.danger),
                                ),
                                icon: const Icon(Icons.delete_outline_rounded, size: 15, color: AppColors.danger),
                                label: const Text('हटवा (Delete)', style: TextStyle(fontSize: 11, color: AppColors.danger, fontWeight: FontWeight.w600)),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (dCtx) => AlertDialog(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      title: Row(
                                        children: const [
                                          Icon(Icons.delete_forever_rounded, color: AppColors.danger, size: 26),
                                          SizedBox(width: 8),
                                          Text('बचत नोंद हटवा (Delete Saving)'),
                                        ],
                                      ),
                                      content: Text(
                                        'तुम्हाला "${item.memberName ?? "सभासद"}" ची ₹${item.paidAmount.toStringAsFixed(0)} ची ही बचत नोंद खरोखर हटवायची आहे का?\n\n'
                                        '• पावती क्र.: ${item.receiptNumber ?? "-"}\n'
                                        '• महिना: ${item.monthNameMr} ${item.year}\n'
                                        '• तारीख: $pDate\n\n'
                                        '⚠️ ही नोंद हटवल्यास सभासदाच्या खात्यातून ही बचत वजा होईल व डॅशबोर्डवरील एकूण बचत कमी होईल.',
                                        style: GoogleFonts.poppins(fontSize: 13),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(dCtx, false),
                                          child: const Text('रद्द करा (Cancel)'),
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.danger,
                                            foregroundColor: Colors.white,
                                          ),
                                          onPressed: () => Navigator.pop(dCtx, true),
                                          child: const Text('होय, हटवा (Confirm Delete)'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true && context.mounted) {
                                    final scaffoldMessenger = ScaffoldMessenger.of(context);
                                    final dashProv = Provider.of<DashboardProvider>(context, listen: false);
                                    final ok = await savingsProv.deletePayment(
                                      savingId: item.id,
                                      groupId: groupId,
                                      memberId: item.memberId,
                                      month: item.month,
                                      year: item.year,
                                      receiptNumber: item.receiptNumber,
                                      members: memberProv.members,
                                    );
                                    if (ok) {
                                      try {
                                        await dashProv.loadDashboardMetrics(groupId);
                                      } catch (_) {}
                                      scaffoldMessenger.showSnackBar(
                                        const SnackBar(
                                          content: Text('बचत नोंद यशस्वीरित्या हटवली! (Saving deleted successfully)'),
                                          backgroundColor: AppColors.success,
                                        ),
                                      );
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
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

  Widget _buildChip(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.cardBorder),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(fontSize: 11, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, color: isSelected ? Colors.white : AppColors.textPrimary),
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 4: 📈 MONTHLY SAVINGS REPORT
  // ===========================================================================
  Widget _buildReportsTab(BuildContext context, AuthProvider auth, MonthlySavingsProvider savingsProv) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${savingsProv.selectedMonthNameMr} ${savingsProv.selectedYear} - संकलन अहवाल',
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 14),

          // Collection Progress Gauge
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('संकलन दर (Collection Rate):', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                    Text('${savingsProv.collectionRate.toStringAsFixed(1)}%', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.primary)),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: (savingsProv.collectionRate / 100).clamp(0.0, 1.0),
                    minHeight: 12,
                    backgroundColor: AppColors.background,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      savingsProv.collectionRate >= 80 ? AppColors.success : (savingsProv.collectionRate >= 50 ? AppColors.warning : AppColors.danger),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('जमा: ₹${savingsProv.totalActual.toStringAsFixed(0)}', style: GoogleFonts.poppins(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w600)),
                    Text('थकबाकी: ₹${savingsProv.totalPending.toStringAsFixed(0)}', style: GoogleFonts.poppins(fontSize: 12, color: AppColors.danger, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Payment Mode Distribution Card
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('भरणा माध्यम वितरण (Payment Mode Distribution)', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),
                _buildModeBar('रोख (Cash)', savingsProv.cashCollection, savingsProv.totalActual, const Color(0xFF27AE60)),
                const SizedBox(height: 10),
                _buildModeBar('UPI / PhonePe', savingsProv.upiCollection, savingsProv.totalActual, const Color(0xFF2F80ED)),
                const SizedBox(height: 10),
                _buildModeBar('बँक ट्रान्सफर (Bank)', savingsProv.bankCollection, savingsProv.totalActual, const Color(0xFF9B51E0)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeBar(String label, double amount, double total, Color color) {
    final pct = total > 0 ? (amount / total) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textPrimary)),
            Text('₹ ${amount.toStringAsFixed(0)} (${(pct * 100).toStringAsFixed(0)}%)', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: AppColors.background,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // TAB 5: ⚙️ MONTHLY SAVING SETTINGS (PLAN CONFIGURATION)
  // ===========================================================================
  Widget _buildSettingsTab(
    BuildContext context,
    AuthProvider auth,
    MemberProvider memberProv,
    MonthlySavingsProvider savingsProv,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.tr('मासिक बचत योजना सेटिंग्ज', 'Monthly Saving Plan Settings'),
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          Text(
            'बचत संकलनापूर्वी मासिक वर्गणी रक्कम, देय तारीख व नियम निश्चित करा.',
            style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),

          AppCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _planNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'बचत योजना नाव (Saving Plan Name)*',
                    hintText: 'उदा. Regular Monthly Saving',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _planAmountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'मासिक बचत रक्कम (Monthly Amount ₹)*',
                    prefixText: '₹ ',
                    hintText: '500',
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _dueDayCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'देय तारीख (Due Date of Month)*',
                          hintText: '10',
                          helperText: 'उदा. दरमहा १० तारीख',
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: TextField(
                        controller: _gracePeriodCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'सवलत कालावधी (Grace Period Days)*',
                          hintText: '5',
                          helperText: 'उदा. ५ दिवस',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _lateFeeCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'विलंब शुल्क (Late Fee ₹)*',
                          prefixText: '₹ ',
                          hintText: '20',
                          helperText: 'मुदतीनंतर आकारला जाणारा दंड',
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _planStatus,
                        decoration: const InputDecoration(labelText: 'योजना स्थिती (Status)*'),
                        items: const [
                          DropdownMenuItem(value: 'active', child: Text('सक्रिय (Active)')),
                          DropdownMenuItem(value: 'inactive', child: Text('निष्क्रिय (Inactive)')),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _planStatus = v);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                AppButton(
                  width: double.infinity,
                  text: 'सेटिंग्ज जतन करा (SAVE PLAN SETTINGS)',
                  icon: Icons.save_rounded,
                  onPressed: () async {
                    if (auth.currentGroup == null) return;
                    final amt = double.tryParse(_planAmountCtrl.text) ?? 500.0;
                    final due = int.tryParse(_dueDayCtrl.text) ?? 10;
                    final grace = int.tryParse(_gracePeriodCtrl.text) ?? 5;
                    final fee = double.tryParse(_lateFeeCtrl.text) ?? 20.0;

                    final updatedPlan = SavingPlan(
                      id: savingsProv.activePlan?.id ?? 'default-plan',
                      groupId: auth.currentGroup!.id,
                      planName: _planNameCtrl.text.trim(),
                      monthlyAmount: amt,
                      dueDay: due,
                      gracePeriodDays: grace,
                      lateFee: fee,
                      status: _planStatus,
                    );

                    await savingsProv.savePlan(updatedPlan, auth.currentGroup!.id, memberProv.members);

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('मासिक बचत योजना यशस्वीरित्या जतन झाली! (Plan saved successfully!)'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
