import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf_text_shaper/pdf_text_shaper.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/image_helper.dart';
import '../../models/member.dart';
import '../../providers/auth_provider.dart';
import '../../services/monthly_bachatgat_pdf_exporter.dart';
import '../../services/supabase_service.dart';

class IndividualMemberReportScreen extends StatefulWidget {
  final String? preSelectedMemberId;

  const IndividualMemberReportScreen({
    super.key,
    this.preSelectedMemberId,
  });

  @override
  State<IndividualMemberReportScreen> createState() => _IndividualMemberReportScreenState();
}

class _IndividualMemberReportScreenState extends State<IndividualMemberReportScreen> {
  final SupabaseService _service = SupabaseService();
  final NumberFormat _numFormat = NumberFormat('#,##,###', 'en_IN');
  final DateFormat _dateFormat = DateFormat('dd-MM-yyyy');

  late DateTime _fromDate;
  late DateTime _toDate;
  String? _selectedMemberId;

  bool _isLoading = true;
  String? _errorMessage;

  List<Member> _allMembers = [];
  Member? _currentMember;

  // Summaries
  double _totalSavings = 0.0;
  double _givenLoanAmount = 0.0;
  double _paidLoanPrincipal = 0.0;
  double _paidInterest = 0.0;
  double _paidLateFee = 0.0;
  double _remainingLoanAmount = 0.0;

  // History tables
  List<Map<String, dynamic>> _loans = [];
  List<Map<String, dynamic>> _emis = [];
  List<Map<String, dynamic>> _savings = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _fromDate = DateTime(now.year, 1, 1);
    _toDate = DateTime(now.year, 12, 31);
    _selectedMemberId = widget.preSelectedMemberId;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMembersAndData();
    });
  }

  Future<void> _loadMembersAndData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final group = auth.currentGroup;
    if (group == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'कृपया प्रथम बचत गट निवडा!';
      });
      return;
    }

    try {
      // 1. Fetch all members
      final mRes = await _service.client
          .from('members')
          .select()
          .eq('group_id', group.id)
          .order('member_code', ascending: true);
      _allMembers = (mRes as List).map((r) => Member.fromJson(r)).toList();

      if (_allMembers.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'या गटात कोणतेही सभासद उपलब्ध नाहीत.';
        });
        return;
      }

      if (_selectedMemberId == null || !_allMembers.any((m) => m.id == _selectedMemberId)) {
        _selectedMemberId = _allMembers.first.id;
      }

      await _fetchMemberDetails();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'माहिती आणताना त्रुटी: $e';
      });
    }
  }

  Future<void> _fetchMemberDetails() async {
    if (_selectedMemberId == null) return;
    setState(() => _isLoading = true);

    try {
      _currentMember = _allMembers.firstWhere(
        (m) => m.id == _selectedMemberId,
        orElse: () => _allMembers.first,
      );

      final fromStr = DateFormat('yyyy-MM-dd').format(_fromDate);
      final toStr = DateFormat('yyyy-MM-dd').format(_toDate);

      // 1. Fetch Savings in range
      final sRes = await _service.client
          .from('savings')
          .select()
          .eq('member_id', _selectedMemberId!)
          .gte('savings_date', fromStr)
          .lte('savings_date', toStr)
          .order('savings_date', ascending: false);
      _savings = List<Map<String, dynamic>>.from(sRes as List);

      // 2. Cumulative Savings (including before date)
      final allSavRes = await _service.client
          .from('savings')
          .select('amount')
          .eq('member_id', _selectedMemberId!)
          .lte('savings_date', toStr);
      double sumSav = 0.0;
      for (var row in (allSavRes as List)) {
        sumSav += (row['amount'] as num?)?.toDouble() ?? 0.0;
      }
      _totalSavings = sumSav;

      // 3. Fetch Loans
      final lRes = await _service.client
          .from('loans')
          .select()
          .eq('member_id', _selectedMemberId!)
          .order('disbursement_date', ascending: false);
      _loans = List<Map<String, dynamic>>.from(lRes as List);

      double sumGivenLoan = 0.0;
      for (var l in _loans) {
        sumGivenLoan += (l['approved_amount'] as num?)?.toDouble() ?? (l['requested_amount'] as num?)?.toDouble() ?? 0.0;
      }
      _givenLoanAmount = sumGivenLoan;

      // 4. Fetch EMIs by member's loan IDs
      final loanIds = _loans.map((l) => l['id']?.toString() ?? '').where((id) => id.isNotEmpty).toSet();
      List<Map<String, dynamic>> allMemberEmis = [];

      if (loanIds.isNotEmpty) {
        if (!mounted) return;
        final auth = Provider.of<AuthProvider>(context, listen: false);
        final gId = auth.currentGroup?.id;
        if (gId != null) {
          final allEmisRes = await _service.client
              .from('loan_emis')
              .select()
              .eq('group_id', gId);
          final allEmisList = List<Map<String, dynamic>>.from(allEmisRes as List);
          allMemberEmis = allEmisList.where((e) {
            final lId = e['loan_id']?.toString() ?? '';
            return loanIds.contains(lId);
          }).toList();
        }
      }

      // Filter EMIs for selected date range
      _emis = allMemberEmis.where((e) {
        final pDate = e['payment_date']?.toString() ?? e['created_at']?.toString() ?? '';
        final cleanDate = pDate.length >= 10 ? pDate.substring(0, 10) : pDate;
        return cleanDate.isNotEmpty && cleanDate.compareTo(fromStr) >= 0 && cleanDate.compareTo(toStr) <= 0;
      }).toList();
      _emis.sort((a, b) => (b['payment_date'] ?? b['created_at'] ?? '').toString().compareTo((a['payment_date'] ?? a['created_at'] ?? '').toString()));

      // Cumulative loan repayments up to toDate
      double sumPrincipal = 0.0;
      double sumInterest = 0.0;
      double sumLateFee = 0.0;
      for (var emi in allMemberEmis) {
        final pDate = emi['payment_date']?.toString() ?? emi['created_at']?.toString() ?? '';
        final cleanDate = pDate.length >= 10 ? pDate.substring(0, 10) : pDate;
        if (cleanDate.isNotEmpty && cleanDate.compareTo(toStr) <= 0) {
          final p = (emi['principal'] as num?)?.toDouble();
          final paid = (emi['paid_amount'] as num?)?.toDouble() ?? 0.0;
          final intr = (emi['interest'] as num?)?.toDouble() ?? 0.0;
          final fee = (emi['late_fee'] as num?)?.toDouble() ?? 0.0;

          sumPrincipal += (p != null && p > 0) ? p : math.max(0.0, paid - intr - fee);
          sumInterest += intr;
          sumLateFee += fee;
        }
      }

      _paidLoanPrincipal = sumPrincipal > 0 ? sumPrincipal : 0.0;
      _paidInterest = sumInterest;
      _paidLateFee = sumLateFee;

      // Outstanding loan balance calculation
      if (_givenLoanAmount > 0) {
        _remainingLoanAmount = math.max(0.0, _givenLoanAmount - _paidLoanPrincipal);
      } else {
        _remainingLoanAmount = 0.0;
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'सभासद तपशील लोड करताना त्रुटी: $e';
      });
    }
  }

  String _formatAmt(num? val) {
    if (val == null) return '₹ 0';
    return '₹ ${_numFormat.format(val.round())}';
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final group = auth.currentGroup;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(
          'व्यक्तिगत सभासद अहवाल (Member Statement)',
          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_rounded),
            tooltip: 'प्रिंट करा (Print)',
            onPressed: _printReport,
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded),
            tooltip: 'PDF एक्सपोर्ट करा',
            onPressed: _printReport,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // 1. TOP FILTER BAR
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Wrap(
              spacing: 16,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Member Selector
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person_rounded, size: 18, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text('सभासद: ', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                    Container(
                      constraints: const BoxConstraints(maxWidth: 240),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(6),
                        color: Colors.grey.shade50,
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedMemberId,
                          isExpanded: true,
                          items: _allMembers.map((m) {
                            return DropdownMenuItem<String>(
                              value: m.id,
                              child: Text(
                                '${m.fullName} (${m.memberCode})',
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedMemberId = val);
                              _fetchMemberDetails();
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),

                // From Date
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('पासून: ', style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600)),
                    InkWell(
                      onTap: () => _pickDate(isFrom: true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(6),
                          color: Colors.grey.shade50,
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_month, size: 16, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Text(_dateFormat.format(_fromDate), style: GoogleFonts.poppins(fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // To Date
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('पर्यंत: ', style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600)),
                    InkWell(
                      onTap: () => _pickDate(isFrom: false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(6),
                          color: Colors.grey.shade50,
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_month, size: 16, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Text(_dateFormat.format(_toDate), style: GoogleFonts.poppins(fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // Apply Button
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  icon: const Icon(Icons.search, size: 16),
                  label: Text('अहवाल पहा', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                  onPressed: _fetchMemberDetails,
                ),
              ],
            ),
          ),

          // 2. MAIN REPORT CANVAS
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 1000),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4)),
                              ],
                            ),
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // A. OFFICIAL BACHAT GAT HEADER
                                _buildGroupHeader(group?.groupName ?? 'महिला बचत गट'),
                                const Divider(height: 32, thickness: 1.5),

                                // B. MEMBER PROFILE BANNER
                                _buildMemberProfileBanner(),
                                const SizedBox(height: 20),

                                // C. 6 FINANCIAL SUMMARY CARDS
                                Text(
                                  'आर्थिक सारांश (Financial Overview)',
                                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                ),
                                const SizedBox(height: 10),
                                _buildSummaryCards(),
                                const SizedBox(height: 24),

                                // D. LOAN DETAILS (If Any)
                                if (_loans.isNotEmpty) ...[
                                  Text(
                                    'कर्ज तपशील (Loan Sanction Details)',
                                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildLoansTable(),
                                  const SizedBox(height: 24),
                                ],

                                // E. EMI REPAYMENT HISTORY TABLE
                                Text(
                                  'कर्ज हप्ता व व्याज परतफेड इतिहास (EMI Repayment History)',
                                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                ),
                                const SizedBox(height: 8),
                                _buildEmisTable(),
                                const SizedBox(height: 24),

                                // F. SAVINGS HISTORY TABLE
                                Text(
                                  'मासिक बचत जमा इतिहास (Monthly Savings History)',
                                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                ),
                                const SizedBox(height: 8),
                                _buildSavingsTable(),
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

  // --- WIDGET BUILDERS ---

  Widget _buildGroupHeader(String groupName) {
    return Column(
      children: [
        Center(
          child: Text(
            groupName,
            style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w800, color: const Color(0xFF1E3A8A)),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFD9E1F2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'व्यक्तिगत सभासद संपूर्ण अहवाल (Individual Member Comprehensive Statement)',
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1F497D)),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            'अहवाल कालावधी: ${_dateFormat.format(_fromDate)} ते ${_dateFormat.format(_toDate)}',
            style: GoogleFonts.poppins(fontSize: 11.5, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _buildMemberProfileBanner() {
    final m = _currentMember;
    if (m == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primary.withOpacity(0.12),
            child: const Icon(Icons.person, color: AppColors.primary, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Wrap(
              spacing: 24,
              runSpacing: 8,
              children: [
                _infoPair('सभासदाचे नाव', m.fullName, isBold: true),
                _infoPair('सदस्य आयडी', m.memberCode),
                _infoPair('मोबाईल क्र.', m.mobileNumber.isNotEmpty ? m.mobileNumber : '-'),
                if (m.joiningDate != null) _infoPair('नोंदणी तारीख', m.joiningDate!),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoPair(String label, String val, {bool isBold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade600)),
        Text(val, style: GoogleFonts.poppins(fontSize: 13, fontWeight: isBold ? FontWeight.w700 : FontWeight.w600, color: Colors.black87)),
      ],
    );
  }

  Widget _buildSummaryCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 20) / 3;
        final isMobile = constraints.maxWidth < 600;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _kpiCard('एकूण जमा बचत', _formatAmt(_totalSavings), Icons.savings, const Color(0xFF00B074), isMobile ? double.infinity : cardWidth),
            _kpiCard('घेतलेले एकूण कर्ज', _formatAmt(_givenLoanAmount), Icons.monetization_on, const Color(0xFF2563EB), isMobile ? double.infinity : cardWidth),
            _kpiCard('परतफेड केलेले मुद्दल', _formatAmt(_paidLoanPrincipal), Icons.check_circle, const Color(0xFF0284C7), isMobile ? double.infinity : cardWidth),
            _kpiCard('भरलेले एकूण व्याज', _formatAmt(_paidInterest), Icons.percent, const Color(0xFF7C3AED), isMobile ? double.infinity : cardWidth),
            _kpiCard('भरलेला लेट फी/दंड', _formatAmt(_paidLateFee), Icons.warning_amber, const Color(0xFFD97706), isMobile ? double.infinity : cardWidth),
            _kpiCard('शिल्लक बाकी कर्ज', _formatAmt(_remainingLoanAmount), Icons.account_balance_wallet, const Color(0xFFDC2626), isMobile ? double.infinity : cardWidth, isAlert: _remainingLoanAmount > 0),
          ],
        );
      },
    );
  }

  Widget _kpiCard(String title, String amt, IconData icon, Color color, double width, {bool isAlert = false}) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
                Text(amt, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoansTable() {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(6)),
      child: Table(
        columnWidths: const {
          0: FixedColumnWidth(40),
          1: FlexColumnWidth(1.2),
          2: FlexColumnWidth(1.2),
          3: FlexColumnWidth(1.0),
          4: FlexColumnWidth(0.8),
          5: FlexColumnWidth(1.2),
          6: FlexColumnWidth(1.0),
        },
        children: [
          TableRow(
            decoration: BoxDecoration(color: Colors.grey.shade100),
            children: const [
              _TableH('#'),
              _TableH('कर्ज कोड'),
              _TableH('मंजूर रक्कम'),
              _TableH('वाटप तारीख'),
              _TableH('व्याज दर'),
              _TableH('शिल्लक मुद्दल'),
              _TableH('स्थिती'),
            ],
          ),
          ..._loans.asMap().entries.map((e) {
            final idx = e.key + 1;
            final l = e.value;
            final code = l['loan_code']?.toString() ?? '-';
            final amt = (l['approved_amount'] as num?)?.toDouble() ?? 0.0;
            final date = l['disbursement_date']?.toString() ?? '-';
            final rate = '${l['interest_rate'] ?? 24}%';
            final out = (l['outstanding_principal'] as num?)?.toDouble() ?? 0.0;
            final status = l['status']?.toString() ?? 'active';

            return TableRow(
              children: [
                _TableC(idx.toString(), align: Alignment.center),
                _TableC(code, isBold: true),
                _TableC(_formatAmt(amt), align: Alignment.centerRight),
                _TableC(date, align: Alignment.center),
                _TableC(rate, align: Alignment.center),
                _TableC(_formatAmt(out), align: Alignment.centerRight, color: out > 0 ? Colors.red.shade700 : Colors.green.shade700),
                _TableC(status == 'closed' ? 'पूर्ण फेडले' : 'सक्रिय', align: Alignment.center, color: status == 'closed' ? Colors.green : Colors.blue),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildEmisTable() {
    if (_emis.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(6)),
        child: Center(child: Text('या कालावधीत कोणतीही हप्ता परतफेड नोंद नाही.', style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 12))),
      );
    }

    return Container(
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(6)),
      child: Table(
        columnWidths: const {
          0: FixedColumnWidth(35),
          1: FlexColumnWidth(1.1),
          2: FixedColumnWidth(60),
          3: FlexColumnWidth(1.0),
          4: FlexColumnWidth(0.9),
          5: FlexColumnWidth(0.9),
          6: FlexColumnWidth(1.1),
          7: FlexColumnWidth(0.8),
        },
        children: [
          TableRow(
            decoration: BoxDecoration(color: Colors.grey.shade100),
            children: const [
              _TableH('#'),
              _TableH('भरणा तारीख'),
              _TableH('हप्ता क्र.'),
              _TableH('मुद्दल'),
              _TableH('व्याज'),
              _TableH('दंड'),
              _TableH('एकूण भरणा'),
              _TableH('माध्यम'),
            ],
          ),
          ..._emis.asMap().entries.map((e) {
            final idx = e.key + 1;
            final emi = e.value;
            final pDate = emi['payment_date']?.toString() ?? '-';
            final emiNo = emi['emi_number'] != null ? '#${emi['emi_number']}' : '-';
            final p = (emi['principal'] as num?)?.toDouble() ?? 0.0;
            final i = (emi['interest'] as num?)?.toDouble() ?? 0.0;
            final f = (emi['late_fee'] as num?)?.toDouble() ?? 0.0;
            final total = (emi['paid_amount'] as num?)?.toDouble() ?? (p + i + f);
            final mode = emi['payment_mode']?.toString().toUpperCase() ?? 'CASH';

            return TableRow(
              children: [
                _TableC(idx.toString(), align: Alignment.center),
                _TableC(pDate, align: Alignment.center),
                _TableC(emiNo, align: Alignment.center),
                _TableC(_formatAmt(p), align: Alignment.centerRight),
                _TableC(_formatAmt(i), align: Alignment.centerRight),
                _TableC(_formatAmt(f), align: Alignment.centerRight),
                _TableC(_formatAmt(total), align: Alignment.centerRight, isBold: true),
                _TableC(mode, align: Alignment.center),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSavingsTable() {
    if (_savings.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(6)),
        child: Center(child: Text('या कालावधीत कोणतीही बचत भरणा नोंद नाही.', style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 12))),
      );
    }

    return Container(
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(6)),
      child: Table(
        columnWidths: const {
          0: FixedColumnWidth(35),
          1: FlexColumnWidth(1.1),
          2: FlexColumnWidth(1.1),
          3: FlexColumnWidth(1.0),
          4: FlexColumnWidth(0.8),
          5: FlexColumnWidth(1.2),
        },
        children: [
          TableRow(
            decoration: BoxDecoration(color: Colors.grey.shade100),
            children: const [
              _TableH('#'),
              _TableH('तारीख'),
              _TableH('पावती क्र.'),
              _TableH('जमा रक्कम'),
              _TableH('माध्यम'),
              _TableH('शेरा'),
            ],
          ),
          ..._savings.asMap().entries.map((e) {
            final idx = e.key + 1;
            final s = e.value;
            final sDate = s['savings_date']?.toString() ?? '-';
            final rcpt = s['receipt_number']?.toString() ?? '-';
            final amt = (s['amount'] as num?)?.toDouble() ?? 0.0;
            final mode = s['payment_mode']?.toString().toUpperCase() ?? 'CASH';
            final rem = s['remarks']?.toString() ?? '';

            return TableRow(
              children: [
                _TableC(idx.toString(), align: Alignment.center),
                _TableC(sDate, align: Alignment.center),
                _TableC(rcpt, align: Alignment.center),
                _TableC(_formatAmt(amt), align: Alignment.centerRight, isBold: true, color: const Color(0xFF00B074)),
                _TableC(mode, align: Alignment.center),
                _TableC(rem.isNotEmpty ? rem : '-', align: Alignment.centerLeft),
              ],
            );
          }),
        ],
      ),
    );
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initDate = isFrom ? _fromDate : _toDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _fromDate = picked;
        } else {
          _toDate = picked;
        }
      });
      _fetchMemberDetails();
    }
  }

  Future<void> _printReport() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final group = auth.currentGroup;
    final member = _currentMember;
    if (member == null) return;

    final groupName = group?.groupName ?? 'महिला बचत गट';
    final groupAddress = group != null ? '${group.village}, ${group.taluka}, ${group.district}' : 'पत्ता: महाराष्ट्र';
    final regNo = group?.registrationNumber ?? 'SBG-REG-2024';
    final mobile = group?.mobile ?? member.mobileNumber;

    Uint8List? logoBytes = ImageHelper.getDecodedBytes(group?.logoUrl);
    if (logoBytes == null || logoBytes.isEmpty) {
      logoBytes = ImageHelper.getDecodedBytes(auth.currentProfile?.profilePhotoUrl);
    }
    pw.MemoryImage? safeLogoImage;
    if (logoBytes != null && logoBytes.isNotEmpty) {
      try {
        safeLogoImage = pw.MemoryImage(logoBytes);
      } catch (e) {
        safeLogoImage = null;
      }
    }

    final doc = pw.Document();
    await MonthlyBachatgatPdfExporter.initFonts();

    final devFont = ShapedFont.fromBytes(MonthlyBachatgatPdfExporter.cachedDevRegular!, name: 'NotoSansDevanagari-Regular');
    final devBoldFont = ShapedFont.fromBytes(MonthlyBachatgatPdfExporter.cachedDevBold!, name: 'NotoSansDevanagari-Bold');
    final robotoFont = ShapedFont.fromBytes(MonthlyBachatgatPdfExporter.cachedRoboto!, name: 'Roboto-Regular');

    final headerTitleStyle = ShapedTextStyle(font: devBoldFont, fallbackFonts: [robotoFont], fontSize: 13, color: PdfColors.white);
    final headerSubStyle = ShapedTextStyle(font: devFont, fallbackFonts: [robotoFont], fontSize: 8, color: PdfColors.grey200);
    final subStyle = ShapedTextStyle(font: devBoldFont, fallbackFonts: [robotoFont], fontSize: 10, color: PdfColor.fromHex('#1F497D'));
    final normalStyle = ShapedTextStyle(font: devFont, fallbackFonts: [robotoFont], fontSize: 8, color: PdfColors.black);
    final boldStyle = ShapedTextStyle(font: devBoldFont, fallbackFonts: [robotoFont], fontSize: 8, color: PdfColors.black);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (ctx) => [
          // Top Branded Header Bar matching standard Bachat Gat reports
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
            margin: const pw.EdgeInsets.only(bottom: 6),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#1E3A8A'),
              borderRadius: pw.BorderRadius.circular(5),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    // Group Logo / Profile Image
                    if (safeLogoImage != null)
                      pw.Container(
                        width: 36,
                        height: 36,
                        margin: const pw.EdgeInsets.only(right: 10),
                        decoration: pw.BoxDecoration(
                          shape: pw.BoxShape.circle,
                          color: PdfColors.white,
                          border: pw.Border.all(color: PdfColor.fromHex('#D97706'), width: 1.5),
                        ),
                        child: pw.ClipOval(
                          child: pw.Image(
                            safeLogoImage,
                            width: 36,
                            height: 36,
                            fit: pw.BoxFit.cover,
                          ),
                        ),
                      )
                    else
                      pw.Container(
                        width: 36,
                        height: 36,
                        margin: const pw.EdgeInsets.only(right: 10),
                        decoration: pw.BoxDecoration(
                          shape: pw.BoxShape.circle,
                          color: PdfColor.fromHex('#D97706'),
                          border: pw.Border.all(color: PdfColors.white, width: 1.5),
                        ),
                        child: pw.Center(
                          child: ShapedText(
                            groupName.trim().isNotEmpty ? groupName.trim().substring(0, 1) : 'स',
                            style: ShapedTextStyle(
                              font: devBoldFont,
                              fallbackFonts: [robotoFont],
                              fontSize: 16,
                              color: PdfColors.white,
                              align: ShapedTextAlign.center,
                            ),
                          ),
                        ),
                      ),
                    // Group Name & Address
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        ShapedText(
                          groupName.toUpperCase(),
                          style: headerTitleStyle,
                        ),
                        pw.SizedBox(height: 1),
                        ShapedText(
                          '$groupAddress | नोंदणी क्र: $regNo${mobile.isNotEmpty ? " | मो. $mobile" : ""}',
                          style: headerSubStyle,
                        ),
                      ],
                    ),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#D97706'),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: ShapedText(
                    'अधिकृत अहवाल (OFFICIAL)',
                    style: ShapedTextStyle(
                      font: devBoldFont,
                      fallbackFonts: [robotoFont],
                      fontSize: 7.5,
                      color: PdfColors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Sub banner
          pw.Center(
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#D9E1F2'),
                borderRadius: pw.BorderRadius.circular(3),
              ),
              child: ShapedText(
                'व्यक्तिगत सभासद संपूर्ण अहवाल (Member Statement)',
                style: ShapedTextStyle(
                  font: subStyle.font,
                  fallbackFonts: subStyle.fallbackFonts,
                  fontSize: subStyle.fontSize,
                  color: subStyle.color,
                  align: ShapedTextAlign.center,
                ),
              ),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Center(
            child: ShapedText(
              'कालावधी: ${_dateFormat.format(_fromDate)} ते ${_dateFormat.format(_toDate)}',
              style: ShapedTextStyle(
                font: devFont,
                fallbackFonts: [robotoFont],
                fontSize: 8.5,
                color: PdfColors.grey700,
                align: ShapedTextAlign.center,
              ),
            ),
          ),
          pw.Divider(height: 14),

          // Member Info Box
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400, width: 0.8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                ShapedText('सभासद: ${member.fullName}', style: boldStyle),
                ShapedText('आयडी: ${member.memberCode}', style: normalStyle),
                ShapedText('मोबाईल: ${member.mobileNumber}', style: normalStyle),
              ],
            ),
          ),
          pw.SizedBox(height: 12),

          // Summary Grid
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.6),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                children: [
                  _pdfCell('एकूण जमा बचत', boldStyle),
                  _pdfCell('घेतलेले एकूण कर्ज', boldStyle),
                  _pdfCell('परतफेड केलेले मुद्दल', boldStyle),
                  _pdfCell('भरलेले एकूण व्याज', boldStyle),
                  _pdfCell('भरलेला लेट फी', boldStyle),
                  _pdfCell('शिल्लक बाकी कर्ज', boldStyle),
                ],
              ),
              pw.TableRow(
                children: [
                  _pdfCell(_formatAmt(_totalSavings), boldStyle),
                  _pdfCell(_formatAmt(_givenLoanAmount), boldStyle),
                  _pdfCell(_formatAmt(_paidLoanPrincipal), boldStyle),
                  _pdfCell(_formatAmt(_paidInterest), boldStyle),
                  _pdfCell(_formatAmt(_paidLateFee), boldStyle),
                  _pdfCell(_formatAmt(_remainingLoanAmount), boldStyle),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 14),

          // Loan Repayment EMI Table
          ShapedText('कर्ज हप्ता व व्याज परतफेड इतिहास:', style: boldStyle),
          pw.SizedBox(height: 4),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _pdfCell('#', boldStyle, align: pw.Alignment.center),
                  _pdfCell('तारीख', boldStyle, align: pw.Alignment.center),
                  _pdfCell('हप्ता क्र.', boldStyle, align: pw.Alignment.center),
                  _pdfCell('मुद्दल', boldStyle, align: pw.Alignment.centerRight),
                  _pdfCell('व्याज', boldStyle, align: pw.Alignment.centerRight),
                  _pdfCell('दंड', boldStyle, align: pw.Alignment.centerRight),
                  _pdfCell('एकूण', boldStyle, align: pw.Alignment.centerRight),
                  _pdfCell('माध्यम', boldStyle, align: pw.Alignment.center),
                ],
              ),
              ..._emis.asMap().entries.map((e) {
                final emi = e.value;
                final p = (emi['principal'] as num?)?.toDouble() ?? 0.0;
                final i = (emi['interest'] as num?)?.toDouble() ?? 0.0;
                final f = (emi['late_fee'] as num?)?.toDouble() ?? 0.0;
                final total = (emi['paid_amount'] as num?)?.toDouble() ?? (p + i + f);

                return pw.TableRow(
                  children: [
                    _pdfCell((e.key + 1).toString(), normalStyle, align: pw.Alignment.center),
                    _pdfCell(emi['payment_date']?.toString() ?? '-', normalStyle, align: pw.Alignment.center),
                    _pdfCell(emi['emi_number'] != null ? '#${emi['emi_number']}' : '-', normalStyle, align: pw.Alignment.center),
                    _pdfCell(_formatAmt(p), normalStyle, align: pw.Alignment.centerRight),
                    _pdfCell(_formatAmt(i), normalStyle, align: pw.Alignment.centerRight),
                    _pdfCell(_formatAmt(f), normalStyle, align: pw.Alignment.centerRight),
                    _pdfCell(_formatAmt(total), boldStyle, align: pw.Alignment.centerRight),
                    _pdfCell(emi['payment_mode']?.toString().toUpperCase() ?? 'CASH', normalStyle, align: pw.Alignment.center),
                  ],
                );
              }),
            ],
          ),
          pw.SizedBox(height: 14),

          // Savings Table
          ShapedText('मासिक बचत जमा इतिहास:', style: boldStyle),
          pw.SizedBox(height: 4),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _pdfCell('#', boldStyle, align: pw.Alignment.center),
                  _pdfCell('तारीख', boldStyle, align: pw.Alignment.center),
                  _pdfCell('पावती क्र.', boldStyle, align: pw.Alignment.center),
                  _pdfCell('जमा रक्कम', boldStyle, align: pw.Alignment.centerRight),
                  _pdfCell('माध्यम', boldStyle, align: pw.Alignment.center),
                  _pdfCell('शेरा', boldStyle, align: pw.Alignment.centerLeft),
                ],
              ),
              ..._savings.asMap().entries.map((e) {
                final s = e.value;
                final amt = (s['amount'] as num?)?.toDouble() ?? 0.0;
                return pw.TableRow(
                  children: [
                    _pdfCell((e.key + 1).toString(), normalStyle, align: pw.Alignment.center),
                    _pdfCell(s['savings_date']?.toString() ?? '-', normalStyle, align: pw.Alignment.center),
                    _pdfCell(s['receipt_number']?.toString() ?? '-', normalStyle, align: pw.Alignment.center),
                    _pdfCell(_formatAmt(amt), boldStyle, align: pw.Alignment.centerRight),
                    _pdfCell(s['payment_mode']?.toString().toUpperCase() ?? 'CASH', normalStyle, align: pw.Alignment.center),
                    _pdfCell(s['remarks']?.toString() ?? '-', normalStyle, align: pw.Alignment.centerLeft),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );

    final bytes = await doc.save();
    await Printing.layoutPdf(
      onLayout: (format) async => bytes,
      name: '${member.fullName}_अहवाल.pdf',
    );
  }

  pw.Widget _pdfCell(String text, ShapedTextStyle style, {pw.Alignment align = pw.Alignment.center}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      alignment: align,
      child: ShapedText(
        text,
        style: ShapedTextStyle(
          font: style.font,
          fallbackFonts: style.fallbackFonts,
          fontSize: style.fontSize,
          color: style.color,
          align: align == pw.Alignment.centerRight
              ? ShapedTextAlign.end
              : (align == pw.Alignment.center ? ShapedTextAlign.center : ShapedTextAlign.start),
        ),
      ),
    );
  }
}

class _TableH extends StatelessWidget {
  final String text;
  const _TableH(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      alignment: Alignment.center,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black87),
      ),
    );
  }
}

class _TableC extends StatelessWidget {
  final String text;
  final Alignment align;
  final bool isBold;
  final Color? color;

  const _TableC(this.text, {this.align = Alignment.centerLeft, this.isBold = false, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      alignment: align,
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
          color: color ?? Colors.black87,
        ),
      ),
    );
  }
}
