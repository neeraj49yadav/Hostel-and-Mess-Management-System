class Organization {
  final String id;
  final String name;
  final String code;
  final String city;
  final String contactPhone;
  final String? logo;
  final String? createdAt;

  Organization({
    required this.id,
    required this.name,
    required this.code,
    required this.city,
    required this.contactPhone,
    this.logo,
    this.createdAt,
  });

  factory Organization.fromJson(Map<String, dynamic> json) {
    return Organization(
      id: json['id'] ?? 'org-default',
      name: json['name'] ?? 'My Hostel & Mess',
      code: (json['code'] ?? 'HOSTEL').toString().toUpperCase(),
      city: json['city'] ?? 'Main Campus',
      contactPhone: json['contactPhone'] ?? '',
      logo: json['logo'],
      createdAt: json['createdAt'],
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
  };

  Organization copyWith({
    String? id,
    String? name,
    String? code,
    String? city,
    String? contactPhone,
    String? logo,
    String? createdAt,
  }) {
    return Organization(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      city: city ?? this.city,
      contactPhone: contactPhone ?? this.contactPhone,
      logo: logo ?? this.logo,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() => '$name ($code)';
}
