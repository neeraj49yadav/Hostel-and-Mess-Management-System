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

  /// Calculates a relevance score for ordering search results.
  /// Lower score = higher priority / better match:
  /// - 0: Name exact match
  /// - 1: Full name starts with query
  /// - 2: A word in the name starts with query (e.g. "Kumar" in "Aman Kumar" when searching "Ku")
  /// - 3: Room starts with or exact matches query
  /// - 4: Phone starts with query
  /// - 5: Name contains query as a substring
  /// - 6: Other fields match (room, bed, notes, parent, etc.)
  static int _computeScore(dynamic student, String rawQuery) {
    final query = rawQuery.trim().toLowerCase();
    if (query.isEmpty) return 100;

    final String name;
    final String phone;
    final String room;

    if (student is Student) {
      name = student.name.trim().toLowerCase();
      phone = student.phone.trim().toLowerCase();
      room = student.roomNumber.trim().toLowerCase();
    } else if (student is Map<String, dynamic> || student is Map) {
      name = (student['name'] ?? '').toString().trim().toLowerCase();
      phone = (student['phone'] ?? '').toString().trim().toLowerCase();
      room = (student['roomNumber'] ?? '').toString().trim().toLowerCase();
    } else {
      return 100;
    }

    if (name == query) return 0;
    if (name.startsWith(query)) return 1;

    final nameWords = name.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    if (nameWords.any((w) => w.startsWith(query))) return 2;

    if (room == query || room.startsWith(query)) return 3;

    final phoneDigits = phone.replaceAll(RegExp(r'\D'), '');
    final queryDigits = query.replaceAll(RegExp(r'\D'), '');
    if (queryDigits.isNotEmpty && phoneDigits.startsWith(queryDigits)) return 4;

    if (name.contains(query)) return 5;

    return 6;
  }

  /// Filters a list of Students instantly in-memory, prioritizing prefix/starting alphabet matches.
  static List<Student> filterStudents(List<Student> students, String query) {
    if (query.trim().isEmpty) return students;
    final matched = students.where((s) => matchesStudent(s, query)).toList();
    matched.sort((a, b) {
      final scoreA = _computeScore(a, query);
      final scoreB = _computeScore(b, query);
      if (scoreA != scoreB) return scoreA.compareTo(scoreB);
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return matched;
  }

  /// Filters a list of Master Register map records instantly in-memory, prioritizing prefix/starting alphabet matches.
  static List<dynamic> filterRecords(List<dynamic> records, String query) {
    if (query.trim().isEmpty) return records;
    final matched = records.where((r) => matchesStudent(r, query)).toList();
    matched.sort((a, b) {
      final scoreA = _computeScore(a, query);
      final scoreB = _computeScore(b, query);
      if (scoreA != scoreB) return scoreA.compareTo(scoreB);
      final nameA = (a['name'] ?? '').toString().toLowerCase();
      final nameB = (b['name'] ?? '').toString().toLowerCase();
      return nameA.compareTo(nameB);
    });
    return matched;
  }
}
