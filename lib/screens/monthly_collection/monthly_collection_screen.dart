import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../models/monthly_collection.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bank_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/loan_provider.dart';
import '../../providers/member_provider.dart';
import '../../providers/monthly_collection_provider.dart';
import '../../providers/savings_provider.dart';
import '../../services/sync_service.dart';

class MonthlyCollectionScreen extends StatefulWidget {
  const MonthlyCollectionScreen({super.key});

  @override
  State<MonthlyCollectionScreen> createState() => _MonthlyCollectionScreenState();
}

class _MonthlyCollectionScreenState extends State<MonthlyCollectionScreen> {
  final NumberFormat _currencyFormat =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
  final DateFormat _dateFormat = DateFormat('dd-MM-yyyy');

  final TextEditingController _savingAmountController = TextEditingController();
  final TextEditingController _paidEmiController = TextEditingController();
  final TextEditingController _refNoController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _historySearchController = TextEditingController();

  DateTime? _filterFromDate;
  DateTime? _filterToDate;
  String? _filterMemberId;

  String _searchQuery = '';
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _savingAmountController.dispose();
    _paidEmiController.dispose();
    _refNoController.dispose();
    _notesController.dispose();
    _historySearchController.dispose();
    super.dispose();
  }

  void _loadData() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final gid = auth.currentGroup?.id;
    if (gid != null && gid.isNotEmpty) {
      final memProv = Provider.of<MemberProvider>(context, listen: false);
      final loanProv = Provider.of<LoanProvider>(context, listen: false);
      final bankProv = Provider.of<BankProvider>(context, listen: false);
      final colProv = Provider.of<MonthlyCollectionProvider>(context, listen: false);

      await Future.wait([
        memProv.fetchMembers(gid),
        loanProv.loadLoans(gid),
        bankProv.loadBanks(gid),
      ]);

      await colProv.fetchCollections(
        groupId: gid,
        membersList: memProv.members,
        loansList: loanProv.loans,
        banksList: bankProv.banks,
      );

      final defaultGroupSaving = auth.currentGroup?.monthlySavingsAmount ?? 200.0;
      if (mounted) {
        _savingAmountController.text = defaultGroupSaving.toStringAsFixed(0);
        _paidEmiController.text = colProv.paidEmi.toStringAsFixed(2);
      }
    }
  }

  Future<void> _pickDate(BuildContext context, {required bool isFilterFrom, bool isFilterTo = false}) async {
    final now = DateTime.now();
    final initialDate = isFilterFrom
        ? (_filterFromDate ?? now)
        : (isFilterTo ? (_filterToDate ?? now) : Provider.of<MonthlyCollectionProvider>(context, listen: false).entryDate);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2050),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isFilterFrom) {
          _filterFromDate = picked;
        } else if (isFilterTo) {
          _filterToDate = picked;
        } else {
          Provider.of<MonthlyCollectionProvider>(context, listen: false).setEntryDate(picked);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final memProv = Provider.of<MemberProvider>(context);
    final loanProv = Provider.of<LoanProvider>(context);
    final bankProv = Provider.of<BankProvider>(context);
    final colProv = Provider.of<MonthlyCollectionProvider>(context);

    final defaultSaving = auth.currentGroup?.monthlySavingsAmount ?? 200.0;

    // Initial sync of form controllers if not yet initialized
    if (!_initialized && colProv.selectedMember != null) {
      _savingAmountController.text = colProv.monthlySaving.toStringAsFixed(0);
      _paidEmiController.text = colProv.paidEmi.toStringAsFixed(2);
      _initialized = true;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      body: colProv.isLoading && colProv.collections.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final screenWidth = constraints.maxWidth;
                final isWideDesktop = screenWidth >= 1350;
                final isMediumScreen = screenWidth >= 880 && screenWidth < 1350;

                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Top Application Header
                      _buildHeader(context, auth),
                      const SizedBox(height: 16),

                      // 2. Top Filter Card
                      _buildFilterCard(context, memProv, loanProv, colProv, defaultSaving),
                      const SizedBox(height: 16),

                      // 3. 5 Overview Metric Cards
                      _buildMetricCards(context, colProv),
                      const SizedBox(height: 20),

                      // 4. Middle Workspace (Adaptive 3-col / 2-col / 1-col)
                      if (isWideDesktop)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left Panel: Entry Form
                            Expanded(
                              flex: 34,
                              child: _buildEntryFormPanel(context, auth, memProv, loanProv, bankProv, colProv, defaultSaving),
                            ),
                            const SizedBox(width: 16),
                            // Middle Panel: Collection History Table
                            Expanded(
                              flex: 42,
                              child: _buildHistoryPanel(context, colProv),
                            ),
                            const SizedBox(width: 16),
                            // Right Panel: Member Details
                            Expanded(
                              flex: 24,
                              child: _buildMemberDetailsPanel(context, memProv, loanProv, colProv),
                            ),
                          ],
                        )
                      else if (isMediumScreen)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left Column: Entry Form with ample space
                            Expanded(
                              flex: 46,
                              child: _buildEntryFormPanel(context, auth, memProv, loanProv, bankProv, colProv, defaultSaving),
                            ),
                            const SizedBox(width: 16),
                            // Right Column: Member Details + History Table
                            Expanded(
                              flex: 54,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildMemberDetailsPanel(context, memProv, loanProv, colProv),
                                  const SizedBox(height: 16),
                                  _buildHistoryPanel(context, colProv),
                                ],
                              ),
                            ),
                          ],
                        )
                      else
                        // Mobile & Small Tablet (1-col stacked)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildEntryFormPanel(context, auth, memProv, loanProv, bankProv, colProv, defaultSaving),
                            const SizedBox(height: 16),
                            _buildMemberDetailsPanel(context, memProv, loanProv, colProv),
                            const SizedBox(height: 16),
                            _buildHistoryPanel(context, colProv),
                          ],
                        ),

                      const SizedBox(height: 24),

                      // 5. Bottom Row: Transaction Details
                      _buildBottomSection(context, colProv),
                      const SizedBox(height: 32),
                    ],
                  ),
                );
              },
            ),
    );
  }

  // ==========================================
  // 1. TOP APPLICATION HEADER
  // ==========================================
  Widget _buildHeader(BuildContext context, AuthProvider auth) {
    final groupName = auth.currentGroup?.groupName ?? 'सखी महिला बचत गट';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Title & Slogan
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.secondary],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$groupName - मासिक संकलन केंद्र',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Save Together · Grow Together  |  एकत्र बचत · प्रगतीची वाट',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Right Icons & Sync Status
          Row(
            children: [
              ValueListenableBuilder<SyncState>(
                valueListenable: SyncService.instance.state,
                builder: (context, syncState, _) {
                  final isOnline = syncState.isOnline;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isOnline ? AppColors.successBg : AppColors.warningBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isOnline ? AppColors.success : AppColors.warning,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isOnline ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                          size: 14,
                          color: isOnline ? AppColors.success : AppColors.warning,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isOnline ? 'Online Sync' : 'Offline Mode',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isOnline ? AppColors.success : AppColors.warning,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
                tooltip: 'रिफ्रेश करा / Refresh Data',
                onPressed: _loadData,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 2. TOP FILTER CARD
  // ==========================================
  void _syncSelectedMember(
    String? memberId,
    MemberProvider memProv,
    LoanProvider loanProv,
    MonthlyCollectionProvider colProv,
    double defaultSaving,
  ) {
    if (memberId != null && memberId.isNotEmpty && memberId != 'all') {
      final mem = memProv.members.where((m) => m.id == memberId).firstOrNull;
      if (mem != null) {
        colProv.onMemberChanged(mem, loanProv.loans, defaultSaving);
        _savingAmountController.text = colProv.monthlySaving.toStringAsFixed(0);
        _paidEmiController.text = colProv.paidEmi.toStringAsFixed(2);
      }
    } else {
      colProv.onMemberChanged(null, loanProv.loans, defaultSaving);
      _savingAmountController.text = defaultSaving.toStringAsFixed(0);
      _paidEmiController.text = '0.00';
    }
  }

  // ==========================================
  // 2. TOP FILTER CARD
  // ==========================================
  Widget _buildFilterCard(
    BuildContext context,
    MemberProvider memProv,
    LoanProvider loanProv,
    MonthlyCollectionProvider colProv,
    double defaultSaving,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 850;
          return isWide
              ? Row(
                  children: [
                    // From Date
                    Expanded(
                      flex: 3,
                      child: _buildDateInput(
                        label: 'दिनांकापासून (From Date)',
                        date: _filterFromDate,
                        onTap: () => _pickDate(context, isFilterFrom: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // To Date
                    Expanded(
                      flex: 3,
                      child: _buildDateInput(
                        label: 'दिनांकापर्यंत (To Date)',
                        date: _filterToDate,
                        onTap: () => _pickDate(context, isFilterFrom: false, isFilterTo: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Member Dropdown
                    Expanded(
                      flex: 4,
                      child: _buildMemberFilterDropdown(memProv, loanProv, colProv, defaultSaving),
                    ),
                    const SizedBox(width: 12),
                    // Apply & Clear Buttons
                    ElevatedButton.icon(
                      onPressed: () {
                        colProv.setDateFilter(_filterFromDate, _filterToDate);
                        colProv.setFilterMember(_filterMemberId);
                        _syncSelectedMember(_filterMemberId, memProv, loanProv, colProv, defaultSaving);
                      },
                      icon: const Icon(Icons.filter_alt_rounded, size: 16),
                      label: Text('लागू करा', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _filterFromDate = null;
                          _filterToDate = null;
                          _filterMemberId = null;
                        });
                        colProv.clearFilters();
                        colProv.resetForm(defaultSaving);
                        _savingAmountController.text = defaultSaving.toStringAsFixed(0);
                        _paidEmiController.text = '0.00';
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        side: const BorderSide(color: AppColors.cardBorder),
                      ),
                      child: const Icon(Icons.clear_rounded, size: 18, color: AppColors.textSecondary),
                    ),
                  ],
                )
              : Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildDateInput(
                            label: 'From Date',
                            date: _filterFromDate,
                            onTap: () => _pickDate(context, isFilterFrom: true),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildDateInput(
                            label: 'To Date',
                            date: _filterToDate,
                            onTap: () => _pickDate(context, isFilterFrom: false, isFilterTo: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildMemberFilterDropdown(memProv, loanProv, colProv, defaultSaving),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              colProv.setDateFilter(_filterFromDate, _filterToDate);
                              colProv.setFilterMember(_filterMemberId);
                              _syncSelectedMember(_filterMemberId, memProv, loanProv, colProv, defaultSaving);
                            },
                            icon: const Icon(Icons.filter_alt_rounded, size: 16),
                            label: Text('लागू करा (Apply)', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _filterFromDate = null;
                              _filterToDate = null;
                              _filterMemberId = null;
                            });
                            colProv.clearFilters();
                            colProv.resetForm(defaultSaving);
                            _savingAmountController.text = defaultSaving.toStringAsFixed(0);
                            _paidEmiController.text = '0.00';
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text('रीसेट', style: GoogleFonts.poppins(color: AppColors.textSecondary)),
                        ),
                      ],
                    ),
                  ],
                );
        },
      ),
    );
  }

  Widget _buildDateInput({required String label, DateTime? date, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_month_rounded, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textSecondary),
                  ),
                  Text(
                    date != null ? _dateFormat.format(date) : 'निवडा (Select)',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: date != null ? AppColors.textPrimary : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberFilterDropdown(
    MemberProvider memProv,
    LoanProvider loanProv,
    MonthlyCollectionProvider colProv,
    double defaultSaving,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _filterMemberId ?? 'all',
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
          items: [
            DropdownMenuItem(
              value: 'all',
              child: Text(
                'सर्व सदस्य (All Members)',
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
            ),
            ...memProv.members.map((m) {
              return DropdownMenuItem(
                value: m.id,
                child: Text(
                  '${m.fullName} (${m.memberCode})',
                  style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }),
          ],
          onChanged: (val) {
            setState(() {
              _filterMemberId = (val == 'all') ? null : val;
            });
            colProv.setFilterMember(_filterMemberId);
            _syncSelectedMember(_filterMemberId, memProv, loanProv, colProv, defaultSaving);
          },
        ),
      ),
    );
  }

  // ==========================================
  // 3. 5 OVERVIEW METRIC CARDS
  // ==========================================
  Widget _buildMetricCards(BuildContext context, MonthlyCollectionProvider colProv) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;
        final cardWidth = isDesktop ? (constraints.maxWidth - 4 * 12) / 5 : (constraints.maxWidth - 12) / 2;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildMetricCard(
              title: 'Total Monthly Saving',
              titleMr: 'एकूण मासिक बचत',
              value: colProv.totalMonthlySaving,
              icon: Icons.savings_outlined,
              accentColor: const Color(0xFF0284C7),
              bgColor: const Color(0xFFF0F9FF),
              width: cardWidth,
            ),
            _buildMetricCard(
              title: 'Total Loan Principal',
              titleMr: 'एकूण कर्ज मुद्दल',
              value: colProv.totalLoanPrincipal,
              icon: Icons.account_balance_outlined,
              accentColor: const Color(0xFF6366F1),
              bgColor: const Color(0xFFEEF2FF),
              width: cardWidth,
            ),
            _buildMetricCard(
              title: 'Total Interest',
              titleMr: 'एकूण व्याज जमा',
              value: colProv.totalInterest,
              icon: Icons.percent_rounded,
              accentColor: const Color(0xFFD97706),
              bgColor: const Color(0xFFFFFBEB),
              width: cardWidth,
            ),
            _buildMetricCard(
              title: 'Total EMI Paid',
              titleMr: 'एकूण भरलेला हप्ता',
              value: colProv.totalEmiPaid,
              icon: Icons.receipt_long_rounded,
              accentColor: const Color(0xFF7C3AED),
              bgColor: const Color(0xFFF5F3FF),
              width: cardWidth,
            ),
            _buildMetricCard(
              title: 'Total Collection',
              titleMr: 'एकूण संकलन जमा',
              value: colProv.totalCollection,
              icon: Icons.monetization_on_rounded,
              accentColor: const Color(0xFF059669),
              bgColor: const Color(0xFFECFDF5),
              isHighlight: true,
              width: isDesktop ? cardWidth : constraints.maxWidth,
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String titleMr,
    required double value,
    required IconData icon,
    required Color accentColor,
    required Color bgColor,
    bool isHighlight = false,
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isHighlight ? const Color(0xFF047857) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isHighlight ? const Color(0xFF059669) : AppColors.cardBorder,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(isHighlight ? 0.15 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isHighlight ? Colors.white.withOpacity(0.2) : bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: isHighlight ? Colors.white : accentColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  titleMr,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isHighlight ? Colors.white70 : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _currencyFormat.format(value),
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isHighlight ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    color: isHighlight ? Colors.white60 : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 4. MIDDLE WORKSPACE: LEFT PANEL (ENTRY FORM)
  // ==========================================
  Widget _buildEntryFormPanel(
    BuildContext context,
    AuthProvider auth,
    MemberProvider memProv,
    LoanProvider loanProv,
    BankProvider bankProv,
    MonthlyCollectionProvider colProv,
    double defaultGroupSaving,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.edit_calendar_rounded, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'मासिक संकलन नोंद',
                      style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    Text(
                      'Monthly Collection Entry Form',
                      style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),

          // Collection Date Picker
          Text('संकलन दिनांक (Collection Date)', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          InkWell(
            onTap: () => _pickDate(context, isFilterFrom: false),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.event_available_rounded, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    _dateFormat.format(colProv.entryDate),
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  const Icon(Icons.arrow_drop_down, color: AppColors.textMuted),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Member Selector
          Text('सदस्य निवडा (Select Member) *', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: colProv.selectedMember?.id,
                hint: Text('सदस्य निवडा...', style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textMuted)),
                isExpanded: true,
                items: memProv.members.map((m) {
                  return DropdownMenuItem(
                    value: m.id,
                    child: Text(
                      '${m.fullName} (${m.memberCode})',
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (memberId) {
                  setState(() {
                    _filterMemberId = memberId;
                  });
                  final mem = memProv.members.where((m) => m.id == memberId).firstOrNull;
                  if (mem != null) {
                    colProv.onMemberChanged(mem, loanProv.loans, defaultGroupSaving);
                    _savingAmountController.text = colProv.monthlySaving.toStringAsFixed(0);
                    _paidEmiController.text = colProv.paidEmi.toStringAsFixed(2);
                    colProv.setFilterMember(memberId);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Member Info Card if selected
          if (colProv.selectedMember != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F4F8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD9E2EC)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      colProv.selectedMember!.fullName.isNotEmpty ? colProv.selectedMember!.fullName[0] : 'M',
                      style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          colProv.selectedMember!.fullName,
                          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                        ),
                        Text(
                          'कोड: ${colProv.selectedMember!.memberCode}  |  मो: ${colProv.selectedMember!.mobileNumber}',
                          style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.successBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.success),
                    ),
                    child: Text(
                      'सक्रिय',
                      style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.success),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Monthly Saving Section
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'मासिक बचत (Monthly Saving)',
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    InkWell(
                      onTap: () => colProv.setIsSavingPaid(!colProv.isSavingPaid),
                      borderRadius: BorderRadius.circular(6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Checkbox(
                            value: colProv.isSavingPaid,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                            activeColor: AppColors.primary,
                            onChanged: (val) {
                              colProv.setIsSavingPaid(val ?? true);
                            },
                          ),
                          const SizedBox(width: 2),
                          Text(
                            'बचत जमा',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: colProv.isSavingPaid ? AppColors.primary : AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _savingAmountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  enabled: colProv.isSavingPaid,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.currency_rupee, size: 16),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    hintText: 'बचत रक्कम',
                  ),
                  onChanged: (val) {
                    final d = double.tryParse(val) ?? 0.0;
                    colProv.setMonthlySaving(d);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Active Loan Section: Previous Principal, Interest, Paid EMI, Remaining Principal
          Text('कर्ज हप्ता तपशील (Active Loan / EMI)', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          if (colProv.activeLoan != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF5FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE9D8FD), width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Multi-loan Selector (if member has more than 1 active loan)
                  if (colProv.availableMemberLoans.length > 1) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFD8B4FE)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: colProv.activeLoan?.id,
                          isExpanded: true,
                          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF6B21A8)),
                          items: colProv.availableMemberLoans.map((l) {
                            return DropdownMenuItem(
                              value: l.id,
                              child: Text(
                                '${l.loanCode} - मंजूर: ₹${l.approvedAmount.toStringAsFixed(0)} (हप्ता: ₹${l.emiAmount.toStringAsFixed(0)})',
                                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF6B21A8)),
                              ),
                            );
                          }).toList(),
                          onChanged: (lId) {
                            final l = colProv.availableMemberLoans.where((x) => x.id == lId).firstOrNull;
                            if (l != null) {
                              colProv.selectActiveLoan(l);
                              _paidEmiController.text = colProv.paidEmi.toStringAsFixed(2);
                            }
                          },
                        ),
                      ),
                    ),
                  ],

                  // Row 1: Loan code & Previous Principal Amount (Wrap prevents overflow)
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'कर्ज क्र: ${colProv.activeLoan!.loanCode}',
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF6B21A8)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3E8FF),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFD8B4FE)),
                        ),
                        child: Text(
                          'आधीची मुद्दल: ${_currencyFormat.format(colProv.previousPrincipal)}',
                          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF6B21A8)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Row 2: Required EMI, Interest, and Principal portion
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE9D8FD)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'देय हप्ता (Required EMI):',
                                style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _currencyFormat.format(colProv.requiredEmi),
                              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'या महिन्याचे व्याज (${colProv.activeLoan!.interestRate}%):',
                                style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _currencyFormat.format(colProv.monthlyInterest),
                              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFFD97706)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 18),

                  // Paid EMI TextField
                  Text('भरलेला हप्ता (Paid EMI Amount) *', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _paidEmiController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.currency_rupee, size: 16),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      hintText: 'भरलेला हप्ता रक्कम',
                    ),
                    onChanged: (val) {
                      final d = double.tryParse(val) ?? 0.0;
                      colProv.setPaidEmi(d);
                    },
                  ),
                  const SizedBox(height: 10),

                  // Live breakdown: Principal paid and Interest paid
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.cardBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('भरलेली मुद्दल (Principal):',
                                  style: GoogleFonts.poppins(fontSize: 9.5, color: AppColors.textSecondary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              Text(_currencyFormat.format(colProv.principalAmount),
                                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF4F46E5))),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.cardBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('भरलेले व्याज (Interest):',
                                  style: GoogleFonts.poppins(fontSize: 9.5, color: AppColors.textSecondary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              Text(_currencyFormat.format(colProv.interestAmount),
                                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFFD97706))),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Live Remaining Principal Box (Key user requirement!)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F3FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFC4B5FD)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'हप्ता भरल्यानंतर शिल्लक मुद्दल:',
                                style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.w600, color: const Color(0xFF5B21B6)),
                              ),
                              Text(
                                'Remaining Principal (${_currencyFormat.format(colProv.previousPrincipal)} - ${_currencyFormat.format(colProv.principalAmount)})',
                                style: GoogleFonts.poppins(fontSize: 8.5, color: const Color(0xFF7C3AED)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _currencyFormat.format(colProv.remainingPrincipal),
                          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF5B21B6)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Live Remaining EMI for this month badge (Wrap prevents horizontal overflow)
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'या महिन्याचा बाकी हप्ता:',
                        style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: colProv.remainingEmi > 0 ? AppColors.warningBg : AppColors.successBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          colProv.remainingEmi > 0
                              ? '${_currencyFormat.format(colProv.remainingEmi)} बाकी'
                              : '₹0.00 (हप्ता पूर्ण भरला)',
                          style: GoogleFonts.poppins(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: colProv.remainingEmi > 0 ? AppColors.warning : AppColors.success,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.info),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      colProv.selectedMember == null
                          ? 'कृपया प्रथम सदस्य निवडा'
                          : 'या सदस्याचे कोणतेही चालू कर्ज नाही (No Active Loan)',
                      style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),

          // Payment Mode: Cash in Hand & Bank Accounts
          Text('पेमेंट पद्धत (Payment Mode & Account)', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Row(
            children: [
              _buildPaymentModeChip(colProv, bankProv, 'cash', 'हातातील रोख\n(Cash in Hand)', Icons.account_balance_wallet_rounded),
              const SizedBox(width: 8),
              _buildPaymentModeChip(colProv, bankProv, 'bank', 'बँक खात्यात जमा\n(Bank Account)', Icons.account_balance_rounded),
              const SizedBox(width: 8),
              _buildPaymentModeChip(colProv, bankProv, 'online', 'UPI / ऑनलाइन\n(Online)', Icons.qr_code_rounded),
            ],
          ),
          const SizedBox(height: 10),

          // Bank Account Selector when Bank or Online is chosen
          if (colProv.paymentMode == 'bank' || colProv.paymentMode == 'online') ...[
            Text('बँक खाते निवडा (Select Group Bank Account) *',
                style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF0369A1))),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F9FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBAE6FD)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: bankProv.activeBanks.any((b) => b.id == colProv.selectedBankAccountId)
                      ? colProv.selectedBankAccountId
                      : (bankProv.activeBanks.isNotEmpty ? bankProv.activeBanks.first.id : null),
                  hint: Text('बँक खाते निवडा (Select Bank)...', style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textMuted)),
                  isExpanded: true,
                  items: bankProv.activeBanks.map((b) {
                    return DropdownMenuItem(
                      value: b.id,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${b.bankName} (${b.maskedAccountNumber})',
                              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'शिल्लक: ${_currencyFormat.format(b.currentBalance)}',
                            style: GoogleFonts.poppins(fontSize: 10.5, color: const Color(0xFF047857), fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (bankId) {
                    if (bankId != null) {
                      final b = bankProv.activeBanks.firstWhere((x) => x.id == bankId, orElse: () => bankProv.activeBanks.first);
                      colProv.setSelectedBankAccount(b.id, '${b.bankName} (${b.maskedAccountNumber})');
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 10),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet_rounded, size: 16, color: Color(0xFF059669)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'रक्कम थेट गटाच्या हातातील रोख शिल्लक (Cash in Hand) मध्ये जमा होईल.',
                      style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.w600, color: const Color(0xFF065F46)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Ref No & Notes
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _refNoController,
                  decoration: InputDecoration(
                    labelText: 'संदर्भ क्र. (Ref / Cheque No)',
                    labelStyle: GoogleFonts.poppins(fontSize: 11),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: colProv.setReferenceNo,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _notesController,
                  decoration: InputDecoration(
                    labelText: 'शेरा (Remark / Notes)',
                    labelStyle: GoogleFonts.poppins(fontSize: 11),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: colProv.setNotes,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Collection Summary Box (Total = Saving + EMI)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFA7F3D0), width: 1.2),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('मासिक बचत:', style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
                    Text(
                      _currencyFormat.format(colProv.isSavingPaid ? colProv.monthlySaving : 0.0),
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('कर्ज हप्ता:', style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
                    Text(
                      _currencyFormat.format(colProv.paidEmi),
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const Divider(height: 16, color: Color(0xFFA7F3D0)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'एकूण संकलन रक्कम',
                          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF065F46)),
                        ),
                        Text(
                          'Total Collection (Saving + EMI)',
                          style: GoogleFonts.poppins(fontSize: 9, color: const Color(0xFF047857)),
                        ),
                      ],
                    ),
                    Text(
                      _currencyFormat.format(colProv.calculatedTotal),
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF065F46),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Action Buttons: Save & Reset (Hidden in Member View-Only mode)
          if (auth.canWrite)
            Row(
              children: [
                Expanded(
                  flex: 6,
                  child: ElevatedButton.icon(
                    onPressed: colProv.isLoading
                        ? null
                        : () async {
                            final gid = auth.currentGroup?.id ?? '';
                            final createdBy = auth.currentProfile?.id ?? 'admin';
                            final messenger = ScaffoldMessenger.of(context);

                            final success = await colProv.saveCurrentEntry(
                              groupId: gid,
                              createdBy: createdBy,
                              membersList: memProv.members,
                              loansList: loanProv.loans,
                              banksList: bankProv.banks,
                            );

                            if (!context.mounted) return;

                             if (success) {
                              // Immediately refresh loans, collections, dashboard metrics, banks, savings & members!
                              if (gid.isNotEmpty) {
                                final loanP = context.read<LoanProvider>();
                                final dashP = context.read<DashboardProvider>();
                                final bankP = context.read<BankProvider>();
                                final savP = context.read<SavingsProvider>();
                                final memP = context.read<MemberProvider>();

                                await loanP.loadLoans(gid);
                                await colProv.fetchCollections(
                                  groupId: gid,
                                  membersList: memProv.members,
                                  loansList: loanP.loans,
                                  banksList: bankProv.banks,
                                );
                                await Future.wait([
                                  dashP.loadDashboardMetrics(gid),
                                  bankP.loadBanks(gid),
                                  savP.fetchSavings(gid),
                                  memP.fetchMembers(gid),
                                ]);
                              }

                              if (context.mounted) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text('मासिक संकलन यशस्वीरीत्या जतन केले! रोख व बँक शिल्लक अपडेट झाली!',
                                        style: GoogleFonts.poppins()),
                                    backgroundColor: AppColors.success,
                                  ),
                                );

                                setState(() {
                                  _filterMemberId = null;
                                });
                                _savingAmountController.text = defaultGroupSaving.toStringAsFixed(0);
                                _paidEmiController.text = '0.00';
                                _refNoController.clear();
                                _notesController.clear();
                              }
                            } else if (colProv.errorMessage != null && mounted) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(colProv.errorMessage!, style: GoogleFonts.poppins()),
                                  backgroundColor: AppColors.danger,
                                ),
                              );
                            }
                          },
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                    label: Text('संकलन जतन करा (Save)', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 4,
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _filterMemberId = null;
                      });
                      colProv.resetForm(defaultGroupSaving);
                      _savingAmountController.text = defaultGroupSaving.toStringAsFixed(0);
                      _paidEmiController.text = '0.00';
                      _refNoController.clear();
                      _notesController.clear();
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      side: const BorderSide(color: AppColors.cardBorder),
                    ),
                    child: Text('रीसेट (Reset)', style: GoogleFonts.poppins(color: AppColors.textSecondary)),
                  ),
                ),
              ],
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFCD34D)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.visibility_rounded, color: Color(0xFFD97706), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'केवळ पाहण्याचा अधिकार (View-Only Mode: संकलन नोंद केवळ Admin करू शकतात)',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPaymentModeChip(
    MonthlyCollectionProvider colProv,
    BankProvider bankProv,
    String modeKey,
    String label,
    IconData icon,
  ) {
    final isSelected = colProv.paymentMode == modeKey;
    return Expanded(
      child: InkWell(
        onTap: () {
          colProv.setPaymentMode(modeKey);
          if ((modeKey == 'bank' || modeKey == 'online') &&
              (colProv.selectedBankAccountId == null || colProv.selectedBankAccountId!.isEmpty) &&
              bankProv.activeBanks.isNotEmpty) {
            final primary = bankProv.activeBanks.firstWhere((b) => b.isPrimary == 1, orElse: () => bankProv.activeBanks.first);
            colProv.setSelectedBankAccount(primary.id, '${primary.bankName} (${primary.maskedAccountNumber})');
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withOpacity(0.12) : const Color(0xFFF9FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.cardBorder,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: isSelected ? AppColors.primary : AppColors.textMuted),
              const SizedBox(height: 2),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 9.5,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 5. MIDDLE WORKSPACE: HISTORY PANEL (TABLE)
  // ==========================================
  Widget _buildHistoryPanel(
    BuildContext context,
    MonthlyCollectionProvider colProv,
  ) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final list = colProv.filteredCollections.where((c) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return (c.memberName?.toLowerCase().contains(q) ?? false) ||
          (c.memberCode?.toLowerCase().contains(q) ?? false) ||
          (c.referenceNo?.toLowerCase().contains(q) ?? false) ||
          c.collectionDate.contains(q);
    }).toList();

    return Container(
      constraints: const BoxConstraints(minHeight: 520),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Search
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.history_rounded, color: AppColors.secondary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'मासिक संकलन इतिहास',
                      style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    Text(
                      'Monthly Collection History (${list.length} नोंदी)',
                      style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              // Search Input
              SizedBox(
                width: 160,
                child: TextField(
                  controller: _historySearchController,
                  decoration: InputDecoration(
                    hintText: 'शोधा (Search)...',
                    hintStyle: GoogleFonts.poppins(fontSize: 11),
                    prefixIcon: const Icon(Icons.search, size: 16),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.trim();
                    });
                  },
                ),
              ),
            ],
          ),
          const Divider(height: 24),

          // Scrollable Data Table
          if (list.isEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 60),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Icons.inbox_outlined, size: 48, color: AppColors.textMuted.withOpacity(0.5)),
                  const SizedBox(height: 12),
                  Text(
                    'कोणतीही संकलन नोंद सापडली नाही',
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                  ),
                  Text(
                    'डाव्या फॉर्ममधून नवीन संकलन नोंदवा किंवा फिल्टर तपासा',
                    style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ] else ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                dataRowMinHeight: 44,
                dataRowMaxHeight: 52,
                horizontalMargin: 12,
                columnSpacing: 16,
                columns: [
                  DataColumn(label: Text('दिनांक\nDate', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700))),
                  DataColumn(label: Text('सदस्य\nMember', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700))),
                  DataColumn(label: Text('बचत\nSaving', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700))),
                  DataColumn(label: Text('मुद्दल\nPrincipal', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700))),
                  DataColumn(label: Text('व्याज\nInterest', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700))),
                  DataColumn(label: Text('हप्ता\nEMI', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700))),
                  DataColumn(label: Text('एकूण संकलन\nTotal', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700))),
                  DataColumn(label: Text('कृती\nAction', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700))),
                ],
                rows: [
                  ...list.map((item) {
                    return DataRow(
                      cells: [
                        DataCell(
                          Text(
                            item.collectionDate,
                            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ),
                        DataCell(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                item.memberName ?? 'सभासद',
                                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              Text(
                                '${item.memberCode ?? "-"} · ${item.paymentMode.toUpperCase()}',
                                style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        DataCell(Text(_currencyFormat.format(item.monthlySaving), style: GoogleFonts.poppins(fontSize: 12))),
                        DataCell(Text(_currencyFormat.format(item.principalAmount), style: GoogleFonts.poppins(fontSize: 12))),
                        DataCell(Text(_currencyFormat.format(item.interestAmount), style: GoogleFonts.poppins(fontSize: 12))),
                        DataCell(Text(_currencyFormat.format(item.paidEmi), style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500))),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _currencyFormat.format(item.totalCollection),
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF047857),
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.visibility_outlined, size: 18, color: AppColors.primary),
                                tooltip: 'पावती पहा (View Receipt)',
                                onPressed: () => _showReceiptDialog(context, item),
                              ),
                              if (auth.canEdit)
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.info),
                                  tooltip: 'बदला (Edit)',
                                  onPressed: () => _showEditDialog(context, item, colProv),
                                ),
                              if (auth.canDelete)
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.danger),
                                  tooltip: 'हटवा (Delete)',
                                  onPressed: () => _confirmDelete(context, item, colProv),
                                ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }),
                  // Total Summary Row
                  DataRow(
                    color: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
                    cells: [
                      DataCell(Text('एकूण (Total)', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w800))),
                      DataCell(Text('${list.length} नोंदी', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700))),
                      DataCell(Text(
                        _currencyFormat.format(list.fold(0.0, (s, i) => s + i.monthlySaving)),
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700),
                      )),
                      DataCell(Text(
                        _currencyFormat.format(list.fold(0.0, (s, i) => s + i.principalAmount)),
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700),
                      )),
                      DataCell(Text(
                        _currencyFormat.format(list.fold(0.0, (s, i) => s + i.interestAmount)),
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700),
                      )),
                      DataCell(Text(
                        _currencyFormat.format(list.fold(0.0, (s, i) => s + i.paidEmi)),
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700),
                      )),
                      DataCell(
                        Text(
                          _currencyFormat.format(list.fold(0.0, (s, i) => s + i.totalCollection)),
                          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w800, color: const Color(0xFF065F46)),
                        ),
                      ),
                      const DataCell(Text('-')),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // 6. MIDDLE WORKSPACE: RIGHT PANEL (MEMBER DETAILS)
  // ==========================================
  Widget _buildMemberDetailsPanel(
    BuildContext context,
    MemberProvider memProv,
    LoanProvider loanProv,
    MonthlyCollectionProvider colProv,
  ) {
    final member = colProv.selectedMember;
    final loan = colProv.activeLoan;

    // Find last collection for this member if exists
    final memberCollections = colProv.collections.where((c) => c.memberId == member?.id).toList();
    final lastCollection = memberCollections.isNotEmpty ? memberCollections.first : null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with "View All Members" Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.teal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.person_pin_rounded, color: Colors.teal, size: 20),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'सदस्य तपशील',
                    style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () => _showAllMembersDialog(context, memProv),
                icon: const Icon(Icons.people_alt_outlined, size: 14),
                label: Text('सर्व पहा', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              ),
            ],
          ),
          const Divider(height: 20),

          if (member == null) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 36),
              alignment: Alignment.center,
              child: Column(
                children: [
                  const Icon(Icons.person_search_rounded, size: 44, color: AppColors.textMuted),
                  const SizedBox(height: 10),
                  Text(
                    'कोणताही सदस्य निवडलेला नाही',
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                  ),
                  Text(
                    'तपशील पाहण्यासाठी डाव्या फॉर्ममधून सदस्य निवडा',
                    style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textMuted),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ] else ...[
            // 1. Profile Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      member.fullName.isNotEmpty ? member.fullName[0] : 'M',
                      style: GoogleFonts.poppins(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    member.fullName,
                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    'सदस्य कोड: ${member.memberCode}',
                    style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
                  ),
                  const Divider(height: 16),
                  _buildDetailRow('मोबाईल (Mobile):', member.mobileNumber),
                  _buildDetailRow('पत्ता (Address):', (member.address != null && member.address!.isNotEmpty) ? member.address! : 'पुणे'),
                  _buildDetailRow('दाखल दिनांक (Joined):', (member.joiningDate != null && member.joiningDate!.isNotEmpty) ? member.joiningDate! : '-'),
                  _buildDetailRow('पद (Role):', member.roleInGroup.isNotEmpty ? member.roleInGroup : 'सदस्य'),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 2. Active Loan Info Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: loan != null ? const Color(0xFFFAF5FF) : const Color(0xFFF9FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: loan != null ? const Color(0xFFE9D8FD) : AppColors.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.monetization_on_outlined, size: 16, color: loan != null ? const Color(0xFF7C3AED) : AppColors.textMuted),
                      const SizedBox(width: 6),
                      Text(
                        'चालू कर्ज माहिती (Active Loan)',
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (loan != null) ...[
                    _buildDetailRow('कर्ज क्र:', loan.loanCode),
                    _buildDetailRow('मंजूर रक्कम:', _currencyFormat.format(loan.approvedAmount)),
                    _buildDetailRow('शिल्लक मुद्दल:', _currencyFormat.format(loan.outstandingPrincipal)),
                    _buildDetailRow('व्याज दर:', '${loan.interestRate}%'),
                    _buildDetailRow('हप्ता (EMI):', _currencyFormat.format(loan.emiAmount)),
                  ] else ...[
                    Text(
                      'या सदस्याचे कोणतेही चालू कर्ज नाही.',
                      style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 3. Monthly Saving Status Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.savings_outlined, size: 16, color: Color(0xFF16A34A)),
                      const SizedBox(width: 6),
                      Text(
                        'मासिक बचत स्थिती (Savings)',
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF15803D)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _buildDetailRow('नियमित मासिक बचत:', _currencyFormat.format(colProv.monthlySaving)),
                  _buildDetailRow('स्थिती:', 'सक्रिय सभासद'),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 4. Last Collection Info Card
            if (lastCollection != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.receipt_rounded, size: 15, color: Color(0xFF2563EB)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'मागील संकलन (Last Collection)',
                            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF1D4ED8)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () {
                            colProv.setFilterMember(member.id);
                          },
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDBEAFE),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'इतिहास पहा',
                              style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF1D4ED8)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _buildDetailRow('दिनांक:', lastCollection.collectionDate),
                    _buildDetailRow('एकूण जमा:', _currencyFormat.format(lastCollection.totalCollection)),
                    _buildDetailRow('पेमेंट मोड:', lastCollection.paymentMode.toUpperCase()),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(
              label,
              style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 5,
            child: Text(
              value,
              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 7. BOTTOM SECTION: TRANSACTION DETAILS ONLY
  // (Automatic calculation logic & rules cards removed per user request)
  // ==========================================
  Widget _buildBottomSection(BuildContext context, MonthlyCollectionProvider colProv) {
    final recent = colProv.collections.take(8).toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                    child: const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'अलीकडील व्यवहार तपशील (Recent Transaction Logs)',
                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                ],
              ),
              Text(
                '${recent.length} व्यवहार',
                style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
              ),
            ],
          ),
          const Divider(height: 20),
          if (recent.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('कोणतेही अलीकडील व्यवहार नाहीत',
                    style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textMuted)),
              ),
            ),
          ] else ...[
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: recent.map((tx) {
                final isBank = tx.paymentMode == 'bank';
                final isOnline = tx.paymentMode == 'online';
                return Container(
                  width: 320,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isOnline
                              ? const Color(0xFFEDE9FE)
                              : (isBank ? const Color(0xFFE0F2FE) : const Color(0xFFDCFCE7)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isOnline
                              ? Icons.qr_code_rounded
                              : (isBank ? Icons.account_balance_rounded : Icons.money_rounded),
                          size: 18,
                          color: isOnline
                              ? const Color(0xFF6D28D9)
                              : (isBank ? const Color(0xFF0369A1) : const Color(0xFF15803D)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tx.memberName ?? 'सभासद',
                                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700),
                                overflow: TextOverflow.ellipsis),
                            Text(
                              isBank && tx.bankAccountName != null
                                  ? '${tx.collectionDate} · ${tx.bankAccountName}'
                                  : '${tx.collectionDate} · ${tx.paymentMode == "cash" ? "Cash in Hand" : tx.paymentMode.toUpperCase()}',
                              style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textSecondary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        _currencyFormat.format(tx.totalCollection),
                        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF047857)),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // 8. DIALOGS: VIEW RECEIPT, EDIT, ALL MEMBERS, DELETE CONFIRMATION
  // ==========================================
  void _showReceiptDialog(BuildContext context, MonthlyCollection item) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 440,
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 30),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'मासिक संकलन अधिकृत पावती',
                        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'Official Monthly Collection Receipt',
                        style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 24),
                _buildReceiptRow('पावती क्र. / ID:', item.id.length > 8 ? item.id.substring(0, 8).toUpperCase() : item.id),
                _buildReceiptRow('दिनांक (Date):', item.collectionDate),
                _buildReceiptRow('सदस्याचे नाव (Member):', item.memberName ?? 'Unknown'),
                _buildReceiptRow('सदस्य कोड (Code):', item.memberCode ?? '-'),
                if (item.loanNumber != null && item.loanNumber != '-')
                  _buildReceiptRow('कर्ज क्र. (Loan No):', item.loanNumber!),
                const Divider(height: 16),
                _buildReceiptRow('मासिक बचत (Monthly Saving):', _currencyFormat.format(item.monthlySaving)),
                _buildReceiptRow('कर्ज मुद्दल (Principal):', _currencyFormat.format(item.principalAmount)),
                _buildReceiptRow('कर्ज व्याज (Interest):', _currencyFormat.format(item.interestAmount)),
                _buildReceiptRow('भरलेला हप्ता (Paid EMI):', _currencyFormat.format(item.paidEmi)),
                if (item.remainingEmi > 0)
                  _buildReceiptRow('शिल्लक हप्ता (Remaining):', _currencyFormat.format(item.remainingEmi)),
                const Divider(height: 16),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'एकूण संकलन जमा:',
                        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF065F46)),
                      ),
                      Text(
                        _currencyFormat.format(item.totalCollection),
                        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF065F46)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                _buildReceiptRow(
                  'पेमेंट पद्धत (Mode):',
                  item.paymentMode == 'cash'
                      ? 'CASH IN HAND'
                      : (item.bankAccountName != null ? 'BANK (${item.bankAccountName})' : item.paymentMode.toUpperCase()),
                ),
                if (item.referenceNo != null && item.referenceNo!.isNotEmpty)
                  _buildReceiptRow('संदर्भ क्र. (Ref No):', item.referenceNo!),
                if (item.notes != null && item.notes!.isNotEmpty)
                  _buildReceiptRow('शेरा (Remarks):', item.notes!),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('बंद करा (Close)', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReceiptRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary)),
          Text(value, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, MonthlyCollection item, MonthlyCollectionProvider colProv) {
    final savingCtrl = TextEditingController(text: item.monthlySaving.toStringAsFixed(0));
    final emiCtrl = TextEditingController(text: item.paidEmi.toStringAsFixed(2));
    final refCtrl = TextEditingController(text: item.referenceNo ?? '');
    final notesCtrl = TextEditingController(text: item.notes ?? '');
    String mode = item.paymentMode;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final sVal = double.tryParse(savingCtrl.text) ?? 0.0;
            final eVal = double.tryParse(emiCtrl.text) ?? 0.0;
            final tot = sVal + eVal;

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                width: 420,
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('संकलन नोंद बदला (Edit Collection)',
                        style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700)),
                    Text('${item.memberName} · ${item.collectionDate}',
                        style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary)),
                    const Divider(height: 20),
                    Text('मासिक बचत रक्कम:', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: savingCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 10),
                    Text('भरलेला हप्ता (Paid EMI):', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: emiCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 10),
                    Text('पेमेंट पद्धत:', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      value: mode,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'cash', child: Text('हातातील रोख (Cash in Hand)')),
                        DropdownMenuItem(value: 'bank', child: Text('बँक (Bank)')),
                        DropdownMenuItem(value: 'online', child: Text('UPI / Online')),
                      ],
                      onChanged: (v) {
                        if (v != null) setDialogState(() => mode = v);
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: refCtrl,
                      decoration: InputDecoration(
                        labelText: 'संदर्भ क्र. (Ref No)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: notesCtrl,
                      decoration: InputDecoration(
                        labelText: 'शेरा (Notes)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('सुधारित एकूण संकलन:',
                              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                          Text(_currencyFormat.format(tot),
                              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF047857))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text('रद्द करा', style: GoogleFonts.poppins()),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            final nav = Navigator.of(context);
                            final messenger = ScaffoldMessenger.of(context);
                            final updated = item.copyWith(
                              monthlySaving: sVal,
                              paidEmi: eVal,
                              totalCollection: tot,
                              paymentMode: mode,
                              referenceNo: refCtrl.text.trim(),
                              notes: notesCtrl.text.trim(),
                            );
                            final ok = await colProv.updateCollection(updated);
                            if (ok && mounted) {
                              nav.pop();
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('नोंद यशस्वीरीत्या बदलली!', style: GoogleFonts.poppins()),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                          child: Text('बदल जतन करा', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, MonthlyCollection item, MonthlyCollectionProvider colProv) {
    showDialog(
      context: context,
      builder: (context) {
        final nav = Navigator.of(context);
        final messenger = ScaffoldMessenger.of(context);
        return AlertDialog(
          title: Text('नोंद हटवायची खात्री आहे का?', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
          content: Text(
            'सदस्य: ${item.memberName}\nदिनांक: ${item.collectionDate}\nरक्कम: ${_currencyFormat.format(item.totalCollection)}\n\nही नोंद कायमस्वरूपी हटवली जाईल.',
            style: GoogleFonts.poppins(fontSize: 12),
          ),
          actions: [
            TextButton(
              onPressed: () => nav.pop(),
              child: Text('नाही (Cancel)', style: GoogleFonts.poppins()),
            ),
            ElevatedButton(
              onPressed: () async {
                nav.pop();
                final ok = await colProv.deleteCollection(item.id);
                if (ok && mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('नोंद यशस्वीरीत्या हटवली!', style: GoogleFonts.poppins()),
                      backgroundColor: AppColors.warning,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
              ),
              child: Text('हटवा (Delete)', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );
  }

  void _showAllMembersDialog(BuildContext context, MemberProvider memProv) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 480,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('गटातील सर्व सदस्य (${memProv.members.length})',
                        style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700)),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(),
                SizedBox(
                  height: 360,
                  child: ListView.separated(
                    itemCount: memProv.members.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final m = memProv.members[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary.withOpacity(0.1),
                          child: Text(m.fullName.isNotEmpty ? m.fullName[0] : 'M',
                              style: GoogleFonts.poppins(color: AppColors.primary, fontWeight: FontWeight.w700)),
                        ),
                        title: Text(m.fullName, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                        subtitle: Text('कोड: ${m.memberCode} · मो: ${m.mobileNumber}',
                            style: GoogleFonts.poppins(fontSize: 11)),
                        trailing: ElevatedButton(
                          onPressed: () {
                            final colProv = Provider.of<MonthlyCollectionProvider>(context, listen: false);
                            final loanProv = Provider.of<LoanProvider>(context, listen: false);
                            final auth = Provider.of<AuthProvider>(context, listen: false);
                            final defaultSaving = auth.currentGroup?.monthlySavingsAmount ?? 200.0;

                            colProv.onMemberChanged(m, loanProv.loans, defaultSaving);
                            _savingAmountController.text = colProv.monthlySaving.toStringAsFixed(0);
                            _paidEmiController.text = colProv.paidEmi.toStringAsFixed(2);
                            Navigator.of(context).pop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          ),
                          child: Text('निवडा', style: GoogleFonts.poppins(fontSize: 11)),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
