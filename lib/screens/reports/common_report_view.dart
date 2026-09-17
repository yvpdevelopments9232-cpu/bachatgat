import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/utils/image_helper.dart';
import '../../models/report_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../services/bachat_gat_pdf_template.dart';
import '../../services/excel_export_service.dart';
import '../../widgets/reports/report_date_filter.dart';
import '../../widgets/desktop_wrapper.dart';

class CommonReportView extends StatefulWidget {
  final ReportDefinition report;

  const CommonReportView({
    super.key,
    required this.report,
  });

  @override
  State<CommonReportView> createState() => _CommonReportViewState();
}

class _CommonReportViewState extends State<CommonReportView> {
  final SupabaseService _supabaseService = SupabaseService();
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ');

  late DateTime _fromDate;
  late DateTime _toDate;

  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _rawRecords = [];
  List<Map<String, dynamic>> _filteredRecords = [];
  Map<String, String> _memberNames = {};
  Map<String, String> _memberCodes = {};
  Map<String, String> _memberMobiles = {};
  Map<String, Map<String, dynamic>> _loansMap = {};
  List<Map<String, dynamic>> _bankAccounts = [];
  String _selectedBankAccountId = 'all';

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _fromDate = DateTime(now.year, 1, 1);
    _toDate = DateTime(now.year, 12, 31);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final groupId = auth.currentGroup?.id;

      if (groupId == null || groupId.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'कृपया प्रथम बचत गट निवडा (Please select a Bachat Gat)';
        });
        return;
      }

      // 1. Fetch Member Lookup Map
      try {
        final memRes = await _supabaseService.client
            .from('members')
            .select('id, full_name, member_code, mobile_number')
            .eq('group_id', groupId);
        final Map<String, String> mNames = {};
        final Map<String, String> mCodes = {};
        final Map<String, String> mMobiles = {};
        for (var m in (memRes as List)) {
          final id = m['id']?.toString() ?? '';
          if (id.isNotEmpty) {
            mNames[id] = m['full_name']?.toString() ?? '';
            mCodes[id] = m['member_code']?.toString() ?? '';
            mMobiles[id] = m['mobile_number']?.toString() ?? '';
          }
        }
        _memberNames = mNames;
        _memberCodes = mCodes;
        _memberMobiles = mMobiles;
      } catch (e) {
        debugPrint('Member lookup note: $e');
      }

      // 2. Fetch Loans Lookup Map (for mapping loan_id to borrower in loan_emis)
      try {
        final loanRes = await _supabaseService.client
            .from('loans')
            .select('id, member_id, loan_code, approved_amount, outstanding_principal')
            .eq('group_id', groupId);
        final Map<String, Map<String, dynamic>> lMap = {};
        for (var l in (loanRes as List)) {
          final id = l['id']?.toString() ?? '';
          if (id.isNotEmpty) {
            final mId = l['member_id']?.toString() ?? '';
            lMap[id] = {
              'member_id': mId,
              'loan_code': l['loan_code']?.toString() ?? '',
              'borrower_name': _memberNames[mId] ?? 'कर्जदार',
              'approved_amount': l['approved_amount'],
              'outstanding_principal': l['outstanding_principal'],
            };
          }
        }
        _loansMap = lMap;
      } catch (e) {
        debugPrint('Loans lookup note: $e');
      }

      // 3. Fetch Bank Accounts Lookup Map (for bank_transactions filter & display)
      if (widget.report.id == 'bank_transactions') {
        try {
          final bankRes = await _supabaseService.client
              .from('bank_accounts')
              .select('id, bank_name, account_number, branch, current_balance, status')
              .eq('group_id', groupId);
          _bankAccounts = (bankRes as List)
              .map((b) => Map<String, dynamic>.from(b as Map))
              .toList();
        } catch (e) {
          debugPrint('Bank accounts lookup error: $e');
        }
      }

      final startDayStr = _fromDate.toIso8601String().split('T').first;
      final endDayStr = _toDate.toIso8601String().split('T').first;
      final startDateStr = startDayStr;
      final endDateStr = '$endDayStr\uffff';

      List<Map<String, dynamic>> enriched = [];

      // --- SPECIAL REPORT HANDLERS (AGGREGATION & PORTFOLIO REPORTS) ---

      if (widget.report.id == 'savings_collection') {
        final res = await _supabaseService.client
            .from('savings')
            .select()
            .eq('group_id', groupId);
        final Map<String, List<double>> modeGroups = {};
        double grandTotal = 0.0;
        for (var row in (res as List)) {
          final mode = row['payment_mode']?.toString() ?? 'रोख (Cash)';
          final amt = ((row['amount'] ?? 0) as num).toDouble();
          modeGroups.putIfAbsent(mode, () => []).add(amt);
          grandTotal += amt;
        }

        modeGroups.forEach((mode, amounts) {
          final totalMode = amounts.fold<double>(0.0, (sum, a) => sum + a);
          final pct = grandTotal > 0 ? (totalMode / grandTotal * 100).toStringAsFixed(1) : '0';
          enriched.add({
            'payment_mode': mode,
            'transactions_count': amounts.length,
            'total_collected': totalMode,
            'share_percentage': '$pct%',
          });
        });
      } else if (widget.report.id == 'annual_savings') {
        final res = await _supabaseService.client
            .from('savings')
            .select()
            .eq('group_id', groupId);
        final Map<String, double> monthGroups = {};
        for (var row in (res as List)) {
          final dateStr = row['savings_date']?.toString() ?? row['created_at']?.toString() ?? '';
          String monthKey = 'या महिन्याची बचत';
          if (dateStr.isNotEmpty) {
            try {
              final d = DateTime.parse(dateStr);
              monthKey = DateFormat('MMMM yyyy').format(d);
            } catch (_) {}
          }
          final amt = ((row['amount'] ?? 0) as num).toDouble();
          monthGroups[monthKey] = (monthGroups[monthKey] ?? 0.0) + amt;
        }

        monthGroups.forEach((mName, collected) {
          final expected = (_memberNames.length * 200.0) > 0 ? (_memberNames.length * 200.0) : collected;
          final pending = (expected - collected) > 0 ? (expected - collected) : 0.0;
          final rate = expected > 0 ? (collected / expected * 100).clamp(0, 100).toStringAsFixed(1) : '100';
          enriched.add({
            'month_name': mName,
            'expected': expected,
            'collected': collected,
            'pending': pending,
            'rate': '$rate%',
          });
        });
      } else if (widget.report.id == 'pending_savings') {
        final res = await _supabaseService.client
            .from('monthly_savings')
            .select()
            .eq('group_id', groupId)
            .eq('status', 'pending');
        for (var row in (res as List)) {
          final mId = row['member_id']?.toString() ?? '';
          enriched.add({
            'member_code': _memberCodes[mId] ?? '-',
            'member_name': _memberNames[mId] ?? 'सदस्य',
            'mobile': _memberMobiles[mId] ?? '-',
            'pending_months': 1,
            'pending_amount': ((row['balance_amount'] ?? row['expected_amount'] ?? 200.0) as num).toDouble(),
          });
        }
      } else if (widget.report.id == 'loan_summary') {
        final res = await _supabaseService.client
            .from('loans')
            .select()
            .eq('group_id', groupId);
        double totalSanctioned = 0.0;
        double totalRepaid = 0.0;
        double totalOutstanding = 0.0;
        int activeCount = 0;
        int settledCount = 0;

        for (var row in (res as List)) {
          final status = row['status']?.toString().toLowerCase() ?? '';
          final sanctioned = ((row['approved_amount'] ?? 0) as num).toDouble();
          final repaid = ((row['total_repaid'] ?? 0) as num).toDouble();
          final out = ((row['outstanding_principal'] ?? sanctioned) as num).toDouble();

          totalSanctioned += sanctioned;
          totalRepaid += repaid;
          if (status == 'active' || status == 'disbursed' || status == 'approved') {
            activeCount++;
            totalOutstanding += out;
          } else if (status == 'closed' || status == 'completed') {
            settledCount++;
          }
        }

        enriched.add({'metric_name': '१. एकूण मंजूर व वाटप कर्जे (Total Sanctioned)', 'count': res.length, 'amount': totalSanctioned});
        enriched.add({'metric_name': '२. चालू सक्रिय कर्जे (Active Running Loans)', 'count': activeCount, 'amount': totalOutstanding});
        enriched.add({'metric_name': '३. पूर्ण परतफेड झालेली कर्जे (Settled Loans)', 'count': settledCount, 'amount': totalRepaid});
        enriched.add({'metric_name': '४. एकूण वसूल झालेली मुद्दल (Total Repaid)', 'count': res.length, 'amount': totalRepaid});
        enriched.add({'metric_name': '५. चालू शिल्लक कर्ज मुद्दल (Current Portfolio)', 'count': activeCount, 'amount': totalOutstanding});
      } else if (widget.report.id == 'profit_loss') {
        final incRes = await _supabaseService.client.from('incomes').select().eq('group_id', groupId);
        final expRes = await _supabaseService.client.from('expenses').select().eq('group_id', groupId);

        double totalIncome = 0.0;
        for (var r in (incRes as List)) {
          totalIncome += ((r['amount'] ?? 0) as num).toDouble();
        }

        double totalExpense = 0.0;
        for (var r in (expRes as List)) {
          totalExpense += ((r['amount'] ?? 0) as num).toDouble();
        }

        final netProfit = (totalIncome - totalExpense);

        enriched.add({'particulars': '१. एकूण जमा उत्पन्न (कर्ज व्याज, वर्गणी, दंड)', 'amount': totalIncome, 'notes': 'गटाचे एकूण आवक उत्पन्न'});
        enriched.add({'particulars': '२. वजा: एकूण प्रशासकीय व इतर खर्च (Expenses)', 'amount': totalExpense, 'notes': 'स्टेशनरी, प्रवास, मेळावे खर्च'});
        enriched.add({
          'particulars': '३. निव्वळ वाटपयोग्य नफा (Net Profit)',
          'amount': netProfit > 0 ? netProfit : 0.0,
          'notes': netProfit >= 0 ? 'सभासदांमध्ये लाभांश वाटपासाठी उपलब्ध' : 'तोटा',
        });
      } else if (widget.report.id == 'monthly_management') {
        final mCount = _memberNames.length;
        final savRes = await _supabaseService.client.from('savings').select('amount').eq('group_id', groupId);
        final double totalSav = (savRes as List).fold<double>(0.0, (sum, r) => sum + ((r['amount'] ?? 0) as num).toDouble());

        final loanRes = await _supabaseService.client.from('loans').select('approved_amount').eq('group_id', groupId);
        final double totalLoans = (loanRes as List).fold<double>(0.0, (sum, r) => sum + ((r['approved_amount'] ?? 0) as num).toDouble());

        final emiRes = await _supabaseService.client.from('loan_emis').select('paid_amount').eq('group_id', groupId).eq('status', 'paid');
        final double totalEmi = (emiRes as List).fold<double>(0.0, (sum, r) => sum + ((r['paid_amount'] ?? 0) as num).toDouble());

        final bankRes = await _supabaseService.client.from('bank_accounts').select('current_balance').eq('group_id', groupId);
        final double totalBank = (bankRes as List).fold<double>(0.0, (sum, r) => sum + ((r['current_balance'] ?? 0) as num).toDouble());

        final cashRes = await _supabaseService.client.from('cash_book').select('balance_after').eq('group_id', groupId).order('entry_date', ascending: false).limit(1);
        final double cashInHand = cashRes.isNotEmpty ? ((cashRes.first['balance_after'] ?? 0) as num).toDouble() : 0.0;

        enriched.add({'metric': '१. नोंदणीकृत सभासद संख्या', 'count': mCount, 'amount': 0.0, 'status': 'सक्रिय गट'});
        enriched.add({'metric': '२. संकलित एकूण मासिक बचत', 'count': savRes.length, 'amount': totalSav, 'status': 'नियमित भरणा'});
        enriched.add({'metric': '३. एकूण मंजूर व वाटप कर्जे', 'count': loanRes.length, 'amount': totalLoans, 'status': 'अंतर्गत कर्ज'});
        enriched.add({'metric': '४. हप्ता व व्याज वसुली भरणा', 'count': emiRes.length, 'amount': totalEmi, 'status': 'वसूल'});
        enriched.add({'metric': '५. बँक खात्यांमधील शिल्लक', 'count': bankRes.length, 'amount': totalBank, 'status': 'सुरक्षित बँक'});
        enriched.add({'metric': '६. हातातील रोकड शिल्लक (Cash In Hand)', 'count': 1, 'amount': cashInHand, 'status': 'दैनिक जमा'});
      } else if (widget.report.id == 'annual_report') {
        final savRes = await _supabaseService.client.from('savings').select('amount').eq('group_id', groupId);
        final double totalSav = (savRes as List).fold<double>(0.0, (sum, r) => sum + ((r['amount'] ?? 0) as num).toDouble());

        final loanRes = await _supabaseService.client.from('loans').select('approved_amount, total_repaid, outstanding_principal').eq('group_id', groupId);
        double loanSanctioned = 0.0;
        double loanOutstanding = 0.0;
        for (var l in (loanRes as List)) {
          loanSanctioned += ((l['approved_amount'] ?? 0) as num).toDouble();
          loanOutstanding += ((l['outstanding_principal'] ?? 0) as num).toDouble();
        }

        final incRes = await _supabaseService.client.from('incomes').select('amount').eq('group_id', groupId);
        final double totalInc = (incRes as List).fold<double>(0.0, (sum, r) => sum + ((r['amount'] ?? 0) as num).toDouble());

        final expRes = await _supabaseService.client.from('expenses').select('amount').eq('group_id', groupId);
        final double totalExp = (expRes as List).fold<double>(0.0, (sum, r) => sum + ((r['amount'] ?? 0) as num).toDouble());

        enriched.add({'section': '१. बचत भांडवल', 'description': 'सभासदांची मासिक बचत जमा निधी', 'opening': 0.0, 'during_year': totalSav, 'closing': totalSav});
        enriched.add({'section': '२. अंतर्गत कर्ज वाटप', 'description': 'सभासदांना उद्योग व गरजेसाठी कर्ज', 'opening': 0.0, 'during_year': loanSanctioned, 'closing': loanOutstanding});
        enriched.add({'section': '३. गट जमा उत्पन्न', 'description': 'कर्ज व्याज, प्रवेश फी व दंड जमा', 'opening': 0.0, 'during_year': totalInc, 'closing': totalInc});
        enriched.add({'section': '४. प्रशासकीय खर्च', 'description': 'स्टेशनरी, प्रवास व इतर खर्च', 'opening': 0.0, 'during_year': totalExp, 'closing': totalExp});
        enriched.add({'section': '५. निव्वळ नफा', 'description': 'वार्षिक वाटपयोग्य निव्वळ शिल्लक नफा', 'opening': 0.0, 'during_year': (totalInc - totalExp) > 0 ? (totalInc - totalExp) : 0.0, 'closing': (totalInc - totalExp) > 0 ? (totalInc - totalExp) : 0.0});
      } else {
        var query = _supabaseService.client
            .from(widget.report.supabaseTable)
            .select()
            .eq('group_id', groupId);

        if (widget.report.id == 'bank_transactions' &&
            _selectedBankAccountId != 'all' &&
            _selectedBankAccountId.isNotEmpty) {
          query = query.eq('bank_account_id', _selectedBankAccountId);
        }

        List<dynamic> response;
        try {
          response = await query
              .gte(widget.report.dateField, startDateStr)
              .lte(widget.report.dateField, endDateStr)
              .order(widget.report.dateField, ascending: false);
        } catch (_) {
          try {
            response = await query.order('created_at', ascending: false);
          } catch (_) {
            response = await query;
          }
        }

        int srCounter = 1;
        double runningLedgerBal = 0.0;

        for (var row in response) {
          final map = Map<String, dynamic>.from(row as Map);
          map['sr_no'] = srCounter++;

          final memberId = map['member_id']?.toString();
          if (memberId != null && memberId.isNotEmpty) {
            map['member_name'] = map['member_name'] ?? _memberNames[memberId] ?? 'सदस्य';
            map['full_name'] = map['full_name'] ?? _memberNames[memberId] ?? 'सदस्य';
            map['member_code'] = map['member_code'] ?? _memberCodes[memberId] ?? '-';
            map['mobile'] = map['mobile'] ?? map['mobile_number'] ?? _memberMobiles[memberId] ?? '-';
          }

          final loanId = map['loan_id']?.toString();
          if (loanId != null && loanId.isNotEmpty && _loansMap.containsKey(loanId)) {
            final lInfo = _loansMap[loanId]!;
            map['borrower_name'] = map['borrower_name'] ?? lInfo['borrower_name'];
            map['loan_code'] = map['loan_code'] ?? lInfo['loan_code'];
            map['member_name'] = map['member_name'] ?? lInfo['borrower_name'];
          }

          if (widget.report.id == 'member_ledger' || widget.report.id == 'member_statement') {
            final amt = ((map['amount'] ?? 0) as num).toDouble();
            runningLedgerBal += amt;
            map['date'] = map['savings_date'] ?? map['created_at'];
            map['particulars'] = map['remarks'] ?? 'नियमित मासिक बचत जमा';
            map['ref_no'] = map['receipt_number'] ?? 'SAV-${map['id']?.toString().substring(0, 4)}';
            map['credit'] = amt;
            map['debit'] = 0.0;
            map['balance'] = runningLedgerBal;
          } else if (widget.report.id == 'member_savings') {
            map['total_months'] = 1;
          } else if (widget.report.id == 'member_attendance') {
            final isAttended = map['attended'] == 1 || map['attended'] == true || map['attended'] == 'true';
            map['attended'] = isAttended ? 1 : 0;
            map['absent'] = isAttended ? 0 : 1;
            map['total_meetings'] = 1;
            map['rate'] = isAttended ? '100%' : '0%';
          } else if (widget.report.id == 'overdue_emi') {
            map['overdue_emis_count'] = 1;
          } else if (widget.report.id == 'bank_transactions') {
            final amt = ((map['amount'] ?? 0) as num).toDouble();
            final type = map['type']?.toString().toLowerCase() ?? '';
            final bankId = map['bank_account_id']?.toString();
            String bankLabel = '';
            if (bankId != null) {
              final b = _bankAccounts.firstWhere((item) => item['id'] == bankId, orElse: () => {});
              if (b.isNotEmpty) {
                final bName = b['bank_name']?.toString() ?? '';
                final accNo = b['account_number']?.toString() ?? '';
                final masked = accNo.length > 4 ? 'XXXX${accNo.substring(accNo.length - 4)}' : accNo;
                bankLabel = ' [$bName $masked]';
              }
            }
            final desc = map['purpose'] ?? map['remarks'] ?? 'बँक व्यवहार';
            map['description'] = (_selectedBankAccountId == 'all' && bankLabel.isNotEmpty) ? '$desc$bankLabel' : desc;
            map['deposit'] = (type == 'deposit') ? amt : 0.0;
            map['withdrawal'] = (type == 'withdrawal') ? amt : 0.0;
            map['balance'] = map['balance_after'] ?? amt;
          } else if (widget.report.id == 'cash_book') {
            final amt = ((map['amount'] ?? 0) as num).toDouble();
            final type = map['type']?.toString().toLowerCase() ?? '';
            final isAdd = type == 'cash_in' || type == 'income' || type == 'receipt' || type.contains('जमा');
            map['cash_in'] = isAdd ? amt : 0.0;
            map['cash_out'] = isAdd ? 0.0 : amt;
          } else if (widget.report.id == 'inventory_stock') {
            map['name'] = map['product_name'] ?? map['name'] ?? '-';
            map['category'] = map['category_name'] ?? map['category'] ?? 'सामान्य';
          } else if (widget.report.id == 'resolutions_report') {
            map['resolution_number'] = 'RES-${(srCounter - 1).toString().padLeft(3, '0')}';
            map['votes_in_favor'] = map['votes_yes'] ?? 0;
            map['votes_against'] = map['votes_no'] ?? 0;
          }

          enriched.add(map);
        }
      }

      _rawRecords = enriched;
      _applySearch();
    } catch (e) {
      debugPrint('Report query error: $e');
      setState(() {
        _errorMessage = 'डेटा लोड करताना त्रुटी आली: $e';
        _isLoading = false;
      });
    }
  }

  void _applySearch() {
    if (_searchQuery.trim().isEmpty) {
      _filteredRecords = List.from(_rawRecords);
    } else {
      final query = _searchQuery.trim().toLowerCase();
      _filteredRecords = _rawRecords.where((row) {
        for (var val in row.values) {
          if (val != null && val.toString().toLowerCase().contains(query)) {
            return true;
          }
        }
        return false;
      }).toList();
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _onFilterApplied(DateTime from, DateTime to) {
    setState(() {
      _fromDate = from;
      _toDate = to;
    });
    _loadData();
  }

  void _onFilterReset() {
    final now = DateTime.now();
    setState(() {
      _fromDate = DateTime(now.year, 1, 1);
      _toDate = DateTime(now.year, 12, 31);
      _selectedBankAccountId = 'all';
    });
    _loadData();
  }

  Future<void> _exportPdf() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final group = auth.currentGroup;

    Uint8List? logoBytes = ImageHelper.getDecodedBytes(group?.logoUrl);
    if (logoBytes == null || logoBytes.isEmpty) {
      logoBytes = ImageHelper.getDecodedBytes(auth.currentProfile?.profilePhotoUrl);
    }

    await BachatGatPdfTemplate.printOrPreviewReport(
      report: widget.report,
      records: _filteredRecords,
      fromDate: _fromDate,
      toDate: _toDate,
      groupName: group?.groupName ?? 'सखी महिला बचत गट',
      groupAddress: group != null ? '${group.village}, ${group.taluka}, ${group.district}' : null,
      registrationNumber: group?.registrationNumber,
      logoBytes: logoBytes,
    );
  }

  Future<void> _sharePdf() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final group = auth.currentGroup;

    Uint8List? logoBytes = ImageHelper.getDecodedBytes(group?.logoUrl);
    if (logoBytes == null || logoBytes.isEmpty) {
      logoBytes = ImageHelper.getDecodedBytes(auth.currentProfile?.profilePhotoUrl);
    }

    await BachatGatPdfTemplate.shareReport(
      report: widget.report,
      records: _filteredRecords,
      fromDate: _fromDate,
      toDate: _toDate,
      groupName: group?.groupName ?? 'सखी महिला बचत गट',
      groupAddress: group != null ? '${group.village}, ${group.taluka}, ${group.district}' : null,
      registrationNumber: group?.registrationNumber,
      logoBytes: logoBytes,
    );
  }

  Future<void> _exportExcel() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final group = auth.currentGroup;

    await ExcelExportService.exportAndShareExcel(
      report: widget.report,
      records: _filteredRecords,
      fromDate: _fromDate,
      toDate: _toDate,
      groupName: group?.groupName ?? 'सखी महिला बचत गट',
    );
  }

  Map<String, double> _calculateTotals() {
    final Map<String, double> totals = {};
    for (var col in widget.report.columns) {
      if (col.isCurrency || col.isNumeric) {
        if (widget.report.id == 'bank_transactions' && col.key == 'balance') {
          if (_selectedBankAccountId != 'all' && _selectedBankAccountId.isNotEmpty) {
            final b = _bankAccounts.firstWhere(
              (item) => item['id'] == _selectedBankAccountId,
              orElse: () => {},
            );
            totals[col.key] = ((b['current_balance'] ?? 0) as num).toDouble();
          } else {
            totals[col.key] = _bankAccounts.fold<double>(
              0.0,
              (sum, b) => sum + ((b['current_balance'] ?? 0) as num).toDouble(),
            );
          }
          continue;
        }

        double sum = 0.0;
        for (var row in _filteredRecords) {
          final val = row[col.key];
          if (val != null) {
            sum += (double.tryParse(val.toString()) ?? 0.0);
          }
        }
        totals[col.key] = sum;
      }
    }
    return totals;
  }

  @override
  Widget build(BuildContext context) {
    final totals = _calculateTotals();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.report.titleMr,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              widget.report.titleEn,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.normal, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded),
            tooltip: 'PDF अहवाल (PDF Preview / Print)',
            onPressed: _filteredRecords.isEmpty ? null : _exportPdf,
          ),
          IconButton(
            icon: const Icon(Icons.table_chart_rounded),
            tooltip: 'Excel एक्सपोर्ट (Excel CSV)',
            onPressed: _filteredRecords.isEmpty ? null : _exportExcel,
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'शेअर करा (Share PDF)',
            onPressed: _filteredRecords.isEmpty ? null : _sharePdf,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: DesktopWrapper(
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ReportDateFilter(
                initialFromDate: _fromDate,
                initialToDate: _toDate,
                onApply: _onFilterApplied,
                onReset: _onFilterReset,
              ),

              if (widget.report.id == 'bank_transactions')
                _buildBankAccountSelector(),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'या अहवालात शोधा (Search records)...',
                            hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                            prefixIcon: const Icon(Icons.search, size: 20, color: Colors.indigo),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchQuery = '';
                                      });
                                      _applySearch();
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 11),
                          ),
                          onChanged: (val) {
                            _searchQuery = val;
                            _applySearch();
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.indigo.shade200),
                      ),
                      child: Text(
                        'नोंदी: ${_filteredRecords.length}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (totals.isNotEmpty && _filteredRecords.isNotEmpty)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.indigo.shade100),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: totals.entries.map((entry) {
                        final col = widget.report.columns.firstWhere(
                          (c) => c.key == entry.key,
                          orElse: () => ReportColumn(key: entry.key, labelMr: entry.key, labelEn: entry.key),
                        );
                        final isCurr = col.isCurrency;
                        final displayVal = isCurr
                            ? _currencyFormat.format(entry.value)
                            : entry.value.toStringAsFixed(0);

                        return Container(
                          margin: const EdgeInsets.only(right: 16),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'एकूण ${col.labelMr}',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                displayVal,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(60.0),
                  child: Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(color: Colors.indigo),
                        SizedBox(height: 16),
                        Text('अहवाल डेटा लोड होत आहे...', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                )
              else if (_errorMessage != null)
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 40),
                      const SizedBox(height: 10),
                      Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _loadData,
                        icon: const Icon(Icons.refresh),
                        label: const Text('पुन्हा प्रयत्न करा'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              else if (_filteredRecords.isEmpty)
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.folder_open_rounded, size: 50, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text(
                        'या कालावधीमध्ये कोणतीही नोंद आढळली नाही.',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'कालावधी: ${_dateFormat.format(_fromDate)} ते ${_dateFormat.format(_toDate)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _onFilterReset,
                        icon: const Icon(Icons.restart_alt),
                        label: const Text('फिल्टर रीसेट करा'),
                      ),
                    ],
                  ),
                )
              else
                _buildDataTable(context, totals),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildDataTable(BuildContext context, Map<String, double> totals) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: MaterialStateProperty.all(const Color(0xFF1E3A8A)),
            headingTextStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            dataRowMaxHeight: 52,
            columnSpacing: 22,
            border: TableBorder(
              horizontalInside: BorderSide(color: Colors.grey.shade200, width: 1),
            ),
            columns: widget.report.columns.map((col) {
              return DataColumn(
                numeric: col.isNumeric || col.isCurrency,
                label: Text(
                  col.labelMr,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              );
            }).toList(),
            rows: [
              ..._filteredRecords.asMap().entries.map((entry) {
                final idx = entry.key;
                final row = entry.value;
                final isEven = idx % 2 == 0;

                return DataRow(
                  color: MaterialStateProperty.all(isEven ? Colors.white : const Color(0xFFF8FAFC)),
                  cells: widget.report.columns.map((col) {
                    final val = row[col.key];
                    String displayStr = '-';

                    if (val != null) {
                      if (col.isCurrency) {
                        final numVal = double.tryParse(val.toString()) ?? 0.0;
                        displayStr = _currencyFormat.format(numVal);
                      } else if (col.isNumeric) {
                        final numVal = double.tryParse(val.toString()) ?? 0.0;
                        displayStr = numVal.toStringAsFixed(0);
                      } else if (col.key.toLowerCase().contains('date') || col.key.toLowerCase().contains('created_at')) {
                        try {
                          displayStr = _dateFormat.format(DateTime.parse(val.toString()));
                        } catch (_) {
                          displayStr = val.toString();
                        }
                      } else {
                        displayStr = BachatGatPdfTemplate.formatCellValue(val);
                      }
                    }

                    return DataCell(
                      Text(
                        displayStr,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: (col.isCurrency || col.key == 'sr_no') ? FontWeight.w600 : FontWeight.normal,
                          color: col.isCurrency ? const Color(0xFF1E3A8A) : Colors.black87,
                        ),
                      ),
                    );
                  }).toList(),
                );
              }),

              if (totals.isNotEmpty && _filteredRecords.isNotEmpty)
                DataRow(
                  color: MaterialStateProperty.all(const Color(0xFFEEF2FF)),
                  cells: widget.report.columns.asMap().entries.map((cEntry) {
                    final cIdx = cEntry.key;
                    final col = cEntry.value;

                    if (cIdx == 0) {
                      return const DataCell(
                        Text(
                          'एकूण (Total)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E3A8A)),
                        ),
                      );
                    }

                    if (totals.containsKey(col.key)) {
                      final val = totals[col.key] ?? 0.0;
                      final displayStr = col.isCurrency ? _currencyFormat.format(val) : val.toStringAsFixed(0);
                      return DataCell(
                        Text(
                          displayStr,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E3A8A)),
                        ),
                      );
                    }

                    return const DataCell(Text(''));
                  }).toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBankAccountSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.indigo.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A8A).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.account_balance_rounded, size: 18, color: Color(0xFF1E3A8A)),
              ),
              const SizedBox(width: 8),
              const Text(
                'बँक खाते निवडा (Select Bank Account)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A8A),
                ),
              ),
              if (_selectedBankAccountId != 'all') ...[
                const Spacer(),
                InkWell(
                  onTap: () {
                    setState(() {
                      _selectedBankAccountId = 'all';
                    });
                    _loadData();
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.indigo.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.clear_rounded, size: 14, color: Color(0xFF1E3A8A)),
                        SizedBox(width: 4),
                        Text(
                          'सर्व खाती (All)',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: (_bankAccounts.any((b) => b['id'] == _selectedBankAccountId) || _selectedBankAccountId == 'all')
                    ? _selectedBankAccountId
                    : 'all',
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF1E3A8A)),
                items: [
                  const DropdownMenuItem<String>(
                    value: 'all',
                    child: Row(
                      children: [
                        Icon(Icons.account_balance_wallet_outlined, size: 18, color: Color(0xFF1E3A8A)),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'सर्व बँक खाती (All Bank Accounts)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ..._bankAccounts.map((b) {
                    final name = b['bank_name']?.toString() ?? 'बँक';
                    final accNo = b['account_number']?.toString() ?? '';
                    final masked = accNo.length > 4 ? 'XXXX${accNo.substring(accNo.length - 4)}' : accNo;
                    final bal = ((b['current_balance'] ?? 0) as num).toDouble();
                    final branch = b['branch']?.toString() ?? '';

                    return DropdownMenuItem<String>(
                      value: b['id']?.toString(),
                      child: Row(
                        children: [
                          const Icon(Icons.account_balance_outlined, size: 18, color: Colors.indigo),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '$name ($masked)${branch.isNotEmpty ? " • $branch" : ""}',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: bal >= 0 ? Colors.green.shade50 : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: bal >= 0 ? Colors.green.shade300 : Colors.red.shade300),
                            ),
                            child: Text(
                              'शिल्लक: ₹ ${bal.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: bal >= 0 ? Colors.green.shade800 : Colors.red.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
                onChanged: (newVal) {
                  if (newVal != null && newVal != _selectedBankAccountId) {
                    setState(() {
                      _selectedBankAccountId = newVal;
                    });
                    _loadData();
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
