import 'student.dart';

class DashboardStats {
  final int totalStudents;
  final int messPendingDuesCount;
  final int messExpiringSoonCount;
  final int messOverdueCount;
  final int rentExpiringSoonCount;
  final int rentOverdueCount;
  final int totalOverdueCount;
  final int totalRooms;
  final int totalBeds;
  final int occupiedBeds;
  final int vacantBeds;
  final int occupancyPercentage;
  final double monthRentInflow;
  final double monthMessInflow;
  final double totalInflow;
  final double totalMessExpense;
  final double netProfitBalance;
  final bool isProfitable;
  final int currentlyOutCount;
  final List<Student> messPendingDues;
  final List<Student> messExpiringSoon;
  final List<Student> messOverdue;
  final List<Student> rentExpiringSoon;
  final List<Student> rentOverdue;

  final double totalPendingMessDuesAmount;
  final double totalCurrentMessDuesAmount;
  final double totalOverdueMessDuesAmount;
  final int totalPendingMessDuesCount;

  int get expiringSoonCount => messExpiringSoonCount + rentExpiringSoonCount;
  int get overdueCount => totalOverdueCount;
  int get totalAlertsCount =>
      messPendingDuesCount +
      messOverdueCount +
      messExpiringSoonCount +
      rentExpiringSoonCount +
      rentOverdueCount;

  double get allMessDuesAmount => totalPendingMessDuesAmount > 0
      ? totalPendingMessDuesAmount
      : (messPendingDues.fold(0.0, (sum, s) => sum + s.messBalanceDue) +
          messOverdue.fold(0.0, (sum, s) => sum + s.messBalanceDue));

  int get allMessDuesCount => totalPendingMessDuesCount > 0
      ? totalPendingMessDuesCount
      : (messPendingDues.length + messOverdue.length);

  double get currentMessDuesAmount => totalCurrentMessDuesAmount > 0
      ? totalCurrentMessDuesAmount
      : messPendingDues.fold(0.0, (sum, s) => sum + s.messBalanceDue);

  double get overdueMessDuesAmount => totalOverdueMessDuesAmount > 0
      ? totalOverdueMessDuesAmount
      : messOverdue.fold(0.0, (sum, s) => sum + s.messBalanceDue);

  DashboardStats({
    required this.totalStudents,
    this.messPendingDuesCount = 0,
    required this.messExpiringSoonCount,
    required this.messOverdueCount,
    required this.rentExpiringSoonCount,
    required this.rentOverdueCount,
    required this.totalOverdueCount,
    this.totalPendingMessDuesAmount = 0.0,
    this.totalCurrentMessDuesAmount = 0.0,
    this.totalOverdueMessDuesAmount = 0.0,
    this.totalPendingMessDuesCount = 0,
    required this.totalRooms,
    required this.totalBeds,
    required this.occupiedBeds,
    required this.vacantBeds,
    required this.occupancyPercentage,
    required this.monthRentInflow,
    required this.monthMessInflow,
    required this.totalInflow,
    required this.totalMessExpense,
    required this.netProfitBalance,
    required this.isProfitable,
    required this.currentlyOutCount,
    this.messPendingDues = const [],
    required this.messExpiringSoon,
    required this.messOverdue,
    required this.rentExpiringSoon,
    required this.rentOverdue,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    final studentsMap = json['students'] as Map<String, dynamic>? ?? {};
    final roomsMap = json['rooms'] as Map<String, dynamic>? ?? {};
    final finMap = json['financials'] as Map<String, dynamic>? ?? {};
    final leavesMap = json['leaves'] as Map<String, dynamic>? ?? {};
    final alertsMap = json['alerts'] as Map<String, dynamic>? ?? {};

    final messPendingRaw = alertsMap['messPendingDues'] as List? ?? [];
    final messExpRaw = alertsMap['messExpiringSoon'] as List? ?? [];
    final messOverdueRaw = alertsMap['messOverdue'] as List? ?? [];
    final rentExpRaw = alertsMap['rentExpiringSoon'] as List? ?? [];
    final rentOverdueRaw = alertsMap['rentOverdue'] as List? ?? [];

    return DashboardStats(
      totalStudents: (studentsMap['total'] as num?)?.toInt() ?? 0,
      messPendingDuesCount: (studentsMap['messPendingDuesCount'] as num?)?.toInt() ?? 0,
      messExpiringSoonCount: (studentsMap['messExpiringSoonCount'] as num?)?.toInt() ?? 0,
      messOverdueCount: (studentsMap['messOverdueCount'] as num?)?.toInt() ?? 0,
      totalPendingMessDuesCount: (studentsMap['totalPendingMessDuesCount'] as num?)?.toInt() ?? 0,
      totalPendingMessDuesAmount: (finMap['totalPendingMessDuesAmount'] as num?)?.toDouble() ??
          (studentsMap['totalPendingMessDuesAmount'] as num?)?.toDouble() ?? 0.0,
      totalCurrentMessDuesAmount: (finMap['totalCurrentMessDuesAmount'] as num?)?.toDouble() ??
          (studentsMap['totalCurrentMessDuesAmount'] as num?)?.toDouble() ?? 0.0,
      totalOverdueMessDuesAmount: (finMap['totalOverdueMessDuesAmount'] as num?)?.toDouble() ??
          (studentsMap['totalOverdueMessDuesAmount'] as num?)?.toDouble() ?? 0.0,
      rentExpiringSoonCount: (studentsMap['rentExpiringSoonCount'] as num?)?.toInt() ?? 0,
      rentOverdueCount: (studentsMap['rentOverdueCount'] as num?)?.toInt() ?? 0,
      totalOverdueCount: (studentsMap['totalOverdueCount'] as num?)?.toInt() ?? 0,
      totalRooms: (roomsMap['totalRooms'] as num?)?.toInt() ?? 0,
      totalBeds: (roomsMap['totalBeds'] as num?)?.toInt() ?? 0,
      occupiedBeds: (roomsMap['occupiedBeds'] as num?)?.toInt() ?? 0,
      vacantBeds: (roomsMap['vacantBeds'] as num?)?.toInt() ?? 0,
      occupancyPercentage: (roomsMap['occupancyPercentage'] as num?)?.toInt() ?? 0,
      monthRentInflow: (finMap['monthRentInflow'] as num?)?.toDouble() ?? 0.0,
      monthMessInflow: (finMap['monthMessInflow'] as num?)?.toDouble() ?? 0.0,
      totalInflow: (finMap['totalInflow'] as num?)?.toDouble() ?? 0.0,
      totalMessExpense: (finMap['totalMessExpense'] as num?)?.toDouble() ?? 0.0,
      netProfitBalance: (finMap['netProfitBalance'] as num?)?.toDouble() ?? 0.0,
      isProfitable: finMap['isProfitable'] ?? true,
      currentlyOutCount: (leavesMap['currentlyOutCount'] as num?)?.toInt() ?? 0,
      messPendingDues: messPendingRaw.map((e) => Student.fromJson(e as Map<String, dynamic>)).toList(),
      messExpiringSoon: messExpRaw.map((e) => Student.fromJson(e as Map<String, dynamic>)).toList(),
      messOverdue: messOverdueRaw.map((e) => Student.fromJson(e as Map<String, dynamic>)).toList(),
      rentExpiringSoon: rentExpRaw.map((e) => Student.fromJson(e as Map<String, dynamic>)).toList(),
      rentOverdue: rentOverdueRaw.map((e) => Student.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}
