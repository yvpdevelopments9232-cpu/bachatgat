import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/loan.dart';
import '../../models/bank_account.dart';
import '../../models/member.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/loan_provider.dart';
import '../../providers/member_provider.dart';
import '../../providers/bank_provider.dart';
import '../../services/pdf_service.dart';
import '../../widgets/app_card.dart';
import '../../widgets/desktop_wrapper.dart';

class CollectEmiScreen extends StatefulWidget {
  final String? preSelectedLoanId;
  final String? preSelectedMemberId;

  const CollectEmiScreen({
    super.key,
    this.preSelectedLoanId,
    this.preSelectedMemberId,
  });

  @override
  State<CollectEmiScreen> createState() => _CollectEmiScreenState();
}

class _CollectEmiScreenState extends State<CollectEmiScreen> {
  DateTime _selectedDate = DateTime.now();
  Loan? _selectedLoan;
  List<LoanEmi> _loanEmis = [];

  // Previous entry and due date tracking
  DateTime? _previousEntryDate;
  DateTime? _scheduledDueDate;
  int _elapsedDays = 0;
  int _overdueDays = 0;

  // Controllers
  late TextEditingController _collectionAmountCtrl;
  late TextEditingController _interestCtrl;
  late TextEditingController _lateFeeCtrl;
  late TextEditingController _transactionIdCtrl;
  late TextEditingController _collectedByCtrl;
  late TextEditingController _remarksCtrl;

  // Real-time calculated amounts
  double _calculatedAutoInterest = 0.0;
  double _calculatedAutoLateFee = 0.0;
  double _reducePrincipal = 0.0;
  double _newPendingPrincipal = 0.0;

  String _paymentMode = 'Cash';
  String? _selectedBankAccountId;
  bool _isSaving = false;
  bool _isInterestManuallyEdited = false;

  @override
  void initState() {
    super.initState();
    _collectionAmountCtrl = TextEditingController();
    _interestCtrl = TextEditingController(text: '0');
    _lateFeeCtrl = TextEditingController(text: '0');
    _transactionIdCtrl = TextEditingController();
    _collectedByCtrl = TextEditingController();
    _remarksCtrl = TextEditingController();

    _collectionAmountCtrl.addListener(_onAmountChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      _collectedByCtrl.text = auth.currentProfile?.fullName ?? 'खजिनदार (Treasurer)';

      final gid = auth.currentGroup?.id;
      if (gid != null) {
        Provider.of<BankProvider>(context, listen: false).loadBanks(gid);
        Provider.of<LoanProvider>(context, listen: false).fetchLoans(gid);
        Provider.of<MemberProvider>(context, listen: false).fetchMembers(gid);
      }

      final loanProv = Provider.of<LoanProvider>(context, listen: false);
      if (widget.preSelectedLoanId != null) {
        final match = loanProv.decreasingEmiLoans.where((l) => l.id == widget.preSelectedLoanId).toList();
        if (match.isNotEmpty) {
          _onSelectLoan(match.first);
          return;
        }
      }
      if (widget.preSelectedMemberId != null) {
        _onSelectMember(widget.preSelectedMemberId);
      }
    });
  }

  @override
  void dispose() {
    _collectionAmountCtrl.removeListener(_onAmountChanged);
    _collectionAmountCtrl.dispose();
    _interestCtrl.dispose();
    _lateFeeCtrl.dispose();
    _transactionIdCtrl.dispose();
    _collectedByCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  void _onAmountChanged() {
    _recalculatePrincipalReduction();
  }

  // Pick Date
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: 'हप्ता भरणा तारीख निवडा (Collection Date)',
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
      _recalculateAll();
    }
  }

  // Member Selected
  void _onSelectMember(String? memberId) {
    if (memberId == null) return;
    final loanProv = Provider.of<LoanProvider>(context, listen: false);
    final activeLoans = loanProv.decreasingEmiLoans.where((l) => l.memberId == memberId).toList();

    setState(() {
      if (activeLoans.isNotEmpty) {
        _selectedLoan = activeLoans.first;
      } else {
        _selectedLoan = null;
      }
    });

    if (_selectedLoan != null) {
      _loadLoanEmisAndCalculate(_selectedLoan!);
    }
  }

  // Loan Selected directly
  void _onSelectLoan(Loan loan) {
    setState(() {
      _selectedLoan = loan;
    });
    _loadLoanEmisAndCalculate(loan);
  }

  Future<void> _loadLoanEmisAndCalculate(Loan loan) async {
    final loanProv = Provider.of<LoanProvider>(context, listen: false);
    await loanProv.loadEmisForLoan(loan.id);

    if (!mounted) return;
    setState(() {
      _loanEmis = List<LoanEmi>.from(loanProv.selectedLoanEmis);
    });

    _determinePreviousEntryAndDueDates(loan, _loanEmis);
    _recalculateAll();
  }

  void _determinePreviousEntryAndDueDates(Loan loan, List<LoanEmi> emis) {
    // 1. Find previous entry date
    final paidEmis = emis.where((e) => e.status == 'paid' && e.paymentDate != null && e.paymentDate!.isNotEmpty).toList();
    if (paidEmis.isNotEmpty) {
      paidEmis.sort((a, b) => (a.paymentDate ?? '').compareTo(b.paymentDate ?? ''));
      _previousEntryDate = DateTime.tryParse(paidEmis.last.paymentDate!);
    } else {
      _previousEntryDate = DateTime.tryParse(loan.firstEmiDate) ?? DateTime.tryParse(loan.applicationDate);
    }
    _previousEntryDate ??= DateTime.now();

    // 2. Find next scheduled due date
    final pendingEmis = emis.where((e) => e.status != 'paid').toList();
    if (pendingEmis.isNotEmpty) {
      pendingEmis.sort((a, b) => a.emiNumber.compareTo(b.emiNumber));
      _scheduledDueDate = DateTime.tryParse(pendingEmis.first.dueDate);
    } else {
      _scheduledDueDate = _previousEntryDate!.add(const Duration(days: 30));
    }
    _scheduledDueDate ??= _previousEntryDate!.add(const Duration(days: 30));

    // Default collection amount to standard emiAmount if empty
    if (_collectionAmountCtrl.text.isEmpty && loan.emiAmount > 0) {
      _collectionAmountCtrl.text = loan.emiAmount.toStringAsFixed(0);
    }
  }

  void _recalculateAll() {
    if (_selectedLoan == null || _previousEntryDate == null) return;
    final loan = _selectedLoan!;
    final loanProv = Provider.of<LoanProvider>(context, listen: false);
    final loanSettings = loanProv.loanSettings;

    // 1. Calculate Elapsed Days from previous entry to selected date
    final dPrev = DateTime(_previousEntryDate!.year, _previousEntryDate!.month, _previousEntryDate!.day);
    final dSel = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final diffDays = dSel.difference(dPrev).inDays;
    _elapsedDays = diffDays > 0 ? diffDays : 0;

    // 2. Calculate Accrued Interest
    // Formula: Pending Principal * (Annual Rate / 100) * (Elapsed Days / 365)
    final pendingPrincipal = loan.outstandingPrincipal > 0 ? loan.outstandingPrincipal : loan.approvedAmount;
    final rate = loan.interestRate > 0 ? loan.interestRate : loanSettings.interestRate;

    if (_elapsedDays > 0 && pendingPrincipal > 0 && rate > 0) {
      final interest = (pendingPrincipal * (rate / 100.0)) * (_elapsedDays / 365.0);
      _calculatedAutoInterest = interest > 0 ? double.parse(interest.toStringAsFixed(2)) : 0.0;
    } else {
      _calculatedAutoInterest = 0.0;
    }

    if (!_isInterestManuallyEdited) {
      _interestCtrl.text = _calculatedAutoInterest.round().toString();
    }

    // 3. Calculate Overdue Days and Overdue Late Fee
    int lateDays = 0;
    if (_scheduledDueDate != null) {
      final dDue = DateTime(_scheduledDueDate!.year, _scheduledDueDate!.month, _scheduledDueDate!.day);
      final overdueDiff = dSel.difference(dDue).inDays;
      if (overdueDiff > 0) {
        lateDays = overdueDiff;
      }
    }
    _overdueDays = lateDays;

    // User explicit Late Fee Formula:
    // (pending principal * late fee rate / 100) * (overdue_days / 365)
    final lateFeeRate = loanSettings.lateFeePercentage;
    final graceDays = loanSettings.overdueDays >= 28 ? 0 : loanSettings.overdueDays;
    if (_overdueDays > graceDays && pendingPrincipal > 0) {
      double fee = 0.0;
      if (lateFeeRate > 0) {
        fee = (pendingPrincipal * (lateFeeRate / 100.0)) * (_overdueDays / 365.0);
      }
      if (fee <= 0 && lateFeeRate > 0) {
        fee = _overdueDays * lateFeeRate;
      }
      _calculatedAutoLateFee = fee > 0 ? fee.roundToDouble() : 0.0;
    } else {
      _calculatedAutoLateFee = 0.0;
    }
    _lateFeeCtrl.text = _calculatedAutoLateFee.toStringAsFixed(0);

    // 4. Reduce Principal and New Balance
    _recalculatePrincipalReduction();
  }

  void _recalculatePrincipalReduction() {
    if (_selectedLoan == null) return;
    final loan = _selectedLoan!;
    final pendingPrincipal = loan.outstandingPrincipal > 0 ? loan.outstandingPrincipal : loan.approvedAmount;

    final collectionAmount = double.tryParse(_collectionAmountCtrl.text) ?? 0.0;
    final interest = double.tryParse(_interestCtrl.text) ?? 0.0;
    final lateFee = double.tryParse(_lateFeeCtrl.text) ?? 0.0;

    // User explicit formula:
    // reduce principle = collection amount - interest - overdue
    final reduced = collectionAmount - interest - lateFee;
    _reducePrincipal = reduced > 0 ? reduced : 0.0;

    final rem = pendingPrincipal - _reducePrincipal;
    _newPendingPrincipal = rem > 0 ? rem : 0.0;

    if (mounted) setState(() {});
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '-';
    return "${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year}";
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final memberProv = Provider.of<MemberProvider>(context);
    final loanProv = Provider.of<LoanProvider>(context);
    final currentGroup = auth.currentGroup;

    // Members who have active Decreasing EMI loans with outstanding balance
    final activeDecreasingLoans = loanProv.decreasingEmiLoans
        .where((l) => (l.status == 'active' || l.status == 'disbursed') && l.outstandingPrincipal > 0)
        .toList();

    final currentPendingPrincipal = _selectedLoan != null
        ? (_selectedLoan!.outstandingPrincipal > 0 ? _selectedLoan!.outstandingPrincipal : _selectedLoan!.approvedAmount)
        : 0.0;

    final totalProfitAdded = (double.tryParse(_interestCtrl.text) ?? 0.0) + (double.tryParse(_lateFeeCtrl.text) ?? 0.0);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📉 घटता हप्ता वसुली (Decreasing EMI Collection)',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            Text(
              '${currentGroup?.groupName ?? "सावित्रीबाई फुले महिला बचत गट"} • घटती हप्ता पद्धत',
              style: GoogleFonts.poppins(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
            tooltip: 'स्क्रीन बंद करा (Close)',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: DesktopWrapper(
        minWidth: 820,
        child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // =============================================================
                // STEP 1: DATE & MEMBER SELECTION CARD
                // =============================================================
                AppCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.person_pin_rounded, color: AppColors.primary, size: 22),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '१. भरणा तारीख व सभासद निवड (Date & Member Selection)',
                            style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Row with Date Picker & Member Dropdown
                      LayoutBuilder(
                        builder: (ctx, constraints) {
                          final isWide = constraints.maxWidth > 550;
                          return Flex(
                            direction: isWide ? Axis.horizontal : Axis.vertical,
                            children: [
                              // Date Picker
                              Expanded(
                                flex: isWide ? 4 : 0,
                                child: InkWell(
                                  onTap: _pickDate,
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade300),
                                      borderRadius: BorderRadius.circular(10),
                                      color: Colors.white,
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.calendar_today_rounded, size: 20, color: AppColors.primary),
                                        const SizedBox(width: 10),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'हप्ता भरणा तारीख',
                                              style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
                                            ),
                                            Text(
                                              _formatDate(_selectedDate),
                                              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700),
                                            ),
                                          ],
                                        ),
                                        const Spacer(),
                                        const Icon(Icons.edit_calendar_rounded, size: 18, color: Colors.grey),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              if (isWide) const SizedBox(width: 16) else const SizedBox(height: 14),

                              // Member Dropdown
                              Expanded(
                                flex: isWide ? 6 : 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.white,
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      isExpanded: true,
                                      hint: Text(
                                        'कर्जदार सभासद निवडा (Select Member)',
                                        style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary),
                                      ),
                                      value: activeDecreasingLoans.any((l) => l.id == _selectedLoan?.id) ? _selectedLoan?.id : null,
                                      items: activeDecreasingLoans.map((l) {
                                        final m = memberProv.members.where((mem) => mem.id == l.memberId).toList();
                                        final displayName = l.memberName ?? (m.isNotEmpty ? m.first.fullName : 'सभासद');
                                        final code = m.isNotEmpty && m.first.memberCode.isNotEmpty ? ' (${m.first.memberCode})' : '';
                                        return DropdownMenuItem<String>(
                                          value: l.id,
                                          child: Text(
                                            '$displayName$code • ${l.loanCode} • बाकी: ₹${l.outstandingPrincipal.toStringAsFixed(0)}',
                                            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (loanId) {
                                        if (loanId != null) {
                                          final match = activeDecreasingLoans.where((l) => l.id == loanId).toList();
                                          if (match.isNotEmpty) {
                                            _onSelectLoan(match.first);
                                          }
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),

                      // If member has no active loan warning
                      if (activeDecreasingLoans.isEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.amber.shade200),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'सध्या गटात कोणतेही घटता हप्ता (Decreasing EMI) कर्ज उपलब्ध नाही. (No active Decreasing EMI loans found)',
                                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.brown, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Active Loan Highlights Banner
                      if (_selectedLoan != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.primary.withOpacity(0.15)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.account_balance_wallet_rounded, size: 18, color: AppColors.primary),
                                      const SizedBox(width: 8),
                                      Text(
                                        'कर्ज क्रमांक: ${_selectedLoan!.loanCode}',
                                        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'व्याज: ${_selectedLoan!.interestRate.toStringAsFixed(1)}% p.a.',
                                      style: GoogleFonts.poppins(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 18),
                              Wrap(
                                spacing: 20,
                                runSpacing: 10,
                                children: [
                                  _buildLoanStat('मंजूर कर्ज रक्कम', '₹ ${_selectedLoan!.approvedAmount.toStringAsFixed(0)}'),
                                  _buildLoanStat('शिल्लक मुद्दल', '₹ ${currentPendingPrincipal.toStringAsFixed(0)}', isHighlight: true),
                                  _buildLoanStat('मागील हप्ता/नोंद तारीख', _formatDate(_previousEntryDate)),
                                  _buildLoanStat('नियत देय तारीख (Due Date)', _formatDate(_scheduledDueDate)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // =============================================================
                // STEP 2: COLLECTION AMOUNT INPUT & REAL-TIME CALCULATION
                // =============================================================
                AppCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00B074).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.calculate_rounded, color: Color(0xFF00B074), size: 22),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '२. वसुली रक्कम व स्वयंचलित हिशोब (Collection & Live Calculation)',
                            style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Big Collection Amount Input Field
                      Text(
                        'एकूण जमा हप्ता रक्कम (Total Collection Amount)',
                        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _collectionAmountCtrl,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.primary),
                        decoration: InputDecoration(
                          prefixIcon: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 14),
                            child: Text('₹', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary)),
                          ),
                          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                          hintText: 'उदा. 2000',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // DYNAMIC CALCULATION BREAKDOWN
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F4FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFD6E2FB)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'गणित व हिशोब तपशील (Real-Time Calculation Breakdown)',
                              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1E3A8A)),
                            ),
                            const Divider(height: 16),

                            // A. Previous Entry to Selected Date & Interest
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.timeline_rounded, color: Color(0xFF2563EB), size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'मागील नोंदीपासून कालावधी (Elapsed Period): $_elapsedDays दिवस',
                                        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
                                      ),
                                      Text(
                                        'मागील नोंद: ${_formatDate(_previousEntryDate)}  ते  निवडलेली तारीख: ${_formatDate(_selectedDate)}',
                                        style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade700),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // B. Interest Calculation
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.trending_up_rounded, color: Color(0xFF0284C7), size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            'आकारलेले व्याज (Accrued Interest): ',
                                            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
                                          ),
                                          Text(
                                            '₹ ${_interestCtrl.text}',
                                            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0284C7)),
                                          ),
                                          const Spacer(),
                                          if (_isInterestManuallyEdited)
                                            TextButton.icon(
                                              style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                                              icon: const Icon(Icons.refresh_rounded, size: 14),
                                              label: const Text('ऑटो हिशोब', style: TextStyle(fontSize: 11)),
                                              onPressed: () {
                                                _isInterestManuallyEdited = false;
                                                _interestCtrl.text = _calculatedAutoInterest.round().toString();
                                                _recalculatePrincipalReduction();
                                              },
                                            ),
                                        ],
                                      ),
                                      Text(
                                        'फॉर्म्युला: शिल्लक मुद्दल ₹${currentPendingPrincipal.toStringAsFixed(0)} × दर ${_selectedLoan?.interestRate ?? 24}% × ($_elapsedDays/365 दिवस)',
                                        style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade700),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // C. Overdue Days & Late Fee
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  _overdueDays > loanProv.loanSettings.overdueDays
                                      ? Icons.warning_amber_rounded
                                      : Icons.check_circle_outline_rounded,
                                  color: _overdueDays > loanProv.loanSettings.overdueDays ? AppColors.danger : AppColors.success,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            _overdueDays > loanProv.loanSettings.overdueDays
                                                ? 'थकबाकी विलंब (Overdue): $_overdueDays दिवस उशीर'
                                                : 'वेळेवर भरणा (On-Time Payment)',
                                            style: GoogleFonts.poppins(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: _overdueDays > loanProv.loanSettings.overdueDays ? AppColors.danger : AppColors.success,
                                            ),
                                          ),
                                          const Spacer(),
                                          Text(
                                            'दंड: ₹ ${_lateFeeCtrl.text}',
                                            style: GoogleFonts.poppins(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: _overdueDays > loanProv.loanSettings.overdueDays ? AppColors.danger : AppColors.success,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        _overdueDays > loanProv.loanSettings.overdueDays
                                            ? 'देय तारीख: ${_formatDate(_scheduledDueDate)} • फॉर्म्युला: मुद्दल × ${loanProv.loanSettings.lateFeePercentage}% × ($_overdueDays/365 दिवस)'
                                            : 'देय तारीख: ${_formatDate(_scheduledDueDate)} च्या आत भरणा केला, कोणताही विलंब दंड नाही.',
                                        style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade700),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 20),

                            // D. REDUCE PRINCIPAL FORMULA
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue.shade100),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'कमी झालेले मुद्दल (Reduce Principal):',
                                        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700),
                                      ),
                                      Text(
                                        '₹ ${_reducePrincipal.toStringAsFixed(0)}',
                                        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primary),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'फॉर्म्युला: एकूण जमा (₹${_collectionAmountCtrl.text.isEmpty ? "0" : _collectionAmountCtrl.text}) - व्याज (₹${_interestCtrl.text}) - विलंब दंड (₹${_lateFeeCtrl.text})',
                                    style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade700),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'नवीन शिल्लक बाकी मुद्दल:',
                                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
                                      ),
                                      Text(
                                        '₹ ${_newPendingPrincipal.toStringAsFixed(0)}',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: _newPendingPrincipal <= 0 ? AppColors.success : Colors.grey.shade900,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_newPendingPrincipal <= 0 && _selectedLoan != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      '🎉 या हप्त्यामुळे कर्ज पूर्ण फेडले जाईल व कर्ज बंद (Closed) होईल!',
                                      style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.success),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            // E. DIRECT PROFIT ADDITION BANNER
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFA5D6A7)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.monetization_on_rounded, color: Color(0xFF2E7D32), size: 24),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'बचत गटाचा नफा वाढ (Added to Group Profit): ₹ ${totalProfitAdded.toStringAsFixed(0)}',
                                          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1B5E20)),
                                        ),
                                        Text(
                                          'व्याज (₹${_interestCtrl.text}) + विलंब शुल्क (₹${_lateFeeCtrl.text}) थेट गटाच्या ढोबळ उत्पन्नात (Incomes) व निव्वळ नफ्यात (Net Profit) जमा होईल.',
                                          style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF2E7D32)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // =============================================================
                // STEP 3: PAYMENT DETAILS & SUBMIT ACTION
                // =============================================================
                AppCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.payment_rounded, color: Colors.orange, size: 22),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '३. भरणा तपशील व पावती (Payment Details)',
                            style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Payment Source Dropdown
                      Text(
                        'भरणा माध्यम (Payment Source) *',
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 6),
                      Consumer<BankProvider>(
                        builder: (context, bankProv, _) {
                          final availableBanks = bankProv.banks.isNotEmpty
                              ? (bankProv.activeBanks.isNotEmpty ? bankProv.activeBanks : bankProv.banks)
                              : <BankAccount>[];
                          String currentVal = 'Cash';
                          if ((_paymentMode == 'Bank' || _paymentMode == 'UPI') && _selectedBankAccountId != null && availableBanks.any((b) => b.id == _selectedBankAccountId)) {
                            currentVal = 'bank_$_selectedBankAccountId';
                          } else if ((_paymentMode == 'Bank' || _paymentMode == 'UPI') && availableBanks.isNotEmpty) {
                            currentVal = 'bank_${availableBanks.first.id}';
                            _selectedBankAccountId = availableBanks.first.id;
                          }

                          BankAccount? selectedBank;
                          if (_selectedBankAccountId != null && availableBanks.any((b) => b.id == _selectedBankAccountId)) {
                            selectedBank = availableBanks.firstWhere((b) => b.id == _selectedBankAccountId);
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DropdownButtonFormField<String>(
                                value: currentVal,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: 'भरणा माध्यम निवडा (Select Payment Source)',
                                  prefixIcon: const Icon(Icons.payment_rounded, size: 20, color: AppColors.primary),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                ),
                                items: [
                                  const DropdownMenuItem(
                                    value: 'Cash',
                                    child: Text('हातातील रोख (Cash in Hand)', overflow: TextOverflow.ellipsis),
                                  ),
                                  ...availableBanks.map((bank) {
                                    return DropdownMenuItem<String>(
                                      value: 'bank_${bank.id}',
                                      child: Text(
                                        '🏦 ${bank.bankName} (${bank.maskedAccountNumber}) - शिल्लक: ₹${bank.currentBalance.toStringAsFixed(0)}',
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                    );
                                  }),
                                ],
                                onChanged: (v) {
                                  if (v == null) return;
                                  setState(() {
                                    if (v == 'Cash') {
                                      _paymentMode = 'Cash';
                                      _selectedBankAccountId = null;
                                    } else if (v.startsWith('bank_')) {
                                      _paymentMode = 'Bank';
                                      _selectedBankAccountId = v.substring(5);
                                    }
                                  });
                                },
                              ),
                              if (selectedBank != null) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8F5E9),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFA5D6A7)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.account_balance_wallet_rounded, size: 16, color: Color(0xFF2E7D32)),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'बँकेतील शिल्लक रक्कम: ₹ ${selectedBank.currentBalance.toStringAsFixed(2)} (${selectedBank.bankName})',
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1B5E20)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 14),

                      // Transaction ID & Received By
                      Row(
                        children: [
                          if (_paymentMode != 'Cash')
                            Expanded(
                              child: TextField(
                                controller: _transactionIdCtrl,
                                decoration: InputDecoration(
                                  labelText: 'UPI / ट्रान्झॅक्शन आयडी',
                                  labelStyle: GoogleFonts.poppins(fontSize: 12),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  isDense: true,
                                ),
                              ),
                            ),
                          if (_paymentMode != 'Cash') const SizedBox(width: 14),
                          Expanded(
                            child: TextField(
                              controller: _collectedByCtrl,
                              decoration: InputDecoration(
                                labelText: 'हप्ता स्वीकारणारा (Collected By)',
                                labelStyle: GoogleFonts.poppins(fontSize: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Remarks
                      TextField(
                        controller: _remarksCtrl,
                        decoration: InputDecoration(
                          labelText: 'शेरा / टीप (Remarks)',
                          labelStyle: GoogleFonts.poppins(fontSize: 12),
                          hintText: 'उदा. हप्ता वेळेवर जमा केला',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Action Buttons
                      Row(
                        children: [
                          // Cancel / Close Screen Button with 'X' icon
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              side: BorderSide(color: Colors.grey.shade400),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.close_rounded, color: Colors.black87, size: 20),
                            label: Text(
                              'रद्द करा (Cancel)',
                              style: GoogleFonts.poppins(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w600),
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 14),

                          // Save EMI & Add Profit Button
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: _isSaving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : const Icon(Icons.check_circle_outline_rounded, color: Colors.white),
                              label: Text(
                                _isSaving ? 'जतन होत आहे...' : 'हप्ता जमा करा व पावती मिळवा (Collect & Save)',
                                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                              ),
                              onPressed: (_isSaving || _selectedLoan == null) ? null : _handleSubmit,
                            ),
                          ),
                        ],
                      ),
                    ],
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

  Future<void> _handleSubmit() async {
    final loan = _selectedLoan;
    if (loan == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('कृपया कर्जदार सभासद निवडा!')));
      return;
    }

    final collectionAmount = double.tryParse(_collectionAmountCtrl.text) ?? 0.0;
    if (collectionAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('कृपया योग्य वसुली रक्कम टाका!')));
      return;
    }

    final interest = double.tryParse(_interestCtrl.text) ?? 0.0;
    final overdueFee = double.tryParse(_lateFeeCtrl.text) ?? 0.0;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final groupId = auth.currentGroup?.id;
    if (groupId == null) return;

    setState(() => _isSaving = true);

    final loanProv = Provider.of<LoanProvider>(context, listen: false);
    final memberProv = Provider.of<MemberProvider>(context, listen: false);
    final dashProv = Provider.of<DashboardProvider>(context, listen: false);
    final bankProv = Provider.of<BankProvider>(context, listen: false);

    final member = memberProv.members.firstWhere(
      (m) => m.id == loan.memberId,
      orElse: () => Member(
        id: loan.memberId,
        groupId: groupId,
        memberCode: 'M001',
        fullName: loan.memberName ?? 'सभासद',
        mobileNumber: '',
      ),
    );

    final paymentDateStr = "${_selectedDate.year.toString().padLeft(4, '0')}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";

    final ok = await loanProv.collectLoanEmiWithProfit(
      groupId: groupId,
      loanId: loan.id,
      memberId: member.id,
      memberName: member.fullName,
      loanCode: loan.loanCode,
      paymentDate: paymentDateStr,
      collectionAmount: collectionAmount,
      interest: interest,
      overdueAmount: overdueFee,
      reducePrincipal: _reducePrincipal,
      newOutstandingPrincipal: _newPendingPrincipal,
      overdueDays: _overdueDays,
      paymentMode: _paymentMode,
      transactionId: _transactionIdCtrl.text.trim(),
      collectedBy: _collectedByCtrl.text.trim(),
      remarks: _remarksCtrl.text.trim(),
      bankAccountId: _paymentMode != 'Cash' ? _selectedBankAccountId : null,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (ok) {
      // Refresh dashboard & bank metrics so balance/profit increases instantly
      await dashProv.loadDashboardMetrics(groupId);
      await bankProv.loadBanks(groupId);

      _showSuccessReceiptDialog(
        groupName: auth.currentGroup?.groupName ?? 'सावित्रीबाई फुले महिला बचत गट',
        memberName: member.fullName,
        loanCode: loan.loanCode,
        paymentDate: paymentDateStr,
        collectionAmount: collectionAmount,
        reducePrincipal: _reducePrincipal,
        interest: interest,
        overdueAmount: overdueFee,
        previousPendingPrincipal: loan.outstandingPrincipal > 0 ? loan.outstandingPrincipal : loan.approvedAmount,
        remainingPrincipal: _newPendingPrincipal,
        paymentMode: _paymentMode,
        transactionId: _transactionIdCtrl.text.trim(),
        collectedBy: _collectedByCtrl.text.trim(),
        remarks: _remarksCtrl.text.trim(),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('हप्ता जतन करताना त्रुटी आली. कृपया पुन्हा प्रयत्न करा.'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  void _showSuccessReceiptDialog({
    required String groupName,
    required String memberName,
    required String loanCode,
    required String paymentDate,
    required double collectionAmount,
    required double reducePrincipal,
    required double interest,
    required double overdueAmount,
    required double previousPendingPrincipal,
    required double remainingPrincipal,
    required String paymentMode,
    String? transactionId,
    String? collectedBy,
    String? remarks,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dlgCtx) {
        final isMobile = MediaQuery.of(dlgCtx).size.width < 600;
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding: EdgeInsets.symmetric(
            horizontal: isMobile ? 12 : 40,
            vertical: isMobile ? 16 : 24,
          ),
          child: Container(
            width: isMobile ? double.infinity : 480,
            constraints: BoxConstraints(maxHeight: MediaQuery.of(dlgCtx).size.height * 0.9),
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with X close button
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 26),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'हप्ता यशस्वीरीत्या जमा झाला!',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: isMobile ? 14 : 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 22),
                        tooltip: 'बंद करा (Close)',
                        onPressed: () {
                          Navigator.pop(dlgCtx);
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                  const Divider(height: 20),

                // Summary details
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      _receiptRow('सभासद नाव', memberName, isBold: true),
                      _receiptRow('कर्ज क्र.', loanCode),
                      _receiptRow('तारीख', paymentDate),
                      _receiptRow('जमा हप्ता रक्कम', '₹ ${collectionAmount.toStringAsFixed(0)}', color: AppColors.success, isBold: true),
                      _receiptRow('आकारलेले व्याज (नफा)', '₹ ${interest.toStringAsFixed(0)}'),
                      if (overdueAmount > 0)
                        _receiptRow('विलंब शुल्क (नफा)', '₹ ${overdueAmount.toStringAsFixed(0)}', color: AppColors.danger),
                      _receiptRow('कमी झालेले मुद्दल', '₹ ${reducePrincipal.toStringAsFixed(0)}', isBold: true),
                      const Divider(height: 12),
                      _receiptRow('शिल्लक बाकी मुद्दल', '₹ ${remainingPrincipal.toStringAsFixed(0)}', color: Colors.deepOrange, isBold: true),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Profit confirmation
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.trending_up_rounded, color: Color(0xFF2E7D32), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'व्याज व विलंब शुल्क (₹${(interest + overdueAmount).toStringAsFixed(0)}) बचत गटाच्या नफ्यात (Profit) यशस्वीरीत्या जोडले गेले!',
                          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF1B5E20)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Buttons
                isMobile
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.print_rounded, color: Colors.white, size: 18),
                            label: const Text('पावती प्रिंट (PDF)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            onPressed: () async {
                              await PdfService.printDetailedEmiCollectionReceipt(
                                groupName: groupName,
                                memberName: memberName,
                                loanCode: loanCode,
                                emiNumber: 1,
                                paymentDate: paymentDate,
                                collectionAmount: collectionAmount,
                                reducePrincipal: reducePrincipal,
                                interest: interest,
                                overdueAmount: overdueAmount,
                                previousPendingPrincipal: previousPendingPrincipal,
                                remainingPrincipal: remainingPrincipal,
                                paymentMode: paymentMode,
                                transactionId: transactionId,
                                collectedBy: collectedBy,
                                remarks: remarks,
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.close_rounded, size: 18),
                            label: const Text('बंद करा (Close)'),
                            onPressed: () {
                              Navigator.pop(dlgCtx);
                              Navigator.pop(context);
                            },
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: const Icon(Icons.close_rounded, size: 18),
                              label: const Text('बंद करा (Close)'),
                              onPressed: () {
                                Navigator.pop(dlgCtx);
                                Navigator.pop(context);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: const Icon(Icons.print_rounded, color: Colors.white, size: 18),
                              label: const Text('पावती प्रिंट (PDF)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              onPressed: () async {
                                await PdfService.printDetailedEmiCollectionReceipt(
                                  groupName: groupName,
                                  memberName: memberName,
                                  loanCode: loanCode,
                                  emiNumber: 1,
                                  paymentDate: paymentDate,
                                  collectionAmount: collectionAmount,
                                  reducePrincipal: reducePrincipal,
                                  interest: interest,
                                  overdueAmount: overdueAmount,
                                  previousPendingPrincipal: previousPendingPrincipal,
                                  remainingPrincipal: remainingPrincipal,
                                  paymentMode: paymentMode,
                                  transactionId: transactionId,
                                  collectedBy: collectedBy,
                                  remarks: remarks,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _receiptRow(String label, String val, {Color? color, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700)),
          Text(
            val,
            style: GoogleFonts.poppins(fontSize: 12, fontWeight: isBold ? FontWeight.w700 : FontWeight.normal, color: color ?? Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildLoanStat(String label, String val, {bool isHighlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary)),
        Text(
          val,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isHighlight ? AppColors.primary : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
