class BachatGroup {
  final String id;
  final String groupName;
  final String? registrationNumber;
  final String? address;
  final String village;
  final String taluka;
  final String district;
  final String? mobile;
  final String? presidentName;
  final String? secretaryName;
  final String? treasurerName;
  final double monthlySavingsAmount;
  final String? logoUrl;

  BachatGroup({
    required this.id,
    required this.groupName,
    this.registrationNumber,
    this.address,
    required this.village,
    required this.taluka,
    required this.district,
    this.mobile,
    this.presidentName,
    this.secretaryName,
    this.treasurerName,
    this.monthlySavingsAmount = 200.0,
    this.logoUrl,
  });

  factory BachatGroup.fromJson(Map<String, dynamic> json) {
    return BachatGroup(
      id: json['id'],
      groupName: json['group_name'] ?? 'Sakhi Bachat Gat',
      registrationNumber: json['registration_number'],
      address: json['address'],
      village: json['village'] ?? '',
      taluka: json['taluka'] ?? '',
      district: json['district'] ?? '',
      mobile: json['mobile'],
      presidentName: json['president_name'],
      secretaryName: json['secretary_name'],
      treasurerName: json['treasurer_name'],
      monthlySavingsAmount: (json['monthly_savings_amount'] as num?)?.toDouble() ?? 200.0,
      logoUrl: json['logo_url'],
    );
  }

  Map<String, dynamic> toJson() => {
    'group_name': groupName,
    'registration_number': registrationNumber,
    'address': address,
    'village': village,
    'taluka': taluka,
    'district': district,
    'mobile': mobile,
    'president_name': presidentName,
    'secretary_name': secretaryName,
    'treasurer_name': treasurerName,
    'monthly_savings_amount': monthlySavingsAmount,
    'logo_url': logoUrl,
  };

  BachatGroup copyWith({
    String? id,
    String? groupName,
    String? registrationNumber,
    String? address,
    String? village,
    String? taluka,
    String? district,
    String? mobile,
    String? presidentName,
    String? secretaryName,
    String? treasurerName,
    double? monthlySavingsAmount,
    String? logoUrl,
  }) {
    return BachatGroup(
      id: id ?? this.id,
      groupName: groupName ?? this.groupName,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      address: address ?? this.address,
      village: village ?? this.village,
      taluka: taluka ?? this.taluka,
      district: district ?? this.district,
      mobile: mobile ?? this.mobile,
      presidentName: presidentName ?? this.presidentName,
      secretaryName: secretaryName ?? this.secretaryName,
      treasurerName: treasurerName ?? this.treasurerName,
      monthlySavingsAmount: monthlySavingsAmount ?? this.monthlySavingsAmount,
      logoUrl: logoUrl ?? this.logoUrl,
    );
  }
}
