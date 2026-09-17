import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_strings.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../main_navigation_screen.dart';
import 'forgot_password_screen.dart';
import 'sub_login_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool isSignUp = false;
  bool isSubUserLogin = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  // Login Controllers
  final TextEditingController _loginEmailController = TextEditingController();
  final TextEditingController _loginPasswordController = TextEditingController();

  // Sign Up Controllers
  final TextEditingController _signupEmailController = TextEditingController();
  final TextEditingController _signupPasswordController = TextEditingController();
  final TextEditingController _signupBachatGatNameController = TextEditingController();
  final TextEditingController _signupAddressController = TextEditingController();
  final TextEditingController _signupFullNameController = TextEditingController();
  final TextEditingController _signupMobileController = TextEditingController();

  @override
  void dispose() {
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _signupEmailController.dispose();
    _signupPasswordController.dispose();
    _signupBachatGatNameController.dispose();
    _signupAddressController.dispose();
    _signupFullNameController.dispose();
    _signupMobileController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return ValueListenableBuilder<bool>(
      valueListenable: AppStrings.languageNotifier,
      builder: (context, isMr, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 440),
                child: isSubUserLogin
                    ? _buildSubUserSwitchView(context, auth)
                    : isSignUp
                        ? _buildSignUpForm(context, auth)
                        : _buildLoginForm(context, auth),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoginForm(BuildContext context, AuthProvider auth) {
    return Column(
      children: [
        // App Logo & Title
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.secondary],
            ),
            boxShadow: [
              BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6)),
            ],
          ),
          child: const Icon(Icons.groups_rounded, color: Colors.white, size: 44),
        ),
        const SizedBox(height: 16),
        Text(
          AppStrings.appName,
          style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.primary),
        ),
        Text(
          AppStrings.appSubtitle,
          style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        // Language Selector Pill
        InkWell(
          onTap: () => AppStrings.toggleLanguage(),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.language, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  AppStrings.isMarathi ? 'मराठी  |  English' : 'English  |  मराठी',
                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Login Card
        AppCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '1. Login & Authentication',
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Supabase Auth',
                      style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.dangerBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.danger.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: GoogleFonts.poppins(fontSize: 12, color: AppColors.danger, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              TextField(
                controller: _loginEmailController,
                keyboardType: TextInputType.emailAddress,
                onChanged: (_) {
                  if (_errorMessage != null) setState(() => _errorMessage = null);
                },
                decoration: const InputDecoration(
                  labelText: 'Email ID (वापरकर्ता ईमेल)',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _loginPasswordController,
                obscureText: _obscurePassword,
                onChanged: (_) {
                  if (_errorMessage != null) setState(() => _errorMessage = null);
                },
                decoration: InputDecoration(
                  labelText: 'Password (पासवर्ड)',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                    );
                  },
                  child: Text(
                    'पासवर्ड विसरलात? (Forgot Password?)',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              AppButton(
                width: double.infinity,
                text: auth.isLoading ? 'लॉगिन होत आहे...' : 'Login',
                isLoading: auth.isLoading,
                onPressed: auth.isLoading ? null : () => _handleLogin(context, auth),
              ),
              const SizedBox(height: 14),

              // Switch to Sign Up
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'नवीन खाते तयार करायचे आहे? ',
                    style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  InkWell(
                    onTap: () => setState(() {
                      isSignUp = true;
                      _errorMessage = null;
                    }),
                    child: Text(
                      'Sign Up करा',
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(color: AppColors.divider),
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      isSubUserLogin = true;
                      _errorMessage = null;
                    });
                  },
                  icon: const Icon(Icons.switch_account_rounded, color: AppColors.primary),
                  label: const Text('Sub-User Switch (कर्मचारी/अध्यक्ष)', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSignUpForm(BuildContext context, AuthProvider auth) {
    return Column(
      children: [
        // App Logo & Title
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(colors: [AppColors.primary, AppColors.secondary]),
            boxShadow: [
              BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6)),
            ],
          ),
          child: const Icon(Icons.app_registration_rounded, color: Colors.white, size: 36),
        ),
        const SizedBox(height: 12),
        Text(
          'नवीन बचत गट नोंदणी (Sign Up)',
          style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.primary),
        ),
        Text(
          'Create New Account & Register Bachat Gat',
          style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 20),

        // Sign Up Card
        AppCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.dangerBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.danger.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: GoogleFonts.poppins(fontSize: 12, color: AppColors.danger, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // 1. Email ID (Username)
              TextField(
                controller: _signupEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Username / Email ID (ईमेल आयडी) *',
                  prefixIcon: Icon(Icons.alternate_email_rounded),
                ),
              ),
              const SizedBox(height: 14),

              // 2. Password
              TextField(
                controller: _signupPasswordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password (किमान ६ अक्षरे) *',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 3. Bachat Gat Name
              TextField(
                controller: _signupBachatGatNameController,
                decoration: const InputDecoration(
                  labelText: 'Bachat Gat Name (बचत गटाचे नाव) *',
                  prefixIcon: Icon(Icons.groups_rounded),
                ),
              ),
              const SizedBox(height: 14),

              // 4. Address / Village
              TextField(
                controller: _signupAddressController,
                decoration: const InputDecoration(
                  labelText: 'Address / Village (गाव / पत्ता) *',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
              const SizedBox(height: 14),

              // 5. Full Name
              TextField(
                controller: _signupFullNameController,
                decoration: const InputDecoration(
                  labelText: 'President / Admin Full Name (पूर्ण नाव) *',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 14),

              // 6. Mobile (Optional)
              TextField(
                controller: _signupMobileController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Mobile Number (मोबाईल नंबर)',
                  prefixIcon: Icon(Icons.phone_android_rounded),
                ),
              ),
              const SizedBox(height: 24),

              // Submit Button
              AppButton(
                width: double.infinity,
                text: auth.isLoading ? 'नोंदणी होत आहे...' : 'Sign Up & Start App',
                isLoading: auth.isLoading,
                onPressed: auth.isLoading ? null : () => _handleSignUp(context, auth),
              ),
              const SizedBox(height: 14),

              // Back to Login
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'आधीच खाते आहे? ',
                    style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  InkWell(
                    onTap: () => setState(() {
                      isSignUp = false;
                      _errorMessage = null;
                    }),
                    child: Text(
                      'Login करा',
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _handleLogin(BuildContext context, AuthProvider auth) async {
    final email = _loginEmailController.text.trim();
    final password = _loginPasswordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'कृपया ईमेल आयडी आणि पासवर्ड टाका (Please enter email and password)');
      return;
    }

    setState(() => _errorMessage = null);
    final error = await auth.signIn(email: email, password: password);

    if (error != null) {
      setState(() => _errorMessage = error);
    } else {
      if (!context.mounted) return;
      _showRoleSelectionDialog(context, auth);
    }
  }

  Future<void> _handleSignUp(BuildContext context, AuthProvider auth) async {
    final email = _signupEmailController.text.trim();
    final password = _signupPasswordController.text;
    final bachatGat = _signupBachatGatNameController.text.trim();
    final address = _signupAddressController.text.trim();
    final fullName = _signupFullNameController.text.trim();
    final mobile = _signupMobileController.text.trim();

    if (email.isEmpty || password.isEmpty || bachatGat.isEmpty || address.isEmpty || fullName.isEmpty) {
      setState(() => _errorMessage = 'सर्व आवश्यक माहिती भरा (Please fill all required fields marked with *)');
      return;
    }

    if (password.length < 6) {
      setState(() => _errorMessage = 'पासवर्ड किमान ६ अक्षरांचा असावा (Password must be at least 6 characters)');
      return;
    }

    setState(() => _errorMessage = null);
    final error = await auth.signUp(
      email: email,
      password: password,
      bachatGatName: bachatGat,
      address: address,
      fullName: fullName,
      mobile: mobile,
    );

    if (error != null) {
      setState(() => _errorMessage = error);
    } else {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('खाते आणि बचत गट यशस्वीरित्या तयार झाले! (Account created successfully!)'),
          backgroundColor: AppColors.success,
        ),
      );
      _showRoleSelectionDialog(context, auth);
    }
  }

  Future<void> _showRoleSelectionDialog(BuildContext context, AuthProvider auth) async {
    AppRole selectedRole = AppRole.admin;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 10,
              child: Container(
                width: 440,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.white,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Title Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.admin_panel_settings_rounded,
                            color: AppColors.primary,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SELECT ROLE',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                'तुमची भूमिका निवडा (Select your role)',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Divider(height: 1),
                    const SizedBox(height: 16),

                    // Role Option 1: Admin
                    InkWell(
                      onTap: () {
                        setDialogState(() => selectedRole = AppRole.admin);
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: selectedRole == AppRole.admin
                              ? const Color(0xFFEFF6FF)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selectedRole == AppRole.admin
                                ? AppColors.primary
                                : AppColors.cardBorder,
                            width: selectedRole == AppRole.admin ? 1.8 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Radio<AppRole>(
                              value: AppRole.admin,
                              groupValue: selectedRole,
                              activeColor: AppColors.primary,
                              onChanged: (val) {
                                if (val != null) {
                                  setDialogState(() => selectedRole = val);
                                }
                              },
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Admin (ॲडमिन)',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: selectedRole == AppRole.admin
                                              ? AppColors.primary
                                              : AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFDBEAFE),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'Full Access',
                                          style: GoogleFonts.poppins(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'सर्व अधिकार, नवीन नोंदी, बदल व व्यवस्थापन (Sub-Login Flow)',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Role Option 2: Member
                    InkWell(
                      onTap: () {
                        setDialogState(() => selectedRole = AppRole.member);
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: selectedRole == AppRole.member
                              ? const Color(0xFFF0FDF4)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selectedRole == AppRole.member
                                ? const Color(0xFF16A34A)
                                : AppColors.cardBorder,
                            width: selectedRole == AppRole.member ? 1.8 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Radio<AppRole>(
                              value: AppRole.member,
                              groupValue: selectedRole,
                              activeColor: const Color(0xFF16A34A),
                              onChanged: (val) {
                                if (val != null) {
                                  setDialogState(() => selectedRole = val);
                                }
                              },
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Member (सभासद)',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: selectedRole == AppRole.member
                                              ? const Color(0xFF15803D)
                                              : AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFDCFCE7),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'View Only',
                                          style: GoogleFonts.poppins(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF15803D),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'फक्त माहिती, हिशोब व अहवाल पाहणे (थेट ॲप सुरू होईल)',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Action Button: CONTINUE
                    ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(dialogCtx);
                        if (selectedRole == AppRole.admin) {
                          await auth.setActiveRole(AppRole.admin);
                          if (!context.mounted) return;
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const SubLoginScreen()),
                          );
                        } else {
                          await auth.setActiveRole(AppRole.member);
                          auth.unlockMemberViewOnlySession();
                          if (!context.mounted) return;
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: selectedRole == AppRole.admin
                            ? AppColors.primary
                            : const Color(0xFF16A34A),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'CONTINUE / पुढे जा',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSubUserSwitchView(BuildContext context, AuthProvider auth) {
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => setState(() => isSubUserLogin = false),
            ),
            Text(
              'Select Account',
              style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...auth.availableUsers.map((u) {
          final isSelected = auth.currentProfile?.id == u.id;
          return AppCard(
            onTap: () {
              auth.switchUser(u);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
              );
            },
            color: isSelected ? AppColors.primary.withOpacity(0.04) : Colors.white,
            border: isSelected ? Border.all(color: AppColors.primary, width: 2) : null,
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary.withOpacity(0.12),
                  child: Icon(Icons.person, color: AppColors.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(u.fullName, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
                      Text(u.role.toUpperCase(), style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                if (isSelected) const Icon(Icons.check_circle_rounded, color: AppColors.primary),
              ],
            ),
          );
        }),
        const SizedBox(height: 16),
        AppButton(
          width: double.infinity,
          isOutlined: true,
          icon: Icons.person_add_rounded,
          text: '+ Add New User',
          onPressed: () => _showAddUserDialog(context, auth),
        ),
      ],
    );
  }

  void _showAddUserDialog(BuildContext context, AuthProvider auth) {
    final nameCtrl = TextEditingController();
    final mobileCtrl = TextEditingController();
    String selectedRole = 'employee';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding: EdgeInsets.symmetric(
            horizontal: MediaQuery.of(ctx).size.width < 500 ? 16 : 40,
            vertical: 24,
          ),
          title: const Text('Add Sub-User'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full Name')),
                const SizedBox(height: 12),
                TextField(controller: mobileCtrl, decoration: const InputDecoration(labelText: 'Mobile')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  items: ['admin', 'president', 'secretary', 'treasurer', 'employee'].map((r) {
                    return DropdownMenuItem(value: r, child: Text(r.toUpperCase()));
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) setDialogState(() => selectedRole = v);
                  },
                  decoration: const InputDecoration(labelText: 'Role'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.isNotEmpty) {
                  auth.addNewSubUser(fullName: nameCtrl.text, mobile: mobileCtrl.text, role: selectedRole);
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Save User'),
            ),
          ],
        ),
      ),
    );
  }
}
