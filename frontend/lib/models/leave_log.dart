class LeaveLog {
  final String id;
  final String studentId;
  final String studentName;
  final String roomNumber;
  final String leaveType; // HOME_VISIT, NIGHT_OUT, EMERGENCY, MARKET
  final String departureDate;
  final String expectedReturnDate;
  final String? actualReturnDate;
  final String status; // OUT, RETURNED
  final String reason;
  final bool parentApproved;
  final String loggedByAdminName;

  LeaveLog({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.roomNumber,
    required this.leaveType,
    required this.departureDate,
    required this.expectedReturnDate,
    this.actualReturnDate,
    required this.status,
    required this.reason,
    required this.parentApproved,
    required this.loggedByAdminName,
  });

  factory LeaveLog.fromJson(Map<String, dynamic> json) {
    return LeaveLog(
      id: json['id'] ?? '',
      studentId: json['studentId'] ?? '',
      studentName: json['studentName'] ?? '',
      roomNumber: json['roomNumber'] ?? '',
      leaveType: json['leaveType'] ?? 'HOME_VISIT',
      departureDate: json['departureDate'] ?? '',
      expectedReturnDate: json['expectedReturnDate'] ?? '',
      actualReturnDate: json['actualReturnDate'],
      status: json['status'] ?? 'OUT',
      reason: json['reason'] ?? '',
      parentApproved: json['parentApproved'] ?? true,
      loggedByAdminName: json['loggedByAdminName'] ?? 'Admin',
    );
  }
}
