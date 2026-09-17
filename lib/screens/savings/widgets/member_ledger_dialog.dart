import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/member.dart';
import '../../../models/monthly_saving.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/monthly_savings_provider.dart';

class MemberLedgerDialog extends StatefulWidget {
  final Member member;
  final AuthProvider auth;
  final MonthlySavingsProvider savingsProv;

  const MemberLedgerDialog({
    super.key,
    required this.member,
    required this.auth,
    required this.savingsProv,
  });

  @override
  State<MemberLedgerDialog> createState() => _MemberLedgerDialogState();
}

class _MemberLedgerDialogState extends State<MemberLedgerDialog> {
  int _selectedYear = DateTime.now().year;
  bool _isLoading = true;
  List<MonthlySaving> _ledger = [];

  @override
  void initState() {
    super.initState();
    _loadLedger();
  }

  Future<void> _loadLedger() async {
    setState(() => _isLoading = true);
    if (widget.auth.currentGroup != null) {
      final res = await widget.savingsProv.loadMemberYearLedger(
        groupId: widget.auth.currentGroup!.id,
        memberId: widget.member.id,
        year: _selectedYear,
        member: widget.member,
      );
      if (mounted) {
        setState(() {
          _ledger = res;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.member;
    final totalExpected = _ledger.fold(0.0, (s, l) => s + l.expectedAmount);
    final totalPaid = _ledger.fold(0.0, (s, l) => s + l.paidAmount);
    final totalPending = (totalExpected - totalPaid) > 0 ? (totalExpected - totalPaid) : 0.0;
    final isMobile = MediaQuery.of(context).size.width < 600;
    final maxYear = math.max(DateTime.now().year + 2, widget.auth.globalEndDate.year + 1);
    final yearsList = {for (int y = 2020; y <= maxYear; y++) y, _selectedYear}.toList()..sort();

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
                        radius: 20,
                        backgroundColor: AppColors.primary.withOpacity(0.12),
                        child: Text(
                          m.fullName.isNotEmpty ? m.fullName[0] : 'S',
                          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primary),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m.fullName,
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: isMobile ? 14 : 16),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'सदस्य क्र: ${m.memberCode} • मो: ${m.mobileNumber}',
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

            // Year Selector
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'वार्षिक बचत खातेवही (Annual Savings)',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _selectedYear,
                      isDense: true,
                      items: yearsList.map((y) {
                        return DropdownMenuItem(value: y, child: Text('$y'));
                      }).toList(),
                      onChanged: (y) {
                        if (y != null) {
                          setState(() => _selectedYear = y);
                          _loadLedger();
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 12-Month Ledger List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : ListView.separated(
                      itemCount: _ledger.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 6),
                      itemBuilder: (ctx, i) {
                        final item = _ledger[i];
                        final isPaid = item.isPaid;
                        final isPartial = item.isPartial;

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isPaid
                                ? AppColors.success.withOpacity(0.04)
                                : (isPartial ? AppColors.warning.withOpacity(0.04) : Colors.white),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isPaid
                                  ? AppColors.success.withOpacity(0.3)
                                  : (isPartial ? AppColors.warning.withOpacity(0.3) : AppColors.cardBorder),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: isPaid
                                          ? AppColors.success.withOpacity(0.12)
                                          : (isPartial ? AppColors.warning.withOpacity(0.12) : AppColors.danger.withOpacity(0.1)),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${item.month}',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                        color: isPaid ? AppColors.success : (isPartial ? AppColors.warning : AppColors.danger),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${item.monthNameMr} (${item.monthNameEn})',
                                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
                                      ),
                                      if (item.paymentDate != null)
                                        Text(
                                          'भरणा: ${item.paymentDate} • ${item.receiptNumber ?? ""}',
                                          style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textSecondary),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Text(
                                    '₹ ${item.paidAmount.toStringAsFixed(0)}',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: isPaid ? AppColors.success : AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isPaid
                                          ? AppColors.success.withOpacity(0.12)
                                          : (isPartial ? AppColors.warning.withOpacity(0.12) : AppColors.danger.withOpacity(0.12)),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      isPaid ? '✅ Paid' : (isPartial ? '🟠 Partial' : '🔴 Pending'),
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: isPaid ? AppColors.success : (isPartial ? AppColors.warning : AppColors.danger),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),

            // Bottom Totals Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text('Total Expected', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary)),
                      Text('₹ ${totalExpected.toStringAsFixed(0)}', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    ],
                  ),
                  Container(width: 1, height: 28, color: AppColors.divider),
                  Column(
                    children: [
                      Text('Total Paid', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary)),
                      Text('₹ ${totalPaid.toStringAsFixed(0)}', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.success)),
                    ],
                  ),
                  Container(width: 1, height: 28, color: AppColors.divider),
                  Column(
                    children: [
                      Text('Pending (बाकी)', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary)),
                      Text('₹ ${totalPending.toStringAsFixed(0)}', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: totalPending > 0 ? AppColors.danger : AppColors.success)),
                    ],
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
