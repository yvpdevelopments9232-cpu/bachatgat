import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_strings.dart';
import '../../models/member.dart';
import '../../providers/auth_provider.dart';
import '../../providers/member_provider.dart';
import '../../services/supabase_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';

class ContributionFineScreen extends StatefulWidget {
  const ContributionFineScreen({super.key});

  @override
  State<ContributionFineScreen> createState() => _ContributionFineScreenState();
}

class _ContributionFineScreenState extends State<ContributionFineScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SupabaseService _service = SupabaseService();
  bool _isLoading = false;

  List<Map<String, dynamic>> _contributions = [];
  List<Map<String, dynamic>> _fines = [];

  // Contribution form
  Member? _selectedContribMember;
  final DateTime _contribDate = DateTime.now();
  String _contribType = 'वार्षिक वर्गणी (Annual Contribution)';
  final _contribAmtCtrl = TextEditingController();
  final _contribReceiptCtrl = TextEditingController();
  final _contribRemarksCtrl = TextEditingController();

  // Fine form
  Member? _selectedFineMember;
  final DateTime _fineDate = DateTime.now();
  String _fineType = 'बैठक गैरहजर दंड (Meeting Absence Fine)';
  final _fineAmtCtrl = TextEditingController(text: '50');
  final _fineReasonCtrl = TextEditingController(text: 'मासिक बैठकीस पूर्वपरवानगीशिवाय गैरहजर');

  final List<String> _contribTypes = [
    'वार्षिक वर्गणी (Annual Contribution)',
    'इमारत / जागा निधी (Building Fund)',
    'सण / उत्सव वर्गणी (Festival Fund)',
    'आपत्कालीन साहाय्य निधी (Emergency Fund)',
    'इतर विशेष वर्गणी (Special Contribution)',
  ];

  final List<String> _fineTypes = [
    'बैठक गैरहजर दंड (Meeting Absence Fine)',
    'हप्ता उशीर दंड (Late EMI Fine)',
    'बचत उशीर दंड (Late Savings Fine)',
    'नियम उल्लंघन दंड (Rule Violation Fine)',
    'इतर दंड (Miscellaneous Penalty)',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _contribReceiptCtrl.text = 'CTB-${DateFormat('yyyyMMdd-HHmm').format(DateTime.now())}';
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _contribAmtCtrl.dispose();
    _contribReceiptCtrl.dispose();
    _contribRemarksCtrl.dispose();
    _fineAmtCtrl.dispose();
    _fineReasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.currentGroup != null) {
      final groupId = auth.currentGroup!.id;
      try {
        final cRes = await _service.client
            .from('contributions')
            .select('*, member:members(full_name, member_code)')
            .eq('group_id', groupId)
            .order('contribution_date', ascending: false);

        final fRes = await _service.client
            .from('fines')
            .select('*, member:members(full_name, member_code)')
            .eq('group_id', groupId)
            .order('fine_date', ascending: false);

        setState(() {
          _contributions = List<Map<String, dynamic>>.from(cRes as List);
          _fines = List<Map<String, dynamic>>.from(fRes as List);
        });
      } catch (e) {
        debugPrint('Error loading contributions & fines: $e');
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveContribution() async {
    if (_selectedContribMember == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('कृपया सभासद निवडा')));
      return;
    }
    final amt = double.tryParse(_contribAmtCtrl.text.trim()) ?? 0.0;
    if (amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('योग्य रक्कम भरा')));
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.currentGroup == null) return;
    final groupId = auth.currentGroup!.id;

    setState(() => _isLoading = true);
    try {
      await _service.client.from('contributions').insert({
        'group_id': groupId,
        'member_id': _selectedContribMember!.id,
        'contribution_date': DateFormat('yyyy-MM-dd').format(_contribDate),
        'contribution_type': _contribType,
        'amount': amt,
        'payment_mode': 'cash',
        'receipt_number': _contribReceiptCtrl.text.trim(),
        'remarks': _contribRemarksCtrl.text.trim(),
      });

      // Add to cash_book
      final lastCashRes = await _service.client.from('cash_book').select('balance_after').eq('group_id', groupId).order('entry_date', ascending: false).limit(1);
      final lastBal = (lastCashRes as List).isNotEmpty ? (lastCashRes.first['balance_after'] as num).toDouble() : 0.0;
      await _service.client.from('cash_book').insert({
        'group_id': groupId,
        'entry_date': DateFormat('yyyy-MM-dd').format(_contribDate),
        'type': 'cash_in',
        'amount': amt,
        'balance_after': lastBal + amt,
        'description': 'वर्गणी जमा ($_contribType): ${_selectedContribMember!.fullName}',
        'reference_module': 'contributions',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('वर्गणी नोंद यशस्वी!'), backgroundColor: AppColors.success));
        _contribAmtCtrl.clear();
        _contribRemarksCtrl.clear();
        _contribReceiptCtrl.text = 'CTB-${DateFormat('yyyyMMdd-HHmm').format(DateTime.now())}';
        await _loadData();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('त्रुटी: $e'), backgroundColor: AppColors.danger));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveFine() async {
    if (_selectedFineMember == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('कृपया सभासद निवडा')));
      return;
    }
    final amt = double.tryParse(_fineAmtCtrl.text.trim()) ?? 0.0;
    if (amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('योग्य रक्कम भरा')));
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.currentGroup == null) return;
    final groupId = auth.currentGroup!.id;

    setState(() => _isLoading = true);
    try {
      await _service.client.from('fines').insert({
        'group_id': groupId,
        'member_id': _selectedFineMember!.id,
        'fine_date': DateFormat('yyyy-MM-dd').format(_fineDate),
        'fine_type': _fineType,
        'reason': _fineReasonCtrl.text.trim(),
        'amount': amt,
        'pending_amount': amt,
        'paid_amount': 0.0,
        'status': 'pending',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('दंड नोंद यशस्वी झाली!'), backgroundColor: AppColors.success));
        await _loadData();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('त्रुटी: $e'), backgroundColor: AppColors.danger));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markFineAsPaid(Map<String, dynamic> fine) async {
    final amt = (fine['amount'] as num?)?.toDouble() ?? 0.0;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.currentGroup == null) return;
    final groupId = auth.currentGroup!.id;

    try {
      await _service.client.from('fines').update({
        'status': 'paid',
        'paid_amount': amt,
        'pending_amount': 0.0,
        'paid_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      }).eq('id', fine['id']);

      // Also record in incomes (boosts profit) and cash_book
      await _service.client.from('incomes').insert({
        'group_id': groupId,
        'income_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'category': 'दंड वसुली (Penalty / Fine)',
        'amount': amt,
        'payment_mode': 'cash',
        'received_from': fine['member']?['full_name'] ?? 'सभासद',
        'description': 'दंड वसुली: ${fine['reason']}',
      });

      final lastCashRes = await _service.client.from('cash_book').select('balance_after').eq('group_id', groupId).order('entry_date', ascending: false).limit(1);
      final lastBal = (lastCashRes as List).isNotEmpty ? (lastCashRes.first['balance_after'] as num).toDouble() : 0.0;
      await _service.client.from('cash_book').insert({
        'group_id': groupId,
        'entry_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'type': 'cash_in',
        'amount': amt,
        'balance_after': lastBal + amt,
        'description': 'दंड वसुली जमा: ${fine['member']?['full_name'] ?? ""}',
        'reference_module': 'fines',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('दंड जमा झाला व नफ्यात जोडला गेला!'), backgroundColor: AppColors.success));
        await _loadData();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('त्रुटी: $e'), backgroundColor: AppColors.danger));
    }
  }

  @override
  Widget build(BuildContext context) {
    final memberProv = Provider.of<MemberProvider>(context);
    final activeMembers = memberProv.members.where((m) => m.isActive).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.tr('१६. वर्गणी व दंड व्यवस्थापन', '16. Contributions & Fines'),
                  style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                Text(
                  AppStrings.tr('वार्षिक/विशेष वर्गणी व नियम उल्लंघन दंड नोंद आणि वसुली', 'Member special contributions & absence/late fee penalties'),
                  style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                TabBar(
                  controller: _tabController,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 3,
                  tabs: [
                    Tab(icon: const Icon(Icons.card_giftcard_rounded, size: 20), text: AppStrings.tr('वर्गणी नोंद (Contributions)', 'Contributions')),
                    Tab(icon: const Icon(Icons.gavel_rounded, size: 20), text: AppStrings.tr('दंड व्यवस्थापन (Fines & Penalties)', 'Fines & Penalties')),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildContributionsTab(activeMembers),
                _buildFinesTab(activeMembers),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 1: CONTRIBUTIONS ---
  Widget _buildContributionsTab(List<Member> members) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Add Form
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppStrings.tr('नवीन वर्गणी नोंद (Add Contribution)', 'Add Contribution'), style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700)),
                const Divider(height: 20),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<Member>(
                        value: _selectedContribMember,
                        decoration: const InputDecoration(labelText: 'सभासद निवडा (Member)*', prefixIcon: Icon(Icons.person)),
                        items: members.map((m) => DropdownMenuItem(value: m, child: Text('${m.fullName} (${m.memberCode})'))).toList(),
                        onChanged: (v) => setState(() => _selectedContribMember = v),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        value: _contribType,
                        decoration: const InputDecoration(labelText: 'वर्गणी प्रकार (Type)*', prefixIcon: Icon(Icons.category)),
                        items: _contribTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13)))).toList(),
                        onChanged: (v) => setState(() => _contribType = v!),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: _contribAmtCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'रक्कम (₹)*', prefixIcon: Icon(Icons.currency_rupee)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _contribRemarksCtrl,
                        decoration: const InputDecoration(labelText: 'शेरा / तपशील (Remarks)', prefixIcon: Icon(Icons.notes)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    AppButton(
                      text: AppStrings.tr('वर्गणी जमा करा', 'Save Contribution'),
                      icon: Icons.check,
                      isLoading: _isLoading,
                      onPressed: _saveContribution,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // List
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _contributions.length,
            separatorBuilder: (ctx, idx) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              final c = _contributions[i];
              final amt = (c['amount'] as num?)?.toDouble() ?? 0.0;
              final name = c['member']?['full_name'] ?? 'सभासद';
              final type = c['contribution_type'] ?? '';
              final date = c['contribution_date'] ?? '';
              return AppCard(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.volunteer_activism_rounded, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$name • $type', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                          Text('तारीख: $date • पावती: ${c['receipt_number'] ?? "-"}', style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                    Text('+ ₹${amt.toStringAsFixed(2)}', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: AppColors.success, fontSize: 16)),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // --- TAB 2: FINES ---
  Widget _buildFinesTab(List<Member> members) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Add Fine Form
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppStrings.tr('नवीन दंड आकारणी (Issue Fine / Penalty)', 'Issue Fine'), style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700)),
                const Divider(height: 20),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<Member>(
                        value: _selectedFineMember,
                        decoration: const InputDecoration(labelText: 'सभासद निवडा (Member)*', prefixIcon: Icon(Icons.person)),
                        items: members.map((m) => DropdownMenuItem(value: m, child: Text('${m.fullName} (${m.memberCode})'))).toList(),
                        onChanged: (v) => setState(() => _selectedFineMember = v),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        value: _fineType,
                        decoration: const InputDecoration(labelText: 'दंडाचे कारण/प्रकार (Fine Type)*', prefixIcon: Icon(Icons.gavel)),
                        items: _fineTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13)))).toList(),
                        onChanged: (v) => setState(() => _fineType = v!),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: _fineAmtCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'दंड रक्कम (₹)*', prefixIcon: Icon(Icons.currency_rupee)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _fineReasonCtrl,
                        decoration: const InputDecoration(labelText: 'दंडाचे सविस्तर कारण (Reason)', prefixIcon: Icon(Icons.description)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    AppButton(
                      text: AppStrings.tr('दंड आकारणी करा', 'Issue Penalty'),
                      icon: Icons.warning_rounded,
                      color: AppColors.danger,
                      isLoading: _isLoading,
                      onPressed: _saveFine,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Fines List
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _fines.length,
            separatorBuilder: (ctx, idx) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              final f = _fines[i];
              final amt = (f['amount'] as num?)?.toDouble() ?? 0.0;
              final isPaid = f['status'] == 'paid';
              final name = f['member']?['full_name'] ?? 'सभासद';
              final type = f['fine_type'] ?? '';
              final reason = f['reason'] ?? '';
              final date = f['fine_date'] ?? '';

              return AppCard(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(isPaid ? Icons.check_circle_rounded : Icons.pending_actions_rounded, color: isPaid ? AppColors.success : Colors.orange),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$name • $type', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                          Text('तारीख: $date • कारण: $reason', style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('₹${amt.toStringAsFixed(2)}', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: isPaid ? AppColors.success : AppColors.danger, fontSize: 16)),
                        if (!isPaid)
                          TextButton(
                            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                            onPressed: () => _markFineAsPaid(f),
                            child: const Text('जमा करून घ्या (Pay)'),
                          )
                        else
                          Text('जमा झाले', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
