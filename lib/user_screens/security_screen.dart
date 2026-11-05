import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../Authentication/auth_error_handler.dart';
import '../Authentication/login_page.dart';
import '../services/security_service.dart';

const Color _primaryNavy = Color(0xFF233253);
const Color _secondaryGrey = Color(0xFF8A94A6);
const Color _bgBeige = Color(0xFFFAF8F5);
const Color _lightBlue = Color(0xFFEFF5FB);
const Color _badgeBlue = Color(0xFFEAF2FB);
const Color _accentBlue = Color(0xFF7098C2);
const Color _inputFill = Color(0xFFF3F5F9);
const Color _alertRed = Color(0xFFE53935);
const Color _lightRed = Color(0xFFFFEBEE);
const Color _successGreen = Color(0xFF10B981);
const Color _warningAmber = Color(0xFFF59E0B);

class SecurityScreen extends StatefulWidget {
  final SecurityService? service;
  final AccountAccessOverview? initialOverview;

  const SecurityScreen({
    super.key,
    this.service,
    this.initialOverview,
  });

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  final _passwordFormKey = GlobalKey<FormState>();

  late final SecurityService _service;

  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  AccountAccessOverview? _overview;
  bool _isLoading = true;
  bool _isUpdatingPassword = false;
  bool _isSendingReset = false;
  bool _isManagingSessions = false;
  bool _isUpdatingPreference = false;

  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  String? _loadError;
  String? _passwordError;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? SecurityService();
    _newPasswordController.addListener(_onNewPasswordChanged);

    if (widget.initialOverview != null) {
      _overview = widget.initialOverview;
      _isLoading = false;
      _refreshOverviewSilently();
    } else {
      _loadOverview();
    }
  }

  @override
  void dispose() {
    _newPasswordController.removeListener(_onNewPasswordChanged);
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onNewPasswordChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _refreshOverviewSilently() async {
    try {
      final fetched = await _service.getSecurityOverview();
      if (mounted && fetched != null && !_isUpdatingPreference) {
        setState(() {
          _overview = fetched;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadOverview({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }

    try {
      final fetched = await _service.getSecurityOverview();
      if (!mounted) return;
      if (fetched == null) {
        setState(() {
          _loadError = 'Please sign in to manage your security settings.';
          _isLoading = false;
        });
        return;
      }
      setState(() {
        _overview = fetched;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = _friendlyError(e);
        _isLoading = false;
      });
    }
  }

  String _friendlyError(Object error) {
    final raw = error.toString();
    if (raw.startsWith('Exception: ')) {
      return raw.substring('Exception: '.length);
    }
    if (error is AuthException || error is PostgrestException) {
      return AuthErrorHandler.getErrorMessage(error);
    }
    return AuthErrorHandler.getErrorMessage(error);
  }

  Future<void> _handleChangePassword() async {
    FocusScope.of(context).unfocus();
    if (!(_passwordFormKey.currentState?.validate() ?? false)) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _isUpdatingPassword = true;
      _passwordError = null;
    });

    try {
      await _service.changePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );

      if (!mounted) return;
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      setState(() {
        _isUpdatingPassword = false;
      });

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Your password has been updated successfully!'),
          backgroundColor: _successGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );

      await _loadOverview(silent: true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _passwordError = _friendlyError(e);
        _isUpdatingPassword = false;
      });
    }
  }

  Future<void> _handleSendResetEmail() async {
    if (_isSendingReset) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _isSendingReset = true;
      _passwordError = null;
    });

    try {
      await _service.sendPasswordResetEmail();
      if (!mounted) return;
      setState(() {
        _isSendingReset = false;
      });

      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Password recovery link sent! Please check your email inbox.',
          ),
          backgroundColor: _successGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );

      await _loadOverview(silent: true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSendingReset = false;
      });
      messenger.showSnackBar(
        SnackBar(
          content: Text(_friendlyError(e)),
          backgroundColor: _alertRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _togglePreference({
    bool? keepSignedIn,
    bool? loginAlertsEnabled,
    bool? anonymousReporting,
  }) async {
    if (_overview == null || _isUpdatingPreference) return;
    final previousOverview = _overview!;
    final previousSettings = previousOverview.settings;
    final messenger = ScaffoldMessenger.of(context);

    // Optimistic UI update
    setState(() {
      _isUpdatingPreference = true;
      _overview = previousOverview.copyWith(
        settings: previousSettings.copyWith(
          keepSignedIn: keepSignedIn ?? previousSettings.keepSignedIn,
          loginAlertsEnabled:
              loginAlertsEnabled ?? previousSettings.loginAlertsEnabled,
          anonymousReporting:
              anonymousReporting ?? previousSettings.anonymousReporting,
        ),
      );
    });

    try {
      final updatedSettings = await _service.updateSecuritySettings(
        keepSignedIn: keepSignedIn,
        loginAlertsEnabled: loginAlertsEnabled,
        anonymousReporting: anonymousReporting,
      );
      if (!mounted) return;
      setState(() {
        _overview = _overview?.copyWith(settings: updatedSettings);
      });
      await _loadOverview(silent: true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _overview = previousOverview;
      });
      messenger.showSnackBar(
        SnackBar(
          content: Text(_friendlyError(e)),
          backgroundColor: _alertRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingPreference = false;
        });
      }
    }
  }

  Future<void> _confirmSignOutOtherDevices() async {
    if (_isManagingSessions) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: const Text(
          'Sign Out of Other Devices?',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: _primaryNavy,
          ),
        ),
        content: const Text(
          'This will immediately revoke active sessions on any other phones, tablets, or browsers while keeping you signed in on this device.',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            color: _secondaryGrey,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                color: _secondaryGrey,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryNavy,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Sign Out Others',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      _isManagingSessions = true;
    });

    try {
      await _service.signOutOtherDevices();
      if (!mounted) return;
      setState(() {
        _isManagingSessions = false;
      });
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Signed out of all other devices.'),
          backgroundColor: _successGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _loadOverview(silent: true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isManagingSessions = false;
      });
      messenger.showSnackBar(
        SnackBar(
          content: Text(_friendlyError(e)),
          backgroundColor: _alertRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _confirmSignOutAllDevices() async {
    if (_isManagingSessions) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: const Text(
          'Sign Out Everywhere?',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: _primaryNavy,
          ),
        ),
        content: const Text(
          'This will sign you out of every active device — including this one — and require your password to log back in.',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            color: _secondaryGrey,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                color: _secondaryGrey,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _alertRed,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Sign Out All',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    setState(() {
      _isManagingSessions = true;
    });

    try {
      await _service.signOutAllDevices();
      if (!mounted) return;
      nav.pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isManagingSessions = false;
      });
      messenger.showSnackBar(
        SnackBar(
          content: Text(_friendlyError(e)),
          backgroundColor: _alertRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgBeige,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _primaryNavy,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Security',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: _primaryNavy,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: const Color(0xFFEDF0F5),
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: _primaryNavy),
      );
    }

    if (_loadError != null && _overview == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: _alertRed,
              ),
              const SizedBox(height: 12),
              Text(
                _loadError!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: _primaryNavy,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadOverview,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text(
                  'Retry',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryNavy,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final overview = _overview!;

    return RefreshIndicator(
      color: _primaryNavy,
      onRefresh: () => _loadOverview(silent: true),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Security Status Banner
            _buildSecurityStatusCard(overview),

            const SizedBox(height: 24),

            // 2. Change Password Form
            _buildSectionHeader('CHANGE PASSWORD'),
            _buildChangePasswordCard(),

            const SizedBox(height: 24),

            // 3. Account Access & Privacy Toggles
            _buildSectionHeader('ACCOUNT ACCESS & PRIVACY'),
            _buildAccessPreferencesCard(overview.settings),

            const SizedBox(height: 24),

            // 4. Device Sessions Management
            _buildSectionHeader('DEVICE SESSIONS'),
            _buildSessionsCard(overview),

            const SizedBox(height: 24),

            // 5. Recent Security Activity Audit Log
            _buildSectionHeader('RECENT SECURITY ACTIVITY'),
            _buildRecentActivityCard(overview.recentLogs),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityStatusCard(AccountAccessOverview overview) {
    final pwdChangedAt = overview.settings.passwordChangedAt;
    final pwdSubtitle = pwdChangedAt != null
        ? 'Password updated ${_formatRelativeTime(pwdChangedAt)}'
        : 'Password unchanged since registration';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _badgeBlue,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified_user_rounded,
              color: _primaryNavy,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Account Protected',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _primaryNavy,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: overview.emailVerified
                            ? const Color(0xFFDCFCE7)
                            : const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        overview.emailVerified
                            ? 'Email Verified'
                            : 'Unverified Email',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: overview.emailVerified
                              ? const Color(0xFF166534)
                              : const Color(0xFF92400E),
                        ),
                      ),
                    ),
                  ],
                ),
                if (overview.email.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    overview.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF4E5E7A),
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  pwdSubtitle,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: _accentBlue,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChangePasswordCard() {
    final strength =
        PasswordStrengthInfo.evaluate(_newPasswordController.text);

    Color strengthColor;
    switch (strength.level) {
      case PasswordStrengthLevel.empty:
        strengthColor = const Color(0xFFD6DEE8);
        break;
      case PasswordStrengthLevel.weak:
        strengthColor = _alertRed;
        break;
      case PasswordStrengthLevel.fair:
        strengthColor = _warningAmber;
        break;
      case PasswordStrengthLevel.good:
        strengthColor = _accentBlue;
        break;
      case PasswordStrengthLevel.strong:
        strengthColor = _successGreen;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Form(
        key: _passwordFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildPasswordField(
              key: const Key('security_current_password_field'),
              controller: _currentPasswordController,
              label: 'Current Password',
              hintText: 'Enter your current password',
              obscureText: _obscureCurrentPassword,
              onToggleVisibility: () {
                setState(() {
                  _obscureCurrentPassword = !_obscureCurrentPassword;
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your current password';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildPasswordField(
              key: const Key('security_new_password_field'),
              controller: _newPasswordController,
              label: 'New Password',
              hintText: 'Create a strong new password',
              obscureText: _obscureNewPassword,
              onToggleVisibility: () {
                setState(() {
                  _obscureNewPassword = !_obscureNewPassword;
                });
              },
              validator: (value) {
                final baseError = AuthErrorHandler.validatePassword(value);
                if (baseError != null) return baseError;
                if (value == _currentPasswordController.text &&
                    _currentPasswordController.text.isNotEmpty) {
                  return 'New password must be different from current password';
                }
                return null;
              },
            ),
            if (_newPasswordController.text.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: strength.progress,
                        minHeight: 5,
                        backgroundColor: const Color(0xFFE5EAF2),
                        valueColor:
                            AlwaysStoppedAnimation<Color>(strengthColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    strength.label,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: strengthColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                strength.helperText,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 10.5,
                  color: _secondaryGrey,
                ),
              ),
            ],
            const SizedBox(height: 16),
            _buildPasswordField(
              key: const Key('security_confirm_password_field'),
              controller: _confirmPasswordController,
              label: 'Confirm New Password',
              hintText: 'Re-enter your new password',
              obscureText: _obscureConfirmPassword,
              onToggleVisibility: () {
                setState(() {
                  _obscureConfirmPassword = !_obscureConfirmPassword;
                });
              },
              validator: (value) => AuthErrorHandler.validateConfirmPassword(
                _newPasswordController.text,
                value,
              ),
            ),
            if (_passwordError != null) ...[
              const SizedBox(height: 14),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _passwordError!,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF991B1B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                key: const Key('security_update_password_button'),
                onPressed: _isUpdatingPassword ? null : _handleChangePassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryNavy,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      _primaryNavy.withValues(alpha: 0.55),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: _isUpdatingPassword
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Update Password',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                onPressed: _isSendingReset ? null : _handleSendResetEmail,
                icon: _isSendingReset
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _accentBlue,
                        ),
                      )
                    : const Icon(
                        Icons.mail_outline_rounded,
                        size: 16,
                        color: _accentBlue,
                      ),
                label: Text(
                  _isSendingReset
                      ? 'Sending recovery link...'
                      : 'Forgot current password? Email recovery link',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _accentBlue,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccessPreferencesCard(UserSecuritySettings settings) {
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        children: [
          _buildSwitchTile(
            switchKey: const Key('security_keep_signed_in_switch'),
            icon: Icons.phonelink_lock_rounded,
            title: 'Keep Me Signed In',
            subtitle: 'Maintain account access on this device across restarts',
            value: settings.keepSignedIn,
            onChanged: (val) => _togglePreference(keepSignedIn: val),
          ),
          _buildDivider(),
          _buildSwitchTile(
            switchKey: const Key('security_login_alerts_switch'),
            icon: Icons.notifications_active_outlined,
            title: 'Security & Login Alerts',
            subtitle: 'Record sign-ins and alert on security changes',
            value: settings.loginAlertsEnabled,
            onChanged: (val) => _togglePreference(loginAlertsEnabled: val),
          ),
          _buildDivider(),
          _buildSwitchTile(
            switchKey: const Key('security_anonymous_reporting_switch'),
            icon: Icons.visibility_off_outlined,
            title: 'Anonymous Hazard Reports',
            subtitle: 'Hide your profile name when sharing community alerts',
            value: settings.anonymousReporting,
            onChanged: (val) => _togglePreference(anonymousReporting: val),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionsCard(AccountAccessOverview overview) {
    final lastSignInLabel = overview.lastSignInAt != null
        ? 'Last sign-in ${_formatRelativeTime(overview.lastSignInAt!)}'
        : 'Current authenticated session';
    final globalSignOutAt = overview.settings.lastGlobalSignoutAt;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: _lightBlue,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _platformIcon(overview.currentPlatform),
                  color: _primaryNavy,
                  size: 21,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'This Device (${overview.currentPlatform})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: _primaryNavy,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: _successGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Active now • $lastSignInLabel',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        color: _secondaryGrey,
                      ),
                    ),
                    if (globalSignOutAt != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Other sessions revoked ${_formatRelativeTime(globalSignOutAt)}',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10.5,
                          color: _accentBlue,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            key: const Key('security_sign_out_others_button'),
            onPressed:
                _isManagingSessions ? null : _confirmSignOutOtherDevices,
            icon: const Icon(Icons.devices_other_rounded, size: 18),
            label: const Text(
              'Sign Out of Other Devices',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: _primaryNavy,
              side: const BorderSide(color: Color(0xFFD0DAE7), width: 1.2),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            key: const Key('security_sign_out_all_button'),
            onPressed: _isManagingSessions ? null : _confirmSignOutAllDevices,
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text(
              'Sign Out of All Devices',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: TextButton.styleFrom(
              foregroundColor: _alertRed,
              backgroundColor: _lightRed,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivityCard(List<SecurityActivityLog> logs) {
    if (logs.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        decoration: _cardDecoration(),
        child: const Column(
          children: [
            Icon(
              Icons.history_rounded,
              size: 32,
              color: _secondaryGrey,
            ),
            SizedBox(height: 8),
            Text(
              'No recent security activity yet',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _primaryNavy,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Password changes, device sign-outs, and access updates will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                color: _secondaryGrey,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: _cardDecoration(),
      child: Column(
        children: [
          for (int i = 0; i < logs.length; i++) ...[
            _buildActivityRow(logs[i]),
            if (i < logs.length - 1) _buildDivider(),
          ],
        ],
      ),
    );
  }

  Widget _buildActivityRow(SecurityActivityLog log) {
    IconData icon;
    Color iconColor = _primaryNavy;
    Color iconBg = _lightBlue;

    switch (log.eventType) {
      case 'password_changed':
        icon = Icons.key_rounded;
        iconColor = _successGreen;
        iconBg = const Color(0xFFECFDF5);
        break;
      case 'password_reset_requested':
        icon = Icons.mark_email_read_outlined;
        iconColor = _accentBlue;
        break;
      case 'signed_out_other_devices':
      case 'signed_out_all_devices':
        icon = Icons.phonelink_erase_rounded;
        iconColor = _alertRed;
        iconBg = _lightRed;
        break;
      case 'login_recorded':
        icon = Icons.login_rounded;
        break;
      case 'security_settings_updated':
      default:
        icon = Icons.tune_rounded;
        break;
    }

    final timeStr = _formatRelativeTime(log.createdAt);
    final metaStr = log.platform != null
        ? '${log.platform} • $timeStr'
        : timeStr;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.description,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: _primaryNavy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  metaStr,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10.5,
                    color: _secondaryGrey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    Key? switchKey,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: _lightBlue,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 19, color: _primaryNavy),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _primaryNavy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10.5,
                    color: _secondaryGrey,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch.adaptive(
            key: switchKey,
            value: value,
            activeTrackColor: _primaryNavy,
            onChanged: _isUpdatingPreference ? null : onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField({
    Key? key,
    required TextEditingController controller,
    required String label,
    required String hintText,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
    required String? Function(String?) validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: _primaryNavy,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          key: key,
          controller: controller,
          obscureText: obscureText,
          validator: validator,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: _primaryNavy,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              color: _secondaryGrey,
            ),
            prefixIcon: const Icon(
              Icons.lock_outline_rounded,
              size: 19,
              color: _accentBlue,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                obscureText
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 19,
                color: _secondaryGrey,
              ),
              onPressed: onToggleVisibility,
            ),
            filled: true,
            fillColor: _inputFill,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _primaryNavy, width: 1.4),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _alertRed, width: 1.2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _alertRed, width: 1.4),
            ),
            errorStyle: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              color: _alertRed,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
          color: _secondaryGrey,
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(
      height: 1,
      thickness: 1,
      indent: 68,
      endIndent: 16,
      color: Color(0xFFF1F3F6),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    );
  }

  IconData _platformIcon(String platform) {
    switch (platform) {
      case 'Android':
        return Icons.phone_android_rounded;
      case 'iOS':
        return Icons.phone_iphone_rounded;
      case 'Web Browser':
        return Icons.public_rounded;
      default:
        return Icons.computer_rounded;
    }
  }

  String _formatRelativeTime(DateTime timestamp) {
    final local = timestamp.toLocal();
    final diff = DateTime.now().difference(local);

    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) {
      final m = diff.inMinutes;
      return '$m ${m == 1 ? 'min' : 'mins'} ago';
    }
    if (diff.inHours < 24) {
      final h = diff.inHours;
      return '$h ${h == 1 ? 'hr' : 'hrs'} ago';
    }
    if (diff.inDays < 7) {
      final d = diff.inDays;
      return '$d ${d == 1 ? 'day' : 'days'} ago';
    }
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[local.month - 1]} ${local.day}, ${local.year}';
  }
}
