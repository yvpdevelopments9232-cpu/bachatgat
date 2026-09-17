import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_strings.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/bank_provider.dart';
import '../../services/supabase_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';

class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SupabaseService _service = SupabaseService();
  bool _isLoading = false;
  List<Map<String, dynamic>> _expenses = [];

  // Filter state
  DateTime _fromDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _toDate = DateTime.now();
  String _selectedCategoryFilter = 'सर्व (All)';
  String _searchQuery = '';

  // Form controllers
  final _formKey = GlobalKey<FormState>();
  DateTime _expenseDate = DateTime.now();
  String _category = 'कच्चा माल खरेदी (Raw Material)';
  final _amountCtrl = TextEditingController();
  String _paymentMode = 'cash';
  String? _selectedBankAccountId;
  final _paidToCtrl = TextEditingController();
  final _billNoCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _approverCtrl = TextEditingController();

  final List<String> _categories = [
    'कच्चा माल खरेदी (Raw Material)',
    'जागा/दुकान भाडे (Rent)',
    'वीजबिल व पाणीपट्टी (Electricity & Water)',
    'वाहतूक व प्रवास खर्च (Transport)',
    'चहा, नाश्ता व बैठक खर्च (Refreshment)',
    'स्टेशनरी व छपाई (Stationery & Print)',
    'दुरुस्ती व देखभाल (Maintenance)',
    'बँक चार्जेस व ऑडिट फी (Bank & Audit Fee)',
    'इतर खर्च (Miscellaneous Expense)',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _billNoCtrl.text = 'EXP-${DateFormat('yyyyMMdd-HHmm').format(DateTime.now())}';
    _loadExpenses();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _amountCtrl.dispose();
    _paidToCtrl.dispose();
    _billNoCtrl.dispose();
    _descCtrl.dispose();
    _approverCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExpenses() async {
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.currentGroup != null) {
      try {
        final res = await _service.client
            .from('expenses')
            .select()
            .eq('group_id', auth.currentGroup!.id)
            .order('expense_date', ascending: false);
        setState(() {
          _expenses = List<Map<String, dynamic>>.from(res as List);
        });
      } catch (e) {
        debugPrint('Error loading expenses: $e');
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.currentGroup == null) return;

    final amt = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
    if (amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('कृपया योग्य रक्कम भरा'), backgroundColor: AppColors.danger),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final groupId = auth.currentGroup!.id;
      final expenseData = {
        'group_id': groupId,
        'expense_date': DateFormat('yyyy-MM-dd').format(_expenseDate),
        'category': _category,
        'amount': amt,
        'payment_mode': _paymentMode,
        'paid_to': _paidToCtrl.text.trim().isNotEmpty ? _paidToCtrl.text.trim() : 'इतर (Other)',
        'bill_number': _billNoCtrl.text.trim().isNotEmpty ? _billNoCtrl.text.trim() : 'EXP-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        'description': _descCtrl.text.trim(),
      };

      await _service.client.from('expenses').insert(expenseData);

      // Record in cash_book or bank_transactions
      if (_paymentMode.toLowerCase() == 'cash') {
        await _service.client.from('cash_book').insert({
          'group_id': groupId,
          'entry_date': DateFormat('yyyy-MM-dd').format(_expenseDate),
          'type': 'cash_out',
          'amount': amt,
          'description': 'खर्च पेमेंट ($_category): ${_paidToCtrl.text.trim()}',
          'reference_module': 'expenses',
        });
      } else {
        await _service.adjustBankBalance(
          groupId: groupId,
          amount: amt,
          isDeposit: false,
          purpose: 'खर्च पेमेंट ($_category): ${_paidToCtrl.text.trim()}',
          remarks: _descCtrl.text.trim(),
          bankAccountId: _selectedBankAccountId,
        );
      }

      if (mounted) {
        try {
          Provider.of<DashboardProvider>(context, listen: false).loadDashboardMetrics(groupId);
        } catch (_) {}
        try {
          Provider.of<BankProvider>(context, listen: false).loadBanks(groupId);
        } catch (_) {}
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('खर्च व्हाउचर यशस्वीरित्या नोंदवले गेले!'), backgroundColor: AppColors.success),
        );
        _amountCtrl.clear();
        _paidToCtrl.clear();
        _descCtrl.clear();
        _billNoCtrl.text = 'EXP-${DateFormat('yyyyMMdd-HHmm').format(DateTime.now())}';
        _tabController.animateTo(0);
        await _loadExpenses();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('नोंद करताना त्रुटी: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteExpense(String id, double amt, String mode) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.tr('खर्च नोंद हटवायची का?', 'Delete Expense Entry?')),
        content: const Text('ही नोंद हटवल्यास खर्चातून रक्कम कमी होईल.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('रद्द करा')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('हटवा (Delete)'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _service.client.from('expenses').delete().eq('id', id);
      await _loadExpenses();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('खर्च नोंद हटवली गेली'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('त्रुटी: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredExpenses {
    return _expenses.where((item) {
      final dateStr = item['expense_date']?.toString();
      if (dateStr != null) {
        final d = DateTime.tryParse(dateStr);
        if (d != null) {
          if (d.isBefore(_fromDate.subtract(const Duration(days: 1))) ||
              d.isAfter(_toDate.add(const Duration(days: 1)))) {
            return false;
          }
        }
      }
      if (_selectedCategoryFilter != 'सर्व (All)') {
        final cat = item['category']?.toString() ?? '';
        if (!cat.contains(_selectedCategoryFilter.split(' ').first)) return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final paidTo = (item['paid_to'] ?? '').toString().toLowerCase();
        final desc = (item['description'] ?? '').toString().toLowerCase();
        final bill = (item['bill_number'] ?? '').toString().toLowerCase();
        if (!paidTo.contains(q) && !desc.contains(q) && !bill.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final filtered = _filteredExpenses;
    final totalFiltered = filtered.fold<double>(0.0, (s, e) => s + ((e['amount'] as num?)?.toDouble() ?? 0.0));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header & Tabs
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = constraints.maxWidth < 600;
                    if (isMobile) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.tr('९. खर्च व्यवस्थापन व अहवाल', '9. Expense Management & Report'),
                            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            AppStrings.tr('गटाचे दैनंदिन खर्च व्हाउचर्स, बिले व वर्गवारी अहवाल', 'Daily expense vouchers, bills & category reports'),
                            style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
                          ),
                          if (auth.canAdd) ...[
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: AppButton(
                                icon: Icons.add_rounded,
                                text: AppStrings.tr('+ नवीन खर्च नोंद', '+ Add Expense'),
                                onPressed: () => _tabController.animateTo(1),
                              ),
                            ),
                          ],
                        ],
                      );
                    }
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppStrings.tr('९. खर्च व्यवस्थापन व अहवाल', '9. Expense Management & Report'),
                                style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                              ),
                              Text(
                                AppStrings.tr('गटाचे दैनंदिन खर्च व्हाउचर्स, बिले व वर्गवारी अहवाल', 'Daily expense vouchers, bills & category reports'),
                                style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        if (auth.canAdd) ...[
                          const SizedBox(width: 12),
                          AppButton(
                            icon: Icons.add_rounded,
                            text: AppStrings.tr('+ नवीन खर्च नोंद', '+ Add Expense'),
                            onPressed: () => _tabController.animateTo(1),
                          ),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 3,
                  labelStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
                  tabs: [
                    Tab(
                      icon: const Icon(Icons.assessment_outlined, size: 20),
                      text: AppStrings.tr('खर्च अहवाल (Expense Report)', 'Expense Report'),
                    ),
                    Tab(
                      icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                      text: AppStrings.tr('+ नवीन खर्च नोंद (Add Expense)', '+ Add Expense'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildReportTab(filtered, totalFiltered),
                _buildAddExpenseTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 1: REPORT & LIST ---
  Widget _buildReportTab(List<Map<String, dynamic>> list, double totalAmount) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPI Banner
          Row(
            children: [
              Expanded(
                child: AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.12), shape: BoxShape.circle),
                        child: const Icon(Icons.trending_down_rounded, color: AppColors.danger, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppStrings.tr('एकूण खर्च (Total Expenses)', 'Total Filtered Expense'),
                              style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '₹${totalAmount.toStringAsFixed(2)}',
                                style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.danger),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppColors.secondary.withOpacity(0.12), shape: BoxShape.circle),
                        child: const Icon(Icons.receipt_long_rounded, color: AppColors.secondary, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppStrings.tr('एकूण खर्च व्हाउचर्स (Vouchers)', 'Total Vouchers'),
                              style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '${list.length}',
                                style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.secondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Filters Card
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.tr('तारीख व वर्गवारी फिल्टर (Filters)', 'Filters'),
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today_rounded, size: 16),
                      label: Text('पासून: ${DateFormat('dd-MM-yyyy').format(_fromDate)}'),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _fromDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2050, 12, 31),
                        );
                        if (picked != null) setState(() => _fromDate = picked);
                      },
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_month_rounded, size: 16),
                      label: Text('पर्यंत: ${DateFormat('dd-MM-yyyy').format(_toDate)}'),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _toDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2050, 12, 31),
                        );
                        if (picked != null) setState(() => _toDate = picked);
                      },
                    ),
                    DropdownButton<String>(
                      value: _selectedCategoryFilter,
                      underline: const SizedBox(),
                      items: ['सर्व (All)', ..._categories].map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13)))).toList(),
                      onChanged: (val) => setState(() => _selectedCategoryFilter = val!),
                    ),
                    SizedBox(
                      width: 200,
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: AppStrings.tr('शोधा...', 'Search...'),
                          prefixIcon: const Icon(Icons.search, size: 18),
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // List
          if (_isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
          else if (list.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(Icons.money_off_rounded, size: 56, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text(
                      AppStrings.tr('निवडलेल्या कालावधीत कोणतीही खर्च नोंद नाही.', 'No expense records found.'),
                      style: GoogleFonts.poppins(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: list.length,
              separatorBuilder: (ctx, idx) => const SizedBox(height: 10),
              itemBuilder: (context, idx) {
                final e = list[idx];
                final amt = (e['amount'] as num?)?.toDouble() ?? 0.0;
                final dateStr = e['expense_date']?.toString() ?? '';
                final cat = e['category']?.toString() ?? 'इतर खर्च';
                final mode = e['payment_mode']?.toString().toUpperCase() ?? 'CASH';
                final paidTo = e['paid_to']?.toString() ?? '-';
                final billNo = e['bill_number']?.toString() ?? '-';
                final desc = e['description']?.toString() ?? '';

                return AppCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.arrow_upward_rounded, color: AppColors.danger, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  paidTo,
                                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.08), borderRadius: BorderRadius.circular(4)),
                                  child: Text(cat, style: GoogleFonts.poppins(fontSize: 11, color: AppColors.danger, fontWeight: FontWeight.w500)),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)),
                                  child: Text(mode, style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey.shade800)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'तारीख: $dateStr • बिल क्र.: $billNo ${desc.isNotEmpty ? "• $desc" : ""}',
                              style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '- ₹${amt.toStringAsFixed(2)}',
                        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.danger),
                      ),
                      if (auth.canDelete)
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.grey, size: 20),
                          tooltip: 'हटवा (Delete)',
                          onPressed: () => _deleteExpense(e['id'].toString(), amt, mode),
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

  // --- TAB 2: ADD EXPENSE FORM ---
  Widget _buildAddExpenseTab() {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 680),
          child: AppCard(
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.add_circle_rounded, color: AppColors.danger, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          AppStrings.tr('नवीन खर्च व्हाउचर नोंद (Add Expense Voucher)', 'Add Expense Voucher'),
                          style: GoogleFonts.poppins(
                            fontSize: isMobile ? 14 : 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _expenseDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2050, 12, 31),
                            );
                            if (picked != null) setState(() => _expenseDate = picked);
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'खर्च तारीख (Date)',
                              prefixIcon: Icon(Icons.calendar_today_rounded, size: 20),
                            ),
                            child: Text(DateFormat('dd-MM-yyyy').format(_expenseDate)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: TextFormField(
                          controller: _billNoCtrl,
                          decoration: const InputDecoration(
                            labelText: 'बिल / व्हाउचर क्र. (Bill/Voucher No)',
                            prefixIcon: Icon(Icons.tag_rounded, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    value: _category,
                    decoration: const InputDecoration(
                      labelText: 'खर्च वर्गवारी (Expense Category)',
                      prefixIcon: Icon(Icons.category_rounded, size: 20),
                    ),
                    items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (val) => setState(() => _category = val!),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: _amountCtrl,
                          keyboardType: TextInputType.number,
                          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.danger),
                          decoration: const InputDecoration(
                            labelText: 'खर्च रक्कम (Amount ₹) *',
                            prefixIcon: Icon(Icons.currency_rupee_rounded, size: 20, color: AppColors.danger),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'रक्कम आवश्यक आहे';
                            if (double.tryParse(v.trim()) == null) return 'अंक प्रविष्ट करा';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          value: _paymentMode,
                          decoration: const InputDecoration(
                            labelText: 'पेमेंट स्रोत (Payment Source)',
                            prefixIcon: Icon(Icons.payments_rounded, size: 20),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'cash', child: Text('हातातील रोख (Cash in Hand)')),
                            DropdownMenuItem(value: 'bank_transfer', child: Text('बँक खाते (Bank Account)')),
                          ],
                          onChanged: (val) => setState(() => _paymentMode = val!),
                        ),
                      ),
                    ],
                  ),
                  if (_paymentMode == 'bank_transfer') ...[
                    const SizedBox(height: 16),
                    Consumer<BankProvider>(
                      builder: (context, bankProv, _) {
                        final activeBanks = bankProv.activeBanks;
                        return DropdownButtonFormField<String>(
                          value: activeBanks.any((b) => b.id == _selectedBankAccountId)
                              ? _selectedBankAccountId
                              : (activeBanks.isNotEmpty ? activeBanks.first.id : null),
                          decoration: const InputDecoration(
                            labelText: 'खर्च बँक खाते (Pay From Bank Account) *',
                            prefixIcon: Icon(Icons.account_balance_rounded, size: 20),
                          ),
                          items: activeBanks.map((b) => DropdownMenuItem(
                            value: b.id,
                            child: Text('${b.bankName} (${b.maskedAccountNumber}) - ₹${b.currentBalance.toStringAsFixed(0)}'),
                          )).toList(),
                          onChanged: (val) => setState(() => _selectedBankAccountId = val),
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _paidToCtrl,
                    decoration: const InputDecoration(
                      labelText: 'कोणास दिले (Paid To) *',
                      hintText: 'उदा. किराणा स्टोअर / महावितरण / गाडी मालक',
                      prefixIcon: Icon(Icons.store_rounded, size: 20),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'नाव आवश्यक आहे' : null,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _descCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'खर्चाचा उद्देश / शेरा (Purpose & Description)',
                      hintText: 'उदा. मसाले बनवण्यासाठी मिरची व तेल खरेदी',
                      prefixIcon: Icon(Icons.notes_rounded, size: 20),
                    ),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      text: AppStrings.tr('खर्च व्हाउचर साठवा (Save Expense)', 'Save Expense Voucher'),
                      icon: Icons.check_circle_rounded,
                      isLoading: _isLoading,
                      onPressed: _saveExpense,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
