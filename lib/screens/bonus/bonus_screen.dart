import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/bonus.dart';
import '../../models/bonus_setting.dart';
import '../../models/member.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bank_provider.dart';
import '../../providers/bonus_provider.dart';
import '../../providers/member_provider.dart';
import '../../services/pdf_service.dart';

class BonusScreen extends StatefulWidget {
  const BonusScreen({super.key});

  @override
  State<BonusScreen> createState() => _BonusScreenState();
}

class _BonusScreenState extends State<BonusScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  // Add/Edit Bonus Form state
  Member? _selectedMember;
  String _entryBonusType = 'savings';
  double _entryBasisAmount = 0.0;
  bool _isFetchingBasisAmount = false;
  final TextEditingController _entryRateController = TextEditingController(text: '5.0');
  final TextEditingController _entryBonusAmountController = TextEditingController(text: '0');
  final TextEditingController _entryRemarksController = TextEditingController();

  // Settings form state
  final TextEditingController _settingsPercentController = TextEditingController(text: '5.0');
  final TextEditingController _settingsMinEligController = TextEditingController(text: '0');
  final TextEditingController _settingsMaxBonusController = TextEditingController(text: '5000');

  // Selected radio in right sidebar
  String _activeMethodRadio = 'Percentage of Savings';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _entryRateController.dispose();
    _entryBonusAmountController.dispose();
    _entryRemarksController.dispose();
    _settingsPercentController.dispose();
    _settingsMinEligController.dispose();
    _settingsMaxBonusController.dispose();
    super.dispose();
  }

  void _loadData() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final gid = auth.currentGroup?.id;
    if (gid != null) {
      final bonusProv = Provider.of<BonusProvider>(context, listen: false);
      bonusProv.loadBonusData(gid).then((_) {
        if (bonusProv.settings != null) {
          _settingsPercentController.text = bonusProv.settings!.bonusPercentage.toString();
          _settingsMinEligController.text = bonusProv.settings!.minEligibility.toString();
          _settingsMaxBonusController.text = bonusProv.settings!.maxBonus.toString();
          _entryRateController.text = bonusProv.settings!.bonusPercentage.toString();
        }
      });
      Provider.of<MemberProvider>(context, listen: false).fetchMembers(gid);
      Provider.of<BankProvider>(context, listen: false).loadBanks(gid);
    }
  }

  // --- MEMBER SELECTION TRIGGER: AUTO FETCH SAVINGS FROM DATABASE ---
  Future<void> _onMemberSelected(Member? member) async {
    setState(() {
      _selectedMember = member;
      _entryBasisAmount = 0.0;
      _isFetchingBasisAmount = member != null;
    });

    if (member == null) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final gid = auth.currentGroup?.id;
    if (gid == null) return;

    final bonusProv = Provider.of<BonusProvider>(context, listen: false);
    final savings = await bonusProv.getMemberSavings(
      gid,
      member.id,
      from: bonusProv.fromDate,
      to: bonusProv.toDate,
    );

    if (!mounted) return;

    setState(() {
      _entryBasisAmount = savings;
      _isFetchingBasisAmount = false;
      _recalculateEntryBonus();
    });
  }

  void _recalculateEntryBonus() {
    final rate = double.tryParse(_entryRateController.text) ?? 5.0;
    double bonusAmt = 0.0;
    if (_entryBonusType == 'fixed' || _entryBonusType == 'fixed_amount') {
      bonusAmt = double.tryParse(_entryBonusAmountController.text) ?? 0.0;
    } else {
      bonusAmt = (_entryBasisAmount * rate / 100.0).roundToDouble();
      final maxBonus = double.tryParse(_settingsMaxBonusController.text) ?? 5000.0;
      if (maxBonus > 0 && bonusAmt > maxBonus) {
        bonusAmt = maxBonus;
      }
      _entryBonusAmountController.text = bonusAmt.toStringAsFixed(0);
    }
  }

  Future<void> _selectDate(BuildContext context, bool isFromDate) async {
    final bonusProv = Provider.of<BonusProvider>(context, listen: false);
    final initialStr = isFromDate ? bonusProv.fromDate : bonusProv.toDate;
    DateTime initial = DateTime.tryParse(initialStr) ?? DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2050, 12, 31),
      builder: (ctx, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      final formatted = DateFormat('yyyy-MM-dd').format(picked);
      if (isFromDate) {
        bonusProv.setDateRange(formatted, bonusProv.toDate);
      } else {
        bonusProv.setDateRange(bonusProv.fromDate, formatted);
      }
      // Re-fetch savings for current member if selected
      if (_selectedMember != null) {
        _onMemberSelected(_selectedMember);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final bonusProv = Provider.of<BonusProvider>(context);
    final memberProv = Provider.of<MemberProvider>(context);
    final isDesktop = MediaQuery.of(context).size.width >= 1000;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: bonusProv.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. PAGE TITLE & HEADER
                  _buildHeader(),
                  const SizedBox(height: 14),

                  // 2. TOP FILTERS ROW
                  _buildTopFilters(bonusProv, auth),
                  const SizedBox(height: 14),

                  // 3. KPI SUMMARY CARDS
                  _buildKpiSummaryCards(bonusProv),
                  const SizedBox(height: 16),

                  // 4. MAIN CONTENT AREA (Left: Tabs & Tables, Right: Quick Actions & Settings)
                  if (isDesktop)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Tabs and Tables (72% width)
                        Expanded(
                          flex: 72,
                          child: _buildMainTabsCard(bonusProv, memberProv, auth),
                        ),
                        const SizedBox(width: 16),
                        // Right Side Panels (28% width)
                        Expanded(
                          flex: 28,
                          child: _buildRightSidePanels(bonusProv, memberProv, auth),
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        _buildMainTabsCard(bonusProv, memberProv, auth),
                        const SizedBox(height: 16),
                        _buildRightSidePanels(bonusProv, memberProv, auth),
                      ],
                    ),
                ],
              ),
            ),
    );
  }

  // --- 1. PAGE TITLE & HEADER ---
  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF1E3A8A).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.card_giftcard, color: Color(0xFF1E3A8A), size: 28),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'लाभांश व बोनस व्यवस्थापन (Bonus Module)',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            Text(
              'Manage member bonuses, calculate, approve and track payments.',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- 2. TOP FILTERS ROW ---
  Widget _buildTopFilters(BonusProvider bonusProv, AuthProvider auth) {
    final currentFY = bonusProv.financialYear;
    final maxTargetYear = math.max(DateTime.now().year, auth.globalEndDate.year) + 1;
    const startFYYear = 2022;
    final Set<String> fySet = {};
    for (int y = startFYYear; y <= maxTargetYear; y++) {
      fySet.add('$y - ${y + 1}');
    }
    if (currentFY.isNotEmpty) {
      fySet.add(currentFY);
    }
    final sortedFY = fySet.toList()..sort();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Financial Year
          SizedBox(
            width: 160,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Financial Year', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: sortedFY.contains(bonusProv.financialYear) ? bonusProv.financialYear : sortedFY.last,
                      isExpanded: true,
                      style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w600),
                      items: sortedFY.map((fy) {
                        return DropdownMenuItem(value: fy, child: Text(fy));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) bonusProv.setFinancialYear(val);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          // From Date
          SizedBox(
            width: 150,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('From Date', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                const SizedBox(height: 4),
                InkWell(
                  onTap: () => _selectDate(context, true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 14, color: Color(0xFF64748B)),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('dd-MM-yyyy').format(DateTime.parse(bonusProv.fromDate)),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // To Date
          SizedBox(
            width: 150,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('To Date', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                const SizedBox(height: 4),
                InkWell(
                  onTap: () => _selectDate(context, false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 14, color: Color(0xFF64748B)),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('dd-MM-yyyy').format(DateTime.parse(bonusProv.toDate)),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bonus Type
          SizedBox(
            width: 180,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Bonus Type', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: bonusProv.selectedBonusType,
                      isExpanded: true,
                      style: const TextStyle(fontSize: 12.5, color: Colors.black87, fontWeight: FontWeight.w500),
                      items: const [
                        DropdownMenuItem(value: 'All Types', child: Text('सर्व प्रकार (All Types)')),
                        DropdownMenuItem(value: 'savings', child: Text('बचत आधारित (Savings)')),
                        DropdownMenuItem(value: 'profit', child: Text('नफा आधारित (Profit)')),
                        DropdownMenuItem(value: 'attendance', child: Text('हजेरी आधारित (Attendance)')),
                        DropdownMenuItem(value: 'fixed', child: Text('निश्चित (Fixed)')),
                        DropdownMenuItem(value: 'custom', child: Text('सानुकूल (Custom)')),
                      ],
                      onChanged: (val) {
                        if (val != null) bonusProv.setBonusType(val);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Member Search
          SizedBox(
            width: 220,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Search', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                const SizedBox(height: 4),
                SizedBox(
                  height: 38,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search Member...',
                      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.search, size: 16, color: Color(0xFF64748B)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                    ),
                    onChanged: (val) => bonusProv.setSearchQuery(val),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 3. KPI SUMMARY CARDS ---
  Widget _buildKpiSummaryCards(BonusProvider bonusProv) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final isWide = constraints.maxWidth >= 700;
      final cardWidth = isWide ? (constraints.maxWidth - 36) / 4 : (constraints.maxWidth - 12) / 2;

      return Wrap(
        spacing: 12,
        runSpacing: 10,
        children: [
          // Total Members
          _buildKpiCard(
            title: 'Total Members',
            value: '${bonusProv.totalMembers}',
            icon: Icons.groups,
            iconBg: const Color(0xFFE0E7FF),
            iconColor: const Color(0xFF3B82F6),
            width: cardWidth,
          ),

          // Total Bonus
          _buildKpiCard(
            title: 'Total Bonus',
            value: '₹ ${bonusProv.totalBonus.toStringAsFixed(0)}',
            icon: Icons.monetization_on,
            iconBg: const Color(0xFFDCFCE7),
            iconColor: const Color(0xFF10B981),
            width: cardWidth,
          ),

          // Paid Bonus
          _buildKpiCard(
            title: 'Paid Bonus',
            value: '₹ ${bonusProv.paidBonus.toStringAsFixed(0)}',
            icon: Icons.check_circle,
            iconBg: const Color(0xFFD1FAE5),
            iconColor: const Color(0xFF059669),
            width: cardWidth,
          ),

          // Pending Bonus
          _buildKpiCard(
            title: 'Pending Bonus',
            value: '₹ ${bonusProv.pendingBonus.toStringAsFixed(0)}',
            icon: Icons.hourglass_top,
            iconBg: const Color(0xFFFEF3C7),
            iconColor: const Color(0xFFF59E0B),
            width: cardWidth,
          ),
        ],
      );
    });
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- 4. MAIN TABS CARD (Tabs 1-6) ---
  Widget _buildMainTabsCard(
    BonusProvider bonusProv,
    MemberProvider memberProv,
    AuthProvider auth,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tabs Bar
          Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: const Color(0xFF1D4ED8),
              unselectedLabelColor: const Color(0xFF64748B),
              indicatorColor: const Color(0xFF1D4ED8),
              indicatorWeight: 3,
              labelStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
              unselectedLabelStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
              tabs: const [
                Tab(text: 'Bonus List'),
                Tab(text: 'Calculation'),
                Tab(text: 'Bonus Entry'),
                Tab(text: 'Approval'),
                Tab(text: 'Payment'),
                Tab(text: 'Settings'),
              ],
            ),
          ),

          // Tab views
          SizedBox(
            height: 640,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTabBonusList(bonusProv, auth),
                _buildTabCalculation(bonusProv, memberProv, auth),
                _buildTabBonusEntry(bonusProv, memberProv, auth),
                _buildTabApproval(bonusProv, auth),
                _buildTabPayment(bonusProv, auth),
                _buildTabSettings(bonusProv, auth),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: BONUS LIST TABLE
  // ==========================================
  Widget _buildTabBonusList(BonusProvider bonusProv, AuthProvider auth) {
    final list = bonusProv.filteredBonuses;

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Action Buttons Bar
          Row(
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.calculate, size: 16, color: Colors.white),
                label: const Text('Calculate Bonus'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _tabController.animateTo(1),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 16, color: Colors.white),
                label: const Text('+ Add Bonus'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _tabController.animateTo(2),
              ),
              const Spacer(),
              OutlinedButton.icon(
                icon: const Icon(Icons.print, size: 16, color: Color(0xFF334155)),
                label: const Text('Print Report', style: TextStyle(color: Color(0xFF334155))),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _printReport(bonusProv, auth),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Table
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.card_giftcard, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 10),
                        const Text(
                          'कोणतीही बोनस नोंद आढळली नाही.\nनवीन बोनस जोडण्यासाठी "Calculate Bonus" किंवा "+ Add Bonus" दाबा.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: MaterialStateProperty.all(const Color(0xFFF8FAFC)),
                        border: TableBorder.all(color: const Color(0xFFE2E8F0), width: 0.8),
                        columns: const [
                          DataColumn(label: Text('Sr. No.', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Member Name', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Bonus Type', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Basis Amount', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Rate', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Bonus Amount', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: list.asMap().entries.map((entry) {
                          final idx = entry.key + 1;
                          final b = entry.value;

                          return DataRow(
                            cells: [
                              DataCell(Text('$idx')),
                              DataCell(
                                Text(
                                  b.memberName ?? 'सभासद',
                                  style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                                ),
                              ),
                              DataCell(Text(b.bonusTypeLabelMr.split(' ')[0])),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('₹ ${b.basisAmount.toStringAsFixed(0)}'),
                                    const SizedBox(width: 4),
                                    const Tooltip(
                                      message: 'बचत खात्यातून स्वयंचलित प्राप्त (Auto-Fetched 🔒)',
                                      child: Icon(Icons.lock, size: 12, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ),
                              DataCell(Text('${b.bonusRate.toStringAsFixed(1)}%')),
                              DataCell(
                                Text(
                                  '₹ ${b.bonusAmount.toStringAsFixed(0)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                                ),
                              ),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: b.statusBgColor,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: b.statusColor.withOpacity(0.3)),
                                  ),
                                  child: Text(
                                    b.statusLabelEn,
                                    style: TextStyle(
                                      color: b.statusColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.visibility, size: 18, color: Color(0xFF3B82F6)),
                                      tooltip: 'पहा (View Details)',
                                      onPressed: () => _showBonusDetailsDialog(b),
                                    ),
                                    if (!b.isPaid)
                                      IconButton(
                                        icon: const Icon(Icons.delete, size: 18, color: Color(0xFFEF4444)),
                                        tooltip: 'डिलीट (Delete)',
                                        onPressed: () => _deleteBonus(b, bonusProv),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
          ),

          // Bottom Pagination Bar & Mini Report Summary
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Showing 1 to ${list.length} of ${list.length} entries',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                Text(
                  'एकूण बोनस: ₹ ${bonusProv.totalBonus.toStringAsFixed(0)}  |  भरले: ₹ ${bonusProv.paidBonus.toStringAsFixed(0)}  |  शिल्लक: ₹ ${bonusProv.pendingBonus.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: CALCULATION (BATCH CALCULATION)
  // ==========================================
  Widget _buildTabCalculation(
    BonusProvider bonusProv,
    MemberProvider memberProv,
    AuthProvider auth,
  ) {
    final batch = bonusProv.calculatedBatch;
    final activeMembers = memberProv.members.where((m) => m.status.toLowerCase() == 'active').toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'स्वयंचलित बोनस गणना (Batch Bonus Calculation)',
                      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'गटातील सर्व सक्रिय सभासदांच्या डेटाबेसमधील बचत नोंदी फेच करून बोनस त्वरित मोजा.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                icon: bonusProv.isCalculating
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.play_arrow, size: 16, color: Colors.white),
                label: const Text('गणना सुरू करा (Run Calculation)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: bonusProv.isCalculating
                    ? null
                    : () async {
                        final gid = auth.currentGroup?.id;
                        if (gid == null) return;
                        final rate = double.tryParse(_settingsPercentController.text) ?? 5.0;
                        await bonusProv.runBatchCalculation(
                          gid,
                          members: activeMembers,
                          bonusType: 'savings',
                          rate: rate,
                        );
                      },
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Preview Table
          Expanded(
            child: batch.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(24),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Text(
                      'बोनस गणना करण्यासाठी वरील "गणना सुरू करा" बटणावर क्लिक करा.\nसर्व सभासदांची मूळ बचत डेटाबेसमधून थेट मिळवून प्रिव्ह्यू दिसेल.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF64748B)),
                    ),
                  )
                : Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          child: DataTable(
                            headingRowColor: MaterialStateProperty.all(const Color(0xFFF1F5F9)),
                            columns: const [
                              DataColumn(label: Text('सभासद नाव (Member)')),
                              DataColumn(label: Text('एकूण बचत (Basic Amount 🔒)')),
                              DataColumn(label: Text('दर (Rate %)')),
                              DataColumn(label: Text('गणना केलेला बोनस (Bonus)')),
                            ],
                            rows: batch.map((b) {
                              return DataRow(cells: [
                                DataCell(Text(b.memberName ?? 'सभासद', style: const TextStyle(fontWeight: FontWeight.bold))),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('₹ ${b.basisAmount.toStringAsFixed(0)}'),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.lock, size: 12, color: Color(0xFF64748B)),
                                    ],
                                  ),
                                ),
                                DataCell(Text('${b.bonusRate.toStringAsFixed(1)}%')),
                                DataCell(
                                  Text(
                                    '₹ ${b.bonusAmount.toStringAsFixed(0)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                                  ),
                                ),
                              ]);
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton.icon(
                            icon: const Icon(Icons.check_circle, size: 18, color: Colors.white),
                            label: const Text('गणना सेव्ह करा (Confirm & Save Calculations)'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF16A34A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () async {
                              final gid = auth.currentGroup?.id;
                              if (gid == null) return;
                              final ok = await bonusProv.saveCalculatedBatch(gid);
                              if (ok && mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('बोनस गणना यशस्वीरीत्या जतन केली!')),
                                );
                                _tabController.animateTo(0);
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 3: BONUS ENTRY (+ ADD BONUS FORM)
  // ==========================================
  Widget _buildTabBonusEntry(
    BonusProvider bonusProv,
    MemberProvider memberProv,
    AuthProvider auth,
  ) {
    final activeMembers = memberProv.members.where((m) => m.status.toLowerCase() == 'active').toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'नवीन बोनस नोंद (+ Add Member Bonus)',
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
          ),
          const SizedBox(height: 4),
          const Text(
            'सभासद निवडल्यावर त्यांची बचत डेटाबेसमधून थेट प्राप्त होते (मॅन्युअल टाईप करण्याची गरज नाही).',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const Divider(height: 24),

          // Form fields
          Wrap(
            spacing: 16,
            runSpacing: 14,
            children: [
              // 1. Member Dropdown
              SizedBox(
                width: 280,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('सभासद निवडा (Member) *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<Member>(
                          value: _selectedMember,
                          hint: const Text('सभासद निवडा...', style: TextStyle(fontSize: 13)),
                          isExpanded: true,
                          items: activeMembers.map((m) {
                            return DropdownMenuItem<Member>(
                              value: m,
                              child: Text(m.fullName, style: const TextStyle(fontSize: 13)),
                            );
                          }).toList(),
                          onChanged: _onMemberSelected,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Bonus Type Dropdown
              SizedBox(
                width: 220,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('बोनस प्रकार (Bonus Type) *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _entryBonusType,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(value: 'savings', child: Text('बचत आधारित (Savings)')),
                            DropdownMenuItem(value: 'profit', child: Text('नफा आधारित (Profit)')),
                            DropdownMenuItem(value: 'attendance', child: Text('हजेरी आधारित (Attendance)')),
                            DropdownMenuItem(value: 'fixed', child: Text('निश्चित (Fixed)')),
                            DropdownMenuItem(value: 'custom', child: Text('सानुकूल (Custom)')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _entryBonusType = val;
                                _recalculateEntryBonus();
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 3. BASIC AMOUNT FIELD (READ-ONLY / AUTO-FETCHED 🔒)
              SizedBox(
                width: 260,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('मूलभूत बचत (Basic Amount) *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lock, size: 10, color: Color(0xFF16A34A)),
                              SizedBox(width: 2),
                              Text('Auto-Fetched', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9), // Disabled light grey
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        children: [
                          const Text('₹ ', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
                          Expanded(
                            child: _isFetchingBasisAmount
                                ? const Text('फेच करत आहे...', style: TextStyle(color: Color(0xFF64748B), fontSize: 13))
                                : Text(
                                    _entryBasisAmount.toStringAsFixed(0),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                                  ),
                          ),
                          const Icon(Icons.lock, size: 16, color: Color(0xFF64748B)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text('🔒 डेटाबेसमधून थेट प्राप्त (बदल करता येत नाही)', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                  ],
                ),
              ),

              // 4. Bonus Rate (%)
              SizedBox(
                width: 140,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('बोनस दर (Rate %) *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _entryRateController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        suffixText: '%',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onChanged: (_) => _recalculateEntryBonus(),
                    ),
                  ],
                ),
              ),

              // 5. Bonus Amount (Auto Calculated)
              SizedBox(
                width: 180,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('बोनस रक्कम (Bonus Amount)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _entryBonusAmountController,
                      readOnly: _entryBonusType != 'fixed' && _entryBonusType != 'custom',
                      decoration: InputDecoration(
                        prefixText: '₹ ',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        filled: _entryBonusType != 'fixed' && _entryBonusType != 'custom',
                        fillColor: const Color(0xFFF1F5F9),
                      ),
                    ),
                  ],
                ),
              ),

              // 6. Remarks
              SizedBox(
                width: 320,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('शेरा / टीप (Remarks)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _entryRemarksController,
                      decoration: InputDecoration(
                        hintText: 'उदा. दिवाळी लाभांश वाटप',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Save Button
          Row(
            children: [
              ElevatedButton.icon(
                icon: bonusProv.isSaving
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.save, size: 18, color: Colors.white),
                label: const Text('बोनस सेव्ह करा (Save Bonus)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: bonusProv.isSaving ? null : () => _saveSingleBonus(bonusProv, auth),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _saveSingleBonus(BonusProvider bonusProv, AuthProvider auth) async {
    if (_selectedMember == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('कृपया प्रथम सभासद निवडा!')),
      );
      return;
    }

    final gid = auth.currentGroup?.id;
    if (gid == null) return;

    final rate = double.tryParse(_entryRateController.text) ?? 5.0;
    final bonusAmt = double.tryParse(_entryBonusAmountController.text) ?? 0.0;

    final bonus = Bonus(
      id: '',
      groupId: gid,
      memberId: _selectedMember!.id,
      memberName: _selectedMember!.fullName,
      financialYear: bonusProv.financialYear,
      fromDate: bonusProv.fromDate,
      toDate: bonusProv.toDate,
      bonusType: _entryBonusType,
      basisAmount: _entryBasisAmount,
      bonusRate: rate,
      bonusAmount: bonusAmt,
      paidAmount: 0.0,
      status: 'calculated',
      remarks: _entryRemarksController.text.trim(),
    );

    final ok = await bonusProv.createBonus(bonus);
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('बोनस यशस्वीरीत्या नोंदवला गेला!')),
      );
      setState(() {
        _selectedMember = null;
        _entryBasisAmount = 0.0;
        _entryRemarksController.clear();
        _entryBonusAmountController.text = '0';
      });
      _tabController.animateTo(0);
    }
  }

  // ==========================================
  // TAB 4: APPROVAL TAB
  // ==========================================
  Widget _buildTabApproval(BonusProvider bonusProv, AuthProvider auth) {
    final pendingApproval = bonusProv.bonuses.where((b) => b.isCalculated || b.isDraft).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'बोनस मंजुरी (Bonus Approval)',
                      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'केवळ मंजूर झालेले बोनसच वाटप (Payment) करण्यासाठी उपलब्ध होतात.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.check, size: 16, color: Colors.white),
                label: const Text('मंजूर करा (Approve Selected)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: bonusProv.selectedBonusIds.isEmpty
                    ? null
                    : () async {
                        final gid = auth.currentGroup?.id;
                        if (gid == null) return;
                        final ok = await bonusProv.approveSelected(gid, auth.currentProfile?.fullName ?? 'Admin');
                        if (ok && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('निवडलेले बोनस यशस्वीरीत्या मंजूर केले!')),
                          );
                        }
                      },
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.close, size: 16, color: Colors.red),
                label: const Text('रद्द करा (Reject)', style: TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: bonusProv.selectedBonusIds.isEmpty
                    ? null
                    : () async {
                        final gid = auth.currentGroup?.id;
                        if (gid == null) return;
                        await bonusProv.rejectSelected(gid);
                      },
              ),
            ],
          ),
          const SizedBox(height: 12),

          Expanded(
            child: pendingApproval.isEmpty
                ? const Center(
                    child: Text(
                      'मंजुरीसाठी कोणताही बोनस प्रलंबित नाही.',
                      style: TextStyle(color: Color(0xFF64748B)),
                    ),
                  )
                : SingleChildScrollView(
                    child: DataTable(
                      columns: [
                        DataColumn(
                          label: Checkbox(
                            value: bonusProv.selectedBonusIds.length == pendingApproval.length && pendingApproval.isNotEmpty,
                            onChanged: (val) {
                              bonusProv.selectAllBonuses(pendingApproval.map((b) => b.id).toList());
                            },
                          ),
                        ),
                        const DataColumn(label: Text('सभासद नाव')),
                        const DataColumn(label: Text('मूलभूत बचत 🔒')),
                        const DataColumn(label: Text('दर')),
                        const DataColumn(label: Text('बोनस रक्कम')),
                        const DataColumn(label: Text('स्थिती')),
                      ],
                      rows: pendingApproval.map((b) {
                        final isSel = bonusProv.selectedBonusIds.contains(b.id);
                        return DataRow(
                          selected: isSel,
                          cells: [
                            DataCell(
                              Checkbox(
                                value: isSel,
                                onChanged: (_) => bonusProv.toggleSelectBonus(b.id),
                              ),
                            ),
                            DataCell(Text(b.memberName ?? 'सभासद', style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataCell(Text('₹ ${b.basisAmount.toStringAsFixed(0)}')),
                            DataCell(Text('${b.bonusRate.toStringAsFixed(1)}%')),
                            DataCell(Text('₹ ${b.bonusAmount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)))),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: b.statusBgColor,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(b.statusLabelEn, style: TextStyle(color: b.statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 5: PAYMENT TAB
  // ==========================================
  Widget _buildTabPayment(BonusProvider bonusProv, AuthProvider auth) {
    final readyForPayment = bonusProv.bonuses.where((b) => b.isApproved).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'बोनस वाटप व देयक (Bonus Disbursement & Payment)',
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
          ),
          const SizedBox(height: 2),
          const Text(
            'मंजूर झालेले बोनस रोकड (Cash) किंवा बँक खात्याद्वारे वाटप करा. (कॅशबुक / बँक खात्याशी थेट जोडलेले).',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),

          Expanded(
            child: readyForPayment.isEmpty
                ? const Center(
                    child: Text(
                      'सध्या वाटपासाठी कोणताही मंजूर बोनस उपलब्ध नाही.\nप्रथम "Approval" टॅबमधून बोनस मंजूर करा.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF64748B)),
                    ),
                  )
                : ListView.separated(
                    itemCount: readyForPayment.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final b = readyForPayment[i];
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              backgroundColor: Color(0xFFFEF3C7),
                              child: Icon(Icons.card_giftcard, color: Color(0xFFD97706)),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    b.memberName ?? 'सभासद',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  Text(
                                    'मूलभूत बचत: ₹ ${b.basisAmount.toStringAsFixed(0)} 🔒  |  दर: ${b.bonusRate.toStringAsFixed(1)}%',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '₹ ${b.bonusAmount.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.payment, size: 16, color: Colors.white),
                              label: const Text('वाटप करा (Pay)'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF97316), // Orange
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () => _showPaymentDialog(b, bonusProv, auth),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // Payment Dialog with Cash / Bank Integration
  void _showPaymentDialog(Bonus bonus, BonusProvider bonusProv, AuthProvider auth) {
    String paymentMode = 'cash';
    String? selectedBankId;
    final amountController = TextEditingController(text: bonus.bonusAmount.toStringAsFixed(0));
    final refController = TextEditingController();
    final remarksController = TextEditingController(text: 'बोनस वाटप - ${bonus.memberName}');
    String paymentDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final bankProv = Provider.of<BankProvider>(context, listen: false);
          final activeBanks = bankProv.banks.where((b) => b.status.toLowerCase() == 'active').toList();
          if (activeBanks.isNotEmpty && selectedBankId == null) {
            selectedBankId = activeBanks.first.id;
          }

          return AlertDialog(
            title: Text('बोनस वाटप (Pay Bonus) - ${bonus.memberName}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('देय रक्कम: ₹ ${bonus.bonusAmount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF16A34A))),
                  const SizedBox(height: 12),

                  // Mode
                  const Text('पेमेंट पद्धत (Payment Mode) *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Radio<String>(
                        value: 'cash',
                        groupValue: paymentMode,
                        onChanged: (val) => setDialogState(() => paymentMode = val!),
                      ),
                      const Text('रोकड (Cash)'),
                      const SizedBox(width: 14),
                      Radio<String>(
                        value: 'bank',
                        groupValue: paymentMode,
                        onChanged: (val) => setDialogState(() => paymentMode = val!),
                      ),
                      const Text('बँक (Bank)'),
                      const SizedBox(width: 14),
                      Radio<String>(
                        value: 'upi',
                        groupValue: paymentMode,
                        onChanged: (val) => setDialogState(() => paymentMode = val!),
                      ),
                      const Text('UPI'),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Bank dropdown
                  if (paymentMode == 'bank' || paymentMode == 'upi') ...[
                    const Text('बँक खाते निवडा (Select Bank Account) *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedBankId,
                      items: activeBanks.map((b) {
                        return DropdownMenuItem(
                          value: b.id,
                          child: Text('${b.bankName} (${b.maskedAccountNumber}) - शिल्लक: ₹ ${b.currentBalance.toStringAsFixed(0)}'),
                        );
                      }).toList(),
                      onChanged: (val) => setDialogState(() => selectedBankId = val),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: refController,
                      decoration: const InputDecoration(labelText: 'UTR / Transaction Ref No.'),
                    ),
                    const SizedBox(height: 10),
                  ],

                  TextField(
                    controller: remarksController,
                    decoration: const InputDecoration(labelText: 'शेरा (Remarks)'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('रद्द करा'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white),
                onPressed: () async {
                  final amt = double.tryParse(amountController.text) ?? bonus.bonusAmount;
                  final ok = await bonusProv.payBonus(
                    bonus,
                    paymentMode: paymentMode,
                    amount: amt,
                    bankAccountId: selectedBankId,
                    transactionRef: refController.text.trim(),
                    paymentDate: paymentDate,
                    remarks: remarksController.text.trim(),
                  );
                  if (ok && mounted) {
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('बोनस पेमेंट यशस्वी! कॅशबुक/बँक खात्यामध्ये नोंद झाली.')),
                    );
                    _tabController.animateTo(0);
                  }
                },
                child: const Text('पेमेंट पूर्ण करा'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ==========================================
  // TAB 6: SETTINGS TAB
  // ==========================================
  Widget _buildTabSettings(BonusProvider bonusProv, AuthProvider auth) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'बोनस नियम व सेटिंग्ज (Bonus Configuration)',
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
          ),
          const SizedBox(height: 4),
          const Text(
            'बचत टक्केवारी, किमान पात्रता आणि कमाल बोनस मर्यादा कॉन्फिगर करा.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const Divider(height: 24),

          Wrap(
            spacing: 20,
            runSpacing: 16,
            children: [
              SizedBox(
                width: 220,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('डिफॉल्ट बोनस टक्केवारी (%) *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _settingsPercentController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(suffixText: '%', border: OutlineInputBorder()),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 220,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('किमान बचत पात्रता (Min Eligibility)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _settingsMinEligController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(prefixText: '₹ ', border: OutlineInputBorder()),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 220,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('कमाल बोनस मर्यादा (Max Bonus Cap)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _settingsMaxBonusController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(prefixText: '₹ ', border: OutlineInputBorder()),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          ElevatedButton.icon(
            icon: const Icon(Icons.save, size: 18, color: Colors.white),
            label: const Text('सेटिंग्ज जतन करा (Save Settings)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A8A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final gid = auth.currentGroup?.id;
              if (gid == null) return;

              final pct = double.tryParse(_settingsPercentController.text) ?? 5.0;
              final minE = double.tryParse(_settingsMinEligController.text) ?? 0.0;
              final maxB = double.tryParse(_settingsMaxBonusController.text) ?? 5000.0;

              final current = bonusProv.settings ?? BonusSetting(id: '', groupId: gid);
              final updated = current.copyWith(
                bonusPercentage: pct,
                minEligibility: minE,
                maxBonus: maxB,
              );

              final ok = await bonusProv.saveSettings(updated);
              if (ok && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('सेटिंग्ज यशस्वीरीत्या जतन केल्या!')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  // --- RIGHT SIDE PANELS (Cards from image mockup) ---
  Widget _buildRightSidePanels(
    BonusProvider bonusProv,
    MemberProvider memberProv,
    AuthProvider auth,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. BONUS CALCULATION METHODS CARD
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.calculate_outlined, size: 18, color: Color(0xFF1E3A8A)),
                  const SizedBox(width: 8),
                  Text('Bonus Calculation Methods', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                ],
              ),
              const SizedBox(height: 10),
              ...[
                'Fixed Amount',
                'Percentage of Savings',
                'Percentage of Profit',
                'Based on Attendance',
                'Custom / Manual Bonus',
              ].map((m) {
                return InkWell(
                  onTap: () {
                    setState(() => _activeMethodRadio = m);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          _activeMethodRadio == m ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                          size: 16,
                          color: _activeMethodRadio == m ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 8),
                        Text(m, style: TextStyle(fontSize: 12, fontWeight: _activeMethodRadio == m ? FontWeight.w600 : FontWeight.normal, color: const Color(0xFF334155))),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 2. QUICK ACTIONS CARD
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.bolt, size: 18, color: Color(0xFFD97706)),
                  const SizedBox(width: 8),
                  Text('Quick Actions', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                ],
              ),
              const SizedBox(height: 10),
              _buildQuickActionBtn(
                label: 'Calculate Bonus',
                color: const Color(0xFF2563EB),
                icon: Icons.calculate,
                onTap: () => _tabController.animateTo(1),
              ),
              const SizedBox(height: 8),
              _buildQuickActionBtn(
                label: '+ Add Bonus',
                color: const Color(0xFF16A34A),
                icon: Icons.add,
                onTap: () => _tabController.animateTo(2),
              ),
              const SizedBox(height: 8),
              _buildQuickActionBtn(
                label: 'Approve Bonus',
                color: const Color(0xFF8B5CF6),
                icon: Icons.check_circle_outline,
                onTap: () => _tabController.animateTo(3),
              ),
              const SizedBox(height: 8),
              _buildQuickActionBtn(
                label: 'Pay Bonus',
                color: const Color(0xFFF97316),
                icon: Icons.payments_outlined,
                onTap: () => _tabController.animateTo(4),
              ),
              const SizedBox(height: 8),
              _buildQuickActionBtn(
                label: 'View Bonus Report',
                color: const Color(0xFF334155),
                icon: Icons.description_outlined,
                isOutlined: true,
                onTap: () => _printReport(bonusProv, auth),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 3. BONUS SETTINGS SUMMARY CARD
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.settings, size: 18, color: Color(0xFF475569)),
                      const SizedBox(width: 8),
                      Text('Bonus Settings', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                    ],
                  ),
                  InkWell(
                    onTap: () => _tabController.animateTo(5),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0E7FF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('Manage', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF3B82F6))),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildSettingItem(
                title: 'Savings Bonus',
                subtitle: 'Savings × ${_settingsPercentController.text}%',
                limits: 'Min: ₹ ${_settingsMinEligController.text} | Max: ₹ ${_settingsMaxBonusController.text}',
                icon: Icons.savings,
                color: const Color(0xFF16A34A),
              ),
              const SizedBox(height: 8),
              _buildSettingItem(
                title: 'Profit Bonus',
                subtitle: 'Profit × 4%',
                limits: 'Min: ₹ 5,000 | Max: ₹ 3,000',
                icon: Icons.trending_up,
                color: const Color(0xFF8B5CF6),
              ),
              const SizedBox(height: 8),
              _buildSettingItem(
                title: 'Attendance Bonus',
                subtitle: 'Attendance × 3%',
                limits: 'Min: 80% | Max: ₹ 2,000',
                icon: Icons.groups,
                color: const Color(0xFF3B82F6),
              ),
              const SizedBox(height: 8),
              _buildSettingItem(
                title: 'Custom Bonus',
                subtitle: 'Manual Entry',
                limits: 'Min: ₹ 0 | Max: ₹ 10,000',
                icon: Icons.tune,
                color: const Color(0xFFF59E0B),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionBtn({
    required String label,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
    bool isOutlined = false,
  }) {
    if (isOutlined) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          icon: Icon(icon, size: 16, color: color),
          label: Text(label, style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w600)),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 10),
            side: BorderSide(color: color.withOpacity(0.5)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: onTap,
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: Icon(icon, size: 16, color: Colors.white),
        label: Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: onTap,
      ),
    );
  }

  Widget _buildSettingItem({
    required String title,
    required String subtitle,
    required String limits,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
            child: Icon(icon, color: Colors.white, size: 14),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                    Text(subtitle, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10.5, color: color)),
                  ],
                ),
                Text(limits, style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showBonusDetailsDialog(Bonus b) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('लाभांश तपशील - ${b.memberName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('आर्थिक वर्ष: ${b.financialYear}'),
            Text('कालावधी: ${b.fromDate} ते ${b.toDate}'),
            Text('बोनस प्रकार: ${b.bonusTypeLabelMr}'),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('मूलभूत बचत (Basic Amount): ₹ ${b.basisAmount.toStringAsFixed(0)}'),
                const SizedBox(width: 4),
                const Icon(Icons.lock, size: 14, color: Color(0xFF16A34A)),
              ],
            ),
            Text('बोनस दर: ${b.bonusRate.toStringAsFixed(1)}%'),
            Text('एकूण बोनस: ₹ ${b.bonusAmount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('जमा / भरले: ₹ ${b.paidAmount.toStringAsFixed(0)}'),
            Text('शिल्लक: ₹ ${b.balanceAmount.toStringAsFixed(0)}'),
            Text('सद्यस्थिती: ${b.statusLabelMr}'),
            if (b.paymentMode != null) Text('पेमेंट पद्धत: ${b.paymentMode}'),
            if (b.remarks != null && b.remarks!.isNotEmpty) Text('शेरा: ${b.remarks}'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('बंद करा')),
        ],
      ),
    );
  }

  void _deleteBonus(Bonus b, BonusProvider bonusProv) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('बोनस डिलीट करा?'),
        content: Text('तुम्हाला खरोखर ${b.memberName} यांचा ₹ ${b.bonusAmount.toStringAsFixed(0)} चा बोनस डिलीट करायचा आहे का?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('नाही')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await bonusProv.deleteBonus(b.id, b.groupId);
            },
            child: const Text('होय, डिलीट करा'),
          ),
        ],
      ),
    );
  }

  Future<void> _printReport(BonusProvider bonusProv, AuthProvider auth) async {
    final list = bonusProv.filteredBonuses;
    final groupName = auth.currentGroup?.groupName ?? 'सखी महिला बचत गट';

    await PdfService.printBonusReport(
      bonuses: list,
      groupName: groupName,
      financialYear: bonusProv.financialYear,
      fromDate: bonusProv.fromDate,
      toDate: bonusProv.toDate,
      bonusType: bonusProv.selectedBonusType,
    );
  }
}
