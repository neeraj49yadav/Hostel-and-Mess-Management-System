import '../../models/student.dart';

class ReminderHelper {
  /// Build customized WhatsApp reminder text:
  /// - In Mess section (feeType == 'MESS') -> Mess name
  /// - In Hostel section (feeType == 'RENT') -> Hostel name
  /// - In Common view (feeType == 'BOTH'):
  ///     - Mess only student -> Mess name
  ///     - Hostel only student -> Hostel name
  ///     - Both student (mess & hostel) -> Both names ("Hostel Name & Mess Name")
  static String buildReminderMessage({
    required Student student,
    String feeType = 'BOTH',
    required String hostelName,
    required String messName,
  }) {
    final isResident = student.isHostelResident;
    final isEnrolledMess = student.enrolledInMess && !student.memberType.contains('HOSTEL_ONLY');
    final isMessOnly = student.isMessOnly || (!isResident && isEnrolledMess);
    final isHostelOnly = isResident && !isEnrolledMess;

    String senderName;
    String notificationSubject;

    if (feeType == 'MESS') {
      senderName = messName;
      notificationSubject = 'Mess subscription';
    } else if (feeType == 'RENT') {
      senderName = hostelName;
      notificationSubject = 'Hostel Rent';
    } else {
      // feeType == 'BOTH'
      if (isMessOnly) {
        senderName = messName;
        notificationSubject = 'Mess subscription';
      } else if (isHostelOnly) {
        senderName = hostelName;
        notificationSubject = 'Hostel Rent';
      } else {
        senderName = hostelName.toLowerCase().trim() == messName.toLowerCase().trim()
            ? hostelName
            : '$hostelName & $messName';
        notificationSubject = 'Hostel & Mess';
      }
    }

    final greetingIdentifier = isResident && student.roomNumber.isNotEmpty
        ? 'Room No: ${student.roomNumber}'
        : 'Day Scholar';

    final buffer = StringBuffer();
    buffer.writeln('🔔 *Payment Reminder - $senderName*\n');
    buffer.writeln('Dear ${student.name} ($greetingIdentifier),');
    buffer.writeln('We are notifying you regarding your pending $notificationSubject dues.\n');
    buffer.writeln('📋 *Current Status:*');

    if (feeType == 'MESS') {
      final messDueText = student.messBalanceDue > 0
          ? '• *Pending Mess Due: ₹${student.messBalanceDue.toStringAsFixed(0)}*'
          : '• *Mess Status: Fully Paid*';
      final expDate = student.messExpiryDate.isNotEmpty
          ? student.messExpiryDate
          : 'Due';
      final statusLabel = student.messStatusLabel.isNotEmpty ? student.messStatusLabel : 'Active';
      buffer.writeln('• *Mess Plan (Monthly)*: ₹${student.monthlyMessFee.toStringAsFixed(0)}/mo (Valid till: $expDate • $statusLabel)');
      buffer.writeln('$messDueText\n');

      if (student.messBalanceDue > 0) {
        buffer.writeln('👉 *Pending Monthly Mess Fee*: ₹${student.messBalanceDue.toStringAsFixed(0)}');
      } else if (student.messDynamicStatus != 'ACTIVE') {
        buffer.writeln('👉 *Pending Monthly Mess Renewal*: ₹${student.monthlyMessFee.toStringAsFixed(0)}');
      }
    } else if (feeType == 'RENT') {
      buffer.writeln('• *Hostel Rent*: Total: ₹${student.totalRentAgreed.toStringAsFixed(0)} | Paid: ₹${student.totalRentPaid.toStringAsFixed(0)} | *Remaining Due: ₹${student.rentBalanceDue.toStringAsFixed(0)}*\n');
      if (student.rentBalanceDue > 0) {
        buffer.writeln('👉 *Pending Rent Balance*: ₹${student.rentBalanceDue.toStringAsFixed(0)}');
      }
    } else {
      if (isResident) {
        buffer.writeln('• *Hostel Rent*: Total: ₹${student.totalRentAgreed.toStringAsFixed(0)} | Paid: ₹${student.totalRentPaid.toStringAsFixed(0)} | *Remaining Due: ₹${student.rentBalanceDue.toStringAsFixed(0)}*');
      }
      if (isEnrolledMess) {
        final messDueText = student.messBalanceDue > 0
            ? '• *Pending Mess Due: ₹${student.messBalanceDue.toStringAsFixed(0)}*'
            : '• *Mess Status: Fully Paid*';
        final expDate = student.messExpiryDate.isNotEmpty
            ? student.messExpiryDate
            : 'Due';
        final statusLabel = student.messStatusLabel.isNotEmpty ? student.messStatusLabel : 'Active';
        buffer.writeln('• *Mess Plan (Monthly)*: ₹${student.monthlyMessFee.toStringAsFixed(0)}/mo (Valid till: $expDate • $statusLabel)');
        buffer.writeln(messDueText);
      }
      buffer.writeln('');

      if (isResident && student.rentBalanceDue > 0) {
        buffer.writeln('👉 *Pending Rent Balance*: ₹${student.rentBalanceDue.toStringAsFixed(0)}');
      }
      if (isEnrolledMess && student.messBalanceDue > 0) {
        buffer.writeln('👉 *Pending Monthly Mess Fee*: ₹${student.messBalanceDue.toStringAsFixed(0)}');
      } else if (isEnrolledMess && student.messDynamicStatus != 'ACTIVE') {
        buffer.writeln('👉 *Pending Monthly Mess Renewal*: ₹${student.monthlyMessFee.toStringAsFixed(0)}');
      }
    }

    buffer.writeln('\nKindly pay at the admin office or via UPI to keep your records clear.\n');
    buffer.write('Thank you,\n*$senderName*');

    return buffer.toString();
  }
}
