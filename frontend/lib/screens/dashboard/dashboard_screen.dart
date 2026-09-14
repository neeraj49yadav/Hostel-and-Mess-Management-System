import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/hostel_provider.dart';
import '../../providers/mess_provider.dart';
import '../hostel/add_edit_student_screen.dart';
import '../hostel/room_matrix_screen.dart';
import '../hostel/leave_register_screen.dart';
import '../mess/add_expense_screen.dart';
import '../mess/add_mess_member_screen.dart';
import '../finance/record_payment_screen.dart';
import '../dues_expiry/dues_expiry_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  Widget _buildAdminProfileAvatar(String? photoUrl, String name) {
    if (photoUrl != null && photoUrl.trim().isNotEmpty) {
      final photo = photoUrl.trim();
      try {
        final cleanBase64 = photo.contains(',') ? photo.split(',')[1] : photo;
        final bytes = base64Decode(cleanBase64);
        return Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipOval(
            child: Image.memory(
              bytes,
              width: 52,
              height: 52,
              fit: BoxFit.cover,
              errorBuilder: (c, e, s) => _buildFallbackShield(),
            ),
          ),
        );
      } catch (_) {
        if (photo.startsWith('http')) {
          return Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.network(
                photo,
                width: 52,
                height: 52,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => _buildFallbackShield(),
              ),
            ),
          );
        }
      }
    }

    return _buildFallbackShield();
  }

  Widget _buildFallbackShield() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(Icons.shield_rounded, color: Colors.white, size: 28),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final dash = context.watch<DashboardProvider>();
    final mess = context.watch<MessProvider>();
    final stats = dash.stats;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (dash.isLoading && stats == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final expiringCount = stats?.expiringSoonCount ?? 0;
    final overdueCount = stats?.overdueCount ?? 0;
    final dashProvider = context.read<DashboardProvider>();
    final hostelProvider = context.read<HostelProvider>();
    final messProvider = context.read<MessProvider>();

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          dashProvider.fetchDashboardStats(),
          hostelProvider.fetchStudents(),
          messProvider.fetchMessMembers(),
        ]);
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // Pro Welcome Hero Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF312E81), const Color(0xFF1E1B4B)]
                    : [AppColors.primary, const Color(0xFF3B82F6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: (isDark ? const Color(0xFF4338CA) : AppColors.primary).withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                _buildAdminProfileAvatar(
                  auth.currentAdmin?.profilePhoto,
                  auth.currentAdmin?.name ?? 'Admin',
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    auth.currentAdmin?.name ?? 'Admin In-Charge',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 🚨 High Priority Expiry Alert Banner
          if (expiringCount > 0 || overdueCount > 0)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? (overdueCount > 0 ? const Color(0xFF450A0A) : const Color(0xFF451A03))
                    : (overdueCount > 0 ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB)),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? (overdueCount > 0 ? const Color(0xFF991B1B) : const Color(0xFFB45309))
                      : (overdueCount > 0 ? const Color(0xFFFCA5A5) : const Color(0xFFFDE68A)),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        overdueCount > 0 ? Icons.error_outline_rounded : Icons.warning_amber_rounded,
                        color: overdueCount > 0 ? AppColors.dangerLight : AppColors.warningLight,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        overdueCount > 0 ? 'Action Required: Pending Dues Alert' : 'Upcoming Expiry Alert',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isDark
                              ? (overdueCount > 0 ? const Color(0xFFFCA5A5) : const Color(0xFFFDE68A))
                              : (overdueCount > 0 ? const Color(0xFF991B1B) : const Color(0xFF92400E)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• ${stats?.messExpiringSoonCount ?? 0} Mess plans expiring in 1–5 days (${stats?.messOverdueCount ?? 0} overdue)\n• ${stats?.rentOverdueCount ?? 0} Hostel Rent installments overdue (${stats?.rentExpiringSoonCount ?? 0} upcoming)',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: isDark
                          ? (overdueCount > 0 ? const Color(0xFFFECACA) : const Color(0xFFFEF08A))
                          : (overdueCount > 0 ? const Color(0xFF7F1D1D) : const Color(0xFF78350F)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: overdueCount > 0 ? AppColors.danger : AppColors.warning,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.send_rounded, size: 16),
                      label: const Text('Open Dues & WhatsApp Reminders'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const DuesExpiryScreen()),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

          // 4-KPI Metric Grid
          Row(
            children: [
              Expanded(
                child: _buildProKpiCard(
                  context,
                  title: 'Residents',
                  value: '${stats?.occupiedBeds ?? 0}',
                  subtitle: '${stats?.occupancyPercentage ?? 0}% Occupied',
                  icon: Icons.hotel_rounded,
                  accentColor: const Color(0xFF6366F1),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildProKpiCard(
                  context,
                  title: 'Vacant Beds',
                  value: '${stats?.vacantBeds ?? 0}',
                  subtitle: 'of ${stats?.totalBeds ?? 0} Total Beds',
                  icon: Icons.single_bed_rounded,
                  accentColor: const Color(0xFF10B981),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: _buildProKpiCard(
                  context,
                  title: 'Net Cash Balance',
                  value: AppFormatters.formatCurrency(stats?.netProfitBalance),
                  subtitle: (stats?.isProfitable ?? true) ? 'Profitable this mo' : 'Loss this mo',
                  icon: Icons.account_balance_wallet_rounded,
                  accentColor: (stats?.isProfitable ?? true) ? AppColors.success : AppColors.danger,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildProKpiCard(
                  context,
                  title: 'Mess Subscribers',
                  value: '${mess.totalAllCount}',
                  subtitle: '${mess.totalOutsideCount} Outside • ${mess.totalHostelCount} Hostel',
                  icon: Icons.restaurant_menu_rounded,
                  accentColor: const Color(0xFF0D9488),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Quick Operations Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Quick Operations',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
              ),
              Text(
                '6 Shortcuts',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Quick Operations 2-Column Grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.3,
            children: [
              _buildActionTile(
                context,
                title: '+ Collect Fee',
                subtitle: 'Rent & Mess fee',
                icon: Icons.receipt_long_rounded,
                color: AppColors.primaryLight,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RecordPaymentScreen()),
                  );
                },
              ),
              _buildActionTile(
                context,
                title: '+ Mess Expense',
                subtitle: 'Log groceries / milk',
                icon: Icons.add_shopping_cart_rounded,
                color: AppColors.secondaryLight,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
                  );
                },
              ),
              _buildActionTile(
                context,
                title: '+ New Resident',
                subtitle: 'Onboard & room bed',
                icon: Icons.person_add_alt_1_rounded,
                color: const Color(0xFFA78BFA),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddEditStudentScreen()),
                  );
                },
              ),
              _buildActionTile(
                context,
                title: '+ Add Mess Member',
                subtitle: 'Outside / hosteler',
                icon: Icons.restaurant_rounded,
                color: const Color(0xFF38BDF8),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddMessMemberScreen()),
                  );
                },
              ),
              _buildActionTile(
                context,
                title: 'Room Matrix',
                subtitle: '${stats?.vacantBeds ?? 0} vacant beds',
                icon: Icons.grid_view_rounded,
                color: const Color(0xFF0EA5E9),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RoomMatrixScreen()),
                  );
                },
              ),
              _buildActionTile(
                context,
                title: 'In/Out Log',
                subtitle: '${stats?.currentlyOutCount ?? 0} students out',
                icon: Icons.departure_board_rounded,
                color: const Color(0xFFF59E0B),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LeaveRegisterScreen()),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildProKpiCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: isDark ? 0.2 : 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: accentColor, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.2 : 0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
