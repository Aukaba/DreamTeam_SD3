import 'package:flutter/material.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'map_screen.dart';
import 'login_page.dart';
// import 'Authentication/auth_service.dart';
// import 'Authentication/sign_in_screen.dart';

Future<void> main() async {
  // await dotenv.load(fileName: ".env");
  // await Supabase.initialize(
  //   url: dotenv.env['SUPABASE_URL']!,
  //   anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  // );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App',
      debugShowCheckedModeBanner: false,
      home: const LoginPage(),
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
        actions: [
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
