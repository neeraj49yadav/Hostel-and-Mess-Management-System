import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/api_constants.dart';
import '../models/admin_user.dart';
import '../models/organization.dart';
import '../models/student.dart';
import '../models/room.dart';
import '../models/payment.dart';
import '../models/mess_expense.dart';
import '../models/vendor.dart';
import '../models/leave_log.dart';
import '../models/dashboard_stats.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String? _customBaseUrl;
  String? _cachedAuthToken;
  String? _cachedOrgId;
  String? _cachedOrgCode;

  Future<String> get baseUrl async {
    if (_customBaseUrl != null && _customBaseUrl!.isNotEmpty) {
      return _customBaseUrl!;
    }
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('custom_backend_url');
    if (saved != null && saved.isNotEmpty) {
      _customBaseUrl = saved;
      return saved;
    }
    return ApiConstants.defaultBaseUrl;
  }

  Future<void> setBaseUrl(String url) async {
    _customBaseUrl = url.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('custom_backend_url', _customBaseUrl!);
  }

  Future<String?> get authToken async {
    if (_cachedAuthToken != null && _cachedAuthToken!.isNotEmpty) {
      return _cachedAuthToken;
    }
    final prefs = await SharedPreferences.getInstance();
    _cachedAuthToken = prefs.getString('auth_jwt_token');
    return _cachedAuthToken;
  }

  Future<void> setAuthToken(String token) async {
    _cachedAuthToken = token.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_jwt_token', _cachedAuthToken!);
  }

  Future<void> clearAuthToken() async {
    _cachedAuthToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_jwt_token');
  }

  Future<String?> get selectedOrgId async {
    if (_cachedOrgId != null && _cachedOrgId!.isNotEmpty) {
      return _cachedOrgId;
    }
    final prefs = await SharedPreferences.getInstance();
    _cachedOrgId = prefs.getString('selected_org_id') ?? 'org-default';
    return _cachedOrgId;
  }

  Future<String?> get selectedOrgCode async {
    if (_cachedOrgCode != null && _cachedOrgCode!.isNotEmpty) {
      return _cachedOrgCode;
    }
    final prefs = await SharedPreferences.getInstance();
    _cachedOrgCode = prefs.getString('selected_org_code') ?? 'CITYPRIDE';
    return _cachedOrgCode;
  }

  Future<void> setSelectedOrg(String orgId, String orgCode) async {
    _cachedOrgId = orgId.trim();
    _cachedOrgCode = orgCode.trim().toUpperCase();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_org_id', _cachedOrgId!);
    await prefs.setString('selected_org_code', _cachedOrgCode!);
  }

  // 🛡️ Build Secure Request Headers with Bearer Token and Multi-tenant Scope
  Future<Map<String, String>> _buildHeaders() async {
    final token = await authToken;
    final orgId = await selectedOrgId;
    final prefs = await SharedPreferences.getInstance();
    final adminId = prefs.getString('logged_admin_id');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    if (orgId != null && orgId.isNotEmpty) {
      headers['x-org-id'] = orgId;
    }
    if (adminId != null && adminId.isNotEmpty) {
      headers['x-admin-id'] = adminId;
    }
    return headers;
  }

  // Generic Secure HTTP Helpers
  Future<Map<String, dynamic>> _get(String endpoint, {Map<String, String>? params}) async {
    final base = await baseUrl;
    var uri = Uri.parse('$base$endpoint');
    if (params != null && params.isNotEmpty) {
      uri = uri.replace(queryParameters: params);
    }
    final headers = await _buildHeaders();
    final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    } else {
      final err = _safeDecodeError(response.body);
      throw Exception(err['message'] ?? 'Server error (${response.statusCode})');
    }
  }

  Future<Map<String, dynamic>> _post(String endpoint, Map<String, dynamic> body) async {
    final base = await baseUrl;
    final uri = Uri.parse('$base$endpoint');
    final headers = await _buildHeaders();
    final response = await http
        .post(
          uri,
          headers: headers,
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    } else {
      final err = _safeDecodeError(response.body);
      throw Exception(err['message'] ?? 'Failed request (${response.statusCode})');
    }
  }

  Future<Map<String, dynamic>> _put(String endpoint, Map<String, dynamic> body) async {
    final base = await baseUrl;
    final uri = Uri.parse('$base$endpoint');
    final headers = await _buildHeaders();
    final response = await http
        .put(
          uri,
          headers: headers,
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    } else {
      final err = _safeDecodeError(response.body);
      throw Exception(err['message'] ?? 'Failed request (${response.statusCode})');
    }
  }

  Future<Map<String, dynamic>> _delete(String endpoint, {Map<String, dynamic>? body}) async {
    final base = await baseUrl;
    final uri = Uri.parse('$base$endpoint');
    final headers = await _buildHeaders();
    final response = await http
        .delete(
          uri,
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    } else {
      final err = _safeDecodeError(response.body);
      throw Exception(err['message'] ?? 'Failed request (${response.statusCode})');
    }
  }

  Map<String, dynamic> _safeDecodeError(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return {'message': body};
    }
  }

  // --- 1. Admin, Organization & Auth ---
  Future<List<Organization>> getOrganizations() async {
    final res = await _get(ApiConstants.organizations);
    final list = res['data'] as List? ?? [];
    return list.map((o) => Organization.fromJson(o)).toList();
  }

  Future<Map<String, dynamic>> registerOrganization(Map<String, dynamic> data) async {
    final res = await _post(ApiConstants.registerOrganization, data);
    if (res['token'] != null) {
      await setAuthToken(res['token'].toString());
    }
    if (res['organization'] != null) {
      final org = Organization.fromJson(res['organization']);
      await setSelectedOrg(org.id, org.code);
    }
    return {
      'organization': Organization.fromJson(res['organization']),
      'admin': AdminUser.fromJson(res['admin']),
      'token': res['token']?.toString(),
      'message': res['message']?.toString(),
    };
  }

  Future<List<AdminUser>> getAdmins() async {
    final res = await _get('${ApiConstants.admins}/list');
    final list = res['data'] as List? ?? [];
    return list.map((a) => AdminUser.fromJson(a)).toList();
  }

  Future<Map<String, dynamic>> verifyPin(String pin, {String? orgId, String? orgCode}) async {
    final body = <String, dynamic>{'pin': pin};
    if (orgId != null && orgId.isNotEmpty) body['orgId'] = orgId;
    if (orgCode != null && orgCode.isNotEmpty) body['orgCode'] = orgCode;

    final res = await _post(ApiConstants.verifyPin, body);
    if (res['token'] != null) {
      await setAuthToken(res['token'].toString());
    }
    if (res['organization'] != null) {
      final org = Organization.fromJson(res['organization']);
      await setSelectedOrg(org.id, org.code);
    }
    return {
      'admin': AdminUser.fromJson(res['admin']),
      'organization': res['organization'] != null ? Organization.fromJson(res['organization']) : null,
      'token': res['token']?.toString(),
    };
  }

  Future<Map<String, dynamic>> forgotPin({
    required String phone,
    required String newPin,
    String? orgId,
    String? orgCode,
  }) async {
    final body = <String, dynamic>{
      'phone': phone,
      'newPin': newPin,
    };
    if (orgId != null && orgId.isNotEmpty) body['orgId'] = orgId;
    if (orgCode != null && orgCode.isNotEmpty) body['orgCode'] = orgCode;

    return await _post(ApiConstants.forgotPin, body);
  }

  Future<List<Map<String, dynamic>>> getAuditLogs() async {
    final res = await _get(ApiConstants.auditLogs);
    final list = res['data'] as List? ?? [];
    return list.map((e) => e as Map<String, dynamic>).toList();
  }

  Future<List<Map<String, dynamic>>> getNotifications() async {
    final res = await _get(ApiConstants.notifications);
    final list = res['data'] as List? ?? [];
    return list.map((e) => e as Map<String, dynamic>).toList();
  }

  // 📜 Get Permanent Master Register (Hostel & Mess Archive)
  Future<Map<String, dynamic>> getMasterRegister({
    String? search,
    String? status,
    String? type,
  }) async {
    final params = <String, String>{};
    if (search != null && search.trim().isNotEmpty) params['search'] = search.trim();
    if (status != null && status.isNotEmpty && status != 'ALL') params['status'] = status;
    if (type != null && type.isNotEmpty && type != 'ALL') params['type'] = type;

    final res = await _get(ApiConstants.masterRegister, params: params.isNotEmpty ? params : null);
    return res;
  }

  Future<Map<String, dynamic>> addUser(Map<String, dynamic> data) async {
    final res = await _post(ApiConstants.addUser, data);
    return res;
  }

  Future<Map<String, dynamic>> updateUser(String id, Map<String, dynamic> data) async {
    final res = await _put('${ApiConstants.admins}/users/$id', data);
    return res;
  }

  Future<void> deleteUser(String id) async {
    await _delete('${ApiConstants.admins}/users/$id');
  }

  Future<Map<String, dynamic>> resetUserPin(String targetAdminId, String newPin) async {
    final res = await _post(ApiConstants.resetUserPin, {
      'targetAdminId': targetAdminId,
      'newPin': newPin.trim(),
    });
    return res;
  }

  Future<Map<String, dynamic>> updateMyPin({
    required String adminId,
    required String currentPin,
    required String newPin,
  }) async {
    final res = await _post(ApiConstants.updatePin, {
      'adminId': adminId,
      'currentPin': currentPin.trim(),
      'newPin': newPin.trim(),
    });
    return res;
  }

  Future<Map<String, dynamic>> updateProfile({
    required String name,
    String? phone,
    String? profilePhoto,
  }) async {
    final res = await _put(ApiConstants.updateProfile, {
      'name': name.trim(),
      if (phone != null) 'phone': phone.trim(),
      if (profilePhoto != null) 'profilePhoto': profilePhoto.trim(),
    });
    return res;
  }

  Future<Map<String, dynamic>> updateOrganization({
    required String name,
    String? logo,
    String? city,
    String? contactPhone,
  }) async {
    final res = await _put(ApiConstants.updateOrganization, {
      'name': name.trim(),
      if (logo != null) 'logo': logo.trim(),
      if (city != null) 'city': city.trim(),
      if (contactPhone != null) 'contactPhone': contactPhone.trim(),
    });
    return res;
  }

  // --- 2. Dashboard & Expiry Alerts ---
  Future<DashboardStats> getDashboardStats() async {
    final res = await _get(ApiConstants.dashboardStats);
    return DashboardStats.fromJson(res['data']);
  }

  Future<Map<String, dynamic>> getDuesAndExpiries() async {
    return await _get(ApiConstants.duesExpiries);
  }

  Future<Map<String, dynamic>> getCashbook({String? month}) async {
    final params = <String, String>{};
    if (month != null) params['month'] = month;
    return await _get(ApiConstants.cashbook, params: params);
  }

  // --- 3. Students ---
  Future<List<Student>> getStudents({String? status, String? search, String? roomId}) async {
    final params = <String, String>{};
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (roomId != null && roomId.isNotEmpty) params['roomId'] = roomId;
    final res = await _get(ApiConstants.students, params: params);
    final list = res['data'] as List? ?? [];
    return list.map((s) => Student.fromJson(s)).toList();
  }

  Future<Map<String, dynamic>> getStudentById(String id) async {
    final res = await _get('${ApiConstants.students}/$id');
    return res['data'];
  }

  Future<Student> createStudent(Map<String, dynamic> data) async {
    final res = await _post(ApiConstants.students, data);
    return Student.fromJson(res['data']);
  }

  Future<Student> updateStudent(String id, Map<String, dynamic> data) async {
    final res = await _put('${ApiConstants.students}/$id', data);
    return Student.fromJson(res['data']);
  }

  Future<void> deleteStudent(String id, String adminName) async {
    await _delete('${ApiConstants.students}/$id', body: {'adminName': adminName});
  }

  Future<void> shiftBed(String studentId, String targetRoomId, String targetBedNo, String adminName) async {
    await _post('${ApiConstants.students}/$studentId/shift-bed', {
      'targetRoomId': targetRoomId,
      'targetBedNo': targetBedNo,
      'adminName': adminName,
    });
  }

  Future<void> checkoutStudent(String studentId, String adminName, String? reason, {bool removeFromMess = false}) async {
    await _post('${ApiConstants.students}/$studentId/checkout', {
      'adminName': adminName,
      'reason': reason,
      'removeFromMess': removeFromMess,
    });
  }

  // --- 4. Rooms ---
  Future<List<Room>> getRooms() async {
    final res = await _get(ApiConstants.rooms);
    final list = (res['data'] ?? res['rooms']) as List? ?? [];
    return list.map((r) => Room.fromJson(r)).toList();
  }

  Future<Room> createRoom(Map<String, dynamic> data) async {
    final res = await _post(ApiConstants.rooms, data);
    return Room.fromJson(res['data']);
  }

  Future<Room> updateRoom(String id, Map<String, dynamic> data) async {
    final res = await _put('${ApiConstants.rooms}/$id', data);
    return Room.fromJson(res['data']);
  }

  // --- 5. Payments ---
  Future<Map<String, dynamic>> recordPayment(Map<String, dynamic> data) async {
    return await _post(ApiConstants.payments, data);
  }

  Future<List<Payment>> getPayments({String? studentId, String? month}) async {
    final params = <String, String>{};
    if (studentId != null) params['studentId'] = studentId;
    if (month != null) params['month'] = month;
    final res = await _get(ApiConstants.payments, params: params);
    final list = res['data'] as List? ?? [];
    return list.map((p) => Payment.fromJson(p)).toList();
  }

  // --- 6. Mess Members & Expenses ---
  Future<Map<String, dynamic>> getMessMembers({String? type, String? search}) async {
    final params = <String, String>{};
    if (type != null && type.isNotEmpty && type != 'ALL') params['type'] = type;
    if (search != null && search.isNotEmpty) params['search'] = search;
    return await _get(ApiConstants.messMembers, params: params);
  }

  Future<Student> createMessMember(Map<String, dynamic> data) async {
    final res = await _post(ApiConstants.messMembers, data);
    return Student.fromJson(res['data']);
  }

  Future<void> unenrollMessMember(String id, String adminName, {bool removeFromHostel = false, String? reason}) async {
    await _post('${ApiConstants.messMembers}/$id/unenroll', {
      'adminName': adminName,
      'removeFromHostel': removeFromHostel,
      'reason': reason,
    });
  }

  Future<Map<String, dynamic>> bulkExtendMessValidity({
    required int days,
    String? reason,
    String targetMemberType = 'ALL',
  }) async {
    return await _post('/mess/bulk-extend-validity', {
      'days': days,
      'reason': reason,
      'targetMemberType': targetMemberType,
    });
  }

  Future<Map<String, dynamic>> getMessExpenses({String? category, String? month}) async {
    final params = <String, String>{};
    if (category != null && category.isNotEmpty) params['category'] = category;
    if (month != null && month.isNotEmpty) params['month'] = month;
    return await _get(ApiConstants.messExpenses, params: params);
  }

  Future<MessExpense> addMessExpense(Map<String, dynamic> data) async {
    final res = await _post(ApiConstants.messExpenses, data);
    return MessExpense.fromJson(res['data']);
  }

  Future<void> deleteMessExpense(String id, String adminName) async {
    await _delete('${ApiConstants.messExpenses}/$id', body: {'adminName': adminName});
  }

  Future<List<Vendor>> getVendors() async {
    final res = await _get(ApiConstants.messVendors);
    final list = res['data'] as List? ?? [];
    return list.map((v) => Vendor.fromJson(v)).toList();
  }

  Future<Vendor> saveVendor(Map<String, dynamic> data) async {
    final res = await _post(ApiConstants.messVendors, data);
    return Vendor.fromJson(res['data']);
  }

  // --- 7. Leave / In-Out Register ---
  Future<List<LeaveLog>> getLeaveLogs({String? status}) async {
    final params = <String, String>{};
    if (status != null) params['status'] = status;
    final res = await _get(ApiConstants.leaves, params: params);
    final list = res['data'] as List? ?? [];
    return list.map((l) => LeaveLog.fromJson(l)).toList();
  }

  Future<LeaveLog> recordDeparture(Map<String, dynamic> data) async {
    final res = await _post(ApiConstants.leaves, data);
    return LeaveLog.fromJson(res['data']);
  }

  Future<LeaveLog> recordReturn(String leaveId, String adminName) async {
    final res = await _post('${ApiConstants.leaves}/$leaveId/return', {'adminName': adminName});
    return LeaveLog.fromJson(res['data']);
  }

  // --- 8. Offline & Annual Backups Export ---
  Future<String> downloadMasterDataCsv() async {
    final base = await baseUrl;
    final token = await authToken;
    final url = Uri.parse('$base/export/master-data?format=csv');
    final res = await http.get(url, headers: {
      if (token != null) 'Authorization': 'Bearer $token',
    });
    if (res.statusCode == 200) {
      return res.body;
    }
    throw Exception('Failed to download Master Data (${res.statusCode}): ${res.body}');
  }

  Future<String> downloadCashbookPnlCsv({int? year}) async {
    final base = await baseUrl;
    final token = await authToken;
    final url = Uri.parse('$base/export/cashbook-pnl?format=csv${year != null ? '&year=$year' : ''}');
    final res = await http.get(url, headers: {
      if (token != null) 'Authorization': 'Bearer $token',
    });
    if (res.statusCode == 200) {
      return res.body;
    }
    throw Exception('Failed to download Cashbook & P&L (${res.statusCode}): ${res.body}');
  }

  Future<String> downloadFullBackupJson() async {
    final base = await baseUrl;
    final token = await authToken;
    final url = Uri.parse('$base/export/backup');
    final res = await http.get(url, headers: {
      if (token != null) 'Authorization': 'Bearer $token',
    });
    if (res.statusCode == 200) {
      return res.body;
    }
    throw Exception('Failed to download Backup (${res.statusCode}): ${res.body}');
  }
}
