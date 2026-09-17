import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_strings.dart';
import '../../models/bank_account.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bank_provider.dart';
import 'widgets/add_bank_transaction_dialog.dart';
import 'widgets/add_edit_bank_dialog.dart';
import 'widgets/bank_details_dialog.dart';

class BankManagementScreen extends StatefulWidget {
  const BankManagementScreen({super.key});

  @override
  State<BankManagementScreen> createState() => _BankManagementScreenState();
}

class _BankManagementScreenState extends State<BankManagementScreen> {
  DateTime? _filterFromDate;
  DateTime? _filterToDate;
  String? _filterBankId; // null = all
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.currentGroup != null) {
        Provider.of<BankProvider>(context, listen: false).loadData(auth.currentGroup!.id);
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isFrom) async {
    final now = DateTime.now();
    final initial = (isFrom ? _filterFromDate : _filterToDate) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _filterFromDate = picked;
        } else {
          _filterToDate = picked;
        }
      });
    }
  }

  void _applyFilter() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final bankProv = Provider.of<BankProvider>(context, listen: false);
    if (auth.currentGroup == null) return;

    BankAccount? selected;
    if (_filterBankId != null && _filterBankId != 'all') {
      try {
        selected = bankProv.banks.firstWhere((b) => b.id == _filterBankId);
      } catch (_) {}
    }

    bankProv.applyAllFilters(
      groupId: auth.currentGroup!.id,
      selectedBank: selected,
      fromDate: _filterFromDate,
      toDate: _filterToDate,
    );
  }

  void _resetFilter() {
    setState(() {
      _filterFromDate = null;
      _filterToDate = null;
      _filterBankId = null;
      _searchCtrl.clear();
    });
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.currentGroup != null) {
      Provider.of<BankProvider>(context, listen: false).resetFilters(auth.currentGroup!.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final bankProv = Provider.of<BankProvider>(context);
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: bankProv.isLoading && bankProv.banks.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                if (auth.currentGroup != null) {
                  await bankProv.loadData(auth.currentGroup!.id);
                }
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 24 : 16,
                  vertical: 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Header Section
                    _buildHeader(isDesktop, bankProv, auth),
                    const SizedBox(height: 18),

                    // Filter Bar
                    _buildFilterBar(bankProv, isDesktop),
                    const SizedBox(height: 20),

                    // 4 Overview Summary Cards
                    _buildSummaryCards(bankProv, isDesktop, isMobile),
                    const SizedBox(height: 24),

                    // Bank Accounts Overview Section
                    _buildBankAccountsSection(bankProv, auth, isDesktop),
                    const SizedBox(height: 24),

                    // Transaction History Section
                    _buildTransactionHistorySection(bankProv, auth, isDesktop),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeader(bool isDesktop, BankProvider bankProv, AuthProvider auth) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 600;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (Navigator.canPop(context)) ...[
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
                    tooltip: 'मागे जा (Back to Dashboard)',
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 6),
                ],
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.account_balance, color: AppColors.primary, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.tr('बँक व्यवस्थापन', 'Bank Management'),
                        style: GoogleFonts.poppins(
                          fontSize: isNarrow ? 20 : 24,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        AppStrings.tr(
                          'बँक खाती, शिल्लक व जमा-खर्च व्यवहार व्यवस्थापन',
                          'Manage bank accounts, deposits, withdrawals and balances',
                        ),
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isNarrow && auth.canWrite) ...[
                  OutlinedButton.icon(
                    onPressed: () => _openAddTransactionDialog(bankProv),
                    icon: const Icon(Icons.sync_alt, size: 18),
                    label: Text(AppStrings.tr('+ व्यवहार नोंदवा', '+ Transaction')),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => _openAddBankDialog(),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(AppStrings.tr('+ बँक जोडा', '+ Add Bank')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ],
            ),
            if (isNarrow && auth.canWrite) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openAddTransactionDialog(bankProv),
                      icon: const Icon(Icons.sync_alt, size: 16),
                      label: Text(AppStrings.tr('+ व्यवहार नोंदवा', '+ Transaction')),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _openAddBankDialog(),
                      icon: const Icon(Icons.add, size: 16),
                      label: Text(AppStrings.tr('+ बँक जोडा', '+ Add Bank')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildFilterBar(BankProvider bankProv, bool isDesktop) {
    final activeBanks = bankProv.activeBanks;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
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
            children: [
              const Icon(Icons.filter_list, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                AppStrings.tr('फिल्टर (Filters)', 'Filters'),
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary),
              ),
              const Spacer(),
              if (_filterFromDate != null || _filterToDate != null || _filterBankId != null)
                TextButton.icon(
                  onPressed: _resetFilter,
                  icon: const Icon(Icons.refresh, size: 14),
                  label: Text(AppStrings.tr('रीसेट (Reset)', 'Reset'), style: const TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 720) {
                return Row(
                  children: [
                    // From Date
                    Expanded(
                      flex: 3,
                      child: _buildDatePickerField(
                        label: AppStrings.tr('पासून तारीख (From Date)', 'From Date'),
                        date: _filterFromDate,
                        onTap: () => _pickDate(true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // To Date
                    Expanded(
                      flex: 3,
                      child: _buildDatePickerField(
                        label: AppStrings.tr('पर्यंत तारीख (To Date)', 'To Date'),
                        date: _filterToDate,
                        onTap: () => _pickDate(false),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Select Bank Dropdown
                    Expanded(
                      flex: 4,
                      child: _buildBankDropdown(activeBanks),
                    ),
                    const SizedBox(width: 12),
                    // Apply Filter Button
                    ElevatedButton.icon(
                      onPressed: _applyFilter,
                      icon: const Icon(Icons.search, size: 16),
                      label: Text(AppStrings.tr('फिल्टर लावा', 'Apply Filter')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                );
              } else {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildDatePickerField(
                            label: AppStrings.tr('पासून', 'From'),
                            date: _filterFromDate,
                            onTap: () => _pickDate(true),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildDatePickerField(
                            label: AppStrings.tr('पर्यंत', 'To'),
                            date: _filterToDate,
                            onTap: () => _pickDate(false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildBankDropdown(activeBanks),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _applyFilter,
                        icon: const Icon(Icons.search, size: 16),
                        label: Text(AppStrings.tr('फिल्टर लावा (Apply Filter)', 'Apply Filter')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDatePickerField({required String label, required DateTime? date, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textSecondary)),
                  Text(
                    date != null
                        ? "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}"
                        : AppStrings.tr('तारीख निवडा', 'Select Date'),
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_drop_down, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildBankDropdown(List<BankAccount> activeBanks) {
    return DropdownButtonFormField<String>(
      value: _filterBankId ?? 'all',
      isExpanded: true,
      decoration: InputDecoration(
        labelText: AppStrings.tr('बँक खाते निवडा (Select Bank)', 'Select Bank'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      items: [
        DropdownMenuItem(
          value: 'all',
          child: Text(
            AppStrings.tr('सर्व बँक खाती (All Banks)', 'All Banks'),
            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
        ...activeBanks.map((b) {
          return DropdownMenuItem(
            value: b.id,
            child: Text(
              '${b.bankName} (${b.maskedAccountNumber})',
              style: GoogleFonts.poppins(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          );
        }),
      ],
      onChanged: (v) {
        setState(() => _filterBankId = v);
      },
    );
  }

  Widget _buildSummaryCards(BankProvider bankProv, bool isDesktop, bool isMobile) {
    final m = bankProv.metrics;

    final cards = [
      _SummaryCard(
        title: AppStrings.tr('चालू बँक शिल्लक', 'Current Bank Balance'),
        subtitle: AppStrings.tr('सध्याची एकूण शिल्लक (All-Time)', 'Unrestricted Balance'),
        amount: m.currentBalance,
        icon: Icons.account_balance_wallet_rounded,
        gradientColors: const [Color(0xFF2563EB), Color(0xFF1D4ED8)],
        iconBgColor: Colors.white.withOpacity(0.2),
        isCurrency: true,
      ),
      _SummaryCard(
        title: AppStrings.tr('कालावधीतील जमा', 'Period Deposit'),
        subtitle: AppStrings.tr('निवडलेल्या कालावधीत जमा रक्कम', 'Total deposited in period'),
        amount: m.periodDeposit,
        icon: Icons.arrow_downward_rounded,
        gradientColors: const [Color(0xFF10B981), Color(0xFF059669)],
        iconBgColor: Colors.white.withOpacity(0.2),
        isCurrency: true,
      ),
      _SummaryCard(
        title: AppStrings.tr('कालावधीतील नावे/खर्च', 'Period Withdraw'),
        subtitle: AppStrings.tr('निवडलेल्या कालावधीत काढलेली रक्कम', 'Total withdrawn in period'),
        amount: m.periodWithdraw,
        icon: Icons.arrow_upward_rounded,
        gradientColors: const [Color(0xFFEF4444), Color(0xFFDC2626)],
        iconBgColor: Colors.white.withOpacity(0.2),
        isCurrency: true,
      ),
      _SummaryCard(
        title: AppStrings.tr('निव्वळ बदल (Net Change)', 'Net Change'),
        subtitle: AppStrings.tr('जमा वजा नावे फरक', 'Period Deposit - Withdraw'),
        amount: m.netChange,
        icon: Icons.swap_vert_rounded,
        gradientColors: m.netChange >= 0
            ? const [Color(0xFF8B5CF6), Color(0xFF7C3AED)]
            : const [Color(0xFFF59E0B), Color(0xFFD97706)],
        iconBgColor: Colors.white.withOpacity(0.2),
        isCurrency: true,
      ),
    ];

    if (isDesktop) {
      return Row(
        children: cards
            .map((c) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: c,
                  ),
                ))
            .toList(),
      );
    } else if (!isMobile) {
      // Tablet: 2x2 grid
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 12),
              Expanded(child: cards[1]),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: cards[2]),
              const SizedBox(width: 12),
              Expanded(child: cards[3]),
            ],
          ),
        ],
      );
    } else {
      // Mobile: 2x2 grid compact
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 10),
              Expanded(child: cards[1]),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: cards[2]),
              const SizedBox(width: 10),
              Expanded(child: cards[3]),
            ],
          ),
        ],
      );
    }
  }

  Widget _buildBankAccountsSection(BankProvider bankProv, AuthProvider auth, bool isDesktop) {
    final banks = bankProv.banks;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                const Icon(Icons.account_balance_outlined, color: AppColors.primary, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    AppStrings.tr('बँक खाती आढावा (Bank Accounts Overview)', 'Bank Accounts Overview'),
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0F172A),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'एकूण: ${banks.length} | सक्रिय: ${bankProv.activeBanks.length}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          if (banks.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.account_balance_outlined, size: 48, color: Colors.grey),
                    const SizedBox(height: 12),
                    Text(
                      AppStrings.tr('कोणतेही बँक खाते जोडलेले नाही', 'No bank accounts added yet'),
                      style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600),
                    ),
                    if (auth.canAdd) ...[
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () => _openAddBankDialog(),
                        icon: const Icon(Icons.add, size: 16),
                        label: Text(AppStrings.tr('पहिले बँक खाते जोडा', 'Add First Bank Account')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: isDesktop ? 850 : 700),
                child: DataTable(
                  headingRowColor: MaterialStateProperty.all(Colors.grey.shade50),
                  dataRowMinHeight: 52,
                  dataRowMaxHeight: 64,
                  columnSpacing: 24,
                  columns: [
                    DataColumn(label: Text(AppStrings.tr('बँकेचे नाव', 'Bank Name'), style: _tableHeaderStyle)),
                    DataColumn(label: Text(AppStrings.tr('खाते क्रमांक', 'Account No'), style: _tableHeaderStyle)),
                    DataColumn(label: Text(AppStrings.tr('प्रकार', 'Type'), style: _tableHeaderStyle)),
                    DataColumn(label: Text(AppStrings.tr('चालू शिल्लक', 'Current Balance'), style: _tableHeaderStyle)),
                    DataColumn(label: Text(AppStrings.tr('स्थिती', 'Status'), style: _tableHeaderStyle)),
                    DataColumn(label: Text(AppStrings.tr('कृती', 'Actions'), style: _tableHeaderStyle)),
                  ],
                  rows: banks.map((b) {
                    return DataRow(
                      cells: [
                        // Bank Name + Branch
                        DataCell(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                b.bankName,
                                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                              if (b.branch.isNotEmpty)
                                Text(
                                  b.branch,
                                  style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
                                ),
                            ],
                          ),
                        ),
                        // Masked Account Number
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              b.maskedAccountNumber,
                              style: GoogleFonts.sourceCodePro(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ),
                        ),
                        // Type (Savings / Current)
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: b.accountType.toLowerCase() == 'savings'
                                  ? Colors.blue.shade50
                                  : Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              b.accountType.toLowerCase() == 'savings'
                                  ? AppStrings.tr('बचत', 'Savings')
                                  : AppStrings.tr('चालू', 'Current'),
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: b.accountType.toLowerCase() == 'savings'
                                    ? Colors.blue.shade800
                                    : Colors.orange.shade800,
                              ),
                            ),
                          ),
                        ),
                        // Current Balance
                        DataCell(
                          Text(
                            '₹ ${b.currentBalance.toStringAsFixed(2)}',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: b.currentBalance >= 0 ? AppColors.success : AppColors.danger,
                            ),
                          ),
                        ),
                        // Status Badge
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: b.isActive ? AppColors.success.withOpacity(0.1) : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  b.isActive ? Icons.check_circle : Icons.cancel,
                                  size: 12,
                                  color: b.isActive ? AppColors.success : Colors.grey.shade600,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  b.isActive
                                      ? AppStrings.tr('सक्रिय', 'Active')
                                      : AppStrings.tr('निष्क्रिय', 'Inactive'),
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: b.isActive ? AppColors.success : Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Actions
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.visibility, size: 18, color: AppColors.primary),
                                tooltip: AppStrings.tr('तपशील पहा', 'View Details'),
                                onPressed: () => _openViewBankDialog(b),
                              ),
                              if (auth.canWrite) ...[
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 18, color: Colors.indigo),
                                  tooltip: AppStrings.tr('संपादन करा', 'Edit Bank'),
                                  onPressed: () => _openAddBankDialog(bank: b),
                                ),
                                IconButton(
                                  icon: Icon(
                                    b.isActive ? Icons.toggle_on : Icons.toggle_off,
                                    size: 22,
                                    color: b.isActive ? AppColors.success : Colors.grey,
                                  ),
                                  tooltip: b.isActive
                                      ? AppStrings.tr('निष्क्रिय करा', 'Deactivate')
                                      : AppStrings.tr('सक्रिय करा', 'Activate'),
                                  onPressed: () => _toggleStatus(b, bankProv, auth),
                                ),
                              ],
                            ],
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

  Widget _buildTransactionHistorySection(BankProvider bankProv, AuthProvider auth, bool isDesktop) {
    final transactions = bankProv.transactions;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header + Controls
          Padding(
            padding: const EdgeInsets.all(18),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 600;
                return Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.receipt_long, color: AppColors.primary, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            AppStrings.tr('बँक व्यवहार नोंद वही (Transaction History)', 'Transaction History'),
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF0F172A),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${transactions.length} व्यवहार',
                            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (isWide)
                      Row(
                        children: [
                          // Search Box
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: _searchCtrl,
                              decoration: InputDecoration(
                                hintText: AppStrings.tr('संदर्भ क्र. किंवा कारणाने शोधा...', 'Search ref, purpose...'),
                                prefixIcon: const Icon(Icons.search, size: 18),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                isDense: true,
                              ),
                              onChanged: (v) {
                                if (auth.currentGroup != null) {
                                  bankProv.setSearchQuery(v, auth.currentGroup!.id);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Type Segmented Filter
                          _buildTypeFilterTabs(bankProv, auth),
                        ],
                      )
                    else ...[
                      TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          hintText: AppStrings.tr('संदर्भ क्र. किंवा कारणाने शोधा...', 'Search ref, purpose...'),
                          prefixIcon: const Icon(Icons.search, size: 18),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          isDense: true,
                        ),
                        onChanged: (v) {
                          if (auth.currentGroup != null) {
                            bankProv.setSearchQuery(v, auth.currentGroup!.id);
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      _buildTypeFilterTabs(bankProv, auth),
                    ],
                  ],
                );
              },
            ),
          ),
          const Divider(height: 1),

          // Transactions Table
          if (transactions.isEmpty)
            Padding(
              padding: const EdgeInsets.all(36),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.receipt_long_outlined, size: 44, color: Colors.grey),
                    const SizedBox(height: 10),
                    Text(
                      AppStrings.tr('या फिल्टरनुसार कोणतेही व्यवहार सापडले नाहीत', 'No transactions found'),
                      style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: isDesktop ? 900 : 750),
                child: DataTable(
                  headingRowColor: MaterialStateProperty.all(Colors.grey.shade50),
                  dataRowMinHeight: 48,
                  dataRowMaxHeight: 58,
                  columnSpacing: 20,
                  columns: [
                    DataColumn(label: Text(AppStrings.tr('तारीख', 'Date'), style: _tableHeaderStyle)),
                    DataColumn(label: Text(AppStrings.tr('प्रकार', 'Type'), style: _tableHeaderStyle)),
                    DataColumn(label: Text(AppStrings.tr('रक्कम', 'Amount'), style: _tableHeaderStyle)),
                    DataColumn(label: Text(AppStrings.tr('उद्देश / कारण', 'Purpose'), style: _tableHeaderStyle)),
                    DataColumn(label: Text(AppStrings.tr('संदर्भ क्र. / Cheque', 'Reference'), style: _tableHeaderStyle)),
                    DataColumn(label: Text(AppStrings.tr('शिल्लक', 'Balance After'), style: _tableHeaderStyle)),
                    DataColumn(label: Text(AppStrings.tr('नोंद केली', 'Recorded By'), style: _tableHeaderStyle)),
                  ],
                  rows: transactions.map((t) {
                    final isDep = t.isDeposit;
                    return DataRow(
                      cells: [
                        // Date
                        DataCell(
                          Text(
                            t.transactionDate,
                            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ),
                        // Type Badge
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isDep
                                  ? AppColors.success.withOpacity(0.12)
                                  : AppColors.danger.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isDep ? Icons.arrow_downward : Icons.arrow_upward,
                                  size: 12,
                                  color: isDep ? AppColors.success : AppColors.danger,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isDep
                                      ? AppStrings.tr('+ जमा', '+ Deposit')
                                      : AppStrings.tr('- नावे', '- Withdraw'),
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isDep ? AppColors.success : AppColors.danger,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Amount
                        DataCell(
                          Text(
                            '₹ ${t.amount.toStringAsFixed(2)}',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: isDep ? AppColors.success : AppColors.danger,
                            ),
                          ),
                        ),
                        // Purpose / Remarks
                        DataCell(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                t.purpose ?? (isDep ? 'बँक जमा' : 'बँक नावे'),
                                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                              if (t.remarks != null && t.remarks!.isNotEmpty)
                                Text(
                                  t.remarks!,
                                  style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey.shade600),
                                ),
                            ],
                          ),
                        ),
                        // Reference / Cheque
                        DataCell(
                          Text(
                            t.transactionNumber ?? t.depositSlipOrChequeNo ?? '-',
                            style: GoogleFonts.sourceCodePro(fontSize: 11, color: Colors.grey.shade800),
                          ),
                        ),
                        // Balance After
                        DataCell(
                          Text(
                            t.balanceAfter > 0 ? '₹ ${t.balanceAfter.toStringAsFixed(2)}' : '-',
                            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ),
                        // Performed By
                        DataCell(
                          Text(
                            t.performedBy ?? '-',
                            style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
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

  Widget _buildTypeFilterTabs(BankProvider bankProv, AuthProvider auth) {
    final current = bankProv.typeFilter;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildFilterTab(
            label: AppStrings.tr('सर्व (All)', 'All'),
            isSelected: current == 'all',
            onTap: () {
              if (auth.currentGroup != null) bankProv.setTypeFilter('all', auth.currentGroup!.id);
            },
          ),
          const SizedBox(width: 6),
          _buildFilterTab(
            label: AppStrings.tr('जमा (Deposit)', 'Deposit'),
            isSelected: current == 'deposit',
            color: AppColors.success,
            onTap: () {
              if (auth.currentGroup != null) bankProv.setTypeFilter('deposit', auth.currentGroup!.id);
            },
          ),
          const SizedBox(width: 6),
          _buildFilterTab(
            label: AppStrings.tr('नावे (Withdraw)', 'Withdraw'),
            isSelected: current == 'withdraw',
            color: AppColors.danger,
            onTap: () {
              if (auth.currentGroup != null) bankProv.setTypeFilter('withdraw', auth.currentGroup!.id);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab({
    required String label,
    required bool isSelected,
    Color color = AppColors.primary,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? color : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  TextStyle get _tableHeaderStyle => GoogleFonts.poppins(
        fontWeight: FontWeight.w600,
        fontSize: 12,
        color: const Color(0xFF475569),
      );

  void _openAddBankDialog({BankAccount? bank}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddEditBankDialog(bank: bank),
    );
  }

  void _openViewBankDialog(BankAccount bank) {
    showDialog(
      context: context,
      builder: (_) => BankDetailsDialog(bank: bank),
    );
  }

  void _openAddTransactionDialog(BankProvider bankProv) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AddBankTransactionDialog(),
    );
  }

  Future<void> _toggleStatus(BankAccount b, BankProvider prov, AuthProvider auth) async {
    final newStatus = b.isActive ? 'inactive' : 'active';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(AppStrings.tr('खाते स्थिती बदला?', 'Change Account Status?')),
        content: Text(
          b.isActive
              ? AppStrings.tr(
                  '${b.bankName} हे खाते निष्क्रिय करायचे आहे का? (नवीन व्यवहारांसाठी दिसणार नाही)',
                  'Deactivate ${b.bankName}? (Will not appear for new transactions)',
                )
              : AppStrings.tr(
                  '${b.bankName} हे खाते पुन्हा सक्रिय करायचे आहे का?',
                  'Reactivate ${b.bankName}?',
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(AppStrings.tr('नाही', 'No'))),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text(AppStrings.tr('होय', 'Yes'))),
        ],
      ),
    );

    if (confirm == true && auth.currentGroup != null) {
      await prov.toggleBankStatus(b.id, newStatus, auth.currentGroup!.id);
    }
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final double amount;
  final IconData icon;
  final List<Color> gradientColors;
  final Color iconBgColor;
  final bool isCurrency;

  const _SummaryCard({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.icon,
    required this.gradientColors,
    required this.iconBgColor,
    this.isCurrency = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withOpacity(0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.92),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              isCurrency ? '₹ ${amount.toStringAsFixed(2)}' : amount.toStringAsFixed(0),
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: Colors.white.withOpacity(0.75),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
