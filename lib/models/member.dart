class Member {
  final String id;
  final String groupId;
  final String memberCode; // MBG01
  final String fullName;
  final String mobileNumber;
  final String? alternateMobile;
  final String? dateOfBirth;
  final String gender;
  final String? address;
  final String? village;
  final String? taluka;
  final String? district;
  final String? pincode;
  final String? aadhaarNumber;
  final String? aadhaarLastFour;
  final String? panNumber;
  final String? education;
  final String? occupation;
  final double? annualIncome;
  final String? nomineeName;
  final String? nomineeRelation;
  final String? nomineeMobile;
  final int? nomineeAge;
  final String? bankName;
  final String? branchName;
  final String? accountNumber;
  final String? ifsc;
  final String? accountHolderName;
  final String roleInGroup; // सदस्य, अध्यक्ष, सचिव, खजिनदार
  final String status;
  final String? remarks;
  final String? photoUrl;
  final String? signatureUrl;
  final String? aadhaarDocUrl;
  final String? panDocUrl;
  final String? passbookDocUrl;
  final String? joiningDate;

  Member({
    required this.id,
    required this.groupId,
    required this.memberCode,
    required this.fullName,
    required this.mobileNumber,
    this.alternateMobile,
    this.dateOfBirth,
    this.gender = 'Female',
    this.address,
    this.village,
    this.taluka,
    this.district,
    this.pincode,
    this.aadhaarNumber,
    this.aadhaarLastFour,
    this.panNumber,
    this.education,
    this.occupation,
    this.annualIncome,
    this.nomineeName,
    this.nomineeRelation,
    this.nomineeMobile,
    this.nomineeAge,
    this.bankName,
    this.branchName,
    this.accountNumber,
    this.ifsc,
    this.accountHolderName,
    this.roleInGroup = 'सदस्य',
    this.status = 'active',
    this.remarks,
    this.photoUrl,
    this.signatureUrl,
    this.aadhaarDocUrl,
    this.panDocUrl,
    this.passbookDocUrl,
    this.joiningDate,
  });

  bool get isActive => status == 'active';

  factory Member.fromJson(Map<String, dynamic> json) {
    // Resolve aadhaar last 4 if full aadhaar is present
    String? aadhaar = json['aadhaar_number']?.toString();
    String? lastFour = json['aadhaar_last_four']?.toString();
    if ((lastFour == null || lastFour.isEmpty) && aadhaar != null && aadhaar.length >= 4) {
      lastFour = aadhaar.substring(aadhaar.length - 4);
    }

    return Member(
      id: json['id']?.toString() ?? '',
      groupId: json['group_id']?.toString() ?? '',
      memberCode: json['member_code']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      mobileNumber: json['mobile_number']?.toString() ?? '',
      alternateMobile: json['alternate_mobile']?.toString(),
      dateOfBirth: json['date_of_birth']?.toString(),
      gender: json['gender']?.toString() ?? 'Female',
      address: json['address']?.toString(),
      village: json['village']?.toString(),
      taluka: json['taluka']?.toString(),
      district: json['district']?.toString(),
      pincode: json['pincode']?.toString(),
      aadhaarNumber: aadhaar,
      aadhaarLastFour: lastFour,
      panNumber: json['pan_number']?.toString(),
      education: json['education']?.toString(),
      occupation: json['occupation']?.toString(),
      annualIncome: json['annual_income'] != null ? (json['annual_income'] as num).toDouble() : null,
      nomineeName: json['nominee_name']?.toString(),
      nomineeRelation: json['nominee_relation']?.toString(),
      nomineeMobile: json['nominee_mobile']?.toString(),
      nomineeAge: json['nominee_age'] != null ? (json['nominee_age'] as num).toInt() : null,
      bankName: json['bank_name']?.toString(),
      branchName: json['branch_name']?.toString(),
      accountNumber: json['account_number']?.toString(),
      ifsc: json['ifsc']?.toString(),
      accountHolderName: json['account_holder_name']?.toString(),
      roleInGroup: json['role_in_group']?.toString() ?? 'सदस्य',
      status: json['status']?.toString() ?? 'active',
      remarks: json['remarks']?.toString(),
      photoUrl: json['photo_url']?.toString(),
      signatureUrl: json['signature_url']?.toString(),
      aadhaarDocUrl: json['aadhaar_doc_url']?.toString(),
      panDocUrl: json['pan_doc_url']?.toString(),
      passbookDocUrl: json['passbook_doc_url']?.toString(),
      joiningDate: json['joining_date']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    if (id.isNotEmpty) 'id': id,
    'group_id': groupId,
    'member_code': memberCode,
    'full_name': fullName,
    'mobile_number': mobileNumber,
    if (alternateMobile != null && alternateMobile!.isNotEmpty) 'alternate_mobile': alternateMobile,
    if (dateOfBirth != null && dateOfBirth!.isNotEmpty) 'date_of_birth': dateOfBirth,
    'gender': gender,
    if (address != null && address!.isNotEmpty) 'address': address,
    if (village != null && village!.isNotEmpty) 'village': village,
    if (taluka != null && taluka!.isNotEmpty) 'taluka': taluka,
    if (district != null && district!.isNotEmpty) 'district': district,
    if (pincode != null && pincode!.isNotEmpty) 'pincode': pincode,
    if (aadhaarNumber != null && aadhaarNumber!.isNotEmpty) 'aadhaar_number': aadhaarNumber,
    if (aadhaarLastFour != null && aadhaarLastFour!.isNotEmpty) 'aadhaar_last_four': aadhaarLastFour,
    if (panNumber != null && panNumber!.isNotEmpty) 'pan_number': panNumber,
    if (education != null && education!.isNotEmpty) 'education': education,
    if (occupation != null && occupation!.isNotEmpty) 'occupation': occupation,
    if (annualIncome != null) 'annual_income': annualIncome,
    if (nomineeName != null && nomineeName!.isNotEmpty) 'nominee_name': nomineeName,
    if (nomineeRelation != null && nomineeRelation!.isNotEmpty) 'nominee_relation': nomineeRelation,
    if (nomineeMobile != null && nomineeMobile!.isNotEmpty) 'nominee_mobile': nomineeMobile,
    if (nomineeAge != null) 'nominee_age': nomineeAge,
    if (bankName != null && bankName!.isNotEmpty) 'bank_name': bankName,
    if (branchName != null && branchName!.isNotEmpty) 'branch_name': branchName,
    if (accountNumber != null && accountNumber!.isNotEmpty) 'account_number': accountNumber,
    if (ifsc != null && ifsc!.isNotEmpty) 'ifsc': ifsc,
    if (accountHolderName != null && accountHolderName!.isNotEmpty) 'account_holder_name': accountHolderName,
    'role_in_group': roleInGroup,
    'status': status,
    if (remarks != null && remarks!.isNotEmpty) 'remarks': remarks,
    if (photoUrl != null && photoUrl!.isNotEmpty) 'photo_url': photoUrl,
    if (signatureUrl != null && signatureUrl!.isNotEmpty) 'signature_url': signatureUrl,
    if (aadhaarDocUrl != null && aadhaarDocUrl!.isNotEmpty) 'aadhaar_doc_url': aadhaarDocUrl,
    if (panDocUrl != null && panDocUrl!.isNotEmpty) 'pan_doc_url': panDocUrl,
    if (passbookDocUrl != null && passbookDocUrl!.isNotEmpty) 'passbook_doc_url': passbookDocUrl,
    if (joiningDate != null && joiningDate!.isNotEmpty) 'joining_date': joiningDate,
  };

  /// Cloud-safe JSON payload stripped of columns that do not exist on Supabase PostgreSQL schema
  Map<String, dynamic> toCloudJson() {
    final map = toJson();
    map.remove('remarks');
    map.remove('aadhaar_last_four');
    return map;
  }
}
