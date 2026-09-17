import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_strings.dart';
import '../../models/member.dart';
import '../../providers/auth_provider.dart';
import '../../providers/member_provider.dart';
import '../../services/supabase_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';

class ResolutionsScreen extends StatefulWidget {
  const ResolutionsScreen({super.key});

  @override
  State<ResolutionsScreen> createState() => _ResolutionsScreenState();
}

class _ResolutionsScreenState extends State<ResolutionsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SupabaseService _service = SupabaseService();
  bool _isLoading = false;

  List<Map<String, dynamic>> _resolutions = [];
  List<Map<String, dynamic>> _documents = [];

  // Resolution form
  final _resTitleCtrl = TextEditingController();
  final _resDescCtrl = TextEditingController();
  Member? _selectedProposer;

  // Doc form
  Member? _selectedDocMember;
  String _docType = 'आधार कार्ड (Aadhaar Card)';
  final _docNoCtrl = TextEditingController();

  final List<String> _docTypes = [
    'आधार कार्ड (Aadhaar Card)',
    'बँक पासबुक (Bank Passbook)',
    'गट नोंदणी प्रमाणपत्र (Group Registration)',
    'कर्ज करारनामा (Loan Agreement)',
    'पॅन कार्ड (PAN Card)',
    'इतर कागदपत्र (Other)',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _resTitleCtrl.dispose();
    _resDescCtrl.dispose();
    _docNoCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.currentGroup != null) {
      final groupId = auth.currentGroup!.id;
      try {
        final rRes = await _service.client
            .from('resolutions')
            .select('*, proposer:members!resolutions_proposed_by_fkey(full_name)')
            .eq('group_id', groupId)
            .order('created_at', ascending: false);

        final dRes = await _service.client
            .from('documents')
            .select('*, member:members(full_name)')
            .eq('group_id', groupId)
            .order('created_at', ascending: false);

        setState(() {
          _resolutions = List<Map<String, dynamic>>.from(rRes as List);
          _documents = List<Map<String, dynamic>>.from(dRes as List);
        });
      } catch (e) {
        debugPrint('Error loading resolutions: $e');
        // Fallback without relation if foreign key name differs
        try {
          final rRes = await _service.client.from('resolutions').select().eq('group_id', groupId);
          final dRes = await _service.client.from('documents').select().eq('group_id', groupId);
          setState(() {
            _resolutions = List<Map<String, dynamic>>.from(rRes as List);
            _documents = List<Map<String, dynamic>>.from(dRes as List);
          });
        } catch (_) {}
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _createResolution() async {
    if (_resTitleCtrl.text.trim().isEmpty || _resDescCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('कृपया विषय व ठराव माहिती भरा')));
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.currentGroup == null) return;

    setState(() => _isLoading = true);
    try {
      await _service.client.from('resolutions').insert({
        'group_id': auth.currentGroup!.id,
        'title': _resTitleCtrl.text.trim(),
        'description': _resDescCtrl.text.trim(),
        'proposed_by': _selectedProposer?.id,
        'status': 'proposed',
        'votes_yes': 1,
        'votes_no': 0,
        'votes_abstain': 0,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('नवीन ठराव नोंदवला गेला!'), backgroundColor: AppColors.success));
        _resTitleCtrl.clear();
        _resDescCtrl.clear();
        await _loadData();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('त्रुटी: $e'), backgroundColor: AppColors.danger));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _castVote(String resolutionId, String voteType) async {
    try {
      final res = await _service.client.from('resolutions').select('votes_yes, votes_no, votes_abstain').eq('id', resolutionId).single();
      int yes = (res['votes_yes'] as num?)?.toInt() ?? 0;
      int no = (res['votes_no'] as num?)?.toInt() ?? 0;
      int abstain = (res['votes_abstain'] as num?)?.toInt() ?? 0;

      if (voteType == 'yes') yes++;
      if (voteType == 'no') no++;
      if (voteType == 'abstain') abstain++;

      String status = yes > (no + abstain) ? 'passed' : 'proposed';

      await _service.client.from('resolutions').update({
        'votes_yes': yes,
        'votes_no': no,
        'votes_abstain': abstain,
        'status': status,
      }).eq('id', resolutionId);

      await _loadData();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('मत नोंदवले गेले!'), backgroundColor: AppColors.success));
    } catch (e) {
      debugPrint('Vote error: $e');
    }
  }

  Future<void> _addDocument() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.currentGroup == null) return;

    setState(() => _isLoading = true);
    try {
      await _service.client.from('documents').insert({
        'group_id': auth.currentGroup!.id,
        'member_id': _selectedDocMember?.id,
        'document_name': _docType,
        'document_number': _docNoCtrl.text.trim(),
        'file_url': 'online_verified',
        'verification_status': 'verified',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('कागदपत्र नोंदवले व पडताळले गेले!'), backgroundColor: AppColors.success));
        _docNoCtrl.clear();
        await _loadData();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('त्रुटी: $e'), backgroundColor: AppColors.danger));
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
                  AppStrings.tr('१८. ठराव वही, मतदान व कागदपत्रे', '18. Voting, Resolutions & Documents'),
                  style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                Text(
                  AppStrings.tr('बैठकीतील ठराव संमत करणे, मतदान व केवायसी कागदपत्र पडताळणी', 'Meeting resolutions voting, approvals & member KYC documents'),
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
                    Tab(icon: const Icon(Icons.how_to_vote_rounded, size: 20), text: AppStrings.tr('ठराव व मतदान (Resolutions)', 'Resolutions & Voting')),
                    Tab(icon: const Icon(Icons.verified_user_rounded, size: 20), text: AppStrings.tr('कागदपत्र पडताळणी (Documents)', 'Document Verification')),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildResolutionsTab(activeMembers),
                _buildDocumentsTab(activeMembers),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 1: RESOLUTIONS ---
  Widget _buildResolutionsTab(List<Member> members) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Add Resolution Form
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppStrings.tr('नवीन ठराव मांडा (Propose Resolution)', 'Propose Resolution'), style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700)),
                const Divider(height: 20),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _resTitleCtrl,
                        decoration: const InputDecoration(labelText: 'ठरावाचा विषय (Title)*', prefixIcon: Icon(Icons.title)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<Member>(
                        value: _selectedProposer,
                        decoration: const InputDecoration(labelText: 'सूचक / प्रस्तावक (Proposer)', prefixIcon: Icon(Icons.person)),
                        items: members.map((m) => DropdownMenuItem(value: m, child: Text(m.fullName))).toList(),
                        onChanged: (v) => setState(() => _selectedProposer = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _resDescCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'ठरावाचा सविस्तर मजकूर (Resolution Body)*', prefixIcon: Icon(Icons.description)),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: AppButton(
                    text: AppStrings.tr('ठराव मांडा (Propose)', 'Propose Resolution'),
                    icon: Icons.how_to_vote,
                    isLoading: _isLoading,
                    onPressed: _createResolution,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Resolutions List
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _resolutions.length,
            separatorBuilder: (ctx, idx) => const SizedBox(height: 12),
            itemBuilder: (ctx, i) {
              final r = _resolutions[i];
              final isPassed = r['status'] == 'passed';
              final yes = (r['votes_yes'] as num?)?.toInt() ?? 0;
              final no = (r['votes_no'] as num?)?.toInt() ?? 0;

              return AppCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            r['title'] ?? '',
                            style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isPassed ? AppColors.success.withOpacity(0.12) : Colors.orange.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isPassed ? 'मंजूर (Passed)' : 'प्रस्तावित (Proposed)',
                            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: isPassed ? AppColors.success : Colors.orange),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(r['description'] ?? '', style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary)),
                    const Divider(height: 18),
                    Row(
                      children: [
                        Text('मतदान:', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, visualDensity: VisualDensity.compact),
                          icon: const Icon(Icons.thumb_up, size: 14),
                          label: Text('संमत ($yes)'),
                          onPressed: () => _castVote(r['id'], 'yes'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, visualDensity: VisualDensity.compact),
                          icon: const Icon(Icons.thumb_down, size: 14),
                          label: Text('असंमत ($no)'),
                          onPressed: () => _castVote(r['id'], 'no'),
                        ),
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

  // --- TAB 2: DOCUMENTS ---
  Widget _buildDocumentsTab(List<Member> members) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Add Doc
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppStrings.tr('कागदपत्र पडताळणी नोंद (Verify Document)', 'Verify Document'), style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700)),
                const Divider(height: 20),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<Member>(
                        value: _selectedDocMember,
                        decoration: const InputDecoration(labelText: 'सभासद (Member) / गट', prefixIcon: Icon(Icons.person)),
                        items: members.map((m) => DropdownMenuItem(value: m, child: Text(m.fullName))).toList(),
                        onChanged: (v) => setState(() => _selectedDocMember = v),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        value: _docType,
                        decoration: const InputDecoration(labelText: 'कागदपत्र प्रकार (Document Type)*', prefixIcon: Icon(Icons.folder)),
                        items: _docTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13)))).toList(),
                        onChanged: (v) => setState(() => _docType = v!),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _docNoCtrl,
                        decoration: const InputDecoration(labelText: 'क्रमांक (Doc No)*', prefixIcon: Icon(Icons.tag)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: AppButton(
                    text: AppStrings.tr('पडताळणी पूर्ण करा (Verify)', 'Save Verified Document'),
                    icon: Icons.check_circle_outline,
                    isLoading: _isLoading,
                    onPressed: _addDocument,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // List
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _documents.length,
            separatorBuilder: (ctx, idx) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              final d = _documents[i];
              final mName = d['member']?['full_name'] ?? 'गट कागदपत्र';
              final docName = d['document_name'] ?? '';
              final docNo = d['document_number'] ?? '-';

              return AppCard(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.verified_rounded, color: AppColors.success, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$docName • $mName', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                          Text('क्रमांक: $docNo • पडताळणी स्थिती: Verified ✅', style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
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
