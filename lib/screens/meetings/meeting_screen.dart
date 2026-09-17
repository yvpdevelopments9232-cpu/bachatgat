import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_strings.dart';
import '../../models/meeting.dart';
import '../../providers/auth_provider.dart';
import '../../services/meeting_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import 'widgets/attendance_dialog.dart';
import 'widgets/meeting_form_dialog.dart';

class MeetingScreen extends StatefulWidget {
  const MeetingScreen({super.key});

  @override
  State<MeetingScreen> createState() => _MeetingScreenState();
}

class _MeetingScreenState extends State<MeetingScreen> {
  final MeetingService _meetingService = MeetingService();
  bool _isLoading = false;
  List<Meeting> _meetings = [];

  // Key: meetingId, Value: { 'present': int, 'absent': int, 'total': int }
  Map<String, Map<String, int>> _attendanceStats = {};

  @override
  void initState() {
    super.initState();
    _loadMeetings();
  }

  Future<void> _loadMeetings() async {
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.currentGroup != null) {
      try {
        final list = await _meetingService.fetchMeetings(auth.currentGroup!.id);
        final stats = await _meetingService.fetchAttendanceSummary(auth.currentGroup!.id);

        if (mounted) {
          setState(() {
            _meetings = list;
            _attendanceStats = stats;
          });
        }
      } catch (e) {
        debugPrint('Error loading meetings: $e');
      }
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final completedCount = _meetings.where((m) => m.status == 'completed').length;
    final scheduledCount = _meetings.where((m) => m.status == 'scheduled').length;

    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 12 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  isMobile
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              AppStrings.tr('मासिक बैठका व ठराव नोंद', 'Meetings & Resolutions Register'),
                              style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                            ),
                            Text(
                              AppStrings.tr('हजेरी, विषयसूची (अजेंडा), बैठकीतील निर्णय व इतिवृत्त', 'Attendance, Agenda, Decisions & Minutes'),
                              style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 10),
                            AppButton(
                              icon: Icons.add_rounded,
                              text: AppStrings.tr('नवीन बैठक आयोजित करा', 'Schedule Meeting'),
                              onPressed: () => _openMeetingForm(),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppStrings.tr('मासिक बैठका व ठराव नोंद', 'Meetings & Resolutions Register'),
                                  style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                ),
                                Text(
                                  AppStrings.tr('हजेरी, विषयसूची (अजेंडा), बैठकीतील निर्णय व इतिवृत्त', 'Attendance, Agenda, Decisions & Minutes'),
                                  style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                            AppButton(
                              icon: Icons.add_rounded,
                              text: AppStrings.tr('नवीन बैठक आयोजित करा', 'Schedule Meeting'),
                              onPressed: () => _openMeetingForm(),
                            ),
                          ],
                        ),
                  const SizedBox(height: 20),

                  // Meeting stats cards
                  Row(
                    children: [
                      Expanded(
                        child: AppCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppStrings.tr('एकूण बैठका', 'Total Meetings'),
                                style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${_meetings.length}',
                                style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.primary),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: AppCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppStrings.tr('पूर्ण झालेल्या बैठका', 'Completed Meetings'),
                                style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '$completedCount',
                                style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.success),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: AppCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppStrings.tr('नियोजित / आगामी', 'Scheduled'),
                                style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '$scheduledCount',
                                style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.orange),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          AppStrings.tr('बैठकांची यादी व हजेरी (Meetings & Attendance)', 'Meetings & Attendance List'),
                          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded, size: 20, color: AppColors.primary),
                        tooltip: 'रिफ्रेश (Refresh)',
                        onPressed: _loadMeetings,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (_meetings.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(36),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.calendar_month_outlined, size: 48, color: AppColors.textMuted),
                          const SizedBox(height: 12),
                          Text(
                            AppStrings.tr('कोणतीही बैठक आयोजित केलेली नाही', 'No meetings scheduled yet'),
                            style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 14),
                          AppButton(
                            text: AppStrings.tr('पहिली बैठक आयोजित करा', 'Schedule First Meeting'),
                            icon: Icons.add,
                            onPressed: () => _openMeetingForm(),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _meetings.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (ctx, i) {
                        final m = _meetings[i];
                        final isCompleted = m.status == 'completed';
                        final stat = _attendanceStats[m.id];
                        final hasAttendance = stat != null && (stat['total'] ?? 0) > 0;
                        final present = stat?['present'] ?? 0;
                        final totalAtt = stat?['total'] ?? 0;
                        final attPct = totalAtt > 0 ? ((present / totalAtt) * 100).toStringAsFixed(0) : '0';

                        return AppCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Date Block
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isCompleted ? AppColors.success.withOpacity(0.1) : AppColors.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isCompleted ? AppColors.success.withOpacity(0.3) : AppColors.primary.withOpacity(0.3),
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          m.meetingDate.split('-').length >= 3 ? m.meetingDate.split('-')[2] : '10',
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 20,
                                            color: isCompleted ? AppColors.success : AppColors.primary,
                                          ),
                                        ),
                                        Text(
                                          m.meetingDate.split('-').length >= 2 ? 'महिना ${m.meetingDate.split('-')[1]}' : 'DATE',
                                          style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 14),

                                  // Meeting Details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                'विषय: ${m.agenda}',
                                                style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            // Status Badge
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: isCompleted ? AppColors.success.withOpacity(0.12) : Colors.orange.withOpacity(0.12),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                isCompleted ? 'पूर्ण (Completed)' : 'नियोजित (Scheduled)',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  color: isCompleted ? AppColors.success : Colors.orange.shade800,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),

                                        Row(
                                          children: [
                                            const Icon(Icons.access_time_rounded, size: 14, color: AppColors.textSecondary),
                                            const SizedBox(width: 4),
                                            Text(
                                              'वेळ: ${m.meetingTime}',
                                              style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                                            ),
                                            const SizedBox(width: 12),
                                            const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondary),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                'ठिकाण: ${m.location}',
                                                style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),

                                        // Resolutions / Discussion
                                        if (m.description != null && m.description!.isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Text(
                                            'ठराव: ${m.description}',
                                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.black87),
                                          ),
                                        ],

                                        // Minutes of meeting
                                        if (m.minutesOfMeeting != null && m.minutesOfMeeting!.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            'इतिवृत्त: ${m.minutesOfMeeting}',
                                            style: GoogleFonts.poppins(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey.shade700),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 18),

                              // Bottom Row: Attendance badge & Action Buttons (Attendance, Edit, Delete)
                              isMobile
                                  ? Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: hasAttendance ? AppColors.success.withOpacity(0.08) : Colors.grey.shade100,
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(
                                                    color: hasAttendance ? AppColors.success.withOpacity(0.3) : Colors.grey.shade300,
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      hasAttendance ? Icons.check_circle_rounded : Icons.pending_actions_rounded,
                                                      size: 14,
                                                      color: hasAttendance ? AppColors.success : Colors.grey.shade700,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Expanded(
                                                      child: Text(
                                                        hasAttendance
                                                            ? 'हजेरी: $present/$totalAtt ($attPct%)'
                                                            : 'हजेरी नोंद नाही',
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: GoogleFonts.poppins(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w600,
                                                          color: hasAttendance ? AppColors.success : Colors.grey.shade700,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            IconButton(
                                              icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.primary),
                                              tooltip: 'बैठक संपादन करा (Edit Meeting)',
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                              onPressed: () => _openMeetingForm(m),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.danger),
                                              tooltip: 'बैठक हटवा (Delete Meeting)',
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                              onPressed: () => _confirmDeleteMeeting(m, auth),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: hasAttendance ? AppColors.success : AppColors.primary,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                          ),
                                          icon: const Icon(Icons.co_present_rounded, size: 16, color: Colors.white),
                                          label: Text(
                                            hasAttendance ? 'हजेरी पहा / बदला (Attendance)' : 'हजेरी घ्या (Take Attendance)',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                          onPressed: () => _openAttendanceDialog(m),
                                        ),
                                      ],
                                    )
                                  : Row(
                                      children: [
                                        // Attendance Status Tag
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: hasAttendance ? AppColors.success.withOpacity(0.08) : Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: hasAttendance ? AppColors.success.withOpacity(0.3) : Colors.grey.shade300,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                hasAttendance ? Icons.check_circle_rounded : Icons.pending_actions_rounded,
                                                size: 14,
                                                color: hasAttendance ? AppColors.success : Colors.grey.shade700,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                hasAttendance
                                                    ? 'हजेरी: $present/$totalAtt ($attPct%)'
                                                    : 'हजेरी नोंद नाही (Not Marked)',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: hasAttendance ? AppColors.success : Colors.grey.shade700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Spacer(),

                                        // ATTENDANCE BUTTON
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: hasAttendance ? AppColors.success : AppColors.primary,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                          ),
                                          icon: const Icon(Icons.co_present_rounded, size: 15, color: Colors.white),
                                          label: Text(
                                            hasAttendance ? 'हजेरी पहा/बदला' : 'हजेरी घ्या (Take Attendance)',
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                          ),
                                          onPressed: () => _openAttendanceDialog(m),
                                        ),
                                        const SizedBox(width: 8),

                                        // EDIT BUTTON
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.primary),
                                          tooltip: 'बैठक संपादन करा (Edit Meeting)',
                                          onPressed: () => _openMeetingForm(m),
                                        ),

                                        // DELETE BUTTON
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.danger),
                                          tooltip: 'बैठक हटवा (Delete Meeting)',
                                          onPressed: () => _confirmDeleteMeeting(m, auth),
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
            ),
    );
  }

  // Open Create / Edit Meeting Form
  void _openMeetingForm([Meeting? meeting]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => MeetingFormDialog(
        meeting: meeting,
        onSaved: _loadMeetings,
      ),
    );
  }

  // Open Attendance Dialog
  void _openAttendanceDialog(Meeting meeting) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AttendanceDialog(
        meeting: meeting,
        onSaved: _loadMeetings,
      ),
    );
  }

  // Confirm Delete Meeting
  Future<void> _confirmDeleteMeeting(Meeting meeting, AuthProvider auth) async {
    final groupId = auth.currentGroup?.id ?? meeting.groupId;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 24),
            SizedBox(width: 10),
            Text('बैठक हटवायची आहे का?'),
          ],
        ),
        content: Text(
          'तुम्ही दिनांक ${meeting.meetingDate} ची "${meeting.agenda}" बैठक हटवू इच्छिता का? या बैठकीची सर्व हजेरी नोंदही कायमस्वरूपी हटवली जाईल.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(AppStrings.cancel, style: const TextStyle(color: Colors.black87)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('होय, हटवा (Delete)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      final ok = await _meetingService.deleteMeeting(meeting.id, groupId);
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (ok) {
        _loadMeetings();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('बैठक यशस्वीरीत्या हटवण्यात आली!'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('बैठक हटवताना त्रुटी आली. कृपया पुन्हा प्रयत्न करा.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }
}
