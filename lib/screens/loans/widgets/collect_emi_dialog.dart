import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_strings.dart';
import '../../../models/loan.dart';
import '../../../models/bank_account.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/loan_provider.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../providers/bank_provider.dart';

class CollectEmiDialog extends StatefulWidget {
  final Loan loan;
  final LoanEmi emi;
  final AuthProvider auth;
  final LoanProvider loanProv;

  const CollectEmiDialog({
    super.key,
    required this.loan,
    required this.emi,
    required this.auth,
    required this.loanProv,
  });

  @override
  State<CollectEmiDialog> createState() => _CollectEmiDialogState();
}

class _CollectEmiDialogState extends State<CollectEmiDialog> {
  late Loan _activeLoan;
  late LoanEmi _activeEmi;

  late TextEditingController _principalCtrl;
  late TextEditingController _interestCtrl;
  late TextEditingController _lateFeeCtrl;
  late TextEditingController _totalPaidCtrl;
  late TextEditingController _txnIdCtrl;
  late TextEditingController _paymentDateCtrl;
  late TextEditingController _collectedByCtrl;
  late TextEditingController _remarksCtrl;

  String _paymentMode = 'Cash';
  String? _selectedBankAccountId;
  bool _isSaving = false;
  int _overdueDays = 0;
  double _calculatedLateFee = 0.0;

  @override
  void initState() {
    super.initState();
    _activeLoan = widget.loan;
    _activeEmi = widget.emi;

    final now = DateTime.now();
    _paymentDateCtrl = TextEditingController(
      text: "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}",
    );

    _principalCtrl = TextEditingController(text: _activeEmi.principal.toStringAsFixed(0));
    _interestCtrl = TextEditingController(text: _activeEmi.interest.toStringAsFixed(0));
    _lateFeeCtrl = TextEditingController(text: '0');
    _totalPaidCtrl = TextEditingController(text: (_activeEmi.principal + _activeEmi.interest).toStringAsFixed(0));
    _txnIdCtrl = TextEditingController();

    _collectedByCtrl = TextEditingController(
      text: widget.auth.currentProfile?.fullName ?? 'खजिनदार (Treasurer)',
    );
    _remarksCtrl = TextEditingController(text: 'हप्ता क्र. ${_activeEmi.emiNumber} जमा');

    _calculateOverdueAndLateFee();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final gid = widget.auth.currentGroup?.id;
      if (gid != null) {
        Provider.of<BankProvider>(context, listen: false).loadBanks(gid);
        widget.loanProv.loadLoans(gid);
      }
    });
  }

  Future<void> _switchLoan(Loan newLoan) async {
    await widget.loanProv.loadEmisForLoan(newLoan.id);
    final emis = widget.loanProv.selectedLoanEmis;
    LoanEmi? pending;
    try {
      pending = emis.firstWhere((e) => e.status == 'pending');
    } catch (_) {
      if (emis.isNotEmpty) pending = emis.first;
    }
    if (pending == null) {
      double monthlyInterest = 0.0;
      if (newLoan.interestRate > 0) {
        monthlyInterest = (newLoan.outstandingPrincipal * (newLoan.interestRate / 100.0)) / 12.0;
      }
      double monthlyPrincipal = newLoan.loanPeriodMonths > 0
          ? (newLoan.outstandingPrincipal / newLoan.loanPeriodMonths)
          : newLoan.outstandingPrincipal;
      if (newLoan.emiAmount > 0 && newLoan.emiAmount > monthlyInterest) {
        monthlyPrincipal = newLoan.emiAmount - monthlyInterest;
      }
      pending = LoanEmi(
        id: '',
        loanId: newLoan.id,
        emiNumber: emis.length + 1,
        dueDate: newLoan.firstEmiDate.isNotEmpty ? newLoan.firstEmiDate : DateTime.now().toString().split(' ').first,
        principal: monthlyPrincipal,
        interest: monthlyInterest,
        emiAmount: monthlyPrincipal + monthlyInterest,
        balance: (newLoan.outstandingPrincipal - monthlyPrincipal) > 0 ? (newLoan.outstandingPrincipal - monthlyPrincipal) : 0.0,
        status: 'pending',
      );
    }

    setState(() {
      _activeLoan = newLoan;
      _activeEmi = pending!;
      _principalCtrl.text = _activeEmi.principal.toStringAsFixed(0);
      _interestCtrl.text = _activeEmi.interest.toStringAsFixed(0);
      _remarksCtrl.text = 'हप्ता क्र. ${_activeEmi.emiNumber} जमा';
    });
    _calculateOverdueAndLateFee();
  }

  @override
  void dispose() {
    _principalCtrl.dispose();
    _interestCtrl.dispose();
    _lateFeeCtrl.dispose();
    _totalPaidCtrl.dispose();
    _txnIdCtrl.dispose();
    _paymentDateCtrl.dispose();
    _collectedByCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  void _calculateOverdueAndLateFee() {
    final emi = _activeEmi;
    final loanSettings = widget.loanProv.loanSettings;

    int lateDays = 0;
    try {
      final dueDate = DateTime.parse(emi.dueDate);
      final payDate = DateTime.tryParse(_paymentDateCtrl.text.trim()) ?? DateTime.now();

      final d1 = DateTime(dueDate.year, dueDate.month, dueDate.day);
      final d2 = DateTime(payDate.year, payDate.month, payDate.day);

      final diff = d2.difference(d1).inDays;
      if (diff > 0) {
        lateDays = diff;
      }
    } catch (_) {}

    _overdueDays = lateDays;

    final pendingPrincipal = double.tryParse(_principalCtrl.text) ?? emi.principal;
    final rate = loanSettings.lateFeePercentage;
    final graceDays = loanSettings.overdueDays >= 28 ? 0 : loanSettings.overdueDays;

    if (lateDays > graceDays && pendingPrincipal > 0) {
      double fee = 0.0;
      if (rate > 0) {
        fee = (pendingPrincipal * (rate / 100.0)) * (lateDays / 365.0);
      }
      if (fee <= 0 && rate > 0) {
        fee = lateDays * rate;
      }
      _calculatedLateFee = fee > 0 ? fee.roundToDouble() : 0.0;
    } else {
      _calculatedLateFee = 0.0;
    }

    _lateFeeCtrl.text = _calculatedLateFee.toStringAsFixed(0);
    _recalcTotal();
  }

  void _recalcTotal() {
    final p = double.tryParse(_principalCtrl.text) ?? 0.0;
    final i = double.tryParse(_interestCtrl.text) ?? 0.0;
    final lf = double.tryParse(_lateFeeCtrl.text) ?? 0.0;
    _totalPaidCtrl.text = (p + i + lf).toStringAsFixed(0);
    setState(() {});
  }

  Future<void> _pickDate() async {
    DateTime initDate = DateTime.tryParse(_paymentDateCtrl.text.trim()) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: 'हप्ता भरणा तारीख निवडा (Payment Date)',
    );
    if (picked != null) {
      setState(() {
        _paymentDateCtrl.text =
            "${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
      _calculateOverdueAndLateFee();
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
        width: isMobile ? double.infinity : 520,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
        padding: EdgeInsets.all(isMobile ? 14 : 24),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
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
                          child: const Icon(Icons.payments_rounded, color: AppColors.primary, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '💰 स्थिर हप्ता वसुली (Fixed EMI)',
                                style: GoogleFonts.poppins(fontSize: isMobile ? 15 : 16, fontWeight: FontWeight.w700),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${_activeLoan.memberName ?? "सदस्य"} • कर्ज क्र: ${_activeLoan.loanCode}',
                                style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF1E88E5), fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.black87, size: 22),
                      tooltip: 'स्क्रीन बंद करा (Close)',
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
              const Divider(height: 16),

              // Member & Loan Selector
              Consumer<LoanProvider>(
                builder: (context, loanProv, _) {
                  final activeLoans = loanProv.fixedEmiLoans.where((l) => (l.status == 'active' || l.status == 'disbursed') && l.outstandingPrincipal > 0).toList();
                  final displayLoans = activeLoans.isNotEmpty ? activeLoans : (_activeLoan.isFixedEmi ? [_activeLoan] : <Loan>[]);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        value: displayLoans.any((l) => l.id == _activeLoan.id)
                            ? _activeLoan.id
                            : (displayLoans.isNotEmpty ? displayLoans.first.id : null),
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'सभासद व कर्ज निवडा (स्थिर हप्ता - Fixed EMI)*',
                          prefixIcon: const Icon(Icons.person, color: Color(0xFF1E88E5), size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        items: displayLoans.map((l) {
                          return DropdownMenuItem<String>(
                            value: l.id,
                            child: Text(
                              '${l.memberName ?? "सदस्य"} (${l.loanCode}) - शिल्लक: ₹${l.outstandingPrincipal.toStringAsFixed(0)}',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          );
                        }).toList(),
                        onChanged: (loanId) {
                          if (loanId != null && loanId != _activeLoan.id) {
                            final match = displayLoans.where((l) => l.id == loanId).toList();
                            if (match.isNotEmpty) {
                              _switchLoan(match.first);
                            }
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                  );
                },
              ),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('हप्ता क्रमांक (EMI No.)', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary)),
                        Text('हप्ता #${_activeEmi.emiNumber} / ${_activeLoan.numberOfEmis}', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('नियत तारीख (Due Date)', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary)),
                        Text(_activeEmi.dueDate, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.danger)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              if (_overdueDays > 0) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.dangerBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.danger.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'विलंब: $_overdueDays दिवस झाले आहेत. नियमानुसार लेट फी लागू झाली आहे.',
                          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.danger),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.successBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.success.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'हप्ता वेळेवर भरला जात आहे (On Time)',
                          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.success),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),

              if (isMobile) ...[
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _principalCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'मुद्दल (Principal)*', prefixText: '₹ '),
                        onChanged: (_) => _calculateOverdueAndLateFee(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _interestCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'व्याज (Interest)*', prefixText: '₹ '),
                        onChanged: (_) => _recalcTotal(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _lateFeeCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'लेट फी / दंड (Late Fee)', prefixText: '₹ '),
                  onChanged: (_) => _recalcTotal(),
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _principalCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'मुद्दल (Principal)*', prefixText: '₹ '),
                        onChanged: (_) => _calculateOverdueAndLateFee(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _interestCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'व्याज (Interest)*', prefixText: '₹ '),
                        onChanged: (_) => _recalcTotal(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _lateFeeCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'लेट फी / दंड', prefixText: '₹ '),
                        onChanged: (_) => _recalcTotal(),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 14),

              if (isMobile) ...[
                TextField(
                  controller: _totalPaidCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'एकूण भरलेली रक्कम (Total Paid)*',
                    prefixText: '₹ ',
                  ),
                ),
                const SizedBox(height: 12),
                _buildPaymentSourceDropdown(),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _totalPaidCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'एकूण भरलेली रक्कम (Total Paid)*',
                          prefixText: '₹ ',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildPaymentSourceDropdown(),
                    ),
                  ],
                ),
              ],
              if (_paymentMode == 'Bank' || _paymentMode == 'UPI') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _txnIdCtrl,
                  decoration: const InputDecoration(
                    labelText: 'व्यवहार क्रमांक / Transaction ID / UTR',
                    hintText: 'उदा. UPI-9238491203',
                  ),
                ),
              ],
              const SizedBox(height: 12),

              if (isMobile) ...[
                InkWell(
                  onTap: _pickDate,
                  child: IgnorePointer(
                    child: TextField(
                      controller: _paymentDateCtrl,
                      decoration: InputDecoration(
                        labelText: 'भरणा तारीख (Payment Date)*',
                        prefixIcon: const Icon(Icons.calendar_month_rounded, size: 18, color: AppColors.primary),
                        suffixIcon: IconButton(icon: const Icon(Icons.edit_calendar_rounded, size: 18), onPressed: _pickDate),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _collectedByCtrl,
                  decoration: const InputDecoration(
                    labelText: 'संकलक (Collected By)*',
                    prefixIcon: Icon(Icons.person_outline_rounded, size: 18),
                  ),
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _pickDate,
                        child: IgnorePointer(
                          child: TextField(
                            controller: _paymentDateCtrl,
                            decoration: InputDecoration(
                              labelText: 'भरणा तारीख (Payment Date)*',
                              prefixIcon: const Icon(Icons.calendar_month_rounded, size: 18, color: AppColors.primary),
                              suffixIcon: IconButton(icon: const Icon(Icons.edit_calendar_rounded, size: 18), onPressed: _pickDate),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _collectedByCtrl,
                        decoration: const InputDecoration(
                          labelText: 'संकलक (Collected By)*',
                          prefixIcon: Icon(Icons.person_outline_rounded, size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _remarksCtrl,
                decoration: const InputDecoration(labelText: 'शेरा / टिप (Remarks)'),
              ),
              const SizedBox(height: 20),

              if (isMobile) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 2,
                    ),
                    icon: _isSaving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.check_circle_rounded, color: Colors.white),
                    label: Text(
                      _isSaving ? 'जमा होत आहे...' : 'हप्ता जमा करा (SAVE EMI)',
                      style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 14),
                    ),
                    onPressed: _isSaving ? null : _handleSave,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text(AppStrings.cancel, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).viewInsets.bottom > 0 ? 16 : 8),
              ] else ...[
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
                          _isSaving ? 'जमा होत आहे...' : 'हप्ता जमा करा (Save EMI)',
                          style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                        onPressed: _isSaving ? null : _handleSave,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSave() async {
    final paid = double.tryParse(_totalPaidCtrl.text) ?? 0.0;
    if (paid <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('कृपया योग्य हप्ता रक्कम टाका!')));
      return;
    }

    final groupId = widget.auth.currentGroup?.id;
    if (groupId == null) return;

    final dashProv = Provider.of<DashboardProvider>(context, listen: false);
    final bankProv = Provider.of<BankProvider>(context, listen: false);

    setState(() => _isSaving = true);

    final principal = double.tryParse(_principalCtrl.text) ?? 0.0;
    final interest = double.tryParse(_interestCtrl.text) ?? 0.0;
    final lateFee = double.tryParse(_lateFeeCtrl.text) ?? 0.0;

    final success = await widget.loanProv.recordEmiPayment(
      groupId: groupId,
      loanId: _activeLoan.id,
      emiId: _activeEmi.id,
      emiNumber: _activeEmi.emiNumber,
      principalPaid: principal,
      interestPaid: interest,
      lateFee: lateFee,
      totalPaid: paid,
      paymentMode: _paymentMode,
      bankAccountId: (_paymentMode == 'Bank' || _paymentMode == 'UPI') ? _selectedBankAccountId : null,
      transactionId: _txnIdCtrl.text.trim(),
      paymentDate: _paymentDateCtrl.text.trim(),
      collectedBy: _collectedByCtrl.text.trim(),
      borrowerName: _activeLoan.memberName,
      loanCode: _activeLoan.loanCode,
      remarks: _remarksCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      try {
        await dashProv.loadDashboardMetrics(groupId);
        await bankProv.loadBanks(groupId);
      } catch (_) {}
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('हप्ता क्र. ${_activeEmi.emiNumber} यशस्वीरीत्या जमा झाला! पावती: EMI-${_activeLoan.loanCode}-${_activeEmi.emiNumber}'),
          backgroundColor: AppColors.success,
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
              decoration: const InputDecoration(
                labelText: 'भरणा माध्यम (Payment Source)*',
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              ),
              items: [
                const DropdownMenuItem(value: 'Cash', child: Text('हातातील रोख (Cash in Hand)', overflow: TextOverflow.ellipsis)),
                ...availableBanks.map((bank) {
                  return DropdownMenuItem<String>(
                    value: 'bank_${bank.id}',
                    child: Text(
                      '🏦 ${bank.bankName} (${bank.maskedAccountNumber}) - ₹${bank.currentBalance.toStringAsFixed(0)}',
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
    );
  }
}
