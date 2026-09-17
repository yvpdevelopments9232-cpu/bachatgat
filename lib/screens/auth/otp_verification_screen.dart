import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import 'login_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String email;

  const OtpVerificationScreen({super.key, required this.email});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _passwordVisible = false;

  @override
  void dispose() {
    _otpController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _verifyAndResetPassword() async {
    final otp = _otpController.text.replaceAll(RegExp(r'\s+'), '').trim();
    final newPassword = _newPasswordController.text.trim();

    if (otp.length != 6 && otp.length != 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('कृपया वैध ६ किंवा ८ अंकी OTP कोड प्रविष्ट करा (Please enter a valid 6 or 8-digit OTP)'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (newPassword.isEmpty || newPassword.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('पासवर्ड किमान ६ अक्षरांचा असावा (Password must be at least 6 characters)'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;

      // 1. Verify OTP with recovery type
      await supabase.auth.verifyOTP(
        type: OtpType.recovery,
        email: widget.email,
        token: otp,
      );

      // 2. Update the user password
      await supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      // 3. Sign out so user logs in cleanly with new credentials
      await supabase.auth.signOut();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('पासवर्ड यशस्वीरित्या बदलला आहे! आता आपण नवीन पासवर्डने लॉगिन करू शकता.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );

        // Navigate back to LoginScreen
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        String msg = 'अवैध किंवा कालबाह्य OTP कोड! कृपया पुन्हा प्रयत्न करा. (Invalid or expired OTP)';
        if (e.toString().toLowerCase().contains('password')) {
          msg = 'पासवर्ड त्रुटी: ${e.toString()}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = AppColors.primary;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(
          'OTP पडताळणी (Verify OTP)',
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        elevation: 1,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(28.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.mark_email_read, size: 54, color: Colors.green),
                ),
                const SizedBox(height: 20),
                Text(
                  'OTP कोड टाका',
                  style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF1E3A8A)),
                ),
                const SizedBox(height: 8),
                Text(
                  'आम्ही OTP कोड खालील ईमेलवर पाठवला आहे:',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 12.5),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.email,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.indigo.shade900, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 28),

                // OTP Field
                TextField(
                  controller: _otpController,
                  decoration: InputDecoration(
                    labelText: 'OTP कोड (६ किंवा ८ अंकी / 6 or 8-Digit OTP)',
                    hintText: 'उदा. 123456 किंवा 12345678',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.pin_rounded, color: primaryColor),
                    counterText: '',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 8,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, letterSpacing: 4, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),

                // New Password Field
                TextField(
                  controller: _newPasswordController,
                  decoration: InputDecoration(
                    labelText: 'नवीन पासवर्ड (New Password)',
                    hintText: 'किमान ६ अक्षरे',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.lock_outline_rounded, color: primaryColor),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _passwordVisible ? Icons.visibility : Icons.visibility_off,
                        color: primaryColor,
                      ),
                      onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
                    ),
                  ),
                  obscureText: !_passwordVisible,
                ),
                const SizedBox(height: 28),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _verifyAndResetPassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A8A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            'पासवर्ड निश्चित करा (SET PASSWORD)',
                            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                      (Route<dynamic> route) => false,
                    );
                  },
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text('लॉगिन पृष्ठावर जा (Go to Login)'),
                  style: TextButton.styleFrom(foregroundColor: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
