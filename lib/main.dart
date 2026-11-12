import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'map_screen.dart';
import 'Authentication/login_page.dart';
import 'Authentication/role_service.dart';
import 'user_screens/user_home_screen.dart';
import 'admin_screens/admin_dashboard_screen.dart';
import 'Authentication/reset_password_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
    final supabaseUrl = dotenv.env['SUPABASE_URL'];
    final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

    if (supabaseUrl == null || supabaseAnonKey == null) {
      throw Exception('SUPABASE_URL or SUPABASE_ANON_KEY is missing in .env file');
    }

    await Supabase.initialize(
      url: supabaseUrl,
      // ignore: deprecated_member_use
      anonKey: supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.implicit,
      ),
    );
    runApp(const MyApp());
  } catch (e) {
    debugPrint('Error initializing Supabase: $e');
    rethrow;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'SafeRoute',
      debugShowCheckedModeBanner: false,
      home: AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  final Stream<AuthState>? authStateStream;
  final Future<UserRoleResolution> Function(String userId)? roleResolver;
  final Future<void> Function()? onSignOut;
  final Widget? adminScreen;
  final Widget? userScreen;
  final Widget? loginScreen;

  const AuthWrapper({
    super.key,
    this.authStateStream,
    this.roleResolver,
    this.onSignOut,
    this.adminScreen,
    this.userScreen,
    this.loginScreen,
  });

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  String? _cachedRoleUserId;
  Future<UserRoleResolution>? _cachedRoleFuture;
  bool _isPasswordRecovery = false;

  bool get _usesInjectedAuth =>
      widget.authStateStream != null || widget.roleResolver != null;

  @override
  void initState() {
    super.initState();
    if (!_usesInjectedAuth) {
      _initSessionAccess();
    }
  }

  Future<void> _initSessionAccess() async {
    // Allow deep-link auth events (such as passwordRecovery) to settle first
    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted || _isPasswordRecovery) return;

    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool('rememberMe') ?? false;

    if (!rememberMe && !_isPasswordRecovery) {
      // Sign out on cold start if persistent sign-in is disabled
      await Supabase.instance.client.auth.signOut();
    }
  }

  Future<UserRoleResolution> _resolveRoleForUser(String userId) {
    if (_cachedRoleFuture == null || _cachedRoleUserId != userId) {
      _cachedRoleUserId = userId;
      _cachedRoleFuture = widget.roleResolver != null
          ? _safeInvokeRoleResolver(userId)
          : UserRoleService.resolveUserRole(
              Supabase.instance.client,
              expectedUserId: userId,
            );
    }
    return _cachedRoleFuture!;
  }

  Future<UserRoleResolution> _safeInvokeRoleResolver(String userId) async {
    try {
      return await widget.roleResolver!(userId);
    } catch (e) {
      debugPrint('Error in roleResolver: $e');
      return const UserRoleResolution(
        status: UserRoleStatus.error,
        message: 'Unable to verify your account permissions. Please try again.',
      );
    }
  }

  void _retryRoleLookup(String userId) {
    setState(() {
      _cachedRoleUserId = userId;
      _cachedRoleFuture = widget.roleResolver != null
          ? _safeInvokeRoleResolver(userId)
          : UserRoleService.resolveUserRole(
              Supabase.instance.client,
              expectedUserId: userId,
            );
    });
  }

  Future<void> _handleSignOut() async {
    if (widget.onSignOut != null) {
      await widget.onSignOut!();
    } else {
      await Supabase.instance.client.auth.signOut();
    }
    if (mounted) {
      setState(() {
        _cachedRoleUserId = null;
        _cachedRoleFuture = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final stream =
        widget.authStateStream ?? Supabase.instance.client.auth.onAuthStateChange;

    return StreamBuilder<AuthState>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final event = snapshot.data?.event;
        if (event == AuthChangeEvent.passwordRecovery) {
          _isPasswordRecovery = true;
          return const ResetPasswordPage();
        }
        if (event == AuthChangeEvent.signedOut) {
          _isPasswordRecovery = false;
        }

        final session = snapshot.data?.session;

        if (_isPasswordRecovery && session != null) {
          return const ResetPasswordPage();
        }

        if (session != null) {
          final userId = session.user.id;
          final roleFuture = _resolveRoleForUser(userId);

          return FutureBuilder<UserRoleResolution>(
            future: roleFuture,
            builder: (context, roleSnapshot) {
              if (roleSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              final resolution = roleSnapshot.data ??
                  const UserRoleResolution(
                    status: UserRoleStatus.error,
                    message: 'Unable to verify your account permissions.',
                  );

              switch (resolution.status) {
                case UserRoleStatus.admin:
                  return widget.adminScreen ?? const AdminDashboardScreen();
                case UserRoleStatus.user:
                  return widget.userScreen ?? const UserHomeScreen();
                case UserRoleStatus.unauthorized:
                case UserRoleStatus.error:
                  return _RoleVerificationErrorScreen(
                    isUnauthorized:
                        resolution.status == UserRoleStatus.unauthorized,
                    message: resolution.message ??
                        'Unable to verify your account permissions.',
                    onRetry: () => _retryRoleLookup(userId),
                    onSignOut: _handleSignOut,
                  );
              }
            },
          );
        } else {
          _cachedRoleUserId = null;
          _cachedRoleFuture = null;
          return widget.loginScreen ?? const LoginPage();
        }
      },
    );
  }
}

class _RoleVerificationErrorScreen extends StatelessWidget {
  final bool isUnauthorized;
  final String message;
  final VoidCallback onRetry;
  final Future<void> Function() onSignOut;

  const _RoleVerificationErrorScreen({
    required this.isUnauthorized,
    required this.message,
    required this.onRetry,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F9FC),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFD9E2EC)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x121F3A5F),
                      blurRadius: 20,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: isUnauthorized
                            ? const Color(0xFFFDF0F3)
                            : const Color(0xFFFFF4E5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isUnauthorized
                            ? Icons.lock_outline
                            : Icons.cloud_off_outlined,
                        color: isUnauthorized
                            ? const Color(0xFFD95379)
                            : const Color(0xFFC17F24),
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isUnauthorized
                          ? 'Access Not Permitted'
                          : 'Verification Failed',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF1F3A5F),
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF5B6B7A),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton.icon(
                        onPressed: onRetry,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1F3A5F),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.refresh, size: 18),
                        label: Text(
                          'Retry',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          onSignOut();
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFD95379),
                          side: const BorderSide(color: Color(0xFFF5C6D2)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.logout, size: 18),
                        label: Text(
                          'Sign Out',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  final bool showAuthButton;

  const HomePage({super.key, this.showAuthButton = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: const [],
      ),
      body: Center(
        child: showAuthButton
            ? const Text('Welcome to DreamTeam SD3')
            : const Text('Welcome! You are logged in.'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const MapScreen()),
          );
        },
        tooltip: 'Open Map',
        child: const Icon(Icons.map),
      ),
    );
  }
}
