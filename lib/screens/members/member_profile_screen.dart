import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/member.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/member_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/status_badge.dart';
import 'add_edit_member_screen.dart';

class MemberProfileScreen extends StatefulWidget {
  final Member member;

  const MemberProfileScreen({super.key, required this.member});

  @override
  State<MemberProfileScreen> createState() => _MemberProfileScreenState();
}

class _MemberProfileScreenState extends State<MemberProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final memberProv = Provider.of<MemberProvider>(context);
    final member = memberProv.members.firstWhere(
      (m) => m.id == widget.member.id,
      orElse: () => widget.member,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(member.fullName),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            tooltip: 'संपादित करा (Edit)',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AddEditMemberScreen(member: member)),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
            tooltip: 'हटवा (Delete)',
            onPressed: () => _confirmDelete(member),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Top Profile Card
            AppCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: AppColors.primary.withOpacity(0.15),
                    child: const Icon(Icons.person, size: 40, color: AppColors.primary),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    member.fullName,
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'सदस्य कोड: ${member.memberCode} • ${member.roleInGroup}',
                    style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  StatusBadge(status: member.isActive ? 'Active' : 'Inactive'),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Personal & Contact Details Card
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('वैयक्तिक व संपर्क माहिती', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary)),
                  const Divider(height: 16),
                  _buildDetailRow(Icons.phone, 'मोबाईल', member.mobileNumber),
                  if (member.alternateMobile != null && member.alternateMobile!.isNotEmpty)
                    _buildDetailRow(Icons.phone_iphone, 'पर्यायी मोबाईल', member.alternateMobile!),
                  _buildDetailRow(Icons.person_outline, 'लिंग', member.gender),
                  if (member.dateOfBirth != null && member.dateOfBirth!.isNotEmpty)
                    _buildDetailRow(Icons.cake_outlined, 'जन्मतारीख', member.dateOfBirth!),
                  if (member.joiningDate != null && member.joiningDate!.isNotEmpty)
                    _buildDetailRow(Icons.calendar_month_outlined, 'सामील तारीख', member.joiningDate!),
                  if (member.address != null && member.address!.isNotEmpty)
                    _buildDetailRow(Icons.location_on, 'पत्ता', member.address!),
                  if (member.village != null && member.village!.isNotEmpty)
                    _buildDetailRow(Icons.location_city, 'गाव/शहर', '${member.village}${member.taluka != null ? ", ता. ${member.taluka}" : ""}${member.district != null ? ", जि. ${member.district}" : ""}'),
                  if (member.pincode != null && member.pincode!.isNotEmpty)
                    _buildDetailRow(Icons.pin_drop, 'पिनकोड', member.pincode!),
                  if (member.education != null && member.education!.isNotEmpty)
                    _buildDetailRow(Icons.school, 'शिक्षण', member.education!),
                  if (member.occupation != null && member.occupation!.isNotEmpty)
                    _buildDetailRow(Icons.work_outline, 'व्यवसाय', member.occupation!),
                  if (member.annualIncome != null)
                    _buildDetailRow(Icons.currency_rupee, 'वार्षिक उत्पन्न', '₹${member.annualIncome!.toStringAsFixed(0)}'),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Identity & Nominee Details Card
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ओळख पुरावे व वारसदार माहिती', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary)),
                  const Divider(height: 16),
                  if (member.aadhaarNumber != null && member.aadhaarNumber!.isNotEmpty)
                    _buildDetailRow(Icons.credit_card, 'आधार क्रमांक', member.aadhaarNumber!)
                  else if (member.aadhaarLastFour != null && member.aadhaarLastFour!.isNotEmpty)
                    _buildDetailRow(Icons.credit_card, 'आधार शेवटचे ४ अंक', 'XXXX-XXXX-${member.aadhaarLastFour}'),
                  if (member.panNumber != null && member.panNumber!.isNotEmpty)
                    _buildDetailRow(Icons.assignment_ind, 'पॅन क्रमांक', member.panNumber!),
                  if (member.nomineeName != null && member.nomineeName!.isNotEmpty)
                    _buildDetailRow(Icons.family_restroom, 'वारसदाराचे नाव', member.nomineeName!),
                  if (member.nomineeRelation != null && member.nomineeRelation!.isNotEmpty)
                    _buildDetailRow(Icons.link, 'नाते', member.nomineeRelation!),
                  if (member.nomineeMobile != null && member.nomineeMobile!.isNotEmpty)
                    _buildDetailRow(Icons.phone_android, 'वारसदार मोबाईल', member.nomineeMobile!),
                  if (member.nomineeAge != null)
                    _buildDetailRow(Icons.calendar_today, 'वारसदार वय', '${member.nomineeAge} वर्षे'),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Bank Details Card
            if (member.bankName != null || member.accountNumber != null)
              AppCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('बँक खाते माहिती', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary)),
                    const Divider(height: 16),
                    if (member.bankName != null && member.bankName!.isNotEmpty)
                      _buildDetailRow(Icons.account_balance, 'बँक', member.bankName!),
                    if (member.branchName != null && member.branchName!.isNotEmpty)
                      _buildDetailRow(Icons.store, 'शाखा', member.branchName!),
                    if (member.accountNumber != null && member.accountNumber!.isNotEmpty)
                      _buildDetailRow(Icons.pin, 'खाते क्रमांक', member.accountNumber!),
                    if (member.ifsc != null && member.ifsc!.isNotEmpty)
                      _buildDetailRow(Icons.confirmation_number, 'IFSC कोड', member.ifsc!),
                    if (member.accountHolderName != null && member.accountHolderName!.isNotEmpty)
                      _buildDetailRow(Icons.person, 'खातेदार नाव', member.accountHolderName!),
                  ],
                ),
              ),
            const SizedBox(height: 16),

            // Action Buttons (Edit & Delete)
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    isOutlined: true,
                    text: 'संपादित करा (Edit)',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => AddEditMemberScreen(member: member)),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _confirmDelete(member),
                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                    label: Text(
                      'हटवा (Delete)',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(Member member) async {
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

    if (confirm != true || !mounted) return;

    final memberProv = Provider.of<MemberProvider>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final success = await memberProv.deleteMember(member.id);
    if (!mounted) return;

    if (success) {
      try {
        Provider.of<DashboardProvider>(context, listen: false).loadDashboardMetrics(member.groupId);
      } catch (_) {}
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('सदस्य "${member.fullName}" यशस्वीरित्या हटवला गेला.'),
          backgroundColor: Colors.green,
        ),
      );
      navigator.pop(true); // Close profile screen
    } else {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(memberProv.lastError ?? 'सदस्य हटवताना त्रुटी आली. कृपया तपासा.'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Text('$label:', style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
