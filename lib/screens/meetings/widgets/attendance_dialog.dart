import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_strings.dart';
import '../../../models/meeting.dart';
import '../../../models/member.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/member_provider.dart';
import '../../../services/meeting_service.dart';

class AttendanceDialog extends StatefulWidget {
  final Meeting meeting;
  final VoidCallback onSaved;

  const AttendanceDialog({
    super.key,
    required this.meeting,
    required this.onSaved,
  });

  @override
  State<AttendanceDialog> createState() => _AttendanceDialogState();
}

class _AttendanceDialogState extends State<AttendanceDialog> {
  final MeetingService _meetingService = MeetingService();
  bool _isLoading = true;
  bool _isSaving = false;

  // Key: memberId, Value: MeetingAttendance
  Map<String, MeetingAttendance> _attendanceMap = {};
  List<Member> _members = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final memberProv = Provider.of<MemberProvider>(context, listen: false);
    final groupId = auth.currentGroup?.id ?? widget.meeting.groupId;

    _members = memberProv.members.where((m) => m.isActive).toList();
    if (_members.isEmpty) {
      _members = memberProv.members;
    }

    // Fetch existing attendance from Supabase
    final existing = await _meetingService.fetchMeetingAttendance(
      meetingId: widget.meeting.id,
      groupId: groupId,
      allMembers: _members,
    );

    final Map<String, MeetingAttendance> map = {};
    for (var a in existing) {
      map[a.memberId] = a;
    }

    // Initialize missing members as 'present' by default
    for (var m in _members) {
      if (!map.containsKey(m.id)) {
        map[m.id] = MeetingAttendance(
          id: '',
          groupId: groupId,
          meetingId: widget.meeting.id,
          memberId: m.id,
          memberName: m.fullName,
          memberCode: m.memberCode,
          status: 'present',
        );
      }
    }

    if (mounted) {
      setState(() {
        _attendanceMap = map;
        _isLoading = false;
      });
    }
  }

  void _markAll(String status) {
    setState(() {
      for (var key in _attendanceMap.keys) {
        _attendanceMap[key] = _attendanceMap[key]!.copyWith(status: status);
      }
    });
  }

  int get _presentCount => _attendanceMap.values.where((a) => a.isPresent).length;
  int get _absentCount => _attendanceMap.values.where((a) => a.isAbsent).length;
  int get _excusedCount => _attendanceMap.values.where((a) => a.isExcused || a.isLate).length;
  int get _totalCount => _attendanceMap.length;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 40,
        vertical: isMobile ? 16 : 24,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: isMobile ? double.infinity : 680,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
        padding: EdgeInsets.all(isMobile ? 14 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Close ('X') Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.co_present_rounded, color: AppColors.primary, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'बैठक हजेरी नोंद (Attendance)',
                              style: GoogleFonts.poppins(fontSize: isMobile ? 15 : 16, fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'तारीख: ${widget.meeting.meetingDate} • वेळ: ${widget.meeting.meetingTime} • ${widget.meeting.agenda}',
                              style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 24),
                  tooltip: 'बंद करा (Close)',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 20),

            // Live KPI Stats & Quick Action Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  // KPI badges
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _buildCountBadge('हजर', _presentCount, AppColors.success),
                      _buildCountBadge('गैरहजर', _absentCount, AppColors.danger),
                      _buildCountBadge('रजा', _excusedCount, Colors.amber.shade800),
                      _buildCountBadge('एकूण', _totalCount, AppColors.primary),
                    ],
                  ),

                  // Quick All Buttons
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.success,
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.done_all_rounded, size: 15),
                        label: const Text('सर्व हजर', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        onPressed: () => _markAll('present'),
                      ),
                      const SizedBox(width: 6),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.danger,
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.remove_circle_outline_rounded, size: 15),
                        label: const Text('सर्व गैरहजर', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        onPressed: () => _markAll('absent'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Member Attendance List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _members.isEmpty
                      ? Center(
                          child: Text('गटात सभासद उपलब्ध नाहीत', style: GoogleFonts.poppins(color: AppColors.textSecondary)),
                        )
                      : ListView.separated(
                          itemCount: _members.length,
                          separatorBuilder: (c, i) => const SizedBox(height: 6),
                          itemBuilder: (ctx, i) {
                            final m = _members[i];
                            final att = _attendanceMap[m.id] ??
                                MeetingAttendance(
                                  id: '',
                                  groupId: widget.meeting.groupId,
                                  meetingId: widget.meeting.id,
                                  memberId: m.id,
                                  memberName: m.fullName,
                                  memberCode: m.memberCode,
                                );

                            final isPresent = att.status == 'present';
                            final isAbsent = att.status == 'absent';

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isPresent
                                      ? AppColors.success.withOpacity(0.3)
                                      : (isAbsent ? AppColors.danger.withOpacity(0.3) : Colors.grey.shade300),
                                ),
                              ),
                              child: isMobile
                                  ? Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 14,
                                              backgroundColor: isPresent
                                                  ? AppColors.success.withOpacity(0.12)
                                                  : (isAbsent ? AppColors.danger.withOpacity(0.12) : Colors.grey.shade200),
                                              child: Text(
                                                m.fullName.isNotEmpty ? m.fullName[0] : 'M',
                                                style: TextStyle(
                                                  color: isPresent ? AppColors.success : (isAbsent ? AppColors.danger : Colors.black87),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                '${m.fullName} (${m.memberCode})',
                                                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          children: [
                                            _buildStatusChip('हजर', 'present', att, AppColors.success),
                                            _buildStatusChip('गैरहजर', 'absent', att, AppColors.danger),
                                            _buildStatusChip('रजा', 'excused', att, Colors.amber.shade800),
                                            _buildStatusChip('उशीर', 'late', att, Colors.orange),
                                          ],
                                        ),
                                      ],
                                    )
                                  : Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 16,
                                          backgroundColor: isPresent
                                              ? AppColors.success.withOpacity(0.12)
                                              : (isAbsent ? AppColors.danger.withOpacity(0.12) : Colors.grey.shade200),
                                          child: Text(
                                            m.fullName.isNotEmpty ? m.fullName[0] : 'M',
                                            style: TextStyle(
                                              color: isPresent ? AppColors.success : (isAbsent ? AppColors.danger : Colors.black87),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),

                                        // Name & Code
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                m.fullName,
                                                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
                                              ),
                                              Text(
                                                'सभासद क्र: ${m.memberCode}',
                                                style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textSecondary),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Status Selection Chips
                                        Wrap(
                                          spacing: 6,
                                          children: [
                                            _buildStatusChip('हजर', 'present', att, AppColors.success),
                                            _buildStatusChip('गैरहजर', 'absent', att, AppColors.danger),
                                            _buildStatusChip('रजा', 'excused', att, Colors.amber.shade800),
                                            _buildStatusChip('उशीर', 'late', att, Colors.orange),
                                          ],
                                        ),
                                      ],
                                    ),
                            );
                          },
                        ),
            ),
            const SizedBox(height: 14),

            // Bottom Actions: Clear & Save
            isMobile
                ? Row(
                    children: [
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.danger,
                          side: const BorderSide(color: AppColors.danger),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        ),
                        onPressed: _isSaving ? null : _confirmDeleteAttendance,
                        child: const Text('हटवा', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: _isSaving
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.check_rounded, color: Colors.white, size: 16),
                          label: Text(
                            _isSaving ? 'जतन...' : 'हजेरी जतन करा',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          onPressed: _isSaving ? null : _handleSave,
                        ),
                      ),
                      const SizedBox(width: 6),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(AppStrings.cancel, style: const TextStyle(color: Colors.black87, fontSize: 12)),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      // Clear Attendance Button
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.danger,
                          side: const BorderSide(color: AppColors.danger),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                        label: const Text('हजेरी हटवा (Delete)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: _isSaving ? null : _confirmDeleteAttendance,
                      ),
                      const Spacer(),

                      // Cancel Button with X
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(AppStrings.cancel, style: const TextStyle(color: Colors.black87)),
                      ),
                      const SizedBox(width: 10),

                      // Save Attendance Button
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: _isSaving
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                        label: Text(
                          _isSaving ? 'जतन होत आहे...' : 'हजेरी जतन करा (Save Attendance)',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        onPressed: _isSaving ? null : _handleSave,
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, String statusKey, MeetingAttendance att, Color activeColor) {
    final isSelected = att.status == statusKey;
    return InkWell(
      onTap: () {
        setState(() {
          _attendanceMap[att.memberId] = att.copyWith(status: statusKey);
        });
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isSelected ? activeColor : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildCountBadge(String label, int count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          '$label: $count',
          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
      ],
    );
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final groupId = auth.currentGroup?.id ?? widget.meeting.groupId;

    final list = _attendanceMap.values.toList();
    final ok = await _meetingService.saveMeetingAttendance(
      meetingId: widget.meeting.id,
      groupId: groupId,
      attendances: list,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (ok) {
      widget.onSaved();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('बैठक हजेरी यशस्वीरीत्या जतन झाली! (हजर: $_presentCount, गैरहजर: $_absentCount)'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('हजेरी जतन करताना त्रुटी आली. कृपया पुन्हा प्रयत्न करा.'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _confirmDeleteAttendance() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('हजेरी हटवायची आहे का?'),
        content: const Text('या बैठकीची नोंदवलेली सर्व सभासद हजेरी हटवली जाईल. तुम्हाला पुढे जायचे आहे का?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('नाही (Cancel)')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('होय, हटवा (Delete)', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final groupId = auth.currentGroup?.id ?? widget.meeting.groupId;

      setState(() => _isSaving = true);
      final ok = await _meetingService.deleteMeetingAttendance(widget.meeting.id, groupId);
      if (!mounted) return;
      setState(() => _isSaving = false);

      if (ok) {
        widget.onSaved();
        navigator.pop();
        messenger.showSnackBar(
          const SnackBar(content: Text('हजेरी नोंद यशस्वीरीत्या हटवण्यात आली!'), backgroundColor: AppColors.success),
        );
      }
    }
  }
}
