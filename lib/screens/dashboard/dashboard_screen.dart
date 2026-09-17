import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_strings.dart';
import '../../core/utils/image_helper.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/bank_provider.dart';
import '../bank/bank_management_screen.dart';
import '../finance/cashbook_screen.dart';
import '../../widgets/app_card.dart';
import '../../widgets/summary_card.dart';

class DashboardScreen extends StatefulWidget {
  final Function(int) onNavigate;
  const DashboardScreen({super.key, required this.onNavigate});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.currentGroup != null) {
        Provider.of<DashboardProvider>(context, listen: false).loadDashboardMetrics(auth.currentGroup!.id);
      }
    });
  }

  String _formatDateDisplay(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final dash = Provider.of<DashboardProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF0F9FF), // Soft Sky Blue tint
              Color(0xFFE0F2FE), // Sky Blue background
            ],
          ),
        ),
        child: dash.isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : RefreshIndicator(
                onRefresh: () async {
                  if (auth.currentGroup != null) {
                    await dash.loadDashboardMetrics(auth.currentGroup!.id);
                  }
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    // Group Header Banner
                    AppCard(
                      color: Colors.white,
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          InkWell(
                            onTap: () => widget.onNavigate(19), // Settings & Logo
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [AppColors.primary, AppColors.secondary],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.25),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: auth.currentGroup?.logoUrl != null && auth.currentGroup!.logoUrl!.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: ImageHelper.buildBase64Image(auth.currentGroup!.logoUrl, width: 52, height: 52),
                                    )
                                  : const Icon(Icons.groups, color: Colors.white, size: 30),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  auth.currentGroup?.groupName ?? 'Sakhi Mahila Bachat Gat',
                                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Village - ${auth.currentGroup?.village ?? "Sangola"}, Tal - ${auth.currentGroup?.taluka ?? "Sangola"}',
                                  style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.notifications_outlined, color: AppColors.primary),
                            onPressed: () => widget.onNavigate(5), // Meetings / Notifications
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // --- DATE SELECTOR CARD (२ तारखा निवडा) ---
                    _buildDateSelectorCard(context, auth, dash),
                    const SizedBox(height: 14),

                    // --- GRID 1: TOTAL MEMBERS & TOTAL SAVINGS ---
                    Row(
                      children: [
                        Expanded(
                          child: SummaryCard(
                            title: AppStrings.totalMembers,
                            value: '${dash.totalMembers}',
                            icon: Icons.people_alt_rounded,
                            iconColor: Colors.white,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2575FC), Color(0xFF6A11CB)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            badgeText: 'नोंदणीकृत (Active)',
                            onTap: () => widget.onNavigate(1), // Members
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: SummaryCard(
                            title: AppStrings.totalSavings,
                            value: '₹ ${dash.totalSavings.toStringAsFixed(0)}',
                            icon: Icons.savings_rounded,
                            iconColor: Colors.white,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF11998E), Color(0xFF38EF7D)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            badgeText: 'एकूण जमा (Savings)',
                            onTap: () => widget.onNavigate(2), // Savings
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // --- GRID 2: ACTIVE LOANS & PENDING EMI ---
                    Row(
                      children: [
                        Expanded(
                          child: SummaryCard(
                            title: AppStrings.activeLoans,
                            value: '₹ ${dash.activeLoans.toStringAsFixed(0)}',
                            icon: Icons.monetization_on_rounded,
                            iconColor: Colors.white,
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF5E36), Color(0xFFFFAE34)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            badgeText: 'अंतर्गत कर्ज',
                            onTap: () => widget.onNavigate(3), // Loans
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: SummaryCard(
                            title: AppStrings.pendingEmi,
                            value: '${dash.pendingEmis}',
                            icon: Icons.pending_actions_rounded,
                            iconColor: Colors.white,
                            gradient: const LinearGradient(
                              colors: [Color(0xFFEB3349), Color(0xFFF45C43)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            badgeText: 'थकबाकी (Overdue)',
                            onTap: () => widget.onNavigate(11), // Dues & Recovery
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // --- GRID 3: BANK BALANCE & CASH IN HAND ---
                    Row(
                      children: [
                        Expanded(
                          child: SummaryCard(
                            title: AppStrings.bankBalance,
                            value: '₹ ${dash.bankBalance.toStringAsFixed(0)}',
                            icon: Icons.account_balance_rounded,
                            iconColor: Colors.white,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            badgeText: 'बँक खाते',
                            onTap: () async {
                              final dashProv = Provider.of<DashboardProvider>(context, listen: false);
                              final bankProv = Provider.of<BankProvider>(context, listen: false);
                              final gid = auth.currentGroup?.id;
                              await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const BankManagementScreen()),
                              );
                              if (gid != null) {
                                await dashProv.loadDashboardMetrics(gid);
                                await bankProv.loadBanks(gid);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: SummaryCard(
                            title: AppStrings.cashInHand,
                            value: '₹ ${dash.cashInHand.toStringAsFixed(0)}',
                            icon: Icons.payments_rounded,
                            iconColor: Colors.white,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF00B4DB), Color(0xFF0083B0)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            badgeText: 'हातातील रोख',
                            onTap: () async {
                              final dashProv = Provider.of<DashboardProvider>(context, listen: false);
                              final bankProv = Provider.of<BankProvider>(context, listen: false);
                              final gid = auth.currentGroup?.id;
                              await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const CashBookScreen()),
                              );
                              if (gid != null) {
                                await dashProv.loadDashboardMetrics(gid);
                                await bankProv.loadBanks(gid);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // --- GRID 4: TOTAL INCOME & TOTAL EXPENSES ---
                    Row(
                      children: [
                        Expanded(
                          child: SummaryCard(
                            title: AppStrings.totalIncome,
                            value: '₹ ${dash.totalIncome.toStringAsFixed(0)}',
                            icon: Icons.trending_up_rounded,
                            iconColor: Colors.white,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF134E5E), Color(0xFF71B280)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            badgeText: 'व्याज व इतर जमा',
                            onTap: () => widget.onNavigate(5), // Income
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: SummaryCard(
                            title: AppStrings.totalExpenses,
                            value: '₹ ${dash.totalExpenses.toStringAsFixed(0)}',
                            icon: Icons.trending_down_rounded,
                            iconColor: Colors.white,
                            gradient: const LinearGradient(
                              colors: [Color(0xFFD31027), Color(0xFFEA384D)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            badgeText: 'खर्च व भत्ते',
                            onTap: () => widget.onNavigate(6), // Expense
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // --- NET PROFIT CARD ---
                    SummaryCard(
                      title: AppStrings.totalProfit,
                      value: '₹ ${dash.totalProfit.toStringAsFixed(0)}',
                      icon: Icons.stars_rounded,
                      iconColor: Colors.white,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0052D4), Color(0xFF4364F7), Color(0xFF6FB1FC)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      subtitle: AppStrings.tr('एकूण उत्पन्न/व्याज वजा खर्च = निव्वळ नफा', 'Total Income minus Expenses = Net Profit'),
                      badgeText: 'गटाचा निव्वळ नफा (Profit)',
                      onTap: () => widget.onNavigate(9), // Profit & Loss
                    ),
                    const SizedBox(height: 14),

                    // --- UPCOMING MEETING CARD ---
                    if (dash.upcomingMeeting != null) ...[
                      InkWell(
                        onTap: () => widget.onNavigate(4), // Meetings
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF614385), Color(0xFF516395)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF614385).withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 26),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      AppStrings.upcomingMeeting,
                                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white70),
                                    ),
                                    Text(
                                      '${dash.upcomingMeeting!.meetingDate} • ${dash.upcomingMeeting!.meetingTime}',
                                      style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                                    ),
                                    Text(
                                      dash.upcomingMeeting!.location,
                                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.white70),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
      ),
    );
  }

  // --- DATE RANGE SELECTOR CARD WIDGET ---
  Widget _buildDateSelectorCard(BuildContext context, AuthProvider auth, DashboardProvider dash) {
    final isFiltered = dash.selectedFilter != 'all';
    String rangeLabel = 'सर्व नोंदी (All Time Data)';

    if (dash.startDate != null && dash.endDate != null) {
      rangeLabel = '${_formatDateDisplay(dash.startDate!)} ते ${_formatDateDisplay(dash.endDate!)}';
    } else if (dash.selectedFilter == 'this_month') {
      rangeLabel = 'चालू महिना (This Month)';
    } else if (dash.selectedFilter == 'last_month') {
      rangeLabel = 'मागील महिना (Last Month)';
    } else if (dash.selectedFilter == 'this_year') {
      rangeLabel = 'चालू आर्थिक वर्ष (Financial Year)';
    }

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.date_range_rounded, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.tr('कालावधी निवडा (Date Range Filter)', 'Date Range Filter'),
                        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                      Text(
                        rangeLabel,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: isFiltered ? FontWeight.w600 : FontWeight.w400,
                          color: isFiltered ? AppColors.primary : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (isFiltered)
                TextButton.icon(
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                  icon: const Icon(Icons.refresh_rounded, size: 16, color: AppColors.danger),
                  label: Text(
                    AppStrings.tr('रीसेट करा', 'Reset'),
                    style: const TextStyle(fontSize: 11, color: AppColors.danger, fontWeight: FontWeight.w600),
                  ),
                  onPressed: () {
                    if (auth.currentGroup != null) {
                      dash.setDateFilter(groupId: auth.currentGroup!.id, filterType: 'all');
                    }
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Quick Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(
                  label: 'सर्व (All Time)',
                  isSelected: dash.selectedFilter == 'all',
                  onTap: () {
                    if (auth.currentGroup != null) {
                      dash.setDateFilter(groupId: auth.currentGroup!.id, filterType: 'all');
                    }
                  },
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'चालू महिना (This Month)',
                  isSelected: dash.selectedFilter == 'this_month',
                  onTap: () {
                    if (auth.currentGroup != null) {
                      dash.setDateFilter(groupId: auth.currentGroup!.id, filterType: 'this_month');
                    }
                  },
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'मागील महिना (Last Month)',
                  isSelected: dash.selectedFilter == 'last_month',
                  onTap: () {
                    if (auth.currentGroup != null) {
                      dash.setDateFilter(groupId: auth.currentGroup!.id, filterType: 'last_month');
                    }
                  },
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'आर्थिक वर्ष (Financial Year)',
                  isSelected: dash.selectedFilter == 'this_year',
                  onTap: () {
                    if (auth.currentGroup != null) {
                      dash.setDateFilter(groupId: auth.currentGroup!.id, filterType: 'this_year');
                    }
                  },
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: '📅 २ तारखा निवडा (Custom Dates)',
                  isSelected: dash.selectedFilter == 'custom',
                  onTap: () => _pickCustomDateRange(context, auth, dash),
                ),
              ],
            ),
          ),

          // Custom 2-Date Selectors Row (If custom dates or user wants direct pickers)
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F3FA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withOpacity(0.15)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 480;

                Widget buildStartDateBox() {
                  return InkWell(
                    onTap: () => _pickSingleDate(context, isStart: true, auth: auth, dash: dash),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.divider),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  AppStrings.tr('पासून (Start)', 'Start Date'),
                                  style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textSecondary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  dash.startDate != null ? _formatDateDisplay(dash.startDate!) : 'तारीख निवडा',
                                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                Widget buildEndDateBox() {
                  return InkWell(
                    onTap: () => _pickSingleDate(context, isStart: false, auth: auth, dash: dash),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.divider),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.event_available_rounded, size: 16, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  AppStrings.tr('पर्यंत (End)', 'End Date'),
                                  style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textSecondary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  dash.endDate != null ? _formatDateDisplay(dash.endDate!) : 'तारीख निवडा',
                                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                Widget buildFilterButton({bool fullWidth = false}) {
                  final btn = ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 1,
                    ),
                    icon: const Icon(Icons.filter_alt_rounded, size: 16, color: Colors.white),
                    label: const Text(
                      'फिल्टर करा',
                      style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    onPressed: () {
                      if (auth.currentGroup != null) {
                        if (dash.startDate != null && dash.endDate != null) {
                          dash.setDateFilter(
                            groupId: auth.currentGroup!.id,
                            filterType: 'custom',
                            customStart: dash.startDate,
                            customEnd: dash.endDate,
                          );
                        } else {
                          _pickCustomDateRange(context, auth, dash);
                        }
                      }
                    },
                  );

                  if (fullWidth) {
                    return SizedBox(width: double.infinity, child: btn);
                  }
                  return btn;
                }

                if (isNarrow) {
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: buildStartDateBox()),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6),
                            child: Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.textSecondary),
                          ),
                          Expanded(child: buildEndDateBox()),
                        ],
                      ),
                      const SizedBox(height: 8),
                      buildFilterButton(fullWidth: true),
                    ],
                  );
                } else {
                  return Row(
                    children: [
                      Expanded(child: buildStartDateBox()),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.textSecondary),
                      ),
                      Expanded(child: buildEndDateBox()),
                      const SizedBox(width: 10),
                      buildFilterButton(),
                    ],
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Future<void> _pickSingleDate(
    BuildContext context, {
    required bool isStart,
    required AuthProvider auth,
    required DashboardProvider dash,
  }) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? (dash.startDate ?? now) : (dash.endDate ?? now),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: isStart ? 'पासून तारीख निवडा (Select Start Date)' : 'पर्यंत तारीख निवडा (Select End Date)',
    );

    if (picked != null && auth.currentGroup != null) {
      final start = isStart ? picked : (dash.startDate ?? DateTime(picked.year, picked.month, 1));
      final end = isStart ? (dash.endDate ?? DateTime(picked.year, picked.month + 1, 0)) : picked;

      await dash.setDateFilter(
        groupId: auth.currentGroup!.id,
        filterType: 'custom',
        customStart: start,
        customEnd: end,
      );
    }
  }

  Future<void> _pickCustomDateRange(
    BuildContext context,
    AuthProvider auth,
    DashboardProvider dash,
  ) async {
    final now = DateTime.now();
    final initialRange = (dash.startDate != null && dash.endDate != null)
        ? DateTimeRange(start: dash.startDate!, end: dash.endDate!)
        : DateTimeRange(
            start: DateTime(now.year, now.month, 1),
            end: DateTime(now.year, now.month + 1, 0),
          );

    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: initialRange,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: 'डॅशबोर्ड कालावधी श्रेणी निवडा (Select Date Range)',
      saveText: 'माहिती पहा (Apply)',
    );

    if (picked != null && auth.currentGroup != null) {
      await dash.setDateFilter(
        groupId: auth.currentGroup!.id,
        filterType: 'custom',
        customStart: picked.start,
        customEnd: picked.end,
      );
    }
  }
}
