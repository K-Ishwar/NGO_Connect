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
    } catch (e) {
      print(e.toString());
      return null;
    }
  }

  // Register User
  Future<UserModel?> registerUser({
    required String email,
    required String password,
    required String role,
    required String name,
    String? skills,
    String? location,
    String? availability,
    String? phoneNumber,
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
    } catch (e) {
      print(e.toString());
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
    } catch (e) {
      print(e.toString());
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
    } catch (e) {
      print(e.toString());
    }
    return null;
  }

  // Logout
  Future<void> logout() async {
    try {
      await GoogleSignIn().signOut();
    } catch (e) {
      // Ignore errors if Google Sign In is not initialized (e.g. on Web)
      print('Google sign out error: $e');
    }
    await _auth.signOut();
  }
}
