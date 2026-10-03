import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/url_helper.dart';
import '../../models/student.dart';
import '../../providers/dashboard_provider.dart';
import '../../widgets/student_avatar.dart';
import '../finance/record_payment_screen.dart';

class DuesExpiryScreen extends StatefulWidget {
  const DuesExpiryScreen({super.key});

  @override
  State<DuesExpiryScreen> createState() => _DuesExpiryScreenState();
}

class _DuesExpiryScreenState extends State<DuesExpiryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _messSubFilter = 'ALL'; // 'ALL', 'OVERDUE', 'UPCOMING'
  final TextEditingController _messSearchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().fetchDuesAndExpiries();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messSearchCtrl.dispose();
    super.dispose();
  }

  void _sendWhatsAppReminder(Student student, String feeType) async {
    final reminder = student.whatsappReminder;
    final message = reminder?['message'] ??
        'Dear ${student.name} (Room ${student.roomNumber}), this is a reminder regarding your pending ${feeType == "MESS" ? "Monthly Mess" : "Hostel Rent"} dues.';
    final phone = student.phone.isNotEmpty ? student.phone : student.parentPhone;

    final launched = await UrlHelper.launchWhatsApp(phone: phone, message: message);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not launch WhatsApp for $phone'), backgroundColor: AppColors.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dash = context.watch<DashboardProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final totalMessAlerts = dash.messExpiringSoon.length + dash.messOverdue.length;
    final totalRentAlerts = dash.rentExpiringSoon.length + dash.rentOverdue.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dues & Expiry Tracker', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: isDark ? AppColors.primaryLight : AppColors.primary,
          unselectedLabelColor: isDark ? AppColors.textMutedDark : AppColors.textSecondaryLight,
          indicatorColor: isDark ? AppColors.primaryLight : AppColors.primary,
          indicatorWeight: 3,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Mess (Monthly)'),
                  const SizedBox(width: 4),
                  Badge(label: Text('$totalMessAlerts'), backgroundColor: AppColors.warning),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Rent (2-3x / Yr)'),
                  const SizedBox(width: 4),
                  Badge(label: Text('$totalRentAlerts'), backgroundColor: AppColors.danger),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('All Active'),
                  const SizedBox(width: 4),
                  Badge(label: Text('${dash.active.length}'), backgroundColor: AppColors.success),
                ],
              ),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<DashboardProvider>().fetchDuesAndExpiries(),
        child: TabBarView(
          controller: _tabController,
          children: [
            // Tab 1: Mess Monthly Alerts with Search & Overdue / Upcoming separation
            _buildMessTab(dash, isDark),

            // Tab 2: Hostel Rent (Semester / Termly) Alerts
            _buildDuesList(
              items: [...dash.rentOverdue, ...dash.rentExpiringSoon],
              type: 'RENT',
              emptyMessage: 'All hostel rent installments are up to date!',
              isDark: isDark,
            ),

            // Tab 3: All Active
            _buildDuesList(
              items: dash.active,
              type: 'ALL',
              emptyMessage: 'No students found.',
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  // 🍽️ Dedicated Mess Tab with Search and Overdue/Upcoming Separation (Req 6 & 7)
  Widget _buildMessTab(DashboardProvider dash, bool isDark) {
    List<Student> baseList;
    if (_messSubFilter == 'OVERDUE') {
      baseList = dash.messOverdue;
    } else if (_messSubFilter == 'UPCOMING') {
      baseList = dash.messExpiringSoon;
    } else {
      baseList = [...dash.messOverdue, ...dash.messExpiringSoon];
    }

    final q = _messSearchCtrl.text.trim().toLowerCase();
    final filtered = q.isEmpty
        ? baseList
        : baseList.where((s) {
            return s.name.toLowerCase().contains(q) ||
                s.phone.contains(q) ||
                s.roomNumber.toLowerCase().contains(q) ||
                s.mealPlanType.toLowerCase().contains(q);
          }).toList();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: isDark ? AppColors.surfaceDark : Colors.white,
          child: Column(
            children: [
              TextField(
                controller: _messSearchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search mess dues by name, phone, room...',
                  prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                  suffixIcon: _messSearchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _messSearchCtrl.clear();
                            });
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: isDark ? AppColors.surfaceDarkSecondary : AppColors.surfaceVariantLight,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      label: Text('All Alerts (${dash.messOverdue.length + dash.messExpiringSoon.length})'),
                      selected: _messSubFilter == 'ALL',
                      selectedColor: AppColors.secondary.withValues(alpha: 0.25),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: _messSubFilter == 'ALL' ? FontWeight.bold : FontWeight.normal,
                        color: _messSubFilter == 'ALL' ? AppColors.secondary : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                      ),
                      onSelected: (_) => setState(() => _messSubFilter = 'ALL'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text('🔴 Overdue / Current Due (${dash.messOverdue.length})'),
                      selected: _messSubFilter == 'OVERDUE',
                      selectedColor: AppColors.danger.withValues(alpha: 0.2),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: _messSubFilter == 'OVERDUE' ? FontWeight.bold : FontWeight.normal,
                        color: _messSubFilter == 'OVERDUE' ? AppColors.danger : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                      ),
                      onSelected: (_) => setState(() => _messSubFilter = 'OVERDUE'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text('🟡 Upcoming Dues (${dash.messExpiringSoon.length})'),
                      selected: _messSubFilter == 'UPCOMING',
                      selectedColor: Colors.amber.withValues(alpha: 0.2),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: _messSubFilter == 'UPCOMING' ? FontWeight.bold : FontWeight.normal,
                        color: _messSubFilter == 'UPCOMING' ? Colors.orange.shade800 : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                      ),
                      onSelected: (_) => setState(() => _messSubFilter = 'UPCOMING'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _buildDuesList(
            items: filtered,
            type: 'MESS',
            emptyMessage: _messSubFilter == 'OVERDUE'
                ? 'No overdue mess subscriptions! All clear.'
                : (_messSubFilter == 'UPCOMING'
                    ? 'No upcoming mess renewals in the next 5 days.'
                    : 'All monthly mess subscriptions are currently active!'),
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildDuesList({
    required List<Student> items,
    required String type,
    required String emptyMessage,
    required bool isDark,
  }) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_outline, size: 64, color: AppColors.success.withValues(alpha: 0.6)),
              const SizedBox(height: 16),
              Text(
                emptyMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? AppColors.textMutedDark : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (c, i) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final student = items[index];
        final isMessType = type == 'MESS';
        final isRentType = type == 'RENT';

        final dynamicStatus = isMessType
            ? student.messDynamicStatus
            : (isRentType ? student.rentDynamicStatus : student.dynamicStatus);

        final badge = AppFormatters.getStatusBadge(dynamicStatus, isDark: isDark);

        return Card(
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
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                  ),
                                ),
                                Text(
                                  student.isMessOnly
                                      ? 'Outside Day Scholar'
                                      : 'Room ${student.roomNumber} • Bed ${student.bedNo}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? AppColors.textMutedDark : AppColors.textSecondaryLight,
                                  ),
                                ),
                                if (isMessType && student.mealPlanType.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    '🍽️ ${student.mealPlanType}',
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
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: badge.bgColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isMessType ? student.messStatusLabel : (isRentType ? student.rentStatusLabel : badge.label),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: badge.textColor),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),

                // Breakdown Row
                Row(
                  children: [
                    if (student.enrolledInMess)
                      Expanded(
                        child: _buildFeeColumn(
                          'Monthly Mess Plan',
                          '${AppFormatters.formatCurrency(student.monthlyMessFee)} / mo',
                          'Valid till: ${AppFormatters.formatDate(student.messExpiryDate)}',
                          isHighlight: isMessType,
                          isDark: isDark,
                        ),
                      ),
                    if (student.enrolledInMess && student.isHostelResident)
                      const SizedBox(width: 8),
                    if (student.isHostelResident)
                      Expanded(
                        child: _buildFeeColumn(
                          'Hostel Rent (${student.rentTermMonths}mo Term)',
                          student.rentBalanceDue > 0
                              ? '${AppFormatters.formatCurrency(student.rentBalanceDue)} due'
                              : 'Paid (${AppFormatters.formatCurrency(student.totalRentPaid)})',
                          'Agreed: ${AppFormatters.formatCurrency(student.totalRentAgreed)} • Till: ${AppFormatters.formatDate(student.rentExpiryDate)}',
                          isHighlight: isRentType,
                          isDark: isDark,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.chat_bubble_outline, color: Color(0xFF25D366), size: 16),
                        label: const Text('WhatsApp Reminder', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          side: const BorderSide(color: Color(0xFF25D366)),
                        ),
                        onPressed: () => _sendWhatsAppReminder(student, type),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.payment, size: 16),
                        label: Text(
                          isMessType ? 'Renew Mess' : (isRentType ? 'Collect Rent' : 'Collect Fee'),
                          style: const TextStyle(fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? AppColors.primaryLight : AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RecordPaymentScreen(
                                preSelectedStudent: student,
                                defaultFeeType: isMessType ? 'MESS' : (isRentType ? 'RENT' : 'BOTH'),
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
        );
      },
    );
  }

  Widget _buildFeeColumn(
    String title,
    String value,
    String validity, {
    bool isHighlight = false,
    required bool isDark,
  }) {
    final highlightColor = isDark ? AppColors.primaryLight : AppColors.primary;
    final primaryTextColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final mutedTextColor = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            color: isHighlight ? highlightColor : mutedTextColor,
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isHighlight ? highlightColor : primaryTextColor,
          ),
        ),
        const SizedBox(height: 1),
        Text(validity, style: TextStyle(fontSize: 10, color: mutedTextColor)),
      ],
    );
  }
}
