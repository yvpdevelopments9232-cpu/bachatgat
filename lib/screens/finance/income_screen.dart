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

class IncomeScreen extends StatefulWidget {
  const IncomeScreen({super.key});

  @override
  State<IncomeScreen> createState() => _IncomeScreenState();
}

class _IncomeScreenState extends State<IncomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SupabaseService _service = SupabaseService();
  bool _isLoading = false;
  List<Map<String, dynamic>> _incomes = [];

  // Filter state
  DateTime _fromDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _toDate = DateTime.now();
  String _selectedCategoryFilter = 'सर्व (All)';
  String _searchQuery = '';

  // Form controllers
  final _formKey = GlobalKey<FormState>();
  DateTime _incomeDate = DateTime.now();
  String _category = 'उत्पादने विक्री (Product Sales)';
  final _amountCtrl = TextEditingController();
  String _paymentMode = 'cash';
  String? _selectedBankAccountId;
  final _receivedFromCtrl = TextEditingController();
  final _receiptNoCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  final List<String> _categories = [
    'उत्पादने विक्री (Product Sales)',
    'कर्ज व्याज (Loan Interest)',
    'विलंब शुल्क (Late Fee)',
    'बँक व्याज (Bank Interest)',
    'शासकीय अनुदान (Govt Grant)',
    'देणगी व इतर निधी (Donation / Fund)',
    'इतर जमा (Other Income)',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _receiptNoCtrl.text = 'INC-${DateFormat('yyyyMMdd-HHmm').format(DateTime.now())}';
    _loadIncomes();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _amountCtrl.dispose();
    _receivedFromCtrl.dispose();
    _receiptNoCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadIncomes() async {
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.currentGroup != null) {
      try {
        final res = await _service.client
            .from('incomes')
            .select()
            .eq('group_id', auth.currentGroup!.id)
            .order('income_date', ascending: false);
        setState(() {
          _incomes = List<Map<String, dynamic>>.from(res as List);
        });
      } catch (e) {
        debugPrint('Error loading incomes: $e');
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveIncome() async {
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
      final incomeData = {
        'group_id': groupId,
        'income_date': DateFormat('yyyy-MM-dd').format(_incomeDate),
        'category': _category,
        'amount': amt,
        'payment_mode': _paymentMode,
        'received_from': _receivedFromCtrl.text.trim().isNotEmpty ? _receivedFromCtrl.text.trim() : 'गट (Group)',
        'receipt_number': _receiptNoCtrl.text.trim().isNotEmpty ? _receiptNoCtrl.text.trim() : 'INC-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        'description': _descCtrl.text.trim(),
      };

      await _service.client.from('incomes').insert(incomeData);

      // Record in cash_book or bank_transactions
      if (_paymentMode.toLowerCase() == 'cash') {
        await _service.client.from('cash_book').insert({
          'group_id': groupId,
          'entry_date': DateFormat('yyyy-MM-dd').format(_incomeDate),
          'type': 'cash_in',
          'amount': amt,
          'description': 'उत्पन्न जमा ($_category): ${_receivedFromCtrl.text.trim()}',
          'reference_module': 'incomes',
        });
      } else {
        await _service.adjustBankBalance(
          groupId: groupId,
          amount: amt,
          isDeposit: true,
          purpose: 'उत्पन्न जमा ($_category): ${_receivedFromCtrl.text.trim()}',
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
          const SnackBar(content: Text('उत्पन्न यशस्वीरित्या नोंदवले गेले!'), backgroundColor: AppColors.success),
        );
        // Reset form
        _amountCtrl.clear();
        _receivedFromCtrl.clear();
        _descCtrl.clear();
        _receiptNoCtrl.text = 'INC-${DateFormat('yyyyMMdd-HHmm').format(DateTime.now())}';
        _tabController.animateTo(0);
        await _loadIncomes();
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

  Future<void> _deleteIncome(String id, double amt, String mode) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.tr('उत्पन्न नोंद हटवायची का?', 'Delete Income Entry?')),
        content: const Text('ही नोंद हटवल्यास उत्पन्नातून रक्कम वजा होईल.'),
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
      await _service.client.from('incomes').delete().eq('id', id);
      await _loadIncomes();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('नोंद हटवली गेली'), backgroundColor: AppColors.success),
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

  List<Map<String, dynamic>> get _filteredIncomes {
    return _incomes.where((item) {
      final dateStr = item['income_date']?.toString();
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
        final from = (item['received_from'] ?? '').toString().toLowerCase();
        final desc = (item['description'] ?? '').toString().toLowerCase();
        final rec = (item['receipt_number'] ?? '').toString().toLowerCase();
        if (!from.contains(q) && !desc.contains(q) && !rec.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final filtered = _filteredIncomes;
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
                            AppStrings.tr('८. उत्पन्न व्यवस्थापन व अहवाल', '8. Income Management & Report'),
                            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            AppStrings.tr('गटाचे सर्व स्त्रोतांकडून आलेले उत्पन्न व पावती नोंद', 'All group income sources, receipts & reports'),
                            style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
                          ),
                          if (auth.canAdd) ...[
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: AppButton(
                                icon: Icons.add_rounded,
                                text: AppStrings.tr('+ नवीन उत्पन्न नोंद', '+ Add Income'),
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
                                AppStrings.tr('८. उत्पन्न व्यवस्थापन व अहवाल', '8. Income Management & Report'),
                                style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                              ),
                              Text(
                                AppStrings.tr('गटाचे सर्व स्त्रोतांकडून आलेले उत्पन्न व पावती नोंद', 'All group income sources, receipts & reports'),
                                style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        if (auth.canAdd) ...[
                          const SizedBox(width: 12),
                          AppButton(
                            icon: Icons.add_rounded,
                            text: AppStrings.tr('+ नवीन उत्पन्न नोंद', '+ Add Income'),
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
                      icon: const Icon(Icons.receipt_long_rounded, size: 20),
                      text: AppStrings.tr('उत्पन्न अहवाल (Income Report)', 'Income Report'),
                    ),
                    Tab(
                      icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                      text: AppStrings.tr('+ नवीन उत्पन्न नोंद (Add Income)', '+ Add Income'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Tab views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildReportTab(filtered, totalFiltered),
                _buildAddIncomeTab(),
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
                        decoration: BoxDecoration(color: AppColors.success.withOpacity(0.12), shape: BoxShape.circle),
                        child: const Icon(Icons.trending_up_rounded, color: AppColors.success, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppStrings.tr('एकूण उत्पन्न (Total Income)', 'Total Filtered Income'),
                              style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '₹${totalAmount.toStringAsFixed(2)}',
                                style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.success),
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
                        decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), shape: BoxShape.circle),
                        child: const Icon(Icons.receipt_rounded, color: AppColors.primary, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppStrings.tr('एकूण पावत्या (Entries)', 'Total Entries'),
                              style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '${list.length}',
                                style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.primary),
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
                    Icon(Icons.receipt_long_outlined, size: 56, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text(
                      AppStrings.tr('निवडलेल्या कालावधीत कोणतीही उत्पन्न नोंद नाही.', 'No income records found.'),
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
                final dateStr = e['income_date']?.toString() ?? '';
                final cat = e['category']?.toString() ?? 'इतर';
                final mode = e['payment_mode']?.toString().toUpperCase() ?? 'CASH';
                final from = e['received_from']?.toString() ?? '-';
                final recNo = e['receipt_number']?.toString() ?? '-';
                final desc = e['description']?.toString() ?? '';

                return AppCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppColors.success.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.arrow_downward_rounded, color: AppColors.success, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  from,
                                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(4)),
                                  child: Text(cat, style: GoogleFonts.poppins(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w500)),
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
                              'तारीख: $dateStr • पावती क्र.: $recNo ${desc.isNotEmpty ? "• $desc" : ""}',
                              style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '+ ₹${amt.toStringAsFixed(2)}',
                        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.success),
                      ),
                      if (auth.canDelete)
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.grey, size: 20),
                          tooltip: 'हटवा (Delete)',
                          onPressed: () => _deleteIncome(e['id'].toString(), amt, mode),
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

  // --- TAB 2: ADD INCOME FORM ---
  Widget _buildAddIncomeTab() {
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
                      const Icon(Icons.add_circle_rounded, color: AppColors.success, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          AppStrings.tr('नवीन उत्पन्न पावती नोंद (Add Income Entry)', 'Add Income Entry'),
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
                              initialDate: _incomeDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2050, 12, 31),
                            );
                            if (picked != null) setState(() => _incomeDate = picked);
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'उत्पन्न तारीख (Date)',
                              prefixIcon: Icon(Icons.calendar_today_rounded, size: 20),
                            ),
                            child: Text(DateFormat('dd-MM-yyyy').format(_incomeDate)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: TextFormField(
                          controller: _receiptNoCtrl,
                          decoration: const InputDecoration(
                            labelText: 'पावती क्रमांक (Receipt No)',
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
                      labelText: 'उत्पन्न वर्गवारी (Category)',
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
                          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.success),
                          decoration: const InputDecoration(
                            labelText: 'जमा रक्कम (Amount ₹) *',
                            prefixIcon: Icon(Icons.currency_rupee_rounded, size: 20, color: AppColors.success),
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
                            labelText: 'जमा बँक खाते (Deposit to Bank Account) *',
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
                    controller: _receivedFromCtrl,
                    decoration: const InputDecoration(
                      labelText: 'कोणाकडून मिळाले (Received From) *',
                      hintText: 'उदा. अनिता कांबळे / ग्राहक / कृषी विभाग',
                      prefixIcon: Icon(Icons.person_rounded, size: 20),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'नाव आवश्यक आहे' : null,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _descCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'तपशील / शेरा (Description / Remarks)',
                      hintText: 'उदा. २५ किलो पापड विक्री रक्कम',
                      prefixIcon: Icon(Icons.notes_rounded, size: 20),
                    ),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      text: AppStrings.tr('उत्पन्न नोंद साठवा (Save Income)', 'Save Income Record'),
                      icon: Icons.check_circle_rounded,
                      isLoading: _isLoading,
                      onPressed: _saveIncome,
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
