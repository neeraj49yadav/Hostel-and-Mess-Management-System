class Organization {
  final String id;
  final String name;
  final String code;
  final String city;
  final String contactPhone;
  final String? logo;
  final String? createdAt;
  final String? hostelName;
  final String? messName;

  Organization({
    required this.id,
    required this.name,
    required this.code,
    required this.city,
    required this.contactPhone,
    this.logo,
    this.createdAt,
    this.hostelName,
    this.messName,
  });

  String get displayHostelName =>
      (hostelName != null && hostelName!.trim().isNotEmpty) ? hostelName!.trim() : name;

  String get displayMessName {
    if (messName != null && messName!.trim().isNotEmpty) {
      return messName!.trim();
    }
    if (name.toLowerCase().contains('mess')) {
      return name;
    }
    final cleaned = name.replaceAll(RegExp(r'Hostel|PG|Residency', caseSensitive: false), '').trim();
    return cleaned.isNotEmpty ? '$cleaned Mess' : '$name Mess';
  }

  factory Organization.fromJson(Map<String, dynamic> json) {
    return Organization(
      id: json['id'] ?? 'org-default',
      name: json['name'] ?? 'My Hostel & Mess',
      code: (json['code'] ?? 'HOSTEL').toString().toUpperCase(),
      city: json['city'] ?? 'Main Campus',
      contactPhone: json['contactPhone'] ?? '',
      logo: json['logo'],
      createdAt: json['createdAt'],
      hostelName: json['hostelName'],
      messName: json['messName'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'code': code,
    'city': city,
    'contactPhone': contactPhone,
    'logo': logo,
    'createdAt': createdAt,
    'hostelName': hostelName,
    'messName': messName,
  };

  Organization copyWith({
    String? id,
    String? name,
    String? code,
    String? city,
    String? contactPhone,
    String? logo,
    String? createdAt,
    String? hostelName,
    String? messName,
  }) {
    return Organization(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      city: city ?? this.city,
      contactPhone: contactPhone ?? this.contactPhone,
      logo: logo ?? this.logo,
      createdAt: createdAt ?? this.createdAt,
      hostelName: hostelName ?? this.hostelName,
      messName: messName ?? this.messName,
    );
  }

  @override
  String toString() => '$name ($code)';
}
