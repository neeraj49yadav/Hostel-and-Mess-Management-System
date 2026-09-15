import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'models/admin_user.dart';
import 'models/organization.dart';
import 'providers/auth_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/hostel_provider.dart';
import 'providers/mess_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/auth/pin_screen.dart';
import 'screens/home_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ⚡ Synchronously restore auth session from SharedPreferences BEFORE first frame renders.
  // This completely eliminates camera-induced logouts and prevents PIN screen from flashing.
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('auth_jwt_token');
  final adminId = prefs.getString('logged_admin_id');
  final adminName = prefs.getString('logged_admin_name');
  final adminRole = prefs.getString('logged_admin_role') ?? 'Admin';
  final adminPhone = prefs.getString('logged_admin_phone') ?? '';
  final adminPhoto = prefs.getString('logged_admin_photo');
  final orgId = prefs.getString('selected_org_id') ?? 'org-default';
  final orgCode = prefs.getString('selected_org_code') ?? 'HOSTEL';

  final bool hasValidSession = token != null && token.isNotEmpty && adminId != null && adminId.isNotEmpty;

  AdminUser? initialAdmin;
  Organization? initialOrg;
  if (hasValidSession) {
    initialAdmin = AdminUser(
      id: adminId,
      name: adminName ?? 'Admin',
      role: adminRole,
      phone: adminPhone,
      profilePhoto: adminPhoto,
      orgId: orgId,
      orgCode: orgCode,
    );
    initialOrg = Organization(
      id: orgId,
      name: prefs.getString('selected_org_name') ?? 'My Hostel & Mess',
      code: orgCode,
      city: prefs.getString('selected_org_city') ?? '',
      contactPhone: prefs.getString('selected_org_phone') ?? '',
      logo: prefs.getString('selected_org_logo'),
    );
  }

  runApp(HostelMessAdminApp(
    initialIsAuthenticated: hasValidSession,
    initialAdmin: initialAdmin,
    initialOrg: initialOrg,
  ));
}

class HostelMessAdminApp extends StatelessWidget {
  final bool initialIsAuthenticated;
  final AdminUser? initialAdmin;
  final Organization? initialOrg;

  const HostelMessAdminApp({
    super.key,
    this.initialIsAuthenticated = false,
    this.initialAdmin,
    this.initialOrg,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(
          create: (_) => AuthProvider(
            initialIsAuthenticated: initialIsAuthenticated,
            initialAdmin: initialAdmin,
            initialOrg: initialOrg,
          ),
        ),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(create: (_) => HostelProvider()),
        ChangeNotifierProvider(create: (_) => MessProvider()),
      ],
      child: Consumer2<ThemeProvider, AuthProvider>(
        builder: (context, themeProvider, authProvider, child) {
          return MaterialApp(
            title: 'Hostel and Mess Management System',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            home: authProvider.isAuthenticated ? const HomeShell() : const PinScreen(),
          );
        },
      ),
    );
  }
}
