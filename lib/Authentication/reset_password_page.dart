import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_page.dart';
import 'auth_service.dart';
import 'auth_error_handler.dart';
import '../services/security_service.dart';
import '../user_screens/help_support_screen.dart';

/// The 3 distinct stages of the OTP-based password recovery flow.
enum ResetPasswordStep {
  email,
  otp,
  newPassword,
}

class ResetPasswordPage extends StatefulWidget {
  final AuthService? authService;
  final SupabaseClient? supabaseClient;
  final SecurityService? securityService;

  const ResetPasswordPage({
    super.key,
    this.authService,
    this.supabaseClient,
    this.securityService,
  });

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  ResetPasswordStep _currentStep = ResetPasswordStep.email;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _otpFocusNode = FocusNode();
  final FocusNode _newPasswordFocusNode = FocusNode();
  final FocusNode _confirmPasswordFocusNode = FocusNode();

  late final AuthService _authService;
  late final SecurityService _securityService;
  SupabaseClient get _supabase => widget.supabaseClient ?? Supabase.instance.client;

  bool _isLoading = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;
  String? _successMessage;

  int _resendCountdown = 0;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService(client: widget.supabaseClient);
    _securityService = widget.securityService ?? SecurityService(client: widget.supabaseClient);

    _emailFocusNode.addListener(() => setState(() {}));
    _otpFocusNode.addListener(() => setState(() {}));
    _newPasswordFocusNode.addListener(() => setState(() {}));
    _confirmPasswordFocusNode.addListener(() => setState(() {}));

    _checkForRecoveryToken();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _emailFocusNode.dispose();
    _otpFocusNode.dispose();
    _newPasswordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  void _checkForRecoveryToken() {
    // If the app was launched directly from an email recovery link
    try {
      final session = _supabase.auth.currentSession;
      if (session != null) {
        setState(() {
          _currentStep = ResetPasswordStep.newPassword;
        });
      }
    } catch (_) {}
  }

  void _startResendCooldown() {
    _resendCountdown = 60;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCountdown <= 1) {
        timer.cancel();
        setState(() => _resendCountdown = 0);
      } else {
        setState(() => _resendCountdown--);
      }
    });
  }

  Future<void> _sendResetOtp({bool isResend = false}) async {
    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your email address.';
      });
      return;
    }

    if (!AuthErrorHandler.isValidEmail(email)) {
      setState(() {
        _errorMessage = 'Please enter a valid email address.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await _authService.resetPassword(email: email);
      if (mounted) {
        setState(() {
          _currentStep = ResetPasswordStep.otp;
          _successMessage = isResend
              ? 'A new verification code was sent to $email.'
              : 'Verification code sent! Please check your email inbox.';
          _startResendCooldown();
        });
      }
    } catch (e) {
      debugPrint('[ResetPasswordPage] _sendResetOtp error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = AuthErrorHandler.getErrorMessage(e);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _verifyOtp() async {
    final email = _emailController.text.trim().toLowerCase();
    final otp = _otpController.text.trim();

    if (otp.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter the 6-digit verification code.';
      });
      return;
    }

    if (otp.length < 6) {
      setState(() {
        _errorMessage = 'Verification code must be 6 digits.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await _authService.verifyPasswordResetOtp(
        email: email,
        token: otp,
      );
      if (mounted) {
        _resendTimer?.cancel();
        setState(() {
          _currentStep = ResetPasswordStep.newPassword;
          _successMessage = 'Code verified! Now enter your new password.';
        });
      }
    } catch (e) {
      debugPrint('[ResetPasswordPage] _verifyOtp error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = AuthErrorHandler.getErrorMessage(e);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updatePassword() async {
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (newPassword.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your new password.';
      });
      return;
    }

    if (newPassword.length < 6) {
      setState(() {
        _errorMessage = 'Password must be at least 6 characters long.';
      });
      return;
    }

    if (confirmPassword.isEmpty) {
      setState(() {
        _errorMessage = 'Please confirm your new password.';
      });
      return;
    }

    if (newPassword != confirmPassword) {
      setState(() {
        _errorMessage = 'Passwords do not match. Please verify and try again.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await _authService.updatePassword(newPassword: newPassword);
      await _securityService.recordPasswordRecoveryCompletion();
      await _authService.signOut();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text('Password updated successfully! Please log in.'),
                ),
              ],
            ),
            backgroundColor: Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('[ResetPasswordPage] _sendResetOtp error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = AuthErrorHandler.getErrorMessage(e);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getSubheaderText() {
    switch (_currentStep) {
      case ResetPasswordStep.email:
        return 'RESET PASSWORD';
      case ResetPasswordStep.otp:
        return 'VERIFY OTP';
      case ResetPasswordStep.newPassword:
        return 'NEW PASSWORD';
    }
  }

  String _getTitleText() {
    switch (_currentStep) {
      case ResetPasswordStep.email:
        return 'Reset your password.';
      case ResetPasswordStep.otp:
        return 'Enter verification code.';
      case ResetPasswordStep.newPassword:
        return 'Create new password.';
    }
  }

  String _getSubtitleText() {
    switch (_currentStep) {
      case ResetPasswordStep.email:
        return 'Enter your email address and we\'ll send you a 6-digit verification code to reset your password.';
      case ResetPasswordStep.otp:
        final email = _emailController.text.trim();
        return 'We sent a 6-digit code to $email. Enter the code below to verify your account.';
      case ResetPasswordStep.newPassword:
        return 'Your verification code was accepted. Please choose a strong new password with at least 6 characters.';
    }
  }

  String _getButtonLabel() {
    switch (_currentStep) {
      case ResetPasswordStep.email:
        return 'Send verification code';
      case ResetPasswordStep.otp:
        return 'Verify code';
      case ResetPasswordStep.newPassword:
        return 'Update password';
    }
  }

  VoidCallback? _getButtonAction() {
    if (_isLoading) return null;
    switch (_currentStep) {
      case ResetPasswordStep.email:
        return _sendResetOtp;
      case ResetPasswordStep.otp:
        return _verifyOtp;
      case ResetPasswordStep.newPassword:
        return _updatePassword;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 35),
                // Logo & Header section
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 59,
                      height: 65,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: const DecorationImage(
                          image: AssetImage("assets/saferoute logo.png"),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'Safe',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF7098C2),
                              fontSize: 25,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          TextSpan(
                            text: 'Route',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF263354),
                              fontSize: 25,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const HelpSupportScreen(),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        child: Text(
                          'Need Help?',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF263354),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Step Subheader
                Text(
                  _getSubheaderText(),
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF63729A),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),

                // Step Title
                Text(
                  _getTitleText(),
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF263354),
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),

                // Step Subtitle
                Text(
                  _getSubtitleText(),
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF63739A),
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),

                // ==============================================================
                // STEP 1: EMAIL INPUT
                // ==============================================================
                if (_currentStep == ResetPasswordStep.email) ...[
                  Text(
                    'Email address',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF344673),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('reset_password_email_field'),
                    controller: _emailController,
                    focusNode: _emailFocusNode,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'Enter your email',
                      hintStyle: GoogleFonts.poppins(
                        color: const Color(0xFF344673),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFEDEEF2),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 20,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          width: 1.5,
                          color: Color(0xFF344673),
                        ),
                      ),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(left: 16, right: 10),
                        child: SvgPicture.asset(
                          'assets/mail.svg',
                          width: 20,
                          height: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // ==============================================================
                // STEP 2: 6-DIGIT OTP INPUT
                // ==============================================================
                if (_currentStep == ResetPasswordStep.otp) ...[
                  Text(
                    '6-digit verification code',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF344673),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('reset_password_otp_field'),
                    controller: _otpController,
                    focusNode: _otpFocusNode,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 8,
                      color: const Color(0xFF263354),
                    ),
                    decoration: InputDecoration(
                      hintText: '000000',
                      hintStyle: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 8,
                        color: const Color(0xFF9AA3BC),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFEDEEF2),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 18,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          width: 1.5,
                          color: Color(0xFF344673),
                        ),
                      ),
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(left: 16, right: 10),
                        child: Icon(
                          Icons.pin_outlined,
                          color: Color(0xFF344673),
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _currentStep = ResetPasswordStep.email;
                            _errorMessage = null;
                            _successMessage = null;
                          });
                        },
                        child: Text(
                          'Change email',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF2563EB),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (_resendCountdown > 0)
                        Text(
                          'Resend in ${_resendCountdown}s',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF8A94A6),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                        )
                      else
                        GestureDetector(
                          key: const Key('reset_password_resend_button'),
                          onTap: _isLoading ? null : () => _sendResetOtp(isResend: true),
                          child: Text(
                            'Resend code',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF2563EB),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],

                // ==============================================================
                // STEP 3: NEW PASSWORD INPUTS
                // ==============================================================
                if (_currentStep == ResetPasswordStep.newPassword) ...[
                  Text(
                    'New password',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF344673),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('reset_password_new_field'),
                    controller: _newPasswordController,
                    focusNode: _newPasswordFocusNode,
                    obscureText: _obscureNewPassword,
                    decoration: InputDecoration(
                      hintText: 'Enter your new password',
                      hintStyle: GoogleFonts.poppins(
                        color: const Color(0xFF344673),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFEDEEF2),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 20,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          width: 1.5,
                          color: Color(0xFF344673),
                        ),
                      ),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(left: 16, right: 10),
                        child: SvgPicture.asset(
                          'assets/lock.svg',
                          width: 20,
                          height: 20,
                        ),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureNewPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: const Color(0xFF344673),
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureNewPassword = !_obscureNewPassword;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Confirm new password',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF344673),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('reset_password_confirm_field'),
                    controller: _confirmPasswordController,
                    focusNode: _confirmPasswordFocusNode,
                    obscureText: _obscureConfirmPassword,
                    decoration: InputDecoration(
                      hintText: 'Confirm your new password',
                      hintStyle: GoogleFonts.poppins(
                        color: const Color(0xFF344673),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFEDEEF2),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 20,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          width: 1.5,
                          color: Color(0xFF344673),
                        ),
                      ),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(left: 16, right: 10),
                        child: SvgPicture.asset(
                          'assets/lock.svg',
                          width: 20,
                          height: 20,
                        ),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: const Color(0xFF344673),
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // ==============================================================
                // PRIMARY ACTION BUTTON (Clean, no trailing arrow)
                // ==============================================================
                InkWell(
                  key: const Key('reset_password_primary_button'),
                  onTap: _getButtonAction(),
                  borderRadius: BorderRadius.circular(28),
                  child: Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFF263354),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF263354).withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              _getButtonLabel(),
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 15.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ),

                // ==============================================================
                // ALERTS & NOTIFICATIONS
                // ==============================================================
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: Color(0xFFDC2626),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: GoogleFonts.poppins(
                                color: const Color(0xFF991B1B),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                if (_successMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle_outline_rounded,
                            color: Color(0xFF16A34A),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _successMessage!,
                              style: GoogleFonts.poppins(
                                color: const Color(0xFF166534),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 24),

                // Divider with "or"
                Row(
                  children: [
                    const Expanded(
                      child: Divider(
                        color: Color(0xFFD1D5E0),
                        thickness: 1,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'or',
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF9AA3BC),
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    const Expanded(
                      child: Divider(
                        color: Color(0xFFD1D5E0),
                        thickness: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Remember your password? Log in
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Remember your password?',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF63739A),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginPage(),
                          ),
                        );
                      },
                      child: Text(
                        ' Log in',
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF344673),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 35),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
