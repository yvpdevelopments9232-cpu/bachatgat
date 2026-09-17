import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_strings.dart';
import '../../../models/bank_account.dart';
import '../../../models/bank_transaction.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/bank_provider.dart';
import '../../../services/bank_service.dart';
import 'add_bank_transaction_dialog.dart';
import 'add_edit_bank_dialog.dart';

class BankDetailsDialog extends StatefulWidget {
  final BankAccount bank;

  const BankDetailsDialog({super.key, required this.bank});

  @override
  State<BankDetailsDialog> createState() => _BankDetailsDialogState();
}

class _BankDetailsDialogState extends State<BankDetailsDialog> {
  final BankService _service = BankService();
  bool _showFullAccount = false;
  bool _isLoadingTx = true;
  List<BankTransaction> _transactions = [];

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.currentGroup != null) {
      final tx = await _service.fetchBankTransactions(
        groupId: auth.currentGroup!.id,
        bankAccountId: widget.bank.id,
      );
      if (mounted) {
        setState(() {
          _transactions = tx;
          _isLoadingTx = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoadingTx = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bankProv = Provider.of<BankProvider>(context);
    final auth = Provider.of<AuthProvider>(context);
    // Find the latest state of this bank
    final currentBank = bankProv.banks.firstWhere(
      (b) => b.id == widget.bank.id,
      orElse: () => widget.bank,
    );

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 750,
          maxHeight: MediaQuery.of(context).size.height * 0.92,
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
                  const Icon(Icons.account_balance, color: Colors.white, size: 26),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentBank.bankName,
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        if (currentBank.branch.isNotEmpty)
                          Text(
                            'शाखा: ${currentBank.branch}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.85),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: currentBank.isActive
                          ? AppColors.success.withOpacity(0.25)
                          : Colors.grey.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: currentBank.isActive ? Colors.greenAccent : Colors.white70,
                      ),
                    ),
                    child: Text(
                      currentBank.isActive
                          ? AppStrings.tr('सक्रिय (Active)', 'Active')
                          : AppStrings.tr('निष्क्रिय (Inactive)', 'Inactive'),
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Balance Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withOpacity(0.08),
                            AppColors.primary.withOpacity(0.02),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.account_balance_wallet, color: AppColors.primary, size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppStrings.tr('चालू बँक शिल्लक (Current Bank Balance)', 'Current Bank Balance'),
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '₹ ${currentBank.currentBalance.toStringAsFixed(2)}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: currentBank.currentBalance >= 0 ? AppColors.success : AppColors.danger,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () async {
                              final res = await showDialog(
                                context: context,
                                builder: (_) => AddBankTransactionDialog(initialBank: currentBank),
                              );
                              if (res == true) {
                                _loadTransactions();
                              }
                            },
                            icon: const Icon(Icons.add, size: 16),
                            label: Text(
                              AppStrings.tr('+ व्यवहार नोंदवा', '+ Transaction'),
                              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Information Grid
                    Text(
                      AppStrings.tr('खात्याचा तपशील', 'Account Details'),
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 10),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          _buildDetailRow(
                            AppStrings.tr('खाते क्रमांक (Account No)', 'Account Number'),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _showFullAccount ? currentBank.accountNumber : currentBank.maskedAccountNumber,
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: Icon(
                                    _showFullAccount ? Icons.visibility_off : Icons.visibility,
                                    size: 18,
                                    color: AppColors.primary,
                                  ),
                                  tooltip: _showFullAccount ? 'खाते क्रमांक लपवा' : 'संपूर्ण क्रमांक दाखवा',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => setState(() => _showFullAccount = !_showFullAccount),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.copy, size: 16, color: Colors.grey),
                                  tooltip: 'क्रमांक कॉपी करा',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: currentBank.accountNumber));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('खाते क्रमांक कॉपी केला!')),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 16),
                          _buildDetailRow(
                            AppStrings.tr('खातेदाराचे नाव (Holder)', 'Account Holder'),
                            Text(currentBank.accountHolder, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                          ),
                          const Divider(height: 16),
                          _buildDetailRow(
                            AppStrings.tr('IFSC कोड (IFSC Code)', 'IFSC Code'),
                            Text(currentBank.ifsc, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                          ),
                          const Divider(height: 16),
                          _buildDetailRow(
                            AppStrings.tr('खाते प्रकार (Account Type)', 'Account Type'),
                            Text(
                              currentBank.accountType.toLowerCase() == 'savings'
                                  ? AppStrings.tr('बचत खाते (Savings)', 'Savings')
                                  : AppStrings.tr('चालू खाते (Current)', 'Current'),
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                            ),
                          ),
                          const Divider(height: 16),
                          _buildDetailRow(
                            AppStrings.tr('आरंभीची शिल्लक (Opening Bal)', 'Opening Balance'),
                            Text(
                              '₹ ${currentBank.openingBalance.toStringAsFixed(2)} (${currentBank.openingBalanceDate ?? '-'})',
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                            ),
                          ),
                          if (currentBank.mobileNumber != null && currentBank.mobileNumber!.isNotEmpty) ...[
                            const Divider(height: 16),
                            _buildDetailRow(
                              AppStrings.tr('मोबाईल क्रमांक (Mobile)', 'Mobile'),
                              Text(currentBank.mobileNumber!, style: GoogleFonts.poppins()),
                            ),
                          ],
                          if (currentBank.email != null && currentBank.email!.isNotEmpty) ...[
                            const Divider(height: 16),
                            _buildDetailRow(
                              AppStrings.tr('ईमेल (Email)', 'Email'),
                              Text(currentBank.email!, style: GoogleFonts.poppins()),
                            ),
                          ],
                          if (currentBank.bankAddress != null && currentBank.bankAddress!.isNotEmpty) ...[
                            const Divider(height: 16),
                            _buildDetailRow(
                              AppStrings.tr('पत्ता (Address)', 'Address'),
                              Text(currentBank.bankAddress!, style: GoogleFonts.poppins()),
                            ),
                          ],
                          if (currentBank.notes != null && currentBank.notes!.isNotEmpty) ...[
                            const Divider(height: 16),
                            _buildDetailRow(
                              AppStrings.tr('शेरा (Notes)', 'Notes'),
                              Text(currentBank.notes!, style: GoogleFonts.poppins(fontStyle: FontStyle.italic)),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Recent Transactions Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          AppStrings.tr('अलीकडील व्यवहार (Recent Transactions)', 'Recent Transactions'),
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                        Text(
                          '${_transactions.length} व्यवहार',
                          style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (_isLoadingTx)
                      const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                    else if (_transactions.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.receipt_long_outlined, size: 36, color: Colors.grey),
                            const SizedBox(height: 8),
                            Text(
                              AppStrings.tr('या बँकेसाठी अद्याप कोणतेही व्यवहार नाहीत', 'No transactions recorded yet'),
                              style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _transactions.length > 10 ? 10 : _transactions.length,
                            separatorBuilder: (_, index) => const Divider(height: 1),
                            itemBuilder: (context, idx) {
                              final t = _transactions[idx];
                              final isDep = t.isDeposit;
                              return ListTile(
                                dense: true,
                                leading: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: isDep
                                      ? AppColors.success.withOpacity(0.12)
                                      : AppColors.danger.withOpacity(0.12),
                                  child: Icon(
                                    isDep ? Icons.arrow_downward : Icons.arrow_upward,
                                    size: 16,
                                    color: isDep ? AppColors.success : AppColors.danger,
                                  ),
                                ),
                                title: Text(
                                  t.purpose ?? (isDep ? 'जमा' : 'नावे'),
                                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                                subtitle: Text(
                                  '${t.transactionDate}${t.transactionNumber != null ? " • Ref: ${t.transactionNumber}" : ""}',
                                  style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${isDep ? "+" : "-"} ₹ ${t.amount.toStringAsFixed(2)}',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: isDep ? AppColors.success : AppColors.danger,
                                      ),
                                    ),
                                    if (t.balanceAfter > 0)
                                      Text(
                                        'शिल्लक: ₹${t.balanceAfter.toStringAsFixed(0)}',
                                        style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey.shade600),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Footer Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      final newStatus = currentBank.isActive ? 'inactive' : 'active';
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: Text(AppStrings.tr('स्थिती बदला?', 'Change Status?')),
                          content: Text(
                            currentBank.isActive
                                ? AppStrings.tr('हे बँक खाते निष्क्रिय करायचे आहे का?', 'Deactivate this bank account?')
                                : AppStrings.tr('हे बँक खाते पुन्हा सक्रिय करायचे आहे का?', 'Activate this bank account?'),
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(AppStrings.tr('नाही', 'No'))),
                            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text(AppStrings.tr('होय', 'Yes'))),
                          ],
                        ),
                      );

                      if (confirm == true && auth.currentGroup != null) {
                        await bankProv.toggleBankStatus(currentBank.id, newStatus, auth.currentGroup!.id);
                      }
                    },
                    icon: Icon(
                      currentBank.isActive ? Icons.toggle_off_outlined : Icons.toggle_on_outlined,
                      size: 18,
                    ),
                    label: Text(
                      currentBank.isActive
                          ? AppStrings.tr('निष्क्रिय करा (Deactivate)', 'Deactivate')
                          : AppStrings.tr('सक्रिय करा (Activate)', 'Activate'),
                    ),
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final res = await showDialog(
                        context: context,
                        builder: (_) => AddEditBankDialog(bank: currentBank),
                      );
                      if (res == true) {
                        _loadTransactions();
                      }
                    },
                    icon: const Icon(Icons.edit, size: 16),
                    label: Text(AppStrings.tr('संपादन (Edit)', 'Edit')),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(AppStrings.tr('बंद करा', 'Close')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, Widget valueWidget) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(width: 16),
        Flexible(child: valueWidget),
      ],
    );
  }
}
