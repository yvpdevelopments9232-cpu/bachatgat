import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/monthly_bachatgat_report_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/excel_export_service.dart';
import '../../services/monthly_bachatgat_pdf_exporter.dart';
import '../../services/monthly_bachatgat_report_service.dart';

class MonthlyBachatgatReportScreen extends StatefulWidget {
  final int? initialMonth;
  final int? initialYear;

  const MonthlyBachatgatReportScreen({
    super.key,
    this.initialMonth,
    this.initialYear,
  });

  @override
  State<MonthlyBachatgatReportScreen> createState() => _MonthlyBachatgatReportScreenState();
}

class _MonthlyBachatgatReportScreenState extends State<MonthlyBachatgatReportScreen> {
  final MonthlyBachatgatReportService _service = MonthlyBachatgatReportService();
  final NumberFormat _numFormat = NumberFormat('#,##,###', 'en_IN');

  late int _selectedMonth;
  late int _selectedYear;
  bool _isLoading = true;
  String? _errorMessage;
  MonthlyBachatgatReportData? _reportData;
  String _searchFilter = '';

  // Marathi month list
  final List<int> _months = List.generate(12, (i) => i + 1);
  final List<int> _years = List.generate(16, (i) => 2020 + i);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = widget.initialMonth ?? now.month;
    _selectedYear = widget.initialYear ?? now.year;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadReport();
    });
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final group = auth.currentGroup;
      if (group == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'कृपया प्रथम बचत गट निवडा!';
        });
        return;
      }

      final data = await _service.fetchReportData(
        groupId: group.id,
        groupName: group.groupName,
        month: _selectedMonth,
        year: _selectedYear,
        group: group,
      );

      setState(() {
        _reportData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'अहवाल लोड करताना त्रुटी: $e';
        _isLoading = false;
      });
    }
  }

  String _formatAmount(double amt, {bool blankIfZero = false}) {
    if (blankIfZero && amt <= 0.001) return '';
    return _numFormat.format(amt.round());
  }

  @override
  Widget build(BuildContext context) {
    final data = _reportData;

    // Filter rows by search
    final rows = (data?.rows ?? []).where((r) {
      if (_searchFilter.trim().isEmpty) return true;
      final q = _searchFilter.trim().toLowerCase();
      return r.memberName.toLowerCase().contains(q) ||
          (r.memberCode != null && r.memberCode!.toLowerCase().contains(q));
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(
          'मासिक बचत अहवाल (Monthly Report)',
          style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        actions: [
          if (data != null) ...[
            IconButton(
              icon: const Icon(Icons.print_rounded),
              tooltip: 'प्रिंट करा (Print)',
              onPressed: () => MonthlyBachatgatPdfExporter.printReport(data),
            ),
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_rounded),
              tooltip: 'PDF एक्सपोर्ट करा',
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final path = await MonthlyBachatgatPdfExporter.exportPdf(data);
                if (path != null) {
                  messenger.showSnackBar(
                    SnackBar(
                      backgroundColor: AppColors.success,
                      content: Text('PDF सेव्ह झाली: $path'),
                    ),
                  );
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.table_chart_rounded),
              tooltip: 'Excel एक्सपोर्ट (.csv)',
              onPressed: () => ExcelExportService.exportMonthlyBachatgatExcel(data),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
      body: Column(
        children: [
          // 1. FILTER BAR
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Wrap(
              spacing: 16,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Month Selector
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('महिना: ', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(6),
                        color: Colors.grey.shade50,
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _selectedMonth,
                          items: _months.map((m) {
                            return DropdownMenuItem<int>(
                              value: m,
                              child: Text(
                                MonthlyBachatgatReportData.marathiMonths[m] ?? 'महिना $m',
                                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedMonth = val);
                              _loadReport();
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),

                // Year Selector
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('वर्ष: ', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(6),
                        color: Colors.grey.shade50,
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _selectedYear,
                          items: _years.map((y) {
                            return DropdownMenuItem<int>(
                              value: y,
                              child: Text(
                                y.toString(),
                                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedYear = val);
                              _loadReport();
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),

                // Quick Search Member
                SizedBox(
                  width: 180,
                  height: 38,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'सभासद शोधा...',
                      hintStyle: GoogleFonts.poppins(fontSize: 12),
                      prefixIcon: const Icon(Icons.search, size: 16),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onChanged: (val) => setState(() => _searchFilter = val),
                  ),
                ),

                // Refresh Button
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: Text('रीफ्रेश (Load)', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                  onPressed: _loadReport,
                ),
              ],
            ),
          ),

          // 2. EXCEL LEDGER SHEET VIEW
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
                    : data == null || rows.isEmpty
                        ? const Center(child: Text('या महिन्यासाठी कोणतीही नोंद उपलब्ध नाही.'))
                        : SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Center(
                              child: Container(
                                constraints: const BoxConstraints(maxWidth: 1100),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.08),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    // A. TOP BLUE HEADER BANNER (बचत महिना : सप्टेंबर २०२६)
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFD9E1F2), // Light blue matching mockup
                                        border: Border(
                                          top: BorderSide(color: Color(0xFF8EA9DB), width: 1.5),
                                          left: BorderSide(color: Color(0xFF8EA9DB), width: 1.5),
                                          right: BorderSide(color: Color(0xFF8EA9DB), width: 1.5),
                                          bottom: BorderSide(color: Color(0xFF8EA9DB), width: 1.5),
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          'बचत महिना : ${data.monthNameMr} ${data.year}',
                                          style: GoogleFonts.poppins(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFF1F497D),
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ),

                                    // B. TABLE CONTAINER (Horizontal Scrollable on Mobile)
                                    SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Container(
                                        constraints: const BoxConstraints(minWidth: 960),
                                        child: Table(
                                          border: TableBorder.all(
                                            color: const Color(0xFF7F7F7F),
                                            width: 0.8,
                                          ),
                                          columnWidths: const {
                                            0: FixedColumnWidth(48), // अ.नं
                                            1: FixedColumnWidth(170), // सभासदाचे नाव
                                            2: FixedColumnWidth(105), // कर्ज आजअखेर
                                            3: FixedColumnWidth(95), // दिलेले कर्ज
                                            4: FixedColumnWidth(80), // महिना बचत
                                            5: FixedColumnWidth(110), // एकूण बचत आजअखेर
                                            6: FixedColumnWidth(80), // हप्ता
                                            7: FixedColumnWidth(80), // व्याज
                                            8: FixedColumnWidth(90), // आजची एकूण
                                            9: FixedColumnWidth(110), // या महिन्यात अखेर शिल्लक कर्ज
                                          },
                                          children: [
                                            // Table Header matching reference image colors
                                            _buildHeaderRow(),

                                            // Data Rows
                                            ...rows.map((r) => _buildDataRow(r)),

                                            // Totals Row
                                            _buildTotalRow(data),
                                          ],
                                        ),
                                      ),
                                    ),

                                    // C. BOTTOM BLUE FOOTER BOX (कर्जदार: सुरज कांबळे 96000₹)
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFD9E1F2),
                                        border: Border(
                                          left: BorderSide(color: Color(0xFF8EA9DB), width: 1.5),
                                          right: BorderSide(color: Color(0xFF8EA9DB), width: 1.5),
                                          bottom: BorderSide(color: Color(0xFF8EA9DB), width: 1.5),
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          data.newBorrowers.isNotEmpty
                                              ? 'कर्जदार: ${data.newBorrowers.map((b) => "${b.memberName} ${_formatAmount(b.amount)}₹").join(' , ')}'
                                              : 'कर्जदार: या महिन्यात कोणतेही नवीन कर्ज वाटप नाही',
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFF1F497D),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  TableRow _buildHeaderRow() {
    const headerGray = Color(0xFFE9EDF4);
    const headerGreen = Color(0xFFC6EFCE); // कर्ज आजअखेर
    const headerYellow = Color(0xFFFFF2CC); // दिलेले कर्ज
    const headerOrange = Color(0xFFFCE4D6); // अखेर शिल्लक कर्ज

    return TableRow(
      children: [
        _th('अ. नं', bg: headerGray),
        _th('सभासदाचे नाव', bg: headerGray),
        _th('कर्ज\nआजअखेर', bg: headerGreen),
        _th('दिलेले कर्ज', bg: headerYellow),
        _th('महिना\nबचत', bg: headerGray),
        _th('एकूण बचत\nआजअखेर', bg: headerGray),
        _th('हप्ता', bg: headerGray),
        _th('व्याज', bg: headerGray),
        _th('आजची\nएकूण', bg: headerGray),
        _th('या महिन्यात\nअखेर\nशिल्लक कर्ज', bg: headerOrange),
      ],
    );
  }

  Widget _th(String label, {required Color bg}) {
    return Container(
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      alignment: Alignment.center,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.black87,
          height: 1.2,
        ),
      ),
    );
  }

  TableRow _buildDataRow(MonthlyBachatgatReportRow r) {
    const bgGreen = Color(0xFFC6EFCE);
    const bgYellow = Color(0xFFFFF2CC);
    const bgOrange = Color(0xFFFCE4D6);

    return TableRow(
      children: [
        // 1. अ.नं
        _td(r.srNo.toString(), align: Alignment.center),

        // 2. सभासदाचे नाव
        _td(r.memberName, align: Alignment.centerLeft, isBold: true),

        // 3. कर्ज आजअखेर (Green)
        _td(_formatAmount(r.openingLoan), bg: bgGreen, isBold: true),

        // 4. दिलेले कर्ज (Yellow, blank if 0)
        _td(_formatAmount(r.newLoan, blankIfZero: true), bg: bgYellow, isBold: true),

        // 5. महिना बचत
        _td(_formatAmount(r.monthlySaving)),

        // 6. एकूण बचत आजअखेर
        _td(_formatAmount(r.cumulativeSavings)),

        // 7. हप्ता
        _td(_formatAmount(r.installment)),

        // 8. व्याज
        _td(_formatAmount(r.interest)),

        // 9. आजची एकूण
        _td(_formatAmount(r.todayTotal), isBold: true),

        // 10. या महिन्यात अखेर शिल्लक कर्ज (Orange)
        _td(_formatAmount(r.closingLoan), bg: bgOrange, isBold: true),
      ],
    );
  }

  TableRow _buildTotalRow(MonthlyBachatgatReportData data) {
    const bgGreen = Color(0xFFC6EFCE);
    const bgYellow = Color(0xFFFFF2CC);
    const bgOrange = Color(0xFFFCE4D6);

    return TableRow(
      decoration: const BoxDecoration(color: Colors.white),
      children: [
        // 1. अ.नं (blank)
        _td('', align: Alignment.center),

        // 2. एकूण जमा:
        _td('एकूण जमा:', align: Alignment.centerRight, isBold: true),

        // 3. कर्ज आजअखेर total
        _td(_formatAmount(data.totalOpeningLoan), bg: bgGreen, isBold: true),

        // 4. दिलेले कर्ज total
        _td(_formatAmount(data.totalNewLoan, blankIfZero: true), bg: bgYellow, isBold: true),

        // 5. महिना बचत total
        _td(_formatAmount(data.totalMonthlySaving), isBold: true),

        // 6. एकूण बचत आजअखेर total
        _td(_formatAmount(data.totalCumulativeSavings), isBold: true),

        // 7. हप्ता total
        _td(_formatAmount(data.totalInstallment), isBold: true),

        // 8. व्याज total
        _td(_formatAmount(data.totalInterest), isBold: true),

        // 9. आजची एकूण total
        _td(_formatAmount(data.totalTodayTotal), isBold: true),

        // 10. या महिन्यात अखेर शिल्लक कर्ज total
        _td(_formatAmount(data.totalClosingLoan), bg: bgOrange, isBold: true),
      ],
    );
  }

  Widget _td(
    String text, {
    Alignment align = Alignment.centerRight,
    Color? bg,
    bool isBold = false,
  }) {
    return Container(
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      alignment: align,
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 11.5,
          fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
          color: Colors.black87,
        ),
      ),
    );
  }
}
