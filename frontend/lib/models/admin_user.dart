class AdminUser {
  final String id;
  final String orgId;
  final String orgCode;
  final String orgName;
  final String name;
  final String role;
  final String phone;
  final String? pin;
  final String? profilePhoto;

  AdminUser({
    required this.id,
    this.orgId = 'org-default',
    this.orgCode = 'HOSTEL',
    this.orgName = 'My Hostel & Mess',
    required this.name,
    required this.role,
    required this.phone,
    this.pin,
    this.profilePhoto,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: json['id'] ?? '',
      orgId: json['orgId'] ?? 'org-default',
      orgCode: json['orgCode'] ?? 'HOSTEL',
      orgName: json['orgName'] ?? 'My Hostel & Mess',
      name: json['name'] ?? '',
      role: json['role'] ?? 'Admin',
      phone: json['phone'] ?? '',
      pin: json['pin']?.toString(),
      profilePhoto: json['profilePhoto']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'orgId': orgId,
    'orgCode': orgCode,
    'orgName': orgName,
    'name': name,
    'role': role,
    'phone': phone,
    if (pin != null) 'pin': pin,
    if (profilePhoto != null) 'profilePhoto': profilePhoto,
  };

  AdminUser copyWith({
    String? id,
    String? orgId,
    String? orgCode,
    String? orgName,
    String? name,
    String? role,
    String? phone,
    String? pin,
    String? profilePhoto,
  }) {
    return AdminUser(
      id: id ?? this.id,
      orgId: orgId ?? this.orgId,
      orgCode: orgCode ?? this.orgCode,
      orgName: orgName ?? this.orgName,
      name: name ?? this.name,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      pin: pin ?? this.pin,
      profilePhoto: profilePhoto ?? this.profilePhoto,
    );
  }
}

