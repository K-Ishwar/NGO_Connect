import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get user stream
  Stream<User?> get userStream => _auth.authStateChanges();

  // Get current user details from Firestore
  Future<UserModel?> getUserDetails(String uid) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) { debugPrint(e.toString());
      return null;
    }
  }

  // Register User
  Future<UserModel?> registerUser({
    required String email,
    required String password,
    required String role,
    required String name,
    String? location,
    String? availability,
    String? phoneNumber,
    List<String> skills = const [],
  }) async {
    try {
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);
      
      User? user = userCredential.user;

      if (user != null) {
        UserModel userModel = UserModel(
          id: user.uid,
          role: role,
          name: name,
          email: email,
          skills: skills,
          location: location,
          availability: availability,
          phoneNumber: phoneNumber,
        );

        await _firestore
            .collection('users')
            .doc(user.uid)
            .set(userModel.toMap());

        return userModel;
      }
    } on FirebaseAuthException catch (e) {
      // Re-throw with readable message
      final msg = e.code == 'email-already-in-use'
          ? 'This email is already registered. Please login instead.'
          : e.code == 'weak-password'
          ? 'Password too weak. Use at least 6 characters.'
          : e.code == 'invalid-email'
          ? 'Invalid email address format.'
          : 'Registration failed: ${e.message}';
      throw Exception(msg);
    } catch (e) {
      throw Exception('Registration failed: $e');
    }
    return null;
  }

  // Login User
  Future<UserModel?> loginUser(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      
      User? user = result.user;
      
      if (user != null) {
        return await getUserDetails(user.uid);
      }
    } on FirebaseAuthException catch (e) {
      final msg = e.code == 'user-not-found'
          ? 'No account found for this email. Please register first.'
          : e.code == 'wrong-password' || e.code == 'invalid-credential'
          ? 'Incorrect password. Please try again.'
          : e.code == 'invalid-email'
          ? 'Invalid email address.'
          : e.code == 'too-many-requests'
          ? 'Too many attempts. Try again later.'
          : 'Login failed: ${e.message}';
      throw Exception(msg);
    } catch (e) {
      throw Exception('Login failed: $e');
    }
    return null;
  }

  // Google Sign-In
  Future<UserModel?> signInWithGoogle(String role) async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await _auth.signInWithCredential(credential);
      User? user = userCredential.user;

      if (user != null) {
        // Check if user exists
        DocumentSnapshot doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          return await getUserDetails(user.uid);
        } else {
          // Create new user record
          UserModel userModel = UserModel(
            id: user.uid,
            role: role, // Assigned from UI selection during Google Login
            name: user.displayName ?? 'Google User',
            email: user.email ?? '',
          );
          await _firestore.collection('users').doc(user.uid).set(userModel.toMap());
          return userModel;
        }
      }
    } catch (e) { debugPrint(e.toString());
    }
    return null;
  }

  // Logout
  Future<void> logout() async {
    try {
      await GoogleSignIn().signOut();
    } catch (e) {
      // Ignore errors if Google Sign In is not initialized (e.g. on Web) debugPrint('Google sign out error: $e');
    }
    await _auth.signOut();
  }
}
