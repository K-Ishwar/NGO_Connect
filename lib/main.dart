import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'services/offline_sync_service.dart';
import 'models/user_model.dart';
import 'screens/login_screen.dart';
import 'screens/ngo_dashboard.dart';
import 'screens/volunteer_dashboard.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, such as Firestore,
  // make sure you call `initializeApp` before using other Firebase services.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Initialize Notification Service handlers
    await NotificationService().initNotifications();

    // Initialize Hive for offline storage
    await OfflineSyncService.initHive();
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
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF2F2F2),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFF2F2F2)),
        textTheme: GoogleFonts.poppinsTextTheme(
          Theme.of(context).textTheme,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF2F2F2),
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.black87),
          titleTextStyle: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
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

    return StreamBuilder<bool>(
      stream: OfflineSyncService.connectivityStream,
      initialData: true,
      builder: (context, connectivitySnapshot) {
        final isOnline = connectivitySnapshot.data ?? true;

        // When connectivity is restored, auto-sync pending offline data
        if (isOnline) {
          OfflineSyncService.syncPendingFeedback();
        }

        return Column(
          children: [
            // Offline banner
            if (!isOnline)
              Material(
                color: Colors.transparent,
                child: Container(
                  width: double.infinity,
                  color: Colors.orange.shade800,
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.wifi_off, color: Colors.white, size: 14),
                      const SizedBox(width: 8),
                      Text(
                        'Offline Mode — ${OfflineSyncService.pendingCount} item(s) pending sync',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: StreamBuilder<User?>(
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
                          return const LoginScreen();
                        },
                      );
                    }
                  }
                  return const Scaffold(body: Center(child: CircularProgressIndicator()));
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
