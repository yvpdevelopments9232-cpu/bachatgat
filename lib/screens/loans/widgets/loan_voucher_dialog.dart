import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/loan.dart';
import '../../../services/pdf_service.dart';
import '../../../services/loan_service.dart';

class LoanVoucherDialog extends StatefulWidget {
  final Loan loan;
  final String groupName;
  final String? guarantor1Name;
  final String? guarantor2Name;
  final List<LoanEmi>? emis;

  const LoanVoucherDialog({
    super.key,
    required this.loan,
    required this.groupName,
    this.guarantor1Name,
    this.guarantor2Name,
    this.emis,
  });

  @override
  State<LoanVoucherDialog> createState() => _LoanVoucherDialogState();
}

class _LoanVoucherDialogState extends State<LoanVoucherDialog> {
  final GlobalKey _voucherKey = GlobalKey();
  bool _isPrinting = false;
  List<LoanEmi> _emis = [];
  bool _isLoadingEmis = true;

  @override
  void initState() {
    super.initState();
    _loadEmis();
  }

  Future<void> _loadEmis() async {
    if (widget.emis != null && widget.emis!.isNotEmpty) {
      if (mounted) {
        setState(() {
          _emis = widget.emis!;
          _isLoadingEmis = false;
        });
      }
      return;
    }
    try {
      final list = await LoanService().fetchEmisForLoan(widget.loan.id, widget.loan);
      if (mounted) {
        setState(() {
          _emis = list;
          _isLoadingEmis = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading EMIs in LoanVoucherDialog: $e');
      if (mounted) setState(() => _isLoadingEmis = false);
    }
  }

  Future<void> _handlePrint() async {
    setState(() => _isPrinting = true);
    Uint8List? imageBytes;
    try {
      final boundary = _voucherKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary != null) {
        final image = await boundary.toImage(pixelRatio: 3.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        imageBytes = byteData?.buffer.asUint8List();
      }
    } catch (e) {
      debugPrint('Error capturing voucher image: $e');
    }

    if (mounted) setState(() => _isPrinting = false);

    await PdfService.printLoanDisbursementVoucher(
      loan: widget.loan,
      groupName: widget.groupName,
      guarantor1: widget.guarantor1Name,
      guarantor2: widget.guarantor2Name,
      voucherImageBytes: imageBytes,
      emis: _emis,
    );
  }

  @override
  Widget build(BuildContext context) {
    final loan = widget.loan;
    final groupName = widget.groupName;
    final guarantor1Name = widget.guarantor1Name;
    final guarantor2Name = widget.guarantor2Name;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24, vertical: isMobile ? 14 : 24),
      child: Center(
        child: Container(
          width: isMobile ? double.infinity : 480,
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.94),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.verified_rounded, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'कर्ज वाटप पावती (Loan Voucher)',
                              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Tooltip(
                      message: 'बंद करा (Close)',
                      child: Material(
                        color: Colors.white.withOpacity(0.25),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => Navigator.of(context).pop(),
                          child: const Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(Icons.close_rounded, color: Colors.white, size: 22),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Slip Body & Schedule
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      RepaintBoundary(
                        key: _voucherKey,
                        child: Container(
                          color: Colors.white,
                          padding: EdgeInsets.all(isMobile ? 14 : 20),
                          child: Column(
                            children: [
                              Text(
                                groupName.toUpperCase(),
                                style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.primary),
                                textAlign: TextAlign.center,
                              ),
                              Text(
                                'अंतर्गत कर्ज वाटप व्हाउचर (Internal Loan Sanction Slip)',
                                style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 10),
                              const Divider(color: AppColors.cardBorder, thickness: 1.5),

                              // Voucher & Date
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('कर्ज क्र (Loan Code):', style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
                                    Text(loan.loanCode, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('वाटप दिनांक (Date):', style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
                                    Text(loan.applicationDate, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Borrower Box
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.cardBorder),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('कर्जदार सभासद:', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary)),
                                        Text(loan.memberName ?? 'सदस्य', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14)),
                                      ],
                                    ),
                                    if (loan.purpose != null && loan.purpose!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text('हेतू: ${loan.purpose}', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary)),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Breakdown Table
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.04),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                                ),
                                child: Column(
                                  children: [
                                    _buildRow('मंजूर कर्ज रक्कम (Sanctioned):', '₹ ${loan.approvedAmount.toStringAsFixed(0)}', isBold: true),
                                    const SizedBox(height: 6),
                                    _buildRow('व्याज दर (Interest Rate):', '${loan.interestRate.toStringAsFixed(1)}% p.a. (${(loan.interestRate / 12).toStringAsFixed(1)}% दरमहा)'),
                                    const SizedBox(height: 6),
                                    _buildRow('परतफेड मुदत (Period):', '${loan.loanPeriodMonths} महिने'),
                                    const SizedBox(height: 6),
                                    _buildRow('मासिक हप्ता (Monthly EMI):', '₹ ${loan.emiAmount.toStringAsFixed(0)} / महिना', isPrimary: true),
                                    const SizedBox(height: 6),
                                    _buildRow('पहिला हप्ता तारीख (First EMI):', loan.firstEmiDate),
                                    if (loan.calculatedEndDate.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      _buildRow('कर्ज समाप्ती तारीख (Ending Date):', loan.calculatedEndDate),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Guarantors
                              if (guarantor1Name != null || guarantor2Name != null)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Text(
                                    'जामीनदार: ${guarantor1Name ?? ""}${guarantor2Name != null ? ", $guarantor2Name" : ""}',
                                    style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
                                  ),
                                ),
                              const SizedBox(height: 14),

                              // Signatures
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    children: [
                                      const SizedBox(height: 25),
                                      Container(width: 80, height: 1, color: AppColors.divider),
                                      const SizedBox(height: 4),
                                      Text('कर्जदार स्वाक्षरी', style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textSecondary)),
                                    ],
                                  ),
                                  Column(
                                    children: [
                                      const SizedBox(height: 25),
                                      Container(width: 80, height: 1, color: AppColors.divider),
                                      const SizedBox(height: 4),
                                      Text('जामीनदार स्वाक्षरी', style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textSecondary)),
                                    ],
                                  ),
                                  Column(
                                    children: [
                                      const SizedBox(height: 25),
                                      Container(width: 90, height: 1, color: AppColors.divider),
                                      const SizedBox(height: 4),
                                      Text('अध्यक्ष / सचिव', style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textSecondary)),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      // EMI Schedule Section below Sanction Slip
                      Container(
                        margin: EdgeInsets.fromLTRB(isMobile ? 10 : 16, 0, isMobile ? 10 : 16, 14),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_month_rounded, size: 16, color: AppColors.primary),
                                    const SizedBox(width: 6),
                                    Text(
                                      'हप्ता परतफेड वेळापत्रक (EMI Schedule)',
                                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    loan.isDecreasingEmi ? 'घटता हप्ता (Decreasing)' : 'स्थिर हप्ता (Fixed)',
                                    style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primary),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (_isLoadingEmis)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(12),
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                ),
                              )
                            else if (_emis.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text('वेळापत्रक माहिती उपलब्ध नाही.', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary)),
                              )
                            else ...[
                              Table(
                                border: TableBorder.all(color: AppColors.cardBorder, width: 0.5),
                                columnWidths: const {
                                  0: FlexColumnWidth(0.7),
                                  1: FlexColumnWidth(1.3),
                                  2: FlexColumnWidth(1.0),
                                  3: FlexColumnWidth(1.0),
                                  4: FlexColumnWidth(1.1),
                                },
                                children: [
                                  TableRow(
                                    decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.08)),
                                    children: [
                                      Padding(padding: const EdgeInsets.all(4), child: Text('हप्ता', textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700))),
                                      Padding(padding: const EdgeInsets.all(4), child: Text('तारीख', textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700))),
                                      Padding(padding: const EdgeInsets.all(4), child: Text('मुद्दल', textAlign: TextAlign.right, style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700))),
                                      Padding(padding: const EdgeInsets.all(4), child: Text('व्याज', textAlign: TextAlign.right, style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700))),
                                      Padding(padding: const EdgeInsets.all(4), child: Text('एकूण', textAlign: TextAlign.right, style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary))),
                                    ],
                                  ),
                                  ..._emis.map((e) => TableRow(
                                    decoration: BoxDecoration(color: e.status == 'paid' ? AppColors.success.withOpacity(0.05) : Colors.white),
                                    children: [
                                      Padding(padding: const EdgeInsets.all(4), child: Text('${e.emiNumber}', textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 10))),
                                      Padding(padding: const EdgeInsets.all(4), child: Text(e.dueDate, textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 10))),
                                      Padding(padding: const EdgeInsets.all(4), child: Text('₹${e.principal.toStringAsFixed(0)}', textAlign: TextAlign.right, style: GoogleFonts.poppins(fontSize: 10))),
                                      Padding(padding: const EdgeInsets.all(4), child: Text('₹${e.interest.toStringAsFixed(0)}', textAlign: TextAlign.right, style: GoogleFonts.poppins(fontSize: 10))),
                                      Padding(padding: const EdgeInsets.all(4), child: Text('₹${e.emiAmount.toStringAsFixed(0)}', textAlign: TextAlign.right, style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: e.status == 'paid' ? AppColors.success : AppColors.textPrimary))),
                                    ],
                                  )),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.info_outline_rounded, size: 12, color: AppColors.textSecondary),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'प्रिंट केल्यावर ही पावती व संपूर्ण वेळापत्रक २ पृष्ठांच्या अधिकृत PDF मध्ये छापले जाईल.',
                                      style: GoogleFonts.poppins(fontSize: 9.5, fontStyle: FontStyle.italic, color: AppColors.textSecondary),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Actions
              Container(
                padding: const EdgeInsets.all(14),
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        icon: _isPrinting
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.print_rounded, size: 18, color: Colors.white),
                        label: const Text('प्रिंट (Print)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        onPressed: _isPrinting ? null : _handlePrint,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
                        icon: const Icon(Icons.share_rounded, size: 18),
                        label: const Text('Share SMS', style: TextStyle(fontWeight: FontWeight.w600)),
                        onPressed: () {
                          final text = '''
*${groupName.toUpperCase()}*
*कर्ज वाटप पावती (Loan Voucher)*
────────────────
कर्ज कोड: ${loan.loanCode}
कर्जदार: ${loan.memberName}
रक्कम: ₹${loan.approvedAmount.toStringAsFixed(0)}
मुदत: ${loan.loanPeriodMonths} महिने
मासिक हप्ता: ₹${loan.emiAmount.toStringAsFixed(0)}
पहिले हप्ता तारीख: ${loan.firstEmiDate}
धन्यवाद!
────────────────''';
                          Clipboard.setData(ClipboardData(text: text));
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('कर्ज माहिती क्लिपबोर्डवर कॉपी झाली!')));
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          side: const BorderSide(color: AppColors.cardBorder),
                        ),
                        icon: const Icon(Icons.close_rounded, size: 16),
                        label: const Text('बंद करा (Close)', style: TextStyle(fontWeight: FontWeight.w600)),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, {bool isBold = false, bool isPrimary = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: isBold || isPrimary ? FontWeight.w700 : FontWeight.w500,
            color: isPrimary ? AppColors.primary : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
