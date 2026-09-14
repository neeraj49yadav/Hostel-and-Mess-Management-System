import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/hostel_provider.dart';
import 'providers/mess_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/auth/pin_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HostelMessAdminApp());
}

class HostelMessAdminApp extends StatelessWidget {
  const HostelMessAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(create: (_) => HostelProvider()),
        ChangeNotifierProvider(create: (_) => MessProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Hostel and Mess Management System',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            home: const PinScreen(),
          );
        },
      ),
    );
  }
}
