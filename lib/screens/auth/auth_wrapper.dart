import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/biometric_service.dart';
import '../../models/UserModel.dart';
import 'login_screen.dart';
import 'biometric_lock_screen.dart';
import '../dashboard/dashboard_screen.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> with WidgetsBindingObserver {
  final _biometricService = BiometricService();
  bool _isBiometricCheckComplete = false;
  bool _requiresBiometric = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkBiometricRequirement();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // When app comes back to foreground, check if biometric is required
    if (state == AppLifecycleState.resumed) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && !_requiresBiometric) {
        _checkBiometricRequirement();
      }
    }
  }

  Future<void> _checkBiometricRequirement() async {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user != null) {
      // User is logged in, check if biometric is enabled
      final isEnabled = await _biometricService.isBiometricEnabled();
      final isAvailable = await _biometricService.isBiometricAvailable();
      
      setState(() {
        _requiresBiometric = isEnabled && isAvailable;
        _isBiometricCheckComplete = true;
      });
    } else {
      // User not logged in, no biometric required
      setState(() {
        _requiresBiometric = false;
        _isBiometricCheckComplete = true;
      });
    }
  }

  void _onBiometricAuthenticated() {
    setState(() {
      _requiresBiometric = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting ||
            !_isBiometricCheckComplete) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final user = snapshot.data;

        if (user == null) {
          // User not logged in
          return const LoginScreen();
        }

        // User is logged in
        if (_requiresBiometric) {
          // Show biometric lock screen
          return BiometricLockScreen(
            onAuthenticated: _onBiometricAuthenticated,
          );
        }

        // User authenticated, show dashboard
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
              // User data not found, logout
              FirebaseAuth.instance.signOut();
              return const LoginScreen();
            }

            final userData =
                userSnapshot.data!.data() as Map<String, dynamic>;
            final userModel = UserModel.fromJson(userData);

            return DashboardScreen(user: userModel);
          },
        );
      },
    );
  }
}
