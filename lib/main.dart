import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/auth_service.dart';
import 'models/user_model.dart';
import 'screens/login_screen.dart';
import 'screens/ngo_dashboard.dart';
import 'screens/volunteer_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // We assume Firebase has been successfully configured via flutterfire configure
  // Ensure that firebase_options.dart exists and passes DefaultFirebaseOptions.currentPlatform
  // Since we don't have user's interactive output, we'll try initializing and warn if failed
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase not configured: $e");
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NGO Connect',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return StreamBuilder<User?>(
      stream: authService.userStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          final user = snapshot.data;
          if (user == null) {
            return const LoginScreen();
          } else {
            return FutureBuilder<UserModel?>(
              future: authService.getUserDetails(user.uid),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                if (userSnapshot.hasData && userSnapshot.data != null) {
                  UserModel userModel = userSnapshot.data!;
                  if (userModel.role == 'ngo') {
                    return const NgoDashboard();
                  } else {
                    return const VolunteerDashboard();
                  }
                }
                // Fallback
                return const LoginScreen();
              },
            );
          }
        }
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}
