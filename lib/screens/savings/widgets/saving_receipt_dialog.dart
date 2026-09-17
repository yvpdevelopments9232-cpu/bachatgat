import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/monthly_saving.dart';
import '../../../services/pdf_service.dart';

class SavingReceiptDialog extends StatefulWidget {
  final MonthlySaving saving;
  final String groupName;

  const SavingReceiptDialog({
    super.key,
    required this.saving,
    required this.groupName,
  });

  @override
  State<SavingReceiptDialog> createState() => _SavingReceiptDialogState();
}

class _SavingReceiptDialogState extends State<SavingReceiptDialog> {
  final GlobalKey _receiptKey = GlobalKey();
  bool _isPrinting = false;

  Future<void> _handlePrintOrPdf() async {
    setState(() => _isPrinting = true);
    Uint8List? imageBytes;
    try {
      final boundary = _receiptKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary != null) {
        final image = await boundary.toImage(pixelRatio: 3.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        imageBytes = byteData?.buffer.asUint8List();
      }
    } catch (e) {
      debugPrint('Error capturing receipt image: $e');
    }

    if (mounted) setState(() => _isPrinting = false);

    await PdfService.printMonthlySavingReceipt(
      saving: widget.saving,
      groupName: widget.groupName,
      receiptImageBytes: imageBytes,
    );
  }

  @override
  Widget build(BuildContext context) {
    final saving = widget.saving;
    final groupName = widget.groupName;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24, vertical: isMobile ? 14 : 24),
      child: Center(
        child: Container(
          width: isMobile ? double.infinity : 440,
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
              // Top Action Bar
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
                          const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'पावती तयार झाली (Receipt Generated)',
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

              // Receipt Slip Body
              Flexible(
                child: SingleChildScrollView(
                  child: RepaintBoundary(
                    key: _receiptKey,
                    child: Container(
                      color: Colors.white,
                      padding: EdgeInsets.all(isMobile ? 16 : 24),
                  child: Column(
                  children: [
                    // Header
                    Text(
                      groupName.toUpperCase(),
                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primary),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      'Monthly Saving Receipt (मासिक बचत पावती)',
                      style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: AppColors.cardBorder, thickness: 1.5),

                    // Receipt No & Date
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Receipt No:', style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
                          Text(saving.receiptNumber ?? 'SAV-2026-000125', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Date:', style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
                          Text(saving.paymentDate ?? DateTime.now().toString().split(' ').first, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Member Information Box
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Member:', style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textSecondary)),
                          Text(saving.memberName ?? 'Sunita Pawar', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14)),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Member ID:', style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textSecondary)),
                                  Text(saving.memberCode ?? 'MB-0001', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12)),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('Month:', style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textSecondary)),
                                  Text('${saving.monthNameEn} ${saving.year}', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.primary)),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Financials
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Monthly Saving:', style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary)),
                        Text('₹ ${saving.expectedAmount.toStringAsFixed(0)}', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    if (saving.lateFee > 0) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Late Fee (विलंब शुल्क):', style: GoogleFonts.poppins(fontSize: 13, color: AppColors.danger)),
                          Text('₹ ${saving.lateFee.toStringAsFixed(0)}', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.danger)),
                        ],
                      ),
                    ],
                    const Divider(color: AppColors.cardBorder, height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Paid (एकूण भरणा):', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700)),
                        Text('₹ ${saving.paidAmount.toStringAsFixed(0)}', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.success)),
                      ],
                    ),
                    const SizedBox(height: 10),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Payment Mode: ${saving.paymentMode.toUpperCase()}', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary)),
                        Text('Collected By: ${saving.collectedBy ?? "Treasurer"}', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary)),
                      ],
                    ),
                    const SizedBox(height: 14),

                    Text(
                      'Thank You (धन्यवाद)',
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

              // Action Buttons: Print | PDF | Share
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                        label: const Text('Print', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        onPressed: _isPrinting ? null : _handlePrintOrPdf,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        icon: _isPrinting
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.picture_as_pdf_rounded, size: 18, color: Colors.white),
                        label: const Text('PDF', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        onPressed: _isPrinting ? null : _handlePrintOrPdf,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        icon: const Icon(Icons.share_rounded, size: 18),
                        label: const Text('Share', style: TextStyle(fontWeight: FontWeight.w600)),
                        onPressed: () {
                          final text = '''
*${groupName.toUpperCase()}*
*Monthly Saving Receipt*
────────────────
Receipt: ${saving.receiptNumber}
Date: ${saving.paymentDate}
Member: ${saving.memberName} (${saving.memberCode})
Month: ${saving.monthNameEn} ${saving.year}
Amount Paid: ₹${saving.paidAmount.toStringAsFixed(0)}
Mode: ${saving.paymentMode.toUpperCase()}
Status: ✅ Paid
Thank you!
────────────────''';
                          Clipboard.setData(ClipboardData(text: text));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('पावती माहिती क्लिपबोर्डवर कॉपी झाली! (Receipt copied!)')),
                          );
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
                        label: const Text('बंद करा', style: TextStyle(fontWeight: FontWeight.w600)),
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
}
