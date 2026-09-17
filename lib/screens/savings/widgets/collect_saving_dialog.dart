import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_strings.dart';
import '../../../models/member.dart';
import '../../../models/monthly_saving.dart';
import '../../../models/bank_account.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/monthly_savings_provider.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../providers/bank_provider.dart';

class CollectSavingDialog extends StatefulWidget {
  final MonthlySaving monthlySaving;
  final AuthProvider auth;
  final MonthlySavingsProvider savingsProv;
  final List<Member> members;
  final bool isEdit;

  const CollectSavingDialog({
    super.key,
    required this.monthlySaving,
    required this.auth,
    required this.savingsProv,
    required this.members,
    this.isEdit = false,
  });

  @override
  State<CollectSavingDialog> createState() => _CollectSavingDialogState();
}

class _CollectSavingDialogState extends State<CollectSavingDialog> {
  late TextEditingController _amountPaidCtrl;
  late TextEditingController _lateFeeCtrl;
  late TextEditingController _txnIdCtrl;
  late TextEditingController _paymentDateCtrl;
  late TextEditingController _collectedByCtrl;
  late TextEditingController _remarksCtrl;

  String _paymentMode = 'Cash';
  String? _selectedBankAccountId;
  double _previousPending = 0.0;
  bool _isLoadingPending = true;
  bool _isSaving = false;

  late String _selectedMemberId;
  late MonthlySaving _activeSaving;

  @override
  void initState() {
    super.initState();
    _selectedMemberId = widget.monthlySaving.memberId;
    _activeSaving = widget.monthlySaving;

    final plan = widget.savingsProv.activePlan;
    final expected = widget.monthlySaving.expectedAmount > 0
        ? widget.monthlySaving.expectedAmount
        : (plan?.monthlyAmount ?? 500.0);

    // Auto-calculate late fee if today > due date + grace
    double autoLateFee = widget.monthlySaving.lateFee;
    if (!widget.isEdit && autoLateFee == 0 && plan != null) {
      try {
        final due = DateTime.parse(widget.monthlySaving.dueDate).add(Duration(days: plan.gracePeriodDays));
        if (DateTime.now().isAfter(due)) {
          autoLateFee = plan.lateFee;
        }
      } catch (_) {}
    }

    final total = expected + autoLateFee;
    final initialPaid = widget.isEdit && widget.monthlySaving.paidAmount > 0
        ? widget.monthlySaving.paidAmount
        : total;

    _amountPaidCtrl = TextEditingController(text: initialPaid.toStringAsFixed(0));
    _lateFeeCtrl = TextEditingController(text: (widget.isEdit ? widget.monthlySaving.lateFee : autoLateFee).toStringAsFixed(0));
    _txnIdCtrl = TextEditingController(text: widget.monthlySaving.transactionId ?? '');
    _paymentDateCtrl = TextEditingController(
      text: widget.monthlySaving.paymentDate ?? DateTime.now().toString().split(' ').first,
    );
    _collectedByCtrl = TextEditingController(
      text: widget.monthlySaving.collectedBy ?? widget.auth.currentProfile?.fullName ?? 'व्यवस्थापक',
    );
    _remarksCtrl = TextEditingController(text: widget.monthlySaving.remarks ?? '');
    _paymentMode = widget.monthlySaving.paymentMode.isNotEmpty
        ? (widget.monthlySaving.paymentMode[0].toUpperCase() + widget.monthlySaving.paymentMode.substring(1))
        : 'Cash';

    _loadPreviousPending();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.auth.currentGroup != null) {
        Provider.of<BankProvider>(context, listen: false).loadBanks(widget.auth.currentGroup!.id);
      }
    });
  }

  Future<void> _loadPreviousPending() async {
    if (widget.auth.currentGroup != null) {
      Member? matchedMember;
      try {
        matchedMember = widget.members.firstWhere((m) => m.id == _selectedMemberId);
      } catch (_) {}

      final prev = await widget.savingsProv.getPreviousPendingForMember(
        groupId: widget.auth.currentGroup!.id,
        memberId: _selectedMemberId,
        member: matchedMember,
      );
      if (mounted) {
        setState(() {
          _previousPending = prev;
          _isLoadingPending = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoadingPending = false);
    }
  }

  void _onMemberChanged(String? newMemberId) async {
    if (newMemberId == null || newMemberId == _selectedMemberId) return;

    Member? member;
    try {
      member = widget.members.firstWhere((m) => m.id == newMemberId);
    } catch (_) {}

    final existing = widget.savingsProv.monthlySavings.firstWhere(
      (s) => s.memberId == newMemberId,
      orElse: () => MonthlySaving(
        id: '',
        groupId: widget.auth.currentGroup?.id ?? '',
        memberId: newMemberId,
        memberName: member?.fullName,
        memberCode: member?.memberCode,
        mobileNumber: member?.mobileNumber,
        month: widget.savingsProv.selectedMonth,
        year: widget.savingsProv.selectedYear,
        dueDate: DateTime.now().toString().split(' ').first,
        expectedAmount: widget.savingsProv.activePlan?.monthlyAmount ?? 500.0,
        paidAmount: 0.0,
      ),
    );

    final plan = widget.savingsProv.activePlan;
    final expected = existing.expectedAmount > 0 ? existing.expectedAmount : (plan?.monthlyAmount ?? 500.0);
    double autoLateFee = existing.lateFee;
    if (!widget.isEdit && autoLateFee == 0 && plan != null) {
      try {
        final due = DateTime.parse(existing.dueDate).add(Duration(days: plan.gracePeriodDays));
        if (DateTime.now().isAfter(due)) {
          autoLateFee = plan.lateFee;
        }
      } catch (_) {}
    }

    final total = expected + autoLateFee;

    setState(() {
      _selectedMemberId = newMemberId;
      _activeSaving = existing;
      _amountPaidCtrl.text = total.toStringAsFixed(0);
      _lateFeeCtrl.text = autoLateFee.toStringAsFixed(0);
      _isLoadingPending = true;
    });

    _loadPreviousPending();
  }

  @override
  void dispose() {
    _amountPaidCtrl.dispose();
    _lateFeeCtrl.dispose();
    _txnIdCtrl.dispose();
    _paymentDateCtrl.dispose();
    _collectedByCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = _activeSaving;
    final lateFeeVal = double.tryParse(_lateFeeCtrl.text) ?? 0.0;
    final totalDue = s.expectedAmount + lateFeeVal;
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
              // Title Header
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
                          child: const Icon(Icons.add_card_rounded, color: AppColors.primary, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.isEdit
                                    ? AppStrings.tr('बचत नोंद संपादन (Edit Saving)', 'Edit Monthly Saving')
                                    : AppStrings.tr('मासिक बचत संकलन (Collect Saving)', 'Collect Monthly Saving'),
                                style: GoogleFonts.poppins(fontSize: isMobile ? 15 : 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${s.monthNameMr} ${s.year} (${s.monthNameEn} ${s.year})',
                                style: GoogleFonts.poppins(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
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

              // 0. Member Selector (Dropdown to select any member)
              if (!widget.isEdit && widget.members.isNotEmpty) ...[
                Text(
                  AppStrings.tr('सभासद निवडा (Select Member)', 'Select Member'),
                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.white,
                  ),
                  child: DropdownButtonFormField<String>(
                    value: widget.members.any((m) => m.id == _selectedMemberId) ? _selectedMemberId : widget.members.first.id,
                    isExpanded: true,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.person_search_rounded, color: AppColors.primary, size: 20),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: widget.members.map((m) {
                      return DropdownMenuItem<String>(
                        value: m.id,
                        child: Text(
                          '${m.fullName} (${m.memberCode})',
                          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: _onMemberChanged,
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // 1. Member Information Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.primary.withOpacity(0.12),
                      child: Text(
                        (s.memberName != null && s.memberName!.isNotEmpty) ? s.memberName![0] : 'S',
                        style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.memberName ?? 'सभासद',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'सदस्य क्र: ${s.memberCode ?? "MB-001"} • मो: ${s.mobileNumber ?? "-"}',
                            style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 2. Payment Breakdown Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    _buildRow('नियमित मासिक बचत (Monthly Saving):', '₹ ${s.expectedAmount.toStringAsFixed(0)}'),
                    const SizedBox(height: 8),
                    _buildRow(
                      'मागील महिन्यांची थकबाकी (Previous Pending):',
                      _isLoadingPending ? 'मोजत आहे...' : '₹ ${_previousPending.toStringAsFixed(0)}',
                      textColor: _previousPending > 0 ? AppColors.danger : AppColors.textSecondary,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text('विलंब शुल्क (Late Fee):', style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary)),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 85,
                          height: 38,
                          child: TextField(
                            controller: _lateFeeCtrl,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.right,
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              prefixText: '₹ ',
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'एकूण देय रक्कम (Total Amount):',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '₹ ${totalDue.toStringAsFixed(0)}',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 3. Payment Entry Form
              if (isMobile) ...[
                TextField(
                  controller: _amountPaidCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'आता भरलेली रक्कम (Amount Paid)*',
                    prefixText: '₹ ',
                  ),
                ),
                _buildPaymentSourceDropdown(),
                if (_paymentMode == 'Bank' || _paymentMode == 'UPI') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _txnIdCtrl,
                    decoration: const InputDecoration(
                      labelText: 'व्यवहार क्रमांक / Transaction ID / UTR*',
                      hintText: 'उदा. UPI Ref 324109823412',
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => _pickPaymentDate(context),
                  borderRadius: BorderRadius.circular(10),
                  child: IgnorePointer(
                    child: TextField(
                      controller: _paymentDateCtrl,
                      decoration: InputDecoration(
                        labelText: 'भरणा तारीख (Payment Date)*',
                        prefixIcon: const Icon(Icons.calendar_month_rounded, size: 20, color: AppColors.primary),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.edit_calendar_rounded, size: 20, color: AppColors.primary),
                          onPressed: () => _pickPaymentDate(context),
                        ),
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
                      child: TextField(
                        controller: _amountPaidCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'आता भरलेली रक्कम (Amount Paid)*',
                          prefixText: '₹ ',
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _buildPaymentSourceDropdown(),
                    ),
                  ],
                ),
                if (_paymentMode == 'Bank' || _paymentMode == 'UPI') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _txnIdCtrl,
                    decoration: const InputDecoration(
                      labelText: 'व्यवहार क्रमांक / Transaction ID / UTR*',
                      hintText: 'उदा. UPI Ref 324109823412',
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickPaymentDate(context),
                        borderRadius: BorderRadius.circular(10),
                        child: IgnorePointer(
                          child: TextField(
                            controller: _paymentDateCtrl,
                            decoration: InputDecoration(
                              labelText: 'भरणा तारीख (Payment Date)*',
                              prefixIcon: const Icon(Icons.calendar_month_rounded, size: 20, color: AppColors.primary),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.edit_calendar_rounded, size: 20, color: AppColors.primary),
                                onPressed: () => _pickPaymentDate(context),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
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
                decoration: const InputDecoration(
                  labelText: 'टिप / शेरा (Remarks / Notes)',
                  hintText: 'उदा. वेळेवर भरणा केला / ऑनलाईन पावती',
                ),
              ),
              const SizedBox(height: 20),

              // Action Buttons
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
                        : const Icon(Icons.receipt_long_rounded, color: Colors.white),
                    label: Text(
                      _isSaving
                          ? 'जतन होत आहे...'
                          : (widget.isEdit
                              ? 'बदल जतन करा (UPDATE SAVING)'
                              : 'जतन करा व पावती पहा (SAVE & RECEIPT)'),
                      style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 13),
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
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: _isSaving
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.receipt_long_rounded, color: Colors.white),
                        label: Text(
                          _isSaving
                              ? 'जतन होत आहे...'
                              : (widget.isEdit
                                  ? 'बदल जतन करा (UPDATE SAVING)'
                                  : 'जतन करा व पावती पहा (SAVE & RECEIPT)'),
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
              decoration: const InputDecoration(labelText: 'भरणा माध्यम (Payment Source)*'),
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

  Widget _buildRow(String label, String value, {Color? textColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(label, style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary)),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: textColor ?? AppColors.textPrimary),
        ),
      ],
    );
  }

  Future<void> _pickPaymentDate(BuildContext context) async {
    DateTime initialDate = DateTime.tryParse(_paymentDateCtrl.text.trim()) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: 'भरणा तारीख निवडा (Select Payment Date)',
      cancelText: 'रद्द करा (Cancel)',
      confirmText: 'निवडा (Select)',
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final formatted =
          "${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      setState(() {
        _paymentDateCtrl.text = formatted;
      });
    }
  }

  Future<void> _handleSave() async {
    final paidAmount = double.tryParse(_amountPaidCtrl.text) ?? 0.0;
    final lateFee = double.tryParse(_lateFeeCtrl.text) ?? 0.0;

    if (paidAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('कृपया योग्य भरणा रक्कम टाका (Enter valid amount)')),
      );
      return;
    }

    final auth = widget.auth;
    if (auth.currentGroup == null) return;
    final groupId = auth.currentGroup!.id;

    final dashProv = Provider.of<DashboardProvider>(context, listen: false);
    final bankProv = Provider.of<BankProvider>(context, listen: false);

    setState(() => _isSaving = true);

    final currentSaving = _activeSaving;
    final currentMemberId = _selectedMemberId;

    final result = widget.isEdit
        ? await widget.savingsProv.updatePayment(
            savingId: currentSaving.id,
            groupId: groupId,
            memberId: currentMemberId,
            month: currentSaving.month,
            year: currentSaving.year,
            expectedAmount: currentSaving.expectedAmount,
            paidAmount: paidAmount,
            lateFee: lateFee,
            paymentMode: _paymentMode,
            transactionId: _txnIdCtrl.text.trim(),
            paymentDate: _paymentDateCtrl.text.trim(),
            collectedBy: _collectedByCtrl.text.trim(),
            remarks: _remarksCtrl.text.trim(),
            receiptNumber: currentSaving.receiptNumber,
            members: widget.members,
          )
        : await widget.savingsProv.recordPayment(
            groupId: groupId,
            memberId: currentMemberId,
            month: currentSaving.month,
            year: currentSaving.year,
            expectedAmount: currentSaving.expectedAmount,
            paidAmount: paidAmount,
            lateFee: lateFee,
            paymentMode: _paymentMode,
            transactionId: _txnIdCtrl.text.trim(),
            paymentDate: _paymentDateCtrl.text.trim(),
            collectedBy: _collectedByCtrl.text.trim(),
            remarks: _remarksCtrl.text.trim(),
            members: widget.members,
            bankAccountId: (_paymentMode == 'Bank' || _paymentMode == 'UPI') ? _selectedBankAccountId : null,
          );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (result != null) {
      try {
        await dashProv.loadDashboardMetrics(groupId);
        await bankProv.loadBanks(groupId);
      } catch (_) {}
      if (!mounted) return;
      Navigator.pop(context, result);
    }
  }
}
