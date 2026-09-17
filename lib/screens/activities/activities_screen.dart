import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_strings.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';

class ActivitiesScreen extends StatefulWidget {
  const ActivitiesScreen({super.key});

  @override
  State<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends State<ActivitiesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SupabaseService _service = SupabaseService();
  bool _isLoading = false;

  List<Map<String, dynamic>> _trainings = [];
  List<Map<String, dynamic>> _events = [];

  // Training Form
  final _trNameCtrl = TextEditingController();
  final _trTrainerCtrl = TextEditingController();
  final _trOrgCtrl = TextEditingController();
  final _trSkillsCtrl = TextEditingController();
  final DateTime _trStartDate = DateTime.now();
  final DateTime _trEndDate = DateTime.now().add(const Duration(days: 3));

  // Event Form
  final _evNameCtrl = TextEditingController();
  final _evLocCtrl = TextEditingController();
  final _evBudgetCtrl = TextEditingController();
  final _evActualCtrl = TextEditingController();
  final DateTime _evDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _trNameCtrl.dispose();
    _trTrainerCtrl.dispose();
    _trOrgCtrl.dispose();
    _trSkillsCtrl.dispose();
    _evNameCtrl.dispose();
    _evLocCtrl.dispose();
    _evBudgetCtrl.dispose();
    _evActualCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.currentGroup != null) {
      final groupId = auth.currentGroup!.id;
      try {
        final tRes = await _service.client.from('trainings').select().eq('group_id', groupId).order('start_date', ascending: false);
        final eRes = await _service.client.from('events').select().eq('group_id', groupId).order('event_date', ascending: false);
        setState(() {
          _trainings = List<Map<String, dynamic>>.from(tRes as List);
          _events = List<Map<String, dynamic>>.from(eRes as List);
        });
      } catch (e) {
        debugPrint('Error loading trainings & events: $e');
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveTraining() async {
    if (_trNameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('प्रशिक्षणाचे नाव आवश्यक आहे')));
      return;
    }
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.currentGroup == null) return;

    setState(() => _isLoading = true);
    try {
      await _service.client.from('trainings').insert({
        'group_id': auth.currentGroup!.id,
        'training_name': _trNameCtrl.text.trim(),
        'trainer': _trTrainerCtrl.text.trim().isEmpty ? 'तज्ज्ञ प्रशिक्षक' : _trTrainerCtrl.text.trim(),
        'organization': _trOrgCtrl.text.trim().isEmpty ? 'MSRLM / उमेद' : _trOrgCtrl.text.trim(),
        'skills_taught': _trSkillsCtrl.text.trim(),
        'start_date': DateFormat('yyyy-MM-dd').format(_trStartDate),
        'end_date': DateFormat('yyyy-MM-dd').format(_trEndDate),
        'certificate_available': true,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('प्रशिक्षण कार्यक्रम नोंदवला गेला!'), backgroundColor: AppColors.success));
        _trNameCtrl.clear();
        _trTrainerCtrl.clear();
        _trOrgCtrl.clear();
        _trSkillsCtrl.clear();
        await _loadData();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('त्रुटी: $e'), backgroundColor: AppColors.danger));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveEvent() async {
    if (_evNameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('कार्यक्रमाचे नाव आवश्यक आहे')));
      return;
    }
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.currentGroup == null) return;

    setState(() => _isLoading = true);
    try {
      await _service.client.from('events').insert({
        'group_id': auth.currentGroup!.id,
        'event_name': _evNameCtrl.text.trim(),
        'event_type': 'सामूहिक उपक्रम',
        'location': _evLocCtrl.text.trim().isEmpty ? 'गाव सभागृह' : _evLocCtrl.text.trim(),
        'event_date': DateFormat('yyyy-MM-dd').format(_evDate),
        'budget': double.tryParse(_evBudgetCtrl.text.trim()) ?? 0.0,
        'actual_expense': double.tryParse(_evActualCtrl.text.trim()) ?? 0.0,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('कार्यक्रम यशस्वीरित्या नोंदवला गेला!'), backgroundColor: AppColors.success));
        _evNameCtrl.clear();
        _evLocCtrl.clear();
        _evBudgetCtrl.clear();
        _evActualCtrl.clear();
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
                  AppStrings.tr('२० व २१. कौशल्य प्रशिक्षण व उपक्रम', '20 & 21. Trainings & Activities'),
                  style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                Text(
                  AppStrings.tr('महिला कौशल्य प्रशिक्षण, कार्यशाळा व गट उपक्रम नियोजन', 'Skill training programs, workshops & community events'),
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
                    Tab(icon: const Icon(Icons.school_rounded, size: 20), text: AppStrings.tr('प्रशिक्षण कार्यक्रम (Trainings)', 'Skill Trainings')),
                    Tab(icon: const Icon(Icons.celebration_rounded, size: 20), text: AppStrings.tr('कार्यक्रम व उपक्रम (Events)', 'Events & Activities')),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTrainingsTab(),
                _buildEventsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 1: TRAININGS ---
  Widget _buildTrainingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppStrings.tr('नवीन प्रशिक्षण कार्यक्रम जोडा (Add Training)', 'Add Training Program'), style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700)),
                const Divider(height: 20),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _trNameCtrl,
                        decoration: const InputDecoration(labelText: 'प्रशिक्षणाचे नाव (Program Name)*', hintText: 'उदा. शिवणकाम व फॅशन डिझाईन', prefixIcon: Icon(Icons.school)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _trTrainerCtrl,
                        decoration: const InputDecoration(labelText: 'प्रशिक्षक (Trainer)', hintText: 'उदा. सौ. स्वाती पाटील', prefixIcon: Icon(Icons.person)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _trOrgCtrl,
                        decoration: const InputDecoration(labelText: 'संस्था (Organization)', hintText: 'उदा. उमेद / जिल्हा परिषद', prefixIcon: Icon(Icons.apartment)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _trSkillsCtrl,
                        decoration: const InputDecoration(labelText: 'शिकवले जाणारे कौशल्य (Skills Taught)', hintText: 'ब्लाऊज, ड्रेस कटिंग, पॅकिंग', prefixIcon: Icon(Icons.lightbulb)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: AppButton(
                    text: AppStrings.tr('प्रशिक्षण नोंद साठवा', 'Save Training'),
                    icon: Icons.check,
                    isLoading: _isLoading,
                    onPressed: _saveTraining,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _trainings.length,
            separatorBuilder: (ctx, idx) => const SizedBox(height: 10),
            itemBuilder: (ctx, i) {
              final t = _trainings[i];
              return AppCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), shape: BoxShape.circle),
                      child: const Icon(Icons.workspace_premium_rounded, color: AppColors.primary),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t['training_name'] ?? '', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700)),
                          Text('प्रशिक्षक: ${t['trainer'] ?? "-"} • संस्था: ${t['organization'] ?? "-"}', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700)),
                          if (t['skills_taught'] != null && t['skills_taught'].toString().isNotEmpty)
                            Text('कौशल्ये: ${t['skills_taught']}', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.primary)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.success.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                      child: const Text('प्रमाणपत्र उपलब्ध 🎓', style: TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.w600)),
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

  // --- TAB 2: EVENTS ---
  Widget _buildEventsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppStrings.tr('नवीन कार्यक्रम नोंद (Add Event / Activity)', 'Add Activity / Event'), style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700)),
                const Divider(height: 20),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _evNameCtrl,
                        decoration: const InputDecoration(labelText: 'कार्यक्रमाचे नाव (Event Name)*', hintText: 'उदा. महिला दिन मेळावा', prefixIcon: Icon(Icons.celebration)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _evLocCtrl,
                        decoration: const InputDecoration(labelText: 'स्थळ (Location)', hintText: 'उदा. समाज मंदिर, सांगली', prefixIcon: Icon(Icons.place)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _evBudgetCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'अंदाजपत्रक (Budget ₹)', prefixIcon: Icon(Icons.currency_rupee)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: TextField(
                        controller: _evActualCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'प्रत्यक्ष खर्च (Actual Expense ₹)', prefixIcon: Icon(Icons.receipt)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    AppButton(
                      text: AppStrings.tr('कार्यक्रम साठवा', 'Save Event'),
                      icon: Icons.check,
                      isLoading: _isLoading,
                      onPressed: _saveEvent,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _events.length,
            separatorBuilder: (ctx, idx) => const SizedBox(height: 10),
            itemBuilder: (ctx, i) {
              final e = _events[i];
              final budget = (e['budget'] as num?)?.toDouble() ?? 0.0;
              final exp = (e['actual_expense'] as num?)?.toDouble() ?? 0.0;
              return AppCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppColors.secondary.withOpacity(0.12), shape: BoxShape.circle),
                      child: const Icon(Icons.event_available_rounded, color: AppColors.secondary),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e['event_name'] ?? '', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700)),
                          Text('तारीख: ${e['event_date'] ?? ""} • ठिकाण: ${e['location'] ?? "-"}', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('खर्च: ₹${exp.toStringAsFixed(2)}', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: AppColors.danger)),
                        Text('बजेट: ₹${budget.toStringAsFixed(2)}', style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
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
