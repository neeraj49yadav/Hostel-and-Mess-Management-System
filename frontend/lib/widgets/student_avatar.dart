import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../models/student.dart';
import 'app_avatar_image.dart';

class StudentAvatar extends StatelessWidget {
  final Student? student;
  final String? name;
  final String? photoUrl;
  final String? roomNumber;
  final double radius;
  final bool showBedBadge;
  final String? bedNo;
  final bool enablePreview;
  final VoidCallback? onTap;

  const StudentAvatar({
    super.key,
    this.student,
    this.name,
    this.photoUrl,
    this.roomNumber,
    this.radius = 22,
    this.showBedBadge = false,
    this.bedNo,
    this.enablePreview = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveName = student?.name ?? name ?? 'Student';
    final effectivePhoto = student?.photoUrl ?? photoUrl;
    final effectiveBed = student?.bedNo ?? bedNo;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final primaryColor = isDark ? AppColors.primaryLight : AppColors.primary;
    final initial = effectiveName.trim().isNotEmpty ? effectiveName.trim()[0].toUpperCase() : 'S';

    final avatarContent = AppAvatarImage(
      photoUrl: effectivePhoto,
      width: radius * 2,
      height: radius * 2,
      isCircle: true,
      fit: BoxFit.cover,
      fallback: _buildFallbackInitial(initial, isDark, primaryColor),
    );

    Widget rootWidget = Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: (isDark ? AppColors.primaryLight : AppColors.primary).withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: avatarContent,
    );

    if (showBedBadge && effectiveBed != null && effectiveBed.isNotEmpty && effectiveBed != '-') {
      rootWidget = Stack(
        clipBehavior: Clip.none,
        children: [
          rootWidget,
          Positioned(
            bottom: -2,
            right: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: isDark ? AppColors.primaryLight : AppColors.primary,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? AppColors.surfaceDark : Colors.white, width: 1.5),
              ),
              child: Text(
                effectiveBed,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: () {
        if (onTap != null) {
          onTap!();
        } else if (enablePreview) {
          showStudentImagePreview(
            context,
            name: effectiveName,
            photoUrl: effectivePhoto,
            roomNumber: student?.roomNumber ?? roomNumber,
            bedNo: effectiveBed,
            phone: student?.phone,
          );
        }
      },
      child: rootWidget,
    );
  }

  Widget _buildFallbackInitial(String initial, bool isDark, Color primaryColor) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [const Color(0xFFEEF2FF), const Color(0xFFE0E7FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: radius * 0.85,
          fontWeight: FontWeight.bold,
          color: primaryColor,
        ),
      ),
    );
  }
}

/// 🔍 Interactive Full-Screen Image Preview Modal with pinch-to-zoom
void showStudentImagePreview(
  BuildContext context, {
  required String name,
  String? photoUrl,
  String? roomNumber,
  String? bedNo,
  String? phone,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'S';

  showDialog(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black87,
    builder: (ctx) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Bar with Resident Info & Close Button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          roomNumber != null && roomNumber.isNotEmpty && roomNumber != 'N/A'
                              ? 'Room $roomNumber • Bed ${bedNo ?? "-"}'
                              : (phone != null ? 'Phone: $phone' : 'Hostel Resident'),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.textMutedDark : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                    tooltip: 'Close Preview',
                  ),
                ],
              ),
            ),

            // Image Preview Area with InteractiveViewer (Zoom & Pan)
            Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.65,
                maxWidth: 450,
              ),
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0B0F19) : const Color(0xFF1E293B),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                child: InteractiveViewer(
                  panEnabled: true,
                  minScale: 0.8,
                  maxScale: 4.0,
                  child: _buildPreviewImage(photoUrl, initial, isDark),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

Widget _buildPreviewImage(String? photoUrl, String initial, bool isDark) {
  return AppAvatarImage(
    photoUrl: photoUrl,
    width: double.infinity,
    height: 350,
    isCircle: false,
    fit: BoxFit.contain,
    fallback: _buildPreviewFallback(initial, isDark),
  );
}

Widget _buildPreviewFallback(String initial, bool isDark) {
  return Container(
    height: 280,
    width: double.infinity,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: isDark
            ? [const Color(0xFF1E293B), const Color(0xFF0B0F19)]
            : [const Color(0xFF334155), const Color(0xFF1E293B)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    alignment: Alignment.center,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 54,
          backgroundColor: AppColors.primary.withValues(alpha: 0.25),
          child: Text(
            initial,
            style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'No photo uploaded yet',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
      ],
    ),
  );
}
