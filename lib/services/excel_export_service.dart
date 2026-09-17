import 'dart:convert';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../models/report_model.dart';
import '../models/monthly_bachatgat_report_model.dart';

class ExcelExportService {
  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  static final DateFormat _fileDateFormat = DateFormat('yyyyMMdd');

  /// Escapes CSV values conforming to RFC 4180
  static String _escapeCsvValue(dynamic val) {
    if (val == null) return '""';
    String str = val.toString();
    if (str.contains(',') || str.contains('"') || str.contains('\n') || str.contains('\r')) {
      final escaped = str.replaceAll('"', '""');
      str = '"$escaped"';
    }
    return str;
  }

  /// Generates UTF-8 BOM CSV bytes readable directly by Microsoft Excel, Google Sheets & LibreOffice
  static Uint8List generateExcelCsvBytes({
    required ReportDefinition report,
    required List<Map<String, dynamic>> records,
    required DateTime fromDate,
    required DateTime toDate,
    String groupName = 'सखी महिला बचत गट',
  }) {
    final StringBuffer buffer = StringBuffer();

    // 1. Title & Metadata Header
    buffer.writeln(_escapeCsvValue(groupName.toUpperCase()));
    buffer.writeln(_escapeCsvValue("${report.titleMr} (${report.titleEn})"));
    buffer.writeln(_escapeCsvValue("अहवाल कालावधी: ${_dateFormat.format(fromDate)} ते ${_dateFormat.format(toDate)}"));
    buffer.writeln(_escapeCsvValue("तयार दिनांक: ${_dateFormat.format(DateTime.now())}"));
    buffer.writeln(); // Empty line

    // 2. Column Headers
    final headerRow = report.columns.map((c) => _escapeCsvValue(c.labelMr)).join(',');
    buffer.writeln(headerRow);

    // 3. Data Rows
    final Map<String, double> numericTotals = {};
    for (var col in report.columns) {
      if (col.isCurrency || col.isNumeric) {
        numericTotals[col.key] = 0.0;
      }
    }

    for (var row in records) {
      final List<String> cellValues = [];
      for (var col in report.columns) {
        final val = row[col.key];
        if (val != null) {
          if (col.isCurrency) {
            final numVal = double.tryParse(val.toString()) ?? 0.0;
            numericTotals[col.key] = (numericTotals[col.key] ?? 0.0) + numVal;
            cellValues.add(_escapeCsvValue(numVal.toStringAsFixed(2)));
          } else if (col.isNumeric) {
            final numVal = double.tryParse(val.toString()) ?? 0.0;
            numericTotals[col.key] = (numericTotals[col.key] ?? 0.0) + numVal;
            cellValues.add(_escapeCsvValue(numVal.toStringAsFixed(0)));
          } else if (col.key.toLowerCase().contains('date') || col.key.toLowerCase().contains('created_at')) {
            try {
              final parsed = DateTime.parse(val.toString());
              cellValues.add(_escapeCsvValue(_dateFormat.format(parsed)));
            } catch (_) {
              cellValues.add(_escapeCsvValue(val.toString()));
            }
          } else {
            cellValues.add(_escapeCsvValue(val.toString()));
          }
        } else {
          cellValues.add('""');
        }
      }
      buffer.writeln(cellValues.join(','));
    }

    // 4. Totals Row
    if (records.isNotEmpty && numericTotals.isNotEmpty) {
      final List<String> totalCells = [];
      for (int i = 0; i < report.columns.length; i++) {
        final col = report.columns[i];
        if (i == 0) {
          totalCells.add(_escapeCsvValue('एकूण (Total)'));
        } else if (numericTotals.containsKey(col.key)) {
          final totalVal = numericTotals[col.key] ?? 0.0;
          totalCells.add(_escapeCsvValue(col.isCurrency ? totalVal.toStringAsFixed(2) : totalVal.toStringAsFixed(0)));
        } else {
          totalCells.add('""');
        }
      }
      buffer.writeln(totalCells.join(','));
    }

    buffer.writeln(); // Empty line

    // 5. Official Signature Footers
    buffer.writeln('${_escapeCsvValue("तयार करणार (सचिव)")},,,${_escapeCsvValue("खजिनदार स्वाक्षरी")},,,${_escapeCsvValue("मंजूर करणार (अध्यक्ष)")}');

    // Convert string to UTF-8 bytes with BOM prefix (0xEF, 0xBB, 0xBF)
    final utf8Bytes = utf8.encode(buffer.toString());
    final bomBytes = Uint8List(3 + utf8Bytes.length);
    bomBytes[0] = 0xEF;
    bomBytes[1] = 0xBB;
    bomBytes[2] = 0xBF;
    bomBytes.setRange(3, bomBytes.length, utf8Bytes);

    return bomBytes;
  }

  /// Exports and triggers file sharing / saving for Excel
  static Future<void> exportAndShareExcel({
    required ReportDefinition report,
    required List<Map<String, dynamic>> records,
    required DateTime fromDate,
    required DateTime toDate,
    String groupName = 'सखी महिला बचत गट',
  }) async {
    final csvBytes = generateExcelCsvBytes(
      report: report,
      records: records,
      fromDate: fromDate,
      toDate: toDate,
      groupName: groupName,
    );

    final filename = '${report.id}_${_fileDateFormat.format(fromDate)}_${_fileDateFormat.format(toDate)}.csv';

    await Printing.sharePdf(
      bytes: csvBytes,
      filename: filename,
    );
  }

  /// Generates specialized UTF-8 BOM CSV bytes for the Monthly Bachatgat Report matching reference image
  static Uint8List generateMonthlyBachatgatExcelBytes(MonthlyBachatgatReportData data) {
    final StringBuffer buffer = StringBuffer();

    // 1. Header Banner
    buffer.writeln(_escapeCsvValue("बचत महिना : ${data.monthNameMr} ${data.year}"));
    buffer.writeln(_escapeCsvValue("गटाचे नाव: ${data.groupName}"));
    buffer.writeln(_escapeCsvValue("तयार दिनांक: ${_dateFormat.format(DateTime.now())}"));
    buffer.writeln(); // Blank line

    // 2. Column Headers (10 Columns)
    final headers = [
      'अ. नं',
      'सभासदाचे नाव',
      'कर्ज आजअखेर',
      'दिलेले कर्ज',
      'महिना बचत',
      'एकूण बचत आजअखेर',
      'हप्ता',
      'व्याज',
      'आजची एकूण',
      'या महिन्यात अखेर शिल्लक कर्ज',
    ];
    buffer.writeln(headers.map((h) => _escapeCsvValue(h)).join(','));

    // 3. Rows
    for (var row in data.rows) {
      final cells = [
        _escapeCsvValue(row.srNo.toString()),
        _escapeCsvValue(row.memberName),
        _escapeCsvValue(row.openingLoan.round().toString()),
        _escapeCsvValue(row.newLoan > 0 ? row.newLoan.round().toString() : ''),
        _escapeCsvValue(row.monthlySaving.round().toString()),
        _escapeCsvValue(row.cumulativeSavings.round().toString()),
        _escapeCsvValue(row.installment.round().toString()),
        _escapeCsvValue(row.interest.round().toString()),
        _escapeCsvValue(row.todayTotal.round().toString()),
        _escapeCsvValue(row.closingLoan.round().toString()),
      ];
      buffer.writeln(cells.join(','));
    }

    // 4. Totals Row
    final totalCells = [
      _escapeCsvValue(''),
      _escapeCsvValue('एकूण जमा:'),
      _escapeCsvValue(data.totalOpeningLoan.round().toString()),
      _escapeCsvValue(data.totalNewLoan > 0 ? data.totalNewLoan.round().toString() : ''),
      _escapeCsvValue(data.totalMonthlySaving.round().toString()),
      _escapeCsvValue(data.totalCumulativeSavings.round().toString()),
      _escapeCsvValue(data.totalInstallment.round().toString()),
      _escapeCsvValue(data.totalInterest.round().toString()),
      _escapeCsvValue(data.totalTodayTotal.round().toString()),
      _escapeCsvValue(data.totalClosingLoan.round().toString()),
    ];
    buffer.writeln(totalCells.join(','));
    buffer.writeln(); // Blank line

    // 5. Dynamic Footer Borrower Note
    if (data.newBorrowers.isNotEmpty) {
      final namesAndAmts = data.newBorrowers.map((b) => '${b.memberName} ${b.amount.round()}₹').join(' , ');
      buffer.writeln(_escapeCsvValue('कर्जदार: $namesAndAmts'));
    } else {
      buffer.writeln(_escapeCsvValue('कर्जदार: या महिन्यात कोणतेही नवीन कर्ज वाटप नाही'));
    }

    // UTF-8 BOM encoding for perfect Excel rendering
    final utf8Bytes = utf8.encode(buffer.toString());
    final bomBytes = Uint8List(3 + utf8Bytes.length);
    bomBytes[0] = 0xEF;
    bomBytes[1] = 0xBB;
    bomBytes[2] = 0xBF;
    bomBytes.setRange(3, bomBytes.length, utf8Bytes);

    return bomBytes;
  }

  /// Exports and shares Monthly Bachatgat Excel file
  static Future<void> exportMonthlyBachatgatExcel(MonthlyBachatgatReportData data) async {
    final csvBytes = generateMonthlyBachatgatExcelBytes(data);
    final filename = 'मासिक_बचत_अहवाल_${data.monthNameMr}_${data.year}.csv';

    await Printing.sharePdf(
      bytes: csvBytes,
      filename: filename,
    );
  }
}
