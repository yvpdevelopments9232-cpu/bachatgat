import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_strings.dart';
import '../../models/report_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/bachat_gat_pdf_template.dart';
import '../../services/supabase_service.dart';
import '../../core/utils/image_helper.dart';
import '../../widgets/app_card.dart';

class ProfitLossScreen extends StatefulWidget {
  const ProfitLossScreen({super.key});

  @override
  State<ProfitLossScreen> createState() => _ProfitLossScreenState();
}

class _ProfitLossScreenState extends State<ProfitLossScreen> {
  final SupabaseService _service = SupabaseService();
  bool _isLoading = false;

  // Filter mode: 'monthly', 'custom', 'all'
  String _filterMode = 'monthly';

  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;

  DateTime _customStartDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _customEndDate = DateTime(DateTime.now().year, DateTime.now().month + 1, 0);

  double _totalIncome = 0.0;
  double _totalExpenses = 0.0;
  double _totalSavings = 0.0;
  double _netProfit = 0.0;
  double _profitMargin = 0.0;
  int _memberCount = 0;

  List<Map<String, dynamic>> _incomeBreakdown = [];
  List<Map<String, dynamic>> _expenseBreakdown = [];

  final List<String> _marathiMonths = [
    'जानेवारी',
    'फेब्रुवारी',
    'मार्च',
    'एप्रिल',
    'मे',
    'जून',
    'जुलै',
    'ऑगस्ट',
    'सप्टेंबर',
    'ऑक्टोबर',
    'नोव्हेंबर',
    'डिसेंबर',
  ];

  final List<String> _englishMonths = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  void initState() {
    super.initState();
    _loadPnL();
  }

  String get _periodTitle {
    if (_filterMode == 'all') {
      return AppStrings.tr('संपूर्ण कालावधी (All Time)', 'All Time');
    } else if (_filterMode == 'custom') {
      final s = DateFormat('dd/MM/yyyy').format(_customStartDate);
      final e = DateFormat('dd/MM/yyyy').format(_customEndDate);
      return '$s ते $e';
    } else {
      return '${_marathiMonths[_selectedMonth - 1]} $_selectedYear (${_englishMonths[_selectedMonth - 1]})';
    }
  }

  Future<void> _loadPnL() async {
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final groupId = auth.currentGroup?.id;
    if (groupId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      DateTime? startDate;
      DateTime? endDate;

      if (_filterMode == 'monthly') {
        startDate = DateTime(_selectedYear, _selectedMonth, 1);
        endDate = DateTime(_selectedYear, _selectedMonth + 1, 0, 23, 59, 59, 999);
      } else if (_filterMode == 'custom') {
        startDate = DateTime(_customStartDate.year, _customStartDate.month, _customStartDate.day);
        endDate = DateTime(_customEndDate.year, _customEndDate.month, _customEndDate.day, 23, 59, 59, 999);
      }

      // 1. Fetch Incomes
      final incRes = await _service.client
          .from('incomes')
          .select('category, amount, income_date, description, receipt_number')
          .eq('group_id', groupId);

      double incSum = 0.0;
      final Map<String, double> incByCat = {};
      final Set<String> recordedReceipts = {};

      for (var r in (incRes as List)) {
        final amt = (r['amount'] as num?)?.toDouble() ?? 0.0;
        final cat = r['category']?.toString().trim() ?? 'इतर उत्पन्न (Other)';
        final dateStr = r['income_date']?.toString() ?? '';
        final receipt = r['receipt_number']?.toString().trim() ?? '';
        if (receipt.isNotEmpty) recordedReceipts.add(receipt);

        if (_isDateInRange(dateStr, startDate, endDate)) {
          incSum += amt;
          incByCat[cat] = (incByCat[cat] ?? 0.0) + amt;
        }
      }

      // 1b. Check loan_emis for any paid interest/late fees
      try {
        final emiRes = await _service.client
            .from('loan_emis')
            .select('interest, late_fee, payment_date, receipt_number, status')
            .eq('group_id', groupId)
            .eq('status', 'paid');

        for (var e in (emiRes as List)) {
          final receipt = e['receipt_number']?.toString().trim() ?? '';
          if (recordedReceipts.contains(receipt)) continue;

          final pDate = e['payment_date']?.toString() ?? '';
          if (_isDateInRange(pDate, startDate, endDate)) {
            final interest = (e['interest'] as num?)?.toDouble() ?? 0.0;
            final lateFee = (e['late_fee'] as num?)?.toDouble() ?? 0.0;

            if (interest > 0) {
              const cat = 'कर्ज व्याज (Loan Interest)';
              incSum += interest;
              incByCat[cat] = (incByCat[cat] ?? 0.0) + interest;
            }
            if (lateFee > 0) {
              const cat = 'विलंब शुल्क (Late Fee)';
              incSum += lateFee;
              incByCat[cat] = (incByCat[cat] ?? 0.0) + lateFee;
            }
          }
        }
      } catch (e) {
        debugPrint('Loan EMI interest check warning: $e');
      }

      // 2. Fetch Expenses
      final expRes = await _service.client
          .from('expenses')
          .select('category, amount, expense_date, description')
          .eq('group_id', groupId);

      double expSum = 0.0;
      final Map<String, double> expByCat = {};
      for (var r in (expRes as List)) {
        final amt = (r['amount'] as num?)?.toDouble() ?? 0.0;
        final cat = r['category']?.toString().trim() ?? 'इतर खर्च (Other)';
        final dateStr = r['expense_date']?.toString() ?? '';

        if (_isDateInRange(dateStr, startDate, endDate)) {
          expSum += amt;
          expByCat[cat] = (expByCat[cat] ?? 0.0) + amt;
        }
      }

      // 3. Fetch Savings for this period
      double savSum = 0.0;
      try {
        final savRes = await _service.client
            .from('savings')
            .select('amount, savings_date')
            .eq('group_id', groupId);

        for (var r in (savRes as List)) {
          final amt = (r['amount'] as num?)?.toDouble() ?? 0.0;
          final dateStr = r['savings_date']?.toString() ?? '';
          if (_isDateInRange(dateStr, startDate, endDate)) {
            savSum += amt;
          }
        }
      } catch (e) {
        debugPrint('Savings fetch warning: $e');
      }

      // 4. Fetch Members count for per-member dividend calculation
      int mCount = 0;
      try {
        final memRes = await _service.client
            .from('members')
            .select('id')
            .eq('group_id', groupId)
            .eq('status', 'active');
        mCount = (memRes as List).length;
      } catch (_) {}

      final netProfit = incSum - expSum;
      final margin = incSum > 0 ? (netProfit / incSum * 100) : 0.0;

      setState(() {
        _totalIncome = incSum;
        _totalExpenses = expSum;
        _totalSavings = savSum;
        _netProfit = netProfit;
        _profitMargin = margin;
        _memberCount = mCount > 0 ? mCount : 10;
        _incomeBreakdown = incByCat.entries
            .map((e) => {'category': e.key, 'amount': e.value})
            .toList()
          ..sort((a, b) => (b['amount'] as double).compareTo(a['amount'] as double));
        _expenseBreakdown = expByCat.entries
            .map((e) => {'category': e.key, 'amount': e.value})
            .toList()
          ..sort((a, b) => (b['amount'] as double).compareTo(a['amount'] as double));
      });
    } catch (e) {
      debugPrint('Error loading P&L data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _isDateInRange(String dateStr, DateTime? start, DateTime? end) {
    if (start == null || end == null) return true; // All time
    if (dateStr.isEmpty) return false;

    try {
      DateTime? d;
      if (dateStr.length >= 10) {
        final cleanDate = dateStr.substring(0, 10);
        d = DateTime.tryParse(cleanDate);
      } else {
        d = DateTime.tryParse(dateStr);
      }
      if (d == null) return false;

      final startOnly = DateTime(start.year, start.month, start.day);
      final endOnly = DateTime(end.year, end.month, end.day, 23, 59, 59);

      return (d.isAfter(startOnly.subtract(const Duration(seconds: 1))) &&
          d.isBefore(endOnly.add(const Duration(seconds: 1))));
    } catch (_) {
      return false;
    }
  }

  void _prevMonth() {
    setState(() {
      _filterMode = 'monthly';
      if (_selectedMonth == 1) {
        _selectedMonth = 12;
        _selectedYear -= 1;
      } else {
        _selectedMonth -= 1;
      }
    });
    _loadPnL();
  }

  void _nextMonth() {
    setState(() {
      _filterMode = 'monthly';
      if (_selectedMonth == 12) {
        _selectedMonth = 1;
        _selectedYear += 1;
      } else {
        _selectedMonth += 1;
      }
    });
    _loadPnL();
  }

  void _setCurrentMonth() {
    final now = DateTime.now();
    setState(() {
      _filterMode = 'monthly';
      _selectedYear = now.year;
      _selectedMonth = now.month;
    });
    _loadPnL();
  }

  Future<void> _pickMonthYearCalendar() async {
    int tempYear = _selectedYear;
    int tempMonth = _selectedMonth;

    final picked = await showDialog<Map<String, int>>(
      context: context,
      builder: (dlgContext) {
        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_month_rounded, color: AppColors.primary, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'महिना व वर्ष निवडा (Select Month)',
                        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Year Navigator Row
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left_rounded, color: AppColors.primary),
                            onPressed: () => setDlgState(() => tempYear--),
                          ),
                          Text(
                            '$tempYear',
                            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
                            onPressed: () => setDlgState(() => tempYear++),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 12 Months Grid
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(12, (index) {
                        final mNum = index + 1;
                        final isSelected = (mNum == tempMonth);
                        final isCurrent = (mNum == DateTime.now().month && tempYear == DateTime.now().year);

                        return SizedBox(
                          width: 105,
                          child: InkWell(
                            onTap: () {
                              Navigator.pop(ctx, {'year': tempYear, 'month': mNum});
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary
                                    : (isCurrent ? AppColors.primary.withOpacity(0.12) : Colors.grey.shade100),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : (isCurrent ? AppColors.primary : Colors.grey.shade300),
                                  width: isSelected || isCurrent ? 1.5 : 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    _marathiMonths[index],
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected ? Colors.white : AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    _englishMonths[index],
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      color: isSelected ? Colors.white70 : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    final now = DateTime.now();
                    Navigator.pop(ctx, {'year': now.year, 'month': now.month});
                  },
                  child: const Text('चालू महिना (Current)'),
                ),
              ],
            );
          },
        );
      },
    );

    if (picked != null) {
      setState(() {
        _filterMode = 'monthly';
        _selectedYear = picked['year']!;
        _selectedMonth = picked['month']!;
      });
      _loadPnL();
    }
  }

  Future<void> _pickCustomDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: DateTimeRange(start: _customStartDate, end: _customEndDate),
      helpText: 'नफा-तोटा कालावधी निवडा (Date Range)',
      saveText: 'निवडा (Select)',
      cancelText: 'रद्द करा (Cancel)',
    );

    if (picked != null) {
      setState(() {
        _filterMode = 'custom';
        _customStartDate = picked.start;
        _customEndDate = picked.end;
      });
      _loadPnL();
    }
  }

  Future<void> _exportPdfReport() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final group = auth.currentGroup;

    Uint8List? logoBytes = ImageHelper.getDecodedBytes(group?.logoUrl);
    if (logoBytes == null || logoBytes.isEmpty) {
      logoBytes = ImageHelper.getDecodedBytes(auth.currentProfile?.profilePhotoUrl);
    }

    final records = <Map<String, dynamic>>[
      {
        'particulars': '१. एकूण जमा उत्पन्न (Total Revenue)',
        'amount': _totalIncome,
        'notes': 'कर्ज व्याज, विलंब शुल्क, प्रवेश फी व इतर जमा',
      },
      {
        'particulars': '२. वजा: एकूण प्रशासकीय खर्च (Expenses)',
        'amount': _totalExpenses,
        'notes': 'स्टेशनरी, प्रवास, मेळावे, चहापान व इतर खर्च',
      },
      {
        'particulars': '३. गटाचा निव्वळ वाटपयोग्य नफा (Net Profit)',
        'amount': _netProfit,
        'notes': _netProfit >= 0 ? 'सभासदांमध्ये लाभांश वाटपासाठी उपलब्ध' : 'तोटा',
      },
      {
        'particulars': '४. जमा मासिक बचत (Monthly Savings)',
        'amount': _totalSavings,
        'notes': 'या कालावधीतील सभासदांचे जमा बचत भांडवल',
      },
      {
        'particulars': '५. प्रति सदस्य अंदाजे लाभांश (Est. Dividend)',
        'amount': _memberCount > 0 && _netProfit > 0 ? (_netProfit / _memberCount) : 0.0,
        'notes': 'एकूण $_memberCount सक्रिय सभासदांसाठी',
      },
    ];

    const reportDef = ReportDefinition(
      id: 'profit_loss',
      titleMr: '१५. नफा-तोटा ताळेबंद पत्रक (Profit & Loss Statement)',
      titleEn: '15. Profit & Loss Statement',
      subtitle: 'गटाचे उत्पन्न, खर्च व निव्वळ वाटपयोग्य नफा ताळेबंद',
      category: ReportCategory.financial,
      icon: Icons.analytics,
      supabaseTable: 'incomes',
      dateField: 'income_date',
      columns: [
        ReportColumn(key: 'particulars', labelMr: 'तपशील (Particulars)', labelEn: 'Particulars', flex: 2.5),
        ReportColumn(key: 'amount', labelMr: 'रक्कम (₹)', labelEn: 'Amount (Rs)', isNumeric: true, isCurrency: true, flex: 1.5),
        ReportColumn(key: 'notes', labelMr: 'शेरा / तपशील', labelEn: 'Notes', flex: 2.0),
      ],
    );

    await BachatGatPdfTemplate.printOrPreviewReport(
      report: reportDef,
      records: records,
      fromDate: _filterMode == 'monthly'
          ? DateTime(_selectedYear, _selectedMonth, 1)
          : _customStartDate,
      toDate: _filterMode == 'monthly'
          ? DateTime(_selectedYear, _selectedMonth + 1, 0)
          : _customEndDate,
      groupName: group?.groupName ?? 'महिला बचत गट',
      groupAddress: group != null ? '${group.village}, ${group.taluka}, ${group.district}' : null,
      registrationNumber: group?.registrationNumber,
      logoBytes: logoBytes,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 768;
    final isProfit = _netProfit >= 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
          : SingleChildScrollView(
              padding: EdgeInsets.all(isDesktop ? 24 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Header with title and Action Buttons
                  _buildHeader(isDesktop),
                  const SizedBox(height: 16),

                  // 2. Interactive Calendar & Date Filter Bar
                  _buildDateFilterBar(isDesktop),
                  const SizedBox(height: 20),

                  // 3. Top 4 Metric Cards
                  _buildSummaryCards(isDesktop, isProfit),
                  const SizedBox(height: 20),

                  // 4. Formal P&L Statement Table
                  _buildFinancialStatementCard(isDesktop, isProfit),
                  const SizedBox(height: 20),

                  // 5. Detailed Breakdown: Income Side & Expense Side
                  if (isDesktop)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildIncomeBreakdownCard()),
                        const SizedBox(width: 20),
                        Expanded(child: _buildExpenseBreakdownCard()),
                      ],
                    )
                  else ...[
                    _buildIncomeBreakdownCard(),
                    const SizedBox(height: 16),
                    _buildExpenseBreakdownCard(),
                  ],
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  // Header
  Widget _buildHeader(bool isDesktop) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.tr('१५. नफा-तोटा व्यवस्थापन (Profit & Loss)', '15. Profit & Loss Management'),
                style: GoogleFonts.poppins(fontSize: isDesktop ? 22 : 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                AppStrings.tr('गटाचे उत्पन्न, खर्च व निव्वळ वाटपयोग्य नफा ताळेबंद पत्रक', 'Group Revenue, Operating Expenses & Net Distributable Profit'),
                style: GoogleFonts.poppins(fontSize: isDesktop ? 13 : 11, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        Row(
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: isDesktop ? 16 : 12, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
              label: Text(
                isDesktop ? 'प्रिंट / PDF डाऊनलोड' : 'PDF',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              onPressed: _exportPdfReport,
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'माहिती रिफ्रेश करा (Refresh)',
              icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
              onPressed: _loadPnL,
            ),
          ],
        ),
      ],
    );
  }

  // Interactive Calendar Date Filter Bar
  Widget _buildDateFilterBar(bool isDesktop) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter Mode Selector Chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_month_rounded, size: 16),
                    const SizedBox(width: 6),
                    Text('महिनानिहाय (Monthly)', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12)),
                  ],
                ),
                selected: _filterMode == 'monthly',
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(color: _filterMode == 'monthly' ? Colors.white : AppColors.textPrimary),
                onSelected: (val) {
                  if (val) {
                    setState(() => _filterMode = 'monthly');
                    _loadPnL();
                  }
                },
              ),
              ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.date_range_rounded, size: 16),
                    const SizedBox(width: 6),
                    Text('तारीख निवडा (Date Range)', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12)),
                  ],
                ),
                selected: _filterMode == 'custom',
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(color: _filterMode == 'custom' ? Colors.white : AppColors.textPrimary),
                onSelected: (val) {
                  if (val) {
                    setState(() => _filterMode = 'custom');
                    _pickCustomDateRange();
                  }
                },
              ),
              ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.all_inclusive_rounded, size: 16),
                    const SizedBox(width: 6),
                    Text('सर्व कालावधी (All Time)', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12)),
                  ],
                ),
                selected: _filterMode == 'all',
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(color: _filterMode == 'all' ? Colors.white : AppColors.textPrimary),
                onSelected: (val) {
                  if (val) {
                    setState(() => _filterMode = 'all');
                    _loadPnL();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Calendar Navigation Row
          if (_filterMode == 'monthly')
            Row(
              children: [
                IconButton(
                  tooltip: 'मागील महिना (Previous Month)',
                  icon: const Icon(Icons.chevron_left_rounded, size: 28, color: AppColors.primary),
                  onPressed: _prevMonth,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: InkWell(
                    onTap: _pickMonthYearCalendar,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.calendar_month_rounded, color: AppColors.primary, size: 20),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _periodTitle,
                              style: GoogleFonts.poppins(
                                fontSize: isDesktop ? 15 : 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_drop_down_rounded, color: AppColors.primary, size: 22),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'पुढील महिना (Next Month)',
                  icon: const Icon(Icons.chevron_right_rounded, size: 28, color: AppColors.primary),
                  onPressed: _nextMonth,
                ),
                if (isDesktop) ...[
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.today_rounded, size: 16),
                    label: const Text('चालू महिना'),
                    onPressed: _setCurrentMonth,
                  ),
                ],
              ],
            )
          else if (_filterMode == 'custom')
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _pickCustomDateRange,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.date_range_rounded, color: AppColors.primary, size: 20),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'कालावधी: $_periodTitle',
                              style: GoogleFonts.poppins(
                                fontSize: isDesktop ? 14 : 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.edit_calendar_rounded, color: AppColors.primary, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'गटाच्या स्थापनेपासूनचा संपूर्ण एकूण निव्वळ नफा-तोटा ताळेबंद प्रदर्शित केला आहे.',
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blue.shade900),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // 4 Top Summary Metric Cards
  Widget _buildSummaryCards(bool isDesktop, bool isProfit) {
    final incomeCard = _buildMetricCard(
      title: AppStrings.tr('एकूण जमा उत्पन्न', 'Total Income'),
      amount: _totalIncome,
      subtitle: 'व्याज, दंड, वर्गणी व इतर आवक',
      icon: Icons.trending_up_rounded,
      iconColor: AppColors.success,
      borderColor: AppColors.success.withOpacity(0.3),
      bgColor: AppColors.successBg,
    );

    final expenseCard = _buildMetricCard(
      title: AppStrings.tr('एकूण प्रशासकीय खर्च', 'Total Expenses'),
      amount: _totalExpenses,
      subtitle: 'स्टेशनरी, प्रवास, मेळावा खर्च',
      icon: Icons.trending_down_rounded,
      iconColor: AppColors.danger,
      borderColor: AppColors.danger.withOpacity(0.3),
      bgColor: AppColors.dangerBg,
    );

    final savingsCard = _buildMetricCard(
      title: AppStrings.tr('चालू बचत जमा', 'Monthly Savings'),
      amount: _totalSavings,
      subtitle: 'सभासदांचे जमा बचत भांडवल',
      icon: Icons.savings_rounded,
      iconColor: AppColors.primary,
      borderColor: AppColors.primary.withOpacity(0.3),
      bgColor: const Color(0xFFEFF6FF),
    );

    // Card 4: Explicitly Net Profit
    final profitCard = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isProfit
              ? [const Color(0xFF0F9D58), const Color(0xFF00897B)]
              : [const Color(0xFFE53935), const Color(0xFFC62828)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: (isProfit ? const Color(0xFF0F9D58) : const Color(0xFFE53935)).withOpacity(0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isProfit ? Icons.monetization_on_rounded : Icons.warning_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isProfit
                        ? AppStrings.tr('गटाचा निव्वळ नफा (Profit)', 'Net Profit')
                        : AppStrings.tr('गटाचा निव्वळ तोटा (Loss)', 'Net Loss'),
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isProfit ? 'नफा' : 'तोटा',
                  style: GoogleFonts.poppins(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${isProfit ? "+" : ""}₹ ${_netProfit.toStringAsFixed(2)}',
            style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(
            isProfit
                ? 'नफा प्रमाण: ${_profitMargin.toStringAsFixed(1)}% (वाटपयोग्य)'
                : 'खर्च उत्पन्नापेक्षा जास्त झाला आहे',
            style: GoogleFonts.poppins(fontSize: 11, color: Colors.white.withOpacity(0.85), fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );

    if (isDesktop) {
      return Row(
        children: [
          Expanded(child: incomeCard),
          const SizedBox(width: 12),
          Expanded(child: expenseCard),
          const SizedBox(width: 12),
          Expanded(child: savingsCard),
          const SizedBox(width: 12),
          Expanded(child: profitCard),
        ],
      );
    } else {
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: incomeCard),
              const SizedBox(width: 10),
              Expanded(child: expenseCard),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: savingsCard),
              const SizedBox(width: 10),
              Expanded(child: profitCard),
            ],
          ),
        ],
      );
    }
  }

  Widget _buildMetricCard({
    required String title,
    required double amount,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color borderColor,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '₹ ${amount.toStringAsFixed(2)}',
            style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: iconColor),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // Formal Bachatgat Financial Statement Card
  Widget _buildFinancialStatementCard(bool isDesktop, bool isProfit) {
    final estDividend = (_memberCount > 0 && _netProfit > 0) ? (_netProfit / _memberCount) : 0.0;

    return AppCard(
      padding: const EdgeInsets.all(20),
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
                    child: const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'ताळेबंद सारांश (P&L Financial Statement)',
                    style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isProfit ? AppColors.successBg : AppColors.dangerBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isProfit ? AppColors.success : AppColors.danger),
                ),
                child: Text(
                  isProfit ? 'नफ्यात आहे (In Profit)' : 'तोट्यात आहे (In Deficit)',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isProfit ? AppColors.success : AppColors.danger,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),

          _buildStatementRow('१. एकूण जमा उत्पन्न (Gross Revenue / Incomes):', '₹ ${_totalIncome.toStringAsFixed(2)}', isBold: true, color: AppColors.success),
          const SizedBox(height: 8),
          _buildStatementRow('२. वजा: एकूण प्रशासकीय व इतर खर्च (Operating Expenses):', '- ₹ ${_totalExpenses.toStringAsFixed(2)}', isBold: true, color: AppColors.danger),
          const Divider(height: 18),
          _buildStatementRow(
            '३. गटाचा निव्वळ नफा / तोटा (Net Profit / Loss):',
            '${isProfit ? "+" : ""}₹ ${_netProfit.toStringAsFixed(2)}',
            isBold: true,
            fontSize: 15,
            color: isProfit ? AppColors.success : AppColors.danger,
          ),
          const SizedBox(height: 10),
          _buildStatementRow('४. या कालावधीतील जमा बचत भांडवल (Monthly Savings):', '₹ ${_totalSavings.toStringAsFixed(2)}', color: AppColors.primary),
          const SizedBox(height: 8),
          _buildStatementRow(
            '५. प्रति सदस्य संभाव्य लाभांश वाटप (Est. Dividend Per Member):',
            '₹ ${estDividend.toStringAsFixed(2)} / सदस्य (एकूण $_memberCount सभासद)',
            color: Colors.purple.shade700,
            isBold: true,
          ),
        ],
      ),
    );
  }

  Widget _buildStatementRow(String label, String value, {bool isBold = false, double fontSize = 13, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
            color: color ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  // Income Sources Breakdown Card
  Widget _buildIncomeBreakdownCard() {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.arrow_circle_down_rounded, color: AppColors.success, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    AppStrings.tr('जमा बाजू (Income Sources)', 'Income Breakdown'),
                    style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.success),
                  ),
                ],
              ),
              Text(
                '₹ ${_totalIncome.toStringAsFixed(2)}',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: AppColors.success),
              ),
            ],
          ),
          const Divider(height: 20),
          if (_incomeBreakdown.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.inbox_rounded, size: 36, color: Colors.grey.shade400),
                    const SizedBox(height: 8),
                    Text('या कालावधीत कोणतीही उत्पन्न नोंद नाही', style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 13)),
                  ],
                ),
              ),
            )
          else
            ..._incomeBreakdown.map((item) {
              final amt = item['amount'] as double;
              final pct = _totalIncome > 0 ? (amt / _totalIncome * 100) : 0.0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item['category']?.toString() ?? '',
                            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          '₹ ${amt.toStringAsFixed(2)} (${pct.toStringAsFixed(1)}%)',
                          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.success),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: _totalIncome > 0 ? (amt / _totalIncome).clamp(0.0, 1.0) : 0.0,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.success),
                      minHeight: 4,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // Expense Breakdown Card
  Widget _buildExpenseBreakdownCard() {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.arrow_circle_up_rounded, color: AppColors.danger, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    AppStrings.tr('नावे / खर्च बाजू (Expenses)', 'Expense Breakdown'),
                    style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.danger),
                  ),
                ],
              ),
              Text(
                '₹ ${_totalExpenses.toStringAsFixed(2)}',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: AppColors.danger),
              ),
            ],
          ),
          const Divider(height: 20),
          if (_expenseBreakdown.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.inbox_rounded, size: 36, color: Colors.grey.shade400),
                    const SizedBox(height: 8),
                    Text('या कालावधीत कोणतीही खर्च नोंद नाही', style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 13)),
                  ],
                ),
              ),
            )
          else
            ..._expenseBreakdown.map((item) {
              final amt = item['amount'] as double;
              final pct = _totalExpenses > 0 ? (amt / _totalExpenses * 100) : 0.0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item['category']?.toString() ?? '',
                            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          '₹ ${amt.toStringAsFixed(2)} (${pct.toStringAsFixed(1)}%)',
                          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.danger),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: _totalExpenses > 0 ? (amt / _totalExpenses).clamp(0.0, 1.0) : 0.0,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.danger),
                      minHeight: 4,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
