import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'map_screen.dart';
import 'login_page.dart';
import 'user_screens/user_home_screen.dart';
import 'reset_password_page.dart';

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
      anonKey: supabaseAnonKey,
    );
    runApp(const MyApp());
  } catch (e) {
    print('Error initializing Supabase: $e');
    rethrow;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'App',
      debugShowCheckedModeBanner: false,
      home: AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    _checkRememberMe();
    _checkDeepLink();
  }

  Future<void> _checkRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool('rememberMe') ?? false;

    if (!rememberMe) {
      // Sign out if remember me is not checked
      await Supabase.instance.client.auth.signOut();
    }
  }

  Future<void> _checkDeepLink() async {
    // Check if app was opened via deep link
    // Supabase Flutter handles deep links automatically
    // We need to check if there's a recovery session
    await Future.delayed(const Duration(milliseconds: 500)); // Wait for auth to initialize
    
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      // Check if user is logged in - if not, this might be a recovery session
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        // Recovery session detected - navigate to reset password page
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const ResetPasswordPage()),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final session = snapshot.data?.session;

        if (session != null) {
          return const UserHomeScreen();
        } else {
          return const LoginPage();
        }
      },
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
        actions: const [
          // if (!showAuthButton)
          //   IconButton(
          //     icon: const Icon(Icons.logout),
          //     onPressed: () async {
          //       await AuthService().signOut();
          //     },
          //   ),
        ],
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
