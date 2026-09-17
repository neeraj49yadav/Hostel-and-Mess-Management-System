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
import 'services/api_service.dart';
import 'services/image_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ⚡ Pre-warm backend immediately in background (wakes Render container before user finishes entering PIN)
  ApiService().preWarmServer();

  // ⚡ Synchronously restore organization and admin session from SharedPreferences.
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
  } else if (prefs.containsKey('selected_org_id')) {
    initialOrg = Organization(
      id: orgId,
      name: prefs.getString('selected_org_name') ?? 'My Hostel & Mess',
      code: orgCode,
      city: prefs.getString('selected_org_city') ?? '',
      contactPhone: prefs.getString('selected_org_phone') ?? '',
      logo: prefs.getString('selected_org_logo'),
    );
  }

  // 🔒 Security: When the app is closed and opened again, ALWAYS require 4-digit PIN!
  // Only auto-authenticate if recovering from an active native camera capture.
  final pendingPhoto = prefs.getString('pending_photo_context');
  final bool isCameraRecovery = pendingPhoto != null && pendingPhoto.isNotEmpty;
  final bool autoAuthenticate = isCameraRecovery && hasValidSession;

  runApp(HostelMessAdminApp(
    initialIsAuthenticated: autoAuthenticate,
    initialAdmin: initialAdmin,
    initialOrg: initialOrg,
  ));
}

class HostelMessAdminApp extends StatefulWidget {
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
  State<HostelMessAdminApp> createState() => _HostelMessAdminAppState();
}

class _HostelMessAdminAppState extends State<HostelMessAdminApp> with WidgetsBindingObserver {
  late final AuthProvider _authProvider;
  DateTime? _backgroundedTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authProvider = AuthProvider(
      initialIsAuthenticated: widget.initialIsAuthenticated,
      initialAdmin: widget.initialAdmin,
      initialOrg: widget.initialOrg,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _backgroundedTime = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      if (_backgroundedTime != null) {
        final elapsedSeconds = DateTime.now().difference(_backgroundedTime!).inSeconds;
        _backgroundedTime = null;

        // Check if camera or image picker was actively open
        final pendingPhoto = await ImageService.getPendingPhotoContext();
        if (pendingPhoto != null && pendingPhoto.isNotEmpty) {
          // Camera capture in progress - do not lock
          return;
        }

        // If backgrounded for more than 15 seconds, lock the app to PIN screen for security
        if (elapsedSeconds >= 15 && _authProvider.isAuthenticated) {
          _authProvider.lockSession();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider.value(value: _authProvider),
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
