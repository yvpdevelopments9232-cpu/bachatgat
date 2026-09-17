import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf_text_shaper/pdf_text_shaper.dart';
import 'package:printing/printing.dart';
import '../models/saving.dart';
import '../models/monthly_saving.dart';
import '../models/loan.dart';
import '../models/bonus.dart';
import 'loan_service.dart';

class PdfService {
  // Helper to load Devanagari font for Marathi text (100% offline with bundled assets, fallback to GoogleFonts)
  static Future<pw.ThemeData> getDevanagariTheme() async {
    try {
      final fontData = await rootBundle.load('assets/fonts/NotoSansDevanagari-Regular.ttf');
      final boldData = await rootBundle.load('assets/fonts/NotoSansDevanagari-Bold.ttf');
      final robotoData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      final font = pw.Font.ttf(fontData);
      final boldFont = pw.Font.ttf(boldData);
      final robotoFont = pw.Font.ttf(robotoData);
      return pw.ThemeData.withFont(
        base: font,
        bold: boldFont,
        fontFallback: [robotoFont],
      );
    } catch (assetErr) {
      debugPrint('Local font asset load note: $assetErr. Trying PdfGoogleFonts...');
      try {
        final font = await PdfGoogleFonts.notoSansDevanagariRegular();
        final boldFont = await PdfGoogleFonts.notoSansDevanagariBold();
        return pw.ThemeData.withFont(base: font, bold: boldFont);
      } catch (e) {
        debugPrint('PdfGoogleFonts fallback note: $e');
        return pw.ThemeData.base();
      }
    }
  }

  static Future<pw.ThemeData> _getTheme() => getDevanagariTheme();

  // 1. MONTHLY SAVING OFFICIAL SLIP
  static Future<void> printMonthlySavingReceipt({
    required MonthlySaving saving,
    required String groupName,
    Uint8List? receiptImageBytes,
  }) async {
    final doc = pw.Document();

    if (receiptImageBytes != null) {
      final image = pw.MemoryImage(receiptImageBytes);
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a5,
          margin: const pw.EdgeInsets.all(12),
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Image(image, fit: pw.BoxFit.contain),
            );
          },
        ),
      );
    } else {
      final theme = await _getTheme();

      doc.addPage(
        pw.Page(
          theme: theme,
          pageFormat: PdfPageFormat.a5,
          build: (pw.Context context) {
            return pw.Container(
              padding: const pw.EdgeInsets.all(24),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.purple900, width: 2),
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text(
                    groupName.toUpperCase(),
                    style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold, color: PdfColors.purple900),
                  ),
                ),
                pw.Center(
                  child: pw.Text(
                    'मासिक बचत पावती (Monthly Saving Receipt)',
                    style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey800),
                  ),
                ),
                pw.Divider(color: PdfColors.purple800, thickness: 1.5),
                pw.SizedBox(height: 8),

                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('पावती क्र: ${saving.receiptNumber ?? "SAV-001"}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text('तारीख: ${saving.paymentDate ?? DateTime.now().toString().split(' ').first}'),
                  ],
                ),
                pw.SizedBox(height: 10),

                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('सभासद: ${saving.memberName ?? "सभासद"}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
                          pw.Text('आयडी: ${saving.memberCode ?? "-"}', style: const pw.TextStyle(fontSize: 11)),
                        ],
                      ),
                      if (saving.mobileNumber != null && saving.mobileNumber!.isNotEmpty)
                        pw.Text('मोबाईल: ${saving.mobileNumber}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      pw.Text('महिना: ${saving.monthNameMr} ${saving.year} (${saving.monthNameEn})', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.purple900)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 12),

                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.purple50),
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('तपशील (Particulars)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('रक्कम (Amount)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('नियमित मासिक बचत (${saving.monthNameMr} ${saving.year})')),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Rs. ${saving.expectedAmount.toStringAsFixed(2)}', textAlign: pw.TextAlign.right)),
                      ],
                    ),
                    if (saving.lateFee > 0)
                      pw.TableRow(
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('विलंब शुल्क (Late Fee)')),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Rs. ${saving.lateFee.toStringAsFixed(2)}', textAlign: pw.TextAlign.right)),
                        ],
                      ),
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.purple100),
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('एकूण भरणा (Total Paid)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Rs. ${saving.paidAmount.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.purple900), textAlign: pw.TextAlign.right)),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 10),

                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('भरणा प्रकार: ${saving.paymentMode.toUpperCase()}'),
                    if (saving.transactionId != null && saving.transactionId!.isNotEmpty)
                      pw.Text('Txn ID: ${saving.transactionId}'),
                  ],
                ),
                pw.Text('संकलक: ${saving.collectedBy ?? "व्यवस्थापक"}'),
                if (saving.remarks != null && saving.remarks!.isNotEmpty)
                  pw.Text('शेरा: ${saving.remarks}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),

                pw.Spacer(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      children: [
                        pw.SizedBox(height: 25),
                        pw.Text('सभासद स्वाक्षरी'),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.SizedBox(height: 25),
                        pw.Text('अध्यक्ष / सचिव स्वाक्षरी'),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 10),
                pw.Center(
                  child: pw.Text('धन्यवाद! (Thank You!)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.purple900)),
                ),
              ],
            ),
          );
        },
      ),
    );
    }

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'receipt_${saving.receiptNumber ?? "SAV"}.pdf',
    );
  }

  // 2. LOAN DISBURSEMENT VOUCHER & SANCTION AGREEMENT (WITH COMPLETE EMI SCHEDULE)
  static Future<void> printLoanDisbursementVoucher({
    required Loan loan,
    required String groupName,
    String? guarantor1,
    String? guarantor2,
    Uint8List? voucherImageBytes,
    List<LoanEmi>? emis,
  }) async {
    final doc = pw.Document();

    // 1. PAGE 1: LOAN DISBURSEMENT VOUCHER / SANCTION SLIP
    if (voucherImageBytes != null) {
      final image = pw.MemoryImage(voucherImageBytes);
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(16),
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Image(image, fit: pw.BoxFit.contain),
            );
          },
        ),
      );
    } else {
      final theme = await _getTheme();

      doc.addPage(
        pw.Page(
          theme: theme,
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Container(
              padding: const pw.EdgeInsets.all(28),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.purple900, width: 2),
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text(
                    groupName.toUpperCase(),
                    style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.purple900),
                  ),
                ),
                pw.Center(
                  child: pw.Text(
                    'अंतर्गत कर्ज वाटप व्हाउचर व करारनामा (Loan Sanction Voucher)',
                    style: const pw.TextStyle(fontSize: 13, color: PdfColors.grey800),
                  ),
                ),
                pw.Divider(color: PdfColors.purple800, thickness: 1.5),
                pw.SizedBox(height: 12),

                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('कर्ज क्र (Loan Code): ${loan.loanCode}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
                    pw.Text('वाटप दिनांक: ${loan.applicationDate}'),
                  ],
                ),
                pw.SizedBox(height: 12),

                // Borrower Info Box
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('कर्जदार सभासद: ${loan.memberName ?? "सभासद"}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                      if (loan.purpose != null)
                        pw.Text('कर्जाचा हेतू: ${loan.purpose}', style: const pw.TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 14),

                // Loan Terms Table
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.purple50),
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('कर्ज अटी व शर्ती (Loan Terms)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('तपशील (Details)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('मंजूर कर्ज रक्कम (Sanctioned Amount)')),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Rs. ${loan.approvedAmount.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.purple900))),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('व्याज दर (Interest Rate)')),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${loan.interestRate.toStringAsFixed(1)}% p.a. (${(loan.interestRate / 12).toStringAsFixed(1)}% दरमहा)')),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('परतफेड मुदत (Repayment Period)')),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${loan.loanPeriodMonths} महिने (${loan.numberOfEmis} हप्ते)')),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('मासिक हप्ता (Monthly EMI)')),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Rs. ${loan.emiAmount.toStringAsFixed(2)} / दरमहा', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('पहिला हप्ता तारीख (First EMI Date)')),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(loan.firstEmiDate)),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 14),

                if (guarantor1 != null || guarantor2 != null)
                  pw.Text(
                    'जामीनदार: ${guarantor1 ?? ""}${guarantor2 != null ? ", $guarantor2" : ""}',
                    style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey800),
                  ),

                pw.SizedBox(height: 14),
                pw.Text(
                  'हमीपत्र / करार: मी घेतलेले वरील कर्ज बचत गटाच्या नियमावलीनुसार दरमहा नियत तारखेला सव्याज नियमित भरण्यास बांधील आहे. मुदतीत कर्जफेड न केल्यास बचत गटाचे निर्णय मजवर बंधनकारक राहतील.',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
                ),

                pw.Spacer(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      children: [
                        pw.SizedBox(height: 35),
                        pw.Text('कर्जदार स्वाक्षरी\n(Borrower)'),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.SizedBox(height: 35),
                        pw.Text('जामीनदार स्वाक्षरी\n(Guarantor)'),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.SizedBox(height: 35),
                        pw.Text('अध्यक्ष / सचिव स्वाक्षरी\n(Authorized Sign)'),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 12),
                pw.Center(
                  child: pw.Text('सखी महिला बचत गट - स्वावलंबन आणि सक्षमीकरण', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                ),
              ],
            ),
          );
        },
      ),
    );
    }

    // 2. PAGE 2+: LOAN EMI REPAYMENT SCHEDULE TABLE
    List<LoanEmi> effectiveEmis = emis ?? [];
    if (effectiveEmis.isEmpty) {
      try {
        effectiveEmis = await LoanService().fetchEmisForLoan(loan.id, loan);
      } catch (e) {
        debugPrint('Loan schedule load in PdfService: $e');
      }
    }

    if (effectiveEmis.isNotEmpty) {
      // Calculate totals
      double totalPrincipal = 0.0;
      double totalInterest = 0.0;
      double totalEmi = 0.0;

      for (var e in effectiveEmis) {
        totalPrincipal += e.principal;
        totalInterest += e.interest;
        totalEmi += e.emiAmount;
      }

      // Try HarfBuzz shaped fonts for Devanagari text
      ShapedFont? devFont;
      ShapedFont? devBoldFont;
      ShapedFont? robotoFont;
      List<ShapedFont> allShapedFonts = [];
      try {
        final devReg = await rootBundle.load('assets/fonts/NotoSansDevanagari-Regular.ttf');
        final devBold = await rootBundle.load('assets/fonts/NotoSansDevanagari-Bold.ttf');
        final roboto = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
        devFont = ShapedFont.fromBytes(devReg.buffer.asUint8List(), name: 'NotoSansDevanagari-Regular');
        devBoldFont = ShapedFont.fromBytes(devBold.buffer.asUint8List(), name: 'NotoSansDevanagari-Bold');
        robotoFont = ShapedFont.fromBytes(roboto.buffer.asUint8List(), name: 'Roboto-Regular');
        allShapedFonts = [devFont, devBoldFont, robotoFont];
      } catch (e) {
        debugPrint('ShapedFont load in PdfService: $e');
      }

      final scheduleTheme = await _getTheme();

      String cleanTxt(String? s) {
        if (s == null || s.isEmpty) return '';
        if (allShapedFonts.isEmpty) return s;
        final buffer = StringBuffer();
        for (final rune in s.runes) {
          if (rune == 0x09 || rune == 0x0A || rune == 0x0D || rune == 0x20 || rune == 0x00A0) {
            buffer.writeCharCode(rune);
            continue;
          }
          bool supported = false;
          for (final font in allShapedFonts) {
            if (font.supportsRune(rune)) {
              supported = true;
              break;
            }
          }
          if (supported) buffer.writeCharCode(rune);
        }
        return buffer.toString();
      }

      pw.Widget makeCellText(
        String text, {
        bool isBold = false,
        PdfColor? color,
        double fontSize = 8.0,
        ShapedTextAlign align = ShapedTextAlign.start,
        pw.TextAlign pwAlign = pw.TextAlign.left,
      }) {
        if (devFont != null && devBoldFont != null && robotoFont != null) {
          final style = ShapedTextStyle(
            font: isBold ? devBoldFont : devFont,
            fallbackFonts: [robotoFont],
            fontSize: fontSize,
            color: color ?? PdfColors.black,
            align: align,
          );
          return ShapedText(cleanTxt(text), style: style);
        } else {
          return pw.Text(
            text,
            textAlign: pwAlign,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: color ?? PdfColors.black,
            ),
          );
        }
      }

      doc.addPage(
        pw.MultiPage(
          theme: scheduleTheme,
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          header: (pw.Context context) {
            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 10),
              padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#4A148C'),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      makeCellText(
                        groupName.toUpperCase(),
                        isBold: true,
                        fontSize: 14,
                        color: PdfColors.white,
                      ),
                      makeCellText(
                        'हप्ता परतफेड वेळापत्रक (Loan EMI Repayment Schedule)',
                        fontSize: 9,
                        color: PdfColors.grey200,
                      ),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#6A1B9A'),
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: makeCellText(
                      loan.isDecreasingEmi ? 'घटता हप्ता (Decreasing)' : 'स्थिर हप्ता (Fixed)',
                      isBold: true,
                      fontSize: 8.5,
                      color: PdfColors.white,
                      align: ShapedTextAlign.center,
                    ),
                  ),
                ],
              ),
            );
          },
          footer: (pw.Context context) {
            return pw.Container(
              margin: const pw.EdgeInsets.only(top: 8),
              padding: const pw.EdgeInsets.only(top: 4),
              decoration: const pw.BoxDecoration(
                border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  makeCellText(
                    'सखी महिला बचत गट • अधिकृत कर्ज हप्ता वेळापत्रक',
                    fontSize: 7.5,
                    color: PdfColors.grey600,
                  ),
                  makeCellText(
                    'पृष्ठ ${context.pageNumber} / ${context.pagesCount}',
                    isBold: true,
                    fontSize: 7.5,
                    color: PdfColors.grey700,
                  ),
                ],
              ),
            );
          },
          build: (pw.Context context) {
            return [
              // Loan Metadata Bar
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 10),
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F3E8FF'),
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: PdfColor.fromHex('#D8B4FE'), width: 0.8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          makeCellText('कर्जदार: ${loan.memberName ?? "सदस्य"}', isBold: true, fontSize: 9.5),
                          pw.SizedBox(height: 2),
                          makeCellText('कर्ज क्र.: ${loan.loanCode}', fontSize: 8.5, color: PdfColors.grey800),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          makeCellText('मंजूर रक्कम: Rs. ${loan.approvedAmount.toStringAsFixed(0)}', isBold: true, fontSize: 9.5, color: PdfColor.fromHex('#4A148C')),
                          pw.SizedBox(height: 2),
                          makeCellText('व्याज दर: ${loan.interestRate.toStringAsFixed(1)}% p.a. (${(loan.interestRate / 12).toStringAsFixed(1)}% दरमहा)', fontSize: 8.5, color: PdfColors.grey800),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          makeCellText('मुदत: ${loan.loanPeriodMonths} महिने (${effectiveEmis.length} हप्ते)', isBold: true, fontSize: 9.5),
                          pw.SizedBox(height: 2),
                          makeCellText('पहिले हप्ता: ${loan.firstEmiDate}', fontSize: 8.5, color: PdfColors.grey800),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // EMI Schedule Table
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                columnWidths: const {
                  0: pw.FlexColumnWidth(0.7),  // हप्ता क्र.
                  1: pw.FlexColumnWidth(1.2),  // देय तारीख
                  2: pw.FlexColumnWidth(1.1),  // मुद्दल
                  3: pw.FlexColumnWidth(1.0),  // व्याज
                  4: pw.FlexColumnWidth(1.2),  // एकूण हप्ता
                  5: pw.FlexColumnWidth(1.3),  // उर्वरित मुद्दल
                  6: pw.FlexColumnWidth(1.0),  // स्थिती
                },
                children: [
                  // Table Header
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColor.fromHex('#4A148C')),
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                        alignment: pw.Alignment.center,
                        child: makeCellText('हप्ता', isBold: true, fontSize: 8, color: PdfColors.white, align: ShapedTextAlign.center),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                        alignment: pw.Alignment.center,
                        child: makeCellText('देय तारीख', isBold: true, fontSize: 8, color: PdfColors.white, align: ShapedTextAlign.center),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                        alignment: pw.Alignment.centerRight,
                        child: makeCellText('मुद्दल (Rs.)', isBold: true, fontSize: 8, color: PdfColors.white, align: ShapedTextAlign.end),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                        alignment: pw.Alignment.centerRight,
                        child: makeCellText('व्याज (Rs.)', isBold: true, fontSize: 8, color: PdfColors.white, align: ShapedTextAlign.end),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                        alignment: pw.Alignment.centerRight,
                        child: makeCellText('एकूण हप्ता (Rs.)', isBold: true, fontSize: 8, color: PdfColors.white, align: ShapedTextAlign.end),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                        alignment: pw.Alignment.centerRight,
                        child: makeCellText('उर्वरित मुद्दल (Rs.)', isBold: true, fontSize: 8, color: PdfColors.white, align: ShapedTextAlign.end),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                        alignment: pw.Alignment.center,
                        child: makeCellText('स्थिती', isBold: true, fontSize: 8, color: PdfColors.white, align: ShapedTextAlign.center),
                      ),
                    ],
                  ),

                  // Data Rows
                  ...effectiveEmis.asMap().entries.map((entry) {
                    final index = entry.key;
                    final emi = entry.value;
                    final isPaid = emi.status == 'paid';
                    final isEven = index % 2 == 0;

                    // Remaining principal after this EMI
                    final monthlyPrincipal = loan.loanPeriodMonths > 0 ? loan.approvedAmount / loan.loanPeriodMonths : emi.principal;
                    final paidSoFar = (index + 1) * monthlyPrincipal;
                    final balanceAfter = math.max(0.0, loan.approvedAmount - paidSoFar);

                    return pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: isPaid
                            ? PdfColor.fromHex('#F0FDF4')
                            : (isEven ? PdfColors.white : PdfColor.fromHex('#FAF5FF')),
                      ),
                      children: [
                        // हप्ता क्र.
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                          alignment: pw.Alignment.center,
                          child: makeCellText('${emi.emiNumber}', fontSize: 7.5, align: ShapedTextAlign.center),
                        ),
                        // देय तारीख
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                          alignment: pw.Alignment.center,
                          child: makeCellText(emi.dueDate, fontSize: 7.5, align: ShapedTextAlign.center),
                        ),
                        // मुद्दल
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                          alignment: pw.Alignment.centerRight,
                          child: makeCellText(emi.principal.toStringAsFixed(0), fontSize: 7.5, align: ShapedTextAlign.end),
                        ),
                        // व्याज
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                          alignment: pw.Alignment.centerRight,
                          child: makeCellText(emi.interest.toStringAsFixed(0), fontSize: 7.5, align: ShapedTextAlign.end),
                        ),
                        // एकूण हप्ता
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                          alignment: pw.Alignment.centerRight,
                          child: makeCellText(
                            emi.emiAmount.toStringAsFixed(0),
                            isBold: true,
                            fontSize: 7.5,
                            color: isPaid ? PdfColor.fromHex('#166534') : PdfColor.fromHex('#4A148C'),
                            align: ShapedTextAlign.end,
                          ),
                        ),
                        // उर्वरित मुद्दल
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                          alignment: pw.Alignment.centerRight,
                          child: makeCellText(
                            balanceAfter.toStringAsFixed(0),
                            fontSize: 7.5,
                            align: ShapedTextAlign.end,
                          ),
                        ),
                        // स्थिती
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                          alignment: pw.Alignment.center,
                          child: makeCellText(
                            isPaid ? 'भरले' : 'प्रलंबित',
                            isBold: true,
                            fontSize: 7,
                            color: isPaid ? PdfColor.fromHex('#166534') : PdfColor.fromHex('#DC2626'),
                            align: ShapedTextAlign.center,
                          ),
                        ),
                      ],
                    );
                  }),

                  // Total Row
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#EDE9FE'),
                      border: pw.Border(top: pw.BorderSide(color: PdfColor.fromHex('#4A148C'), width: 1)),
                    ),
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                        alignment: pw.Alignment.center,
                        child: makeCellText('एकूण', isBold: true, fontSize: 8, align: ShapedTextAlign.center),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                        alignment: pw.Alignment.center,
                        child: makeCellText('${effectiveEmis.length} हप्ते', isBold: true, fontSize: 7.5, align: ShapedTextAlign.center),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                        alignment: pw.Alignment.centerRight,
                        child: makeCellText(totalPrincipal.toStringAsFixed(0), isBold: true, fontSize: 8, align: ShapedTextAlign.end),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                        alignment: pw.Alignment.centerRight,
                        child: makeCellText(totalInterest.toStringAsFixed(0), isBold: true, fontSize: 8, align: ShapedTextAlign.end),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                        alignment: pw.Alignment.centerRight,
                        child: makeCellText(
                          totalEmi.toStringAsFixed(0),
                          isBold: true,
                          fontSize: 8,
                          color: PdfColor.fromHex('#4A148C'),
                          align: ShapedTextAlign.end,
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                        alignment: pw.Alignment.centerRight,
                        child: makeCellText('0', isBold: true, fontSize: 8, align: ShapedTextAlign.end),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                        alignment: pw.Alignment.center,
                        child: makeCellText('-', isBold: true, fontSize: 8, align: ShapedTextAlign.center),
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 20),

              // Signatures Block
              pw.Container(
                padding: const pw.EdgeInsets.only(top: 10),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Container(width: 100, height: 1, color: PdfColors.grey600),
                        pw.SizedBox(height: 4),
                        makeCellText('कर्जदार स्वाक्षरी', fontSize: 8, isBold: true),
                        makeCellText('(Borrower)', fontSize: 7, color: PdfColors.grey600),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Container(width: 100, height: 1, color: PdfColors.grey600),
                        pw.SizedBox(height: 4),
                        makeCellText('जामीनदार स्वाक्षरी', fontSize: 8, isBold: true),
                        makeCellText('(Guarantor)', fontSize: 7, color: PdfColors.grey600),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Container(width: 110, height: 1, color: PdfColors.grey600),
                        pw.SizedBox(height: 4),
                        makeCellText('अध्यक्ष / सचिव स्वाक्षरी', fontSize: 8, isBold: true),
                        makeCellText('(Authorized Sign)', fontSize: 7, color: PdfColors.grey600),
                      ],
                    ),
                  ],
                ),
              ),
            ];
          },
        ),
      );
    }

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'loan_voucher_${loan.loanCode}.pdf',
    );
  }

  // 3. LOAN EMI PAYMENT RECEIPT
  static Future<void> printLoanEmiReceipt({
    required Loan loan,
    required LoanEmi emi,
    required String groupName,
    Uint8List? receiptImageBytes,
  }) async {
    final doc = pw.Document();

    if (receiptImageBytes != null) {
      final image = pw.MemoryImage(receiptImageBytes);
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a5,
          margin: const pw.EdgeInsets.all(12),
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Image(image, fit: pw.BoxFit.contain),
            );
          },
        ),
      );
    } else {
      final theme = await _getTheme();

      doc.addPage(
        pw.Page(
          theme: theme,
          pageFormat: PdfPageFormat.a5,
          build: (pw.Context context) {
            return pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.purple900, width: 2),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text(
                    groupName.toUpperCase(),
                    style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.purple900),
                  ),
                ),
                pw.Center(
                  child: pw.Text('कर्ज हप्ता वसुली पावती (Loan EMI Receipt)', style: const pw.TextStyle(fontSize: 11)),
                ),
                pw.Divider(color: PdfColors.purple800),
                pw.SizedBox(height: 8),

                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('पावती क्र: ${emi.receiptNumber ?? "EMI-${loan.loanCode}-${emi.emiNumber}"}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text('दिनांक: ${emi.paymentDate ?? DateTime.now().toString().split(' ').first}'),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Text('कर्जदार: ${loan.memberName ?? "सदस्य"} (कर्ज कोड: ${loan.loanCode})', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
                pw.Text('हप्ता क्रमांक: #${emi.emiNumber} / ${loan.numberOfEmis} (नियत तारीख: ${emi.dueDate})', style: const pw.TextStyle(fontSize: 11)),
                pw.SizedBox(height: 10),

                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.purple50),
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('तपशील', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('रक्कम', style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('मुद्दल परतफेड (Principal)')),
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Rs. ${emi.principal.toStringAsFixed(2)}', textAlign: pw.TextAlign.right)),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('व्याज भरणा (Interest)')),
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Rs. ${emi.interest.toStringAsFixed(2)}', textAlign: pw.TextAlign.right)),
                      ],
                    ),
                    if (emi.lateFee > 0)
                      pw.TableRow(
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('लेट फी / दंड (Late Fee)')),
                          pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Rs. ${emi.lateFee.toStringAsFixed(2)}', textAlign: pw.TextAlign.right)),
                        ],
                      ),
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.purple100),
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('एकूण भरणा (Total Paid)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Rs. ${(emi.paidAmount > 0 ? emi.paidAmount : emi.emiAmount).toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.purple900), textAlign: pw.TextAlign.right)),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 8),

                pw.Text('भरणा प्रकार: ${emi.paymentMode?.toUpperCase() ?? "CASH"}'),
                pw.Spacer(),

                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('सभासद स्वाक्षरी'),
                    pw.Text('अध्यक्ष / खजिनदार स्वाक्षरी'),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Center(child: pw.Text('धन्यवाद!', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.purple900))),
              ],
            ),
          );
        },
      ),
    );
    }

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'emi_receipt_${loan.loanCode}_${emi.emiNumber}.pdf',
    );
  }

  // 4. LEGACY SAVINGS RECEIPT
  static Future<void> printSavingsReceipt({
    required Saving saving,
    required String groupName,
    required String memberName,
  }) async {
    final doc = pw.Document();
    final theme = await _getTheme();

    doc.addPage(
      pw.Page(
        theme: theme,
        pageFormat: PdfPageFormat.a5,
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.purple900, width: 2),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text(
                    groupName,
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.purple900),
                  ),
                ),
                pw.Center(
                  child: pw.Text('महिला बचत गट पावती (Savings Receipt)', style: const pw.TextStyle(fontSize: 12)),
                ),
                pw.Divider(color: PdfColors.purple800),
                pw.SizedBox(height: 10),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('पावती क्र: ${saving.receiptNumber ?? "REC-001"}'),
                    pw.Text('दिनांक: ${saving.savingsDate}'),
                  ],
                ),
                pw.SizedBox(height: 6),
                pw.Text('सदस्याचे नाव: $memberName', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
                pw.Text('बचत प्रकार: ${saving.savingsType.toUpperCase()}'),
                pw.Text('भरणा प्रकार: ${saving.paymentMode.toUpperCase()}'),
                pw.SizedBox(height: 12),
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.purple50,
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('एकूण रक्कम (Total Paid):', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
                      pw.Text('Rs. ${saving.amount.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16, color: PdfColors.purple900)),
                    ],
                  ),
                ),
                pw.Spacer(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('सदस्याची स्वाक्षरी'),
                    pw.Text('अध्यक्ष / खजिनदार स्वाक्षरी'),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Center(
                  child: pw.Text('धन्यवाद!', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'receipt_${saving.receiptNumber ?? "001"}.pdf',
    );
  }

  // 4. LOAN EMI OFFICIAL RECEIPT (कर्ज हप्ता अधिकृत पावती)
  static Future<void> printDetailedEmiCollectionReceipt({
    required String groupName,
    required String memberName,
    required String loanCode,
    required int emiNumber,
    required String paymentDate,
    required double collectionAmount,
    required double reducePrincipal,
    required double interest,
    required double overdueAmount,
    required double previousPendingPrincipal,
    required double remainingPrincipal,
    required String paymentMode,
    String? transactionId,
    String? collectedBy,
    String? remarks,
  }) async {
    final doc = pw.Document();
    final theme = await _getTheme();

    doc.addPage(
      pw.Page(
        theme: theme,
        pageFormat: PdfPageFormat.a5,
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.deepPurple900, width: 2),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text(
                    groupName,
                    style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold, color: PdfColors.deepPurple900),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Center(
                  child: pw.Text(
                    'कर्ज हप्ता वसुली पावती (Loan EMI Receipt)',
                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
                  ),
                ),
                pw.Divider(thickness: 1.2, color: PdfColors.deepPurple900),
                pw.SizedBox(height: 6),

                // Details Row
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('पावती क्र.: EMI-$loanCode-$emiNumber', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.Text('तारीख: $paymentDate', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('कर्जदार सभासद: $memberName', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                    pw.Text('कर्ज क्र.: $loanCode', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.deepPurple)),
                  ],
                ),
                pw.SizedBox(height: 10),

                // Breakdown Table
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.purple50),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('तपशील (Particulars)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('रक्कम (Amount in Rs.)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10), textAlign: pw.TextAlign.right),
                        ),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('एकूण जमा हप्ता रक्कम (Total Paid Amount)', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Rs. ${collectionAmount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.green900), textAlign: pw.TextAlign.right)),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('आकारलेले व्याज (Interest Accrued)', style: const pw.TextStyle(fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Rs. ${interest.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.right)),
                      ],
                    ),
                    if (overdueAmount > 0)
                      pw.TableRow(
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('थकबाकी विलंब शुल्क (Overdue Late Fee)', style: const pw.TextStyle(fontSize: 9, color: PdfColors.red900))),
                          pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Rs. ${overdueAmount.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.red900), textAlign: pw.TextAlign.right)),
                        ],
                      ),
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('कमी झालेले मुद्दल (Principal Reduced)', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Rs. ${reducePrincipal.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('पूर्वीची शिल्लक मुद्दल (Previous Balance)', style: const pw.TextStyle(fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Rs. ${previousPendingPrincipal.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.right)),
                      ],
                    ),
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.amber50),
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('आता शिल्लक बाकी मुद्दल (New Balance)', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.deepOrange900))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Rs. ${remainingPrincipal.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.deepOrange900), textAlign: pw.TextAlign.right)),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 8),

                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('भरणा प्रकार: $paymentMode ${transactionId != null && transactionId.isNotEmpty ? "($transactionId)" : ""}', style: const pw.TextStyle(fontSize: 9)),
                    if (collectedBy != null && collectedBy.isNotEmpty)
                      pw.Text('स्वीकारकर्ता: $collectedBy', style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
                if (remarks != null && remarks.isNotEmpty)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 3),
                    child: pw.Text('टीप: $remarks', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  ),

                pw.Spacer(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      children: [
                        pw.SizedBox(height: 25),
                        pw.Text('कर्जदार सभासद स्वाक्षरी', style: const pw.TextStyle(fontSize: 9)),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.SizedBox(height: 25),
                        pw.Text('अध्यक्ष / खजिनदार स्वाक्षरी', style: const pw.TextStyle(fontSize: 9)),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 6),
                pw.Center(
                  child: pw.Text('बचत गट संगणकीय पावती • धन्यवाद!', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'emi_receipt_EMI-$loanCode-$emiNumber.pdf',
    );
  }

  // 12. OFFICIAL BONUS & DIVIDEND REPORT (लाभांश व बोनस अहवाल)
  static Future<void> printBonusReport({
    required List<Bonus> bonuses,
    required String groupName,
    required String financialYear,
    required String fromDate,
    required String toDate,
    String? bonusType,
  }) async {
    final doc = pw.Document();

    pw.ThemeData reportTheme;
    ShapedFont? devFont;
    ShapedFont? devBoldFont;
    ShapedFont? robotoFont;

    try {
      final fontData = await rootBundle.load('assets/fonts/NotoSansDevanagari-Regular.ttf');
      final boldData = await rootBundle.load('assets/fonts/NotoSansDevanagari-Bold.ttf');
      final robotoData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');

      devFont = ShapedFont.fromBytes(fontData.buffer.asUint8List(), name: 'NotoSansDevanagari-Regular');
      devBoldFont = ShapedFont.fromBytes(boldData.buffer.asUint8List(), name: 'NotoSansDevanagari-Bold');
      robotoFont = ShapedFont.fromBytes(robotoData.buffer.asUint8List(), name: 'Roboto-Regular');

      reportTheme = pw.ThemeData.withFont(
        base: pw.Font.ttf(fontData),
        bold: pw.Font.ttf(boldData),
        fontFallback: [pw.Font.ttf(robotoData)],
      );
    } catch (_) {
      reportTheme = await getDevanagariTheme();
    }

    String cleanTxt(String text) {
      if (devFont == null) return text;
      final buffer = StringBuffer();
      for (final rune in text.runes) {
        bool supported = false;
        for (final font in [devFont, devBoldFont, robotoFont]) {
          if (font != null && font.supportsRune(rune)) {
            supported = true;
            break;
          }
        }
        if (supported) buffer.writeCharCode(rune);
      }
      return buffer.toString();
    }

    pw.Widget makeText(
      String text, {
      bool isBold = false,
      PdfColor? color,
      double fontSize = 8.5,
      ShapedTextAlign align = ShapedTextAlign.start,
      pw.TextAlign pwAlign = pw.TextAlign.left,
    }) {
      if (devFont != null && devBoldFont != null && robotoFont != null) {
        return ShapedText(
          cleanTxt(text),
          style: ShapedTextStyle(
            font: isBold ? devBoldFont : devFont,
            fallbackFonts: [robotoFont],
            fontSize: fontSize,
            color: color ?? PdfColors.black,
            align: align,
          ),
        );
      }
      return pw.Text(
        text,
        textAlign: pwAlign,
        style: pw.TextStyle(
          fontSize: fontSize,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color ?? PdfColors.black,
        ),
      );
    }

    final double totalBasis = bonuses.fold(0.0, (s, b) => s + b.basisAmount);
    final double totalBonus = bonuses.where((b) => !b.isCancelled).fold(0.0, (s, b) => s + b.bonusAmount);
    final double totalPaid = bonuses.where((b) => b.isPaid).fold(0.0, (s, b) => s + b.paidAmount);
    final double totalPending = bonuses.where((b) => b.isPending).fold(0.0, (s, b) => s + b.balanceAmount);

    doc.addPage(
      pw.MultiPage(
        theme: reportTheme,
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        header: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 10),
            padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#1E3A8A'),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    makeText(
                      groupName.toUpperCase(),
                      isBold: true,
                      fontSize: 14,
                      color: PdfColors.white,
                    ),
                    makeText(
                      'लाभांश व बोनस अहवाल (BONUS & DIVIDEND REPORT)',
                      fontSize: 9.5,
                      color: PdfColors.grey200,
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    makeText(
                      'आर्थिक वर्ष: $financialYear',
                      isBold: true,
                      fontSize: 10,
                      color: PdfColors.white,
                    ),
                    makeText(
                      'कालावधी: $fromDate ते $toDate',
                      fontSize: 8.5,
                      color: PdfColors.grey300,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(top: 8),
            padding: const pw.EdgeInsets.only(top: 4),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                makeText('सखी बचत गट व्यवस्थापन प्रणाली • अधिकृत बोनस अहवाल', fontSize: 7.5, color: PdfColors.grey600),
                makeText('पृष्ठ ${context.pageNumber} / ${context.pagesCount}', isBold: true, fontSize: 7.5, color: PdfColors.grey700),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          return [
            // KPI Summary Cards Bar
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 10),
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F8FAFC'),
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  pw.Column(
                    children: [
                      makeText('एकूण सभासद (Members)', fontSize: 8, color: PdfColors.grey600),
                      makeText('${bonuses.length}', isBold: true, fontSize: 11, color: PdfColor.fromHex('#1E3A8A')),
                    ],
                  ),
                  pw.Column(
                    children: [
                      makeText('एकूण मूलभूत बचत (Basis Amount)', fontSize: 8, color: PdfColors.grey600),
                      makeText('Rs. ${totalBasis.toStringAsFixed(0)}', isBold: true, fontSize: 11, color: PdfColors.black),
                    ],
                  ),
                  pw.Column(
                    children: [
                      makeText('एकूण बोनस (Total Bonus)', fontSize: 8, color: PdfColors.grey600),
                      makeText('Rs. ${totalBonus.toStringAsFixed(0)}', isBold: true, fontSize: 11, color: PdfColor.fromHex('#16A34A')),
                    ],
                  ),
                  pw.Column(
                    children: [
                      makeText('वाटप झालेला बोनस (Paid)', fontSize: 8, color: PdfColors.grey600),
                      makeText('Rs. ${totalPaid.toStringAsFixed(0)}', isBold: true, fontSize: 11, color: PdfColor.fromHex('#059669')),
                    ],
                  ),
                  pw.Column(
                    children: [
                      makeText('प्रलंबित बोनस (Pending)', fontSize: 8, color: PdfColors.grey600),
                      makeText('Rs. ${totalPending.toStringAsFixed(0)}', isBold: true, fontSize: 11, color: PdfColor.fromHex('#D97706')),
                    ],
                  ),
                ],
              ),
            ),

            // Bonus Table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: const {
                0: pw.FlexColumnWidth(0.6),  // अ.क्र.
                1: pw.FlexColumnWidth(2.2),  // सभासद नाव
                2: pw.FlexColumnWidth(1.2),  // प्रकार
                3: pw.FlexColumnWidth(1.4),  // मूलभूत बचत
                4: pw.FlexColumnWidth(0.9),  // दर
                5: pw.FlexColumnWidth(1.3),  // एकूण बोनस
                6: pw.FlexColumnWidth(1.3),  // भरले
                7: pw.FlexColumnWidth(1.3),  // शिल्लक
                8: pw.FlexColumnWidth(1.0),  // स्थिती
              },
              children: [
                // Header
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColor.fromHex('#1E3A8A')),
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                      alignment: pw.Alignment.center,
                      child: makeText('अ.क्र.', isBold: true, fontSize: 8, color: PdfColors.white, align: ShapedTextAlign.center),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 6),
                      child: makeText('सभासदाचे नाव (Member Name)', isBold: true, fontSize: 8, color: PdfColors.white),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                      alignment: pw.Alignment.center,
                      child: makeText('बोनस प्रकार', isBold: true, fontSize: 8, color: PdfColors.white, align: ShapedTextAlign.center),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                      alignment: pw.Alignment.centerRight,
                      child: makeText('मूलभूत बचत (Rs.)', isBold: true, fontSize: 8, color: PdfColors.white, align: ShapedTextAlign.end),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                      alignment: pw.Alignment.center,
                      child: makeText('दर (%)', isBold: true, fontSize: 8, color: PdfColors.white, align: ShapedTextAlign.center),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                      alignment: pw.Alignment.centerRight,
                      child: makeText('एकूण बोनस (Rs.)', isBold: true, fontSize: 8, color: PdfColors.white, align: ShapedTextAlign.end),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                      alignment: pw.Alignment.centerRight,
                      child: makeText('भरले (Rs.)', isBold: true, fontSize: 8, color: PdfColors.white, align: ShapedTextAlign.end),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                      alignment: pw.Alignment.centerRight,
                      child: makeText('शिल्लक (Rs.)', isBold: true, fontSize: 8, color: PdfColors.white, align: ShapedTextAlign.end),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                      alignment: pw.Alignment.center,
                      child: makeText('स्थिती', isBold: true, fontSize: 8, color: PdfColors.white, align: ShapedTextAlign.center),
                    ),
                  ],
                ),

                // Rows
                ...bonuses.asMap().entries.map((entry) {
                  final idx = entry.key + 1;
                  final b = entry.value;
                  final isEven = idx % 2 == 0;
                  final rowColor = isEven ? PdfColor.fromHex('#F8FAFC') : PdfColors.white;

                  return pw.TableRow(
                    decoration: pw.BoxDecoration(color: rowColor),
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                        alignment: pw.Alignment.center,
                        child: makeText('$idx', fontSize: 8, align: ShapedTextAlign.center),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                        child: makeText(b.memberName ?? 'सभासद', isBold: true, fontSize: 8),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                        alignment: pw.Alignment.center,
                        child: makeText(b.bonusTypeLabelMr.split(' ')[0], fontSize: 7.5, align: ShapedTextAlign.center),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                        alignment: pw.Alignment.centerRight,
                        child: makeText('Rs. ${b.basisAmount.toStringAsFixed(0)}', fontSize: 8, align: ShapedTextAlign.end),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                        alignment: pw.Alignment.center,
                        child: makeText('${b.bonusRate.toStringAsFixed(1)}%', fontSize: 8, align: ShapedTextAlign.center),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                        alignment: pw.Alignment.centerRight,
                        child: makeText('Rs. ${b.bonusAmount.toStringAsFixed(0)}', isBold: true, fontSize: 8, align: ShapedTextAlign.end),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                        alignment: pw.Alignment.centerRight,
                        child: makeText('Rs. ${b.paidAmount.toStringAsFixed(0)}', fontSize: 8, color: PdfColor.fromHex('#059669'), align: ShapedTextAlign.end),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                        alignment: pw.Alignment.centerRight,
                        child: makeText('Rs. ${b.balanceAmount.toStringAsFixed(0)}', fontSize: 8, color: b.balanceAmount > 0 ? PdfColor.fromHex('#D97706') : PdfColors.grey600, align: ShapedTextAlign.end),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                        alignment: pw.Alignment.center,
                        child: makeText(b.statusLabelMr.split(' ')[0], isBold: true, fontSize: 7.5, color: b.isPaid ? PdfColor.fromHex('#059669') : PdfColor.fromHex('#D97706'), align: ShapedTextAlign.center),
                      ),
                    ],
                  );
                }),

                // Total Summary Row
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColor.fromHex('#E0E7FF')),
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                      alignment: pw.Alignment.center,
                      child: makeText('एकूण', isBold: true, fontSize: 8.5, align: ShapedTextAlign.center),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 6),
                      child: makeText('${bonuses.length} सभासद', isBold: true, fontSize: 8.5),
                    ),
                    pw.Container(padding: const pw.EdgeInsets.all(4), child: pw.SizedBox()),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                      alignment: pw.Alignment.centerRight,
                      child: makeText('Rs. ${totalBasis.toStringAsFixed(0)}', isBold: true, fontSize: 8.5, align: ShapedTextAlign.end),
                    ),
                    pw.Container(padding: const pw.EdgeInsets.all(4), child: pw.SizedBox()),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                      alignment: pw.Alignment.centerRight,
                      child: makeText('Rs. ${totalBonus.toStringAsFixed(0)}', isBold: true, fontSize: 8.5, color: PdfColor.fromHex('#1E3A8A'), align: ShapedTextAlign.end),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                      alignment: pw.Alignment.centerRight,
                      child: makeText('Rs. ${totalPaid.toStringAsFixed(0)}', isBold: true, fontSize: 8.5, color: PdfColor.fromHex('#059669'), align: ShapedTextAlign.end),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                      alignment: pw.Alignment.centerRight,
                      child: makeText('Rs. ${totalPending.toStringAsFixed(0)}', isBold: true, fontSize: 8.5, color: PdfColor.fromHex('#D97706'), align: ShapedTextAlign.end),
                    ),
                    pw.Container(padding: const pw.EdgeInsets.all(4), child: pw.SizedBox()),
                  ],
                ),
              ],
            ),

            pw.SizedBox(height: 25),

            // Signatures block
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  children: [
                    pw.Container(width: 140, height: 1, color: PdfColors.grey400),
                    pw.SizedBox(height: 4),
                    makeText('खजिनदार स्वाक्षरी', isBold: true, fontSize: 8.5),
                  ],
                ),
                pw.Column(
                  children: [
                    pw.Container(width: 140, height: 1, color: PdfColors.grey400),
                    pw.SizedBox(height: 4),
                    makeText('सचिव स्वाक्षरी', isBold: true, fontSize: 8.5),
                  ],
                ),
                pw.Column(
                  children: [
                    pw.Container(width: 140, height: 1, color: PdfColors.grey400),
                    pw.SizedBox(height: 4),
                    makeText('अध्यक्ष / मुख्य सही व शिक्का', isBold: true, fontSize: 8.5),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'bonus_report_${financialYear.replaceAll(" ", "")}.pdf',
    );
  }
}
