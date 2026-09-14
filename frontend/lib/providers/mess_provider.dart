import 'package:flutter/material.dart';
import '../models/mess_expense.dart';
import '../models/vendor.dart';
import '../models/student.dart';
import '../services/api_service.dart';

class MessProvider with ChangeNotifier {
  final ApiService _api = ApiService();

  // Mess Members State
  List<Student> _messMembers = [];
  int _totalAllCount = 0;
  int _totalOutsideCount = 0;
  int _totalHostelCount = 0;
  String _memberTypeFilter = 'ALL'; // 'ALL', 'OUTSIDE_ONLY', 'HOSTEL_ONLY'
  String _memberSearchQuery = '';

  // Mess Expenses State
  List<MessExpense> _expenses = [];
  Map<String, dynamic> _categoryTotals = {};
  double _totalExpense = 0.0;
  List<Vendor> _vendors = [];
  bool _isLoading = false;
  String? _error;
  String _selectedCategory = '';

  List<Student> get messMembers => _messMembers;
  int get totalAllCount => _totalAllCount;
  int get totalOutsideCount => _totalOutsideCount;
  int get totalHostelCount => _totalHostelCount;
  String get memberTypeFilter => _memberTypeFilter;

  List<MessExpense> get expenses => _expenses;
  Map<String, dynamic> get categoryTotals => _categoryTotals;
  double get totalExpense => _totalExpense;
  List<Vendor> get vendors => _vendors;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get selectedCategory => _selectedCategory;

  // --- Mess Members Operations ---
  Future<void> fetchMessMembers() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await _api.getMessMembers(
        type: _memberTypeFilter,
        search: _memberSearchQuery,
      );

      final rawList = res['data'] as List? ?? [];
      _messMembers = rawList.map((s) => Student.fromJson(s as Map<String, dynamic>)).toList();
      _totalAllCount = (res['totalAllCount'] as num?)?.toInt() ?? _messMembers.length;
      _totalOutsideCount = (res['totalOutsideCount'] as num?)?.toInt() ?? 0;
      _totalHostelCount = (res['totalHostelCount'] as num?)?.toInt() ?? 0;

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString().replaceAll('Exception:', '').trim();
      notifyListeners();
    }
  }

  void setMemberTypeFilter(String filter) {
    _memberTypeFilter = filter;
    fetchMessMembers();
  }

  void setMemberSearchQuery(String query) {
    _memberSearchQuery = query;
    fetchMessMembers();
  }

  Future<bool> createOutsideMessMember(Map<String, dynamic> data) async {
    try {
      await _api.createMessMember(data);
      await fetchMessMembers();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception:', '').trim();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateOutsideMessMember(String id, Map<String, dynamic> data) async {
    try {
      await _api.updateStudent(id, data);
      await fetchMessMembers();
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
      await fetchMessMembers();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception:', '').trim();
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, dynamic>> bulkExtendMessValidity({
    required int days,
    String? reason,
    String targetMemberType = 'ALL',
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await _api.bulkExtendMessValidity(
        days: days,
        reason: reason,
        targetMemberType: targetMemberType,
      );
      await fetchMessMembers();
      _isLoading = false;
      notifyListeners();
      return {'success': true, 'message': res['message']?.toString() ?? 'Mess validity extended', 'data': res['data']};
    } catch (e) {
      _isLoading = false;
      _error = e.toString().replaceAll('Exception:', '').trim();
      notifyListeners();
      return {'success': false, 'message': _error ?? 'Failed to extend mess validity'};
    }
  }

  // --- Expenses Operations ---
  Future<void> fetchExpenses({String? category, String? month}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await _api.getMessExpenses(
        category: category ?? (_selectedCategory.isNotEmpty ? _selectedCategory : null),
        month: month,
      );

      final rawList = res['data'] as List? ?? [];
      _expenses = rawList.map((e) => MessExpense.fromJson(e as Map<String, dynamic>)).toList();
      _categoryTotals = res['categoryTotals'] as Map<String, dynamic>? ?? {};
      _totalExpense = (res['totalExpense'] as num?)?.toDouble() ?? 0.0;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString().replaceAll('Exception:', '').trim();
      notifyListeners();
    }
  }

  void setCategoryFilter(String category) {
    _selectedCategory = category;
    fetchExpenses();
  }

  Future<bool> addExpense(Map<String, dynamic> data) async {
    try {
      await _api.addMessExpense(data);
      await fetchExpenses();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception:', '').trim();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteExpense(String id, String adminName) async {
    try {
      await _api.deleteMessExpense(id, adminName);
      await fetchExpenses();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception:', '').trim();
      notifyListeners();
      return false;
    }
  }

  Future<void> fetchVendors() async {
    try {
      _vendors = await _api.getVendors();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<bool> saveVendor(Map<String, dynamic> data) async {
    try {
      await _api.saveVendor(data);
      await fetchVendors();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception:', '').trim();
      notifyListeners();
      return false;
    }
  }
}
