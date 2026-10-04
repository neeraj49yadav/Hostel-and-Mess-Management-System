import 'package:flutter/material.dart';
import '../models/dashboard_stats.dart';
import '../models/student.dart';
import '../services/api_service.dart';

class DashboardProvider with ChangeNotifier {
  final ApiService _api = ApiService();

  DashboardStats? _stats;
  bool _isLoading = false;
  String? _error;

  // Dues Hub lists
  List<Student> _messPendingDues = [];
  List<Student> _messExpiringSoon = [];
  List<Student> _messOverdue = [];
  List<Student> _rentExpiringSoon = [];
  List<Student> _rentOverdue = [];
  List<Student> _active = [];

  Map<String, dynamic>? _cashbookData;

  DashboardStats? get stats => _stats;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<Student> get messPendingDues => _messPendingDues;
  List<Student> get messExpiringSoon => _messExpiringSoon;
  List<Student> get messOverdue => _messOverdue;
  List<Student> get rentExpiringSoon => _rentExpiringSoon;
  List<Student> get rentOverdue => _rentOverdue;
  List<Student> get active => _active;
  Map<String, dynamic>? get cashbookData => _cashbookData;

  double get totalPendingMessDuesAmount =>
      (_stats?.allMessDuesAmount ?? 0) > 0
          ? (_stats!.allMessDuesAmount)
          : (_messPendingDues.fold(0.0, (sum, s) => sum + s.messBalanceDue) +
              _messOverdue.fold(0.0, (sum, s) => sum + s.messBalanceDue));

  int get totalPendingMessStudentsCount =>
      (_stats?.allMessDuesCount ?? 0) > 0
          ? (_stats!.allMessDuesCount)
          : (_messPendingDues.length + _messOverdue.length);

  double get currentMessDuesAmount =>
      (_stats?.currentMessDuesAmount ?? 0) > 0
          ? (_stats!.currentMessDuesAmount)
          : _messPendingDues.fold(0.0, (sum, s) => sum + s.messBalanceDue);

  double get overdueMessDuesAmount =>
      (_stats?.overdueMessDuesAmount ?? 0) > 0
          ? (_stats!.overdueMessDuesAmount)
          : _messOverdue.fold(0.0, (sum, s) => sum + s.messBalanceDue);

  int get totalAlertsCount =>
      _stats != null
          ? _stats!.totalAlertsCount
          : (_messPendingDues.length +
              _messOverdue.length +
              _messExpiringSoon.length +
              _rentExpiringSoon.length +
              _rentOverdue.length);

  Future<void> fetchDashboardStats() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _stats = await _api.getDashboardStats();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString().replaceAll('Exception:', '').trim();
      notifyListeners();
    }
  }

  Future<void> fetchDuesAndExpiries() async {
    try {
      final res = await _api.getDuesAndExpiries();
      final mPendingList = res['messPendingDues'] as List? ?? [];
      final mExpList = res['messExpiringSoon'] as List? ?? [];
      final mOvList = res['messOverdue'] as List? ?? [];
      final rExpList = res['rentExpiringSoon'] as List? ?? [];
      final rOvList = res['rentOverdue'] as List? ?? [];
      final actList = res['active'] as List? ?? [];

      _messPendingDues = mPendingList.map((s) => Student.fromJson(s as Map<String, dynamic>)).toList();
      _messExpiringSoon = mExpList.map((s) => Student.fromJson(s as Map<String, dynamic>)).toList();
      _messOverdue = mOvList.map((s) => Student.fromJson(s as Map<String, dynamic>)).toList();
      _rentExpiringSoon = rExpList.map((s) => Student.fromJson(s as Map<String, dynamic>)).toList();
      _rentOverdue = rOvList.map((s) => Student.fromJson(s as Map<String, dynamic>)).toList();
      _active = actList.map((s) => Student.fromJson(s as Map<String, dynamic>)).toList();

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> fetchCashbook({String? month}) async {
    try {
      _cashbookData = await _api.getCashbook(month: month);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
}
