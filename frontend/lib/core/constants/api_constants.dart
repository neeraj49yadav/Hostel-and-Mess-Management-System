import 'package:flutter/foundation.dart';

class ApiConstants {
  // Default URL based on platform and runtime origin
  static String get defaultBaseUrl {
    if (kIsWeb) {
      try {
        final uri = Uri.base;
        // If web app is hosted on Firebase, custom domain, or HTTPS
        if (uri.host.contains('web.app') ||
            uri.host.contains('firebaseapp.com') ||
            uri.scheme == 'https' ||
            uri.port == 5000) {
          return '${uri.origin}/api/v1';
        }
        // If web app is running in Flutter debug / dev server on localhost
        if (uri.host == 'localhost' || uri.host == '127.0.0.1') {
          return 'http://localhost:5000/api/v1';
        }
        // If web app is accessed via LAN IP on a dev server port (e.g. 10.74.11.194:8080)
        if (uri.host.isNotEmpty && uri.host != 'null' && !uri.host.startsWith('file')) {
          return 'http://${uri.host}:5000/api/v1';
        }
      } catch (_) {}
      return 'http://localhost:5000/api/v1';
    }
    // On Android physical devices or emulator
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.20.35.194:5000/api/v1';
    }
    return 'http://localhost:5000/api/v1';
  }

  // Endpoints
  static const String organizations = '/admins/organizations';
  static const String registerOrganization = '/admins/register-organization';
  static const String admins = '/admins';
  static const String verifyPin = '/admins/verify-pin';
  static const String forgotPin = '/admins/forgot-pin';
  static const String updatePin = '/admins/update-pin';
  static const String resetUserPin = '/admins/reset-user-pin';
  static const String addUser = '/admins/add-user';
  static const String updateProfile = '/admins/profile';
  static const String updateOrganization = '/admins/organization';
  static const String notifications = '/admins/notifications';
  static const String auditLogs = '/admins/audit-logs';
  static const String masterRegister = '/admins/master-register';
  static const String students = '/students';
  static const String rooms = '/rooms';
  static const String payments = '/payments';
  static const String messMembers = '/mess/members';
  static const String messExpenses = '/mess/expenses';
  static const String messVendors = '/mess/vendors';
  static const String leaves = '/leaves';
  static const String dashboardStats = '/stats/dashboard';
  static const String duesExpiries = '/stats/dues-expiries';
  static const String cashbook = '/stats/cashbook';
}
