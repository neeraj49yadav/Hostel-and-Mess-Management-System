class MessExpense {
  final String id;
  final String title;
  final String category; // MILK, VEGETABLES, RATION, GAS, SPICES, OTHER
  final double amount;
  final String date;
  final String vendorName;
  final String vendorPhone;
  final String paymentMode;
  final String billImageUrl;
  final String recordedByAdminName;
  final String notes;

  MessExpense({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.date,
    required this.vendorName,
    required this.vendorPhone,
    required this.paymentMode,
    required this.billImageUrl,
    required this.recordedByAdminName,
    required this.notes,
  });

  factory MessExpense.fromJson(Map<String, dynamic> json) {
    return MessExpense(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      category: json['category'] ?? 'OTHER',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      date: json['date'] ?? '',
      vendorName: json['vendorName'] ?? '',
      vendorPhone: json['vendorPhone'] ?? '',
      paymentMode: json['paymentMode'] ?? 'CASH',
      billImageUrl: json['billImageUrl'] ?? '',
      recordedByAdminName: json['recordedByAdminName'] ?? 'Mess In-charge',
      notes: json['notes'] ?? '',
    );
  }
}
