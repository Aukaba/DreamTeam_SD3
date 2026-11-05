import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Password strength classification for live feedback when changing passwords.
enum PasswordStrengthLevel {
  empty,
  weak,
  fair,
  good,
  strong,
}

class PasswordStrengthInfo {
  final PasswordStrengthLevel level;
  final double progress;
  final String label;
  final String helperText;

  const PasswordStrengthInfo({
    required this.level,
    required this.progress,
    required this.label,
    required this.helperText,
  });

  static PasswordStrengthInfo evaluate(String password) {
    if (password.isEmpty) {
      return const PasswordStrengthInfo(
        level: PasswordStrengthLevel.empty,
        progress: 0.0,
        label: '',
        helperText: 'Use at least 8 characters with letters, numbers & symbols.',
      );
    }

    if (password.length < 6) {
      return const PasswordStrengthInfo(
        level: PasswordStrengthLevel.weak,
        progress: 0.22,
        label: 'Too short',
        helperText: 'Minimum 6 characters required.',
      );
    }

    int score = 0;
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;
    if (RegExp(r'[A-Z]').hasMatch(password) &&
        RegExp(r'[a-z]').hasMatch(password)) {
      score++;
    }
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) score++;

    if (score <= 1) {
      return const PasswordStrengthInfo(
        level: PasswordStrengthLevel.weak,
        progress: 0.30,
        label: 'Weak',
        helperText: 'Add uppercase letters, numbers, or symbols.',
      );
    } else if (score == 2) {
      return const PasswordStrengthInfo(
        level: PasswordStrengthLevel.fair,
        progress: 0.55,
        label: 'Fair',
        helperText: 'Good start — add numbers or symbols for stronger safety.',
      );
    } else if (score == 3) {
      return const PasswordStrengthInfo(
        level: PasswordStrengthLevel.good,
        progress: 0.80,
        label: 'Good',
        helperText: 'Strong password for daily protection.',
      );
    } else {
      return const PasswordStrengthInfo(
        level: PasswordStrengthLevel.strong,
        progress: 1.0,
        label: 'Strong',
        helperText: 'Excellent password strength!',
      );
    }
  }
}

/// Persistent security and account-access settings stored in `public.user_security_settings`.
class UserSecuritySettings {
  final String userId;
  final bool loginAlertsEnabled;
  final bool keepSignedIn;
  final bool anonymousReporting;
  final DateTime? passwordChangedAt;
  final DateTime? lastGlobalSignoutAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserSecuritySettings({
    required this.userId,
    this.loginAlertsEnabled = true,
    this.keepSignedIn = true,
    this.anonymousReporting = false,
    this.passwordChangedAt,
    this.lastGlobalSignoutAt,
    this.createdAt,
    this.updatedAt,
  });

  factory UserSecuritySettings.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      return DateTime.tryParse(val.toString());
    }

    return UserSecuritySettings(
      userId: json['user_id']?.toString() ?? '',
      loginAlertsEnabled: json['login_alerts_enabled'] as bool? ?? true,
      keepSignedIn: json['keep_signed_in'] as bool? ?? true,
      anonymousReporting: json['anonymous_reporting'] as bool? ?? false,
      passwordChangedAt: parseDate(json['password_changed_at']),
      lastGlobalSignoutAt: parseDate(json['last_global_signout_at']),
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'login_alerts_enabled': loginAlertsEnabled,
      'keep_signed_in': keepSignedIn,
      'anonymous_reporting': anonymousReporting,
      'password_changed_at': passwordChangedAt?.toUtc().toIso8601String(),
      'last_global_signout_at': lastGlobalSignoutAt?.toUtc().toIso8601String(),
    };
  }

  UserSecuritySettings copyWith({
    String? userId,
    bool? loginAlertsEnabled,
    bool? keepSignedIn,
    bool? anonymousReporting,
    DateTime? passwordChangedAt,
    DateTime? lastGlobalSignoutAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserSecuritySettings(
      userId: userId ?? this.userId,
      loginAlertsEnabled: loginAlertsEnabled ?? this.loginAlertsEnabled,
      keepSignedIn: keepSignedIn ?? this.keepSignedIn,
      anonymousReporting: anonymousReporting ?? this.anonymousReporting,
      passwordChangedAt: passwordChangedAt ?? this.passwordChangedAt,
      lastGlobalSignoutAt: lastGlobalSignoutAt ?? this.lastGlobalSignoutAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Single immutable entry in `public.security_activity_logs`.
class SecurityActivityLog {
  final int id;
  final String userId;
  final String eventType;
  final String description;
  final String? platform;
  final DateTime createdAt;

  const SecurityActivityLog({
    required this.id,
    required this.userId,
    required this.eventType,
    required this.description,
    this.platform,
    required this.createdAt,
  });

  factory SecurityActivityLog.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final parsedId = rawId is int
        ? rawId
        : int.tryParse(rawId?.toString() ?? '0') ?? 0;

    final parsedCreated = json['created_at'] != null
        ? (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now())
        : DateTime.now();

    final rawPlatform = (json['platform'] as String?)?.trim();

    return SecurityActivityLog(
      id: parsedId,
      userId: json['user_id']?.toString() ?? '',
      eventType: json['event_type']?.toString() ?? 'security_settings_updated',
      description: json['description']?.toString() ?? 'Security event',
      platform:
          (rawPlatform != null && rawPlatform.isNotEmpty) ? rawPlatform : null,
      createdAt: parsedCreated,
    );
  }
}

/// Aggregated account-access and security snapshot displayed on [SecurityScreen].
class AccountAccessOverview {
  final String email;
  final bool emailVerified;
  final DateTime? lastSignInAt;
  final DateTime? accountCreatedAt;
  final String currentPlatform;
  final UserSecuritySettings settings;
  final List<SecurityActivityLog> recentLogs;

  const AccountAccessOverview({
    required this.email,
    required this.emailVerified,
    this.lastSignInAt,
    this.accountCreatedAt,
    required this.currentPlatform,
    required this.settings,
    required this.recentLogs,
  });

  AccountAccessOverview copyWith({
    String? email,
    bool? emailVerified,
    DateTime? lastSignInAt,
    DateTime? accountCreatedAt,
    String? currentPlatform,
    UserSecuritySettings? settings,
    List<SecurityActivityLog>? recentLogs,
  }) {
    return AccountAccessOverview(
      email: email ?? this.email,
      emailVerified: emailVerified ?? this.emailVerified,
      lastSignInAt: lastSignInAt ?? this.lastSignInAt,
      accountCreatedAt: accountCreatedAt ?? this.accountCreatedAt,
      currentPlatform: currentPlatform ?? this.currentPlatform,
      settings: settings ?? this.settings,
      recentLogs: recentLogs ?? this.recentLogs,
    );
  }
}

/// Service managing password updates, session access revocation, security preferences,
/// and security audit logging in Supabase.
class SecurityService {
  final SupabaseClient? _client;

  SecurityService({SupabaseClient? client}) : _client = client;

  SupabaseClient get client => _client ?? Supabase.instance.client;

  User? get currentUser {
    try {
      return client.auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  /// Web-safe platform identifier without importing `dart:io`.
  static String detectPlatformLabel() {
    if (kIsWeb) return 'Web Browser';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'Android';
      case TargetPlatform.iOS:
        return 'iOS';
      case TargetPlatform.windows:
        return 'Windows';
      case TargetPlatform.macOS:
        return 'macOS';
      case TargetPlatform.linux:
        return 'Linux';
      case TargetPlatform.fuchsia:
        return 'Fuchsia';
    }
  }

  /// Fetch the signed-in user's security settings, session status, and recent activity logs.
  Future<AccountAccessOverview?> getSecurityOverview({int logLimit = 15}) async {
    final user = currentUser;
    if (user == null) return null;

    final prefs = await SharedPreferences.getInstance();
    final localRememberMe = prefs.getBool('rememberMe');

    final existingRow = await client
        .from('user_security_settings')
        .select()
        .eq('user_id', user.id)
        .maybeSingle();

    UserSecuritySettings settings;
    if (existingRow != null) {
      settings = UserSecuritySettings.fromJson(existingRow);
      await prefs.setBool('rememberMe', settings.keepSignedIn);
    } else {
      final initialKeepSignedIn = localRememberMe ?? true;
      final inserted = await client
          .from('user_security_settings')
          .upsert(
            {
              'user_id': user.id,
              'login_alerts_enabled': true,
              'keep_signed_in': initialKeepSignedIn,
              'anonymous_reporting': false,
            },
            onConflict: 'user_id',
          )
          .select()
          .single();
      settings = UserSecuritySettings.fromJson(inserted);
      await prefs.setBool('rememberMe', settings.keepSignedIn);
    }

    final rawLogs = await client
        .from('security_activity_logs')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(logLimit);

    final logs = (rawLogs as List<dynamic>)
        .map((item) =>
            SecurityActivityLog.fromJson(item as Map<String, dynamic>))
        .toList();

    return AccountAccessOverview(
      email: user.email ?? '',
      emailVerified: user.emailConfirmedAt != null,
      lastSignInAt: user.lastSignInAt != null
          ? DateTime.tryParse(user.lastSignInAt!)
          : null,
      accountCreatedAt: DateTime.tryParse(user.createdAt),
      currentPlatform: detectPlatformLabel(),
      settings: settings,
      recentLogs: logs,
    );
  }

  /// Update one or more account access & privacy preferences in `public.user_security_settings`.
  Future<UserSecuritySettings> updateSecuritySettings({
    bool? loginAlertsEnabled,
    bool? keepSignedIn,
    bool? anonymousReporting,
  }) async {
    final user = currentUser;
    if (user == null) {
      throw Exception('You must be signed in to update security settings.');
    }

    final payload = <String, dynamic>{
      'user_id': user.id,
    };
    final changedDescriptions = <String>[];

    if (loginAlertsEnabled != null) {
      payload['login_alerts_enabled'] = loginAlertsEnabled;
      changedDescriptions.add(
        loginAlertsEnabled
            ? 'Enabled security & login alerts'
            : 'Disabled security & login alerts',
      );
    }
    if (keepSignedIn != null) {
      payload['keep_signed_in'] = keepSignedIn;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('rememberMe', keepSignedIn);
      changedDescriptions.add(
        keepSignedIn
            ? 'Enabled persistent sign-in on this device'
            : 'Disabled persistent sign-in on this device',
      );
    }
    if (anonymousReporting != null) {
      payload['anonymous_reporting'] = anonymousReporting;
      changedDescriptions.add(
        anonymousReporting
            ? 'Enabled anonymous community reporting'
            : 'Disabled anonymous community reporting',
      );
    }

    final updated = await client
        .from('user_security_settings')
        .upsert(payload, onConflict: 'user_id')
        .select()
        .single();

    if (changedDescriptions.isNotEmpty) {
      await _appendLogBestEffort(
        userId: user.id,
        eventType: 'security_settings_updated',
        description: changedDescriptions.join('; '),
      );
    }

    return UserSecuritySettings.fromJson(updated);
  }

  /// Verify the user's [currentPassword] and update to [newPassword], recording
  /// `password_changed_at` and an immutable audit log entry.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = currentUser;
    final email = user?.email?.trim() ?? '';
    if (user == null || email.isEmpty) {
      throw Exception('Your session has expired. Please sign in again.');
    }
    if (currentPassword.isEmpty) {
      throw Exception('Please enter your current password.');
    }
    if (newPassword.length < 6) {
      throw Exception('New password must be at least 6 characters long.');
    }
    if (currentPassword == newPassword) {
      throw Exception(
          'Your new password must be different from your current password.');
    }

    // 1. Re-authenticate with currentPassword to prove account ownership
    try {
      await client.auth.signInWithPassword(
        email: email,
        password: currentPassword,
      );
    } on AuthException catch (e) {
      final lower = e.message.toLowerCase();
      if (lower.contains('invalid login credentials') ||
          lower.contains('invalid credentials') ||
          lower.contains('invalid_grant')) {
        throw Exception('Your current password is incorrect.');
      }
      rethrow;
    }

    // 2. Update password in Supabase Auth (never trim passwords)
    await client.auth.updateUser(
      UserAttributes(password: newPassword),
    );

    // 3. Persist password_changed_at and security audit log
    final activeUserId = currentUser?.id ?? user.id;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    await client.from('user_security_settings').upsert(
      {
        'user_id': activeUserId,
        'password_changed_at': nowIso,
      },
      onConflict: 'user_id',
    );

    await _appendLogBestEffort(
      userId: activeUserId,
      eventType: 'password_changed',
      description: 'Account password updated on ${detectPlatformLabel()}',
    );
  }

  /// Send a password recovery email to the currently signed-in user's address.
  Future<void> sendPasswordResetEmail() async {
    final user = currentUser;
    final email = user?.email?.trim() ?? '';
    if (user == null || email.isEmpty) {
      throw Exception('Unable to determine your account email address.');
    }

    await client.auth.resetPasswordForEmail(email);

    await _appendLogBestEffort(
      userId: user.id,
      eventType: 'password_reset_requested',
      description: 'Requested password recovery link for $email',
    );
  }

  /// Revoke all sessions on OTHER devices while keeping this device signed in.
  Future<void> signOutOtherDevices() async {
    final user = currentUser;
    if (user == null) {
      throw Exception('Your session has expired. Please sign in again.');
    }

    await client.auth.signOut(scope: SignOutScope.others);

    final nowIso = DateTime.now().toUtc().toIso8601String();
    await client.from('user_security_settings').upsert(
      {
        'user_id': user.id,
        'last_global_signout_at': nowIso,
      },
      onConflict: 'user_id',
    );

    await _appendLogBestEffort(
      userId: user.id,
      eventType: 'signed_out_other_devices',
      description:
          'Signed out of all other active devices from ${detectPlatformLabel()}',
    );
  }

  /// Revoke ALL active sessions globally (including this device) and clear persistent login.
  Future<void> signOutAllDevices() async {
    final user = currentUser;
    if (user != null) {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      try {
        await client.from('user_security_settings').upsert(
          {
            'user_id': user.id,
            'last_global_signout_at': nowIso,
          },
          onConflict: 'user_id',
        );
      } catch (_) {}

      await _appendLogBestEffort(
        userId: user.id,
        eventType: 'signed_out_all_devices',
        description:
            'Signed out of all devices globally from ${detectPlatformLabel()}',
      );
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('rememberMe', false);
    } catch (_) {}

    await client.auth.signOut(scope: SignOutScope.global);
  }

  /// Record password update timestamp and audit entry after recovery-link reset.
  Future<void> recordPasswordRecoveryCompletion() async {
    final user = currentUser;
    if (user == null) return;

    try {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      await client.from('user_security_settings').upsert(
        {
          'user_id': user.id,
          'password_changed_at': nowIso,
        },
        onConflict: 'user_id',
      );

      await _appendLogBestEffort(
        userId: user.id,
        eventType: 'password_changed',
        description:
            'Password reset via recovery link on ${detectPlatformLabel()}',
      );
    } catch (_) {
      // Non-fatal fallback
    }
  }

  /// Best-effort login event logger called after password sign-in.
  Future<void> recordLoginEvent({bool? rememberMe}) async {
    final user = currentUser;
    if (user == null) return;

    try {
      final existing = await client
          .from('user_security_settings')
          .select('login_alerts_enabled, keep_signed_in')
          .eq('user_id', user.id)
          .maybeSingle();

      final alertsEnabled =
          existing == null ? true : (existing['login_alerts_enabled'] as bool? ?? true);

      if (rememberMe != null || existing == null) {
        await client.from('user_security_settings').upsert(
          {
            'user_id': user.id,
            if (rememberMe != null) 'keep_signed_in': rememberMe,
          },
          onConflict: 'user_id',
        );
      }

      if (alertsEnabled) {
        await _appendLogBestEffort(
          userId: user.id,
          eventType: 'login_recorded',
          description: 'Signed in from ${detectPlatformLabel()}',
        );
      }
    } catch (_) {
      // Never block sign-in flow if audit logging fails
    }
  }

  Future<void> _appendLogBestEffort({
    required String userId,
    required String eventType,
    required String description,
  }) async {
    try {
      await client.from('security_activity_logs').insert({
        'user_id': userId,
        'event_type': eventType,
        'description': description,
        'platform': detectPlatformLabel(),
      });
    } catch (_) {
      // Non-fatal audit insert fallback
    }
  }
}
