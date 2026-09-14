import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/url_helper.dart';
import '../../models/mess_expense.dart';
import '../../providers/auth_provider.dart';
import '../../providers/mess_provider.dart';
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
                                          decoration: BoxDecoration(color: badge.bgColor, borderRadius: BorderRadius.circular(6)),
                                          child: Text(
                                            member.messStatusLabel.isNotEmpty ? member.messStatusLabel : badge.label,
                                            style: TextStyle(color: badge.textColor, fontWeight: FontWeight.bold, fontSize: 11),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        PopupMenuButton<String>(
                                          icon: const Icon(Icons.more_vert, size: 20),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          tooltip: 'Member Options',
                                          onSelected: (val) async {
                                            if (val == 'view') {
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
