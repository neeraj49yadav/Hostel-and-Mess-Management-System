import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/admin_user.dart';
import '../models/organization.dart';
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

  AuthProvider() {
    _initOrganizationAndAdmins();
  }

  Future<void> _initOrganizationAndAdmins() async {
    await loadOrganizations();
    await _loadAvailableAdmins();
    await _restoreSavedSession();
    await loadNotifications();
  }

  Future<void> _restoreSavedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_jwt_token');
      final loggedAdminId = prefs.getString('logged_admin_id');

      if (token != null && token.isNotEmpty && loggedAdminId != null && loggedAdminId.isNotEmpty) {
        AdminUser? matched;
        for (final a in _availableAdmins) {
          if (a.id == loggedAdminId) {
            matched = a;
            break;
          }
        }

        if (matched != null) {
          _currentAdmin = matched;
        } else {
          final savedName = prefs.getString('logged_admin_name') ?? 'Admin';
          final savedPhone = prefs.getString('logged_admin_phone') ?? '';
          _currentAdmin = AdminUser(
            id: loggedAdminId,
            name: savedName,
            role: 'Admin',
            phone: savedPhone,
            orgId: _currentOrganization?.id ?? 'org-default',
            orgCode: _currentOrganization?.code ?? 'HOSTEL',
          );
        }

        _isAuthenticated = true;
        notifyListeners();
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
      if (_currentOrganization != null) {
        await _api.setSelectedOrg(_currentOrganization!.id, _currentOrganization!.code);
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
    await loadOrganizations();
    await _loadAvailableAdmins();
    notifyListeners();
  }
}

