import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/UserModel.dart';

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  UserModel? get currentUser {
    final user = _auth.currentUser;
    if (user == null) return null;
    
    return UserModel(
      uid: user.uid,
      email: user.email ?? '',
      name: user.displayName ?? '',
      phoneNumber: user.phoneNumber ?? '',
    );
  }

  // Sign in with email and password
  Future<UserModel?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      print('AuthService: Attempting login for email: $email');
      
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      if (userCredential.user != null) {
        print('AuthService: Login successful for: $email');
        
        // Fetch user data from Firestore
        final userDoc = await _firestore
            .collection('users')
            .doc(userCredential.user!.uid)
            .get();

        if (userDoc.exists) {
          return UserModel.fromJson({
            ...userDoc.data()!,
            'uid': userCredential.user!.uid,
          });
        } else {
          // If user document doesn't exist, create one with email
          return UserModel(
            uid: userCredential.user!.uid,
            email: userCredential.user!.email ?? email,
            name: userCredential.user!.displayName ?? '',
            phoneNumber: userCredential.user!.phoneNumber ?? '',
          );
        }
      }
      
      throw AuthException('Login failed');
    } on FirebaseAuthException catch (e) {
      print('AuthService: Firebase Auth Error: ${e.code}');
      switch (e.code) {
        case 'user-not-found':
          throw AuthException('No user found with this email');
        case 'wrong-password':
          throw AuthException('Wrong password provided');
        case 'invalid-email':
          throw AuthException('Invalid email address');
        case 'user-disabled':
          throw AuthException('This account has been disabled');
        default:
          throw AuthException('Login failed: ${e.message}');
      }
    } catch (e) {
      print('AuthService: Login error: $e');
      throw AuthException('Invalid credentials');
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Password reset
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      print('Password reset email sent to $email');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        throw AuthException('No user found with this email');
      }
      throw AuthException('Password reset failed: ${e.message}');
    }
  }

  // Check if email is already in use
  Future<bool> isEmailInUse(String email) async {
    try {
      final methods = await _auth.fetchSignInMethodsForEmail(email.trim());
      return methods.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Register with email and password
  Future<UserModel?> registerWithEmailAndPassword(
    String email,
    String password,
    String name,
    String phoneNumber,
  ) async {
    try {
      print('AuthService: Attempting registration for email: $email');

      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      if (userCredential.user != null) {
        // Update display name
        await userCredential.user!.updateDisplayName(name);

        final UserModel newUser = UserModel(
          uid: userCredential.user!.uid,
          email: email.trim(),
          name: name,
          phoneNumber: phoneNumber,
        );

        // Store user data in Firestore
        await _firestore
            .collection('users')
            .doc(userCredential.user!.uid)
            .set(newUser.toJson());

        print('AuthService: Registration successful for: $email');
        return newUser;
      }

      throw AuthException('Registration failed');
    } on FirebaseAuthException catch (e) {
      print('AuthService: Firebase Auth Error: ${e.code}');
      switch (e.code) {
        case 'weak-password':
          throw AuthException('The password provided is too weak');
        case 'email-already-in-use':
          throw AuthException('An account already exists for this email');
        case 'invalid-email':
          throw AuthException('Invalid email address');
        default:
          throw AuthException('Registration failed: ${e.message}');
      }
    } catch (e) {
      print('AuthService: Registration error: $e');
      throw AuthException(e.toString());
    }
  }
}