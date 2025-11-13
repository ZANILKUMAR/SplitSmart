import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/UserModel.dart';

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

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

  // Sign in with email or phone number
  Future<UserModel?> signInWithEmailOrPhone(
    String emailOrPhone,
    String password,
  ) async {
    try {
      print('AuthService: Attempting login for: $emailOrPhone');

      String email;
      Map<String, dynamic>? cachedUserData;
      String? cachedUserId;
      
      // Check if input is email or phone number
      if (emailOrPhone.contains('@')) {
        // It's an email
        email = emailOrPhone.trim();
      } else {
        // It's a phone number, find the associated email
        print('AuthService: Looking up user by phone: $emailOrPhone');
        final phoneQuery = await _firestore
            .collection('users')
            .where('phoneNumber', isEqualTo: emailOrPhone.trim())
            .limit(1)
            .get();

        if (phoneQuery.docs.isEmpty) {
          throw AuthException('Login failed - Invalid email or password');
        }

        // Cache the user data to avoid another Firestore query
        final userDoc = phoneQuery.docs.first;
        cachedUserData = userDoc.data();
        cachedUserId = userDoc.id;
        email = cachedUserData['email'] as String? ?? '';
        
        if (email.isEmpty) {
          throw AuthException('Login failed - Invalid email or password');
        }
        print('AuthService: Found user data for phone number');
      }

      // Authenticate with Firebase Auth
      final UserCredential userCredential = await _auth
          .signInWithEmailAndPassword(email: email, password: password);

      if (userCredential.user != null) {
        print('AuthService: Authentication successful');

        // If we already have cached user data from phone lookup, use it
        if (cachedUserData != null && cachedUserId != null) {
          print('AuthService: Using cached user data');
          return UserModel.fromJson({
            ...cachedUserData,
            'uid': userCredential.user!.uid,
          });
        }

        // Otherwise, fetch user data from Firestore
        try {
          final userDoc = await _firestore
              .collection('users')
              .doc(userCredential.user!.uid)
              .get();

          if (userDoc.exists) {
            return UserModel.fromJson({
              ...userDoc.data()!,
              'uid': userCredential.user!.uid,
            });
          }
        } catch (firestoreError) {
          print(
            'AuthService: Firestore error (will use fallback): $firestoreError',
          );
        }

        // Fallback: use Firebase Auth data
        return UserModel(
          uid: userCredential.user!.uid,
          email: userCredential.user!.email ?? email,
          name: userCredential.user!.displayName ?? email.split('@')[0],
          phoneNumber: userCredential.user!.phoneNumber ?? '',
        );
      }

      throw AuthException('Login failed');
    } on FirebaseAuthException catch (e) {
      print('AuthService: Firebase Auth Error: ${e.code}');
      switch (e.code) {
        case 'user-not-found':
          throw AuthException('Login failed - Invalid email or password');
        case 'wrong-password':
          throw AuthException('Login failed - Invalid email or password');
        case 'invalid-credential':
          throw AuthException('Login failed - Invalid email or password');
        case 'invalid-email':
          throw AuthException('Invalid email address');
        case 'user-disabled':
          throw AuthException('This account has been disabled');
        case 'too-many-requests':
          throw AuthException('Too many failed attempts. Please try again later');
        default:
          throw AuthException('Login failed - Invalid email or password');
      }
    } catch (e) {
      print('AuthService: Login error: $e');
      throw AuthException('Login failed - Invalid email or password');
    }
  }

  // Sign in with email and password (kept for backward compatibility)
  Future<UserModel?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    return signInWithEmailOrPhone(email, password);
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
  }

  // Sign in with Google
  Future<UserModel?> signInWithGoogle() async {
    try {
      print('AuthService: Attempting Google Sign-In');
      
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        // User canceled the sign-in
        print('AuthService: Google Sign-In cancelled by user');
        return null;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final UserCredential userCredential = await _auth.signInWithCredential(credential);

      if (userCredential.user != null) {
        print('AuthService: Google Sign-In successful');

        final user = userCredential.user!;
        
        // Check if user document exists in Firestore
        final userDoc = await _firestore.collection('users').doc(user.uid).get();

        if (!userDoc.exists) {
          // Create new user document
          final newUser = UserModel(
            uid: user.uid,
            email: user.email ?? '',
            name: user.displayName ?? '',
            phoneNumber: user.phoneNumber ?? '',
          );

          await _firestore.collection('users').doc(user.uid).set(newUser.toJson());
          print('AuthService: Created new user document for Google user');
          
          return newUser;
        } else {
          // Return existing user data
          return UserModel.fromJson({
            ...userDoc.data()!,
            'uid': user.uid,
          });
        }
      }

      throw AuthException('Google Sign-In failed');
    } on FirebaseAuthException catch (e) {
      print('AuthService: Firebase Auth Error: ${e.code}');
      switch (e.code) {
        case 'account-exists-with-different-credential':
          throw AuthException('An account already exists with the same email');
        case 'invalid-credential':
          throw AuthException('Invalid credentials. Please try again');
        case 'user-disabled':
          throw AuthException('This account has been disabled');
        default:
          throw AuthException('Google Sign-In failed: ${e.message}');
      }
    } catch (e) {
      print('AuthService: Google Sign-In error: $e');
      if (e is AuthException) {
        rethrow;
      }
      throw AuthException('Failed to sign in with Google');
    }
  }

  // Password reset with email or phone number
  Future<void> resetPasswordWithEmailOrPhone(String emailOrPhone) async {
    try {
      String email;
      
      // Check if input is email or phone number
      if (emailOrPhone.contains('@')) {
        // It's an email
        email = emailOrPhone.trim();
      } else {
        // It's a phone number, find the associated email
        print('AuthService: Looking up email for phone: $emailOrPhone');
        final phoneQuery = await _firestore
            .collection('users')
            .where('phoneNumber', isEqualTo: emailOrPhone.trim())
            .limit(1)
            .get();

        if (phoneQuery.docs.isEmpty) {
          throw AuthException('No user found with this phone number');
        }

        final userData = phoneQuery.docs.first.data();
        email = userData['email'] as String? ?? '';
        
        if (email.isEmpty) {
          throw AuthException('No email associated with this account');
        }
        print('AuthService: Found email for phone number');
      }

      await _auth.sendPasswordResetEmail(email: email);
      print('Password reset email sent to $email');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        throw AuthException('No user found with this email or phone number');
      }
      throw AuthException('Password reset failed: ${e.message}');
    } catch (e) {
      if (e is AuthException) {
        rethrow;
      }
      throw AuthException('Failed to send password reset email');
    }
  }

  // Password reset (kept for backward compatibility)
  Future<void> resetPassword(String email) async {
    return resetPasswordWithEmailOrPhone(email);
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

      final UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(
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
