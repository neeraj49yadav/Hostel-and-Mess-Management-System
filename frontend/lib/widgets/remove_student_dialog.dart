import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../models/student.dart';
import '../providers/auth_provider.dart';
import '../providers/hostel_provider.dart';
import '../providers/mess_provider.dart';
import '../providers/dashboard_provider.dart';
import 'student_avatar.dart';

enum RemovalActionType {
  bothHostelAndMess,
  hostelOnly,
  messOnly,
  deletePermanently,
}

Future<void> showRemoveStudentDialog(
  BuildContext context, {
  required Student student,
  VoidCallback? onRemoved,
  bool defaultToMessOnly = false,
}) async {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  // Determine initial mode
  RemovalActionType selectedAction;
  if (student.isMessOnly) {
    selectedAction = RemovalActionType.messOnly;
  } else if (defaultToMessOnly && student.enrolledInMess) {
    selectedAction = RemovalActionType.messOnly;
  } else if (student.enrolledInMess) {
    selectedAction = RemovalActionType.bothHostelAndMess;
  } else {
    selectedAction = RemovalActionType.hostelOnly;
  }

  final reasonController = TextEditingController();
  bool isSubmitting = false;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          final auth = context.read<AuthProvider>();
          final hostel = context.read<HostelProvider>();
          final mess = context.read<MessProvider>();
          final dash = context.read<DashboardProvider>();

          Future<void> handleConfirm() async {
            setModalState(() => isSubmitting = true);
            final adminName = auth.currentAdmin?.name ?? 'Admin';
            final reason = reasonController.text.trim();
            bool success = false;
            String message = '';

            try {
              switch (selectedAction) {
                case RemovalActionType.bothHostelAndMess:
                  success = await hostel.checkoutStudent(
                    student.id,
                    adminName,
                    reason.isNotEmpty ? reason : 'Left Hostel & Mess',
                    removeFromMess: true,
                  );
                  message = 'Checked out from Hostel and removed from Mess!';
                  break;

                case RemovalActionType.hostelOnly:
                  success = await hostel.checkoutStudent(
                    student.id,
                    adminName,
                    reason.isNotEmpty ? reason : 'Left Hostel',
                    removeFromMess: false,
                  );
                  message = 'Resident checked out from Hostel. Bed is now vacant!';
                  break;

                case RemovalActionType.messOnly:
                  success = await mess.unenrollMessMember(
                    student.id,
                    adminName,
                    removeFromHostel: false,
                    reason: reason.isNotEmpty ? reason : 'Unenrolled from Mess',
                  );
                  message = student.isMessOnly
                      ? 'Outside mess member removed successfully!'
                      : 'Unenrolled from Mess! Student remains in hostel room.';
                  break;

                case RemovalActionType.deletePermanently:
                  success = await hostel.deleteStudent(student.id, adminName);
                  message = 'Student record permanently deleted!';
                  break;
              }

              if (success) {
                await hostel.fetchStudents();
                await mess.fetchMessMembers();
                dash.fetchDashboardStats();
                dash.fetchDuesAndExpiries();

                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(message), backgroundColor: AppColors.success),
                  );
                  if (onRemoved != null) onRemoved();
                }
              } else {
                setModalState(() => isSubmitting = false);
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(hostel.error ?? mess.error ?? 'Failed to complete removal'),
                      backgroundColor: AppColors.danger,
                    ),
                  );
                }
              }
            } catch (e) {
              setModalState(() => isSubmitting = false);
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger),
                );
              }
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              top: 20,
              left: 20,
              right: 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row
                  Row(
                    children: [
                      StudentAvatar(
                        student: student,
                        radius: 24,
                        enablePreview: false,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              student.name,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                              ),
                            ),
                            Text(
                              student.isMessOnly
                                  ? 'Outside Day Scholar (Mess Only)'
                                  : 'Room ${student.roomNumber} (Bed ${student.bedNo})${student.enrolledInMess ? ' • Mess Enrolled' : ''}',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? AppColors.textMutedDark : AppColors.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),

                  // Removal Options
                  if (student.isMessOnly) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.person_remove_rounded, color: AppColors.danger, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Remove from Mess Subscriptions',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.danger),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'This will delete ${student.name}\'s outside mess membership and active subscription.',
                                  style: TextStyle(fontSize: 12, color: isDark ? AppColors.textMutedDark : AppColors.textSecondaryLight),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    const Text(
                      'Select Removal Option',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 10),

                    // Option 1: Remove from Both Hostel & Mess (if enrolled in both)
                    if (student.enrolledInMess)
                      _buildOptionTile(
                        isDark: isDark,
                        isSelected: selectedAction == RemovalActionType.bothHostelAndMess,
                        icon: Icons.exit_to_app_rounded,
                        iconColor: AppColors.danger,
                        title: 'Remove from BOTH Hostel & Mess',
                        subtitle: 'Frees Bed ${student.bedNo} in Room ${student.roomNumber} and terminates monthly Mess subscription.',
                        onTap: () => setModalState(() => selectedAction = RemovalActionType.bothHostelAndMess),
                      ),

                    // Option 2: Checkout from Hostel Only
                    _buildOptionTile(
                      isDark: isDark,
                      isSelected: selectedAction == RemovalActionType.hostelOnly,
                      icon: Icons.hotel_rounded,
                      iconColor: AppColors.primary,
                      title: 'Checkout from Hostel Only',
                      subtitle: student.enrolledInMess
                          ? 'Frees Bed ${student.bedNo} in Room ${student.roomNumber}. Student continues mess subscription as day scholar.'
                          : 'Frees Bed ${student.bedNo} in Room ${student.roomNumber} and archives hostel stay.',
                      onTap: () => setModalState(() => selectedAction = RemovalActionType.hostelOnly),
                    ),

                    // Option 3: Unenroll from Mess Only (if enrolled)
                    if (student.enrolledInMess)
                      _buildOptionTile(
                        isDark: isDark,
                        isSelected: selectedAction == RemovalActionType.messOnly,
                        icon: Icons.restaurant_rounded,
                        iconColor: AppColors.secondary,
                        title: 'Unenroll from Mess Only',
                        subtitle: 'Student stays in Room ${student.roomNumber}, but monthly mess subscription is stopped.',
                        onTap: () => setModalState(() => selectedAction = RemovalActionType.messOnly),
                      ),

                    // Option 4: Permanently Delete
                    _buildOptionTile(
                      isDark: isDark,
                      isSelected: selectedAction == RemovalActionType.deletePermanently,
                      icon: Icons.delete_forever_rounded,
                      iconColor: AppColors.danger,
                      title: 'Permanently Delete Student Record',
                      subtitle: 'Completely deletes all records for ${student.name} from the database.',
                      onTap: () => setModalState(() => selectedAction = RemovalActionType.deletePermanently),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Reason text field
                  TextField(
                    controller: reasonController,
                    decoration: InputDecoration(
                      labelText: 'Reason / Notes (Optional)',
                      hintText: 'e.g. Course completed / Relocated / Opted out',
                      prefixIcon: const Icon(Icons.notes_rounded),
                      filled: true,
                      fillColor: isDark ? AppColors.surfaceDarkSecondary : AppColors.surfaceVariantLight,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: (selectedAction == RemovalActionType.bothHostelAndMess ||
                                selectedAction == RemovalActionType.deletePermanently ||
                                student.isMessOnly)
                            ? AppColors.danger
                            : (selectedAction == RemovalActionType.messOnly
                                ? (isDark ? AppColors.secondaryLight : AppColors.secondary)
                                : (isDark ? AppColors.primaryLight : AppColors.primary)),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: isSubmitting ? null : handleConfirm,
                      icon: isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_circle_outline, size: 18),
                      label: Text(
                        isSubmitting
                            ? 'Processing...'
                            : _getActionLabel(selectedAction, student.isMessOnly),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

Widget _buildOptionTile({
  required bool isDark,
  required bool isSelected,
  required IconData icon,
  required Color iconColor,
  required String title,
  required String subtitle,
  required VoidCallback onTap,
}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(
      color: isSelected
          ? iconColor.withValues(alpha: isDark ? 0.2 : 0.08)
          : (isDark ? AppColors.surfaceDarkSecondary : Colors.white),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: isSelected ? iconColor : (isDark ? AppColors.borderDark : AppColors.borderLight),
        width: isSelected ? 2 : 1,
      ),
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.textMutedDark : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
            Radio<bool>(
              value: true,
              groupValue: isSelected,
              activeColor: iconColor,
              onChanged: (_) => onTap(),
            ),
          ],
        ),
      ),
    ),
  );
}

String _getActionLabel(RemovalActionType action, bool isMessOnly) {
  if (isMessOnly) return 'Confirm Remove from Mess';
  switch (action) {
    case RemovalActionType.bothHostelAndMess:
      return 'Confirm Remove from Both Hostel & Mess';
    case RemovalActionType.hostelOnly:
      return 'Confirm Checkout from Hostel';
    case RemovalActionType.messOnly:
      return 'Confirm Unenroll from Mess';
    case RemovalActionType.deletePermanently:
      return 'Permanently Delete Record';
  }
}
