import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_strings.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/member_provider.dart';
import '../../widgets/app_card.dart';
import '../../widgets/status_badge.dart';
import 'add_edit_member_screen.dart';
import 'member_profile_screen.dart';

class MemberListScreen extends StatefulWidget {
  const MemberListScreen({super.key});

  @override
  State<MemberListScreen> createState() => _MemberListScreenState();
}

class _MemberListScreenState extends State<MemberListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.currentGroup != null) {
        Provider.of<MemberProvider>(context, listen: false).fetchMembers(auth.currentGroup!.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final memberProv = Provider.of<MemberProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(AppStrings.navMembers),
        actions: [
          if (auth.canAdd)
            IconButton(
              icon: const Icon(Icons.person_add_rounded, color: AppColors.primary),
              onPressed: () => _showAddMemberDialog(context),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar matching Screen 4
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: memberProv.setSearchQuery,
              decoration: InputDecoration(
                hintText: AppStrings.searchMembers,
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: const Icon(Icons.tune_rounded),
              ),
            ),
          ),

          // Member List
          Expanded(
            child: memberProv.isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : memberProv.members.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.people_outline_rounded, size: 64, color: AppColors.textMuted),
                              const SizedBox(height: 12),
                              Text(
                                AppStrings.noMembersYet,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                              ),
                                if (auth.canAdd) ...[
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: () => _showAddMemberDialog(context),
                                    icon: const Icon(Icons.person_add_rounded),
                                    label: Text(AppStrings.addFirstMember),
                                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                                  ),
                                ],
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: memberProv.members.length,
                        itemBuilder: (ctx, i) {
                          final m = memberProv.members[i];
                          return AppCard(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => MemberProfileScreen(member: m)),
                              );
                            },
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: AppColors.primary.withOpacity(0.12),
                                  child: Text(
                                    '${i + 1}',
                                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: AppColors.primary),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        m.fullName,
                                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
                                      ),
                                      Text(
                                        '${m.memberCode} • ${m.mobileNumber}',
                                        style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                StatusBadge(status: m.isActive ? 'Active' : 'Inactive'),
                                if (auth.canWrite)
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
                                    tooltip: 'पर्याय (Options)',
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    onSelected: (val) async {
                                      if (val == 'edit') {
                                        final res = await Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (_) => AddEditMemberScreen(member: m)),
                                        );
                                        if (res == true && context.mounted) {
                                          final gId = m.groupId;
                                          if (gId.isNotEmpty) {
                                            Provider.of<MemberProvider>(context, listen: false).fetchMembers(gId);
                                          }
                                        }
                                      } else if (val == 'delete') {
                                        _confirmDeleteMember(context, m);
                                      }
                                    },
                                    itemBuilder: (ctx) => [
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit_outlined, color: Color(0xFF1E3A8A), size: 20),
                                            SizedBox(width: 10),
                                            Text('संपादित करा (Edit)'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                            SizedBox(width: 10),
                                            Text('हटवा (Delete)', style: TextStyle(color: Colors.red)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: auth.canAdd
          ? FloatingActionButton.extended(
              onPressed: () => _showAddMemberDialog(context),
              backgroundColor: const Color(0xFF1E3A8A),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.person_add_rounded),
              label: Text(
                'नवीन सदस्य जोडा',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            )
          : null,
    );
  }

  Future<void> _showAddMemberDialog(BuildContext context) async {
    final res = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddEditMemberScreen()),
    );
    if (res == true && context.mounted) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final gId = auth.currentGroup?.id ?? auth.currentProfile?.groupId ?? '';
      if (gId.isNotEmpty) {
        Provider.of<MemberProvider>(context, listen: false).fetchMembers(gId);
        try {
          Provider.of<DashboardProvider>(context, listen: false).loadDashboardMetrics(gId);
        } catch (_) {}
      }
    }
  }

  Future<void> _confirmDeleteMember(BuildContext context, dynamic member) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'सदस्य हटवा (Delete)?',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'तुम्हाला खात्री आहे का? तुम्ही खालील सदस्याची माहिती कायमची हटवू इच्छिता?',
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.fullName,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.red.shade900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'कोड: ${member.memberCode} • मोबाईल: ${member.mobileNumber}',
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.red.shade700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'टीप: ही क्रिया पूर्ववत करता येत नाही.',
              style: GoogleFonts.poppins(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text('रद्द करा (Cancel)', style: GoogleFonts.poppins(color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: Text('होय, हटवा (Delete)', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      final memberProv = Provider.of<MemberProvider>(context, listen: false);
      final success = await memberProv.deleteMember(member.id);
      if (context.mounted) {
        if (success) {
          try {
            Provider.of<DashboardProvider>(context, listen: false).loadDashboardMetrics(member.groupId);
          } catch (_) {}
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('सदस्य "${member.fullName}" यशस्वीरित्या हटवला गेला.'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(memberProv.lastError ?? 'सदस्य हटवताना त्रुटी आली. कृपया तपासा.'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }
}
