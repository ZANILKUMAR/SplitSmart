import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../../services/biometric_service.dart';

class BiometricSettingsScreen extends StatefulWidget {
  const BiometricSettingsScreen({super.key});

  @override
  State<BiometricSettingsScreen> createState() =>
      _BiometricSettingsScreenState();
}

class _BiometricSettingsScreenState extends State<BiometricSettingsScreen> {
  final _biometricService = BiometricService();
  bool _isLoading = true;
  bool _isDeviceSupported = false;
  bool _isBiometricAvailable = false;
  bool _isBiometricEnabled = false;
  List<BiometricType> _availableBiometrics = [];
  String _supportedBiometrics = '';

  @override
  void initState() {
    super.initState();
    _checkBiometricStatus();
  }

  Future<void> _checkBiometricStatus() async {
    setState(() => _isLoading = true);

    try {
      final isSupported = await _biometricService.isDeviceSupported();
      final isAvailable = await _biometricService.isBiometricAvailable();
      final isEnabled = await _biometricService.isBiometricEnabled();
      final biometrics = await _biometricService.getAvailableBiometrics();
      final supportedString =
          await _biometricService.getSupportedBiometricsString();

      setState(() {
        _isDeviceSupported = isSupported;
        _isBiometricAvailable = isAvailable;
        _isBiometricEnabled = isEnabled;
        _availableBiometrics = biometrics;
        _supportedBiometrics = supportedString;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error checking biometric status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value) {
      // Enabling biometric - need to authenticate first
      final authenticated = await _biometricService.authenticate(
        reason: 'Please authenticate to enable biometric login',
      );

      if (!authenticated) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Authentication failed'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      await _biometricService.setBiometricEnabled(true);
      setState(() => _isBiometricEnabled = true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biometric authentication enabled'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      // Disabling biometric
      await _biometricService.setBiometricEnabled(false);
      setState(() => _isBiometricEnabled = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biometric authentication disabled'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Biometric Authentication'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Device Status Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _isDeviceSupported
                                  ? Icons.check_circle
                                  : Icons.cancel,
                              color: _isDeviceSupported
                                  ? Colors.green
                                  : Colors.red,
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Device Support',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isDeviceSupported
                              ? 'Your device supports biometric authentication'
                              : 'Your device does not support biometric authentication',
                          style: TextStyle(
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Available Biometrics Card
                if (_isDeviceSupported)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _isBiometricAvailable
                                    ? Icons.fingerprint
                                    : Icons.info_outline,
                                color: _isBiometricAvailable
                                    ? Colors.blue
                                    : Colors.orange,
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Available Biometrics',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isBiometricAvailable
                                ? _supportedBiometrics
                                : 'No biometric methods enrolled. Please set up fingerprint or face recognition in your device settings.',
                            style: TextStyle(
                              color:
                                  isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                          if (_isBiometricAvailable) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              children: _availableBiometrics.map((type) {
                                return Chip(
                                  avatar: Icon(
                                    _getBiometricIcon(type),
                                    size: 18,
                                  ),
                                  label: Text(
                                    _biometricService.getBiometricTypeName(type),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 16),

                // Enable/Disable Biometric Card
                if (_isBiometricAvailable)
                  Card(
                    child: SwitchListTile(
                      value: _isBiometricEnabled,
                      onChanged: _toggleBiometric,
                      title: const Text(
                        'Enable Biometric Login',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        _isBiometricEnabled
                            ? 'You will be asked to authenticate when opening the app'
                            : 'Enable to use biometric authentication for login',
                        style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                      secondary: Icon(
                        _isBiometricEnabled
                            ? Icons.lock
                            : Icons.lock_open,
                        color: _isBiometricEnabled
                            ? Colors.green
                            : Colors.grey,
                      ),
                    ),
                  ),

                const SizedBox(height: 16),

                // Information Card
                Card(
                  color: Colors.blue.withOpacity(0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.blue[700],
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'About Biometric Authentication',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '• Biometric authentication adds an extra layer of security to your account\n\n'
                          '• You can use fingerprint, face recognition, or other biometric methods supported by your device\n\n'
                          '• Your biometric data is stored securely on your device and never sent to our servers\n\n'
                          '• You can disable this feature at any time',
                          style: TextStyle(
                            color: isDark ? Colors.grey[300] : Colors.grey[800],
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Test Authentication Button
                if (_isBiometricAvailable && _isBiometricEnabled)
                  ElevatedButton.icon(
                    onPressed: _testAuthentication,
                    icon: const Icon(Icons.touch_app),
                    label: const Text('Test Authentication'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
              ],
            ),
    );
  }

  IconData _getBiometricIcon(BiometricType type) {
    switch (type) {
      case BiometricType.face:
        return Icons.face;
      case BiometricType.fingerprint:
        return Icons.fingerprint;
      case BiometricType.iris:
        return Icons.visibility;
      case BiometricType.strong:
        return Icons.security;
      case BiometricType.weak:
        return Icons.verified_user;
    }
  }

  Future<void> _testAuthentication() async {
    final authenticated = await _biometricService.authenticate(
      reason: 'Test your biometric authentication',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            authenticated
                ? 'Authentication successful! ✓'
                : 'Authentication failed',
          ),
          backgroundColor: authenticated ? Colors.green : Colors.red,
        ),
      );
    }
  }
}
