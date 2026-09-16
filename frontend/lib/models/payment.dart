class Payment {
  final String id;
  final String receiptNo;
  final String studentId;
  final String studentName;
  final String roomNumber;
  final double amount;
  final String feeType; // RENT, MESS, BOTH
  final double rentAmount;
  final double messAmount;
  final String paymentMode; // CASH, UPI, BANK_TRANSFER
  final String transactionRef;
  final String paymentDate;
  final String cycleStartDate;
  final String cycleEndDate;
  final String collectedByAdminName;
  final String notes;
  final String targetMonth;
  final int messMonthsToAdd;

  Payment({
    required this.id,
    required this.receiptNo,
    required this.studentId,
    required this.studentName,
    required this.roomNumber,
    required this.amount,
    required this.feeType,
    required this.rentAmount,
    required this.messAmount,
    required this.paymentMode,
    required this.transactionRef,
    required this.paymentDate,
    required this.cycleStartDate,
    required this.cycleEndDate,
    required this.collectedByAdminName,
    required this.notes,
    this.targetMonth = '',
    this.messMonthsToAdd = 1,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'] ?? '',
      receiptNo: json['receiptNo'] ?? '',
      studentId: json['studentId'] ?? '',
      studentName: json['studentName'] ?? '',
      roomNumber: json['roomNumber'] ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      feeType: json['feeType'] ?? 'BOTH',
      rentAmount: (json['rentAmount'] as num?)?.toDouble() ?? 0.0,
      messAmount: (json['messAmount'] as num?)?.toDouble() ?? 0.0,
      paymentMode: json['paymentMode'] ?? 'CASH',
      transactionRef: json['transactionRef'] ?? '',
      paymentDate: json['paymentDate'] ?? '',
      cycleStartDate: json['cycleStartDate'] ?? '',
      cycleEndDate: json['cycleEndDate'] ?? '',
      collectedByAdminName: json['collectedByAdminName'] ?? 'Admin',
      notes: json['notes'] ?? '',
      targetMonth: json['targetMonth'] ?? '',
      messMonthsToAdd: (json['messMonthsToAdd'] as num?)?.toInt() ?? 1,
    );
  }
}
