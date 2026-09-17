import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_strings.dart';
import '../../../models/loan.dart';
import '../../../models/bank_account.dart';
import '../../../models/member.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/loan_provider.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../providers/bank_provider.dart';
import 'loan_voucher_dialog.dart';

class DisburseLoanDialog extends StatefulWidget {
  final AuthProvider auth;
  final LoanProvider loanProv;
  final List<Member> members;
  final Member? initialMember;

  const DisburseLoanDialog({
    super.key,
    required this.auth,
    required this.loanProv,
    required this.members,
    this.initialMember,
  });

  @override
  State<DisburseLoanDialog> createState() => _DisburseLoanDialogState();
}

class _DisburseLoanDialogState extends State<DisburseLoanDialog> {
  late Member _selectedMember;
  Member? _guarantor1;
  Member? _guarantor2;

  final TextEditingController _amountCtrl = TextEditingController(text: '20000');
  late final TextEditingController _rateCtrl;
  final TextEditingController _periodCtrl = TextEditingController(text: '10'); // 10 months
  final TextEditingController _disbDateCtrl = TextEditingController();
  final TextEditingController _remarksCtrl = TextEditingController();

  String _purpose = 'किराणा / घरगुती व्यवसाय';
  String _paymentMode = 'Cash';
  String? _selectedBankAccountId;
  String _emiType = 'fixed'; // 'fixed' or 'decreasing'
  bool _isSaving = false;

  final List<String> _purposes = const [
    'किराणा / घरगुती व्यवसाय',
    'शेती व बी-बियाणे',
    'शेळीपालन / कुक्कुटपालन',
    'हस्तकला / शिलाई मशीन',
    'शिक्षण व शाळा फी',
    'आजारपण / वैद्यकीय खर्च',
    'घरदुरुस्ती व बांधकाम',
    'कौटुंबिक सण / लग्नकार्य',
    'इतर',
  ];

  @override
  void initState() {
    super.initState();
    // Automatically fetch default interest rate from saved loan settings
    final defaultRate = widget.loanProv.loanSettings.interestRate;
    final rateStr = defaultRate > 0
        ? (defaultRate.truncateToDouble() == defaultRate ? defaultRate.toStringAsFixed(0) : defaultRate.toStringAsFixed(1))
        : '24';
    _rateCtrl = TextEditingController(text: rateStr);

    _selectedMember = widget.initialMember ??
        (widget.members.isNotEmpty
            ? widget.members.first
            : Member(id: '', groupId: '', memberCode: 'M-00', fullName: '', mobileNumber: ''));

    // Default other members as guarantors if available
    final otherMembers = widget.members.where((m) => m.id != _selectedMember.id).toList();
    if (otherMembers.isNotEmpty) _guarantor1 = otherMembers[0];
    if (otherMembers.length > 1) _guarantor2 = otherMembers[1];

    final now = DateTime.now();
    _disbDateCtrl.text =
        "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final gid = widget.auth.currentGroup?.id;
      if (gid != null) {
        Provider.of<BankProvider>(context, listen: false).loadBanks(gid);
      }
    });
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _rateCtrl.dispose();
    _periodCtrl.dispose();
    _disbDateCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  // Live calculations
  double get _amount => double.tryParse(_amountCtrl.text) ?? 0.0;
  double get _annualRate => double.tryParse(_rateCtrl.text) ?? 24.0;
  int get _months => int.tryParse(_periodCtrl.text) ?? 12;

  // Fixed EMI Calculation
  double get _fixedEmi => calculateFixedEmi(principal: _amount, annualRate: _annualRate, months: _months);
  double get _fixedTotalRepayable => _fixedEmi * _months;

  // Decreasing EMI Calculation
  double get _monthlyPrincipal => _months > 0 ? _amount / _months : 0.0;
  double get _month1Emi => calculateDecreasingEmi(principal: _amount, annualRate: _annualRate, months: _months, monthIndex: 1);
  double get _month2Emi => calculateDecreasingEmi(principal: _amount, annualRate: _annualRate, months: _months, monthIndex: 2);
  double get _month3Emi => calculateDecreasingEmi(principal: _amount, annualRate: _annualRate, months: _months, monthIndex: 3);
  double get _lastMonthEmi => calculateDecreasingEmi(principal: _amount, annualRate: _annualRate, months: _months, monthIndex: _months);
  double get _decreasingTotalInterest => (_amount * (_annualRate / 100) / 12) * (_months + 1) / 2;
  double get _decreasingTotalRepayable => _amount + _decreasingTotalInterest;

  double get _currentTotalRepayable => _emiType == 'fixed' ? _fixedTotalRepayable : _decreasingTotalRepayable;

  DateTime _parseDate(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return DateTime.now();

    DateTime? dt = DateTime.tryParse(trimmed);
    if (dt != null) return dt;

    final parts = trimmed.contains('-') ? trimmed.split('-') : trimmed.split('/');
    if (parts.length == 3) {
      if (parts[0].length == 4) {
        final y = int.tryParse(parts[0]) ?? DateTime.now().year;
        final m = int.tryParse(parts[1]) ?? DateTime.now().month;
        final d = int.tryParse(parts[2]) ?? DateTime.now().day;
        return DateTime(y, m, d);
      } else {
        final d = int.tryParse(parts[0]) ?? DateTime.now().day;
        final m = int.tryParse(parts[1]) ?? DateTime.now().month;
        final y = int.tryParse(parts[2]) ?? DateTime.now().year;
        return DateTime(y, m, d);
      }
    }

    return DateTime.now();
  }

  DateTime get _disbDateTime => _parseDate(_disbDateCtrl.text);

  int get _startDay => _disbDateTime.day;

  // First EMI Date: 1 month after disbursement date on the SAME day (e.g. 7 or 8)
  DateTime get _firstEmiDate {
    final y = _disbDateTime.year;
    final m = _disbDateTime.month + 1;
    final maxDays = DateTime(y, m + 1, 0).day;
    final d = _startDay > maxDays ? maxDays : _startDay;
    return DateTime(y, m, d);
  }

  String get _firstEmiDateStr =>
      "${_firstEmiDate.year}-${_firstEmiDate.month.toString().padLeft(2, '0')}-${_firstEmiDate.day.toString().padLeft(2, '0')}";

  // Ending Date / Last EMI: exactly _months months after disbursement date on the SAME day (e.g. 7 or 8)
  DateTime get _loanEndDate {
    final y = _disbDateTime.year;
    final m = _disbDateTime.month + (_months > 0 ? _months : 1);
    final maxDays = DateTime(y, m + 1, 0).day;
    final d = _startDay > maxDays ? maxDays : _startDay;
    return DateTime(y, m, d);
  }

  String get _loanEndDateStr =>
      "${_loanEndDate.year}-${_loanEndDate.month.toString().padLeft(2, '0')}-${_loanEndDate.day.toString().padLeft(2, '0')}";

  Future<void> _pickDisbDate() async {
    DateTime initDate = DateTime.tryParse(_disbDateCtrl.text.trim()) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: 'कर्ज वाटप तारीख निवडा (Disbursement Date)',
    );
    if (picked != null) {
      setState(() {
        _disbDateCtrl.text =
            "${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 40,
        vertical: isMobile ? 16 : 24,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: isMobile ? double.infinity : 580,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
        padding: EdgeInsets.all(isMobile ? 14 : 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.monetization_on_rounded, color: AppColors.primary, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppStrings.tr('नवीन अंतर्गत कर्ज वाटप', 'Disburse Internal Loan'),
                                style: GoogleFonts.poppins(fontSize: isMobile ? 15 : 16, fontWeight: FontWeight.w700),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'गटाच्या अंतर्गत निधीतून कर्ज वाटप व हप्ता निश्चिती',
                                style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 20),

              // 1. Borrower Member Selector
              Text('कर्जदार सभासद (Borrower Member)*', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _selectedMember.id,
                isExpanded: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.person_rounded, color: AppColors.primary),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: widget.members.map((m) {
                  return DropdownMenuItem(
                    value: m.id,
                    child: Text('${m.fullName} (${m.memberCode})', overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (id) {
                  if (id != null) {
                    setState(() {
                      _selectedMember = widget.members.firstWhere((m) => m.id == id);
                    });
                  }
                },
              ),
              const SizedBox(height: 14),

              // 2. Amount & Quick Amount Chips
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _amountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'कर्ज रक्कम (Loan Amount)*',
                        prefixText: '₹ ',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _rateCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'व्याज दर (Rate)*',
                        suffixText: '% p.a.',
                        hintText: '24 (2% दरमहा)',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Quick Amount Suggestion Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [5000, 10000, 15000, 20000, 30000, 50000].map((amt) {
                    final isSel = _amount == amt.toDouble();
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _amountCtrl.text = '$amt';
                          });
                        },
                        child: Chip(
                          label: Text('₹$amt', style: TextStyle(fontSize: 11, fontWeight: isSel ? FontWeight.bold : FontWeight.normal, color: isSel ? Colors.white : AppColors.textPrimary)),
                          backgroundColor: isSel ? AppColors.primary : AppColors.background,
                          side: BorderSide(color: isSel ? AppColors.primary : AppColors.cardBorder),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),

              // 3. Period & Purpose
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _periodCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'मुदत (Period in Months)*',
                        suffixText: 'महिने',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      value: _purpose,
                      decoration: const InputDecoration(labelText: 'कर्जाचा हेतू (Purpose)*'),
                      items: _purposes.map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 13)))).toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _purpose = v);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 4. Guarantors (जामीनदार १ व २)
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _guarantor1?.id,
                      decoration: const InputDecoration(labelText: 'जामीनदार १ (Guarantor 1)'),
                      items: widget.members.where((m) => m.id != _selectedMember.id).map((m) {
                        return DropdownMenuItem(value: m.id, child: Text(m.fullName, overflow: TextOverflow.ellipsis));
                      }).toList(),
                      onChanged: (id) {
                        if (id != null) setState(() => _guarantor1 = widget.members.firstWhere((m) => m.id == id));
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _guarantor2?.id,
                      decoration: const InputDecoration(labelText: 'जामीनदार २ (Guarantor 2)'),
                      items: widget.members.where((m) => m.id != _selectedMember.id && m.id != _guarantor1?.id).map((m) {
                        return DropdownMenuItem(value: m.id, child: Text(m.fullName, overflow: TextOverflow.ellipsis));
                      }).toList(),
                      onChanged: (id) {
                        if (id != null) setState(() => _guarantor2 = widget.members.firstWhere((m) => m.id == id));
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 5. Date, Ending Date & Payment Mode
              if (isMobile) ...[
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _disbDateCtrl,
                        decoration: InputDecoration(
                          labelText: 'वाटप तारीख (Date)*',
                          hintText: 'YYYY-MM-DD',
                          prefixIcon: IconButton(
                            icon: const Icon(Icons.calendar_month_rounded, size: 18, color: AppColors.primary),
                            onPressed: _pickDisbDate,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: _buildPaymentSourceDropdown(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primary.withOpacity(0.25)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.event_available_rounded, size: 15, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text('समाप्ती तारीख (Auto):', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
                        ],
                      ),
                      Text(
                        _loanEndDateStr,
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: TextField(
                        controller: _disbDateCtrl,
                        decoration: InputDecoration(
                          labelText: 'वाटप तारीख (Date)*',
                          hintText: 'YYYY-MM-DD',
                          prefixIcon: IconButton(
                            icon: const Icon(Icons.calendar_month_rounded, size: 18, color: AppColors.primary),
                            onPressed: _pickDisbDate,
                          ),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.edit_calendar_rounded, size: 18, color: AppColors.primary),
                            onPressed: _pickDisbDate,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.primary.withOpacity(0.25)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.event_available_rounded, size: 13, color: AppColors.primary),
                                const SizedBox(width: 4),
                                Text('समाप्ती तारीख (Auto)', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primary)),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _loanEndDateStr,
                              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 4,
                      child: _buildPaymentSourceDropdown(),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),

              // ===============================================================
              // 6. 💰 EMI TYPE SELECTION (Fixed EMI vs Decreasing EMI)
              // ===============================================================
              Row(
                children: [
                  const Icon(Icons.account_balance_rounded, size: 18, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    '💰 हप्ता प्रकार निवडा (EMI Type)*',
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.cardBorder, width: 1.2),
                ),
                child: Column(
                  children: [
                    // Option 1: Fixed EMI
                    InkWell(
                      onTap: () => setState(() => _emiType = 'fixed'),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: _emiType == 'fixed' ? AppColors.primary.withOpacity(0.06) : Colors.transparent,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Radio<String>(
                              value: 'fixed',
                              groupValue: _emiType,
                              activeColor: AppColors.primary,
                              onChanged: (val) {
                                if (val != null) setState(() => _emiType = val);
                              },
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      Text(
                                        '१. स्थिर हप्ता (Fixed EMI)',
                                        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'दरमहा ₹ ${_fixedEmi.toStringAsFixed(0)}',
                                          style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'कर्जदार दरमहा समान हप्ता भरतो. मुद्दल वाढत जाते व व्याज कमी होते. (जुनी हप्ता वसुली प्रणाली लागू राहील)',
                                    style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 1),

                    // Option 2: Decreasing EMI
                    InkWell(
                      onTap: () => setState(() => _emiType = 'decreasing'),
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: _emiType == 'decreasing' ? Colors.deepOrange.withOpacity(0.06) : Colors.transparent,
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Radio<String>(
                              value: 'decreasing',
                              groupValue: _emiType,
                              activeColor: Colors.deepOrange,
                              onChanged: (val) {
                                if (val != null) setState(() => _emiType = val);
                              },
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      Text(
                                        '२. घटता हप्ता (Decreasing EMI)',
                                        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.deepOrange.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'महिना १: ₹ ${_month1Emi.toStringAsFixed(0)} → घटत जाणारा',
                                          style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.deepOrange),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'दरमहा समान मुद्दल (₹ ${_monthlyPrincipal.toStringAsFixed(0)}) आणि उर्वरित मुद्दलावर व्याज कमी होत जाते. (नवीन हप्ता वसुली प्रणाली लागू राहील)',
                                    style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
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
              ),
              const SizedBox(height: 16),

              // ===============================================================
              // 7. LIVE REAL-TIME EMI PREVIEW CARD
              // ===============================================================
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _emiType == 'fixed' ? AppColors.primary.withOpacity(0.06) : Colors.deepOrange.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _emiType == 'fixed' ? AppColors.primary.withOpacity(0.3) : Colors.deepOrange.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _emiType == 'fixed' ? Icons.lock_clock_rounded : Icons.trending_down_rounded,
                              size: 17,
                              color: _emiType == 'fixed' ? AppColors.primary : Colors.deepOrange,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _emiType == 'fixed'
                                  ? 'कर्ज परतफेड अंदाज: स्थिर हप्ता (Fixed EMI)'
                                  : 'कर्ज परतफेड अंदाज: घटता हप्ता (Decreasing EMI)',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _emiType == 'fixed' ? AppColors.primary : Colors.deepOrange,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _emiType == 'fixed' ? AppColors.primary : Colors.deepOrange,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${(_annualRate / 12).toStringAsFixed(1)}% दरमहा',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16),

                    if (_emiType == 'fixed') ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildCalcCol('मासिक समान हप्ता (Fixed EMI)', '₹ ${_fixedEmi.toStringAsFixed(0)}', isHighlight: true),
                          _buildCalcCol('एकूण व्याज (Total Interest)', '₹ ${math.max(0, _fixedTotalRepayable - _amount).toStringAsFixed(0)}'),
                          _buildCalcCol('एकूण परतफेड (Repayable)', '₹ ${_fixedTotalRepayable.toStringAsFixed(0)}'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'दरमहा समान ₹ ${_fixedEmi.toStringAsFixed(0)} हप्ता राहील. (हा सदस्य जुन्या हप्ता वसुलीमध्ये दिसेल)',
                        style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
                      ),
                    ] else ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildCalcCol('दरमहा मुद्दल (Fixed Principal)', '₹ ${_monthlyPrincipal.toStringAsFixed(0)}'),
                          _buildCalcCol('पहिला हप्ता (Month 1)', '₹ ${_month1Emi.toStringAsFixed(0)}', isHighlight: true),
                          _buildCalcCol('शेवटचा हप्ता (Final Month)', '₹ ${_lastMonthEmi.toStringAsFixed(0)}'),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.deepOrange.withOpacity(0.25)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.show_chart_rounded, size: 16, color: Colors.deepOrange),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'हप्ता क्रम: १ला महिना: ₹${_month1Emi.toStringAsFixed(0)} → २रा महिना: ₹${_month2Emi.toStringAsFixed(0)} → ३रा महिना: ₹${_month3Emi.toStringAsFixed(0)} ... शेवटचा हप्ता: ₹${_lastMonthEmi.toStringAsFixed(0)} (कमी होत जाणारा)',
                                style: GoogleFonts.poppins(fontSize: 10.5, color: Colors.deepOrange.shade900, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'उर्वरित मुद्दलावर दरमहा व्याज मोजले जाईल. (हा सदस्य नवीन हप्ता वसुलीमध्ये दिसेल)',
                        style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
                      ),
                    ],

                    const SizedBox(height: 10),

                    // Live Timeline / Dates Preview (First EMI & Ending Date)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.primary.withOpacity(0.15)),
                      ),
                      child: isMobile
                          ? Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.play_circle_outline_rounded, size: 15, color: AppColors.success),
                                        const SizedBox(width: 5),
                                        Text('पहिला हप्ता:', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary)),
                                      ],
                                    ),
                                    Text(_firstEmiDateStr, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                                  ],
                                ),
                                const Divider(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.event_available_rounded, size: 15, color: AppColors.danger),
                                        const SizedBox(width: 5),
                                        Text('कर्ज समाप्ती तारीख:', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary)),
                                      ],
                                    ),
                                    Text(_loanEndDateStr, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.danger)),
                                  ],
                                ),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.play_circle_outline_rounded, size: 15, color: AppColors.success),
                                    const SizedBox(width: 5),
                                    Text('पहिला हप्ता: ', style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textSecondary)),
                                    Text(_firstEmiDateStr, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                                  ],
                                ),
                                Container(height: 16, width: 1, color: AppColors.cardBorder),
                                Row(
                                  children: [
                                    const Icon(Icons.event_available_rounded, size: 15, color: AppColors.danger),
                                    const SizedBox(width: 5),
                                    Text('कर्ज समाप्ती तारीख: ', style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textSecondary)),
                                    Text(_loanEndDateStr, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.danger)),
                                  ],
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('एकूण परतफेड रक्कम ($_months महिने):', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary)),
                        Text('₹ ${_currentTotalRepayable.toStringAsFixed(0)}', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                      onPressed: () => Navigator.pop(context),
                      child: Text(AppStrings.cancel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: _isSaving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.check_circle_rounded, color: Colors.white),
                      label: Text(
                        _isSaving ? 'मंजूर होत आहे...' : 'कर्ज मंजूर करा व पावती पहा',
                        style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                      onPressed: _isSaving ? null : _handleDisburse,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalcCol(String label, String val, {bool isHighlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textSecondary)),
        Text(val, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: isHighlight ? AppColors.primary : AppColors.textPrimary)),
      ],
    );
  }

  Future<void> _handleDisburse() async {
    if (_amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('कृपया योग्य कर्ज रक्कम टाका!')));
      return;
    }

    final groupId = widget.auth.currentGroup?.id;
    if (groupId == null) return;

    final dashProv = Provider.of<DashboardProvider>(context, listen: false);
    final bankProv = Provider.of<BankProvider>(context, listen: false);

    setState(() => _isSaving = true);

    final d = _disbDateTime;
    final disbDateIso = "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

    final loan = await widget.loanProv.disburseLoan(
      groupId: groupId,
      member: _selectedMember,
      amount: _amount,
      interestRateAnnual: _annualRate,
      periodMonths: _months,
      purpose: _purpose,
      guarantor1Id: _guarantor1?.id,
      guarantor2Id: _guarantor2?.id,
      disbursementDate: disbDateIso,
      paymentMode: _paymentMode,
      bankAccountId: _paymentMode == 'Bank' ? _selectedBankAccountId : null,
      interestType: _emiType,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (loan != null) {
      try {
        await dashProv.loadDashboardMetrics(groupId);
        await bankProv.loadBanks(groupId);
      } catch (_) {}
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('कर्ज यशस्वीरीत्या मंजूर व वाटप करण्यात आले!'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, loan);
      // Open Voucher Dialog
      showDialog(
        context: context,
        builder: (ctx) => LoanVoucherDialog(
          loan: loan,
          groupName: widget.auth.currentGroup?.groupName ?? 'Sakhi Bachat Gat',
          guarantor1Name: _guarantor1?.fullName,
          guarantor2Name: _guarantor2?.fullName,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('कर्ज नोंद सेव्ह करताना त्रुटी आली. कृपया पुन्हा प्रयत्न करा.'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Widget _buildPaymentSourceDropdown() {
    return Consumer<BankProvider>(
      builder: (context, bankProv, _) {
        final availableBanks = bankProv.banks.isNotEmpty
            ? (bankProv.activeBanks.isNotEmpty ? bankProv.activeBanks : bankProv.banks)
            : <BankAccount>[];

        String currentVal = 'Cash';
        if (_paymentMode == 'Bank' && _selectedBankAccountId != null && availableBanks.any((b) => b.id == _selectedBankAccountId)) {
          currentVal = 'bank_$_selectedBankAccountId';
        } else if (_paymentMode == 'Bank' && availableBanks.isNotEmpty) {
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
              decoration: const InputDecoration(
                labelText: 'माध्यम (Mode)*',
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              ),
              items: [
                const DropdownMenuItem(value: 'Cash', child: Text('हातातील रोख (Cash in Hand)', overflow: TextOverflow.ellipsis)),
                ...availableBanks.map((b) => DropdownMenuItem(
                  value: 'bank_${b.id}',
                  child: Text(
                    '🏦 ${b.bankName} (${b.maskedAccountNumber}) - ₹${b.currentBalance.toStringAsFixed(0)}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                )),
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
    );
  }
}
