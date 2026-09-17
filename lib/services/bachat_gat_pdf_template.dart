import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf_text_shaper/pdf_text_shaper.dart';
import 'package:printing/printing.dart';
import '../models/report_model.dart';

class BachatGatPdfTemplate {
  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  static final DateFormat _dateTimeFormat = DateFormat('dd/MM/yyyy hh:mm a');
  static final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ');

  static Uint8List? _cachedDevRegular;
  static Uint8List? _cachedDevBold;
  static Uint8List? _cachedRoboto;

  /// Loads and caches font bytes from bundled application assets
  static Future<void> _initFonts() async {
    if (_cachedDevRegular != null && _cachedDevBold != null && _cachedRoboto != null) return;
    try {
      final devReg = await rootBundle.load('assets/fonts/NotoSansDevanagari-Regular.ttf');
      _cachedDevRegular = devReg.buffer.asUint8List(devReg.offsetInBytes, devReg.lengthInBytes);

      final devBold = await rootBundle.load('assets/fonts/NotoSansDevanagari-Bold.ttf');
      _cachedDevBold = devBold.buffer.asUint8List(devBold.offsetInBytes, devBold.lengthInBytes);

      final roboto = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      _cachedRoboto = roboto.buffer.asUint8List(roboto.offsetInBytes, roboto.lengthInBytes);
    } catch (e) {
      debugPrint('Error loading bundled PDF fonts: $e');
      rethrow;
    }
  }

  /// Sanitizes text so only runes supported by loaded fonts or whitespace are emitted.
  /// Prevents HarfBuzz StateError on unsupported emojis or obscure symbols.
  static String _cleanText(String? input, List<ShapedFont> fonts) {
    if (input == null || input.isEmpty) return '';
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      if (rune == 0x09 || rune == 0x0A || rune == 0x0D || rune == 0x20 || rune == 0x00A0) {
        buffer.writeCharCode(rune);
        continue;
      }
      bool supported = false;
      for (final font in fonts) {
        if (font.supportsRune(rune)) {
          supported = true;
          break;
        }
      }
      if (supported) {
        buffer.writeCharCode(rune);
      }
    }
    return buffer.toString();
  }

  /// Translates raw English database values/enums into clean Marathi & bilingual text
  static String formatCellValue(
    dynamic val, {
    bool isCurrency = false,
    bool isNumeric = false,
    bool isDate = false,
  }) {
    if (val == null) return '-';
    final str = val.toString().trim();
    if (str.isEmpty) return '-';

    if (isCurrency) {
      final numVal = double.tryParse(str) ?? 0.0;
      return _currencyFormat.format(numVal);
    }
    if (isNumeric) {
      final numVal = double.tryParse(str) ?? 0.0;
      return numVal.toStringAsFixed(0);
    }
    if (isDate) {
      try {
        return _dateFormat.format(DateTime.parse(str));
      } catch (_) {
        return str;
      }
    }

    // Clean English enums to Marathi bilingual
    final lower = str.toLowerCase();
    switch (lower) {
      case 'female':
        return 'महिला (Female)';
      case 'male':
        return 'पुरुष (Male)';
      case 'other':
        return 'इतर (Other)';
      case 'active':
        return 'सक्रिय (Active)';
      case 'inactive':
        return 'निष्क्रिय (Inactive)';
      case 'pending':
        return 'प्रलंबित (Pending)';
      case 'approved':
        return 'मंजूर (Approved)';
      case 'rejected':
        return 'नाकारले (Rejected)';
      case 'completed':
      case 'closed':
        return 'पूर्ण (Completed)';
      case 'disbursed':
        return 'वितरित (Disbursed)';
      case 'overdue':
        return 'थकबाकी (Overdue)';
      case 'cash':
        return 'रोख (Cash)';
      case 'online':
      case 'upi':
        return 'ऑनलाईन (UPI)';
      case 'bank':
      case 'bank_transfer':
        return 'बँक (Bank)';
      case 'president':
        return 'अध्यक्ष (President)';
      case 'secretary':
        return 'सचिव (Secretary)';
      case 'treasurer':
        return 'खजिनदार (Treasurer)';
      case 'member':
        return 'सदस्य (Member)';
      default:
        return str;
    }
  }

  /// Generates the complete standardized Bachat Gat PDF document matching official standards
  static Future<Uint8List> generateReportPdf({
    required ReportDefinition report,
    required List<Map<String, dynamic>> records,
    required DateTime fromDate,
    required DateTime toDate,
    String groupName = 'सखी महिला बचत गट',
    String? groupAddress,
    String? registrationNumber,
    Uint8List? logoBytes,
    Map<String, dynamic>? summaryKpis,
  }) async {
    await _initFonts();

    final devFont = ShapedFont.fromBytes(_cachedDevRegular!, name: 'NotoSansDevanagari-Regular');
    final devBoldFont = ShapedFont.fromBytes(_cachedDevBold!, name: 'NotoSansDevanagari-Bold');
    final robotoFont = ShapedFont.fromBytes(_cachedRoboto!, name: 'Roboto-Regular');
    final allFonts = [devFont, devBoldFont, robotoFont];

    try {
      final doc = pw.Document();

      final isLandscape = report.isLandscape || report.columns.length > 6;
      final pageFormat = isLandscape ? PdfPageFormat.a4.landscape : PdfPageFormat.a4;

      // Typography Styles with HarfBuzz Devanagari text shaping + Latin Roboto fallback
      final titleStyle = ShapedTextStyle(font: devBoldFont, fallbackFonts: [robotoFont], fontSize: 15, color: PdfColors.white);
      final subTitleStyle = ShapedTextStyle(font: devFont, fallbackFonts: [robotoFont], fontSize: 8.5, color: PdfColors.grey200);
      final badgeStyle = ShapedTextStyle(font: devBoldFont, fallbackFonts: [robotoFont], fontSize: 7.5, color: PdfColors.white);

      final reportTitleStyle = ShapedTextStyle(font: devBoldFont, fallbackFonts: [robotoFont], fontSize: 12, color: PdfColor.fromHex('#1E3A8A'));
      final metaStyle = ShapedTextStyle(font: devFont, fallbackFonts: [robotoFont], fontSize: 8.5, color: PdfColors.grey700);
      final dateStyle = ShapedTextStyle(font: devBoldFont, fallbackFonts: [robotoFont], fontSize: 8.5, color: PdfColor.fromHex('#047857'));

      final kpiLabelStyle = ShapedTextStyle(font: devFont, fallbackFonts: [robotoFont], fontSize: 7.5, color: PdfColors.grey700);
      final kpiValueStyle = ShapedTextStyle(font: devBoldFont, fallbackFonts: [robotoFont], fontSize: 10, color: PdfColor.fromHex('#1E3A8A'));

      final tableHeaderStyle = ShapedTextStyle(font: devBoldFont, fallbackFonts: [robotoFont], fontSize: 8, color: PdfColors.white);
      final tableCellStyle = ShapedTextStyle(font: devFont, fallbackFonts: [robotoFont], fontSize: 7.5, color: PdfColors.black);
      final tableCellBoldStyle = ShapedTextStyle(font: devBoldFont, fallbackFonts: [robotoFont], fontSize: 7.5, color: PdfColor.fromHex('#1E3A8A'));

      final sigTitleStyle = ShapedTextStyle(font: devBoldFont, fallbackFonts: [robotoFont], fontSize: 8.5, color: PdfColors.black);
      final sigSubStyle = ShapedTextStyle(font: devFont, fallbackFonts: [robotoFont], fontSize: 7, color: PdfColors.grey600);

      final footerStyle = ShapedTextStyle(font: devFont, fallbackFonts: [robotoFont], fontSize: 7.5, color: PdfColors.grey600);
      final footerBoldStyle = ShapedTextStyle(font: devBoldFont, fallbackFonts: [robotoFont], fontSize: 8, color: PdfColors.grey800);

      // Safe Logo Image handling
      pw.MemoryImage? safeLogoImage;
      if (logoBytes != null && logoBytes.isNotEmpty) {
        try {
          safeLogoImage = pw.MemoryImage(logoBytes);
        } catch (e) {
          debugPrint('PDF Logo memory image note: $e');
          safeLogoImage = null;
        }
      }

      // Column widths and alignments
      final Map<int, pw.TableColumnWidth> columnWidths = {};
      final Map<int, pw.Alignment> cellAlignments = {};
      final Map<int, ShapedTextAlign> shapedAlignments = {};

      for (int i = 0; i < report.columns.length; i++) {
        final col = report.columns[i];
        final key = col.key.toLowerCase();

        if (key.contains('sr') || key.contains('index') || key == 'id') {
          columnWidths[i] = const pw.FlexColumnWidth(0.7);
        } else if (key.contains('code')) {
          columnWidths[i] = const pw.FlexColumnWidth(1.0);
        } else if (key.contains('name') || key.contains('title') || key.contains('description') || key.contains('purpose')) {
          columnWidths[i] = const pw.FlexColumnWidth(2.2);
        } else if (key.contains('mobile') || key.contains('phone')) {
          columnWidths[i] = const pw.FlexColumnWidth(1.3);
        } else if (col.isCurrency || col.isNumeric) {
          columnWidths[i] = const pw.FlexColumnWidth(1.3);
        } else if (key.contains('date')) {
          columnWidths[i] = const pw.FlexColumnWidth(1.2);
        } else {
          columnWidths[i] = const pw.FlexColumnWidth(1.2);
        }

        if (col.isCurrency || col.isNumeric) {
          cellAlignments[i] = pw.Alignment.centerRight;
          shapedAlignments[i] = ShapedTextAlign.end;
        } else if (key.contains('date') || key.contains('status') || key.contains('code') || key.contains('type')) {
          cellAlignments[i] = pw.Alignment.center;
          shapedAlignments[i] = ShapedTextAlign.center;
        } else {
          cellAlignments[i] = pw.Alignment.centerLeft;
          shapedAlignments[i] = ShapedTextAlign.start;
        }
      }

      // Build data rows and calculate totals
      final List<List<String>> dataRows = [];
      final Map<String, double> numericTotals = {};

      for (var col in report.columns) {
        if (col.isCurrency || col.isNumeric) {
          numericTotals[col.key] = 0.0;
        }
      }

      for (var row in records) {
        final List<String> rowCells = [];
        for (var col in report.columns) {
          final val = row[col.key];
          final isDate = col.key.toLowerCase().contains('date') || col.key.toLowerCase().contains('created_at');
          final cellStr = formatCellValue(val, isCurrency: col.isCurrency, isNumeric: col.isNumeric, isDate: isDate);

          if (val != null) {
            if (col.isCurrency || col.isNumeric) {
              final numVal = double.tryParse(val.toString()) ?? 0.0;
              numericTotals[col.key] = (numericTotals[col.key] ?? 0.0) + numVal;
            }
          }
          rowCells.add(cellStr);
        }
        dataRows.add(rowCells);
      }

      // Prepare Total Row
      final List<String> totalRow = [];
      if (dataRows.isNotEmpty && numericTotals.isNotEmpty) {
        for (int i = 0; i < report.columns.length; i++) {
          final col = report.columns[i];
          if (i == 0) {
            totalRow.add('एकूण (Total)');
          } else if (numericTotals.containsKey(col.key)) {
            if (col.isCurrency) {
              totalRow.add(_currencyFormat.format(numericTotals[col.key] ?? 0.0));
            } else {
              totalRow.add((numericTotals[col.key] ?? 0.0).toStringAsFixed(0));
            }
          } else {
            totalRow.add('');
          }
        }
      }

      // Prepare KPI metric cards
      final List<MapEntry<String, String>> kpiList = [];
      kpiList.add(MapEntry('एकूण नोंदी (Total Records)', '${records.length}'));
      if (summaryKpis != null && summaryKpis.isNotEmpty) {
        summaryKpis.forEach((k, v) {
          if (v is double || v is int) {
            kpiList.add(MapEntry(k, _currencyFormat.format(v)));
          } else {
            kpiList.add(MapEntry(k, v.toString()));
          }
        });
      } else {
        int added = 0;
        for (var col in report.columns) {
          if (numericTotals.containsKey(col.key) && added < 2) {
            final isCurr = col.isCurrency;
            final totalVal = numericTotals[col.key] ?? 0.0;
            final formatted = isCurr ? _currencyFormat.format(totalVal) : totalVal.toStringAsFixed(0);
            kpiList.add(MapEntry('एकूण ${col.labelMr}', formatted));
            added++;
          }
        }
      }

      // Construct MultiPage Document
      doc.addPage(
        pw.MultiPage(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.all(24),
          header: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Top Branded Header Bar
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#1E3A8A'),
                    borderRadius: pw.BorderRadius.circular(6),
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
                              width: 42,
                              height: 42,
                              margin: const pw.EdgeInsets.only(right: 10),
                              decoration: pw.BoxDecoration(
                                shape: pw.BoxShape.circle,
                                color: PdfColors.white,
                                border: pw.Border.all(color: PdfColor.fromHex('#D97706'), width: 1.5),
                              ),
                              child: pw.ClipOval(
                                child: pw.Image(
                                  safeLogoImage,
                                  width: 42,
                                  height: 42,
                                  fit: pw.BoxFit.cover,
                                ),
                              ),
                            )
                          else
                            pw.Container(
                              width: 42,
                              height: 42,
                              margin: const pw.EdgeInsets.only(right: 10),
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
                                    fontSize: 18,
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
                                _cleanText(groupName.toUpperCase(), allFonts),
                                style: titleStyle,
                              ),
                              pw.SizedBox(height: 2),
                              ShapedText(
                                _cleanText('${groupAddress ?? "पत्ता: महाराष्ट्र"} | नोंदणी क्र: ${registrationNumber ?? "SBG-REG-2024"}', allFonts),
                                style: subTitleStyle,
                              ),
                            ],
                          ),
                        ],
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromHex('#D97706'),
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: ShapedText(
                          _cleanText('अधिकृत अहवाल (OFFICIAL)', allFonts),
                          style: badgeStyle,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 8),

                // Report Title & Period Banner
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        ShapedText(
                          _cleanText('${report.titleMr} (${report.titleEn})', allFonts),
                          style: reportTitleStyle,
                        ),
                        pw.SizedBox(height: 1),
                        ShapedText(
                          _cleanText('वर्गवारी: ${report.category.titleMr}', allFonts),
                          style: metaStyle,
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        ShapedText(
                          _cleanText('कालावधी: ${_dateFormat.format(fromDate)} ते ${_dateFormat.format(toDate)}', allFonts),
                          style: dateStyle,
                        ),
                        pw.SizedBox(height: 1),
                        ShapedText(
                          _cleanText('तयार दिनांक: ${_dateTimeFormat.format(DateTime.now())}', allFonts),
                          style: metaStyle,
                        ),
                      ],
                    ),
                  ],
                ),
                pw.Divider(thickness: 1, color: PdfColor.fromHex('#CBD5E1')),
                pw.SizedBox(height: 6),
              ],
            );
          },
          footer: (pw.Context context) {
            return pw.Container(
              padding: const pw.EdgeInsets.only(top: 8),
              decoration: const pw.BoxDecoration(
                border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.8)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  ShapedText(
                    _cleanText('सखी महिला बचत गट व्यवस्थापन प्रणाली (Sakhi Bachat Gat System)', allFonts),
                    style: footerStyle,
                  ),
                  ShapedText(
                    _cleanText('पृष्ठ ${context.pageNumber} पैकी ${context.pagesCount}', allFonts),
                    style: footerBoldStyle,
                  ),
                ],
              ),
            );
          },
          build: (pw.Context context) => [
            // KPI Summary Cards
            if (kpiList.isNotEmpty) ...[
              pw.Row(
                children: kpiList.take(4).map((kpi) {
                  return pw.Expanded(
                    child: pw.Container(
                      margin: const pw.EdgeInsets.only(right: 6, bottom: 8),
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('#F1F5F9'),
                        borderRadius: pw.BorderRadius.circular(6),
                        border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          ShapedText(
                            _cleanText(kpi.key, allFonts),
                            style: kpiLabelStyle,
                            maxLines: 1,
                          ),
                          pw.SizedBox(height: 2),
                          ShapedText(
                            _cleanText(kpi.value, allFonts),
                            style: kpiValueStyle,
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              pw.SizedBox(height: 4),
            ],

            // Data Table
            if (records.isEmpty)
              pw.Container(
                padding: const pw.EdgeInsets.all(30),
                alignment: pw.Alignment.center,
                child: ShapedText(
                  _cleanText('निवडलेल्या कालावधीमध्ये कोणतीही नोंद आढळली नाही. (No records found)', allFonts),
                  style: metaStyle,
                ),
              )
            else
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                columnWidths: columnWidths,
                children: [
                  // Table Header
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColor.fromHex('#1E3A8A')),
                    children: [
                      for (int i = 0; i < report.columns.length; i++)
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                          alignment: cellAlignments[i],
                          child: ShapedText(
                            _cleanText(report.columns[i].labelMr, allFonts),
                            style: tableHeaderStyle.copyWith(align: shapedAlignments[i]),
                          ),
                        ),
                    ],
                  ),

                  // Data Rows
                  for (int r = 0; r < dataRows.length; r++)
                    pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: r % 2 == 1 ? PdfColor.fromHex('#F8FAFC') : PdfColors.white,
                      ),
                      children: [
                        for (int c = 0; c < dataRows[r].length; c++)
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                            alignment: cellAlignments[c],
                            child: ShapedText(
                              _cleanText(dataRows[r][c], allFonts),
                              style: tableCellStyle.copyWith(align: shapedAlignments[c]),
                            ),
                          ),
                      ],
                    ),

                  // Total Row
                  if (totalRow.isNotEmpty)
                    pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('#EEF2FF'),
                        border: pw.Border(top: pw.BorderSide(color: PdfColor.fromHex('#1E3A8A'), width: 1)),
                      ),
                      children: [
                        for (int c = 0; c < totalRow.length; c++)
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                            alignment: cellAlignments[c],
                            child: ShapedText(
                              _cleanText(totalRow[c], allFonts),
                              style: tableCellBoldStyle.copyWith(align: shapedAlignments[c]),
                            ),
                          ),
                      ],
                    ),
                ],
              ),

            pw.SizedBox(height: 25),

            // 3 Official Signatures Block
            pw.Container(
              padding: const pw.EdgeInsets.only(top: 15),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  // 1. Secretary
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Container(width: 130, height: 1, color: PdfColors.grey600),
                      pw.SizedBox(height: 4),
                      ShapedText(_cleanText('तयार करणार (सचिव)', allFonts), style: sigTitleStyle),
                      ShapedText(_cleanText('Prepared By (Secretary)', allFonts), style: sigSubStyle),
                    ],
                  ),
                  // 2. Treasurer
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Container(width: 130, height: 1, color: PdfColors.grey600),
                      pw.SizedBox(height: 4),
                      ShapedText(_cleanText('खजिनदार स्वाक्षरी', allFonts), style: sigTitleStyle),
                      ShapedText(_cleanText('Treasurer Sign', allFonts), style: sigSubStyle),
                    ],
                  ),
                  // 3. President
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Container(width: 130, height: 1, color: PdfColors.grey600),
                      pw.SizedBox(height: 4),
                      ShapedText(_cleanText('मंजूर करणार (अध्यक्ष)', allFonts), style: sigTitleStyle),
                      ShapedText(_cleanText('Approved By (President)', allFonts), style: sigSubStyle),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );

      return await doc.save();
    } finally {
      devFont.dispose();
      devBoldFont.dispose();
      robotoFont.dispose();
    }
  }

  /// Direct print or preview report
  static Future<void> printOrPreviewReport({
    required ReportDefinition report,
    required List<Map<String, dynamic>> records,
    required DateTime fromDate,
    required DateTime toDate,
    String groupName = 'सखी महिला बचत गट',
    String? groupAddress,
    String? registrationNumber,
    Uint8List? logoBytes,
    Map<String, dynamic>? summaryKpis,
  }) async {
    final pdfBytes = await generateReportPdf(
      report: report,
      records: records,
      fromDate: fromDate,
      toDate: toDate,
      groupName: groupName,
      groupAddress: groupAddress,
      registrationNumber: registrationNumber,
      logoBytes: logoBytes,
      summaryKpis: summaryKpis,
    );

    final filename = '${report.id}_${DateFormat("yyyyMMdd").format(fromDate)}_${DateFormat("yyyyMMdd").format(toDate)}.pdf';

    await Printing.layoutPdf(
      onLayout: (format) async => pdfBytes,
      name: filename,
    );
  }

  /// Share report PDF
  static Future<void> shareReport({
    required ReportDefinition report,
    required List<Map<String, dynamic>> records,
    required DateTime fromDate,
    required DateTime toDate,
    String groupName = 'सखी महिला बचत गट',
    String? groupAddress,
    String? registrationNumber,
    Uint8List? logoBytes,
    Map<String, dynamic>? summaryKpis,
  }) async {
    final pdfBytes = await generateReportPdf(
      report: report,
      records: records,
      fromDate: fromDate,
      toDate: toDate,
      groupName: groupName,
      groupAddress: groupAddress,
      registrationNumber: registrationNumber,
      logoBytes: logoBytes,
      summaryKpis: summaryKpis,
    );

    final filename = '${report.id}_${DateFormat("yyyyMMdd").format(fromDate)}_${DateFormat("yyyyMMdd").format(toDate)}.pdf';

    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: filename,
    );
  }
}
