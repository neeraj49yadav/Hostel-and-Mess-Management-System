import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/url_helper.dart';
import '../../models/student.dart';
import '../../providers/hostel_provider.dart';
import '../../widgets/student_avatar.dart';
import '../../widgets/remove_student_dialog.dart';
import 'add_edit_student_screen.dart';
import 'student_detail_screen.dart';

class StudentListScreen extends StatefulWidget {
  const StudentListScreen({super.key});

  @override
  State<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends State<StudentListScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HostelProvider>().fetchStudents();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hostel = context.watch<HostelProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final residents = hostel.students.where((s) => s.isHostelResident).toList();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Hostel Residents', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Badge(
              label: Text('${residents.length}'),
              backgroundColor: isDark ? AppColors.primaryLight : AppColors.primary,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: isDark ? AppColors.primaryLight : AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Add Resident'),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddEditStudentScreen()),
          );
        },
      ),
      body: Column(
        children: [
          // Search & Filter Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: isDark ? AppColors.surfaceDark : Colors.white,
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name, room, phone...',
                    prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              hostel.setSearchQuery('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: isDark ? AppColors.surfaceDarkSecondary : AppColors.surfaceVariantLight,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  onChanged: (val) => hostel.setSearchQuery(val),
                ),
                const SizedBox(height: 10),

                // Status Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip(hostel, 'All', '', isDark),
                      const SizedBox(width: 8),
                      _buildFilterChip(hostel, 'Active', 'ACTIVE', isDark),
                      const SizedBox(width: 8),
                      _buildFilterChip(hostel, 'Expiring (5d)', 'EXPIRING_SOON', isDark),
                      const SizedBox(width: 8),
                      _buildFilterChip(hostel, 'Overdue', 'EXPIRED', isDark),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Student List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => hostel.fetchStudents(),
              child: Builder(
                builder: (context) {
                  if (hostel.isLoading && residents.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (residents.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.people_outline, size: 64, color: AppColors.textMuted),
                          const SizedBox(height: 12),
                          Text(
                            'No hostel residents found',
                            style: TextStyle(
                              color: isDark ? AppColors.textMutedDark : AppColors.textSecondaryLight,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const AddEditStudentScreen()),
                              );
                            },
                            child: const Text('Add First Resident'),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: residents.length,
                    separatorBuilder: (c, i) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final student = residents[index];
                      return _buildStudentCard(student, isDark);
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(HostelProvider hostel, String label, String value, bool isDark) {
    final isSelected = hostel.statusFilter == value;
    final primaryColor = isDark ? AppColors.primaryLight : AppColors.primary;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: primaryColor.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected
            ? primaryColor
            : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
      ),
      onSelected: (_) => hostel.setStatusFilter(value),
    );
  }

  Widget _buildStudentCard(Student student, bool isDark) {
    final badge = AppFormatters.getStatusBadge(student.dynamicStatus, isDark: isDark);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StudentDetailScreen(studentId: student.id),
            ),
          );
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
                          student: student,
                          radius: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                student.name,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 6,
                                runSpacing: 3,
                                children: [
                                  Text(
                                    'Room ${student.roomNumber} (Bed ${student.bedNo})',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? AppColors.textMutedDark : AppColors.textSecondaryLight,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: student.enrolledInMess
                                          ? (isDark
                                              ? const Color(0xFF064E3B).withValues(alpha: 0.6)
                                              : const Color(0xFFD1FAE5))
                                          : (isDark
                                              ? AppColors.surfaceVariantDark
                                              : const Color(0xFFF3F4F6)),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      student.enrolledInMess ? '🍽️ Mess Enrolled' : 'Hostel Only',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: student.enrolledInMess
                                            ? (isDark ? const Color(0xFF34D399) : const Color(0xFF065F46))
                                            : (isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
                                      ),
                                    ),
                                  ),
                                ],
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
                        decoration: BoxDecoration(
                          color: badge.bgColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badge.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: badge.textColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Resident Options',
                        onSelected: (val) {
                          if (val == 'remove') {
                            showRemoveStudentDialog(
                              context,
                              student: student,
                              onRemoved: () {
                                context.read<HostelProvider>().fetchStudents();
                              },
                            );
                          } else if (val == 'edit') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => AddEditStudentScreen(studentToEdit: student)),
                            );
                          }
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit_outlined, size: 18),
                                SizedBox(width: 8),
                                Text('Edit Profile', style: TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'remove',
                            child: Row(
                              children: [
                                Icon(Icons.person_remove_outlined, color: AppColors.danger, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'Check-out / Remove',
                                  style: TextStyle(color: AppColors.danger, fontSize: 13, fontWeight: FontWeight.w600),
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
              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Mess: ${AppFormatters.formatCurrency(student.monthlyMessFee)}/mo',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textPrimaryLight,
                    ),
                  ),
                  Text(
                    'Rent: ${student.rentBalanceDue > 0 ? '${AppFormatters.formatCurrency(student.rentBalanceDue)} due' : 'Paid (${AppFormatters.formatCurrency(student.totalRentPaid)})'}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textPrimaryLight,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Mess till: ${AppFormatters.formatDate(student.messExpiryDate)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                    ),
                  ),
                  Text(
                    'Rent till: ${AppFormatters.formatDate(student.rentExpiryDate)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.phone_outlined,
                      color: isDark ? AppColors.primaryLight : AppColors.primary,
                      size: 20,
                    ),
                    tooltip: 'Call Student',
                    onPressed: () => UrlHelper.launchPhoneCall(student.phone),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chat_bubble_outline, color: Color(0xFF25D366), size: 20),
                    tooltip: 'WhatsApp Reminder',
                    onPressed: () async {
                      final reminder = student.whatsappReminder;
                      final message = reminder?['message'] ??
                          'Hi ${student.name}, monthly Hostel & Mess plan is due. Total: ₹${student.totalMonthlyFee}.';
                      await UrlHelper.launchWhatsApp(phone: student.phone, message: message);
                    },
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
