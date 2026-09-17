import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_strings.dart';
import '../../../models/bank_account.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/bank_provider.dart';

class AddEditBankDialog extends StatefulWidget {
  final BankAccount? bank; // Null if adding new bank

  const AddEditBankDialog({super.key, this.bank});

  @override
  State<AddEditBankDialog> createState() => _AddEditBankDialogState();
}

class _AddEditBankDialogState extends State<AddEditBankDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _bankNameCtrl;
  late final TextEditingController _branchCtrl;
  late final TextEditingController _holderCtrl;
  late final TextEditingController _accountNumberCtrl;
  late final TextEditingController _ifscCtrl;
  late final TextEditingController _openingBalCtrl;
  late final TextEditingController _openingDateCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _mobileCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _notesCtrl;

  String _accountType = 'savings';
  String _status = 'active';
  bool _isSubmitting = false;

  bool get isEdit => widget.bank != null;

  @override
  void initState() {
    super.initState();
    final b = widget.bank;
    final nowStr = DateTime.now().toIso8601String().split('T').first;

    _bankNameCtrl = TextEditingController(text: b?.bankName ?? '');
    _branchCtrl = TextEditingController(text: b?.branch ?? '');
    _holderCtrl = TextEditingController(text: b?.accountHolder ?? '');
    _accountNumberCtrl = TextEditingController(text: b?.accountNumber ?? '');
    _ifscCtrl = TextEditingController(text: b?.ifsc ?? '');
    _openingBalCtrl = TextEditingController(text: b != null ? b.openingBalance.toStringAsFixed(2) : '0.00');
    _openingDateCtrl = TextEditingController(text: b?.openingBalanceDate ?? nowStr);
    _addressCtrl = TextEditingController(text: b?.bankAddress ?? '');
    _mobileCtrl = TextEditingController(text: b?.mobileNumber ?? '');
    _emailCtrl = TextEditingController(text: b?.email ?? '');
    _notesCtrl = TextEditingController(text: b?.notes ?? '');

    if (b != null) {
      _accountType = b.accountType.isNotEmpty ? b.accountType : 'savings';
      _status = b.status.isNotEmpty ? b.status : 'active';
    }
  }

  @override
  void dispose() {
    _bankNameCtrl.dispose();
    _branchCtrl.dispose();
    _holderCtrl.dispose();
    _accountNumberCtrl.dispose();
    _ifscCtrl.dispose();
    _openingBalCtrl.dispose();
    _openingDateCtrl.dispose();
    _addressCtrl.dispose();
    _mobileCtrl.dispose();
    _emailCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    DateTime initial = DateTime.tryParse(_openingDateCtrl.text) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _openingDateCtrl.text =
            "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final bankProv = Provider.of<BankProvider>(context, listen: false);

    if (auth.currentGroup == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.tr('कृपया गट निवडा', 'Please select a group'))),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final openingBal = double.tryParse(_openingBalCtrl.text.trim()) ?? 0.0;

    final account = BankAccount(
      id: widget.bank?.id ?? '',
      groupId: auth.currentGroup!.id,
      bankName: _bankNameCtrl.text.trim(),
      branch: _branchCtrl.text.trim(),
      accountHolder: _holderCtrl.text.trim(),
      accountNumber: _accountNumberCtrl.text.trim(),
      ifsc: _ifscCtrl.text.trim().toUpperCase(),
      accountType: _accountType,
      openingBalance: openingBal,
      openingBalanceDate: _openingDateCtrl.text.trim(),
      currentBalance: isEdit ? widget.bank!.currentBalance : openingBal,
      status: _status,
      bankAddress: _addressCtrl.text.trim().isNotEmpty ? _addressCtrl.text.trim() : null,
      mobileNumber: _mobileCtrl.text.trim().isNotEmpty ? _mobileCtrl.text.trim() : null,
      email: _emailCtrl.text.trim().isNotEmpty ? _emailCtrl.text.trim() : null,
      notes: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
    );

    bool success = false;
    if (isEdit) {
      success = await bankProv.updateBankAccount(account, auth.currentGroup!.id);
    } else {
      success = await bankProv.addBankAccount(account, auth.currentGroup!.id);
    }

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Text(
              isEdit
                  ? AppStrings.tr('बँक माहिती यशस्वीरीत्या अद्ययावत झाली!', 'Bank account updated successfully!')
                  : AppStrings.tr('नवीन बँक खाते यशस्वीरीत्या जोडले गेले!', 'New bank account added successfully!'),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.danger,
            content: Text(AppStrings.tr('त्रुटी: बँक जतन करता आली नाही.', 'Error: Failed to save bank account.')),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 650;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 700,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isEdit
                          ? AppStrings.tr('बँक खात्याचे संपादन', 'Edit Bank Account')
                          : AppStrings.tr('नवीन बँक खाते जोडा', 'Add Bank Account'),
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
                      // Section 1: Core Bank Details
                      Text(
                        AppStrings.tr('बँकेचा तपशील (Bank Details)', 'Bank Details'),
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Bank Name & Branch
                      if (isWide)
                        Row(
                          children: [
                            Expanded(child: _buildBankNameField()),
                            const SizedBox(width: 16),
                            Expanded(child: _buildBranchField()),
                          ],
                        )
                      else ...[
                        _buildBankNameField(),
                        const SizedBox(height: 12),
                        _buildBranchField(),
                      ],
                      const SizedBox(height: 12),

                      // Account Holder & Account Number
                      if (isWide)
                        Row(
                          children: [
                            Expanded(child: _buildHolderField()),
                            const SizedBox(width: 16),
                            Expanded(child: _buildAccountNumberField()),
                          ],
                        )
                      else ...[
                        _buildHolderField(),
                        const SizedBox(height: 12),
                        _buildAccountNumberField(),
                      ],
                      const SizedBox(height: 12),

                      // IFSC Code & Account Type
                      if (isWide)
                        Row(
                          children: [
                            Expanded(child: _buildIfscField()),
                            const SizedBox(width: 16),
                            Expanded(child: _buildAccountTypeField()),
                          ],
                        )
                      else ...[
                        _buildIfscField(),
                        const SizedBox(height: 12),
                        _buildAccountTypeField(),
                      ],
                      const SizedBox(height: 16),

                      const Divider(),
                      const SizedBox(height: 12),

                      // Section 2: Opening Balance & Status
                      Text(
                        AppStrings.tr('शिल्लक व स्थिती (Balance & Status)', 'Balance & Status'),
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (isWide)
                        Row(
                          children: [
                            Expanded(child: _buildOpeningBalField()),
                            const SizedBox(width: 16),
                            Expanded(child: _buildOpeningDateField()),
                            const SizedBox(width: 16),
                            Expanded(child: _buildStatusField()),
                          ],
                        )
                      else ...[
                        _buildOpeningBalField(),
                        const SizedBox(height: 12),
                        _buildOpeningDateField(),
                        const SizedBox(height: 12),
                        _buildStatusField(),
                      ],
                      const SizedBox(height: 16),

                      const Divider(),
                      const SizedBox(height: 12),

                      // Section 3: Contact & Remarks (Optional)
                      Text(
                        AppStrings.tr('इतर माहिती (Contact & Notes)', 'Other Information'),
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (isWide)
                        Row(
                          children: [
                            Expanded(child: _buildMobileField()),
                            const SizedBox(width: 16),
                            Expanded(child: _buildEmailField()),
                          ],
                        )
                      else ...[
                        _buildMobileField(),
                        const SizedBox(height: 12),
                        _buildEmailField(),
                      ],
                      const SizedBox(height: 12),

                      _buildAddressField(),
                      const SizedBox(height: 12),

                      _buildNotesField(),
                    ],
                  ),
                ),
              ),
            ),

            // Footer / Actions
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
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
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
                        : const Icon(Icons.check_circle_outline, size: 18),
                    label: Text(
                      isEdit
                          ? AppStrings.tr('अद्ययावत करा', 'Update Bank')
                          : AppStrings.tr('जतन करा', 'Save Bank'),
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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

  Widget _buildBankNameField() {
    return TextFormField(
      controller: _bankNameCtrl,
      decoration: InputDecoration(
        labelText: AppStrings.tr('बँकेचे नाव (Bank Name)*', 'Bank Name*'),
        hintText: 'उदा. State Bank of India, बँक ऑफ महाराष्ट्र',
        prefixIcon: const Icon(Icons.account_balance, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      validator: (v) => (v == null || v.trim().isEmpty)
          ? AppStrings.tr('कृपया बँकेचे नाव टाका', 'Enter bank name')
          : null,
    );
  }

  Widget _buildBranchField() {
    return TextFormField(
      controller: _branchCtrl,
      decoration: InputDecoration(
        labelText: AppStrings.tr('शाखेचे नाव (Branch)*', 'Branch Name*'),
        hintText: 'उदा. शिवाजीनगर, मुख्य शाखा',
        prefixIcon: const Icon(Icons.location_city, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      validator: (v) => (v == null || v.trim().isEmpty)
          ? AppStrings.tr('कृपया शाखा टाका', 'Enter branch name')
          : null,
    );
  }

  Widget _buildHolderField() {
    return TextFormField(
      controller: _holderCtrl,
      decoration: InputDecoration(
        labelText: AppStrings.tr('खातेदाराचे नाव (Account Holder)*', 'Account Holder Name*'),
        hintText: 'उदा. सखी महिला बचत गट',
        prefixIcon: const Icon(Icons.person, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      validator: (v) => (v == null || v.trim().isEmpty)
          ? AppStrings.tr('कृपया खातेदाराचे नाव टाका', 'Enter account holder')
          : null,
    );
  }

  Widget _buildAccountNumberField() {
    return TextFormField(
      controller: _accountNumberCtrl,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: AppStrings.tr('खाते क्रमांक (Account Number)*', 'Account Number*'),
        hintText: 'उदा. 123456789012',
        prefixIcon: const Icon(Icons.numbers, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      validator: (v) => (v == null || v.trim().isEmpty)
          ? AppStrings.tr('कृपया खाते क्रमांक टाका', 'Enter account number')
          : null,
    );
  }

  Widget _buildIfscField() {
    return TextFormField(
      controller: _ifscCtrl,
      textCapitalization: TextCapitalization.characters,
      decoration: InputDecoration(
        labelText: AppStrings.tr('IFSC कोड (IFSC Code)*', 'IFSC Code*'),
        hintText: 'उदा. SBIN0001234',
        prefixIcon: const Icon(Icons.qr_code, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      validator: (v) => (v == null || v.trim().isEmpty)
          ? AppStrings.tr('कृपया IFSC कोड टाका', 'Enter IFSC code')
          : null,
    );
  }

  Widget _buildAccountTypeField() {
    return DropdownButtonFormField<String>(
      value: _accountType,
      decoration: InputDecoration(
        labelText: AppStrings.tr('खाते प्रकार (Account Type)*', 'Account Type*'),
        prefixIcon: const Icon(Icons.category, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      items: [
        DropdownMenuItem(
          value: 'savings',
          child: Text(AppStrings.tr('बचत खाते (Savings)', 'Savings Account')),
        ),
        DropdownMenuItem(
          value: 'current',
          child: Text(AppStrings.tr('चालू खाते (Current)', 'Current Account')),
        ),
      ],
      onChanged: (v) {
        if (v != null) setState(() => _accountType = v);
      },
    );
  }

  Widget _buildOpeningBalField() {
    return TextFormField(
      controller: _openingBalCtrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: AppStrings.tr('आरंभीची शिल्लक (Opening Bal)*', 'Opening Balance*'),
        prefixText: '₹ ',
        prefixIcon: const Icon(Icons.currency_rupee, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) {
          return AppStrings.tr('शिल्लक टाका', 'Enter amount');
        }
        if (double.tryParse(v.trim()) == null) {
          return AppStrings.tr('वैध रक्कम टाका', 'Enter valid amount');
        }
        return null;
      },
    );
  }

  Widget _buildOpeningDateField() {
    return TextFormField(
      controller: _openingDateCtrl,
      readOnly: true,
      onTap: _pickDate,
      decoration: InputDecoration(
        labelText: AppStrings.tr('आरंभीची तारीख (Opening Date)*', 'Opening Date*'),
        prefixIcon: const Icon(Icons.calendar_today, size: 20),
        suffixIcon: const Icon(Icons.arrow_drop_down),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildStatusField() {
    return DropdownButtonFormField<String>(
      value: _status,
      decoration: InputDecoration(
        labelText: AppStrings.tr('स्थिती (Status)*', 'Status*'),
        prefixIcon: const Icon(Icons.toggle_on, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      items: [
        DropdownMenuItem(
          value: 'active',
          child: Row(
            children: [
              const Icon(Icons.check_circle, size: 16, color: AppColors.success),
              const SizedBox(width: 8),
              Text(AppStrings.tr('सक्रिय (Active)', 'Active')),
            ],
          ),
        ),
        DropdownMenuItem(
          value: 'inactive',
          child: Row(
            children: [
              const Icon(Icons.cancel, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Text(AppStrings.tr('निष्क्रिय (Inactive)', 'Inactive')),
            ],
          ),
        ),
      ],
      onChanged: (v) {
        if (v != null) setState(() => _status = v);
      },
    );
  }

  Widget _buildMobileField() {
    return TextFormField(
      controller: _mobileCtrl,
      keyboardType: TextInputType.phone,
      decoration: InputDecoration(
        labelText: AppStrings.tr('मोबाईल क्रमांक (Mobile)', 'Mobile Number'),
        hintText: 'उदा. 9876543210',
        prefixIcon: const Icon(Icons.phone, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailCtrl,
      keyboardType: TextInputType.emailAddress,
      decoration: InputDecoration(
        labelText: AppStrings.tr('ईमेल (Email)', 'Email ID'),
        hintText: 'उदा. bank@example.com',
        prefixIcon: const Icon(Icons.email, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildAddressField() {
    return TextFormField(
      controller: _addressCtrl,
      maxLines: 2,
      decoration: InputDecoration(
        labelText: AppStrings.tr('बँकेचा पत्ता (Bank Address)', 'Bank Address'),
        hintText: 'शाखेचा संपूर्ण पत्ता किंवा पत्ता खूण',
        prefixIcon: const Icon(Icons.place, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildNotesField() {
    return TextFormField(
      controller: _notesCtrl,
      maxLines: 2,
      decoration: InputDecoration(
        labelText: AppStrings.tr('शेरा / नोंद (Notes)', 'Notes / Remarks'),
        hintText: 'अधिक माहिती, पासबुक क्रमांक, इत्यादी',
        prefixIcon: const Icon(Icons.note, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
