import 'package:flutter/foundation.dart';

class ApiConstants {
  // Production Cloud Backend on Render
  static const String productionCloudUrl = 'https://hostel-and-mess-management-system.onrender.com/api/v1';

  // Default URL based on platform and runtime origin
  static String get defaultBaseUrl {
    if (kIsWeb) {
      try {
        final uri = Uri.base;
        // If web app is running locally on localhost dev server
        if (uri.host == 'localhost' || uri.host == '127.0.0.1') {
          return 'http://localhost:5000/api/v1';
        }
      } catch (_) {}
      return productionCloudUrl;
    }
    // On Android physical devices, iOS, or release builds: Connect to Live Cloud
    return productionCloudUrl;
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
