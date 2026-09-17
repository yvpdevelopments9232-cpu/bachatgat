import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/utils/image_helper.dart';
import 'login_screen.dart';
import '../main_navigation_screen.dart';

class SubLoginScreen extends StatefulWidget {
  const SubLoginScreen({super.key});

  @override
  State<SubLoginScreen> createState() => _SubLoginScreenState();
}

class _SubLoginScreenState extends State<SubLoginScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();

  bool _obscurePassword = true;
  bool _isAuthenticating = false;
  String? _errorMessage;

  DateTime _selectedEndDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedEndDate = DateTime(now.year, now.month, now.day);
    _dateController.text = _formatDateDdMmYyyy(_selectedEndDate);
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  String _formatDateDdMmYyyy(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    return '$d-$m-$y';
  }

  DateTime? _validateAndParseDate(String input, DateTime appStartDate) {
    final trimmed = input.trim();
    final regex = RegExp(r'^\d{2}-\d{2}-\d{4}$');
    if (!regex.hasMatch(trimmed)) {
      setState(() {
        _errorMessage = 'Please enter date in DD-MM-YYYY format.';
      });
      return null;
    }

    final parts = trimmed.split('-');
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);

    if (day == null || month == null || year == null || month < 1 || month > 12 || year < 2000 || year > 2100) {
      setState(() {
        _errorMessage = 'Please enter a valid date.';
      });
      return null;
    }

    // Days in month validation (accounting for leap years)
    final daysInMonth = DateTime(year, month + 1, 0).day;
    if (day < 1 || day > daysInMonth) {
      setState(() {
        _errorMessage = 'Please enter a valid date.';
      });
      return null;
    }

    final parsedDate = DateTime(year, month, day);
    final startDayOnly = DateTime(appStartDate.year, appStartDate.month, appStartDate.day);

    if (parsedDate.isBefore(startDayOnly)) {
      final startFmt = _formatDateDdMmYyyy(startDayOnly);
      setState(() {
        _errorMessage = 'Selected date cannot be earlier than the application start date ($startFmt).';
      });
      return null;
    }

    return parsedDate;
  }

  Future<void> _pickDate(DateTime appStartDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedEndDate.isBefore(appStartDate) ? appStartDate : _selectedEndDate,
      firstDate: appStartDate,
      lastDate: DateTime(2050, 12, 31),
      locale: const Locale('en', 'IN'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF2563EB),
              onPrimary: Colors.white,
              onSurface: Color(0xFF1E293B),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedEndDate = picked;
        _dateController.text = _formatDateDdMmYyyy(picked);
        _errorMessage = null;
      });
    }
  }

  Future<void> _handleSubLogin(AuthProvider auth) async {
    final enteredPassword = _passwordController.text;
    if (enteredPassword.isEmpty) {
      setState(() {
        _errorMessage = 'कृपया पासवर्ड टाका (Please enter your password)';
      });
      return;
    }

    final parsedDate = _validateAndParseDate(_dateController.text, auth.applicationStartDate);
    if (parsedDate == null) {
      return;
    }

    setState(() {
      _isAuthenticating = true;
      _errorMessage = null;
    });

    final isValid = await auth.verifySubLoginPassword(enteredPassword);

    if (!mounted) return;

    if (!isValid) {
      setState(() {
        _isAuthenticating = false;
        _errorMessage = 'चुकीचा पासवर्ड! कृपया योग्य पासवर्ड टाका. (Incorrect password. Please try again.)';
      });
      return;
    }

    // Success: Unlock Sub Login and set global viewing date range
    auth.unlockSubLogin(endDate: parsedDate);
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final isDesktop = MediaQuery.of(context).size.width >= 960;
    final group = auth.currentGroup;
    final profile = auth.currentProfile;
    final appStartDateFormatted = auth.applicationStartDateFormatted;

    final enteredDateFormatted = _dateController.text.isNotEmpty ? _dateController.text : _formatDateDdMmYyyy(_selectedEndDate);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFEFF6FF), // Soft Sky Blue
              Color(0xFFF8FAFC), // Off-white
              Color(0xFFE2E8F0), // Cool Slate
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Left Branding Side (Desktop only)
                if (isDesktop) ...[
                  Flexible(
                    flex: 4,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 360),
                      margin: const EdgeInsets.only(right: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // App / Group Badge Icon
                          Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Color(0xFF0D9488), Color(0xFF059669)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF0D9488).withOpacity(0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.groups_rounded, color: Colors.white, size: 56),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Bachat Gat',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1E3A8A),
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            'Management System',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(width: 32, height: 2, color: const Color(0xFF94A3B8)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Text(
                                  'Together We Grow',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontStyle: FontStyle.italic,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                              Container(width: 32, height: 2, color: const Color(0xFF94A3B8)),
                            ],
                          ),
                          const SizedBox(height: 36),
                          // Stylized Plant / Coins Icon Art
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 15,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.eco_rounded, color: Color(0xFF059669), size: 30),
                                ),
                                const SizedBox(width: 14),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'सुरक्षित बचत, समृद्ध भविष्य',
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF1E293B),
                                      ),
                                    ),
                                    Text(
                                      'Safe & Secure Access',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        color: const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // Center Sub-Login Card
                Flexible(
                  flex: 6,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 480),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 1. TOP PROFILE IMAGE & BACHAT GAT NAME (Explicit user requirement)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              // User Profile Photo
                              profile?.profilePhotoUrl != null && profile!.profilePhotoUrl!.isNotEmpty
                                  ? ImageHelper.buildBase64Avatar(
                                      profile.profilePhotoUrl,
                                      radius: 24,
                                      fallbackInitial: profile.fullName.isNotEmpty ? profile.fullName[0].toUpperCase() : 'A',
                                    )
                                  : CircleAvatar(
                                      radius: 24,
                                      backgroundColor: const Color(0xFF2563EB).withOpacity(0.12),
                                      child: Text(
                                        profile?.fullName.isNotEmpty == true ? profile!.fullName[0].toUpperCase() : 'A',
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF2563EB),
                                          fontSize: 18,
                                        ),
                                      ),
                                    ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      group?.groupName ?? 'सखी महिला बचत गट',
                                      style: GoogleFonts.poppins(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF0F172A),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '${profile?.fullName ?? "Admin"} (${profile?.role ?? "Admin"})',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF64748B),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF059669)),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Active',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF059669),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Center Icon
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.supervised_user_circle_rounded,
                            color: Color(0xFF059669),
                            size: 34,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Card Title & Subtitle
                        Text(
                          'Bachat Gat Management System',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1E3A8A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Secure Application Access',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 22),

                        // Error message alert if any
                        if (_errorMessage != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFFCA5A5)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFFB91C1C),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // 2. PASSWORD FIELD
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Row(
                            children: [
                              const Icon(Icons.lock_rounded, size: 16, color: Color(0xFF2563EB)),
                              const SizedBox(width: 6),
                              Text(
                                'Password',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF334155),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.next,
                          onChanged: (_) {
                            if (_errorMessage != null) setState(() => _errorMessage = null);
                          },
                          decoration: InputDecoration(
                            hintText: 'Enter your password',
                            hintStyle: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF94A3B8)),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                size: 20,
                                color: const Color(0xFF64748B),
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // 3. DATA UP TO DATE FIELD (Default: Today's date)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_month_rounded, size: 16, color: Color(0xFF2563EB)),
                              const SizedBox(width: 6),
                              Text(
                                'Data Up To Date',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF334155),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _dateController,
                          keyboardType: TextInputType.datetime,
                          onChanged: (val) {
                            if (_errorMessage != null) setState(() => _errorMessage = null);
                            final parsed = DateTime.tryParse(val);
                            if (parsed != null) {
                              _selectedEndDate = parsed;
                            }
                            setState(() {});
                          },
                          decoration: InputDecoration(
                            hintText: 'DD-MM-YYYY (e.g. 31-12-2026)',
                            hintStyle: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF94A3B8)),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                            ),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.calendar_today_rounded, size: 20, color: Color(0xFF2563EB)),
                              tooltip: 'कॅलेंडरमधून तारीख निवडा',
                              onPressed: () => _pickDate(auth.applicationStartDate),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 5, left: 4),
                            child: Text(
                              'Format: DD-MM-YYYY (e.g. 31-12-2026)',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),

                        // 4. LOGIN & CONTINUE BUTTON
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 2,
                            ),
                            onPressed: _isAuthenticating ? null : () => _handleSubLogin(auth),
                            child: _isAuthenticating
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.login_rounded, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Login & Continue',
                                        style: GoogleFonts.poppins(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // 5. INFO CONTAINER (Application Start Date -> Entered Date)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF2563EB),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.info_outline_rounded, color: Colors.white, size: 16),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Data will be displayed from',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF1E40AF),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$appStartDateFormatted to $enteredDateFormatted',
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF1E3A8A),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '(Application Start Date → Entered Date)',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        color: const Color(0xFF60A5FA),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Option: Open as Member (View Only)
                        OutlinedButton.icon(
                          onPressed: () {
                            auth.unlockMemberViewOnlySession();
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
                            );
                          },
                          icon: const Icon(Icons.visibility_rounded, size: 16, color: Color(0xFF16A34A)),
                          label: Text(
                            'सभासद म्हणून उघडा (View Only Mode)',
                            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF15803D)),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF86EFAC)),
                            backgroundColor: const Color(0xFFF0FDF4),
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Switch to Main Login / Different User
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'दुसऱ्या खात्यातून लॉगिन करायचे आहे? ',
                              style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B)),
                            ),
                            InkWell(
                              onTap: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                                );
                              },
                              child: Text(
                                'Main Login',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF2563EB),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Right Guide Side Panel (Desktop only)
                if (isDesktop) ...[
                  Flexible(
                    flex: 4,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 340),
                      margin: const EdgeInsets.only(left: 32),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2563EB).withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.security_rounded, color: Color(0xFF2563EB), size: 24),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Secure Access',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1E293B),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Please enter your password and the date up to which you want to view the data.',
                            style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'How It Works',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 14),
                          _buildStepRow(1, 'Enter your password'),
                          const SizedBox(height: 12),
                          _buildStepRow(2, 'Select Data Up To Date (DD-MM-YYYY)'),
                          const SizedBox(height: 12),
                          _buildStepRow(3, 'Click Login & Continue'),
                          const SizedBox(height: 12),
                          _buildStepRow(4, 'Application will load data from $appStartDateFormatted to your selected date'),
                          const SizedBox(height: 24),
                          const Divider(color: Color(0xFFE2E8F0)),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              const Icon(Icons.event_note_rounded, size: 20, color: Color(0xFF64748B)),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Application Start Date',
                                    style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF94A3B8)),
                                  ),
                                  Text(
                                    appStartDateFormatted,
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF1E293B),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepRow(int number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: Color(0xFF2563EB),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            '$number',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF334155),
            ),
          ),
        ),
      ],
    );
  }
}
