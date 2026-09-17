class Meeting {
  final String id;
  final String groupId;
  final String meetingDate;
  final String meetingTime;
  final String location;
  final String meetingType;
  final String agenda;
  final String? description;
  final String? minutesOfMeeting;
  final String status;

  Meeting({
    required this.id,
    required this.groupId,
    required this.meetingDate,
    required this.meetingTime,
    required this.location,
    this.meetingType = 'monthly',
    required this.agenda,
    this.description,
    this.minutesOfMeeting,
    this.status = 'scheduled',
  });

  bool get isCompleted => status == 'completed';
  bool get isScheduled => status == 'scheduled';
  bool get isCancelled => status == 'cancelled';

  factory Meeting.fromJson(Map<String, dynamic> json) {
    return Meeting(
      id: json['id']?.toString() ?? '',
      groupId: json['group_id']?.toString() ?? '',
      meetingDate: json['meeting_date']?.toString() ?? '',
      meetingTime: json['meeting_time']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      meetingType: json['meeting_type']?.toString() ?? 'monthly',
      agenda: json['agenda']?.toString() ?? '',
      description: json['description']?.toString(),
      minutesOfMeeting: json['minutes_of_meeting']?.toString(),
      status: json['status']?.toString() ?? 'scheduled',
    );
  }

  Map<String, dynamic> toJson() => {
    'group_id': groupId,
    'meeting_date': meetingDate,
    'meeting_time': meetingTime,
    'location': location,
    'meeting_type': meetingType,
    'agenda': agenda,
    if (description != null) 'description': description,
    if (minutesOfMeeting != null) 'minutes_of_meeting': minutesOfMeeting,
    'status': status,
  };
}

class MeetingAttendance {
  final String id;
  final String groupId;
  final String meetingId;
  final String memberId;
  final String? memberName;
  final String? memberCode;
  final String status; // 'present', 'absent', 'late', 'excused'
  final String? arrivalTime;
  final String? remarks;

  MeetingAttendance({
    required this.id,
    required this.groupId,
    required this.meetingId,
    required this.memberId,
    this.memberName,
    this.memberCode,
    this.status = 'present',
    this.arrivalTime,
    this.remarks,
  });

  bool get isPresent => status == 'present';
  bool get isAbsent => status == 'absent';
  bool get isLate => status == 'late';
  bool get isExcused => status == 'excused';

  factory MeetingAttendance.fromJson(Map<String, dynamic> json) {
    final memberData = (json['member'] ?? json['members']) as Map<String, dynamic>?;
    return MeetingAttendance(
      id: json['id']?.toString() ?? '',
      groupId: json['group_id']?.toString() ?? '',
      meetingId: json['meeting_id']?.toString() ?? '',
      memberId: json['member_id']?.toString() ?? '',
      memberName: memberData?['full_name'] ?? json['member_name'],
      memberCode: memberData?['member_code'] ?? json['member_code'],
      status: json['status']?.toString() ?? 'present',
      arrivalTime: json['arrival_time']?.toString(),
      remarks: json['remarks']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'group_id': groupId,
    'meeting_id': meetingId,
    'member_id': memberId,
    'status': status,
    if (arrivalTime != null && arrivalTime!.isNotEmpty) 'arrival_time': arrivalTime,
    if (remarks != null && remarks!.isNotEmpty) 'remarks': remarks,
  };

  MeetingAttendance copyWith({
    String? status,
    String? remarks,
    String? arrivalTime,
  }) {
    return MeetingAttendance(
      id: id,
      groupId: groupId,
      meetingId: meetingId,
      memberId: memberId,
      memberName: memberName,
      memberCode: memberCode,
      status: status ?? this.status,
      arrivalTime: arrivalTime ?? this.arrivalTime,
      remarks: remarks ?? this.remarks,
    );
  }
}
