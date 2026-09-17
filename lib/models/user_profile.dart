class UserProfile {
  final String id;
  final String groupId;
  final String fullName;
  final String mobile;
  final String? email;
  final String role; // admin, president, secretary, treasurer, employee
  final String status;
  final bool isMainAdmin;
  final String? profilePhotoUrl;

  UserProfile({
    required this.id,
    required this.groupId,
    required this.fullName,
    required this.mobile,
    this.email,
    required this.role,
    this.status = 'active',
    this.isMainAdmin = false,
    this.profilePhotoUrl,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'],
      groupId: json['group_id'] ?? '',
      fullName: json['full_name'] ?? '',
      mobile: json['mobile'] ?? '',
      email: json['email'],
      role: json['role'] ?? 'employee',
      status: json['status'] ?? 'active',
      isMainAdmin: json['is_main_admin'] ?? false,
      profilePhotoUrl: json['profile_photo_url'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'group_id': groupId,
    'full_name': fullName,
    'mobile': mobile,
    'email': email,
    'role': role,
    'status': status,
    'is_main_admin': isMainAdmin,
    'profile_photo_url': profilePhotoUrl,
  };

  UserProfile copyWith({
    String? id,
    String? groupId,
    String? fullName,
    String? mobile,
    String? email,
    String? role,
    String? status,
    bool? isMainAdmin,
    String? profilePhotoUrl,
  }) {
    return UserProfile(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      fullName: fullName ?? this.fullName,
      mobile: mobile ?? this.mobile,
      email: email ?? this.email,
      role: role ?? this.role,
      status: status ?? this.status,
      isMainAdmin: isMainAdmin ?? this.isMainAdmin,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
    );
  }
}
