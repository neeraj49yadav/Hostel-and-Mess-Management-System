import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/hostel_provider.dart';
import '../providers/mess_provider.dart';
import '../providers/theme_provider.dart';
import 'dashboard/dashboard_screen.dart';
import 'dues_expiry/dues_expiry_screen.dart';
import 'hostel/student_list_screen.dart';
import 'mess/mess_expenses_screen.dart';
import 'finance/cashbook_screen.dart';
import 'audit/audit_log_screen.dart';
import 'auth/pin_screen.dart';
import 'profile/profile_screen.dart';
import '../widgets/app_avatar_image.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    DashboardScreen(),
    DuesExpiryScreen(),
    StudentListScreen(),
    MessExpensesScreen(),
    CashbookScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Initial fetch for all providers in staged smooth batches
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // Phase 1: High-priority dashboard and resident counts
      context.read<DashboardProvider>().fetchDashboardStats();
      context.read<HostelProvider>().fetchStudents();

      // Phase 2: Rooms and Mess roster
      await Future.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;
      context.read<HostelProvider>().fetchRooms();
      context.read<MessProvider>().fetchMessMembers();

      // Phase 3: Background logs and vendors
      await Future.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;
      context.read<HostelProvider>().fetchLeaveLogs();
      context.read<MessProvider>().fetchExpenses();
      context.read<MessProvider>().fetchVendors();
    });
  }

  void _showSettingsModal() {
    final auth = context.read<AuthProvider>();
    final theme = context.read<ThemeProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildAdminAvatar(
                      auth.currentAdmin?.profilePhoto,
                      auth.currentAdmin?.name ?? 'Admin',
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            auth.currentAdmin?.name ?? 'Admin',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            '${auth.currentAdmin?.role ?? "Chief Warden"} • ${auth.currentOrganization?.name ?? "Hostel"}',
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (auth.currentOrganization != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceDarkSecondary : AppColors.surfaceVariantLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? AppColors.borderDark : AppColors.borderLight,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.business_rounded, size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Org Code: ${auth.currentOrganization!.code} (${auth.currentOrganization!.city})',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),

                // Profile & Staff Management Tile
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.person_pin_rounded, color: AppColors.primaryLight, size: 20),
                  ),
                  title: const Text('My Profile & Team Management', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('Manage PIN, team staff, and security', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProfileScreen()),
                    );
                  },
                ),

                // Theme Mode Switcher Tile
                SwitchListTile(
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF6366F1).withValues(alpha: 0.2) : Colors.amber.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                      color: isDark ? const Color(0xFF818CF8) : Colors.amber.shade800,
                      size: 20,
                    ),
                  ),
                  title: const Text('Dark Mode (Obsidian Pro)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(
                    isDark ? 'High contrast dark theme enabled' : 'Clean light theme enabled',
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  value: theme.isDarkMode,
                  activeThumbColor: AppColors.primaryLight,
                  onChanged: (_) {
                    theme.toggleTheme();
                  },
                ),

                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.history_rounded, color: AppColors.primaryLight, size: 20),
                  ),
                  title: const Text('Admin Audit Log', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text('3-Admin timestamped trail', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AuditLogScreen()),
                    );
                  },
                ),

                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.lock_reset, color: AppColors.danger, size: 20),
                  ),
                  title: const Text('Lock App / Switch Admin', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.danger)),
                  subtitle: const Text('Return to 4-Digit Security Keypad', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  onTap: () {
                    Navigator.pop(ctx);
                    auth.logout();
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const PinScreen()),
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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final dash = context.watch<DashboardProvider>();
    final theme = context.watch<ThemeProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final expiringCount = dash.stats?.expiringSoonCount ?? 0;
    final overdueCount = dash.stats?.overdueCount ?? 0;
    final totalAlerts = expiringCount + overdueCount;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            _buildOrgLogo(auth.currentOrganization?.logo),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    auth.currentOrganization?.name ?? 'Hostel and Mess Management System',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    auth.currentOrganization != null
                        ? 'Org: ${auth.currentOrganization!.code} • ${auth.currentAdmin?.name ?? "Admin"}'
                        : '3-Admin Synchronized',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // 🌙 / ☀️ Dark Mode 1-Tap Toggle
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: isDark ? Colors.amber : AppColors.textPrimaryLight,
            ),
            tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            onPressed: () {
              theme.toggleTheme();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Sync Data',
            onPressed: () {
              context.read<DashboardProvider>().fetchDashboardStats();
              context.read<HostelProvider>().fetchStudents();
              context.read<HostelProvider>().fetchRooms();
              context.read<MessProvider>().fetchMessMembers();
              context.read<MessProvider>().fetchExpenses();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Synced latest updates!'),
                  duration: Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'Admin Settings',
            onPressed: _showSettingsModal,
          ),
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: totalAlerts > 0,
              label: Text('$totalAlerts'),
              backgroundColor: overdueCount > 0 ? AppColors.danger : AppColors.warning,
              child: const Icon(Icons.notifications_active_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: totalAlerts > 0,
              label: Text('$totalAlerts'),
              backgroundColor: overdueCount > 0 ? AppColors.danger : AppColors.warning,
              child: const Icon(Icons.notifications_active_rounded),
            ),
            label: 'Dues & Alerts',
          ),
          const NavigationDestination(
            icon: Icon(Icons.hotel_outlined),
            selectedIcon: Icon(Icons.hotel_rounded),
            label: 'Hostel',
          ),
          const NavigationDestination(
            icon: Icon(Icons.restaurant_menu_outlined),
            selectedIcon: Icon(Icons.restaurant_menu_rounded),
            label: 'Mess',
          ),
          const NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet_rounded),
            label: 'Finance',
          ),
        ],
      ),
    );
  }

  Widget _buildOrgLogo(String? logo) {
    if (logo != null && logo.trim().isNotEmpty) {
      try {
        final cleanBase64 = logo.contains(',') ? logo.split(',')[1] : logo;
        final bytes = base64Decode(cleanBase64);
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.memory(
            bytes,
            width: 36,
            height: 36,
            fit: BoxFit.cover,
            errorBuilder: (c, e, s) => _buildDefaultOrgLogo(),
          ),
        );
      } catch (_) {
        if (logo.startsWith('http')) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              logo,
              width: 36,
              height: 36,
              fit: BoxFit.cover,
              errorBuilder: (c, e, s) => _buildDefaultOrgLogo(),
            ),
          );
        }
      }
    }
    return _buildDefaultOrgLogo();
  }

  Widget _buildDefaultOrgLogo() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.accent],
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Icon(Icons.apartment, color: Colors.white, size: 18),
    );
  }

  Widget _buildAdminAvatar(String? photoUrl, String name) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.6), width: 2),
      ),
      child: AppAvatarImage(
        photoUrl: photoUrl,
        width: 44,
        height: 44,
        isCircle: true,
        fit: BoxFit.cover,
        fallback: _buildFallbackAdminAvatar(),
      ),
    );
  }

  Widget _buildFallbackAdminAvatar() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.accent],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Center(
        child: Icon(
          Icons.shield_rounded,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }
}
