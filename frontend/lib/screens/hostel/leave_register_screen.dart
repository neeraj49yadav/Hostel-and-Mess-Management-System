import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../providers/auth_provider.dart';
import '../../providers/hostel_provider.dart';

class LeaveRegisterScreen extends StatefulWidget {
  const LeaveRegisterScreen({super.key});

  @override
  State<LeaveRegisterScreen> createState() => _LeaveRegisterScreenState();
}

class _LeaveRegisterScreenState extends State<LeaveRegisterScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HostelProvider>().fetchLeaveLogs();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showNewDepartureDialog() {
    final hostel = context.read<HostelProvider>();
    final auth = context.read<AuthProvider>();

    final currentlyOutIds = hostel.leaveLogs
        .where((l) => l.status == 'OUT')
        .map((l) => l.studentId)
        .toSet();

    final eligibleStudents = hostel.students
        .where((s) => s.isHostelResident && !currentlyOutIds.contains(s.id))
        .toList();

    String? selectedStudentId;
    String selectedLeaveType = 'HOME_VISIT';
    final reasonCtrl = TextEditingController();
    DateTime expectedReturn = DateTime.now().add(const Duration(days: 2));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 20,
                left: 20,
                right: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('🚪 Log Student Departure (Going Out)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),

                  if (eligibleStudents.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.amber, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'All active hostel residents are already logged as OUT.',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    DropdownButtonFormField<String>(
                      value: selectedStudentId,
                      hint: const Text('Choose student to log departure...'),
                      decoration: const InputDecoration(
                        labelText: 'Select Student *',
                        prefixIcon: Icon(Icons.person_search_outlined),
                      ),
                      items: eligibleStudents.map((s) {
                        return DropdownMenuItem(value: s.id, child: Text('${s.name} (Room ${s.roomNumber})'));
                      }).toList(),
                      onChanged: (val) => setModalState(() => selectedStudentId = val),
                    ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    value: selectedLeaveType,
                    decoration: const InputDecoration(labelText: 'Leave Type'),
                    items: const [
                      DropdownMenuItem(value: 'HOME_VISIT', child: Text('Home Visit')),
                      DropdownMenuItem(value: 'NIGHT_OUT', child: Text('Night Outing')),
                      DropdownMenuItem(value: 'EMERGENCY', child: Text('Emergency')),
                      DropdownMenuItem(value: 'MARKET', child: Text('Day Outing / Market')),
                    ],
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedLeaveType = val);
                    },
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: reasonCtrl,
                    decoration: const InputDecoration(labelText: 'Reason for Departure', hintText: 'Wedding / Vacation / College Work'),
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (selectedStudentId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please select a student first'), backgroundColor: AppColors.danger),
                          );
                          return;
                        }
                        final messenger = ScaffoldMessenger.of(context);
                        Navigator.pop(ctx);
                        final success = await hostel.recordDeparture({
                          'studentId': selectedStudentId,
                          'leaveType': selectedLeaveType,
                          'reason': reasonCtrl.text.trim(),
                          'expectedReturnDate': expectedReturn.toIso8601String(),
                          'adminName': auth.currentAdmin?.name ?? 'Admin',
                        });
                        if (success && mounted) {
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Departure logged!'), backgroundColor: AppColors.success),
                          );
                        }
                      },
                      child: const Text('Confirm Departure Entry'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hostel = context.watch<HostelProvider>();
    final auth = context.read<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final currentlyOut = hostel.leaveLogs.where((l) => l.status == 'OUT').toList();
    final history = hostel.leaveLogs.where((l) => l.status == 'RETURNED').toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('In/Out Leave Register', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: isDark ? AppColors.primaryLight : AppColors.primary,
          unselectedLabelColor: isDark ? AppColors.textMutedDark : AppColors.textSecondaryLight,
          indicatorColor: isDark ? AppColors.primaryLight : AppColors.primary,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Currently OUT'),
                  const SizedBox(width: 6),
                  Badge(label: Text('${currentlyOut.length}'), backgroundColor: AppColors.warning),
                ],
              ),
            ),
            const Tab(text: 'Return History'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: isDark ? AppColors.primaryLight : AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.exit_to_app),
        label: const Text('Log Departure'),
        onPressed: _showNewDepartureDialog,
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Currently Out List
          RefreshIndicator(
            onRefresh: () => hostel.fetchLeaveLogs(),
            child: currentlyOut.isEmpty
                ? Center(
                    child: Text(
                      'All residents are currently inside the hostel!',
                      style: TextStyle(color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: currentlyOut.length,
                    separatorBuilder: (c, i) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final log = currentlyOut[index];
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    log.studentName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF78350F).withValues(alpha: 0.6)
                                          : const Color(0xFFFEF3C7),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      log.leaveType,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? const Color(0xFFFBBF24) : const Color(0xFF92400E),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Room ${log.roomNumber}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? AppColors.textMutedDark : AppColors.textSecondaryLight,
                                ),
                              ),
                              const Divider(height: 16),

                              Text(
                                'Departed: ${AppFormatters.formatDateTime(log.departureDate)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppColors.textSecondaryDark : AppColors.textPrimaryLight,
                                ),
                              ),
                              Text(
                                'Reason: ${log.reason.isNotEmpty ? log.reason : "Personal"}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                                ),
                              ),
                              const SizedBox(height: 12),

                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.check_circle_outline, size: 16),
                                  label: const Text('Mark Checked-In (Returned)'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isDark ? AppColors.successLight : AppColors.success,
                                    foregroundColor: isDark ? Colors.black : Colors.white,
                                  ),
                                  onPressed: () async {
                                    final success = await hostel.recordReturn(log.id, auth.currentAdmin?.name ?? 'Admin');
                                    if (success && context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Resident marked returned!'), backgroundColor: AppColors.success),
                                      );
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Return History List
          RefreshIndicator(
            onRefresh: () => hostel.fetchLeaveLogs(),
            child: history.isEmpty
                ? Center(
                    child: Text(
                      'No historical logs yet',
                      style: TextStyle(color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: history.length,
                    separatorBuilder: (c, i) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final log = history[index];
                      return Card(
                        child: ListTile(
                          title: Text(
                            '${log.studentName} (Room ${log.roomNumber})',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                            ),
                          ),
                          subtitle: Text(
                            'Out: ${AppFormatters.formatDateTime(log.departureDate)}\nBack: ${AppFormatters.formatDateTime(log.actualReturnDate)}',
                            style: TextStyle(
                              color: isDark ? AppColors.textMutedDark : AppColors.textSecondaryLight,
                            ),
                          ),
                          trailing: Icon(Icons.check_circle, color: isDark ? AppColors.successLight : AppColors.success),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
