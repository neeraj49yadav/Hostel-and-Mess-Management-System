import '../../models/student.dart';

/// 🔍 Unified high-performance student search matcher.
/// Handles multi-token queries (e.g. "Rahul 102"), phone digits normalization (+91 vs raw),
/// room & bed prefixes ("Room 101", "B2"), parent contacts, notes, and plan types.
class StudentSearchHelper {
  static bool matchesStudent(dynamic student, String query) {
    if (query.trim().isEmpty) return true;
    final cleanQuery = query.trim().toLowerCase();
    final tokens = cleanQuery.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (tokens.isEmpty) return true;

    final String name;
    final String phone;
    final String parentPhone;
    final String parentName;
    final String room;
    final String bed;
    final String mealPlan;
    final String notes;

    if (student is Student) {
      name = student.name.toLowerCase();
      phone = student.phone.toLowerCase();
      parentPhone = student.parentPhone.toLowerCase();
      parentName = student.parentName.toLowerCase();
      room = student.roomNumber.toLowerCase();
      bed = student.bedNo.toLowerCase();
      mealPlan = student.mealPlanType.toLowerCase();
      notes = student.notes.toLowerCase();
    } else if (student is Map<String, dynamic> || student is Map) {
      name = (student['name'] ?? '').toString().toLowerCase();
      phone = (student['phone'] ?? '').toString().toLowerCase();
      parentPhone = (student['parentPhone'] ?? '').toString().toLowerCase();
      parentName = (student['parentName'] ?? '').toString().toLowerCase();
      room = (student['roomNumber'] ?? '').toString().toLowerCase();
      bed = (student['bedNo'] ?? '').toString().toLowerCase();
      mealPlan = (student['mealPlanType'] ?? '').toString().toLowerCase();
      notes = '${student['notes'] ?? ''} ${student['exitReason'] ?? ''}'.toLowerCase();
    } else {
      return false;
    }

    final phoneDigits = phone.replaceAll(RegExp(r'\D'), '');
    final parentPhoneDigits = parentPhone.replaceAll(RegExp(r'\D'), '');
    final roomBed = 'room $room bed $bed $room $bed';
    final combined = '$name $phone $parentName $parentPhone $roomBed $mealPlan $notes';

    return tokens.every((token) {
      final tokenDigits = token.replaceAll(RegExp(r'\D'), '');
      if (tokenDigits.length >= 3 &&
          (phoneDigits.contains(tokenDigits) || parentPhoneDigits.contains(tokenDigits))) {
        return true;
      }
      return combined.contains(token);
    });
  }

  /// Filters a list of Students instantly in-memory.
  static List<Student> filterStudents(List<Student> students, String query) {
    if (query.trim().isEmpty) return students;
    return students.where((s) => matchesStudent(s, query)).toList();
  }

  /// Filters a list of Master Register map records instantly in-memory.
  static List<dynamic> filterRecords(List<dynamic> records, String query) {
    if (query.trim().isEmpty) return records;
    return records.where((r) => matchesStudent(r, query)).toList();
  }
}
