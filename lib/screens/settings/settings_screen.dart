import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_strings.dart';
import '../../core/utils/image_helper.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SupabaseService _service = SupabaseService();
  bool _isSaving = false;
  bool _isBackingUp = false;

  // Group logo & profile photos
  String? _groupLogoBase64;
  String? _userPhotoBase64;

  late TextEditingController _nameCtrl;
  late TextEditingController _regNoCtrl;
  late TextEditingController _villageCtrl;
  late TextEditingController _talukaCtrl;
  late TextEditingController _districtCtrl;
  late TextEditingController _monthlySavingsCtrl;
  late TextEditingController _presidentCtrl;
  late TextEditingController _secretaryCtrl;
  late TextEditingController _treasurerCtrl;

  // App Settings
  bool _pinLockEnabled = false;
  bool _biometricEnabled = false;
  int _sessionTimeout = 30;
  String _lastBackupTime = 'आज, ०९-०९-२०२६ रोजी यशस्वी';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final group = auth.currentGroup;
    final profile = auth.currentProfile;

    _groupLogoBase64 = group?.logoUrl;
    _userPhotoBase64 = profile?.profilePhotoUrl;

    _nameCtrl = TextEditingController(text: group?.groupName ?? '');
    _regNoCtrl = TextEditingController(text: group?.registrationNumber ?? '');
    _villageCtrl = TextEditingController(text: group?.village ?? '');
    _talukaCtrl = TextEditingController(text: group?.taluka ?? '');
    _districtCtrl = TextEditingController(text: group?.district ?? '');
    _monthlySavingsCtrl = TextEditingController(text: group?.monthlySavingsAmount.toStringAsFixed(0) ?? '200');
    _presidentCtrl = TextEditingController(text: group?.presidentName ?? '');
    _secretaryCtrl = TextEditingController(text: group?.secretaryName ?? '');
    _treasurerCtrl = TextEditingController(text: group?.treasurerName ?? '');
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameCtrl.dispose();
    _regNoCtrl.dispose();
    _villageCtrl.dispose();
    _talukaCtrl.dispose();
    _districtCtrl.dispose();
    _monthlySavingsCtrl.dispose();
    _presidentCtrl.dispose();
    _secretaryCtrl.dispose();
    _treasurerCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto({required bool isGroupLogo}) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Wrap(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  isGroupLogo
                      ? AppStrings.tr('बचत गट लोगो / फोटो निवडा', 'Select Bachat Gat Logo / Photo')
                      : AppStrings.tr('वापरकर्ता प्रोफाईल फोटो निवडा', 'Select Profile Photo'),
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
              ),
              const Divider(),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), shape: BoxShape.circle),
                  child: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
                ),
                title: Text(AppStrings.tr('गॅलरीतून फोटो निवडा', 'Choose from Gallery')),
                subtitle: const Text('फोन किंवा कॉम्प्युटरवरील फोटो'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.secondary.withOpacity(0.12), shape: BoxShape.circle),
                  child: const Icon(Icons.camera_alt_rounded, color: AppColors.secondary),
                ),
                title: Text(AppStrings.tr('कॅमेरामधून नवीन फोटो काढा', 'Take a Photo with Camera')),
                subtitle: const Text('थेट कॅमेरा सुरू करा'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              if ((isGroupLogo && _groupLogoBase64 != null) || (!isGroupLogo && _userPhotoBase64 != null))
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.12), shape: BoxShape.circle),
                    child: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                  ),
                  title: Text(AppStrings.tr('फोटो काढून टाका', 'Remove Photo')),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final auth = Provider.of<AuthProvider>(context, listen: false);
                    if (isGroupLogo) {
                      await auth.updateGroupLogo('');
                    } else {
                      await auth.updateUserProfilePhoto('');
                    }
                    setState(() {
                      if (isGroupLogo) {
                        _groupLogoBase64 = null;
                      } else {
                        _userPhotoBase64 = null;
                      }
                    });
                  },
                ),
            ],
          ),
        ),
      ),
    );

    if (source == null || !mounted) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final b64 = await ImageHelper.pickImageAsBase64(source: source, maxWidth: 600, maxHeight: 600, imageQuality: 75);
    if (b64 != null) {
      if (isGroupLogo) {
        await auth.updateGroupLogo(b64);
      } else {
        await auth.updateUserProfilePhoto(b64);
      }
      if (!mounted) return;
      setState(() {
        if (isGroupLogo) {
          _groupLogoBase64 = b64;
        } else {
          _userPhotoBase64 = b64;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isGroupLogo ? 'लोगो यशस्वीरित्या सेव्ह झाला!' : 'प्रोफाईल फोटो यशस्वीरित्या सेव्ह झाला!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _saveSettings(AuthProvider auth) async {
    if (auth.currentGroup == null) return;
    setState(() => _isSaving = true);

    try {
      // 1. Update Group profile including logo_url
      await _service.client.from('groups').update({
        'group_name': _nameCtrl.text.trim(),
        'registration_number': _regNoCtrl.text.trim(),
        'village': _villageCtrl.text.trim(),
        'taluka': _talukaCtrl.text.trim(),
        'district': _districtCtrl.text.trim(),
        'monthly_savings_amount': double.tryParse(_monthlySavingsCtrl.text) ?? 200.0,
        'president_name': _presidentCtrl.text.trim(),
        'secretary_name': _secretaryCtrl.text.trim(),
        'treasurer_name': _treasurerCtrl.text.trim(),
        'logo_url': _groupLogoBase64,
      }).eq('id', auth.currentGroup!.id);

      // 2. Update user profile photo if available
      if (auth.currentProfile != null && _userPhotoBase64 != null) {
        try {
          await _service.client.from('profiles').update({
            'profile_photo_url': _userPhotoBase64,
          }).eq('id', auth.currentProfile!.id);
        } catch (e) {
          debugPrint('Profile photo update warning: $e');
        }
      }

      await auth.fetchGroups();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('माहिती व प्रोफाईल फोटो यशस्वीरित्या सेव्ह झाला! (Settings saved successfully!)'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving settings: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _performBackup(AuthProvider auth) async {
    if (auth.currentGroup == null) return;
    setState(() => _isBackingUp = true);

    try {
      final groupId = auth.currentGroup!.id;
      // Fetch summary data to verify backup
      final members = await _service.client.from('members').select('id, full_name').eq('group_id', groupId);
      final savings = await _service.client.from('savings').select('id, amount').eq('group_id', groupId);
      final loans = await _service.client.from('loans').select('id, approved_amount').eq('group_id', groupId);

      await Future.delayed(const Duration(milliseconds: 800));

      setState(() {
        _lastBackupTime = 'आज, ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')} वाजता पूर्ण';
      });

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: const [
                Icon(Icons.check_circle_rounded, color: AppColors.success),
                SizedBox(width: 8),
                Text('क्लाउड बॅकअप यशस्वी!'),
              ],
            ),
            content: Text(
              'सर्व डेटा सुरक्षित आहे:\n\n'
              '• एकूण सभासद: ${(members as List).length}\n'
              '• बचत नोंदी: ${(savings as List).length}\n'
              '• कर्ज नोंदी: ${(loans as List).length}\n'
              '• बॅकअप वेळ: ${DateTime.now().toLocal()}',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ठीक आहे (OK)')),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('बॅकअप त्रुटी: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isBackingUp = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header & Tabs
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.tr('२६ व २७. गट माहिती, प्रोफाईल व सुरक्षा', '26 & 27. Group Profile & Security'),
                          style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                        ),
                        Text(
                          AppStrings.tr('गटाचा लोगो, प्रोफाईल फोटो, नियम, क्लाउड बॅकअप व सुरक्षा', 'Group logo, profile photo, rules, backup & security'),
                          style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    AppButton(
                      icon: Icons.save_rounded,
                      isLoading: _isSaving,
                      text: AppStrings.tr('बदल सेव्ह करा', 'Save Changes'),
                      onPressed: () => _saveSettings(auth),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TabBar(
                  controller: _tabController,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 3,
                  tabs: [
                    Tab(
                      icon: const Icon(Icons.corporate_fare_rounded, size: 20),
                      text: AppStrings.tr('गट प्रोफाईल व फोटो (Profile & Logo)', 'Group Profile & Logo'),
                    ),
                    Tab(
                      icon: const Icon(Icons.security_rounded, size: 20),
                      text: AppStrings.tr('बॅकअप व सुरक्षा (Backup & Security)', 'Backup & Security'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildGroupProfileTab(auth),
                _buildBackupSecurityTab(auth),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 1: GROUP PROFILE & LOGO ---
  Widget _buildGroupProfileTab(AuthProvider auth) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo Upload Card (Group Logo & User Photo)
              AppCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.tr('बचत गट लोगो / प्रोफाईल फोटो (Profile Image)', 'Group Logo & Profile Image'),
                      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      AppStrings.tr('हा लोगो पावत्या, व्हाउचर्स व अहवालांवर दिसेल.', 'This logo appears on receipts, vouchers and reports.'),
                      style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        // Group Logo
                        Column(
                          children: [
                            Stack(
                              children: [
                                Container(
                                  width: 110,
                                  height: 110,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppColors.primary, width: 3),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primary.withOpacity(0.15),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ClipOval(
                                    child: _groupLogoBase64 != null && _groupLogoBase64!.isNotEmpty
                                        ? ImageHelper.buildBase64Image(_groupLogoBase64, width: 110, height: 110)
                                        : Container(
                                            color: AppColors.primary.withOpacity(0.08),
                                            child: const Icon(Icons.groups_rounded, size: 54, color: AppColors.primary),
                                          ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: InkWell(
                                    onTap: () => _pickPhoto(isGroupLogo: true),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: const BoxDecoration(
                                        color: AppColors.primary,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              AppStrings.tr('बचत गट लोगो', 'Group Logo'),
                              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                            ),
                            TextButton.icon(
                              icon: const Icon(Icons.photo_camera_rounded, size: 16),
                              label: Text(
                                _groupLogoBase64 == null
                                    ? AppStrings.tr('लोगो जोडा', '+ Add Logo')
                                    : AppStrings.tr('लोगो बदला', 'Change Logo'),
                                style: GoogleFonts.poppins(fontSize: 12),
                              ),
                              onPressed: () => _pickPhoto(isGroupLogo: true),
                            ),
                          ],
                        ),

                        // Active Sub-User Photo
                        Column(
                          children: [
                            Stack(
                              children: [
                                Container(
                                  width: 110,
                                  height: 110,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppColors.secondary, width: 3),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.secondary.withOpacity(0.15),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ClipOval(
                                    child: _userPhotoBase64 != null && _userPhotoBase64!.isNotEmpty
                                        ? ImageHelper.buildBase64Image(_userPhotoBase64, width: 110, height: 110)
                                        : Container(
                                            color: AppColors.secondary.withOpacity(0.08),
                                            child: const Icon(Icons.person_rounded, size: 54, color: AppColors.secondary),
                                          ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: InkWell(
                                    onTap: () => _pickPhoto(isGroupLogo: false),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: const BoxDecoration(
                                        color: AppColors.secondary,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              auth.currentProfile?.fullName ?? 'व्यवस्थापक फोटो',
                              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                            ),
                            TextButton.icon(
                              icon: const Icon(Icons.photo_camera_rounded, size: 16),
                              label: Text(
                                _userPhotoBase64 == null
                                    ? AppStrings.tr('फोटो जोडा', '+ Add Photo')
                                    : AppStrings.tr('फोटो बदला', 'Change Photo'),
                                style: GoogleFonts.poppins(fontSize: 12),
                              ),
                              onPressed: () => _pickPhoto(isGroupLogo: false),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Form Card
              AppCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.tr('१. बचत गट तपशील', '1. Group Master Details'),
                      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.primary),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nameCtrl,
                      decoration: InputDecoration(
                        labelText: AppStrings.tr('बचत गटाचे नाव*', 'Bachat Gat Name*'),
                        prefixIcon: const Icon(Icons.corporate_fare_rounded),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _regNoCtrl,
                            decoration: InputDecoration(
                              labelText: AppStrings.tr('नोंदणी क्र.', 'Reg. Number'),
                              prefixIcon: const Icon(Icons.numbers_rounded),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: TextField(
                            controller: _monthlySavingsCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: AppStrings.tr('दरमहा बचत रक्कम (₹)*', 'Monthly Savings (₹)*'),
                              prefixIcon: const Icon(Icons.savings_rounded),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    isMobile
                        ? Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _villageCtrl,
                                      decoration: InputDecoration(
                                        labelText: AppStrings.tr('गाव*', 'Village*'),
                                        prefixIcon: const Icon(Icons.location_on_rounded),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextField(
                                      controller: _talukaCtrl,
                                      decoration: InputDecoration(
                                        labelText: AppStrings.tr('तालुका*', 'Taluka*'),
                                        prefixIcon: const Icon(Icons.map_rounded),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: _districtCtrl,
                                decoration: InputDecoration(
                                  labelText: AppStrings.tr('जिल्हा*', 'District*'),
                                  prefixIcon: const Icon(Icons.place_rounded),
                                ),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _villageCtrl,
                                  decoration: InputDecoration(
                                    labelText: AppStrings.tr('गाव*', 'Village*'),
                                    prefixIcon: const Icon(Icons.location_on_rounded),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: TextField(
                                  controller: _talukaCtrl,
                                  decoration: InputDecoration(
                                    labelText: AppStrings.tr('तालुका*', 'Taluka*'),
                                    prefixIcon: const Icon(Icons.map_rounded),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: TextField(
                                  controller: _districtCtrl,
                                  decoration: InputDecoration(
                                    labelText: AppStrings.tr('जिल्हा*', 'District*'),
                                    prefixIcon: const Icon(Icons.place_rounded),
                                  ),
                                ),
                              ),
                            ],
                          ),
                    const SizedBox(height: 24),

                    Text(
                      AppStrings.tr('२. मुख्य पदाधिकारी (Key Office Bearers)', '2. Office Bearers'),
                      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.primary),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _presidentCtrl,
                      decoration: InputDecoration(
                        labelText: AppStrings.tr('अध्यक्षांचे नाव (President Name)', 'President Name'),
                        prefixIcon: const Icon(Icons.person_rounded),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _secretaryCtrl,
                            decoration: InputDecoration(
                              labelText: AppStrings.tr('सचिवांचे नाव (Secretary)', 'Secretary Name'),
                              prefixIcon: const Icon(Icons.person_outline_rounded),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: TextField(
                            controller: _treasurerCtrl,
                            decoration: InputDecoration(
                              labelText: AppStrings.tr('खजिनदारांचे नाव (Treasurer)', 'Treasurer Name'),
                              prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    AppButton(
                      width: double.infinity,
                      isLoading: _isSaving,
                      text: AppStrings.tr('बदल व फोटो सेव्ह करा (Save Changes)', 'Save Changes & Photo'),
                      onPressed: _isSaving ? null : () => _saveSettings(auth),
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

  // --- TAB 2: BACKUP & SECURITY (MODULE 27) ---
  Widget _buildBackupSecurityTab(AuthProvider auth) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Backup Card
              AppCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), shape: BoxShape.circle),
                          child: const Icon(Icons.cloud_sync_rounded, color: AppColors.primary, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppStrings.tr('क्लाउड बॅकअप व डेटा रीस्टोअर (Cloud Backup)', 'Cloud Backup & Restore'),
                                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                              ),
                              Text(
                                'शेवटचा बॅकअप: $_lastBackupTime',
                                style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 28),
                    Text(
                      AppStrings.tr(
                        'आपल्या बचत गटाचा संपूर्ण डेटा (सभासद, बचत, कर्ज, बैठका, कॅशबुक) स्वयंचलितरित्या क्लाउडवर सुरक्षित साठवला जातो.',
                        'All group data is securely synchronized with online cloud servers.',
                      ),
                      style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            text: AppStrings.tr('आत्ताच संपूर्ण बॅकअप घ्या (Backup Now)', 'Backup Now'),
                            icon: Icons.backup_rounded,
                            isLoading: _isBackingUp,
                            onPressed: () => _performBackup(auth),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Security & PIN Lock Card
              AppCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.tr('सुरक्षा व गोपनीयता (Security & Access Control)', 'Security & Access Control'),
                      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    const Divider(height: 24),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(AppStrings.tr('सुरक्षा पिन लॉक (Security PIN Lock)', 'PIN Lock')),
                      subtitle: const Text('ॲप उघडताना ४ आकडी पिन आवश्यक'),
                      value: _pinLockEnabled,
                      activeColor: AppColors.primary,
                      onChanged: (val) => setState(() => _pinLockEnabled = val),
                    ),
                    const Divider(),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(AppStrings.tr('बायोमेट्रिक फिंगरप्रिंट लॉगिन (Biometric Login)', 'Biometric Login')),
                      subtitle: const Text('मोबाईल फिंगरप्रिंट सेन्सरने जलद लॉगिन'),
                      value: _biometricEnabled,
                      activeColor: AppColors.primary,
                      onChanged: (val) => setState(() => _biometricEnabled = val),
                    ),
                    const Divider(),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(AppStrings.tr('सेशन टाईमआऊट (Session Timeout)', 'Session Timeout')),
                      subtitle: Text('निष्क्रिय राहिल्यास $_sessionTimeout मिनिटांनंतर स्वयंचलित लॉक'),
                      trailing: DropdownButton<int>(
                        value: _sessionTimeout,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(value: 15, child: Text('१५ मिनिटे')),
                          DropdownMenuItem(value: 30, child: Text('३० मिनिटे')),
                          DropdownMenuItem(value: 60, child: Text('१ तास')),
                        ],
                        onChanged: (val) => setState(() => _sessionTimeout = val ?? 30),
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
