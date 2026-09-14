class Vendor {
  final String id;
  final String name;
  final String category;
  final String phone;
  final String address;
  final double pendingBalance;

  Vendor({
    required this.id,
    required this.name,
    required this.category,
    required this.phone,
    required this.address,
    required this.pendingBalance,
  });

  factory Vendor.fromJson(Map<String, dynamic> json) {
    return Vendor(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      category: json['category'] ?? 'OTHER',
      phone: json['phone'] ?? '',
      address: json['address'] ?? '',
      pendingBalance: (json['pendingBalance'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
