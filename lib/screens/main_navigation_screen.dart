import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../core/localization/app_strings.dart';
import '../models/bachat_group.dart';
import '../providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/loan_provider.dart';
import '../providers/member_provider.dart';
import '../providers/savings_provider.dart';
import '../providers/bank_provider.dart';
import '../providers/monthly_collection_provider.dart';
import '../core/utils/image_helper.dart';
import 'package:image_picker/image_picker.dart';
import 'activities/activities_screen.dart';
import 'audit/audit_log_screen.dart';
import 'auth/login_screen.dart';
import 'contributions/contribution_fine_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'bank/bank_management_screen.dart';
import 'dues/dues_screen.dart';
import 'finance/cashbook_screen.dart';
import 'finance/expense_screen.dart';
import 'finance/income_screen.dart';
import 'finance/profit_loss_screen.dart';
import 'governance/resolutions_screen.dart';
import 'inventory/inventory_screen.dart';
import 'loans/bank_loan_screen.dart';
import 'loans/loan_screen.dart';
import 'meetings/meeting_screen.dart';
import 'members/member_list_screen.dart';
import 'notifications/notifications_screen.dart';
import 'reports/reports_screen.dart';
import 'savings/savings_screen.dart';
import 'settings/settings_screen.dart';
import 'backup/backup_restore_screen.dart';
import 'bonus/bonus_screen.dart';
import 'monthly_collection/monthly_collection_screen.dart';
import '../widgets/desktop_wrapper.dart';
import '../services/app_config.dart';
import '../services/sync_service.dart';
import '../widgets/sync_status_badge.dart';

class _NavModuleItem {
  final int index;
  final IconData icon;
  final String titleMr;
  final String titleEn;
  final String? subtitle;
  final String category;

  const _NavModuleItem({
    required this.index,
    required this.icon,
    required this.titleMr,
    required this.titleEn,
    this.subtitle,
    required this.category,
  });
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedModuleIndex = 0;
  bool _isSidebarExpanded = true;
  bool _isSidebarVisible = true;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshDashboardAndBanks();
    });
    if (AppConfig.isHybridMode) {
      SyncService.instance.syncVersion.addListener(_onSyncVersionChanged);
    }
  }

  @override
  void dispose() {
    if (AppConfig.isHybridMode) {
      SyncService.instance.syncVersion.removeListener(_onSyncVersionChanged);
    }
    super.dispose();
  }

  void _onSyncVersionChanged() {
    if (!mounted) return;
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final gid = auth.currentGroup?.id;
      if (gid != null && gid.isNotEmpty) {
        Provider.of<DashboardProvider>(context, listen: false).loadDashboardMetrics(gid);
        Provider.of<BankProvider>(context, listen: false).loadBanks(gid);
        Provider.of<MemberProvider>(context, listen: false).fetchMembers(gid);
        Provider.of<LoanProvider>(context, listen: false).loadLoans(gid);
        Provider.of<MonthlyCollectionProvider>(context, listen: false).fetchCollections(groupId: gid);
      }
    } catch (_) {}
  }

  void _refreshDashboardAndBanks() {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final gid = auth.currentGroup?.id;
      if (gid != null) {
        Provider.of<DashboardProvider>(context, listen: false).loadDashboardMetrics(gid);
        Provider.of<BankProvider>(context, listen: false).loadBanks(gid);
      }
    } catch (_) {}
  }

  void _onSelectModule(int index) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.isMember && (index == 19 || index == 20)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'ॲडमिन अधिकार आवश्यक आहेत (Admin privileges required for this module)',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    setState(() => _selectedModuleIndex = index);
    if (index == 0) {
      _refreshDashboardAndBanks();
    }
  }

  final List<_NavModuleItem> _moduleItems = const [
    _NavModuleItem(
      index: 0,
      icon: Icons.dashboard,
      titleMr: '३. मुख्य डॅशबोर्ड',
      titleEn: '3. Dashboard',
      subtitle: 'गटाचा एकूण आढावा व सारांश',
      category: 'मुख्य व्यवस्थापन',
    ),
    _NavModuleItem(
      index: 1,
      icon: Icons.people_alt,
      titleMr: '४. सदस्य व्यवस्थापन',
      titleEn: '4. Members & Profile',
      subtitle: 'सर्व सभासद यादी व केवायसी',
      category: 'मुख्य व्यवस्थापन',
    ),
    _NavModuleItem(
      index: 2,
      icon: Icons.savings,
      titleMr: '५. मासिक बचत नोंद',
      titleEn: '5. Monthly Savings',
      subtitle: 'नियमित बचत जमा व पासबुक',
      category: 'मुख्य व्यवस्थापन',
    ),
    _NavModuleItem(
      index: 3,
      icon: Icons.monetization_on,
      titleMr: '६ व ७. कर्ज वाटप व हप्ता वसुली',
      titleEn: '6 & 7. Loans & Collect EMI',
      subtitle: 'कर्ज वाटप, हप्ता व व्याज वसुली',
      category: 'मुख्य व्यवस्थापन',
    ),
    _NavModuleItem(
      index: 4,
      icon: Icons.calendar_month,
      titleMr: '७b. मासिक बैठका व हजेरी',
      titleEn: '7b. Meetings & Attendance',
      subtitle: 'हजेरी, विषयपत्रिका व ठराव वही',
      category: 'मुख्य व्यवस्थापन',
    ),
    _NavModuleItem(
      index: 5,
      icon: Icons.trending_up,
      titleMr: '८. उत्पन्न व्यवस्थापन व अहवाल',
      titleEn: '8. Income Management',
      subtitle: 'गट उत्पन्न नोंद, पावती व अहवाल',
      category: 'आर्थिक व्यवहार व हिशोब',
    ),
    _NavModuleItem(
      index: 6,
      icon: Icons.trending_down,
      titleMr: '९. खर्च व्यवस्थापन व अहवाल',
      titleEn: '9. Expense Management',
      subtitle: 'खर्च व्हाउचर्स, बिले व अहवाल',
      category: 'आर्थिक व्यवहार व हिशोब',
    ),
    _NavModuleItem(
      index: 7,
      icon: Icons.account_balance,
      titleMr: '१०. बँक व्यवस्थापन',
      titleEn: '10. Bank Management',
      subtitle: 'बँक खाती, शिल्लक व व्यवहार नोंद',
      category: 'आर्थिक व्यवहार व हिशोब',
    ),
    // Module 14. Cash Book kept in code but hidden from navigation per user request
    /*
    _NavModuleItem(
      index: 8,
      icon: Icons.menu_book,
      titleMr: '१४. कॅश बुक (रोख वही)',
      titleEn: '14. Cash Book',
      subtitle: 'रोख जमा-खर्च व शिल्लक वही',
      category: 'आर्थिक व्यवहार व हिशोब',
    ),
    */
    _NavModuleItem(
      index: 9,
      icon: Icons.bar_chart,
      titleMr: '१५. मासिक नफा-तोटा पत्रक',
      titleEn: '15. Profit & Loss Statement',
      subtitle: 'जमा vs खर्च निव्वळ नफा ताळेबंद',
      category: 'आर्थिक व्यवहार व हिशोब',
    ),
    _NavModuleItem(
      index: 10,
      icon: Icons.volunteer_activism,
      titleMr: '१६. वर्गणी व दंड नोंद',
      titleEn: '16. Contributions & Fines',
      subtitle: 'विशेष निधी, वर्गणी व गैरहजर दंड',
      category: 'आर्थिक व्यवहार व हिशोब',
    ),
    _NavModuleItem(
      index: 11,
      icon: Icons.pending_actions,
      titleMr: '२२. थकबाकी व वसुली नोंद',
      titleEn: '22. Dues & Recovery',
      subtitle: 'प्रलंबित हप्ते व बचत वसुली',
      category: 'आर्थिक व्यवहार व हिशोब',
    ),
    _NavModuleItem(
      index: 21,
      icon: Icons.card_giftcard,
      titleMr: '२८. लाभांश व बोनस वाटप',
      titleEn: '28. Bonus Module',
      subtitle: 'सभासद लाभांश, बोनस गणना व वाटप',
      category: 'आर्थिक व्यवहार व हिशोब',
    ),
    _NavModuleItem(
      index: 22,
      icon: Icons.account_balance_wallet_rounded,
      titleMr: '२९. मासिक संकलन केंद्र',
      titleEn: '29. Monthly Collection',
      subtitle: 'मासिक बचत व कर्ज हप्ता एकात्मिक संकलन',
      category: 'आर्थिक व्यवहार व हिशोब',
    ),
    _NavModuleItem(
      index: 12,
      icon: Icons.inventory_2,
      titleMr: '११ व १२. उत्पादने व स्टॉक POS',
      titleEn: '11 & 12. Products & Inventory',
      subtitle: 'पापड, लोणचे, स्टॉक व विक्री',
      category: 'व्यवसाय व शासकीय योजना',
    ),
    // Module 13 & 17 Bank Loans & Schemes kept in code but hidden from navigation per user request
    /*
    _NavModuleItem(
      index: 13,
      icon: Icons.account_balance,
      titleMr: '१३ व १७. बँक कर्ज व योजना',
      titleEn: '13 & 17. Bank Loans & Schemes',
      subtitle: 'बँक लिंकेज व शासकीय योजना',
      category: 'व्यवसाय व शासकीय योजना',
    ),
    */
    _NavModuleItem(
      index: 14,
      icon: Icons.how_to_vote,
      titleMr: '१८. ठराव वही व कागदपत्रे',
      titleEn: '18. Resolutions & Documents',
      subtitle: 'बैठक ठराव, मतदान व केवायसी',
      category: 'व्यवसाय व शासकीय योजना',
    ),
    _NavModuleItem(
      index: 15,
      icon: Icons.school,
      titleMr: '२० व २१. कौशल्य प्रशिक्षण व उपक्रम',
      titleEn: '20 & 21. Trainings & Events',
      subtitle: 'महिला प्रशिक्षण व मेळावा उपक्रम',
      category: 'व्यवसाय व शासकीय योजना',
    ),
    _NavModuleItem(
      index: 16,
      icon: Icons.notifications_active,
      titleMr: '२३. सूचना व स्मरणपत्रे',
      titleEn: '23. Notifications & Reminders',
      subtitle: 'हप्ता थकबाकी व बैठक स्मरणपत्रे',
      category: 'अहवाल व गट प्रशासन',
    ),
    _NavModuleItem(
      index: 17,
      icon: Icons.analytics_rounded,
      titleMr: 'सर्व अहवाल (All Reports)',
      titleEn: 'All Reports & PDF System',
      subtitle: '३८+ अधिकृत अहवाल, ताळेबंद व PDF',
      category: 'अहवाल व गट प्रशासन',
    ),
    _NavModuleItem(
      index: 18,
      icon: Icons.security,
      titleMr: '२५. ऑडिट व हालचाली नोंद',
      titleEn: '25. Audit & Activity Log',
      subtitle: 'व्यवहारांची खातरजमा व ऑडिट ट्रेल',
      category: 'अहवाल व गट प्रशासन',
    ),
    _NavModuleItem(
      index: 19,
      icon: Icons.settings,
      titleMr: '२६. गट माहिती, फोटो व नियम',
      titleEn: '26. Settings & Profile',
      subtitle: 'लोगो, नियम व पदाधिकारी तपशील',
      category: 'अहवाल व गट प्रशासन',
    ),
    _NavModuleItem(
      index: 20,
      icon: Icons.settings_backup_restore_rounded,
      titleMr: '२७. बॅकअप व रिस्टोअर (.db)',
      titleEn: '27. Backup & Restore (.db)',
      subtitle: '.db बॅकअप एक्सपोर्ट, इम्पोर्ट व क्लाउड मायग्रेशन',
      category: 'अहवाल व गट प्रशासन',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final isDesktop = MediaQuery.of(context).size.width >= 768;

    final screens = [
      DashboardScreen(onNavigate: _onSelectModule),
      const MemberListScreen(),
      const SavingsScreen(),
      const LoanScreen(),
      const MeetingScreen(),
      const IncomeScreen(),
      const ExpenseScreen(),
      const BankManagementScreen(),
      const CashBookScreen(),
      const ProfitLossScreen(),
      const ContributionFineScreen(),
      const DuesScreen(),
      const InventoryScreen(),
      const BankLoanScreen(),
      const ResolutionsScreen(),
      const ActivitiesScreen(),
      const NotificationsScreen(),
      const ReportsScreen(),
      const AuditLogScreen(),
      const SettingsScreen(),
      const BackupRestoreScreen(),
      const BonusScreen(),
      const MonthlyCollectionScreen(),
    ];

    return ValueListenableBuilder<bool>(
      valueListenable: AppStrings.languageNotifier,
      builder: (context, isMarathi, _) {
        return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: !isDesktop ? _buildDrawer(context, auth) : null,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu, color: AppColors.primary, size: 28),
          tooltip: 'मेनू (Toggle Navigation Bar)',
          onPressed: () {
            if (!isDesktop) {
              _scaffoldKey.currentState?.openDrawer();
            } else {
              setState(() {
                if (!_isSidebarVisible) {
                  _isSidebarVisible = true;
                  _isSidebarExpanded = true;
                } else {
                  _isSidebarExpanded = !_isSidebarExpanded;
                }
              });
            }
          },
        ),
        title: InkWell(
          onTap: () => _showGroupSelector(context, auth),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Group Logo / Icon
                Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppColors.primary, AppColors.secondary]),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: auth.currentGroup?.logoUrl != null && auth.currentGroup!.logoUrl!.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: ImageHelper.buildBase64Image(auth.currentGroup!.logoUrl, width: 32, height: 32),
                        )
                      : const Icon(Icons.groups, color: Colors.white, size: 18),
                ),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              auth.currentGroup?.groupName ?? AppStrings.appName,
                              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_drop_down, size: 20, color: AppColors.primary),
                        ],
                      ),
                      Text(
                        '${auth.currentProfile?.fullName ?? "Admin"} • ${auth.currentGroup?.village ?? ""}',
                        style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: isDesktop
            ? [
                // Desktop: Full Action Items
                InkWell(
                  onTap: () => _showProfilePhotoDialog(context, auth),
                  borderRadius: BorderRadius.circular(24),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            auth.currentProfile?.profilePhotoUrl != null && auth.currentProfile!.profilePhotoUrl!.isNotEmpty
                                ? ImageHelper.buildBase64Avatar(
                                    auth.currentProfile!.profilePhotoUrl,
                                    radius: 17,
                                    fallbackInitial: auth.currentProfile?.fullName.isNotEmpty == true
                                        ? auth.currentProfile!.fullName[0].toUpperCase()
                                        : 'A',
                                  )
                                : CircleAvatar(
                                    radius: 17,
                                    backgroundColor: AppColors.primary.withOpacity(0.12),
                                    child: Text(
                                      auth.currentProfile?.fullName.isNotEmpty == true
                                          ? auth.currentProfile!.fullName[0].toUpperCase()
                                          : 'A',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt, size: 8, color: Colors.white),
                            ),
                          ],
                        ),
                        const SizedBox(width: 6),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              auth.currentProfile?.fullName ?? 'Admin',
                              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                            ),
                            Text(
                              AppStrings.tr('फोटो बदला', 'Change Photo'),
                              style: GoogleFonts.poppins(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        const SizedBox(width: 4),
                      ],
                    ),
                  ),
                ),

                // Data Period Badge (Active Session Date Filter)
                InkWell(
                  onTap: () => _showChangeDataDateDialog(context, auth),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.date_range_rounded, size: 15, color: Color(0xFF1D4ED8)),
                        const SizedBox(width: 5),
                        Text(
                          'Data Period: ${auth.applicationStartDateFormatted} → ${auth.globalEndDateFormatted}',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1E40AF),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.edit_calendar_rounded, size: 13, color: Color(0xFF2563EB)),
                      ],
                    ),
                  ),
                ),

                // Role Badge (Admin / Member View-Only)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: auth.isAdmin ? const Color(0xFFEFF6FF) : const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: auth.isAdmin ? const Color(0xFF3B82F6) : const Color(0xFF16A34A),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        auth.isAdmin ? Icons.shield_rounded : Icons.visibility_rounded,
                        size: 15,
                        color: auth.isAdmin ? const Color(0xFF1D4ED8) : const Color(0xFF15803D),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        auth.isAdmin ? 'Admin' : 'Member (View Only)',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: auth.isAdmin ? const Color(0xFF1D4ED8) : const Color(0xFF15803D),
                        ),
                      ),
                    ],
                  ),
                ),

                if (AppConfig.isHybridMode)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Center(child: SyncStatusBadge()),
                  )
                else if (AppConfig.isOfflineMode)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.amber.shade700.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_off, size: 14, color: Colors.amber.shade900),
                        const SizedBox(width: 4),
                        Text(
                          'Offline',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.domain, color: AppColors.primary),
                  tooltip: AppStrings.switchGroup,
                  onPressed: () => _showGroupSelector(context, auth),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.language, size: 16, color: AppColors.primary),
                  label: Text(AppStrings.isMarathi ? 'मराठी' : 'English', style: const TextStyle(color: AppColors.primary)),
                  onPressed: () => AppStrings.toggleLanguage(),
                ),
                IconButton(
                  icon: const Icon(Icons.switch_account, color: AppColors.primary),
                  tooltip: 'Switch User (वापरकर्ता बदला)',
                  onPressed: () {
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.logout, color: AppColors.danger),
                  tooltip: 'Logout (लॉगआउट)',
                  onPressed: () => _handleLogout(context, auth),
                ),
              ]
            : [
                // Mobile: Compact Non-Overlapping Action Bar
                InkWell(
                  onTap: () => _showChangeDataDateDialog(context, auth),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.date_range_rounded, size: 12, color: Color(0xFF1D4ED8)),
                        const SizedBox(width: 3),
                        Text(
                          '${auth.globalEndDate.day}/${auth.globalEndDate.month}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E40AF),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: auth.isAdmin ? const Color(0xFFEFF6FF) : const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: auth.isAdmin ? const Color(0xFF3B82F6) : const Color(0xFF16A34A),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        auth.isAdmin ? Icons.shield_rounded : Icons.visibility_rounded,
                        size: 11,
                        color: auth.isAdmin ? const Color(0xFF1D4ED8) : const Color(0xFF15803D),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        auth.isAdmin ? 'Admin' : 'Member',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: auth.isAdmin ? const Color(0xFF1D4ED8) : const Color(0xFF15803D),
                        ),
                      ),
                    ],
                  ),
                ),
                if (AppConfig.isHybridMode)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 2),
                    child: Center(child: SyncStatusBadge()),
                  )
                else if (AppConfig.isOfflineMode)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade700.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_off, size: 12, color: Colors.amber.shade900),
                        const SizedBox(width: 2),
                        Text(
                          'Offline',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Mobile Avatar Icon Button
                InkWell(
                  onTap: () => _showProfilePhotoDialog(context, auth),
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        auth.currentProfile?.profilePhotoUrl != null && auth.currentProfile!.profilePhotoUrl!.isNotEmpty
                            ? ImageHelper.buildBase64Avatar(
                                auth.currentProfile!.profilePhotoUrl,
                                radius: 16,
                                fallbackInitial: auth.currentProfile?.fullName.isNotEmpty == true
                                    ? auth.currentProfile!.fullName[0].toUpperCase()
                                    : 'A',
                              )
                            : CircleAvatar(
                                radius: 16,
                                backgroundColor: AppColors.primary.withOpacity(0.12),
                                child: Text(
                                  auth.currentProfile?.fullName.isNotEmpty == true
                                      ? auth.currentProfile!.fullName[0].toUpperCase()
                                      : 'A',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt, size: 7, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),

                // Mobile Overflow Menu
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: AppColors.primary),
                  tooltip: 'पर्याय (Options)',
                  onSelected: (value) {
                    if (value == 'switch_group') {
                      _showGroupSelector(context, auth);
                    } else if (value == 'toggle_language') {
                      AppStrings.toggleLanguage();
                    } else if (value == 'switch_user') {
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                    } else if (value == 'logout') {
                      _handleLogout(context, auth);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'toggle_language',
                      child: Row(
                        children: [
                          const Icon(Icons.language, size: 20, color: AppColors.primary),
                          const SizedBox(width: 10),
                          Text(AppStrings.isMarathi ? 'English मध्ये बदला' : 'मराठी मध्ये बदला'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'switch_group',
                      child: Row(
                        children: [
                          const Icon(Icons.domain, size: 20, color: AppColors.primary),
                          const SizedBox(width: 10),
                          Text(AppStrings.switchGroup),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'switch_user',
                      child: Row(
                        children: [
                          Icon(Icons.switch_account, size: 20, color: AppColors.primary),
                          SizedBox(width: 10),
                          Text('वापरकर्ता बदला (Switch User)'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'logout',
                      child: Row(
                        children: [
                          Icon(Icons.logout, size: 20, color: AppColors.danger),
                          SizedBox(width: 10),
                          Text('लॉगआउट (Logout)', style: TextStyle(color: AppColors.danger)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
      ),
      body: Row(
        children: [
          // Left Togglable Vertical Bar (For desktop/tablet)
          if (isDesktop && _isSidebarVisible)
            _buildVerticalBar(context, auth),

          // Main View for the selected module (scrollable on mobile like dairy app)
          Expanded(
            child: DesktopWrapper(
              child: screens[_selectedModuleIndex < screens.length ? _selectedModuleIndex : 0],
            ),
          ),
        ],
      ),
    );
      },
    );
  }

  // --- LEFT VERTICAL NAVIGATION BAR ---
  Widget _buildVerticalBar(BuildContext context, AuthProvider auth) {
    final width = _isSidebarExpanded ? 275.0 : 72.0;
    final visibleItems = auth.isMember
        ? _moduleItems.where((m) => m.index != 19 && m.index != 20).toList()
        : _moduleItems;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      width: width,
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          right: BorderSide(color: AppColors.cardBorder, width: 1.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(3, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top Header (Logo & Toggle Button)
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: _isSidebarExpanded ? 14 : 8,
              vertical: 12,
            ),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.divider, width: 1)),
            ),
            child: _isSidebarExpanded
                ? Row(
                    children: [
                      InkWell(
                        onTap: () => _showProfilePhotoDialog(context, auth),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.primary, AppColors.secondary],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: auth.currentGroup?.logoUrl != null && auth.currentGroup!.logoUrl!.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: ImageHelper.buildBase64Image(auth.currentGroup!.logoUrl, width: 40, height: 40),
                                )
                              : const Icon(Icons.groups, color: Colors.white, size: 22),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              auth.currentGroup?.groupName ?? 'सखी बचत गट',
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.primary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              AppStrings.tr('सर्व २७ मॉड्युल्स', 'All 27 Modules'),
                              style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_left, size: 22, color: AppColors.textSecondary),
                        tooltip: 'संक्षिप्त करा (Collapse)',
                        onPressed: () => setState(() => _isSidebarExpanded = false),
                      ),
                    ],
                  )
                : Center(
                    child: InkWell(
                      onTap: () => setState(() => _isSidebarExpanded = true),
                      borderRadius: BorderRadius.circular(10),
                      child: Tooltip(
                        message: 'विस्तृत करा (Expand Navigation)',
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [AppColors.primary, AppColors.secondary],
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: auth.currentGroup?.logoUrl != null && auth.currentGroup!.logoUrl!.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: ImageHelper.buildBase64Image(auth.currentGroup!.logoUrl, width: 42, height: 42),
                                    )
                                  : const Icon(Icons.groups, color: Colors.white, size: 22),
                            ),
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.chevron_right, size: 12, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),

          // Featured "सर्व अहवाल (All Reports)" Quick Launch Button in Sidebar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: InkWell(
              onTap: () => setState(() => _selectedModuleIndex = 17),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: _isSidebarExpanded ? 12 : 6, vertical: 9),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _selectedModuleIndex == 17
                        ? [const Color(0xFF1E3A8A), const Color(0xFF1D4ED8)]
                        : [const Color(0xFF0F172A), const Color(0xFF334155)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _selectedModuleIndex == 17 ? const Color(0xFFD97706) : Colors.black,
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: _isSidebarExpanded
                    ? Row(
                        children: [
                          const Icon(Icons.analytics_rounded, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'सर्व अहवाल (All Reports)',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD97706),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              '३८',
                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      )
                    : const Center(
                        child: Tooltip(
                          message: 'सर्व अहवाल (All Reports - ३८ अहवाल)',
                          child: Icon(Icons.analytics_rounded, color: Colors.white, size: 20),
                        ),
                      ),
              ),
            ),
          ),

          // Middle: Scrollable list of modules
          Expanded(
            child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: visibleItems.length,
                  itemBuilder: (ctx, i) {
                    final item = visibleItems[i];
                    final isSelected = _selectedModuleIndex == item.index;
                    final showCategory = _isSidebarExpanded && (i == 0 || visibleItems[i].category != visibleItems[i - 1].category);

                if (!_isSidebarExpanded) {
                  // Compact Icon Mode
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
                    child: Tooltip(
                      message: AppStrings.isMarathi ? item.titleMr : item.titleEn,
                      preferBelow: false,
                      child: InkWell(
                        onTap: () => _onSelectModule(item.index),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFFFCC80) : const Color(0xFFFFE0B2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.black, width: 1.2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 2,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Icon(
                            item.icon,
                            color: isSelected ? const Color(0xFFBF360C) : Colors.black87,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  );
                }

                // Expanded Full Mode
                Widget tile = Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2.5),
                  child: InkWell(
                    onTap: () => _onSelectModule(item.index),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFFFCC80) : const Color(0xFFFFE0B2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.black, width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            item.icon,
                            color: isSelected ? const Color(0xFFBF360C) : Colors.black87,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              AppStrings.isMarathi ? item.titleMr : item.titleEn,
                              style: GoogleFonts.poppins(
                                fontSize: 12.5,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                color: isSelected ? const Color(0xFFBF360C) : Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (item.index == 16)
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E3A8A),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                '३८',
                                style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                              ),
                            ),
                          if (isSelected)
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: Color(0xFFBF360C),
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );

                if (showCategory) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Text(
                          item.category.toUpperCase(),
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: AppColors.primary.withOpacity(0.75),
                          ),
                        ),
                      ),
                      tile,
                    ],
                  );
                }

                return tile;
              },
            ),
          ),

          // Bottom Section (User profile & Actions)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.divider, width: 1)),
            ),
            child: _isSidebarExpanded
                ? InkWell(
                    onTap: () => _showProfilePhotoDialog(context, auth),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                      child: Row(
                        children: [
                          Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              auth.currentProfile?.profilePhotoUrl != null && auth.currentProfile!.profilePhotoUrl!.isNotEmpty
                                  ? ImageHelper.buildBase64Avatar(auth.currentProfile!.profilePhotoUrl, radius: 18)
                                  : CircleAvatar(
                                      radius: 18,
                                      backgroundColor: AppColors.primary.withOpacity(0.12),
                                      child: const Icon(Icons.person, color: AppColors.primary, size: 20),
                                    ),
                              Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                                child: const Icon(Icons.camera_alt, size: 8, color: Colors.white),
                              ),
                            ],
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  auth.currentProfile?.fullName ?? 'Admin',
                                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  AppStrings.tr('फोटो बदला', 'Change Photo'),
                                  style: GoogleFonts.poppins(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.logout, color: AppColors.danger, size: 18),
                            tooltip: 'Logout (लॉगआउट)',
                            onPressed: () => _handleLogout(context, auth),
                          ),
                        ],
                      ),
                    ),
                  )
                : Center(
                    child: InkWell(
                      onTap: () => _showProfilePhotoDialog(context, auth),
                      borderRadius: BorderRadius.circular(18),
                      child: Tooltip(
                        message: 'माझा प्रोफाईल फोटो बदला (Change Photo)',
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            auth.currentProfile?.profilePhotoUrl != null && auth.currentProfile!.profilePhotoUrl!.isNotEmpty
                                ? ImageHelper.buildBase64Avatar(auth.currentProfile!.profilePhotoUrl, radius: 18)
                                : CircleAvatar(
                                    radius: 18,
                                    backgroundColor: AppColors.primary.withOpacity(0.12),
                                    child: const Icon(Icons.person, color: AppColors.primary, size: 20),
                                  ),
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                              child: const Icon(Icons.camera_alt, size: 8, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // --- DRAWER FOR MOBILE / NARROW SCREENS ---
  Widget _buildDrawer(BuildContext context, AuthProvider auth) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.primary, AppColors.secondary]),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: auth.currentGroup?.logoUrl != null && auth.currentGroup!.logoUrl!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: ImageHelper.buildBase64Image(auth.currentGroup!.logoUrl, width: 44, height: 44),
                          )
                        : const Icon(Icons.groups_rounded, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          auth.currentGroup?.groupName ?? 'सखी बचत गट',
                          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${auth.currentProfile?.fullName ?? "Admin"} (${auth.currentGroup?.village ?? ""})',
                          style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Builder(
              builder: (ctx) {
                final visibleDrawerItems = auth.isMember
                    ? _moduleItems.where((m) => m.index != 19 && m.index != 20).toList()
                    : _moduleItems;
                return Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: visibleDrawerItems.length,
                    itemBuilder: (ctx, i) {
                      final item = visibleDrawerItems[i];
                      final isSelected = _selectedModuleIndex == item.index;
                      final showCategory = i == 0 || visibleDrawerItems[i].category != visibleDrawerItems[i - 1].category;

                  final tile = Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2.5),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        Navigator.pop(ctx);
                        _onSelectModule(item.index);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFFFCC80) : const Color(0xFFFFE0B2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.black, width: 1.2),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              item.icon,
                              color: isSelected ? const Color(0xFFBF360C) : Colors.black87,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                AppStrings.isMarathi ? item.titleMr : item.titleEn,
                                style: GoogleFonts.poppins(
                                  fontSize: 12.5,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                  color: isSelected ? const Color(0xFFBF360C) : Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (item.index == 16)
                              Container(
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E3A8A),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  '३८',
                                  style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                                ),
                              ),
                            if (isSelected)
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFBF360C),
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );

                  if (showCategory) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                          child: Text(
                            item.category.toUpperCase(),
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        tile,
                      ],
                    );
                  }

                  return tile;
                },
              ),
            );
          },
        ),
        const Divider(),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: AppColors.danger),
              title: Text('Logout (लॉगआउट)', style: GoogleFonts.poppins(color: AppColors.danger, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                _handleLogout(context, auth);
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- CHANGE DATA DATE DIALOG (Active Session Date Filter) ---
  void _showChangeDataDateDialog(BuildContext context, AuthProvider auth) {
    final dateController = TextEditingController(text: auth.globalEndDateFormatted);
    String? errorText;
    DateTime selectedDate = auth.globalEndDate;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          DateTime? validateAndParseDate(String input) {
            final trimmed = input.trim();
            final regex = RegExp(r'^\d{2}-\d{2}-\d{4}$');
            if (!regex.hasMatch(trimmed)) {
              setDialogState(() {
                errorText = 'Please enter date in DD-MM-YYYY format.';
              });
              return null;
            }

            final parts = trimmed.split('-');
            final day = int.tryParse(parts[0]);
            final month = int.tryParse(parts[1]);
            final year = int.tryParse(parts[2]);

            if (day == null || month == null || year == null || month < 1 || month > 12 || year < 2000 || year > 2100) {
              setDialogState(() {
                errorText = 'Please enter a valid date.';
              });
              return null;
            }

            final daysInMonth = DateTime(year, month + 1, 0).day;
            if (day < 1 || day > daysInMonth) {
              setDialogState(() {
                errorText = 'Please enter a valid date.';
              });
              return null;
            }

            final parsed = DateTime(year, month, day);
            final startDay = DateTime(auth.applicationStartDate.year, auth.applicationStartDate.month, auth.applicationStartDate.day);
            if (parsed.isBefore(startDay)) {
              setDialogState(() {
                errorText = 'Selected date cannot be earlier than the application start date (${auth.applicationStartDateFormatted}).';
              });
              return null;
            }

            return parsed;
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.edit_calendar_rounded, color: Color(0xFF2563EB), size: 22),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Change Data Date (डेटा तारीख बदला)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            content: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Active Session Period:',
                          style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${auth.applicationStartDateFormatted} → ${dateController.text}',
                          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1E40AF)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '(Application Start Date → Entered Date)',
                          style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF60A5FA)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (errorText != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, size: 18, color: Color(0xFFDC2626)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              errorText!,
                              style: const TextStyle(fontSize: 11, color: Color(0xFFB91C1C)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  Text(
                    'Data Up To Date (शेवटची तारीख)',
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: dateController,
                    keyboardType: TextInputType.datetime,
                    decoration: InputDecoration(
                      hintText: 'DD-MM-YYYY (e.g. 31-12-2026)',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.calendar_today_rounded, size: 20, color: Color(0xFF2563EB)),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: dialogCtx,
                            initialDate: selectedDate.isBefore(auth.applicationStartDate) ? auth.applicationStartDate : selectedDate,
                            firstDate: auth.applicationStartDate,
                            lastDate: DateTime(2050, 12, 31),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              selectedDate = picked;
                              final d = picked.day.toString().padLeft(2, '0');
                              final m = picked.month.toString().padLeft(2, '0');
                              final y = picked.year.toString();
                              dateController.text = '$d-$m-$y';
                              errorText = null;
                            });
                          }
                        },
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Format: DD-MM-YYYY (e.g. 31-12-2026)',
                    style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('रद्द करा (Cancel)'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  final parsed = validateAndParseDate(dateController.text);
                  if (parsed != null) {
                    auth.updateGlobalEndDate(parsed);
                    if (dialogCtx.mounted) {
                      Navigator.pop(dialogCtx);
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('डेटा तारीख बदलली: ${auth.applicationStartDateFormatted} → ${auth.globalEndDateFormatted}'),
                        backgroundColor: const Color(0xFF2563EB),
                      ),
                    );
                  }
                },
                child: const Text('तारीख बदला (Apply)'),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- DIRECT PROFILE PHOTO & GROUP LOGO UPLOADER ---
  void _showProfilePhotoDialog(BuildContext context, AuthProvider auth) {
    final messenger = ScaffoldMessenger.of(context);
    final isDesktop = MediaQuery.of(context).size.width >= 700;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          bool isUploading = false;

          Future<void> pickAndSave({required bool isGroupLogo}) async {
            final source = await showModalBottomSheet<ImageSource>(
              context: ctx,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
              builder: (sheetCtx) => SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Wrap(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        child: Text(
                          isGroupLogo
                              ? AppStrings.tr('बचत गट लोगो निवडा', 'Select Group Logo')
                              : AppStrings.tr('माझा प्रोफाईल फोटो निवडा', 'Select Profile Photo'),
                          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const Divider(),
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), shape: BoxShape.circle),
                          child: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
                        ),
                        title: Text(AppStrings.tr('गॅलरीतून निवडा (Gallery)', 'Choose from Gallery')),
                        subtitle: const Text('फोन किंवा कॉम्प्युटरमधील फोटो'),
                        onTap: () => Navigator.pop(sheetCtx, ImageSource.gallery),
                      ),
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: AppColors.secondary.withOpacity(0.12), shape: BoxShape.circle),
                          child: const Icon(Icons.camera_alt_rounded, color: AppColors.secondary),
                        ),
                        title: Text(AppStrings.tr('कॅमेराने नवीन फोटो काढा (Camera)', 'Take a Photo with Camera')),
                        subtitle: const Text('थेट कॅमेरा सुरू करा'),
                        onTap: () => Navigator.pop(sheetCtx, ImageSource.camera),
                      ),
                    ],
                  ),
                ),
              ),
            );

            if (source == null) return;

            final b64 = await ImageHelper.pickImageAsBase64(source: source, maxWidth: 600, maxHeight: 600, imageQuality: 75);
            if (b64 != null) {
              setDlgState(() => isUploading = true);
              bool ok = false;
              if (isGroupLogo) {
                ok = await auth.updateGroupLogo(b64);
              } else {
                ok = await auth.updateUserProfilePhoto(b64);
              }
              setDlgState(() => isUploading = false);

              if (!mounted) return;
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    ok
                        ? (isGroupLogo ? 'बचत गट लोगो यशस्वीरित्या बदलला!' : 'प्रोफाईल फोटो यशस्वीरित्या सेव्ह झाला!')
                        : 'फोटो सेव्ह करताना त्रुटी आली!',
                  ),
                  backgroundColor: ok ? AppColors.success : AppColors.danger,
                ),
              );
            }
          }

          final screenWidth = MediaQuery.of(context).size.width;
          final dialogWidth = isDesktop ? 480.0 : (screenWidth - 32.0).clamp(280.0, 480.0);

          return Dialog(
            insetPadding: EdgeInsets.symmetric(horizontal: isDesktop ? 40 : 16, vertical: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              width: dialogWidth,
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
              padding: EdgeInsets.all(isDesktop ? 20 : 16),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.account_circle, color: AppColors.primary, size: 24),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppStrings.tr('प्रोफाईल व गट फोटो व्यवस्थापन', 'Profile & Group Logo'),
                                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700),
                              ),
                              Text(
                                AppStrings.tr('थेट फोटो किंवा लोगो बदला', 'Upload or change photo instantly'),
                                style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const Divider(height: 20),

                    if (isUploading)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('फोटो सेव्ह होत आहे... (Saving Photo...)'),
                          ],
                        ),
                      )
                    else ...[
                      // Option 1: User Profile Photo
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Stack(
                                  alignment: Alignment.bottomRight,
                                  children: [
                                    auth.currentProfile?.profilePhotoUrl != null && auth.currentProfile!.profilePhotoUrl!.isNotEmpty
                                        ? ImageHelper.buildBase64Avatar(auth.currentProfile!.profilePhotoUrl, radius: 26)
                                        : CircleAvatar(
                                            radius: 26,
                                            backgroundColor: AppColors.secondary.withOpacity(0.12),
                                            child: const Icon(Icons.person, color: AppColors.secondary, size: 28),
                                          ),
                                    Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: const BoxDecoration(color: AppColors.secondary, shape: BoxShape.circle),
                                      child: const Icon(Icons.camera_alt, size: 9, color: Colors.white),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        auth.currentProfile?.fullName ?? 'Admin',
                                        style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                      ),
                                      Text(
                                        'वापरकर्ता प्रोफाईल (${auth.currentProfile?.role.toUpperCase() ?? "ADMIN"})',
                                        style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isDesktop) ...[
                                  const SizedBox(width: 10),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.secondary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    icon: const Icon(Icons.photo_camera, size: 16),
                                    label: const Text('फोटो बदला', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                    onPressed: () => pickAndSave(isGroupLogo: false),
                                  ),
                                ],
                              ],
                            ),
                            if (!isDesktop) ...[
                              const SizedBox(height: 10),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.secondary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.photo_camera, size: 16),
                                label: const Text('माझा फोटो बदला', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                onPressed: () => pickAndSave(isGroupLogo: false),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Option 2: Bachat Gat Logo
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(colors: [AppColors.primary, AppColors.secondary]),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: auth.currentGroup?.logoUrl != null && auth.currentGroup!.logoUrl!.isNotEmpty
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: ImageHelper.buildBase64Image(auth.currentGroup!.logoUrl, width: 52, height: 52),
                                        )
                                      : const Icon(Icons.groups, color: Colors.white, size: 26),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        auth.currentGroup?.groupName ?? 'सखी बचत गट',
                                        style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        'बचत गट लोगो (Group Logo)',
                                        style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isDesktop) ...[
                                  const SizedBox(width: 10),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    icon: const Icon(Icons.business, size: 16),
                                    label: const Text('लोगो बदला', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                    onPressed: () => pickAndSave(isGroupLogo: true),
                                  ),
                                ],
                              ],
                            ),
                            if (!isDesktop) ...[
                              const SizedBox(height: 10),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.business, size: 16),
                                label: const Text('बचत गट लोगो बदला', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                onPressed: () => pickAndSave(isGroupLogo: true),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (isDesktop)
                          TextButton.icon(
                            icon: const Icon(Icons.settings_outlined, size: 16),
                            label: const Text('सर्व २६ व २७ सेटिंग्ज उघडा (Full Settings)'),
                            onPressed: () {
                              Navigator.pop(ctx);
                              setState(() => _selectedModuleIndex = 19); // SettingsScreen
                            },
                          ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('पूर्ण झाले (Done)', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // --- LOGOUT CONFIRMATION ---
  Future<void> _handleLogout(BuildContext context, AuthProvider auth) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout (लॉगआउट)'),
        content: const Text('तुम्हाला खात्यातून बाहेर पडायचे आहे का? (Do you want to log out?)'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('नाही (Cancel)'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('होय, लॉगआउट (Logout)', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await auth.signOut();
      if (!context.mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  // --- GROUP SWITCHER & REGISTRATION ---
  void _showGroupSelector(BuildContext context, AuthProvider auth) {
    final currentGroup = auth.currentGroup;
    final hasMultiple = auth.availableGroups.length > 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.shield_rounded, color: AppColors.primary, size: 22),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hasMultiple ? 'बचत गट निवडा' : 'तुमचा अधिकृत बचत गट',
                              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                            ),
                            Text(
                              '१००% स्वतंत्र व सुरक्षित डेटा (Isolated)',
                              style: GoogleFonts.poppins(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.add_business_rounded, size: 16),
                          label: Text(AppStrings.registerGroup, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showRegisterGroupDialog(context, auth);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (!hasMultiple && currentGroup != null) ...[
                  // Single Authorized Group Profile Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withOpacity(0.06),
                          AppColors.secondary.withOpacity(0.04),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: AppColors.primary,
                              child: const Icon(Icons.corporate_fare_rounded, color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    currentGroup.groupName,
                                    style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                  ),
                                  Text(
                                    '${currentGroup.village}, ${currentGroup.taluka}, ${currentGroup.district}',
                                    style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.successBg,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.success.withOpacity(0.3)),
                              ),
                              child: Text(
                                'अधिकृत',
                                style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.success),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'मासिक बचत:',
                              style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                            ),
                            Text(
                              '₹ ${currentGroup.monthlySavingsAmount.toStringAsFixed(0)} / महिना',
                              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary),
                            ),
                          ],
                        ),
                        if (currentGroup.registrationNumber != null && currentGroup.registrationNumber!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'नोंदणी क्र.:',
                                style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                              ),
                              Text(
                                currentGroup.registrationNumber!,
                                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.lock_outline_rounded, color: AppColors.primary, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'सुरक्षा हमी: इतर कोणताही बचत गट तुमचा डेटा पाहू शकत नाही. सर्व नोंदी केवळ तुमच्या अधिकृत खात्यापुरत्या मर्यादित आहेत.',
                                  style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary, height: 1.3),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // Multiple Groups List
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: auth.availableGroups.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) {
                      final g = auth.availableGroups[i];
                      final isSelected = auth.currentGroup?.id == g.id;

                      return InkWell(
                        onTap: () {
                          Navigator.pop(ctx);
                          if (!isSelected) {
                            _handleGroupSwitch(context, g);
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary.withOpacity(0.08) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? AppColors.primary : AppColors.cardBorder,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: isSelected ? AppColors.primary : AppColors.background,
                                child: Icon(
                                  Icons.corporate_fare_rounded,
                                  color: isSelected ? Colors.white : AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      g.groupName,
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      '${g.village}, ${g.taluka} • बचत: ₹${g.monthlySavingsAmount.toStringAsFixed(0)}/महिना',
                                      style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 22),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleGroupSwitch(BuildContext context, BachatGroup group) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final dash = Provider.of<DashboardProvider>(context, listen: false);
    final mem = Provider.of<MemberProvider>(context, listen: false);
    final sav = Provider.of<SavingsProvider>(context, listen: false);
    final loan = Provider.of<LoanProvider>(context, listen: false);

    await auth.switchGroup(group);

    if (!context.mounted) return;
    await dash.loadDashboardMetrics(group.id);
    await mem.fetchMembers(group.id);
    await sav.fetchSavings(group.id);
    await loan.fetchLoans(group.id, mem.members);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${AppStrings.switchedGroupMsg} ${group.groupName}'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showRegisterGroupDialog(BuildContext context, AuthProvider auth) {
    final nameCtrl = TextEditingController();
    final regCtrl = TextEditingController();
    final villageCtrl = TextEditingController();
    final talukaCtrl = TextEditingController();
    final districtCtrl = TextEditingController(text: 'सोलापूर');
    final mobileCtrl = TextEditingController();
    final presCtrl = TextEditingController();
    final secCtrl = TextEditingController();
    final tresCtrl = TextEditingController();
    final savingsCtrl = TextEditingController(text: '200');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.registerGroup, style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: InputDecoration(labelText: AppStrings.groupName)),
              const SizedBox(height: 10),
              TextField(controller: regCtrl, decoration: InputDecoration(labelText: AppStrings.registrationNo)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: TextField(controller: villageCtrl, decoration: InputDecoration(labelText: AppStrings.village))),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: talukaCtrl, decoration: InputDecoration(labelText: AppStrings.taluka))),
                ],
              ),
              const SizedBox(height: 10),
              TextField(controller: districtCtrl, decoration: InputDecoration(labelText: AppStrings.district)),
              const SizedBox(height: 10),
              TextField(controller: mobileCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Mobile Number')),
              const SizedBox(height: 10),
              TextField(controller: presCtrl, decoration: InputDecoration(labelText: AppStrings.presidentName)),
              const SizedBox(height: 10),
              TextField(controller: secCtrl, decoration: InputDecoration(labelText: AppStrings.secretaryName)),
              const SizedBox(height: 10),
              TextField(controller: tresCtrl, decoration: InputDecoration(labelText: AppStrings.treasurerName)),
              const SizedBox(height: 10),
              TextField(controller: savingsCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: AppStrings.monthlySavings)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.cancel)),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isNotEmpty && villageCtrl.text.isNotEmpty) {
                final monthly = double.tryParse(savingsCtrl.text) ?? 200.0;
                final newGroup = await auth.registerNewGroup(
                  groupName: nameCtrl.text,
                  registrationNumber: regCtrl.text.isNotEmpty ? regCtrl.text : 'REG-${DateTime.now().millisecondsSinceEpoch}',
                  village: villageCtrl.text,
                  taluka: talukaCtrl.text.isNotEmpty ? talukaCtrl.text : villageCtrl.text,
                  district: districtCtrl.text,
                  mobile: mobileCtrl.text.isNotEmpty ? mobileCtrl.text : '9876543210',
                  presidentName: presCtrl.text,
                  secretaryName: secCtrl.text,
                  treasurerName: tresCtrl.text,
                  monthlySavingsAmount: monthly,
                );

                if (newGroup != null && context.mounted) {
                  Navigator.pop(ctx);
                  _handleGroupSwitch(context, newGroup);
                }
              }
            },
            child: Text(AppStrings.save),
          ),
        ],
      ),
    );
  }
}
