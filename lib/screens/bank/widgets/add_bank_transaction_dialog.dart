import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_strings.dart';
import '../../../models/bank_account.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/bank_provider.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../services/supabase_service.dart';

class AddBankTransactionDialog extends StatefulWidget {
  final BankAccount? initialBank;
  final String? initialType; // 'deposit' or 'withdrawal'

  const AddBankTransactionDialog({
    super.key,
    this.initialBank,
    this.initialType,
  });

  @override
  State<AddBankTransactionDialog> createState() => _AddBankTransactionDialogState();
}

class _AddBankTransactionDialogState extends State<AddBankTransactionDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _dateCtrl;
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _refCtrl = TextEditingController();
  final TextEditingController _purposeCtrl = TextEditingController();
  final TextEditingController _performedByCtrl = TextEditingController();
  final TextEditingController _remarksCtrl = TextEditingController();

  String? _selectedBankId;
  String _type = 'deposit'; // 'deposit' or 'withdrawal'
  bool _isSubmitting = false;

  final List<String> _quickPurposes = [
    'हातातील रोख (Cash in Hand)',
    'बचत संकलन जमा (Savings Deposit)',
    'कर्ज हप्ता वसुली (EMI Collection)',
    'कर्ज वाटप (Loan Disbursement)',
    'खर्च चेक/RTGS (Expense Payment)',
    'बँक व्याज (Bank Interest Credit)',
    'बँक चार्जेस व SMS शुल्क (Bank Charges)',
    'शासकीय अनुदान / रिव्हॉल्व्हिंग फंड (Govt Grant)',
    'इतर जमा / नावे (Other)',
  ];

  @override
  void initState() {
    super.initState();
    final nowStr = DateTime.now().toIso8601String().split('T').first;
    _dateCtrl = TextEditingController(text: nowStr);

    if (widget.initialBank != null) {
      _selectedBankId = widget.initialBank!.id;
    }

    if (widget.initialType != null && widget.initialType!.isNotEmpty) {
      _type = widget.initialType!.toLowerCase().contains('with') ? 'withdrawal' : 'deposit';
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    _performedByCtrl.text = auth.currentProfile?.fullName ?? 'व्यवस्थापक';
  }

  @override
  void dispose() {
    _dateCtrl.dispose();
    _amountCtrl.dispose();
    _refCtrl.dispose();
    _purposeCtrl.dispose();
    _performedByCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    DateTime initial = DateTime.tryParse(_dateCtrl.text) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _dateCtrl.text =
            "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedBankId == null || _selectedBankId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.tr('कृपया बँक खाते निवडा', 'Please select a bank account'))),
      );
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final bankProv = Provider.of<BankProvider>(context, listen: false);
    final dashProv = Provider.of<DashboardProvider>(context, listen: false);

    if (auth.currentGroup == null) return;
    final groupId = auth.currentGroup!.id;

    setState(() => _isSubmitting = true);

    final amt = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
    final purposeText = _purposeCtrl.text.trim();
    final isCashTransfer = purposeText.contains('हातातील रोख') || purposeText.toLowerCase().contains('cash in hand');

    final success = await bankProv.addTransaction(
      groupId: groupId,
      bankAccountId: _selectedBankId!,
      transactionDate: _dateCtrl.text.trim(),
      type: _type,
      amount: amt,
      referenceNumber: _refCtrl.text.trim().isNotEmpty ? _refCtrl.text.trim() : null,
      purpose: purposeText.isNotEmpty ? purposeText : null,
      performedBy: _performedByCtrl.text.trim().isNotEmpty ? _performedByCtrl.text.trim() : null,
      remarks: _remarksCtrl.text.trim().isNotEmpty ? _remarksCtrl.text.trim() : null,
    );

    if (success && isCashTransfer) {
      // CONTRA ENTRY: Adjust Cash in Hand via Cash Book
      try {
        final service = SupabaseService();
        final bankList = bankProv.activeBanks.where((b) => b.id == _selectedBankId).toList();
        final bankName = bankList.isNotEmpty ? bankList.first.bankName : 'बँक खाते';

        // Fetch latest cash balance
        final lastCashRes = await service.client
            .from('cash_book')
            .select('balance_after')
            .eq('group_id', groupId)
            .order('entry_date', ascending: false)
            .limit(1);

        double prevBal = (lastCashRes as List).isNotEmpty
            ? ((lastCashRes.first['balance_after'] as num?)?.toDouble() ?? 0.0)
            : dashProv.cashInHand;

        if (prevBal <= 0 && dashProv.cashInHand > 0) {
          prevBal = dashProv.cashInHand;
        }

        if (prevBal <= 0) {
          try {
            final metrics = await service.fetchDashboardMetrics(groupId);
            final liveCash = (metrics['cash_in_hand'] as num?)?.toDouble() ?? 0.0;
            if (liveCash > 0) {
              prevBal = liveCash;
            }
          } catch (_) {}
        }

        final isDeposit = _type == 'deposit';
        final newCashBal = isDeposit
            ? ((prevBal - amt >= 0) ? (prevBal - amt) : 0.0)
            : (prevBal + amt);

        await service.client.from('cash_book').insert({
          'group_id': groupId,
          'entry_date': _dateCtrl.text.trim(),
          'type': isDeposit ? 'cash_out' : 'cash_in',
          'amount': amt,
          'balance_after': newCashBal,
          'description': isDeposit
              ? 'बँकेत रोख भरणा ($bankName) - $purposeText'
              : 'बँकेतून रोख काढली ($bankName) - $purposeText',
          'reference_module': 'bank',
          'entered_by': _performedByCtrl.text.trim().isNotEmpty ? _performedByCtrl.text.trim() : 'व्यवस्थापक',
        });
      } catch (e) {
        debugPrint('Error inserting contra cash_book entry: $e');
      }
    }

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        try {
          await dashProv.loadDashboardMetrics(groupId);
          await bankProv.loadData(groupId);
        } catch (_) {}

        if (!mounted) return;
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Text(
              isCashTransfer
                  ? (_type == 'deposit'
                      ? 'बँकेत ₹${amt.toStringAsFixed(0)} जमा झाले व हातातील रोख (Cash in Hand) मधून ₹${amt.toStringAsFixed(0)} वजा झाले!'
                      : 'बँकेतून ₹${amt.toStringAsFixed(0)} काढले व हातातील रोख (Cash in Hand) मध्ये ₹${amt.toStringAsFixed(0)} जमा झाले!')
                  : (_type == 'deposit'
                      ? AppStrings.tr('बँकेमध्ये रक्कम यशस्वीरीत्या जमा केली!', 'Amount deposited successfully!')
                      : AppStrings.tr('बँकेतून रक्कम यशस्वीरीत्या नावे/काढली!', 'Amount withdrawn successfully!')),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.danger,
            content: Text(AppStrings.tr('त्रुटी: व्यवहार नोंदवता आला नाही.', 'Error recording transaction.')),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bankProv = Provider.of<BankProvider>(context);
    final activeBanks = bankProv.activeBanks;

    // Set default bank if not yet selected
    if (_selectedBankId == null && activeBanks.isNotEmpty) {
      _selectedBankId = activeBanks.first.id;
    }

    final isDeposit = _type == 'deposit';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: isDeposit ? AppColors.success : AppColors.danger,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Icon(
                    isDeposit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isDeposit
                          ? AppStrings.tr('बँकेत ठेव/रक्कम जमा करा', 'Bank Deposit')
                          : AppStrings.tr('बँकेतून रक्कम काढा/नावे करा', 'Bank Withdrawal'),
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // Form Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Type Switcher
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => setState(() => _type = 'deposit'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isDeposit ? AppColors.success : Colors.transparent,
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  alignment: Alignment.center,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.arrow_downward,
                                        size: 18,
                                        color: isDeposit ? Colors.white : Colors.grey.shade700,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        AppStrings.tr('+ जमा (Deposit)', '+ Deposit'),
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                          color: isDeposit ? Colors.white : Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: InkWell(
                                onTap: () => setState(() => _type = 'withdrawal'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: !isDeposit ? AppColors.danger : Colors.transparent,
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  alignment: Alignment.center,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.arrow_upward,
                                        size: 18,
                                        color: !isDeposit ? Colors.white : Colors.grey.shade700,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        AppStrings.tr('- नावे (Withdrawal)', '- Withdrawal'),
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                          color: !isDeposit ? Colors.white : Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Bank Account Dropdown
                      DropdownButtonFormField<String>(
                        value: _selectedBankId,
                        decoration: InputDecoration(
                          labelText: AppStrings.tr('बँक खाते निवडा (Bank Account)*', 'Select Bank Account*'),
                          prefixIcon: const Icon(Icons.account_balance, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        items: activeBanks.map((b) {
                          return DropdownMenuItem<String>(
                            value: b.id,
                            child: Text(
                              '${b.bankName} (${b.maskedAccountNumber}) - ₹${b.currentBalance.toStringAsFixed(0)}',
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(fontSize: 13),
                            ),
                          );
                        }).toList(),
                        onChanged: (v) => setState(() => _selectedBankId = v),
                        validator: (v) => (v == null || v.isEmpty)
                            ? AppStrings.tr('कृपया बँक खाते निवडा', 'Select bank account')
                            : null,
                      ),
                      const SizedBox(height: 14),

                      // Date & Amount
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _dateCtrl,
                              readOnly: true,
                              onTap: _pickDate,
                              decoration: InputDecoration(
                                labelText: AppStrings.tr('तारीख (Date)*', 'Date*'),
                                prefixIcon: const Icon(Icons.calendar_today, size: 20),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: TextFormField(
                              controller: _amountCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: AppStrings.tr('रक्कम (Amount)*', 'Amount*'),
                                prefixText: '₹ ',
                                prefixIcon: const Icon(Icons.currency_rupee, size: 20),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return AppStrings.tr('रक्कम टाका', 'Enter amount');
                                }
                                final val = double.tryParse(v.trim());
                                if (val == null || val <= 0) {
                                  return AppStrings.tr('वैध रक्कम टाका', 'Enter valid amount');
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Reference Number / Cheque / UTR
                      TextFormField(
                        controller: _refCtrl,
                        decoration: InputDecoration(
                          labelText: AppStrings.tr('धनादेश / UTR / संदर्भ क्र. (Ref / Cheque / UTR No)', 'Reference / UTR / Cheque No'),
                          hintText: 'उदा. CHQ-104928 किंवा UPI / UTR No',
                          prefixIcon: const Icon(Icons.tag, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Purpose / Category
                      TextFormField(
                        controller: _purposeCtrl,
                        decoration: InputDecoration(
                          labelText: AppStrings.tr('व्यवहाराचा उद्देश / कारण (Purpose)*', 'Purpose / Reason*'),
                          hintText: 'उदा. बचत संकलन, कर्ज वाटप, चेक खर्च',
                          prefixIcon: const Icon(Icons.description, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? AppStrings.tr('कृपया उद्देश टाका', 'Enter purpose')
                            : null,
                      ),
                      const SizedBox(height: 8),

                      // Quick Purpose Chips
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _quickPurposes.map((p) {
                          final shortName = p.split(' (').first;
                          final isCashChip = p.contains('हातातील रोख') || p.contains('Cash in Hand');
                          final isSelected = _purposeCtrl.text.contains(shortName);

                          return ActionChip(
                            avatar: isCashChip
                                ? Icon(Icons.account_balance_wallet_rounded, size: 14, color: isDeposit ? AppColors.success : AppColors.primary)
                                : null,
                            label: Text(
                              shortName,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: isCashChip ? FontWeight.w700 : FontWeight.w500,
                                color: isCashChip
                                    ? (isDeposit ? AppColors.success : AppColors.primary)
                                    : (isSelected ? AppColors.primary : Colors.black87),
                              ),
                            ),
                            backgroundColor: isCashChip
                                ? (isDeposit ? AppColors.success.withOpacity(0.12) : AppColors.primary.withOpacity(0.12))
                                : (isSelected ? AppColors.primary.withOpacity(0.08) : Colors.grey.shade100),
                            side: isCashChip
                                ? BorderSide(color: isDeposit ? AppColors.success : AppColors.primary, width: 1.2)
                                : BorderSide(color: Colors.grey.shade300),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            onPressed: () {
                              setState(() {
                                if (isCashChip) {
                                  _purposeCtrl.text = isDeposit
                                      ? 'हातातील रोख बँकेत जमा (Cash in Hand to Bank)'
                                      : 'बँकेतून रोख काढली (Cash withdrawn from Bank)';
                                } else {
                                  _purposeCtrl.text = shortName;
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),

                      // Live Contra Information Card when Cash in Hand is chosen
                      if (_purposeCtrl.text.contains('हातातील रोख') || _purposeCtrl.text.toLowerCase().contains('cash in hand')) ...[
                        const SizedBox(height: 12),
                        Consumer<DashboardProvider>(
                          builder: (context, dashProv, _) {
                            final currentCash = dashProv.cashInHand;
                            final enteredAmt = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
                            final resultingCash = isDeposit
                                ? (currentCash - enteredAmt >= 0 ? currentCash - enteredAmt : 0.0)
                                : (currentCash + enteredAmt);
                            final isExceeding = isDeposit && enteredAmt > currentCash && currentCash > 0;

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isExceeding
                                    ? Colors.amber.shade50
                                    : (isDeposit ? const Color(0xFFF0FDF4) : const Color(0xFFEFF6FF)),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isExceeding
                                      ? Colors.amber.shade300
                                      : (isDeposit ? const Color(0xFF86EFAC) : const Color(0xFF93C5FD)),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    isExceeding
                                        ? Icons.warning_amber_rounded
                                        : (isDeposit ? Icons.swap_horiz_rounded : Icons.account_balance_wallet_rounded),
                                    color: isExceeding
                                        ? Colors.amber.shade900
                                        : (isDeposit ? AppColors.success : AppColors.primary),
                                    size: 22,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isDeposit
                                              ? 'हातातील रोख ➔ बँक खात्यात जमा (Cash to Bank)'
                                              : 'बँक खाते ➔ हातातील रोख (Withdrawal to Cash)',
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                            color: isExceeding
                                                ? Colors.amber.shade900
                                                : (isDeposit ? AppColors.success : AppColors.primary),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'सध्या हातातील रोख शिल्लक: ₹ ${currentCash.toStringAsFixed(2)}',
                                          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                                        ),
                                        if (enteredAmt > 0) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            isDeposit
                                                ? 'बँकेत ₹${enteredAmt.toStringAsFixed(0)} जमा झाल्यानंतर शिल्लक रोख: ₹ ${resultingCash.toStringAsFixed(2)}'
                                                : 'बँकेतून ₹${enteredAmt.toStringAsFixed(0)} काढल्यानंतर नवीन शिल्लक रोख: ₹ ${resultingCash.toStringAsFixed(2)}',
                                            style: GoogleFonts.poppins(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: isExceeding ? AppColors.danger : Colors.grey.shade800,
                                            ),
                                          ),
                                        ],
                                        if (isExceeding) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            '⚠️ सूचना: भरणा रक्कम उपलब्ध रोख रकमेपेक्षा जास्त आहे!',
                                            style: GoogleFonts.poppins(fontSize: 11, color: AppColors.danger, fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                      const SizedBox(height: 14),

                      // Performed By & Remarks
                      TextFormField(
                        controller: _performedByCtrl,
                        decoration: InputDecoration(
                          labelText: AppStrings.tr('व्यवहार करणारी व्यक्ती (Performed By)', 'Performed By'),
                          prefixIcon: const Icon(Icons.person, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _remarksCtrl,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: AppStrings.tr('शेरा (Remarks)', 'Remarks'),
                          hintText: 'अतिरिक्त माहिती किंवा टिप',
                          prefixIcon: const Icon(Icons.comment, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                    child: Text(AppStrings.tr('रद्द करा', 'Cancel')),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _save,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Icon(isDeposit ? Icons.add_circle_outline : Icons.remove_circle_outline, size: 18),
                    label: Text(
                      isDeposit
                          ? AppStrings.tr('जमा नोंदवा (Record Deposit)', 'Record Deposit')
                          : AppStrings.tr('नावे नोंदवा (Record Withdrawal)', 'Record Withdrawal'),
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDeposit ? AppColors.success : AppColors.danger,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
