import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_strings.dart';
import '../../../models/loan.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/loan_provider.dart';
import '../../../providers/bank_provider.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../widgets/status_badge.dart';
import '../../../services/pdf_service.dart';
import 'collect_emi_dialog.dart';

class LoanDetailsDialog extends StatefulWidget {
  final Loan loan;
  final AuthProvider auth;
  final LoanProvider loanProv;

  const LoanDetailsDialog({
    super.key,
    required this.loan,
    required this.auth,
    required this.loanProv,
  });

  @override
  State<LoanDetailsDialog> createState() => _LoanDetailsDialogState();
}

class _LoanDetailsDialogState extends State<LoanDetailsDialog> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<LoanProvider>().loadEmisForLoan(widget.loan.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LoanProvider>(
      builder: (context, loanProv, _) {
        final loan = loanProv.loans.cast<Loan?>().firstWhere(
          (l) => l?.id == widget.loan.id,
          orElse: () => widget.loan,
        ) ?? widget.loan;
        final emis = loanProv.selectedLoanEmis;
        final isLoading = loanProv.isLoadingEmis;
        final isMobile = MediaQuery.of(context).size.width < 600;

        final progress = loan.approvedAmount > 0 ? (loan.totalRepaid / loan.approvedAmount).clamp(0.0, 1.0) : 0.0;

        return Dialog(
          insetPadding: EdgeInsets.symmetric(
            horizontal: isMobile ? 12 : 40,
            vertical: isMobile ? 16 : 24,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: isMobile ? double.infinity : 620,
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
            padding: EdgeInsets.all(isMobile ? 14 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppColors.primary.withOpacity(0.12),
                        radius: 20,
                        child: const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${loan.memberName ?? "सदस्य"} - कर्ज खातेवही',
                              style: GoogleFonts.poppins(fontSize: isMobile ? 14 : 16, fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'कर्ज क्र: ${loan.loanCode} • दिनांक: ${loan.applicationDate}',
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
                  tooltip: 'प्रिंट व्हाउचर व वेळापत्रक (Print Voucher & Schedule)',
                  icon: const Icon(Icons.print_rounded, color: AppColors.primary),
                  onPressed: () {
                    PdfService.printLoanDisbursementVoucher(
                      loan: loan,
                      groupName: widget.auth.currentGroup?.groupName ?? 'सखी महिला बचत गट',
                      emis: emis,
                    );
                  },
                ),
                IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const Divider(height: 20),

            // Summary Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                children: [
                  if (isMobile) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: _buildSummaryItem('मंजूर रक्कम', '₹ ${loan.approvedAmount.toStringAsFixed(0)}', AppColors.primary)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildSummaryItem('परतफेड रक्कम', '₹ ${loan.totalRepaid.toStringAsFixed(0)}', AppColors.success)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: _buildSummaryItem('शिल्लक मुद्दल', '₹ ${loan.outstandingPrincipal.toStringAsFixed(0)}', loan.outstandingPrincipal > 0 ? AppColors.danger : AppColors.success)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildSummaryItem('मासिक हप्ता', '₹ ${loan.emiAmount.toStringAsFixed(0)}', AppColors.textPrimary)),
                      ],
                    ),
                  ] else ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSummaryItem('मंजूर रक्कम', '₹ ${loan.approvedAmount.toStringAsFixed(0)}', AppColors.primary),
                        _buildSummaryItem('परतफेड रक्कम', '₹ ${loan.totalRepaid.toStringAsFixed(0)}', AppColors.success),
                        _buildSummaryItem('शिल्लक मुद्दल', '₹ ${loan.outstandingPrincipal.toStringAsFixed(0)}', loan.outstandingPrincipal > 0 ? AppColors.danger : AppColors.success),
                        _buildSummaryItem('मासिक हप्ता', '₹ ${loan.emiAmount.toStringAsFixed(0)}', AppColors.textPrimary),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  // Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: Colors.white,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.success),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('परतफेड प्रगती: ${(progress * 100).toStringAsFixed(0)}%', style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textSecondary)),
                      StatusBadge(status: loan.status),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Section Title & Pre-Close Action
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  'हप्ता वेळापत्रक (EMI Schedule)',
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                if (loan.isActive && loan.outstandingPrincipal > 0)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.lock_rounded, size: 14),
                    label: const Text('कर्ज पूर्ण परतफेड', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    onPressed: () => _confirmPreclose(loan),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // EMI Schedule List
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : emis.isEmpty
                      ? Center(
                          child: Text('हप्ता माहिती उपलब्ध नाही', style: GoogleFonts.poppins(color: AppColors.textSecondary)),
                        )
                      : ListView.separated(
                          itemCount: emis.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 6),
                          itemBuilder: (ctx, i) {
                            final emi = emis[i];
                            final isPaid = emi.status == 'paid';

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isPaid ? AppColors.success.withOpacity(0.04) : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isPaid ? AppColors.success.withOpacity(0.3) : AppColors.cardBorder,
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Circle EMI number
                                  Container(
                                    width: 32,
                                    height: 32,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: isPaid ? AppColors.success : AppColors.primary.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '${emi.emiNumber}',
                                      style: TextStyle(
                                        color: isPaid ? Colors.white : AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'तारीख: ${emi.dueDate}',
                                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
                                        ),
                                        Text(
                                          'मुद्दल: ₹${emi.principal.toStringAsFixed(0)} • व्याज: ₹${emi.interest.toStringAsFixed(0)}',
                                          style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '₹ ${emi.emiAmount.toStringAsFixed(0)}',
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: isPaid ? AppColors.success : AppColors.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        isPaid ? 'जमा: ${emi.paymentDate ?? ""}' : 'बाकी (Pending)',
                                        style: GoogleFonts.poppins(
                                          fontSize: 10,
                                          color: isPaid ? AppColors.success : AppColors.danger,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 10),
                                  if (!isPaid)
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        minimumSize: Size.zero,
                                      ),
                                      onPressed: () async {
                                        final res = await showDialog<bool>(
                                          context: context,
                                          builder: (c) => CollectEmiDialog(
                                            loan: loan,
                                            emi: emi,
                                            auth: widget.auth,
                                            loanProv: widget.loanProv,
                                          ),
                                        );
                                        if (res == true && mounted) {
                                          await widget.loanProv.loadEmisForLoan(loan.id);
                                          if (mounted) setState(() {});
                                        }
                                      },
                                      child: const Text('भरा', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                    )
                                  else
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_note_rounded, color: AppColors.primary, size: 20),
                                          tooltip: 'हप्ता दुरुस्त करा (Edit EMI)',
                                          onPressed: () => _showEditEmiDialog(emi, loan),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 20),
                                          tooltip: 'हप्ता डिलीट करा (Delete EMI)',
                                          onPressed: () => _confirmDeleteEmi(emi, loan),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
   },
 );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textSecondary)),
        Text(value, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }

  void _confirmPreclose(Loan currentLoan) {
    final outstanding = currentLoan.outstandingPrincipal;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('कर्ज पूर्ण परतफेड (Pre-Close Loan)'),
        content: Text(
          'शिल्लक मुद्दल रक्कम ₹${outstanding.toStringAsFixed(0)} पूर्ण भरणा करून हे कर्ज खाते बंद करायचे आहे का?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              Navigator.pop(ctx);
              final groupId = widget.auth.currentGroup?.id;
              if (groupId == null) return;

              final today = DateTime.now().toString().split(' ').first;
              final success = await widget.loanProv.precloseLoan(
                groupId: groupId,
                loanId: currentLoan.id,
                loanCode: currentLoan.loanCode,
                borrowerName: currentLoan.memberName ?? 'सदस्य',
                settlementAmount: outstanding,
                paymentMode: 'Cash',
                paymentDate: today,
                collectedBy: widget.auth.currentProfile?.fullName ?? 'Treasurer',
              );

              if (success && mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('कर्ज खाते यशस्वीरीत्या बंद झाले! (Loan Closed Successfully)')),
                );
              }
            },
            child: const Text('होय, खाते बंद करा', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteEmi(LoanEmi emi, Loan currentLoan) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.danger),
            const SizedBox(width: 8),
            Text('हप्ता डिलीट करा?', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
          ],
        ),
        content: Text(
          'हप्ता क्र. ${emi.emiNumber} (रक्कम: ₹${emi.paidAmount.toStringAsFixed(0)}) डिलीट करायचा आहे का?\n\n'
          'टीप: भरलेली मुद्दल (₹${emi.principal.toStringAsFixed(0)}) कर्जाच्या उर्वरित मुद्दलात पूर्ववत जोडली जाईल आणि बँक/कॅश शिल्लक दुरुस्त होईल.',
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('रद्द करा'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              Navigator.pop(ctx);
              final groupId = widget.auth.currentGroup?.id;
              if (groupId == null) return;

              final success = await widget.loanProv.deleteEmi(
                groupId: groupId,
                loanId: currentLoan.id,
                emiId: emi.id,
              );
              if (success && mounted) {
                try {
                  Provider.of<DashboardProvider>(context, listen: false).loadDashboardMetrics(groupId);
                  Provider.of<BankProvider>(context, listen: false).loadBanks(groupId);
                } catch (_) {}
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('हप्ता क्र. ${emi.emiNumber} यशस्वीरीत्या डिलीट झाला!'), backgroundColor: AppColors.success),
                );
                setState(() {});
              }
            },
            child: const Text('डिलीट करा', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showEditEmiDialog(LoanEmi emi, Loan currentLoan) {
    final principalCtrl = TextEditingController(text: emi.principal.toStringAsFixed(0));
    final interestCtrl = TextEditingController(text: emi.interest.toStringAsFixed(0));
    final lateFeeCtrl = TextEditingController(text: emi.lateFee.toStringAsFixed(0));
    final totalPaidCtrl = TextEditingController(text: emi.paidAmount.toStringAsFixed(0));
    final dateCtrl = TextEditingController(text: emi.paymentDate ?? DateTime.now().toString().split(' ').first);
    final remarksCtrl = TextEditingController(text: emi.remarks ?? '');
    String mode = (emi.paymentMode != null && emi.paymentMode!.isNotEmpty) ? emi.paymentMode! : 'cash';

    void recalc() {
      final p = double.tryParse(principalCtrl.text) ?? 0.0;
      final i = double.tryParse(interestCtrl.text) ?? 0.0;
      final lf = double.tryParse(lateFeeCtrl.text) ?? 0.0;
      totalPaidCtrl.text = (p + i + lf).toStringAsFixed(0);
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('हप्ता क्र. ${emi.emiNumber} दुरुस्त करा (Edit EMI)', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: principalCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'मुद्दल (Principal)*', prefixText: '₹ '),
                  onChanged: (_) => setDlgState(() => recalc()),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: interestCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'व्याज (Interest)*', prefixText: '₹ '),
                  onChanged: (_) => setDlgState(() => recalc()),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: lateFeeCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'लेट फी / दंड (Late Fee)', prefixText: '₹ '),
                  onChanged: (_) => setDlgState(() => recalc()),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: totalPaidCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'एकूण भरलेली रक्कम (Total Paid)*', prefixText: '₹ '),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: dateCtrl,
                  decoration: const InputDecoration(labelText: 'भरणा तारीख (Payment Date)*', hintText: 'YYYY-MM-DD'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: remarksCtrl,
                  decoration: const InputDecoration(labelText: 'शेरा (Remarks)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('रद्द करा')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () async {
                final p = double.tryParse(principalCtrl.text) ?? 0.0;
                final i = double.tryParse(interestCtrl.text) ?? 0.0;
                final lf = double.tryParse(lateFeeCtrl.text) ?? 0.0;
                final total = double.tryParse(totalPaidCtrl.text) ?? (p + i + lf);

                Navigator.pop(ctx);
                final groupId = widget.auth.currentGroup?.id;
                if (groupId == null) return;

                final success = await widget.loanProv.updateEmi(
                  groupId: groupId,
                  loanId: currentLoan.id,
                  emiId: emi.id,
                  newPrincipal: p,
                  newInterest: i,
                  newLateFee: lf,
                  newTotalPaid: total,
                  paymentMode: mode,
                  paymentDate: dateCtrl.text.trim(),
                  collectedBy: widget.auth.currentProfile?.fullName ?? 'व्यवस्थापक',
                  remarks: remarksCtrl.text.trim(),
                );

                if (success && mounted) {
                  try {
                    Provider.of<DashboardProvider>(context, listen: false).loadDashboardMetrics(groupId);
                    Provider.of<BankProvider>(context, listen: false).loadBanks(groupId);
                  } catch (_) {}
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('हप्ता क्र. ${emi.emiNumber} दुरुस्त झाला!'), backgroundColor: AppColors.success),
                  );
                  setState(() {});
                }
              },
              child: const Text('अपडेट करा', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
