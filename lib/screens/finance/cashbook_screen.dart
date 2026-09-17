import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_strings.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../services/supabase_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';

class CashTransactionItem {
  final String id;
  final String date;
  final String type; // 'cash_in' or 'cash_out'
  final String category; // 'मासिक बचत', 'कर्ज हप्ता', 'गट उत्पन्न', 'गट खर्च', 'बँक व्यवहार', 'रोख व्हाउचर'
  final String title;
  final String? subtitle;
  final String? receiptNo;
  final double amount;
  final String? paymentMode;
  final String? enteredBy;

  CashTransactionItem({
    required this.id,
    required this.date,
    required this.type,
    required this.category,
    required this.title,
    this.subtitle,
    this.receiptNo,
    required this.amount,
    this.paymentMode,
    this.enteredBy,
  });

  bool get isIncome => type == 'cash_in';
}

class CashBookScreen extends StatefulWidget {
  const CashBookScreen({super.key});

  @override
  State<CashBookScreen> createState() => _CashBookScreenState();
}

class _CashBookScreenState extends State<CashBookScreen> {
  final SupabaseService _service = SupabaseService();
  bool _isLoading = false;
  List<CashTransactionItem> _allTransactions = [];

  // Filters
  DateTime? _fromDate;
  DateTime? _toDate;
  String _activePeriodPreset = 'all'; // 'all', 'this_month', 'last_month', 'today', 'custom'
  String _typeFilter = 'all'; // 'all', 'cash_in', 'cash_out'
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCashBook();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCashBook() async {
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.currentGroup != null) {
      final gId = auth.currentGroup!.id;
      final List<CashTransactionItem> items = [];
      try {
        // 1. Fetch members map for name resolution
        final Map<String, String> memberMap = {};
        try {
          final mRes = await _service.client.from('members').select('id, full_name').eq('group_id', gId);
          for (var m in (mRes as List)) {
            final id = m['id']?.toString() ?? '';
            final name = m['full_name']?.toString() ?? '';
            if (id.isNotEmpty && name.isNotEmpty) {
              memberMap[id] = name;
            }
          }
        } catch (_) {}

        // 2. Fetch cash_book entries (vouchers + bank contra)
        try {
          final cbRes = await _service.client.from('cash_book').select().eq('group_id', gId);
          for (var r in (cbRes as List)) {
            final amt = (r['amount'] as num?)?.toDouble() ?? 0.0;
            final t = (r['type'] ?? r['transaction_type'])?.toString().toLowerCase() ?? '';
            final isAdd = t == 'cash_in' || t == 'receipt' || t == 'income' || t.contains('जमा');
            final date = (r['entry_date'] ?? r['transaction_date'] ?? '').toString();
            final desc = (r['description'] ?? r['particulars'] ?? 'रोख व्हाउचर').toString();
            final refMod = r['reference_module']?.toString() ?? '';
            final isBankContra = refMod == 'bank' || desc.contains('बँक');
            items.add(CashTransactionItem(
              id: r['id']?.toString() ?? UniqueKey().toString(),
              date: date.isNotEmpty ? date : DateTime.now().toIso8601String().split('T').first,
              type: isAdd ? 'cash_in' : 'cash_out',
              category: isBankContra ? 'बँक व्यवहार' : 'रोख व्हाउचर',
              title: desc,
              subtitle: 'नोंद: ${r['entered_by'] ?? "व्यवस्थापक"}',
              amount: amt,
              paymentMode: 'हातातील रोख (Cash in Hand)',
              enteredBy: r['entered_by']?.toString(),
            ));
          }
        } catch (_) {}

        // 3. Fetch Savings where mode is cash
        try {
          final savRes = await _service.client.from('savings').select().eq('group_id', gId);
          for (var s in (savRes as List)) {
            final mode = (s['payment_mode'] ?? 'cash').toString().toLowerCase();
            if (mode == 'cash' || mode.isEmpty || mode == 'रोख') {
              final amt = (s['amount'] as num?)?.toDouble() ?? 0.0;
              final mId = s['member_id']?.toString() ?? '';
              final mName = memberMap[mId] ?? 'सभासद';
              final date = (s['savings_date'] ?? s['saving_date'] ?? '').toString();
              items.add(CashTransactionItem(
                id: s['id']?.toString() ?? UniqueKey().toString(),
                date: date.isNotEmpty ? date : DateTime.now().toIso8601String().split('T').first,
                type: 'cash_in',
                category: 'मासिक बचत',
                title: '$mName - मासिक बचत जमा',
                subtitle: (s['remarks'] ?? s['notes'])?.toString(),
                receiptNo: (s['receipt_number'] ?? s['receipt_no'])?.toString(),
                amount: amt,
                paymentMode: 'हातातील रोख (Cash)',
              ));
            }
          }
        } catch (_) {}

        // 4. Fetch Loan EMIs where mode is cash
        try {
          final emiRes = await _service.client.from('loan_emis').select().eq('group_id', gId);
          for (var e in (emiRes as List)) {
            final mode = (e['payment_mode'] ?? 'cash').toString().toLowerCase();
            if (mode == 'cash' || mode.isEmpty || mode == 'रोख') {
              final amt = (e['paid_amount'] ?? (e['principal'] ?? 0) + (e['interest'] ?? 0) + (e['late_fee'] ?? 0) as num?)?.toDouble() ?? 0.0;
              final emiNum = (e['emi_number'] ?? e['installment_number'])?.toString() ?? '';
              final date = (e['payment_date'] ?? e['due_date'] ?? '').toString();
              items.add(CashTransactionItem(
                id: e['id']?.toString() ?? UniqueKey().toString(),
                date: date.isNotEmpty ? date : DateTime.now().toIso8601String().split('T').first,
                type: 'cash_in',
                category: 'कर्ज हप्ता वसुली',
                title: 'कर्ज हप्ता #$emiNum भरणा',
                subtitle: (e['remarks'] ?? e['notes'])?.toString(),
                receiptNo: (e['receipt_number'] ?? e['receipt_no'])?.toString(),
                amount: amt,
                paymentMode: 'हातातील रोख (Cash)',
              ));
            }
          }
        } catch (_) {}

        // 5. Fetch Incomes where mode is cash
        try {
          final incRes = await _service.client.from('incomes').select().eq('group_id', gId);
          for (var i in (incRes as List)) {
            final mode = (i['payment_mode'] ?? 'cash').toString().toLowerCase();
            if (mode == 'cash' || mode.isEmpty || mode == 'रोख') {
              final amt = (i['amount'] as num?)?.toDouble() ?? 0.0;
              final src = (i['received_from'] ?? i['source_name'] ?? 'गट उत्पन्न').toString();
              final date = (i['income_date'] ?? '').toString();
              items.add(CashTransactionItem(
                id: i['id']?.toString() ?? UniqueKey().toString(),
                date: date.isNotEmpty ? date : DateTime.now().toIso8601String().split('T').first,
                type: 'cash_in',
                category: 'गट उत्पन्न',
                title: '$src - जमा',
                subtitle: (i['description'] ?? i['notes'])?.toString(),
                receiptNo: (i['receipt_number'] ?? i['receipt_no'])?.toString(),
                amount: amt,
                paymentMode: 'हातातील रोख (Cash)',
              ));
            }
          }
        } catch (_) {}

        // 6. Fetch Expenses where mode is cash
        try {
          final expRes = await _service.client.from('expenses').select().eq('group_id', gId);
          for (var ex in (expRes as List)) {
            final mode = (ex['payment_mode'] ?? 'cash').toString().toLowerCase();
            if (mode == 'cash' || mode.isEmpty || mode == 'रोख') {
              final amt = (ex['amount'] as num?)?.toDouble() ?? 0.0;
              final cat = (ex['category'] ?? 'खर्च').toString();
              final date = (ex['expense_date'] ?? '').toString();
              items.add(CashTransactionItem(
                id: ex['id']?.toString() ?? UniqueKey().toString(),
                date: date.isNotEmpty ? date : DateTime.now().toIso8601String().split('T').first,
                type: 'cash_out',
                category: 'गट खर्च',
                title: '$cat - खर्च व्हाऊचर',
                subtitle: (ex['description'] ?? ex['notes'])?.toString(),
                receiptNo: (ex['bill_number'] ?? ex['voucher_no'])?.toString(),
                amount: amt,
                paymentMode: 'हातातील रोख (Cash)',
              ));
            }
          }
        } catch (_) {}

        // Sort descending by date
        items.sort((a, b) => b.date.compareTo(a.date));

        setState(() {
          _allTransactions = items;
        });
      } catch (e) {
        debugPrint('Error loading cashbook transactions: $e');
      }
    }
    setState(() => _isLoading = false);
  }

  void _applyPeriodPreset(String preset) {
    final now = DateTime.now();
    setState(() {
      _activePeriodPreset = preset;
      if (preset == 'all') {
        _fromDate = null;
        _toDate = null;
      } else if (preset == 'today') {
        _fromDate = DateTime(now.year, now.month, now.day);
        _toDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
      } else if (preset == 'this_month') {
        _fromDate = DateTime(now.year, now.month, 1);
        _toDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      } else if (preset == 'last_month') {
        _fromDate = DateTime(now.year, now.month - 1, 1);
        _toDate = DateTime(now.year, now.month, 0, 23, 59, 59);
      }
    });
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _fromDate != null && _toDate != null
          ? DateTimeRange(start: _fromDate!, end: _toDate!)
          : DateTimeRange(start: DateTime.now().subtract(const Duration(days: 30)), end: DateTime.now()),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _activePeriodPreset = 'custom';
        _fromDate = picked.start;
        _toDate = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
      });
    }
  }

  List<CashTransactionItem> get _filteredTransactions {
    final fStr = _fromDate != null
        ? "${_fromDate!.year}-${_fromDate!.month.toString().padLeft(2, '0')}-${_fromDate!.day.toString().padLeft(2, '0')}"
        : null;
    final tStr = _toDate != null
        ? "${_toDate!.year}-${_toDate!.month.toString().padLeft(2, '0')}-${_toDate!.day.toString().padLeft(2, '0')}"
        : null;
    final q = _searchQuery.toLowerCase().trim();

    return _allTransactions.where((t) {
      // Date filter
      if (fStr != null && t.date.compareTo(fStr) < 0) return false;
      if (tStr != null && t.date.compareTo(tStr) > 0) return false;

      // Type filter
      if (_typeFilter != 'all' && t.type != _typeFilter) return false;

      // Search query
      if (q.isNotEmpty) {
        final titleMatch = t.title.toLowerCase().contains(q);
        final subMatch = (t.subtitle ?? '').toLowerCase().contains(q);
        final catMatch = t.category.toLowerCase().contains(q);
        final recMatch = (t.receiptNo ?? '').toLowerCase().contains(q);
        final amtMatch = t.amount.toString().contains(q);
        if (!titleMatch && !subMatch && !catMatch && !recMatch && !amtMatch) return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final isDesktop = MediaQuery.of(context).size.width >= 768;
    final isMobile = MediaQuery.of(context).size.width < 600;

    // Calculate metrics
    final filtered = _filteredTransactions;
    double periodIn = 0;
    double periodOut = 0;
    for (var t in filtered) {
      if (t.isIncome) {
        periodIn += t.amount;
      } else {
        periodOut += t.amount;
      }
    }

    // All-time net cash in hand
    double allTimeIn = 0;
    double allTimeOut = 0;
    for (var t in _allTransactions) {
      if (t.isIncome) {
        allTimeIn += t.amount;
      } else {
        allTimeOut += t.amount;
      }
    }
    final netCashInHand = allTimeIn - allTimeOut;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
                tooltip: 'मागे जा (Back)',
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.tr('बँक व रोख वही (Bank & Cash Book)', 'Bank & Cash Book (Ledger)'),
              style: GoogleFonts.poppins(
                fontSize: isMobile ? 16 : 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            Text(
              AppStrings.tr('हातातील रोख (Cash in Hand) व संबंधित व्यवहारांची नोंद वही', 'Cash in Hand & Daily Transactions Ledger'),
              style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            tooltip: 'रिफ्रेश (Refresh)',
            onPressed: _loadCashBook,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: AppButton(
              icon: Icons.add_card_rounded,
              text: isMobile ? '+ पावती' : AppStrings.tr('+ नवीन पावती / खर्च', '+ Add Voucher'),
              onPressed: () => _showAddVoucherDialog(context, auth),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 12 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- TOP SUMMARY CARDS ---
                  _buildSummaryCards(periodIn, periodOut, netCashInHand, isDesktop, isMobile),
                  const SizedBox(height: 18),

                  // --- DATE FILTER & SEARCH BAR ---
                  _buildFilterBar(isDesktop, isMobile),
                  const SizedBox(height: 18),

                  // --- TRANSACTIONS LIST / TABLE ---
                  _buildTransactionsSection(filtered, isDesktop, isMobile, auth),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCards(double periodIn, double periodOut, double netCash, bool isDesktop, bool isMobile) {
    final netCard = AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF00B4DB), Color(0xFF0083B0)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.payments_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.tr('हातातील निव्वळ रोख शिल्लक', 'Net Cash in Hand Balance'),
                  style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  '₹ ${netCash.toStringAsFixed(0)}',
                  style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: const Color(0xFF0083B0)),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final inCard = AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_downward_rounded, color: AppColors.success, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _activePeriodPreset == 'all'
                      ? AppStrings.tr('एकूण रोख जमा (All Time)', 'Total Cash Receipts')
                      : AppStrings.tr('कालावधीतील रोख जमा', 'Period Receipts'),
                  style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  '₹ ${periodIn.toStringAsFixed(0)}',
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.success),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final outCard = AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.danger.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_upward_rounded, color: AppColors.danger, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _activePeriodPreset == 'all'
                      ? AppStrings.tr('एकूण रोख खर्च/बँक भरणा', 'Total Cash Payments')
                      : AppStrings.tr('कालावधीतील रोख खर्च/बँक भरणा', 'Period Payments'),
                  style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  '₹ ${periodOut.toStringAsFixed(0)}',
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.danger),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (isDesktop) {
      return Row(
        children: [
          Expanded(child: netCard),
          const SizedBox(width: 14),
          Expanded(child: inCard),
          const SizedBox(width: 14),
          Expanded(child: outCard),
        ],
      );
    }

    return Column(
      children: [
        netCard,
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: inCard),
            const SizedBox(width: 10),
            Expanded(child: outCard),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterBar(bool isDesktop, bool isMobile) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Period Preset Chips & Date Range Picker Button
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildPresetChip('all', AppStrings.tr('सर्व नोंदी (All)', 'All')),
              _buildPresetChip('today', AppStrings.tr('आजचे (Today)', 'Today')),
              _buildPresetChip('this_month', AppStrings.tr('चालू महिना (This Month)', 'This Month')),
              _buildPresetChip('last_month', AppStrings.tr('मागील महिना (Last Month)', 'Last Month')),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _activePeriodPreset == 'custom' ? Colors.white : AppColors.primary,
                  backgroundColor: _activePeriodPreset == 'custom' ? AppColors.primary : Colors.white,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                icon: const Icon(Icons.date_range_rounded, size: 16),
                label: Text(
                  _fromDate != null && _toDate != null
                      ? '${_fromDate!.day}/${_fromDate!.month}/${_fromDate!.year} - ${_toDate!.day}/${_toDate!.month}/${_toDate!.year}'
                      : AppStrings.tr('तारीख निवडा (Date Range)', 'Select Dates'),
                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                onPressed: _pickDateRange,
              ),
              if (_fromDate != null || _toDate != null || _activePeriodPreset != 'all')
                TextButton.icon(
                  onPressed: () => _applyPeriodPreset('all'),
                  icon: const Icon(Icons.clear, size: 16, color: Colors.grey),
                  label: Text(
                    AppStrings.tr('फिल्टर काढा', 'Clear Filter'),
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ),
            ],
          ),
          const Divider(height: 20),

          // Search Bar & Type Filter Chips
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: AppStrings.tr('शोध: सभासद नाव, तपशील, पावती क्र....', 'Search by name, particulars...'),
                    hintStyle: GoogleFonts.poppins(fontSize: 12, color: AppColors.textMuted),
                    prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textMuted),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.cardBorder)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary)),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),
              const SizedBox(width: 12),
              // Filter Type Buttons
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'all', label: Text(isMobile ? 'सर्व' : 'सर्व (All)')),
                  ButtonSegment(value: 'cash_in', label: Text(isMobile ? 'जमा' : 'जमा (In)')),
                  ButtonSegment(value: 'cash_out', label: Text(isMobile ? 'खर्च' : 'खर्च (Out)')),
                ],
                selected: {_typeFilter},
                onSelectionChanged: (val) => setState(() => _typeFilter = val.first),
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  textStyle: WidgetStateProperty.all(GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(String preset, String label) {
    final isSelected = _activePeriodPreset == preset;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => _applyPeriodPreset(preset),
      selectedColor: AppColors.primary.withOpacity(0.15),
      labelStyle: GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? AppColors.primary : const Color(0xFF0F172A),
      ),
    );
  }

  Widget _buildTransactionsSection(List<CashTransactionItem> list, bool isDesktop, bool isMobile, AuthProvider auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${AppStrings.tr("रोख जमा-खर्च नोंदी (Cash Ledger)", "Cash Ledger Entries")} (${list.length})',
              style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
            ),
            Text(
              AppStrings.tr('माध्यम: हातातील रोख (Mode: Cash)', 'Mode: Cash in Hand'),
              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF0083B0)),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (list.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(36),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              children: [
                const Icon(Icons.account_balance_wallet_outlined, size: 48, color: AppColors.textMuted),
                const SizedBox(height: 12),
                Text(
                  AppStrings.tr('निवडलेल्या कालावधीत कोणताही रोख व्यवहार आढळला नाही', 'No cash transactions found for the selected period'),
                  style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                AppButton(
                  text: AppStrings.tr('+ नवीन पावती / व्हाउचर नोंदवा', '+ Add Cash Voucher'),
                  icon: Icons.add,
                  onPressed: () => _showAddVoucherDialog(context, auth),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: list.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              final item = list[i];
              final isIncome = item.isIncome;

              Color categoryColor = AppColors.primary;
              if (item.category.contains('बचत')) categoryColor = const Color(0xFF11998E);
              if (item.category.contains('कर्ज हप्ता')) categoryColor = const Color(0xFFFF5E36);
              if (item.category.contains('उत्पन्न')) categoryColor = const Color(0xFF10B981);
              if (item.category.contains('खर्च')) categoryColor = const Color(0xFFEF4444);
              if (item.category.contains('बँक')) categoryColor = const Color(0xFF8E2DE2);

              return AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: (isIncome ? AppColors.success : AppColors.danger).withOpacity(0.12),
                      child: Icon(
                        isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                        color: isIncome ? AppColors.success : AppColors.danger,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: categoryColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  item.category,
                                  style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: categoryColor),
                                ),
                              ),
                              if (item.receiptNo != null && item.receiptNo!.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Text(
                                  'क्र: ${item.receiptNo}',
                                  style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textSecondary),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.title,
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13, color: const Color(0xFF0F172A)),
                          ),
                          Text(
                            'तारीख: ${item.date} • माध्यम: हातातील रोख (Cash in Hand)',
                            style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${isIncome ? "+" : "-"} ₹ ${item.amount.toStringAsFixed(0)}',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: isIncome ? AppColors.success : AppColors.danger,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  void _showAddVoucherDialog(BuildContext context, AuthProvider auth) {
    final dashProv = Provider.of<DashboardProvider>(context, listen: false);
    final particularsCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final dateCtrl = TextEditingController(text: DateTime.now().toIso8601String().split('T').first);
    String type = 'cash_in';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding: EdgeInsets.symmetric(
            horizontal: MediaQuery.of(ctx).size.width < 500 ? 12 : 40,
            vertical: 24,
          ),
          title: Text(AppStrings.tr('नवीन रोख व्हाउचर नोंद (Add Cash Entry)', 'Add Cash Entry')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: Text(AppStrings.tr('जमा (Receipt)', 'Receipt')),
                        selected: type == 'cash_in',
                        selectedColor: AppColors.success.withOpacity(0.2),
                        onSelected: (val) => setDialogState(() => type = 'cash_in'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: Text(AppStrings.tr('खर्च (Payment)', 'Payment')),
                        selected: type == 'cash_out',
                        selectedColor: AppColors.danger.withOpacity(0.2),
                        onSelected: (val) => setDialogState(() => type = 'cash_out'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: particularsCtrl,
                  decoration: InputDecoration(
                    labelText: AppStrings.tr('तपशील / कारण (Description)*', 'Description*'),
                    hintText: 'उदा. स्टेशनरी खर्च / प्रवास भत्ता / चहापान',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: AppStrings.tr('रक्कम (Amount ₹)*', 'Amount (₹)*'),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: dateCtrl,
                  decoration: InputDecoration(
                    labelText: AppStrings.tr('तारीख (Date)*', 'Date*'),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: DateTime.tryParse(dateCtrl.text) ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setDialogState(() {
                            dateCtrl.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                          });
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0083B0).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: Color(0xFF0083B0)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'व्यवहार थेट हातातील रोख (Cash in Hand) मध्ये नोंदवला जाईल.',
                          style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF0083B0)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.cancel)),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () async {
                if (particularsCtrl.text.isEmpty || amountCtrl.text.isEmpty) return;
                Navigator.pop(ctx);
                try {
                  final amt = double.tryParse(amountCtrl.text) ?? 0.0;
                  await _service.client.from('cash_book').insert({
                    'group_id': auth.currentGroup!.id,
                    'entry_date': dateCtrl.text.trim(),
                    'type': type,
                    'amount': amt,
                    'description': particularsCtrl.text.trim(),
                    'entered_by': auth.currentProfile?.fullName ?? 'व्यवस्थापक',
                    'reference_module': 'manual_voucher',
                  });
                  await _loadCashBook();
                  if (auth.currentGroup != null) {
                    await dashProv.loadDashboardMetrics(auth.currentGroup!.id);
                  }
                } catch (e) {
                  debugPrint('Error inserting cashbook entry: $e');
                }
              },
              child: Text(AppStrings.save, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
