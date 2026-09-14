class Room {
  final String id;
  final String roomNumber;
  final int floor;
  final int totalBeds;
  final int occupiedBeds;
  final int vacantBeds;
  final String status;
  final List<RoomOccupant> occupants;

  Room({
    required this.id,
    required this.roomNumber,
    required this.floor,
    required this.totalBeds,
    required this.occupiedBeds,
    required this.vacantBeds,
    required this.status,
    required this.occupants,
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    var rawOccupants = json['occupants'] as List? ?? [];
    List<RoomOccupant> occList = rawOccupants
        .map((o) => RoomOccupant.fromJson(o as Map<String, dynamic>))
        .toList();

    return Room(
      id: json['id'] ?? '',
      roomNumber: json['roomNumber'] ?? '',
      floor: (json['floor'] as num?)?.toInt() ?? 1,
      totalBeds: (json['totalBeds'] as num?)?.toInt() ?? 1,
      occupiedBeds: (json['occupiedBeds'] as num?)?.toInt() ?? 0,
      vacantBeds: (json['vacantBeds'] as num?)?.toInt() ?? 0,
      status: json['status'] ?? 'AVAILABLE',
      occupants: occList,
    );
  }
}

class RoomOccupant {
  final String id;
  final String name;
  final String phone;
  final String bedNo;
  final String planExpiryDate;
  final String status;

  RoomOccupant({
    required this.id,
    required this.name,
    required this.phone,
    required this.bedNo,
    required this.planExpiryDate,
    required this.status,
  });

  factory RoomOccupant.fromJson(Map<String, dynamic> json) {
    return RoomOccupant(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      bedNo: json['bedNo'] ?? '',
      planExpiryDate: json['planExpiryDate'] ?? '',
      status: json['status'] ?? 'ACTIVE',
    );
  }
}
