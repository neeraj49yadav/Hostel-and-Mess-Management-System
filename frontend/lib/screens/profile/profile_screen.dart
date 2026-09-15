import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/admin_user.dart';
import '../../models/organization.dart';
import '../../providers/auth_provider.dart';
import '../../providers/mess_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/image_service.dart';
import '../audit/audit_log_screen.dart';
import '../auth/pin_screen.dart';
import 'master_register_screen.dart';
import '../../widgets/app_avatar_image.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      auth.refreshAdmins();
      auth.loadNotifications();
    });
    _recoverLostProfileImage();
  }

  Future<void> _recoverLostProfileImage() async {
    try {
      final lostPhoto = await ImageService.retrieveLostData();
      if (lostPhoto != null && mounted) {
        final ctx = await ImageService.getPendingPhotoContext();
        await ImageService.clearPendingPhotoContext();
        if (!mounted) return;
        final auth = context.read<AuthProvider>();
        if (ctx == 'logo' && auth.currentOrganization != null) {
          final org = auth.currentOrganization!;
          await auth.updateOrganization(
            name: org.name,
            logo: lostPhoto,
            city: org.city,
            contactPhone: org.contactPhone,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('📸 Restored captured photo as hostel logo!'), backgroundColor: AppColors.success),
            );
          }
        } else if (auth.currentAdmin != null) {
          final admin = auth.currentAdmin!;
          await auth.updateProfile(name: admin.name, phone: admin.phone, profilePhoto: lostPhoto);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('📸 Restored captured photo to your profile!'), backgroundColor: AppColors.success),
            );
          }
        }
      }
    } catch (_) {}
  }

  // --- Image Picker Helper (Auto-Compressed) ---
  Future<String?> _pickBase64Image(ImageSource source, [String contextType = 'profile']) async {
    try {
      await ImageService.setPendingPhotoContext(contextType);
      final base64String = await ImageService.pickAndCompressImage(
        source: source,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 70,
      );
      await ImageService.clearPendingPhotoContext();
      return base64String;
    } catch (e) {
      await ImageService.clearPendingPhotoContext();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick photo: $e'), backgroundColor: AppColors.danger),
        );
      }
      return null;
    }
  }

  // --- Avatar Display Helper ---
  Widget _buildAdminAvatar({
    required String? photoUrl,
    required String name,
    double radius = 26,
    bool isSelf = false,
  }) {
    return AppAvatarImage(
      photoUrl: photoUrl,
      width: radius * 2,
      height: radius * 2,
      isCircle: true,
      fit: BoxFit.cover,
      fallback: _buildFallbackShield(radius, isSelf),
    );
  }

  Widget _buildFallbackShield(double radius, bool isSelf) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isSelf
              ? [AppColors.primary, AppColors.accent]
              : [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(radius * 0.7),
        boxShadow: [
          BoxShadow(
            color: (isSelf ? AppColors.primary : const Color(0xFF6366F1)).withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          Icons.shield_rounded,
          color: Colors.white,
          size: radius * 1.05,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = context.watch<ThemeProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final currentAdmin = auth.currentAdmin;
    final org = auth.currentOrganization;
    final isOrgAdmin = auth.isOrgAdmin;

    final pinAlerts = auth.notifications.where((n) {
      final action = (n['action'] ?? '').toString();
      final type = (n['metadata']?['notificationType'] ?? '').toString();
      return action == 'STAFF_PIN_CHANGED' || type == 'PIN_CHANGE_ALERT' || (n['metadata']?['isHighPriority'] == true && action.contains('PIN'));
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile & Team', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          if (isOrgAdmin)
            IconButton(
              icon: Badge(
                isLabelVisible: pinAlerts.isNotEmpty,
                label: Text('${pinAlerts.length}'),
                backgroundColor: AppColors.danger,
                child: const Icon(Icons.notifications_rounded),
              ),
              tooltip: 'Staff PIN Change Alerts',
              onPressed: () => _showPinAlertsModal(context, auth, isDark),
            ),
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: isDark ? Colors.amber : AppColors.textPrimaryLight,
            ),
            tooltip: 'Toggle Theme',
            onPressed: () => theme.toggleTheme(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Team & Alerts',
            onPressed: () {
              auth.refreshAdmins();
              auth.loadNotifications();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Refreshed team profiles!'), duration: Duration(seconds: 1)),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await auth.refreshAdmins();
          await auth.loadNotifications();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 1. Current User Profile Card (With Photo Upload)
            _buildUserProfileCard(context, auth, currentAdmin, org, isDark),

            const SizedBox(height: 16),

            // 1b. Hostel / Organization Profile Card (With Logo & Name Edit)
            _buildOrganizationProfileCard(context, auth, org, isOrgAdmin, isDark),

            const SizedBox(height: 16),

            // 2. PIN Management & Security Card
            _buildSecurityCard(context, currentAdmin, isOrgAdmin, isDark),

            const SizedBox(height: 16),

            // 3. Staff & Team Management Section (For Org Admins / Owners)
            if (isOrgAdmin) ...[
              _buildStaffManagementSection(context, auth, isDark),
              const SizedBox(height: 16),

              // 🍽️ Admin Action: Bulk Extend Mess Validity
              ListTile(
                tileColor: isDark ? AppColors.surfaceDarkSecondary : AppColors.surfaceVariantLight,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.more_time_rounded, color: Colors.orange, size: 22),
                ),
                title: const Text('Bulk Extend Mess Validity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Extend validity in days & push billing cycles forward', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text('Admin Only', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange)),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right, size: 20),
                  ],
                ),
                onTap: () {
                  _showBulkExtendMessDialog(context);
                },
              ),
              const SizedBox(height: 16),
            ],

            // 📜 Permanent Master Student & Member Register
            ListTile(
              tileColor: isDark ? AppColors.surfaceDarkSecondary : AppColors.surfaceVariantLight,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.indigo.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.menu_book_rounded, color: Colors.indigo, size: 22),
              ),
              title: const Text('Master Student & Member Register', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('Permanent non-deletable archive & Print PDF', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('Archive', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.success)),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right, size: 20),
                ],
              ),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const MasterRegisterScreen()));
              },
            ),

            const SizedBox(height: 12),

            // 4. Audit Log Quick Link
            ListTile(
              tileColor: isDark ? AppColors.surfaceDarkSecondary : AppColors.surfaceVariantLight,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.history_rounded, color: AppColors.primaryLight, size: 22),
              ),
              title: const Text('Admin Audit Log & Activity Trail', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('View timestamped actions & logins', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AuditLogScreen()));
              },
            ),

            const SizedBox(height: 20),

            // 5. Sign Out Button
            OutlinedButton.icon(
              onPressed: () {
                _showSignOutDialog(context, auth);
              },
              icon: const Icon(Icons.logout_rounded, color: AppColors.danger, size: 20),
              label: const Text('Sign Out / Switch Admin', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.danger),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- Profile Card ---
  Widget _buildUserProfileCard(
    BuildContext context,
    AuthProvider auth,
    AdminUser? admin,
    dynamic org,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Profile Photo with Camera Badge
              Stack(
                children: [
                  _buildAdminAvatar(
                    photoUrl: admin?.profilePhoto,
                    name: admin?.name ?? 'Admin',
                    radius: 36,
                    isSelf: true,
                  ),
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: InkWell(
                      onTap: () => _showPhotoOptionSheet(context, auth, admin),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      admin?.name ?? 'Administrator',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        admin?.role ?? 'Staff',
                        style: const TextStyle(
                          color: AppColors.primaryLight,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    if (admin?.phone.isNotEmpty == true) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.phone_rounded, size: 14, color: AppColors.textMuted),
                          const SizedBox(width: 6),
                          Text(
                            admin!.phone,
                            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: AppColors.primaryLight),
                tooltip: 'Edit Profile Details',
                onPressed: () => _showEditProfileDialog(context, admin),
              ),
            ],
          ),

          if (org != null) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.business_rounded, size: 18, color: AppColors.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${org.name}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDarkSecondary : AppColors.surfaceVariantLight,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                  ),
                  child: Text(
                    'CODE: ${org.code}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.primaryLight),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // --- Hostel / Organization Profile Card (With Logo & Name Edit) ---
  Widget _buildOrganizationProfileCard(
    BuildContext context,
    AuthProvider auth,
    Organization? org,
    bool isOrgAdmin,
    bool isDark,
  ) {
    if (org == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Hostel Logo with Camera Badge for Org Admin
              Stack(
                children: [
                  _buildOrgLogoAvatar(
                    logoUrl: org.logo,
                    name: org.name,
                    radius: 28,
                  ),
                  if (isOrgAdmin)
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: InkWell(
                        onTap: () => _showOrgLogoOptionSheet(context, auth, org),
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 12),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      org.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'ORG: ${org.code}',
                            style: const TextStyle(
                              color: AppColors.primaryLight,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        if (org.city.isNotEmpty)
                          Text(
                            '📍 ${org.city}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                          ),
                      ],
                    ),
                    if (org.contactPhone.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '📞 ${org.contactPhone}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ],
                ),
              ),
              if (isOrgAdmin)
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: AppColors.primaryLight),
                  tooltip: 'Edit Hostel Name & Logo',
                  onPressed: () => _showEditOrganizationModal(context, auth, org),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Org Logo Avatar Helper ---
  Widget _buildOrgLogoAvatar({
    required String? logoUrl,
    required String name,
    double radius = 28,
  }) {
    return AppAvatarImage(
      photoUrl: logoUrl,
      width: radius * 2,
      height: radius * 2,
      borderRadius: BorderRadius.circular(radius),
      isCircle: false,
      fit: BoxFit.cover,
      fallback: _buildFallbackOrgIcon(radius),
    );
  }

  Widget _buildFallbackOrgIcon(double radius) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(Icons.apartment_rounded, color: Colors.white, size: radius),
    );
  }

  // --- Org Logo Photo Sheet ---
  void _showOrgLogoOptionSheet(BuildContext context, AuthProvider auth, Organization org) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Hostel / Organization Logo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
                  title: const Text('Take Photo with Camera'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final b64 = await _pickBase64Image(ImageSource.camera, 'logo');
                    if (b64 != null) {
                      await auth.updateOrganization(
                        name: org.name,
                        logo: b64,
                        city: org.city,
                        contactPhone: org.contactPhone,
                      );
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_rounded, color: AppColors.accent),
                  title: const Text('Choose from Gallery'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final b64 = await _pickBase64Image(ImageSource.gallery, 'logo');
                    if (b64 != null) {
                      await auth.updateOrganization(
                        name: org.name,
                        logo: b64,
                        city: org.city,
                        contactPhone: org.contactPhone,
                      );
                    }
                  },
                ),
                if (org.logo != null && org.logo!.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                    title: const Text('Remove Logo', style: TextStyle(color: AppColors.danger)),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await auth.updateOrganization(
                        name: org.name,
                        logo: '',
                        city: org.city,
                        contactPhone: org.contactPhone,
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- Edit Hostel Details Modal ---
  void _showEditOrganizationModal(BuildContext context, AuthProvider auth, Organization org) {
    final nameCtrl = TextEditingController(text: org.name);
    final cityCtrl = TextEditingController(text: org.city);
    final phoneCtrl = TextEditingController(text: org.contactPhone);
    String? currentLogo = org.logo;
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;

          return Container(
            margin: EdgeInsets.only(
              top: MediaQuery.of(ctx).padding.top + 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.black12,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.primary, AppColors.accent],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.apartment_rounded, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Edit Hostel Details',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                ),
                              ),
                              Text(
                                'Change hostel name, logo, and contact info',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppColors.textMutedDark : AppColors.textSecondaryLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const Divider(height: 28),

                    // Logo Selection
                    Center(
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              _buildOrgLogoAvatar(
                                logoUrl: currentLogo,
                                name: nameCtrl.text,
                                radius: 40,
                              ),
                              Positioned(
                                bottom: -2,
                                right: -2,
                                child: InkWell(
                                  onTap: () async {
                                    final b64 = await _pickBase64Image(ImageSource.gallery);
                                    if (b64 != null) {
                                      setModalState(() => currentLogo = b64);
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                    child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TextButton.icon(
                                icon: const Icon(Icons.photo_library_rounded, size: 16),
                                label: const Text('Change Logo', style: TextStyle(fontSize: 12)),
                                onPressed: () async {
                                  final b64 = await _pickBase64Image(ImageSource.gallery);
                                  if (b64 != null) {
                                    setModalState(() => currentLogo = b64);
                                  }
                                },
                              ),
                              if (currentLogo != null && currentLogo!.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                TextButton.icon(
                                  icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.danger),
                                  label: const Text('Remove', style: TextStyle(fontSize: 12, color: AppColors.danger)),
                                  onPressed: () {
                                    setModalState(() => currentLogo = '');
                                  },
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Hostel Name
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Hostel / PG Name *',
                        hintText: 'e.g. Yaduvanshi Hostel & Mess',
                        prefixIcon: Icon(Icons.domain_rounded),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Hostel name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // City / Campus
                    TextFormField(
                      controller: cityCtrl,
                      decoration: const InputDecoration(
                        labelText: 'City / Campus',
                        hintText: 'e.g. City / Campus',
                        prefixIcon: Icon(Icons.location_city_rounded),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Contact Phone
                    TextFormField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Hostel Contact Phone',
                        hintText: 'e.g. 9876543210',
                        prefixIcon: Icon(Icons.phone_rounded),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 3,
                        ),
                        onPressed: isSaving
                            ? null
                            : () async {
                                if (formKey.currentState!.validate()) {
                                  setModalState(() => isSaving = true);
                                  final messenger = ScaffoldMessenger.of(context);
                                  final nav = Navigator.of(ctx);
                                  final updatedName = nameCtrl.text.trim();
                                  final success = await auth.updateOrganization(
                                    name: updatedName,
                                    logo: currentLogo,
                                    city: cityCtrl.text.trim(),
                                    contactPhone: phoneCtrl.text.trim(),
                                  );

                                  if (mounted) {
                                    setModalState(() => isSaving = false);
                                    if (success) {
                                      nav.pop();
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text('🎉 Hostel details for "$updatedName" updated!'),
                                          backgroundColor: AppColors.success,
                                        ),
                                      );
                                    } else {
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(auth.errorMessage ?? 'Failed to update hostel details'),
                                          backgroundColor: AppColors.danger,
                                        ),
                                      );
                                    }
                                  }
                                }
                              },
                        child: isSaving
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  ),
                                  SizedBox(width: 12),
                                  Text('Saving Changes...'),
                                ],
                              )
                            : const Text(
                                'Save Hostel Details',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // --- Photo Options Sheet ---
  void _showPhotoOptionSheet(BuildContext context, AuthProvider auth, AdminUser? admin) {
    if (admin == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Profile Photo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
                  title: const Text('Take Photo with Camera'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final b64 = await _pickBase64Image(ImageSource.camera);
                    if (b64 != null && mounted) {
                      final ok = await auth.updateProfile(name: admin.name, phone: admin.phone, profilePhoto: b64);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(ok ? '✅ Profile photo updated successfully!' : (auth.errorMessage ?? 'Failed to update photo')),
                            backgroundColor: ok ? AppColors.success : AppColors.danger,
                          ),
                        );
                      }
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_rounded, color: AppColors.accent),
                  title: const Text('Choose from Gallery'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final b64 = await _pickBase64Image(ImageSource.gallery);
                    if (b64 != null && mounted) {
                      final ok = await auth.updateProfile(name: admin.name, phone: admin.phone, profilePhoto: b64);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(ok ? '✅ Profile photo updated successfully!' : (auth.errorMessage ?? 'Failed to update photo')),
                            backgroundColor: ok ? AppColors.success : AppColors.danger,
                          ),
                        );
                      }
                    }
                  },
                ),
                if (admin.profilePhoto != null && admin.profilePhoto!.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                    title: const Text('Remove Photo', style: TextStyle(color: AppColors.danger)),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final ok = await auth.updateProfile(name: admin.name, phone: admin.phone, profilePhoto: '');
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(ok ? 'Profile photo removed' : 'Failed to remove photo'),
                            backgroundColor: ok ? AppColors.info : AppColors.danger,
                          ),
                        );
                      }
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- Security & PIN Card ---
  Widget _buildSecurityCard(BuildContext context, AdminUser? admin, bool isOrgAdmin, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.shield_outlined, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'Security & PIN Settings',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Your 4-digit PIN is used to sign into the system and authenticate your actions.',
            style: TextStyle(fontSize: 12, color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
          ),
          const SizedBox(height: 14),

          ElevatedButton.icon(
            onPressed: () => _showChangeMyPinDialog(context, admin),
            icon: const Icon(Icons.lock_reset_rounded, size: 18),
            label: const Text('Change My 4-Digit PIN'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  // --- Staff & Team Management Section ---
  Widget _buildStaffManagementSection(BuildContext context, AuthProvider auth, bool isDark) {
    final admins = auth.availableAdmins;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.people_alt_rounded, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Organization Staff',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${admins.length}',
                      style: const TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddStaffDialog(context, auth),
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                label: const Text('Add User'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'As Organization Admin, you have full control over staff members, their profile photos, and their 4-digit PINs.',
            style: TextStyle(fontSize: 12, color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
          ),
          const SizedBox(height: 14),

          // List of Admins with PIN Display
          ...admins.map((staff) {
            final isSelf = staff.id == auth.currentAdmin?.id;
            final staffPin = staff.pin ?? '1111';

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDarkSecondary : AppColors.surfaceVariantLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelf ? AppColors.primary.withValues(alpha: 0.5) : (isDark ? AppColors.borderDark : AppColors.borderLight),
                ),
              ),
              child: Row(
                children: [
                  // Staff Avatar Photo
                  _buildAdminAvatar(
                    photoUrl: staff.profilePhoto,
                    name: staff.name,
                    radius: 22,
                    isSelf: isSelf,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                staff.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isSelf) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'YOU',
                                  style: TextStyle(color: AppColors.primaryLight, fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${staff.role} ${staff.phone.isNotEmpty ? "• ${staff.phone}" : ""}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                        const SizedBox(height: 6),

                        // 🔑 STAFF PIN BADGE (PROMINENTLY DISPLAYED)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                : const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF10B981).withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.vpn_key_rounded, size: 12, color: Color(0xFF059669)),
                              const SizedBox(width: 4),
                              Text(
                                'PIN: $staffPin',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  letterSpacing: 1.2,
                                  color: Color(0xFF059669),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Actions Popup
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, size: 20),
                    onSelected: (val) {
                      if (val == 'reset_pin') {
                        _showAdminResetPinDialog(context, auth, staff);
                      } else if (val == 'edit') {
                        _showEditStaffDialog(context, auth, staff);
                      } else if (val == 'delete') {
                        _showDeleteStaffDialog(context, auth, staff);
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'reset_pin',
                        child: Row(
                          children: [
                            Icon(Icons.lock_reset, size: 18, color: AppColors.primary),
                            SizedBox(width: 8),
                            Text('Reset PIN (Set New)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 18, color: Colors.blue),
                            SizedBox(width: 8),
                            Text('Edit Details & Photo', style: TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                      if (!isSelf)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.danger),
                              SizedBox(width: 8),
                              Text('Remove User', style: TextStyle(fontSize: 13, color: AppColors.danger)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // --- Real-Time Staff PIN Change Modal (Opened via Bell Icon) ---
  void _showPinAlertsModal(BuildContext context, AuthProvider auth, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final pinAlerts = auth.notifications.where((n) {
          final action = (n['action'] ?? '').toString();
          final type = (n['metadata']?['notificationType'] ?? '').toString();
          return action == 'STAFF_PIN_CHANGED' || type == 'PIN_CHANGE_ALERT' || (n['metadata']?['isHighPriority'] == true && action.contains('PIN'));
        }).toList();

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.8,
          ),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top drag handle
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.notifications_active_rounded, color: AppColors.warning, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Staff PIN Alerts',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                if (pinAlerts.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.warning,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${pinAlerts.length}',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const Text(
                              'Real-time alerts when staff members update their PIN',
                              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 20),

                // Alerts Content
                Flexible(
                  child: pinAlerts.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 48),
                              SizedBox(height: 12),
                              Text(
                                'No Recent PIN Alerts',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'All staff credentials are up to date and synchronized.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          shrinkWrap: true,
                          itemCount: pinAlerts.length,
                          itemBuilder: (c, index) {
                            final n = pinAlerts[index];
                            final staffName = n['metadata']?['staffName'] ?? n['adminName'] ?? 'Staff Member';
                            final staffRole = n['metadata']?['staffRole'] ?? 'Staff';
                            final newPin = n['metadata']?['newPin'] ?? '';
                            final timeStr = AppFormatters.formatDateTime(n['timestamp']?.toString());

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF3B2D05) : const Color(0xFFFFFBEB),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF78350F) : const Color(0xFFFDE68A),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'PIN Updated by $staffName',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                      ),
                                      if (newPin.toString().isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            'NEW PIN: $newPin',
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    n['details'] ?? '$staffName ($staffRole) updated their login PIN.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(Icons.access_time_rounded, size: 12, color: AppColors.textMuted),
                                      const SizedBox(width: 4),
                                      Text(
                                        timeStr,
                                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- 1. Dialog: Change My Own PIN ---
  void _showChangeMyPinDialog(BuildContext context, AdminUser? admin) {
    final currentPinCtrl = TextEditingController();
    final newPinCtrl = TextEditingController();
    final confirmPinCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.lock_reset_rounded, color: AppColors.primaryLight, size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Change My 4-Digit PIN',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                        ),
                        IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: currentPinCtrl,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                      decoration: const InputDecoration(
                        labelText: 'Current 4-Digit PIN *',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      validator: (v) => (v == null || v.trim().length != 4) ? 'Enter your 4-digit current PIN' : null,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: newPinCtrl,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                      decoration: const InputDecoration(
                        labelText: 'New 4-Digit PIN *',
                        prefixIcon: Icon(Icons.pin),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().length != 4) return 'New PIN must be exactly 4 digits';
                        if (v.trim() == currentPinCtrl.text.trim()) return 'New PIN must be different from current PIN';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: confirmPinCtrl,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                      decoration: const InputDecoration(
                        labelText: 'Confirm New 4-Digit PIN *',
                        prefixIcon: Icon(Icons.check_circle_outline),
                      ),
                      validator: (v) {
                        if (v != newPinCtrl.text) return 'PINs do not match';
                        return null;
                      },
                    ),

                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                setModalState(() => isSubmitting = true);

                                final messenger = ScaffoldMessenger.of(context);
                                final nav = Navigator.of(ctx);
                                final pinText = newPinCtrl.text.trim();
                                final auth = context.read<AuthProvider>();
                                final success = await auth.updateMyPin(
                                  currentPin: currentPinCtrl.text.trim(),
                                  newPin: pinText,
                                );

                                if (mounted) {
                                  setModalState(() => isSubmitting = false);
                                  if (success) {
                                    nav.pop();
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text('🎉 PIN updated successfully to $pinText!'),
                                        backgroundColor: AppColors.success,
                                      ),
                                    );
                                  } else {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(auth.errorMessage ?? 'Failed to update PIN. Check current PIN.'),
                                        backgroundColor: AppColors.danger,
                                      ),
                                    );
                                  }
                                }
                              },
                        child: isSubmitting
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Update PIN', style: TextStyle(fontWeight: FontWeight.bold)),
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

  // --- 2. Dialog: Admin Directly Sets/Resets Staff PIN ---
  void _showAdminResetPinDialog(BuildContext context, AuthProvider auth, AdminUser staff) {
    final pinCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: Row(
                children: [
                  const Icon(Icons.lock_reset_rounded, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Reset PIN: ${staff.name}', style: const TextStyle(fontSize: 16)),
                  ),
                ],
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'As Organization Admin, you can set the new 4-digit PIN for ${staff.name} (${staff.role}). Current PIN is: ${staff.pin ?? "1111"}.',
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: pinCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                      decoration: const InputDecoration(
                        labelText: 'New 4-Digit PIN *',
                        hintText: 'e.g. 5566',
                        prefixIcon: Icon(Icons.pin_rounded),
                      ),
                      validator: (v) => (v == null || v.trim().length != 4) ? 'Must be exactly 4 digits' : null,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => isSubmitting = true);

                          final messenger = ScaffoldMessenger.of(context);
                          final nav = Navigator.of(ctx);
                          final resetPin = pinCtrl.text.trim();
                          final staffName = staff.name;
                          final success = await auth.resetStaffPin(
                            targetAdminId: staff.id,
                            newPin: resetPin,
                          );

                          if (mounted) {
                            setDialogState(() => isSubmitting = false);
                            if (success) {
                              nav.pop();
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('✅ PIN for $staffName reset to "$resetPin"!'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            } else {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(auth.errorMessage ?? 'Failed to reset PIN'),
                                  backgroundColor: AppColors.danger,
                                ),
                              );
                            }
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Set PIN'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- 3. Dialog: Add New Staff Member (Admin Sets Initial PIN & Photo) ---
  void _showAddStaffDialog(BuildContext context, AuthProvider auth) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final pinCtrl = TextEditingController();
    String selectedRole = 'Hostel In-charge';
    String? staffPhoto;
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    final roles = [
      'Hostel In-charge',
      'Mess In-charge',
      'Assistant Warden',
      'Chief Warden',
      'Accountant',
      'Supervisor / Staff',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.person_add_rounded, color: AppColors.primaryLight, size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Add New Team Member',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                        ),
                        IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Staff Photo Picker
                    Center(
                      child: Stack(
                        children: [
                          _buildAdminAvatar(
                            photoUrl: staffPhoto,
                            name: nameCtrl.text.isNotEmpty ? nameCtrl.text : 'New Staff',
                            radius: 32,
                          ),
                          Positioned(
                            bottom: -2,
                            right: -2,
                            child: InkWell(
                              onTap: () async {
                                final b64 = await _pickBase64Image(ImageSource.gallery);
                                if (b64 != null) {
                                  setModalState(() => staffPhoto = b64);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.camera_alt, color: Colors.white, size: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Staff Full Name *',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter staff name' : null,
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      initialValue: selectedRole,
                      decoration: const InputDecoration(
                        labelText: 'Role / Designation *',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      items: roles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedRole = val);
                      },
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Contact Phone Number (Optional)',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: pinCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                      decoration: const InputDecoration(
                        labelText: 'Assign 4-Digit Login PIN *',
                        hintText: 'e.g. 5566',
                        prefixIcon: Icon(Icons.pin_rounded),
                        helperText: 'Decide the 4-digit PIN for this user to log in.',
                      ),
                      validator: (v) => (v == null || v.trim().length != 4) ? 'Enter a 4-digit PIN' : null,
                    ),

                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                setModalState(() => isSubmitting = true);

                                final messenger = ScaffoldMessenger.of(context);
                                final nav = Navigator.of(ctx);
                                final staffName = nameCtrl.text.trim();
                                final staffPin = pinCtrl.text.trim();

                                final success = await auth.addUser(
                                  name: staffName,
                                  role: selectedRole,
                                  phone: phoneCtrl.text.trim(),
                                  pin: staffPin,
                                  profilePhoto: staffPhoto,
                                );

                                if (mounted) {
                                  setModalState(() => isSubmitting = false);
                                  if (success) {
                                    nav.pop();
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text('🎉 Staff member "$staffName" added with PIN $staffPin!'),
                                        backgroundColor: AppColors.success,
                                      ),
                                    );
                                  } else {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(auth.errorMessage ?? 'Failed to add staff member'),
                                        backgroundColor: AppColors.danger,
                                      ),
                                    );
                                  }
                                }
                              },
                        child: isSubmitting
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Add User & Create Profile', style: TextStyle(fontWeight: FontWeight.bold)),
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

  // --- 4. Dialog: Edit Staff Profile Details & Photo ---
  void _showEditStaffDialog(BuildContext context, AuthProvider auth, AdminUser staff) {
    final nameCtrl = TextEditingController(text: staff.name);
    final phoneCtrl = TextEditingController(text: staff.phone);
    String selectedRole = staff.role;
    String? staffPhoto = staff.profilePhoto;
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    final roles = [
      'Hostel In-charge',
      'Mess In-charge',
      'Assistant Warden',
      'Chief Warden',
      'Accountant',
      'Supervisor / Staff',
      if (![
        'Hostel In-charge',
        'Mess In-charge',
        'Assistant Warden',
        'Chief Warden',
        'Accountant',
        'Supervisor / Staff',
      ].contains(staff.role))
        staff.role,
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: const Text('Edit Staff Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Photo
                    Stack(
                      children: [
                        _buildAdminAvatar(
                          photoUrl: staffPhoto,
                          name: nameCtrl.text,
                          radius: 28,
                        ),
                        Positioned(
                          bottom: -2,
                          right: -2,
                          child: InkWell(
                            onTap: () async {
                              final b64 = await _pickBase64Image(ImageSource.gallery);
                              if (b64 != null) {
                                setDialogState(() => staffPhoto = b64);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt, color: Colors.white, size: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Full Name *', prefixIcon: Icon(Icons.person_outline)),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Name required' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedRole,
                      decoration: const InputDecoration(labelText: 'Role *', prefixIcon: Icon(Icons.badge_outlined)),
                      items: roles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedRole = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: phoneCtrl,
                      decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone_outlined)),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => isSubmitting = true);

                          final messenger = ScaffoldMessenger.of(context);
                          final nav = Navigator.of(ctx);
                          final success = await auth.updateUser(
                            staff.id,
                            name: nameCtrl.text.trim(),
                            role: selectedRole,
                            phone: phoneCtrl.text.trim(),
                            profilePhoto: staffPhoto,
                          );

                          if (mounted) {
                            setDialogState(() => isSubmitting = false);
                            if (success) {
                              nav.pop();
                              messenger.showSnackBar(
                                const SnackBar(content: Text('Staff details updated!'), backgroundColor: AppColors.success),
                              );
                            }
                          }
                        },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- 5. Dialog: Edit My Profile Details ---
  void _showEditProfileDialog(BuildContext context, AdminUser? admin) {
    if (admin == null) return;
    final nameCtrl = TextEditingController(text: admin.name);
    final phoneCtrl = TextEditingController(text: admin.phone);
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: const Text('Edit My Profile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'My Name *', prefixIcon: Icon(Icons.person_outline)),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: phoneCtrl,
                      decoration: const InputDecoration(labelText: 'Phone Number', prefixIcon: Icon(Icons.phone_outlined)),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => isSubmitting = true);

                          final messenger = ScaffoldMessenger.of(context);
                          final nav = Navigator.of(ctx);
                          final auth = context.read<AuthProvider>();
                          final success = await auth.updateProfile(
                            name: nameCtrl.text.trim(),
                            phone: phoneCtrl.text.trim(),
                            profilePhoto: admin.profilePhoto,
                          );

                          if (mounted) {
                            setDialogState(() => isSubmitting = false);
                            if (success) {
                              nav.pop();
                              messenger.showSnackBar(
                                const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: AppColors.success),
                              );
                            }
                          }
                        },
                  child: const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- 6. Dialog: Delete Staff ---
  void _showDeleteStaffDialog(BuildContext context, AuthProvider auth, AdminUser staff) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.danger),
              const SizedBox(width: 8),
              Expanded(child: Text('Remove ${staff.name}?')),
            ],
          ),
          content: Text(
            'Are you sure you want to remove "${staff.name}" (${staff.role}) from this organization? They will no longer be able to log in.',
            style: const TextStyle(fontSize: 13),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final nav = Navigator.of(ctx);
                final staffName = staff.name;
                final success = await auth.deleteUser(staff.id);
                if (mounted) {
                  nav.pop();
                  if (success) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('Removed $staffName'), backgroundColor: AppColors.danger),
                    );
                  }
                }
              },
              child: const Text('Remove User'),
            ),
          ],
        );
      },
    );
  }

  // --- 8. Bulk Extend Mess Validity Dialog (Admin Only) ---
  void _showBulkExtendMessDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    int selectedDays = 7;
    final customDaysCtrl = TextEditingController(text: '7');
    final reasonCtrl = TextEditingController();
    String targetScope = 'ALL';
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          return Container(
            margin: EdgeInsets.only(
              top: MediaQuery.of(ctx).padding.top + 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.more_time_rounded, color: Colors.orange, size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bulk Extend Mess Validity',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                            Text(
                              'Push validity & update billing cycles for students',
                              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Preset Chips
                  const Text('Select Extension Days:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [5, 7, 10, 15, 30].map((d) {
                      final isSelected = selectedDays == d;
                      return ChoiceChip(
                        label: Text('+$d Days', style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Colors.white : null)),
                        selected: isSelected,
                        selectedColor: Colors.orange,
                        onSelected: (val) {
                          if (val) {
                            setModalState(() {
                              selectedDays = d;
                              customDaysCtrl.text = d.toString();
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),

                  // Custom days input
                  TextField(
                    controller: customDaysCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'Custom Extension (Days)',
                      prefixIcon: const Icon(Icons.calendar_today_rounded, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    onChanged: (val) {
                      final parsed = int.tryParse(val);
                      if (parsed != null && parsed > 0) {
                        setModalState(() {
                          selectedDays = parsed;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // Target Scope
                  const Text('Apply To:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'ALL', label: Text('All Students', style: TextStyle(fontSize: 12))),
                      ButtonSegment(value: 'HOSTEL_ONLY', label: Text('Hostelites', style: TextStyle(fontSize: 12))),
                      ButtonSegment(value: 'OUTSIDE_ONLY', label: Text('Day Scholars', style: TextStyle(fontSize: 12))),
                    ],
                    selected: {targetScope},
                    onSelectionChanged: (newSet) {
                      setModalState(() {
                        targetScope = newSet.first;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Optional Reason
                  TextField(
                    controller: reasonCtrl,
                    decoration: InputDecoration(
                      labelText: 'Reason for Extension (Optional)',
                      hintText: 'e.g. Diwali Vacation, Semester Break, Monsoon Leave',
                      prefixIcon: const Icon(Icons.edit_note_rounded, size: 22),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Notice Box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded, color: Colors.orange, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Extending by +$selectedDays day${selectedDays > 1 ? "s" : ""} will push every active mess student\'s expiry date forward and automatically update their monthly billing cycle day in active records and Master Register.',
                            style: const TextStyle(fontSize: 12, height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(modalCtx),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  final daysToApply = int.tryParse(customDaysCtrl.text.trim()) ?? selectedDays;
                                  if (daysToApply <= 0) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Please enter a valid number of days (> 0).'), backgroundColor: AppColors.danger),
                                    );
                                    return;
                                  }

                                  setModalState(() => isSubmitting = true);
                                  final messProv = context.read<MessProvider>();
                                  final res = await messProv.bulkExtendMessValidity(
                                    days: daysToApply,
                                    reason: reasonCtrl.text.trim(),
                                    targetMemberType: targetScope,
                                  );

                                  if (modalCtx.mounted) {
                                    Navigator.pop(modalCtx);
                                  }

                                  if (context.mounted) {
                                    if (res['success'] == true) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('🎉 ${res['message']}'),
                                          backgroundColor: AppColors.success,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('❌ ${res['message']}'),
                                          backgroundColor: AppColors.danger,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  }
                                },
                          icon: isSubmitting
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.check_circle_outline_rounded),
                          label: Text(
                            isSubmitting ? 'Extending...' : 'Apply +$selectedDays Days',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // --- 9. Sign Out Dialog ---
  void _showSignOutDialog(BuildContext context, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.logout_rounded, color: AppColors.danger),
              SizedBox(width: 8),
              Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text('Are you sure you want to sign out and lock the application?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(ctx);
                auth.logout();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const PinScreen()),
                );
              },
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );
  }
}
