import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/navigation/app_navigator.dart';
import '../models/admin_user.dart';
import '../models/organization.dart';
import '../screens/auth/pin_screen.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _api = ApiService();

  AdminUser? _currentAdmin;
  Organization? _currentOrganization;
  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _errorMessage;
  List<AdminUser> _availableAdmins = [];
  List<Organization> _availableOrganizations = [];

  List<Map<String, dynamic>> _notifications = [];

  AdminUser? get currentAdmin => _currentAdmin;
  Organization? get currentOrganization => _currentOrganization;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<AdminUser> get availableAdmins => _availableAdmins;
  List<Organization> get availableOrganizations => _availableOrganizations;
  List<Map<String, dynamic>> get notifications => _notifications;

  bool get isOrgAdmin {
    if (_currentAdmin == null) return false;
    final r = _currentAdmin!.role.toLowerCase();
    if (r.contains('chief') || r.contains('owner') || r.contains('super') || r.contains('primary')) {
      return true;
    }
    if (_availableAdmins.isNotEmpty && _availableAdmins.first.id == _currentAdmin!.id) {
      return true;
    }
    return false;
  }

  // Lock the current session and prompt for 4-digit PIN
  void lockSession() {
    _isAuthenticated = false;
    notifyListeners();
    AppNavigator.key.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const PinScreen()),
      (route) => false,
    );
  }

  AuthProvider({
    bool initialIsAuthenticated = false,
    AdminUser? initialAdmin,
    Organization? initialOrg,
  }) {
    // 🔒 Security: Cold start ALWAYS starts unauthenticated on PinScreen
    _isAuthenticated = false;
    if (initialAdmin != null) {
      _currentAdmin = initialAdmin;
    }
    if (initialOrg != null) {
      _currentOrganization = initialOrg;
    }
    _initOrganizationAndAdmins();
  }

  Future<void> _initOrganizationAndAdmins() async {
    await _restoreSavedSession();
    // ⚡ Fast non-blocking startup: dispatch background synchronization in parallel
    loadOrganizations().catchError((_) {});
    _loadAvailableAdmins().catchError((_) {});
    loadNotifications().catchError((_) {});
  }

  Future<void> _restoreSavedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_jwt_token');
      final loggedAdminId = prefs.getString('logged_admin_id');

      if (token != null && token.isNotEmpty && loggedAdminId != null && loggedAdminId.isNotEmpty) {
        final savedName = prefs.getString('logged_admin_name') ?? 'Admin';
        final savedPhone = prefs.getString('logged_admin_phone') ?? '';
        final savedRole = prefs.getString('logged_admin_role') ?? 'Admin';
        final savedPhoto = prefs.getString('logged_admin_photo');
        final savedOrgId = prefs.getString('selected_org_id') ?? 'org-default';
        final savedOrgCode = prefs.getString('selected_org_code') ?? 'HOSTEL';

        _currentAdmin = AdminUser(
          id: loggedAdminId,
          name: savedName,
          role: savedRole,
          phone: savedPhone,
          profilePhoto: savedPhoto,
          orgId: savedOrgId,
          orgCode: savedOrgCode,
        );

        _currentOrganization ??= Organization(
          id: savedOrgId,
          name: prefs.getString('selected_org_name') ?? 'My Hostel & Mess',
          code: savedOrgCode,
          city: prefs.getString('selected_org_city') ?? '',
          contactPhone: prefs.getString('selected_org_phone') ?? '',
          logo: prefs.getString('selected_org_logo'),
        );

        // 🔒 Security: Restoring session does NOT auto-login; always require 4-digit PIN!
        _isAuthenticated = false;
        notifyListeners();
      } else {
        final savedOrgId = prefs.getString('selected_org_id');
        if (savedOrgId != null) {
          _currentOrganization ??= Organization(
            id: savedOrgId,
            name: prefs.getString('selected_org_name') ?? 'My Hostel & Mess',
            code: prefs.getString('selected_org_code') ?? 'HOSTEL',
            city: prefs.getString('selected_org_city') ?? '',
            contactPhone: prefs.getString('selected_org_phone') ?? '',
            logo: prefs.getString('selected_org_logo'),
          );
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('[AuthProvider] Error restoring session: $e');
    }
  }

  Future<void> loadNotifications() async {
    try {
      _notifications = await _api.getNotifications();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> refreshAdmins() async {
    await _loadAvailableAdmins();
  }

  // --- Staff / User Management Methods ---

  Future<bool> addUser({
    required String name,
    required String role,
    required String pin,
    String? phone,
    String? profilePhoto,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _api.addUser({
        'name': name.trim(),
        'role': role.trim(),
        'pin': pin.trim(),
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
        if (profilePhoto != null && profilePhoto.trim().isNotEmpty) 'profilePhoto': profilePhoto.trim(),
      });
      await _loadAvailableAdmins();
      await loadNotifications();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateUser(
    String id, {
    required String name,
    required String role,
    String? phone,
    String? profilePhoto,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _api.updateUser(id, {
        'name': name.trim(),
        'role': role.trim(),
        if (phone != null) 'phone': phone.trim(),
        if (profilePhoto != null) 'profilePhoto': profilePhoto.trim(),
      });
      await _loadAvailableAdmins();
      if (_currentAdmin?.id == id) {
        _currentAdmin = _currentAdmin!.copyWith(
          name: name,
          role: role,
          phone: phone,
          profilePhoto: profilePhoto,
        );
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteUser(String id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _api.deleteUser(id);
      await _loadAvailableAdmins();
      await loadNotifications();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      notifyListeners();
      return false;
    }
  }

  Future<bool> resetStaffPin({
    required String targetAdminId,
    required String newPin,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _api.resetUserPin(targetAdminId, newPin);
      await _loadAvailableAdmins();
      await loadNotifications();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateMyPin({
    required String currentPin,
    required String newPin,
  }) async {
    if (_currentAdmin == null) return false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _api.updateMyPin(
        adminId: _currentAdmin!.id,
        currentPin: currentPin,
        newPin: newPin,
      );
      _currentAdmin = _currentAdmin!.copyWith(pin: newPin);
      await _loadAvailableAdmins();
      await loadNotifications();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, dynamic>> forgotPin({
    required String phone,
    required String newPin,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _api.forgotPin(
        phone: phone,
        newPin: newPin,
        orgId: _currentOrganization?.id,
        orgCode: _currentOrganization?.code,
      );
      await _loadAvailableAdmins();
      _isLoading = false;
      notifyListeners();
      return {'success': true, 'message': res['message'] ?? 'PIN reset successfully!'};
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      notifyListeners();
      return {'success': false, 'message': _errorMessage};
    }
  }

  Future<bool> updateProfile({
    required String name,
    String? phone,
    String? profilePhoto,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _api.updateProfile(
        name: name,
        phone: phone,
        profilePhoto: profilePhoto,
      );
      if (res['data'] != null) {
        _currentAdmin = AdminUser.fromJson(res['data']);
      } else if (_currentAdmin != null) {
        _currentAdmin = _currentAdmin!.copyWith(
          name: name,
          phone: phone,
          profilePhoto: profilePhoto,
        );
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('logged_admin_name', name);
      if (phone != null) await prefs.setString('logged_admin_phone', phone);
      if (profilePhoto != null && profilePhoto.isNotEmpty) {
        await prefs.setString('logged_admin_photo', profilePhoto);
      }
      await _loadAvailableAdmins();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateOrganization({
    required String name,
    String? logo,
    String? city,
    String? contactPhone,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _api.updateOrganization(
        name: name,
        logo: logo,
        city: city,
        contactPhone: contactPhone,
      );

      if (res['data'] != null) {
        _currentOrganization = Organization.fromJson(res['data']);
        await _api.setSelectedOrg(_currentOrganization!.id, _currentOrganization!.code);
      } else if (_currentOrganization != null) {
        _currentOrganization = _currentOrganization!.copyWith(
          name: name,
          logo: logo,
          city: city,
          contactPhone: contactPhone,
        );
        await _api.setSelectedOrg(_currentOrganization!.id, _currentOrganization!.code);
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_org_name', name);
      if (city != null) await prefs.setString('selected_org_city', city);
      if (contactPhone != null) await prefs.setString('selected_org_phone', contactPhone);
      if (logo != null && logo.isNotEmpty) await prefs.setString('selected_org_logo', logo);

      await loadOrganizations();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      notifyListeners();
      return false;
    }
  }

  Future<void> loadOrganizations() async {
    try {
      _availableOrganizations = await _api.getOrganizations();
      final prefs = await SharedPreferences.getInstance();
      final savedOrgId = prefs.getString('selected_org_id');

      if (savedOrgId != null && _availableOrganizations.isNotEmpty) {
        _currentOrganization = _availableOrganizations.firstWhere(
          (o) => o.id == savedOrgId,
          orElse: () => _availableOrganizations.first,
        );
      } else if (_availableOrganizations.isNotEmpty) {
        _currentOrganization = _availableOrganizations.first;
      } else {
        _currentOrganization = null;
      }
      notifyListeners();
    } catch (_) {
      // Offline fallback: default organization
      _availableOrganizations = [
        Organization(
          id: 'org-default',
          name: 'My Hostel & Mess',
          code: 'HOSTEL',
          city: 'Main Campus',
          contactPhone: '',
        ),
      ];
      _currentOrganization = _availableOrganizations.first;
      notifyListeners();
    }
  }

  Future<void> selectOrganization(Organization org) async {
    _currentOrganization = org;
    await _api.setSelectedOrg(org.id, org.code);
    await _loadAvailableAdmins();
    notifyListeners();
  }

  Future<void> _loadAvailableAdmins() async {
    try {
      _availableAdmins = await _api.getAdmins();
      notifyListeners();
    } catch (_) {
      // Offline fallback: default 3 admins for default org
      if (_currentOrganization == null || _currentOrganization!.id == 'org-default') {
        _availableAdmins = [
          AdminUser(id: 'admin-1', orgId: 'org-default', orgCode: 'CITYPRIDE', name: 'Warden 1 (Chief Warden)', role: 'Chief Warden', phone: '9876543210'),
          AdminUser(id: 'admin-2', orgId: 'org-default', orgCode: 'CITYPRIDE', name: 'Warden 2 (Hostel In-charge)', role: 'Hostel In-charge', phone: '9876543211'),
          AdminUser(id: 'admin-3', orgId: 'org-default', orgCode: 'CITYPRIDE', name: 'Warden 3 (Mess In-charge)', role: 'Mess In-charge', phone: '9876543212'),
        ];
      } else {
        _availableAdmins = [];
      }
      notifyListeners();
    }
  }

  // Register New Organization from Login Screen
  Future<bool> registerOrganization({
    required String orgName,
    String? orgCode,
    String? city,
    String? contactPhone,
    required String adminName,
    String? adminPhone,
    required String adminPin,
    String? adminRole,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _api.registerOrganization({
        'orgName': orgName.trim(),
        'orgCode': orgCode != null && orgCode.isNotEmpty ? orgCode.trim() : null,
        'city': city != null && city.isNotEmpty ? city.trim() : null,
        'contactPhone': contactPhone != null && contactPhone.isNotEmpty ? contactPhone.trim() : null,
        'adminName': adminName.trim(),
        'adminPhone': adminPhone != null && adminPhone.isNotEmpty ? adminPhone.trim() : null,
        'adminPin': adminPin.trim(),
        'adminRole': adminRole ?? 'Chief Warden / Owner',
      });

      final Organization newOrg = res['organization'] as Organization;
      final AdminUser admin = res['admin'] as AdminUser;

      _currentOrganization = newOrg;
      _currentAdmin = admin;
      _isAuthenticated = true;
      _isLoading = false;

      await _api.setSelectedOrg(newOrg.id, newOrg.code);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('logged_admin_id', admin.id);
      await prefs.setString('logged_admin_name', admin.name);
      await prefs.setString('logged_admin_role', admin.role);
      await prefs.setString('logged_admin_phone', admin.phone);
      if (admin.profilePhoto != null && admin.profilePhoto!.isNotEmpty) {
        await prefs.setString('logged_admin_photo', admin.profilePhoto!);
      }
      await prefs.setString('selected_org_id', newOrg.id);
      await prefs.setString('selected_org_code', newOrg.code);
      await prefs.setString('selected_org_name', newOrg.name);
      await prefs.setString('selected_org_city', newOrg.city);
      await prefs.setString('selected_org_phone', newOrg.contactPhone);
      if (newOrg.logo != null && newOrg.logo!.isNotEmpty) {
        await prefs.setString('selected_org_logo', newOrg.logo!);
      }

      await loadOrganizations();
      await _loadAvailableAdmins();

      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      notifyListeners();
      return false;
    }
  }

  // Verify PIN & Login
  Future<bool> loginWithPin(String pin, {String? orgId, String? orgCode}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final targetOrgId = orgId ?? _currentOrganization?.id;
      final targetOrgCode = orgCode ?? _currentOrganization?.code;

      final res = await _api.verifyPin(pin, orgId: targetOrgId, orgCode: targetOrgCode);
      final AdminUser admin = res['admin'] as AdminUser;
      final Organization? org = res['organization'] as Organization?;

      _currentAdmin = admin;
      if (org != null) {
        _currentOrganization = org;
      }
      _isAuthenticated = true;
      _isLoading = false;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('logged_admin_id', admin.id);
      await prefs.setString('logged_admin_name', admin.name);
      await prefs.setString('logged_admin_role', admin.role);
      await prefs.setString('logged_admin_phone', admin.phone);
      if (admin.profilePhoto != null && admin.profilePhoto!.isNotEmpty) {
        await prefs.setString('logged_admin_photo', admin.profilePhoto!);
      } else {
        await prefs.remove('logged_admin_photo');
      }

      if (_currentOrganization != null) {
        await _api.setSelectedOrg(_currentOrganization!.id, _currentOrganization!.code);
        await prefs.setString('selected_org_name', _currentOrganization!.name);
        await prefs.setString('selected_org_city', _currentOrganization!.city);
        await prefs.setString('selected_org_phone', _currentOrganization!.contactPhone);
        if (_currentOrganization!.logo != null && _currentOrganization!.logo!.isNotEmpty) {
          await prefs.setString('selected_org_logo', _currentOrganization!.logo!);
        } else {
          await prefs.remove('selected_org_logo');
        }
      }

      notifyListeners();
      return true;
    } catch (e) {
      // Offline fallback: PIN 1111, 2222, 3333 on default org
      if ((_currentOrganization == null || _currentOrganization!.id == 'org-default') &&
          (pin == '1111' || pin == '2222' || pin == '3333')) {
        int idx = pin == '1111' ? 0 : (pin == '2222' ? 1 : 2);
        final admin = _availableAdmins.isNotEmpty
            ? _availableAdmins[idx % _availableAdmins.length]
            : AdminUser(id: 'admin-${idx + 1}', name: 'Warden ${idx + 1}', role: 'Admin', phone: '987654321$idx');
        _currentAdmin = admin;
        _isAuthenticated = true;
        _isLoading = false;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('logged_admin_id', admin.id);
        await prefs.setString('logged_admin_name', admin.name);
        await prefs.setString('logged_admin_role', admin.role);
        await prefs.setString('logged_admin_phone', admin.phone);
        await _api.setAuthToken('fallback-token-${admin.id}');

        notifyListeners();
        return true;
      }

      _isLoading = false;
      _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _currentAdmin = null;
    _isAuthenticated = false;
    await _api.clearAuthToken();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('logged_admin_id');
    await prefs.remove('logged_admin_name');
    await prefs.remove('logged_admin_role');
    await prefs.remove('logged_admin_phone');
    await prefs.remove('logged_admin_photo');
    await prefs.remove('pending_photo_context');
    await loadOrganizations();
    await _loadAvailableAdmins();
    notifyListeners();
    AppNavigator.key.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const PinScreen()),
      (route) => false,
    );
  }
}

