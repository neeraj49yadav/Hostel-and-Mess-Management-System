class Student {
  final String id;
  final String memberType; // 'HOSTEL_RESIDENT' or 'MESS_ONLY'
  final String name;
  final String phone;
  final String parentPhone;
  final String parentName;
  final String? photoUrl;
  final String? roomId;
  final String roomNumber;
  final String bedNo;
  final String admissionDate;
  final String? messStartDate;
  final int cycleDay;
  final bool enrolledInMess;
  final double monthlyMessFee;
  final String messExpiryDate;
  final int mealsPerDay; // 1, 2, or 3
  final String mealPlanType; // e.g. '1 Meal / Day', '2 Meals / Day', '3 Meals / Day (Full)'
  final List<String> mealSlots; // e.g. ['Morning', 'Noon', 'Evening']
  final String planValidityType; // 'MONTHLY' or 'CUSTOM_DAYS'
  final int? planValidityDays;
  final bool isAutoRemoved;
  final String? autoRemovedAt;
  final String? autoRemoveReason;
  final bool isOverdueMess;
  final bool isUpcomingMess;
  final double totalRentAgreed;
  final double totalRentPaid;
  final double rentBalanceDue;
  final double totalMessPaid;
  final double messBalanceDue;
  final double totalPaidAll;
  final int rentTermMonths;
  final double rentAmountPerTerm;
  final String? rentExpiryDate;
  final String status;
  final String messDynamicStatus;
  final String messStatusLabel;
  final int messDaysRemaining;
  final String rentDynamicStatus;
  final String rentStatusLabel;
  final int rentDaysRemaining;
  final String dynamicStatus;
  final String statusLabel;
  final String notes;
  final Map<String, dynamic>? whatsappReminder;

  bool get isHostelResident => memberType == 'HOSTEL_RESIDENT';
  bool get isMessOnly => memberType == 'MESS_ONLY';
  bool get hasPhoto => photoUrl != null && photoUrl!.trim().isNotEmpty;

  bool get isRentFullyPaid => isHostelResident && totalRentAgreed > 0 && rentBalanceDue <= 0;
  bool get hasRentDues => isHostelResident && rentBalanceDue > 0;
  bool get hasMessDues => enrolledInMess && messBalanceDue > 0;

  double get totalMonthlyFee =>
      (enrolledInMess ? monthlyMessFee : 0.0) +
      (isHostelResident ? (totalRentAgreed > 0 ? (totalRentAgreed / (rentTermMonths > 0 ? rentTermMonths : 6)) : (rentAmountPerTerm / (rentTermMonths > 0 ? rentTermMonths : 6))) : 0.0);

  Student({
    required this.id,
    required this.memberType,
    required this.name,
    required this.phone,
    required this.parentPhone,
    required this.parentName,
    this.photoUrl,
    this.roomId,
    required this.roomNumber,
    required this.bedNo,
    required this.admissionDate,
    this.messStartDate,
    required this.cycleDay,
    required this.enrolledInMess,
    required this.monthlyMessFee,
    required this.messExpiryDate,
    this.mealsPerDay = 3,
    this.mealPlanType = '3 Meals / Day (Full)',
    this.mealSlots = const ['Morning', 'Noon', 'Evening'],
    this.planValidityType = 'MONTHLY',
    this.planValidityDays,
    this.isAutoRemoved = false,
    this.autoRemovedAt,
    this.autoRemoveReason,
    this.isOverdueMess = false,
    this.isUpcomingMess = false,
    required this.totalRentAgreed,
    required this.totalRentPaid,
    required this.rentBalanceDue,
    required this.totalMessPaid,
    this.messBalanceDue = 0.0,
    required this.totalPaidAll,
    required this.rentTermMonths,
    required this.rentAmountPerTerm,
    this.rentExpiryDate,
    required this.status,
    required this.messDynamicStatus,
    required this.messStatusLabel,
    required this.messDaysRemaining,
    required this.rentDynamicStatus,
    required this.rentStatusLabel,
    required this.rentDaysRemaining,
    required this.dynamicStatus,
    required this.statusLabel,
    required this.notes,
    this.whatsappReminder,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    final mType = json['memberType'] ?? (json['roomId'] != null ? 'HOSTEL_RESIDENT' : 'MESS_ONLY');
    final fee = (json['monthlyMessFee'] as num?)?.toDouble() ?? 3500.0;
    final isMess = json['enrolledInMess'] is bool
        ? json['enrolledInMess'] as bool
        : (mType == 'MESS_ONLY' || fee > 0);

    final rentAgreed = (json['totalRentAgreed'] as num?)?.toDouble() ??
        (json['rentAmountPerTerm'] as num?)?.toDouble() ??
        (json['monthlyRent'] != null ? (json['monthlyRent'] as num).toDouble() * 6 : 27000.0);

    final rentPaid = (json['totalRentPaid'] as num?)?.toDouble() ?? 0.0;
    final rentDue = (json['rentBalanceDue'] as num?)?.toDouble() ??
        (rentAgreed > rentPaid ? rentAgreed - rentPaid : 0.0);

    final messPaid = (json['totalMessPaid'] as num?)?.toDouble() ?? 0.0;
    final messDue = (json['messBalanceDue'] as num?)?.toDouble() ?? 0.0;
    final totalAll = (json['totalPaidAll'] as num?)?.toDouble() ?? (rentPaid + messPaid);

    final mPerDay = (json['mealsPerDay'] as num?)?.toInt() ?? 3;
    final mSlots = json['mealSlots'] is List
        ? (json['mealSlots'] as List).map((e) => e.toString()).toList()
        : <String>['Morning', 'Noon', 'Evening'];

    final statusStr = json['status']?.toString() ?? 'ACTIVE';
    final autoRem = statusStr == 'MESS_AUTO_REMOVED' || statusStr == 'REMOVED_AUTO' || json['isAutoRemoved'] == true || json['autoRemovedAt'] != null;

    return Student(
      id: json['id'] ?? '',
      memberType: mType,
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      parentPhone: json['parentPhone'] ?? '',
      parentName: json['parentName'] ?? '',
      photoUrl: json['photoUrl'] ?? json['photo'],
      roomId: json['roomId'],
      roomNumber: json['roomNumber'] ?? (mType == 'MESS_ONLY' ? 'External / Day Scholar' : 'N/A'),
      bedNo: json['bedNo'] ?? '-',
      admissionDate: json['admissionDate'] ?? '',
      messStartDate: json['messStartDate'] ?? (isMess ? json['admissionDate'] : null),
      cycleDay: json['cycleDay'] is int ? json['cycleDay'] : int.tryParse('${json['cycleDay']}') ?? 1,
      enrolledInMess: isMess,
      monthlyMessFee: fee,
      messExpiryDate: json['messExpiryDate'] ?? json['planExpiryDate'] ?? '',
      mealsPerDay: mPerDay,
      mealPlanType: json['mealPlanType'] ?? (mPerDay == 1 ? '1 Meal / Day' : (mPerDay == 2 ? '2 Meals / Day' : '3 Meals / Day (Full)')),
      mealSlots: mSlots,
      planValidityType: json['planValidityType'] ?? 'MONTHLY',
      planValidityDays: (json['planValidityDays'] as num?)?.toInt(),
      isAutoRemoved: autoRem,
      autoRemovedAt: json['autoRemovedAt']?.toString(),
      autoRemoveReason: json['autoRemoveReason']?.toString(),
      isOverdueMess: json['isOverdueMess'] == true,
      isUpcomingMess: json['isUpcomingMess'] == true,
      totalRentAgreed: rentAgreed,
      totalRentPaid: rentPaid,
      rentBalanceDue: rentDue,
      totalMessPaid: messPaid,
      messBalanceDue: messDue,
      totalPaidAll: totalAll,
      rentTermMonths: (json['rentTermMonths'] as num?)?.toInt() ?? 6,
      rentAmountPerTerm: rentAgreed,
      rentExpiryDate: json['rentExpiryDate'],
      status: statusStr,
      messDynamicStatus: json['messDynamicStatus'] ?? json['dynamicStatus'] ?? 'ACTIVE',
      messStatusLabel: json['messStatusLabel'] ?? '',
      messDaysRemaining: (json['messDaysRemaining'] as num?)?.toInt() ?? 0,
      rentDynamicStatus: json['rentDynamicStatus'] ?? json['dynamicStatus'] ?? 'ACTIVE',
      rentStatusLabel: json['rentStatusLabel'] ?? '',
      rentDaysRemaining: (json['rentDaysRemaining'] as num?)?.toInt() ?? 0,
      dynamicStatus: json['dynamicStatus'] ?? json['status'] ?? 'ACTIVE',
      statusLabel: json['statusLabel'] ?? '',
      notes: json['notes'] ?? '',
      whatsappReminder: json['whatsappReminder'] is Map<String, dynamic>
          ? json['whatsappReminder']
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'memberType': memberType,
    'name': name,
    'phone': phone,
    'parentPhone': parentPhone,
    'parentName': parentName,
    'photoUrl': photoUrl,
    'roomId': roomId,
    'roomNumber': roomNumber,
    'bedNo': bedNo,
    'admissionDate': admissionDate,
    'messStartDate': messStartDate,
    'cycleDay': cycleDay,
    'enrolledInMess': enrolledInMess,
    'monthlyMessFee': monthlyMessFee,
    'messExpiryDate': messExpiryDate,
    'mealsPerDay': mealsPerDay,
    'mealPlanType': mealPlanType,
    'mealSlots': mealSlots,
    'planValidityType': planValidityType,
    'planValidityDays': planValidityDays,
    'isAutoRemoved': isAutoRemoved,
    'autoRemovedAt': autoRemovedAt,
    'autoRemoveReason': autoRemoveReason,
    'totalRentAgreed': totalRentAgreed,
    'totalRentPaid': totalRentPaid,
    'rentBalanceDue': rentBalanceDue,
    'totalMessPaid': totalMessPaid,
    'messBalanceDue': messBalanceDue,
    'rentTermMonths': rentTermMonths,
    'rentAmountPerTerm': rentAmountPerTerm,
    'rentExpiryDate': rentExpiryDate,
    'status': status,
    'notes': notes,
  };
}
