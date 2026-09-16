import 'package:flutter/material.dart';
import '../models/student.dart';
import '../models/room.dart';
import '../models/payment.dart';
import '../models/leave_log.dart';
import '../services/api_service.dart';

class HostelProvider with ChangeNotifier {
  final ApiService _api = ApiService();

  List<Student> _students = [];
  List<Room> _rooms = [];
  List<Payment> _payments = [];
  List<LeaveLog> _leaveLogs = [];
  bool _isLoading = false;
  String? _error;

  String _searchQuery = '';
  String _statusFilter = '';
  String _roomFilter = '';

  List<Student> get students => _students;
  List<Room> get rooms => _rooms;
  List<Payment> get payments => _payments;
  List<LeaveLog> get leaveLogs => _leaveLogs;
  bool get isLoading => _isLoading;
  String? get error => _error;

  String get searchQuery => _searchQuery;
  String get statusFilter => _statusFilter;
  String get roomFilter => _roomFilter;

  Future<void> fetchStudents() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _students = await _api.getStudents(
        search: _searchQuery,
        status: _statusFilter,
        roomId: _roomFilter,
      );
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString().replaceAll('Exception:', '').trim();
      notifyListeners();
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    fetchStudents();
  }

  void setStatusFilter(String status) {
    _statusFilter = status;
    fetchStudents();
  }

  void setRoomFilter(String roomId) {
    _roomFilter = roomId;
    fetchStudents();
  }

  Future<void> fetchRooms() async {
    try {
      _rooms = await _api.getRooms();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<bool> createRoom(Map<String, dynamic> data) async {
    try {
      await _api.createRoom(data);
      await fetchRooms();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception:', '').trim();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateRoom(String id, Map<String, dynamic> data) async {
    try {
      await _api.updateRoom(id, data);
      await fetchRooms();
      await fetchStudents();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception:', '').trim();
      notifyListeners();
      return false;
    }
  }

  Future<bool> createStudent(Map<String, dynamic> data) async {
    try {
      await _api.createStudent(data);
      await fetchStudents();
      await fetchRooms();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception:', '').trim();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateStudent(String id, Map<String, dynamic> data) async {
    try {
      await _api.updateStudent(id, data);
      await fetchStudents();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception:', '').trim();
      notifyListeners();
      return false;
    }
  }

  Future<bool> shiftBed(String id, String newRoomId, String newBedNo, String adminName) async {
    try {
      await _api.shiftBed(id, newRoomId, newBedNo, adminName);
      await fetchStudents();
      await fetchRooms();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception:', '').trim();
      notifyListeners();
      return false;
    }
  }

  Future<bool> checkoutStudent(String id, String adminName, String? reason, {bool removeFromMess = false}) async {
    try {
      await _api.checkoutStudent(id, adminName, reason, removeFromMess: removeFromMess);
      await fetchStudents();
      await fetchRooms();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception:', '').trim();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteStudent(String id, String adminName) async {
    try {
      await _api.deleteStudent(id, adminName);
      await fetchStudents();
      await fetchRooms();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception:', '').trim();
      notifyListeners();
      return false;
    }
  }

  Future<bool> unenrollMessMember(String id, String adminName, {bool removeFromHostel = false, String? reason}) async {
    try {
      await _api.unenrollMessMember(id, adminName, removeFromHostel: removeFromHostel, reason: reason);
      await fetchStudents();
      await fetchRooms();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception:', '').trim();
      notifyListeners();
      return false;
    }
  }

  // Payments
  Future<void> fetchPayments({String? month}) async {
    try {
      _payments = await _api.getPayments(month: month);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> recordPayment(Map<String, dynamic> data) async {
    try {
      final res = await _api.recordPayment(data);
      await fetchPayments();
      await fetchStudents();
      return res;
    } catch (e) {
      _error = e.toString().replaceAll('Exception:', '').trim();
      notifyListeners();
      return null;
    }
  }

  Future<bool> deletePayment(String paymentId, {String? reason, String? adminName}) async {
    try {
      await _api.deletePayment(paymentId, reason: reason, adminName: adminName);
      await fetchPayments();
      await fetchStudents();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception:', '').trim();
      notifyListeners();
      return false;
    }
  }

  // Leave Logs
  Future<void> fetchLeaveLogs({String? status}) async {
    try {
      _leaveLogs = await _api.getLeaveLogs(status: status);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<bool> recordDeparture(Map<String, dynamic> data) async {
    try {
      await _api.recordDeparture(data);
      await fetchLeaveLogs();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception:', '').trim();
      notifyListeners();
      return false;
    }
  }

  Future<bool> recordReturn(String id, String adminName) async {
    try {
      await _api.recordReturn(id, adminName);
      await fetchLeaveLogs();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception:', '').trim();
      notifyListeners();
      return false;
    }
  }
}
