import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/url_helper.dart';
import '../../models/student.dart';
import '../../models/payment.dart';
import '../../providers/auth_provider.dart';
import '../../providers/hostel_provider.dart';
import '../../services/api_service.dart';
import '../../services/pdf_service.dart';
import '../../widgets/student_avatar.dart';
import '../../widgets/remove_student_dialog.dart';
import 'add_edit_student_screen.dart';
import '../mess/add_mess_member_screen.dart';
import '../finance/record_payment_screen.dart';

class StudentDetailScreen extends StatefulWidget {
  final String studentId;

  const StudentDetailScreen({super.key, required this.studentId});

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  final ApiService _api = ApiService();
  Student? _student;
  List<Payment> _payments = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStudentDetails();
  }

  Future<void> _loadStudentDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await _api.getStudentById(widget.studentId);
      final rawPayments = data['payments'] as List? ?? [];

      setState(() {
        _student = Student.fromJson(data);
        _payments = rawPayments.map((p) => Payment.fromJson(p)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception:', '').trim();
        _isLoading = false;
      });
    }
  }

  void _showShiftBedModal() {
    if (_student == null) return;
    final hostel = context.read<HostelProvider>();
    final auth = context.read<AuthProvider>();

    String? selectedRoomId = _student!.roomId;
    String selectedBedNo = 'A';

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
                  const Text('🔄 Shift Resident Bed', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    'Currently in Room ${_student!.roomNumber} (Bed ${_student!.bedNo})',
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    value: selectedRoomId,
                    decoration: const InputDecoration(labelText: 'Target Room'),
                    items: hostel.rooms.map((r) {
                      return DropdownMenuItem(
                        value: r.id,
                        child: Text('Room ${r.roomNumber} (Floor ${r.floor}) • ${r.vacantBeds} vacant'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setModalState(() => selectedRoomId = val);
                    },
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    value: selectedBedNo,
                    decoration: const InputDecoration(labelText: 'Target Bed'),
                    items: ['A', 'B', 'C', 'D'].map((b) => DropdownMenuItem(value: b, child: Text('Bed $b'))).toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedBedNo = val);
                    },
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (selectedRoomId == null) return;
                        Navigator.pop(ctx);
                        final success = await hostel.shiftBed(
                          _student!.id,
                          selectedRoomId!,
                          selectedBedNo,
                          auth.currentAdmin?.name ?? 'Admin',
                        );
                        if (success) {
                          _loadStudentDetails();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Bed shifted successfully!'), backgroundColor: AppColors.success),
                            );
                          }
                        }
                      },
                      child: const Text('Confirm Bed Shift'),
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

  void _showCheckoutDialog() {
    if (_student == null) return;
    showRemoveStudentDialog(
      context,
      student: _student!,
      onRemoved: () {
        if (mounted) Navigator.pop(context);
      },
    );
  }

  Future<void> _confirmDeletePayment(Payment p) async {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 28),
            SizedBox(width: 8),
            Text('Reverse Payment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to delete payment receipt #${p.receiptNo} of ${AppFormatters.formatCurrency(p.amount)}?',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.2)),
                ),
                child: const Text(
                  '⚠️ This will roll back the student\'s balance and recalculate validity. An immutable audit log entry will be created.',
                  style: TextStyle(fontSize: 12, color: AppColors.danger, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason for Reversal / Deletion *',
                  hintText: 'e.g. Wrong entry, student paid incorrect amount',
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Please enter a reason' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Reverse & Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final hostel = context.read<HostelProvider>();
      final auth = context.read<AuthProvider>();
      final adminName = auth.currentAdmin?.name ?? 'Admin';

      final success = await hostel.deletePayment(
        p.id,
        reason: reasonController.text.trim(),
        adminName: adminName,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Payment reversed successfully. Audit record created.'),
              backgroundColor: AppColors.success,
            ),
          );
          _loadStudentDetails();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(hostel.error ?? 'Failed to delete payment'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    }
  }

  String _paymentFilter = 'ALL';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_student == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Resident Details')),
        body: Center(child: Text(_error ?? 'Student not found')),
      );
    }

    final s = _student!;
    final messBadge = AppFormatters.getStatusBadge(s.messDynamicStatus, isDark: isDark);
    final rentBadge = AppFormatters.getStatusBadge(s.rentDynamicStatus, isDark: isDark);

    final filteredPayments = _payments.where((p) {
      if (_paymentFilter == 'RENT') {
        return p.feeType == 'RENT' || (p.rentAmount > 0 && p.messAmount == 0);
      } else if (_paymentFilter == 'MESS') {
        return p.feeType == 'MESS' || (p.messAmount > 0 && p.rentAmount == 0);
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Profile',
            onPressed: () async {
              if (s.isMessOnly) {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AddMessMemberScreen(memberToEdit: s)),
                );
              } else {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AddEditStudentScreen(studentToEdit: s)),
                );
              }
              _loadStudentDetails();
            },
          ),
          if (!s.isMessOnly)
            IconButton(
              icon: const Icon(Icons.swap_horiz_rounded),
              tooltip: 'Shift Bed',
              onPressed: _showShiftBedModal,
            ),
          IconButton(
            icon: const Icon(Icons.exit_to_app, color: AppColors.danger),
            tooltip: s.isMessOnly ? 'Remove Member' : 'Check-out Resident',
            onPressed: _showCheckoutDialog,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadStudentDetails,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Profile Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        StudentAvatar(
                          student: s,
                          radius: 32,
                          showBedBadge: true,
                          enablePreview: true,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.name,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  Text(
                                    s.isMessOnly
                                        ? 'Outside Day Scholar'
                                        : 'Room ${s.roomNumber} • Bed ${s.bedNo}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isDark ? AppColors.textMutedDark : AppColors.textSecondaryLight,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: s.enrolledInMess
                                          ? (isDark ? const Color(0xFF064E3B).withValues(alpha: 0.6) : const Color(0xFFD1FAE5))
                                          : (isDark ? AppColors.surfaceVariantDark : const Color(0xFFF3F4F6)),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      s.enrolledInMess ? '🍽️ Mess Enrolled' : 'Hostel Only',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: s.enrolledInMess
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
                    const Divider(height: 24),

                    _buildInfoRow(Icons.phone_outlined, 'Phone', s.phone, isDark, isPhone: true),
                    if (s.parentPhone.isNotEmpty)
                      _buildInfoRow(Icons.family_restroom_outlined, 'Parent (${s.parentName})', s.parentPhone, isDark, isPhone: true),
                    _buildInfoRow(Icons.calendar_today_outlined, s.isMessOnly ? 'Joining Date' : 'Hostel Admission Date', AppFormatters.formatDate(s.admissionDate), isDark),
                    if (s.enrolledInMess && s.messStartDate != null && s.messStartDate!.isNotEmpty)
                      _buildInfoRow(Icons.restaurant_outlined, 'Mess Joining Date', AppFormatters.formatDate(s.messStartDate!), isDark),
                    if (s.notes.isNotEmpty)
                      _buildInfoRow(Icons.notes_outlined, 'Notes / Course', s.notes, isDark),

                    const SizedBox(height: 16),

                    // Financial Overview & Ledger Container
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceDarkSecondary : AppColors.surfaceVariantLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Hostel Rent Ledger
                          if (s.isHostelResident) ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('🏨', style: TextStyle(fontSize: 18)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Hostel Rent Ledger (${s.rentTermMonths}mo Term)',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: rentBadge.bgColor,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              s.rentStatusLabel,
                                              style: TextStyle(color: rentBadge.textColor, fontWeight: FontWeight.bold, fontSize: 11),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Total Agreed Rent: ${AppFormatters.formatCurrency(s.totalRentAgreed)}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                            ),
                                          ),
                                          Text(
                                            'Paid: ${AppFormatters.formatCurrency(s.totalRentPaid)}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.success,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            s.rentBalanceDue > 0
                                                ? 'Remaining Due: ${AppFormatters.formatCurrency(s.rentBalanceDue)}'
                                                : 'Remaining Due: ₹0 (Fully Paid)',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: s.rentBalanceDue > 0 ? AppColors.danger : AppColors.success,
                                            ),
                                          ),
                                          Text(
                                            'Till: ${AppFormatters.formatDate(s.rentExpiryDate)}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 16),
                          ],

                          // 2. Monthly Mess Plan
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('🍽️', style: TextStyle(fontSize: 18)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Monthly Mess Subscription',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                          ),
                                        ),
                                        if (s.enrolledInMess)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: messBadge.bgColor,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              s.messStatusLabel,
                                              style: TextStyle(color: messBadge.textColor, fontWeight: FontWeight.bold, fontSize: 11),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    if (s.enrolledInMess) ...[
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '${AppFormatters.formatCurrency(s.monthlyMessFee)} / month',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                            ),
                                          ),
                                          Text(
                                            'Total Paid: ${AppFormatters.formatCurrency(s.totalMessPaid)}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.success,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            s.messBalanceDue > 0
                                                ? 'Mess Due: ${AppFormatters.formatCurrency(s.messBalanceDue)}'
                                                : 'Mess Dues: ₹0 (Current)',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: s.messBalanceDue > 0 ? AppColors.danger : AppColors.success,
                                            ),
                                          ),
                                          Text(
                                            'Valid Till: ${AppFormatters.formatDate(s.messExpiryDate)}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ] else ...[
                                      Text(
                                        'Not Enrolled in Mess (Self-managed meals)',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontStyle: FontStyle.italic,
                                          color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Quick Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.chat_bubble_outline, size: 16),
                            label: const Text('WhatsApp'),
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
                            onPressed: () {
                              final reminder = s.whatsappReminder;
                              final message = reminder?['message'] ??
                                  'Hi ${s.name}, regarding your Hostel & Mess payment status.';
                              UrlHelper.launchWhatsApp(phone: s.phone, message: message);
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.receipt_long_rounded, size: 16),
                            label: const Text('Collect Fee'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark ? AppColors.primaryLight : AppColors.primary,
                            ),
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => RecordPaymentScreen(preSelectedStudent: s)),
                              );
                              _loadStudentDetails();
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Fee History Header & Filters
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '💳 Payment History',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
                Text(
                  '${_payments.length} Records',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildPaymentFilterChip('All (${_payments.length})', 'ALL', isDark),
                  const SizedBox(width: 8),
                  _buildPaymentFilterChip(
                    '🏨 Hostel Rent (${_payments.where((p) => p.feeType == 'RENT' || p.rentAmount > 0).length})',
                    'RENT',
                    isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildPaymentFilterChip(
                    '🍽️ Mess Fee (${_payments.where((p) => p.feeType == 'MESS' || p.messAmount > 0).length})',
                    'MESS',
                    isDark,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            if (filteredPayments.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 48, color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
                      const SizedBox(height: 8),
                      Text(
                        _payments.isEmpty
                            ? 'No payment records logged yet'
                            : 'No payment records matching the selected filter',
                        style: TextStyle(color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredPayments.length,
                separatorBuilder: (c, i) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final p = filteredPayments[index];
                  final primColor = isDark ? AppColors.primaryLight : AppColors.primary;
                  final isRent = p.feeType == 'RENT' || (p.rentAmount > 0 && p.messAmount == 0);
                  final isMess = p.feeType == 'MESS' || (p.messAmount > 0 && p.rentAmount == 0);

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text(isRent ? '🏨' : (isMess ? '🍽️' : '💳'), style: const TextStyle(fontSize: 16)),
                                  const SizedBox(width: 6),
                                  Text(
                                    p.receiptNo,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Text(
                                    AppFormatters.formatCurrency(p.amount),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: isDark ? AppColors.primaryLight : AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  IconButton(
                                    icon: Icon(Icons.picture_as_pdf_rounded, color: primColor, size: 20),
                                    tooltip: 'View & Share Receipt PDF',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => PdfService.printReceipt(
                                      p,
                                      hostelName: context.read<AuthProvider>().currentOrganization?.name,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 20),
                                    tooltip: 'Reverse & Delete Payment',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => _confirmDeletePayment(p),
                                  ),
                                ],
                              ),
                             ],
                           ),
                           const Divider(height: 12),

                           Row(
                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
                             children: [
                               Expanded(
                                 child: Text(
                                   isRent
                                       ? 'Hostel Room Rent'
                                       : (isMess ? 'Monthly Mess Fee' : 'Combined (Rent: ₹${p.rentAmount} | Mess: ₹${p.messAmount})'),
                                   style: TextStyle(
                                     fontSize: 12,
                                     fontWeight: FontWeight.w600,
                                     color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                   ),
                                   overflow: TextOverflow.ellipsis,
                                 ),
                               ),
                               const SizedBox(width: 8),
                               Container(
                                 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                 decoration: BoxDecoration(
                                   color: (isDark ? AppColors.surfaceVariantDark : const Color(0xFFF3F4F6)),
                                   borderRadius: BorderRadius.circular(4),
                                 ),
                                 child: Text(
                                   p.paymentMode,
                                   style: TextStyle(
                                     fontSize: 10,
                                     fontWeight: FontWeight.bold,
                                     color: isDark ? AppColors.textMutedDark : AppColors.textSecondaryLight,
                                   ),
                                 ),
                               ),
                             ],
                           ),
                           const SizedBox(height: 6),

                           // Payment Date
                           Row(
                             children: [
                               Icon(Icons.calendar_today_rounded, size: 12, color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
                               const SizedBox(width: 5),
                               Text(
                                 'Date: ${AppFormatters.formatDate(p.paymentDate)}',
                                 style: TextStyle(
                                   fontSize: 11,
                                   fontWeight: FontWeight.w500,
                                   color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                                 ),
                               ),
                             ],
                           ),

                            if (p.targetMonth.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.event_note_outlined, size: 12, color: primColor),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Billing Month: ${p.targetMonth}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: primColor,
                                    ),
                                  ),
                                ],
                              ),
                            ],

                           // Description & Period Notes (Full-width wrapping so it never clips)
                           if (p.cycleEndDate.isNotEmpty) ...[
                             const SizedBox(height: 4),
                             Row(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 Icon(Icons.info_outline_rounded, size: 12, color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
                                 const SizedBox(width: 5),
                                 Expanded(
                                   child: Text(
                                     p.cycleEndDate,
                                     style: TextStyle(
                                       fontSize: 11,
                                       height: 1.3,
                                       color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                                     ),
                                   ),
                                 ),
                               ],
                             ),
                           ],

                           if (p.notes.isNotEmpty || p.collectedByAdminName.isNotEmpty) ...[
                             const SizedBox(height: 4),
                             Text(
                               '${p.collectedByAdminName.isNotEmpty ? 'Collected by: ${p.collectedByAdminName}' : ''}${p.notes.isNotEmpty ? ' • Note: ${p.notes}' : ''}',
                               style: TextStyle(
                                 fontSize: 11,
                                 fontStyle: FontStyle.italic,
                                 color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                               ),
                             ),
                           ],
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentFilterChip(String label, String value, bool isDark) {
    final isSelected = _paymentFilter == value;
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
      onSelected: (_) => setState(() => _paymentFilter = value),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, bool isDark, {bool isPhone = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.textMutedDark : AppColors.textSecondaryLight,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
            ),
          ),
          if (isPhone)
            InkWell(
              onTap: () => UrlHelper.launchPhoneCall(value),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.call,
                  size: 16,
                  color: isDark ? AppColors.primaryLight : AppColors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
