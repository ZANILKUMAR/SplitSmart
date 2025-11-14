import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'screens/auth/auth_wrapper.dart';
import 'constants/app_theme.dart';
import 'providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        // Determine which theme to use based on selection
        ThemeData selectedTheme;
        if (themeProvider.themeMode == ThemeMode.dark) {
          selectedTheme = AppTheme.darkTheme;
        } else if (themeProvider.themeMode == ThemeMode.system) {
          selectedTheme = AppTheme.systemTheme;
        } else {
          selectedTheme = AppTheme.lightTheme;
        }

        return MaterialApp(
          title: 'Split Smart',
          theme: selectedTheme,
          themeMode: themeProvider.themeMode,
          home: const AuthWrapper(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
