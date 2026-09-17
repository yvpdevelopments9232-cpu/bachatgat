import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/member.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/member_provider.dart';

class AddEditMemberScreen extends StatefulWidget {
  final Member? member; // If null => Add Mode, else => Edit Mode

  const AddEditMemberScreen({super.key, this.member});

  @override
  State<AddEditMemberScreen> createState() => _AddEditMemberScreenState();
}

class _AddEditMemberScreenState extends State<AddEditMemberScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Controllers
  late TextEditingController _codeCtrl;
  late TextEditingController _nameCtrl;
  late TextEditingController _mobileCtrl;
  late TextEditingController _altMobileCtrl;
  late TextEditingController _dobCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _villageCtrl;
  late TextEditingController _talukaCtrl;
  late TextEditingController _districtCtrl;
  late TextEditingController _pincodeCtrl;
  late TextEditingController _aadhaarCtrl;
  late TextEditingController _panCtrl;
  late TextEditingController _educationCtrl;
  late TextEditingController _occupationCtrl;
  late TextEditingController _annualIncomeCtrl;
  late TextEditingController _nomineeNameCtrl;
  late TextEditingController _nomineeRelationCtrl;
  late TextEditingController _nomineeMobileCtrl;
  late TextEditingController _nomineeAgeCtrl;
  late TextEditingController _bankNameCtrl;
  late TextEditingController _branchNameCtrl;
  late TextEditingController _accountNumberCtrl;
  late TextEditingController _ifscCtrl;
  late TextEditingController _accountHolderCtrl;
  late TextEditingController _joiningDateCtrl;
  late TextEditingController _remarksCtrl;

  String _selectedGender = 'Female';
  String _selectedRole = 'सदस्य';
  String _selectedStatus = 'active';

  final List<String> _genderOptions = ['Female', 'Male', 'Other'];
  final List<String> _roleOptions = ['सदस्य', 'अध्यक्ष', 'सचिव', 'खजिनदार', 'उपाध्यक्ष'];
  final List<String> _statusOptions = ['active', 'inactive'];

  @override
  void initState() {
    super.initState();
    final m = widget.member;
    final now = DateTime.now();
    final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    _codeCtrl = TextEditingController(text: m?.memberCode ?? '');
    _nameCtrl = TextEditingController(text: m?.fullName ?? '');
    _mobileCtrl = TextEditingController(text: m?.mobileNumber ?? '');
    _altMobileCtrl = TextEditingController(text: m?.alternateMobile ?? '');
    _dobCtrl = TextEditingController(text: m?.dateOfBirth ?? '');
    _addressCtrl = TextEditingController(text: m?.address ?? '');
    _villageCtrl = TextEditingController(text: m?.village ?? '');
    _talukaCtrl = TextEditingController(text: m?.taluka ?? '');
    _districtCtrl = TextEditingController(text: m?.district ?? '');
    _pincodeCtrl = TextEditingController(text: m?.pincode ?? '');
    _aadhaarCtrl = TextEditingController(text: m?.aadhaarNumber ?? (m?.aadhaarLastFour != null ? 'XXXX-XXXX-${m!.aadhaarLastFour}' : ''));
    _panCtrl = TextEditingController(text: m?.panNumber ?? '');
    _educationCtrl = TextEditingController(text: m?.education ?? '');
    _occupationCtrl = TextEditingController(text: m?.occupation ?? '');
    _annualIncomeCtrl = TextEditingController(text: m?.annualIncome != null ? m!.annualIncome!.toStringAsFixed(0) : '');
    _nomineeNameCtrl = TextEditingController(text: m?.nomineeName ?? '');
    _nomineeRelationCtrl = TextEditingController(text: m?.nomineeRelation ?? '');
    _nomineeMobileCtrl = TextEditingController(text: m?.nomineeMobile ?? '');
    _nomineeAgeCtrl = TextEditingController(text: m?.nomineeAge != null ? m!.nomineeAge.toString() : '');
    _bankNameCtrl = TextEditingController(text: m?.bankName ?? '');
    _branchNameCtrl = TextEditingController(text: m?.branchName ?? '');
    _accountNumberCtrl = TextEditingController(text: m?.accountNumber ?? '');
    _ifscCtrl = TextEditingController(text: m?.ifsc ?? '');
    _accountHolderCtrl = TextEditingController(text: m?.accountHolderName ?? '');
    _joiningDateCtrl = TextEditingController(text: m?.joiningDate ?? todayStr);
    _remarksCtrl = TextEditingController(text: m?.remarks ?? '');

    if (m != null) {
      _selectedGender = m.gender;
      _selectedRole = m.roleInGroup;
      _selectedStatus = m.status;
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _altMobileCtrl.dispose();
    _dobCtrl.dispose();
    _addressCtrl.dispose();
    _villageCtrl.dispose();
    _talukaCtrl.dispose();
    _districtCtrl.dispose();
    _pincodeCtrl.dispose();
    _aadhaarCtrl.dispose();
    _panCtrl.dispose();
    _educationCtrl.dispose();
    _occupationCtrl.dispose();
    _annualIncomeCtrl.dispose();
    _nomineeNameCtrl.dispose();
    _nomineeRelationCtrl.dispose();
    _nomineeMobileCtrl.dispose();
    _nomineeAgeCtrl.dispose();
    _bankNameCtrl.dispose();
    _branchNameCtrl.dispose();
    _accountNumberCtrl.dispose();
    _ifscCtrl.dispose();
    _accountHolderCtrl.dispose();
    _joiningDateCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    DateTime initial = DateTime.now();
    try {
      if (controller.text.isNotEmpty) {
        initial = DateTime.parse(controller.text);
      }
    } catch (_) {}

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1940),
      lastDate: DateTime(2035),
    );

    if (picked != null) {
      setState(() {
        controller.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  Future<void> _saveMember() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final memberProv = Provider.of<MemberProvider>(context, listen: false);
    final groupId = auth.currentGroup?.id ?? auth.currentProfile?.groupId ?? '';

    if (groupId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('गट माहिती उपलब्ध नाही. कृपया पुन्हा लॉगिन करा.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    final cleanAadhaar = _aadhaarCtrl.text.replaceAll(RegExp(r'\s+|-'), '').trim();
    String? aadhaarLastFour;
    if (cleanAadhaar.length >= 4) {
      aadhaarLastFour = cleanAadhaar.substring(cleanAadhaar.length - 4);
    }

    final newMember = Member(
      id: widget.member?.id ?? '',
      groupId: groupId,
      memberCode: _codeCtrl.text.trim().isNotEmpty
          ? _codeCtrl.text.trim()
          : 'MBG-${(memberProv.members.length + 1).toString().padLeft(2, '0')}',
      fullName: _nameCtrl.text.trim(),
      mobileNumber: _mobileCtrl.text.trim(),
      alternateMobile: _altMobileCtrl.text.trim().isNotEmpty ? _altMobileCtrl.text.trim() : null,
      dateOfBirth: _dobCtrl.text.trim().isNotEmpty ? _dobCtrl.text.trim() : null,
      gender: _selectedGender,
      address: _addressCtrl.text.trim().isNotEmpty ? _addressCtrl.text.trim() : null,
      village: _villageCtrl.text.trim().isNotEmpty ? _villageCtrl.text.trim() : null,
      taluka: _talukaCtrl.text.trim().isNotEmpty ? _talukaCtrl.text.trim() : null,
      district: _districtCtrl.text.trim().isNotEmpty ? _districtCtrl.text.trim() : null,
      pincode: _pincodeCtrl.text.trim().isNotEmpty ? _pincodeCtrl.text.trim() : null,
      aadhaarNumber: cleanAadhaar.isNotEmpty ? cleanAadhaar : null,
      aadhaarLastFour: aadhaarLastFour,
      panNumber: _panCtrl.text.trim().isNotEmpty ? _panCtrl.text.trim().toUpperCase() : null,
      education: _educationCtrl.text.trim().isNotEmpty ? _educationCtrl.text.trim() : null,
      occupation: _occupationCtrl.text.trim().isNotEmpty ? _occupationCtrl.text.trim() : null,
      annualIncome: double.tryParse(_annualIncomeCtrl.text.trim()),
      nomineeName: _nomineeNameCtrl.text.trim().isNotEmpty ? _nomineeNameCtrl.text.trim() : null,
      nomineeRelation: _nomineeRelationCtrl.text.trim().isNotEmpty ? _nomineeRelationCtrl.text.trim() : null,
      nomineeMobile: _nomineeMobileCtrl.text.trim().isNotEmpty ? _nomineeMobileCtrl.text.trim() : null,
      nomineeAge: int.tryParse(_nomineeAgeCtrl.text.trim()),
      bankName: _bankNameCtrl.text.trim().isNotEmpty ? _bankNameCtrl.text.trim() : null,
      branchName: _branchNameCtrl.text.trim().isNotEmpty ? _branchNameCtrl.text.trim() : null,
      accountNumber: _accountNumberCtrl.text.trim().isNotEmpty ? _accountNumberCtrl.text.trim() : null,
      ifsc: _ifscCtrl.text.trim().isNotEmpty ? _ifscCtrl.text.trim().toUpperCase() : null,
      accountHolderName: _accountHolderCtrl.text.trim().isNotEmpty ? _accountHolderCtrl.text.trim() : null,
      roleInGroup: _selectedRole,
      status: _selectedStatus,
      remarks: _remarksCtrl.text.trim().isNotEmpty ? _remarksCtrl.text.trim() : null,
      joiningDate: _joiningDateCtrl.text.trim().isNotEmpty ? _joiningDateCtrl.text.trim() : null,
    );

    bool success = false;
    if (widget.member == null) {
      success = await memberProv.addMember(newMember);
    } else {
      success = await memberProv.updateMember(newMember);
    }

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        try {
          Provider.of<DashboardProvider>(context, listen: false).loadDashboardMetrics(newMember.groupId);
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.member == null ? 'सदस्य यशस्वीरित्या जोडला गेला!' : 'सदस्य माहिती यशस्वीरित्या जतन झाली!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(memberProv.lastError ?? 'सदस्य माहिती सेव्ह करताना त्रुटी आली. कृपया तपासा.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.member != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          isEdit ? 'सदस्य माहिती संपादित करा (Edit Member)' : 'नवीन सदस्य जोडा (Add Member)',
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        elevation: 1,
        actions: [
          if (isEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.white),
              tooltip: 'सदस्य हटवा (Delete Member)',
              onPressed: _confirmDeleteInEdit,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Section 1: वैयक्तिक माहिती
                  _buildSectionCard(
                    title: '१. वैयक्तिक माहिती (Personal Details)',
                    icon: Icons.person_rounded,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: _buildTextField(
                              controller: _codeCtrl,
                              label: 'सदस्य कोड (Member Code)',
                              hint: 'उदा. MBG-01',
                              prefixIcon: Icons.badge_rounded,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: _buildTextField(
                              controller: _nameCtrl,
                              label: 'पूर्ण नाव (Full Name) *',
                              hint: 'सदस्याचे नाव टाका',
                              prefixIcon: Icons.person_outline_rounded,
                              isRequired: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDropdown(
                              label: 'गटातील पद (Role in Group)',
                              value: _selectedRole,
                              items: _roleOptions,
                              onChanged: (val) => setState(() => _selectedRole = val!),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildDropdown(
                              label: 'लिंग (Gender)',
                              value: _selectedGender,
                              items: _genderOptions,
                              onChanged: (val) => setState(() => _selectedGender = val!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDateField(
                              controller: _dobCtrl,
                              label: 'जन्मतारीख (Date of Birth)',
                              onTap: () => _selectDate(context, _dobCtrl),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildDateField(
                              controller: _joiningDateCtrl,
                              label: 'सामील तारीख (Joining Date)',
                              onTap: () => _selectDate(context, _joiningDateCtrl),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _educationCtrl,
                              label: 'शिक्षण (Education)',
                              hint: 'उदा. १० वी, १२ वी, पदवीधर',
                              prefixIcon: Icons.school_rounded,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              controller: _occupationCtrl,
                              label: 'व्यवसाय (Occupation)',
                              hint: 'उदा. गृहिणी, शेती, नोकरी',
                              prefixIcon: Icons.work_outline_rounded,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _annualIncomeCtrl,
                        label: 'वार्षिक उत्पन्न ₹ (Annual Income)',
                        hint: 'उदा. 150000',
                        prefixIcon: Icons.currency_rupee_rounded,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Section 2: संपर्क व पत्ता
                  _buildSectionCard(
                    title: '२. संपर्क व पत्ता (Contact & Address)',
                    icon: Icons.location_on_rounded,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _mobileCtrl,
                              label: 'मोबाईल नंबर (Mobile Number) *',
                              hint: '१० अंकी मोबाईल नंबर',
                              prefixIcon: Icons.phone_rounded,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                              isRequired: true,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              controller: _altMobileCtrl,
                              label: 'पर्यायी मोबाईल (Alternate Mobile)',
                              hint: 'पर्यायी मोबाईल नंबर',
                              prefixIcon: Icons.phone_iphone_rounded,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _addressCtrl,
                        label: 'संपूर्ण पत्ता (Full Address)',
                        hint: 'घर क्र., गल्ली, परिसर',
                        prefixIcon: Icons.home_rounded,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _villageCtrl,
                              label: 'गाव / शहर (Village/City)',
                              hint: 'उदा. वाटंबरे',
                              prefixIcon: Icons.location_city_rounded,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              controller: _talukaCtrl,
                              label: 'तालुका (Taluka)',
                              hint: 'उदा. सांगोला',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _districtCtrl,
                              label: 'जिल्हा (District)',
                              hint: 'उदा. सोलापूर',
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              controller: _pincodeCtrl,
                              label: 'पिनकोड (Pincode)',
                              hint: '६ अंकी पिनकोड',
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Section 3: ओळख पुरावे
                  _buildSectionCard(
                    title: '३. ओळख पुरावे (Identity Details)',
                    icon: Icons.badge_outlined,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _aadhaarCtrl,
                              label: 'आधार कार्ड क्रमांक (Aadhaar Number)',
                              hint: '१२ अंकी आधार क्रमांक',
                              prefixIcon: Icons.credit_card_rounded,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(12)],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              controller: _panCtrl,
                              label: 'पॅन कार्ड क्रमांक (PAN Number)',
                              hint: 'उदा. ABCDE1234F',
                              prefixIcon: Icons.assignment_ind_rounded,
                              inputFormatters: [LengthLimitingTextInputFormatter(10)],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Section 4: वारसदार तपशील
                  _buildSectionCard(
                    title: '४. वारसदार तपशील (Nominee Details)',
                    icon: Icons.family_restroom_rounded,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: _buildTextField(
                              controller: _nomineeNameCtrl,
                              label: 'वारसदाराचे नाव (Nominee Name)',
                              hint: 'पूर्ण नाव टाका',
                              prefixIcon: Icons.person_pin_rounded,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 1,
                            child: _buildTextField(
                              controller: _nomineeRelationCtrl,
                              label: 'नाते (Relation)',
                              hint: 'उदा. पती, मुलगा',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _nomineeMobileCtrl,
                              label: 'वारसदाराचा मोबाईल (Nominee Mobile)',
                              hint: '१० अंकी मोबाईल',
                              prefixIcon: Icons.phone_android_rounded,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              controller: _nomineeAgeCtrl,
                              label: 'वारसदाराचे वय (Nominee Age)',
                              hint: 'उदा. 25',
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Section 5: बँक खाते तपशील
                  _buildSectionCard(
                    title: '५. बँक खाते तपशील (Bank Account Details)',
                    icon: Icons.account_balance_rounded,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _bankNameCtrl,
                              label: 'बँकेचे नाव (Bank Name)',
                              hint: 'उदा. State Bank of India',
                              prefixIcon: Icons.account_balance_rounded,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              controller: _branchNameCtrl,
                              label: 'शाखेचे नाव (Branch Name)',
                              hint: 'उदा. सांगोला शाखा',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _accountNumberCtrl,
                              label: 'बँक खाते क्रमांक (Account Number)',
                              hint: 'खाते क्रमांक टाका',
                              prefixIcon: Icons.pin_rounded,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              controller: _ifscCtrl,
                              label: 'IFSC कोड (IFSC Code)',
                              hint: 'उदा. SBIN0001234',
                              prefixIcon: Icons.numbers_rounded,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _accountHolderCtrl,
                        label: 'खातेदाराचे नाव (Account Holder Name)',
                        hint: 'बँक पासबुक प्रमाणे नाव',
                        prefixIcon: Icons.person_rounded,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Section 6: स्थिती व शेरा
                  _buildSectionCard(
                    title: '६. स्थिती व शेरा (Status & Remarks)',
                    icon: Icons.notes_rounded,
                    children: [
                      _buildDropdown(
                        label: 'सदस्य स्थिती (Member Status)',
                        value: _selectedStatus,
                        items: _statusOptions,
                        onChanged: (val) => setState(() => _selectedStatus = val!),
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _remarksCtrl,
                        label: 'शेरा / टिप्पणी (Remarks)',
                        hint: 'काही विशेष सूचना किंवा माहिती असल्यास टाका',
                        maxLines: 2,
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // Save Button
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _saveMember,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A8A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 3,
                      ),
                      icon: _isLoading
                          ? const SizedBox.shrink()
                          : const Icon(Icons.check_circle_rounded, color: Colors.white),
                      label: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              isEdit ? 'बदल जतन करा (UPDATE MEMBER)' : 'सदस्य जतन करा (SAVE MEMBER)',
                              style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A8A).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: const Color(0xFF1E3A8A), size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E3A8A),
                ),
              ),
            ],
          ),
          const Divider(height: 24, thickness: 1),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? prefixIcon,
    bool isRequired = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20, color: const Color(0xFF1E3A8A)) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      validator: isRequired
          ? (v) => (v == null || v.trim().isEmpty) ? 'हे फील्ड भरणे आवश्यक आहे' : null
          : null,
    );
  }

  Widget _buildDateField({
    required TextEditingController controller,
    required String label,
    required VoidCallback onTap,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.calendar_today_rounded, size: 20, color: Color(0xFF1E3A8A)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: items.contains(value) ? value : items.first,
      items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Future<void> _confirmDeleteInEdit() async {
    final member = widget.member;
    if (member == null) return;

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
      navigator.pop(true);
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
}
