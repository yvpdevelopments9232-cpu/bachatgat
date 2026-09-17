import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf_text_shaper/pdf_text_shaper.dart';
import 'package:printing/printing.dart';
import '../core/utils/image_helper.dart';
import '../models/monthly_bachatgat_report_model.dart';

class MonthlyBachatgatPdfExporter {
  static final NumberFormat _numFormat = NumberFormat('#,##,###', 'en_IN');

  static Uint8List? cachedDevRegular;
  static Uint8List? cachedDevBold;
  static Uint8List? cachedRoboto;

  static Future<void> initFonts() async {
    if (cachedDevRegular != null && cachedDevBold != null && cachedRoboto != null) return;
    try {
      final devReg = await rootBundle.load('assets/fonts/NotoSansDevanagari-Regular.ttf');
      cachedDevRegular = devReg.buffer.asUint8List(devReg.offsetInBytes, devReg.lengthInBytes);

      final devBold = await rootBundle.load('assets/fonts/NotoSansDevanagari-Bold.ttf');
      cachedDevBold = devBold.buffer.asUint8List(devBold.offsetInBytes, devBold.lengthInBytes);

      final roboto = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      cachedRoboto = roboto.buffer.asUint8List(roboto.offsetInBytes, roboto.lengthInBytes);
    } catch (e) {
      debugPrint('Error loading fonts for Monthly Bachatgat PDF: $e');
      rethrow;
    }
  }

  static String _formatAmount(double amt, {bool blankIfZero = false}) {
    if (blankIfZero && amt <= 0.001) return '';
    return _numFormat.format(amt.round());
  }

  static Future<Uint8List> generatePdfBytes(
    MonthlyBachatgatReportData data, {
    PdfPageFormat? pageFormat,
  }) async {
    await initFonts();

    final format = pageFormat ?? PdfPageFormat.a4.landscape;

    final devFont = ShapedFont.fromBytes(cachedDevRegular!, name: 'NotoSansDevanagari-Regular');
    final devBoldFont = ShapedFont.fromBytes(cachedDevBold!, name: 'NotoSansDevanagari-Bold');
    final robotoFont = ShapedFont.fromBytes(cachedRoboto!, name: 'Roboto-Regular');

    final doc = pw.Document();

    final isLandscape = format.width > format.height;
    final horizontalMargin = isLandscape ? 18.0 : 10.0;
    final verticalMargin = isLandscape ? 16.0 : 12.0;

    final group = data.group;
    final groupName = (group?.groupName ?? data.groupName).trim();
    final addressParts = [group?.village, group?.taluka, group?.district]
        .where((s) => s != null && s.trim().isNotEmpty)
        .join(', ');
    final groupAddress = addressParts.isNotEmpty ? addressParts : 'महाराष्ट्र';
    final regNo = (group?.registrationNumber ?? '').trim();
    final mobile = (group?.mobile ?? '').trim();

    final subList = <String>[groupAddress];
    if (regNo.isNotEmpty) subList.add('नोंदणी क्र: $regNo');
    if (mobile.isNotEmpty) subList.add('मो. $mobile');
    final subtitleStr = subList.join(' | ');

    Uint8List? logoBytes = ImageHelper.getDecodedBytes(group?.logoUrl);
    pw.MemoryImage? safeLogoImage;
    if (logoBytes != null && logoBytes.isNotEmpty) {
      try {
        safeLogoImage = pw.MemoryImage(logoBytes);
      } catch (e) {
        safeLogoImage = null;
      }
    }

    // Palette matching reference image
    final colorHeaderBanner = PdfColor.fromHex('#D9E1F2'); // Light blue
    final colorBannerBorder = PdfColor.fromHex('#8EA9DB');
    final colorGreen = PdfColor.fromHex('#C6EFCE'); // Green for कर्ज आजअखेर
    final colorYellow = PdfColor.fromHex('#FFF2CC'); // Yellow for दिलेले कर्ज
    final colorOrange = PdfColor.fromHex('#FCE4D6'); // Light orange for अखेर शिल्लक कर्ज
    final colorGray = PdfColor.fromHex('#F2F2F2'); // Header gray
    final colorBorder = PdfColor.fromHex('#595959'); // Crisp grid lines

    // Typography
    final headerTitleStyle = ShapedTextStyle(font: devBoldFont, fallbackFonts: [robotoFont], fontSize: isLandscape ? 13 : 11, color: PdfColors.white);
    final headerSubStyle = ShapedTextStyle(font: devFont, fallbackFonts: [robotoFont], fontSize: isLandscape ? 8 : 7, color: PdfColors.grey200);
    final bannerStyle = ShapedTextStyle(font: devBoldFont, fallbackFonts: [robotoFont], fontSize: isLandscape ? 12 : 10, color: PdfColor.fromHex('#1F497D'));
    final headerStyle = ShapedTextStyle(font: devBoldFont, fallbackFonts: [robotoFont], fontSize: isLandscape ? 8 : 6.8, color: PdfColors.black);
    final rowStyle = ShapedTextStyle(font: devFont, fallbackFonts: [robotoFont], fontSize: isLandscape ? 8 : 6.8, color: PdfColors.black);
    final rowBoldStyle = ShapedTextStyle(font: devBoldFont, fallbackFonts: [robotoFont], fontSize: isLandscape ? 8 : 6.8, color: PdfColors.black);
    final totalStyle = ShapedTextStyle(font: devBoldFont, fallbackFonts: [robotoFont], fontSize: isLandscape ? 8.5 : 7.2, color: PdfColors.black);
    final footerStyle = ShapedTextStyle(font: devBoldFont, fallbackFonts: [robotoFont], fontSize: isLandscape ? 11 : 9, color: PdfColor.fromHex('#1F497D'));

    final padH = isLandscape ? 4.5 : 2.5;
    final padV = isLandscape ? 3.5 : 2.5;

    // Column Flex Widths (10 Columns)
    final colWidths = {
      0: pw.FlexColumnWidth(isLandscape ? 0.5 : 0.45), // अ.नं
      1: pw.FlexColumnWidth(isLandscape ? 2.3 : 1.9),  // सभासदाचे नाव
      2: pw.FlexColumnWidth(isLandscape ? 1.2 : 1.1),  // कर्ज आजअखेर
      3: pw.FlexColumnWidth(isLandscape ? 1.1 : 1.0),  // दिलेले कर्ज
      4: pw.FlexColumnWidth(isLandscape ? 0.9 : 0.85), // महिना बचत
      5: pw.FlexColumnWidth(isLandscape ? 1.3 : 1.15), // एकूण बचत आजअखेर
      6: pw.FlexColumnWidth(isLandscape ? 0.9 : 0.85), // हप्ता
      7: pw.FlexColumnWidth(isLandscape ? 0.9 : 0.85), // व्याज
      8: pw.FlexColumnWidth(isLandscape ? 1.0 : 0.95), // आजची एकूण
      9: pw.FlexColumnWidth(isLandscape ? 1.3 : 1.2),  // या महिन्यात अखेर शिल्लक कर्ज
    };

    // Table Header Row
    pw.TableRow buildHeader() {
      return pw.TableRow(
        children: [
          _cellHeader('अ. नं', colorGray, headerStyle, align: pw.Alignment.center, padH: padH, padV: padV),
          _cellHeader('सभासदाचे नाव', colorGray, headerStyle, align: pw.Alignment.center, padH: padH, padV: padV),
          _cellHeader('कर्ज\nआजअखेर', colorGreen, headerStyle, align: pw.Alignment.center, padH: padH, padV: padV),
          _cellHeader('दिलेले कर्ज', colorYellow, headerStyle, align: pw.Alignment.center, padH: padH, padV: padV),
          _cellHeader('महिना\nबचत', colorGray, headerStyle, align: pw.Alignment.center, padH: padH, padV: padV),
          _cellHeader('एकूण बचत\nआजअखेर', colorGray, headerStyle, align: pw.Alignment.center, padH: padH, padV: padV),
          _cellHeader('हप्ता', colorGray, headerStyle, align: pw.Alignment.center, padH: padH, padV: padV),
          _cellHeader('व्याज', colorGray, headerStyle, align: pw.Alignment.center, padH: padH, padV: padV),
          _cellHeader('आजची\nएकूण', colorGray, headerStyle, align: pw.Alignment.center, padH: padH, padV: padV),
          _cellHeader('या महिन्यात\nअखेर\nशिल्लक कर्ज', colorOrange, headerStyle, align: pw.Alignment.center, padH: padH, padV: padV),
        ],
      );
    }

    // Dynamic Borrower Note String
    String borrowerNoteText;
    if (data.newBorrowers.isNotEmpty) {
      final namesAndAmts = data.newBorrowers.map((b) => '${b.memberName} ${_formatAmount(b.amount)}₹').join(' , ');
      borrowerNoteText = 'कर्जदार: $namesAndAmts';
    } else {
      borrowerNoteText = 'कर्जदार: या महिन्यात कोणतेही नवीन कर्ज वाटप नाही';
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: pw.EdgeInsets.symmetric(horizontal: horizontalMargin, vertical: verticalMargin),
        header: (ctx) => pw.Column(
          children: [
            // Top Branded Header Bar matching official Bachat Gat reports
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 10),
              margin: const pw.EdgeInsets.only(bottom: 4),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#1E3A8A'),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      // Group Logo / Profile Image
                      if (safeLogoImage != null)
                        pw.Container(
                          width: 32,
                          height: 32,
                          margin: const pw.EdgeInsets.only(right: 8),
                          decoration: pw.BoxDecoration(
                            shape: pw.BoxShape.circle,
                            color: PdfColors.white,
                            border: pw.Border.all(color: PdfColor.fromHex('#D97706'), width: 1.5),
                          ),
                          child: pw.ClipOval(
                            child: pw.Image(
                              safeLogoImage,
                              width: 32,
                              height: 32,
                              fit: pw.BoxFit.cover,
                            ),
                          ),
                        )
                      else
                        pw.Container(
                          width: 32,
                          height: 32,
                          margin: const pw.EdgeInsets.only(right: 8),
                          decoration: pw.BoxDecoration(
                            shape: pw.BoxShape.circle,
                            color: PdfColor.fromHex('#D97706'),
                            border: pw.Border.all(color: PdfColors.white, width: 1.5),
                          ),
                          child: pw.Center(
                            child: ShapedText(
                              groupName.trim().isNotEmpty ? groupName.trim().substring(0, 1) : 'स',
                              style: ShapedTextStyle(
                                font: devBoldFont,
                                fallbackFonts: [robotoFont],
                                fontSize: 15,
                                color: PdfColors.white,
                                align: ShapedTextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      // Group Name & Address
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          ShapedText(
                            groupName.toUpperCase(),
                            style: headerTitleStyle,
                          ),
                          pw.SizedBox(height: 1),
                          ShapedText(
                            subtitleStr,
                            style: headerSubStyle,
                          ),
                        ],
                      ),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#D97706'),
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: ShapedText(
                      'अधिकृत अहवाल (OFFICIAL)',
                      style: ShapedTextStyle(
                        font: devBoldFont,
                        fallbackFonts: [robotoFont],
                        fontSize: 7.5,
                        color: PdfColors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Month Header Banner matching reference image
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(vertical: 4),
              decoration: pw.BoxDecoration(
                color: colorHeaderBanner,
                border: pw.Border.all(color: colorBannerBorder, width: 1),
              ),
              child: pw.Center(
                child: ShapedText(
                  'बचत महिना : ${data.monthNameMr} ${data.year}',
                  style: bannerStyle,
                ),
              ),
            ),
            pw.SizedBox(height: 1),
          ],
        ),
        footer: (ctx) => pw.Column(
          children: [
            pw.SizedBox(height: 4),
            // Centered Blue Footer Box matching reference image
            pw.Center(
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 5),
                decoration: pw.BoxDecoration(
                  color: colorHeaderBanner,
                  border: pw.Border.all(color: colorBannerBorder, width: 1),
                ),
                child: ShapedText(
                  borrowerNoteText,
                  style: ShapedTextStyle(
                    font: footerStyle.font,
                    fallbackFonts: footerStyle.fallbackFonts,
                    fontSize: footerStyle.fontSize,
                    color: footerStyle.color,
                    align: ShapedTextAlign.center,
                  ),
                ),
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'गटाचे नाव: ${data.groupName}',
                  style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
                ),
                pw.Text(
                  'पान ${ctx.pageNumber} / ${ctx.pagesCount}',
                  style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
                ),
              ],
            ),
          ],
        ),
        build: (ctx) => [
          pw.Table(
            border: pw.TableBorder.all(color: colorBorder, width: 0.6),
            columnWidths: colWidths,
            children: [
              // Header
              buildHeader(),

              // Data Rows
              ...data.rows.map((row) {
                return pw.TableRow(
                  children: [
                    _cell(row.srNo.toString(), rowStyle, align: pw.Alignment.center, padH: padH, padV: padV),
                    _cell(row.memberName, rowBoldStyle, align: pw.Alignment.centerLeft, padH: padH, padV: padV),
                    _cell(_formatAmount(row.openingLoan), rowBoldStyle, bgColor: colorGreen, padH: padH, padV: padV),
                    _cell(_formatAmount(row.newLoan, blankIfZero: true), rowBoldStyle, bgColor: colorYellow, padH: padH, padV: padV),
                    _cell(_formatAmount(row.monthlySaving), rowStyle, padH: padH, padV: padV),
                    _cell(_formatAmount(row.cumulativeSavings), rowStyle, padH: padH, padV: padV),
                    _cell(_formatAmount(row.installment), rowStyle, padH: padH, padV: padV),
                    _cell(_formatAmount(row.interest), rowStyle, padH: padH, padV: padV),
                    _cell(_formatAmount(row.todayTotal), rowBoldStyle, padH: padH, padV: padV),
                    _cell(_formatAmount(row.closingLoan), rowBoldStyle, bgColor: colorOrange, padH: padH, padV: padV),
                  ],
                );
              }),

              // Total Row matching reference image
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColors.white),
                children: [
                  _cell('', totalStyle, align: pw.Alignment.center, padH: padH, padV: padV),
                  _cell('एकूण जमा:', totalStyle, align: pw.Alignment.centerRight, padH: padH, padV: padV),
                  _cell(_formatAmount(data.totalOpeningLoan), totalStyle, bgColor: colorGreen, padH: padH, padV: padV),
                  _cell(_formatAmount(data.totalNewLoan, blankIfZero: true), totalStyle, bgColor: colorYellow, padH: padH, padV: padV),
                  _cell(_formatAmount(data.totalMonthlySaving), totalStyle, padH: padH, padV: padV),
                  _cell(_formatAmount(data.totalCumulativeSavings), totalStyle, padH: padH, padV: padV),
                  _cell(_formatAmount(data.totalInstallment), totalStyle, padH: padH, padV: padV),
                  _cell(_formatAmount(data.totalInterest), totalStyle, padH: padH, padV: padV),
                  _cell(_formatAmount(data.totalTodayTotal), totalStyle, padH: padH, padV: padV),
                  _cell(_formatAmount(data.totalClosingLoan), totalStyle, bgColor: colorOrange, padH: padH, padV: padV),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _cellHeader(
    String text,
    PdfColor bgColor,
    ShapedTextStyle style, {
    pw.Alignment align = pw.Alignment.center,
    double padH = 4.0,
    double padV = 4.0,
  }) {
    return pw.Container(
      color: bgColor,
      padding: pw.EdgeInsets.symmetric(horizontal: padH, vertical: padV),
      alignment: align,
      child: ShapedText(
        text,
        style: ShapedTextStyle(
          font: style.font,
          fallbackFonts: style.fallbackFonts,
          fontSize: style.fontSize,
          color: style.color,
          align: ShapedTextAlign.center,
        ),
      ),
    );
  }

  static pw.Widget _cell(
    String text,
    ShapedTextStyle style, {
    pw.Alignment align = pw.Alignment.centerRight,
    PdfColor? bgColor,
    double padH = 5.0,
    double padV = 3.5,
  }) {
    return pw.Container(
      color: bgColor,
      padding: pw.EdgeInsets.symmetric(horizontal: padH, vertical: padV),
      alignment: align,
      child: ShapedText(
        text,
        style: ShapedTextStyle(
          font: style.font,
          fallbackFonts: style.fallbackFonts,
          fontSize: style.fontSize,
          color: style.color,
          align: align == pw.Alignment.centerRight
              ? ShapedTextAlign.end
              : (align == pw.Alignment.center ? ShapedTextAlign.center : ShapedTextAlign.start),
        ),
      ),
    );
  }

  static Future<void> printReport(MonthlyBachatgatReportData data) async {
    await Printing.layoutPdf(
      onLayout: (format) async => await generatePdfBytes(data, pageFormat: format),
      name: 'मासिक_बचत_अहवाल_${data.monthNameMr}_${data.year}.pdf',
      format: PdfPageFormat.a4.landscape,
    );
  }

  static Future<String?> exportPdf(MonthlyBachatgatReportData data) async {
    final pdfBytes = await generatePdfBytes(data, pageFormat: PdfPageFormat.a4.landscape);
    final filename = 'मासिक_बचत_अहवाल_${data.monthNameMr}_${data.year}.pdf';

    String? savedPath;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      try {
        final downloadsDir = await getDownloadsDirectory();
        if (downloadsDir != null) {
          final targetFile = File('${downloadsDir.path}\\$filename');
          await targetFile.writeAsBytes(pdfBytes);
          savedPath = targetFile.path;
        }
      } catch (e) {
        debugPrint('Direct save to Downloads note: $e');
      }
    }

    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: filename,
    );

    return savedPath;
  }
}
