import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/notification_model.dart';

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> initNotifications() async {
    // Request permission for iOS/Web
    await _firebaseMessaging.requestPermission();

    // Get current token and save to user's document
    String? token = await _firebaseMessaging.getToken();
    if (token != null) {
      await _saveTokenToDatabase(token);
    }

    // Listen to token refresh
    _firebaseMessaging.onTokenRefresh.listen(_saveTokenToDatabase);

    // Foreground notifications handler
    FirebaseMessaging.onMessage.listen((RemoteMessage message) { debugPrint('Got a message whilst in the foreground!'); debugPrint('Message data: ${message.data}');

      if (message.notification != null) { debugPrint('Message also contained a notification: ${message.notification}');
      }
      // You could push these into a local UI state / snackbar here
    });
  }

  Future<void> _saveTokenToDatabase(String token) async {
    String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      await _firestore.collection('users').doc(userId).update({
        'fcmToken': token,
      });
    }
  }

  // Subscribe to topic (used for sending high urgency announcements to all devices)
  Future<void> subscribeToHighUrgency() async {
    await _firebaseMessaging.subscribeToTopic('high_urgency');
  }

  // Record a notification in Firestore logs (useful for in-app notification center)
  Future<void> logNotification({
    required String title,
    required String body,
    required String targetUserId,
  }) async {
    final notification = NotificationModel(
      title: title,
      body: body,
      userId: targetUserId,
      date: DateTime.now(),
    );
    await _firestore.collection('notifications').add(notification.toMap());
  }
}
