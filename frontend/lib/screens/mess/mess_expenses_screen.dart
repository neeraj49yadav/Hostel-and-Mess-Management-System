import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/url_helper.dart';
import '../../models/mess_expense.dart';
import '../../models/student.dart';
import '../../providers/auth_provider.dart';
import '../../providers/mess_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../widgets/student_avatar.dart';
import '../../widgets/remove_student_dialog.dart';
import 'add_expense_screen.dart';
import 'add_mess_member_screen.dart';
import 'vendor_khata_screen.dart';
import '../finance/record_payment_screen.dart';
import '../hostel/student_detail_screen.dart';
import '../hostel/add_edit_student_screen.dart';

class MessExpensesScreen extends StatefulWidget {
  const MessExpensesScreen({super.key});

  @override
  State<MessExpensesScreen> createState() => _MessExpensesScreenState();
}

class _MessExpensesScreenState extends State<MessExpensesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MessProvider>().fetchMessMembers();
      context.read<MessProvider>().fetchExpenses();
      context.read<MessProvider>().fetchVendors();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _confirmDeleteExpense(MessExpense expense) {
    final mess = context.read<MessProvider>();
    final auth = context.read<AuthProvider>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense Entry?'),
        content: Text('Are you sure you want to delete "${expense.title}" of ${AppFormatters.formatCurrency(expense.amount)}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              Navigator.pop(ctx);
              await mess.deleteExpense(expense.id, auth.currentAdmin?.name ?? 'Admin');
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmRestoreMember(Student member) {
    final mess = context.read<MessProvider>();
    final auth = context.read<AuthProvider>();
    final dash = context.read<DashboardProvider>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: const Icon(Icons.settings_backup_restore_rounded, color: AppColors.success, size: 22),
            ),
            const SizedBox(width: 10),
            const Text('Restore Member?'),
          ],
        ),
        content: Text(
          'Do you want to restore "${member.name}" back to the active mess subscription list? Their mess cycle will restart from today.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await mess.restoreMessMember(member.id, auth.currentAdmin?.name ?? 'Admin');
              if (mounted) {
                if (ok) {
                  dash.fetchDashboardStats();
                  dash.fetchDuesAndExpiries();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ "${member.name}" restored to active mess successfully!'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(mess.error ?? 'Failed to restore member'),
                      backgroundColor: AppColors.danger,
                    ),
                  );
                }
              }
            },
            child: const Text('Restore Member'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mess = context.watch<MessProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mess Management Hub', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: isDark ? AppColors.secondaryLight : AppColors.secondary,
          unselectedLabelColor: isDark ? AppColors.textMutedDark : AppColors.textSecondaryLight,
          indicatorColor: isDark ? AppColors.secondaryLight : AppColors.secondary,
          indicatorWeight: 3,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Members'),
                  const SizedBox(width: 6),
                  Badge(label: Text('${mess.totalAllCount}'), backgroundColor: AppColors.secondary),
                ],
              ),
            ),
            const Tab(text: 'Grocery Cashbook'),
            const Tab(text: 'Vendors & Khata'),
          ],
        ),
      ),
      floatingActionButton: _buildFab(isDark),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: Mess Members (Hostelites + Outside Day Scholars)
          _buildMembersTab(mess, isDark),

          // TAB 2: Grocery Cashbook
          _buildCashbookTab(mess, isDark),

          // TAB 3: Vendors & Khata
          const VendorKhataScreen(),
        ],
      ),
    );
  }

  Widget? _buildFab(bool isDark) {
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, _) {
        if (_tabController.index == 0) {
          return FloatingActionButton.extended(
            backgroundColor: isDark ? AppColors.secondaryLight : AppColors.secondary,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('Add Member'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddMessMemberScreen()),
              );
            },
          );
        } else if (_tabController.index == 1) {
          return FloatingActionButton.extended(
            backgroundColor: isDark ? AppColors.primaryLight : AppColors.primary,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_shopping_cart_rounded),
            label: const Text('Add Grocery Expense'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
              );
            },
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  // --- TAB 1: MEMBERS VIEW ---
  Widget _buildMembersTab(MessProvider mess, bool isDark) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: isDark ? AppColors.surfaceDark : Colors.white,
          child: Column(
            children: [
              TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search mess subscribers by name, phone...',
                  prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchCtrl.clear();
                            mess.setMemberSearchQuery('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: isDark ? AppColors.surfaceDarkSecondary : AppColors.surfaceVariantLight,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
                onChanged: (val) => mess.setMemberSearchQuery(val),
              ),
              const SizedBox(height: 10),

              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildMemberTypeChip(mess, 'All Subscribers (${mess.totalAllCount})', 'ALL', isDark),
                    const SizedBox(width: 8),
                    _buildMemberTypeChip(mess, 'Outside Only (${mess.totalOutsideCount})', 'OUTSIDE_ONLY', isDark),
                    const SizedBox(width: 8),
                    _buildMemberTypeChip(mess, 'Hostelites (${mess.totalHostelCount})', 'HOSTEL_ONLY', isDark),
                    const SizedBox(width: 8),
                    _buildMemberTypeChip(mess, '🚫 Auto-Removed (${mess.removedCount})', 'REMOVED', isDark),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        Expanded(
          child: RefreshIndicator(
            onRefresh: () => mess.fetchMessMembers(),
            child: mess.messMembers.isEmpty
                ? Center(
                    child: Text(
                      'No mess members found',
                      style: TextStyle(color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: mess.messMembers.length,
                    separatorBuilder: (c, i) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final member = mess.messMembers[index];
                      final isOutside = member.isMessOnly;
                      final badge = AppFormatters.getStatusBadge(member.messDynamicStatus, isDark: isDark);

                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => StudentDetailScreen(studentId: member.id),
                              ),
                            );
                            if (context.mounted) {
                              context.read<MessProvider>().fetchMessMembers();
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          StudentAvatar(
                                            student: member,
                                            radius: 20,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  member.name,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                                  ),
                                                ),
                                                Text(
                                                  isOutside ? 'Outside Day Scholar' : 'Hostel Room ${member.roomNumber} (${member.bedNo})',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: isDark ? AppColors.textMutedDark : AppColors.textSecondaryLight,
                                                  ),
                                                ),
                                                if (member.mealPlanType.isNotEmpty) ...[
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    '🍽️ ${member.mealPlanType}',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: isDark ? AppColors.secondaryLight : AppColors.secondary,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: (member.isAutoRemoved || mess.memberTypeFilter == 'REMOVED')
                                                ? AppColors.danger.withValues(alpha: 0.15)
                                                : badge.bgColor,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            (member.isAutoRemoved || mess.memberTypeFilter == 'REMOVED')
                                                ? 'AUTO-REMOVED'
                                                : (member.messStatusLabel.isNotEmpty ? member.messStatusLabel : badge.label),
                                            style: TextStyle(
                                              color: (member.isAutoRemoved || mess.memberTypeFilter == 'REMOVED')
                                                  ? AppColors.danger
                                                  : badge.textColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        PopupMenuButton<String>(
                                          icon: const Icon(Icons.more_vert, size: 20),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          tooltip: 'Member Options',
                                          onSelected: (val) async {
                                            if (val == 'restore') {
                                              _confirmRestoreMember(member);
                                            } else if (val == 'view') {
                                              await Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => StudentDetailScreen(studentId: member.id),
                                                ),
                                              );
                                              if (context.mounted) {
                                                context.read<MessProvider>().fetchMessMembers();
                                              }
                                            } else if (val == 'edit') {
                                              if (isOutside) {
                                                await Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) => AddMessMemberScreen(memberToEdit: member),
                                                  ),
                                                );
                                              } else {
                                                await Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) => AddEditStudentScreen(studentToEdit: member),
                                                  ),
                                                );
                                              }
                                              if (context.mounted) {
                                                context.read<MessProvider>().fetchMessMembers();
                                              }
                                            } else if (val == 'remove') {
                                              showRemoveStudentDialog(
                                                context,
                                                student: member,
                                                defaultToMessOnly: true,
                                                onRemoved: () {
                                                  context.read<MessProvider>().fetchMessMembers();
                                                },
                                              );
                                            }
                                          },
                                          itemBuilder: (ctx) => [
                                            if (member.isAutoRemoved || mess.memberTypeFilter == 'REMOVED')
                                              const PopupMenuItem(
                                                value: 'restore',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.settings_backup_restore_rounded, color: AppColors.success, size: 18),
                                                    SizedBox(width: 8),
                                                    Text('Restore Member', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.success)),
                                                  ],
                                                ),
                                              ),
                                            const PopupMenuItem(
                                              value: 'view',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.account_circle_outlined, size: 18),
                                                  SizedBox(width: 8),
                                                  Text(
                                                    'View Profile & History',
                                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const PopupMenuItem(
                                              value: 'edit',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.edit_outlined, size: 18),
                                                  SizedBox(width: 8),
                                                  Text(
                                                    'Edit Profile',
                                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (!member.isAutoRemoved && mess.memberTypeFilter != 'REMOVED')
                                              PopupMenuItem(
                                                value: 'remove',
                                                child: Row(
                                                  children: [
                                                    const Icon(Icons.person_remove_outlined, color: AppColors.danger, size: 18),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      isOutside ? 'Remove from Mess' : 'Unenroll / Remove',
                                                      style: const TextStyle(color: AppColors.danger, fontSize: 13, fontWeight: FontWeight.w600),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                if (member.isAutoRemoved || mess.memberTypeFilter == 'REMOVED') ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: AppColors.danger.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 16),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            member.autoRemoveReason != null && member.autoRemoveReason!.isNotEmpty
                                                ? 'Removed: ${member.autoRemoveReason}'
                                                : 'Auto-Removed: Overdue >60 days without payment',
                                            style: const TextStyle(color: AppColors.danger, fontSize: 11, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const Divider(height: 16),

                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Plan: ${AppFormatters.formatCurrency(member.monthlyMessFee)} / month',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        color: isDark ? AppColors.textSecondaryDark : AppColors.textPrimaryLight,
                                      ),
                                    ),
                                    Text(
                                      'Valid till: ${AppFormatters.formatDate(member.messExpiryDate)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                if (member.isAutoRemoved || mess.memberTypeFilter == 'REMOVED') ...[
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      icon: const Icon(Icons.settings_backup_restore_rounded, size: 16),
                                      label: const Text('Restore Member to Active Mess', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.success,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      onPressed: () => _confirmRestoreMember(member),
                                    ),
                                  ),
                                ] else ...[
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          icon: const Icon(Icons.chat_bubble_outline, color: Color(0xFF25D366), size: 16),
                                          label: const Text('WhatsApp Reminder', style: TextStyle(fontSize: 12)),
                                          style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF25D366))),
                                          onPressed: () {
                                            final reminder = member.whatsappReminder;
                                            final message = reminder?['message'] ??
                                                'Hi ${member.name}, monthly Mess subscription renewal is due. Total: ₹${member.monthlyMessFee}.';
                                            UrlHelper.launchWhatsApp(phone: member.phone, message: message);
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          icon: const Icon(Icons.payment, size: 16),
                                          label: const Text('Renew Mess', style: TextStyle(fontSize: 12)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: isDark ? AppColors.secondaryLight : AppColors.secondary,
                                          ),
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => RecordPaymentScreen(
                                                  preSelectedStudent: member,
                                                  defaultFeeType: 'MESS',
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildMemberTypeChip(MessProvider mess, String label, String value, bool isDark) {
    final isSelected = mess.memberTypeFilter == value;
    final secColor = isDark ? AppColors.secondaryLight : AppColors.secondary;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: secColor.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? secColor : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
      ),
      onSelected: (_) => mess.setMemberTypeFilter(value),
    );
  }

  // --- TAB 2: GROCERY CASHBOOK ---
  Widget _buildCashbookTab(MessProvider mess, bool isDark) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF064E3B), const Color(0xFF0F766E)]
                  : [const Color(0xFF0F766E), const Color(0xFF0D9488)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0D9488).withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Kitchen Purchases', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(
                    AppFormatters.formatCurrency(mess.totalExpense),
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                child: const Icon(Icons.restaurant, color: Colors.white, size: 26),
              ),
            ],
          ),
        ),

        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _buildCategoryChip(mess, 'All Categories', '', isDark),
              const SizedBox(width: 8),
              _buildCategoryChip(mess, '🥛 Milk', 'MILK', isDark),
              const SizedBox(width: 8),
              _buildCategoryChip(mess, '🥬 Vegetables', 'VEGETABLES', isDark),
              const SizedBox(width: 8),
              _buildCategoryChip(mess, '🌾 Ration & Grains', 'RATION', isDark),
              const SizedBox(width: 8),
              _buildCategoryChip(mess, '🔥 Gas Cylinder', 'GAS', isDark),
              const SizedBox(width: 8),
              _buildCategoryChip(mess, '🧂 Spices & Oils', 'SPICES', isDark),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Divider(height: 1),

        Expanded(
          child: RefreshIndicator(
            onRefresh: () => mess.fetchExpenses(),
            child: mess.expenses.isEmpty
                ? Center(
                    child: Text(
                      'No grocery expenses recorded yet',
                      style: TextStyle(color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: mess.expenses.length,
                    separatorBuilder: (c, i) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final expense = mess.expenses[index];
                      final catColor = AppFormatters.getCategoryColor(expense.category);

                      return Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: catColor.withValues(alpha: isDark ? 0.25 : 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.shopping_bag_outlined, color: catColor, size: 22),
                          ),
                          title: Text(
                            expense.title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 2),
                              Text(
                                '${expense.category} • ${AppFormatters.formatDate(expense.date)} • ${expense.vendorName}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppColors.textMutedDark : AppColors.textSecondaryLight,
                                ),
                              ),
                              Text(
                                'By: ${expense.recordedByAdminName}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                                ),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                AppFormatters.formatCurrency(expense.amount),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: isDark ? AppColors.dangerLight : AppColors.danger,
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.delete_outline,
                                  color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                                  size: 20,
                                ),
                                onPressed: () => _confirmDeleteExpense(expense),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryChip(MessProvider mess, String label, String category, bool isDark) {
    final isSelected = mess.selectedCategory == category;
    final secColor = isDark ? AppColors.secondaryLight : AppColors.secondary;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: secColor.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? secColor : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
      ),
      onSelected: (_) => mess.setCategoryFilter(category),
    );
  }
}
