import 'package:flutter/foundation.dart';
import '../models/meeting.dart';
import '../models/member.dart';
import 'supabase_service.dart';

class MeetingService {
  final SupabaseService _service = SupabaseService();

  // 1. FETCH ALL MEETINGS FOR A GROUP
  Future<List<Meeting>> fetchMeetings(String groupId) async {
    try {
      final res = await _service.client
          .from('meetings')
          .select()
          .eq('group_id', groupId)
          .order('meeting_date', ascending: false);

      return (res as List).map((m) => Meeting.fromJson(m)).toList();
    } catch (e) {
      debugPrint('Error fetching meetings: $e');
      return [];
    }
  }

  // 2. CREATE A NEW MEETING
  Future<Meeting?> createMeeting(Meeting meeting) async {
    try {
      final res = await _service.client.from('meetings').insert(meeting.toJson()).select().single();
      return Meeting.fromJson(res);
    } catch (e) {
      debugPrint('Error creating meeting: $e');
      return null;
    }
  }

  // 3. UPDATE AN EXISTING MEETING
  Future<bool> updateMeeting(Meeting meeting) async {
    try {
      await _service.client.from('meetings').update({
        'meeting_date': meeting.meetingDate,
        'meeting_time': meeting.meetingTime,
        'location': meeting.location,
        'meeting_type': meeting.meetingType,
        'agenda': meeting.agenda,
        'description': meeting.description,
        'minutes_of_meeting': meeting.minutesOfMeeting,
        'status': meeting.status,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', meeting.id).eq('group_id', meeting.groupId);

      return true;
    } catch (e) {
      debugPrint('Error updating meeting: $e');
      return false;
    }
  }

  // 4. DELETE A MEETING (AND CASCADES ITS ATTENDANCE)
  Future<bool> deleteMeeting(String meetingId, String groupId) async {
    try {
      // Clean up attendance first for safety
      try {
        await _service.client
            .from('meeting_attendance')
            .delete()
            .eq('meeting_id', meetingId)
            .eq('group_id', groupId);
      } catch (attErr) {
        debugPrint('Attendance delete cascade note: $attErr');
      }

      await _service.client
          .from('meetings')
          .delete()
          .eq('id', meetingId)
          .eq('group_id', groupId);

      return true;
    } catch (e) {
      debugPrint('Error deleting meeting: $e');
      return false;
    }
  }

  // 5. FETCH ATTENDANCE FOR A SPECIFIC MEETING
  Future<List<MeetingAttendance>> fetchMeetingAttendance({
    required String meetingId,
    required String groupId,
    List<Member>? allMembers,
  }) async {
    try {
      dynamic res;
      try {
        res = await _service.client
            .from('meeting_attendance')
            .select('*, member:members!meeting_attendance_member_id_fkey(full_name, member_code)')
            .eq('meeting_id', meetingId)
            .eq('group_id', groupId);
      } catch (relErr) {
        debugPrint('Meeting attendance relation join note: $relErr');
        res = await _service.client
            .from('meeting_attendance')
            .select()
            .eq('meeting_id', meetingId)
            .eq('group_id', groupId);
      }

      final Map<String, Member> memberMap = {
        for (var m in (allMembers ?? [])) m.id: m
      };

      final List<MeetingAttendance> list = [];
      for (var row in (res as List)) {
        final memberId = row['member_id']?.toString() ?? '';
        final memberData = (row['member'] ?? row['members']) as Map<String, dynamic>?;

        String? name = memberData?['full_name'];
        if ((name == null || name.isEmpty) && memberMap.containsKey(memberId)) {
          name = memberMap[memberId]!.fullName;
        }

        String? code = memberData?['member_code'];
        if ((code == null || code.isEmpty) && memberMap.containsKey(memberId)) {
          code = memberMap[memberId]!.memberCode;
        }

        list.add(MeetingAttendance(
          id: row['id']?.toString() ?? '',
          groupId: groupId,
          meetingId: meetingId,
          memberId: memberId,
          memberName: name,
          memberCode: code,
          status: row['status']?.toString() ?? 'present',
          arrivalTime: row['arrival_time']?.toString(),
          remarks: row['remarks']?.toString(),
        ));
      }

      return list;
    } catch (e) {
      debugPrint('Error fetching meeting attendance: $e');
      return [];
    }
  }

  // 6. SAVE / UPDATE ATTENDANCE LIST (UPSERT / REPLACE)
  Future<bool> saveMeetingAttendance({
    required String meetingId,
    required String groupId,
    required List<MeetingAttendance> attendances,
  }) async {
    try {
      if (attendances.isEmpty) return true;

      final rows = attendances.map((a) => {
        'group_id': groupId,
        'meeting_id': meetingId,
        'member_id': a.memberId,
        'status': a.status,
        if (a.arrivalTime != null && a.arrivalTime!.isNotEmpty) 'arrival_time': a.arrivalTime,
        if (a.remarks != null && a.remarks!.isNotEmpty) 'remarks': a.remarks,
        'updated_at': DateTime.now().toIso8601String(),
      }).toList();

      // Upsert into meeting_attendance using UNIQUE (meeting_id, member_id)
      await _service.client.from('meeting_attendance').upsert(
        rows,
        onConflict: 'meeting_id,member_id',
      );

      return true;
    } catch (e) {
      debugPrint('Error saving meeting attendance: $e');
      // Fallback: delete and re-insert
      try {
        await _service.client
            .from('meeting_attendance')
            .delete()
            .eq('meeting_id', meetingId)
            .eq('group_id', groupId);

        final rows = attendances.map((a) => a.toJson()).toList();
        await _service.client.from('meeting_attendance').insert(rows);
        return true;
      } catch (fallbackErr) {
        debugPrint('Fallback attendance insert error: $fallbackErr');
        return false;
      }
    }
  }

  // 7. DELETE ALL ATTENDANCE FOR A MEETING
  Future<bool> deleteMeetingAttendance(String meetingId, String groupId) async {
    try {
      await _service.client
          .from('meeting_attendance')
          .delete()
          .eq('meeting_id', meetingId)
          .eq('group_id', groupId);
      return true;
    } catch (e) {
      debugPrint('Error deleting meeting attendance: $e');
      return false;
    }
  }

  // 8. FETCH ATTENDANCE SUMMARY STATS FOR ALL MEETINGS IN GROUP
  Future<Map<String, Map<String, int>>> fetchAttendanceSummary(String groupId) async {
    try {
      final res = await _service.client
          .from('meeting_attendance')
          .select('meeting_id, status')
          .eq('group_id', groupId);

      final Map<String, Map<String, int>> map = {};
      for (var row in (res as List)) {
        final mId = row['meeting_id']?.toString() ?? '';
        final status = row['status']?.toString() ?? 'present';

        map.putIfAbsent(mId, () => {'present': 0, 'absent': 0, 'late': 0, 'excused': 0, 'total': 0});
        map[mId]!['total'] = (map[mId]!['total'] ?? 0) + 1;
        map[mId]![status] = (map[mId]![status] ?? 0) + 1;
      }
      return map;
    } catch (e) {
      debugPrint('Error fetching attendance summary: $e');
      return {};
    }
  }
}
