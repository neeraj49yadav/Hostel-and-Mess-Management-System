import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/student_search_helper.dart';
import '../../core/utils/url_helper.dart';
import '../../models/student.dart';
import '../../models/payment.dart';
import '../../providers/auth_provider.dart';
import '../../providers/hostel_provider.dart';
import '../../providers/mess_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../widgets/student_avatar.dart';

class RecordPaymentScreen extends StatefulWidget {
  final Student? preSelectedStudent;
  final String? defaultFeeType; // 'MESS', 'RENT', 'BOTH'

  const RecordPaymentScreen({super.key, this.preSelectedStudent, this.defaultFeeType});

  @override
  State<RecordPaymentScreen> createState() => _RecordPaymentScreenState();
}

class _RecordPaymentScreenState extends State<RecordPaymentScreen> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedStudentId;
  Student? _currentStudent;

  String _feeType = 'MESS'; // Default to MESS or RENT or BOTH
  String _paymentMode = 'UPI';

  late String _targetMonth;
  late final List<String> _monthOptions;

  final _rentAmountCtrl = TextEditingController();
  final _messAmountCtrl = TextEditingController();
  final _totalAmountCtrl = TextEditingController();
  final _txnRefCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  final int _messMonthsToAdd = 1;
  int _rentMonthsToAdd = 6; // Default to 6-months Semester (2x a year)
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    const monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    _monthOptions = [];
    for (int offset = -6; offset <= 6; offset++) {
      final d = DateTime(now.year, now.month + offset, 1);
      _monthOptions.add('${monthNames[d.month - 1]} ${d.year}');
    }
    _targetMonth = '${monthNames[now.month - 1]} ${now.year}';

    if (widget.preSelectedStudent != null) {
      _selectedStudentId = widget.preSelectedStudent!.id;
      _currentStudent = widget.preSelectedStudent;
      _rentMonthsToAdd = widget.preSelectedStudent!.rentTermMonths;
      if (widget.preSelectedStudent!.isMessOnly || !widget.preSelectedStudent!.isHostelResident) {
        _feeType = 'MESS';
      } else if (!widget.preSelectedStudent!.enrolledInMess) {
        _feeType = 'RENT';
      } else if (widget.defaultFeeType != null) {
        _feeType = widget.defaultFeeType!;
      }
      _updateFeeFields(widget.preSelectedStudent!);
    } else if (widget.defaultFeeType != null) {
      _feeType = widget.defaultFeeType!;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final hostel = context.read<HostelProvider>();
      final mess = context.read<MessProvider>();
      if (hostel.students.isEmpty) hostel.fetchStudents();
      if (mess.messMembers.isEmpty) mess.fetchMessMembers();
    });
  }

  @override
  void dispose() {
    _rentAmountCtrl.dispose();
    _messAmountCtrl.dispose();
    _totalAmountCtrl.dispose();
    _txnRefCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _updateFeeFields(Student student) {
    double messDefault = student.messBalanceDue > 0
        ? student.messBalanceDue
        : (student.monthlyMessFee > 0 ? (student.monthlyMessFee * _messMonthsToAdd) : 3500.0);
    double mess = _feeType != 'RENT' ? messDefault : 0.0;
    double rent = _feeType != 'MESS'
        ? (student.rentBalanceDue > 0 ? student.rentBalanceDue : (student.totalRentAgreed > 0 ? student.totalRentAgreed : 27000.0))
        : 0.0;
    double total = mess + rent;

    setState(() {
      _messAmountCtrl.text = mess > 0 ? mess.toStringAsFixed(0) : '';
      _rentAmountCtrl.text = rent > 0 ? rent.toStringAsFixed(0) : '';
      _totalAmountCtrl.text = total.toStringAsFixed(0);
    });
  }

  void _openStudentSearchSheet(
    List<Student> students,
    List<Student> allStudents,
    FormFieldState<String> formState,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final searchCtrl = TextEditingController();
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final filtered = StudentSearchHelper.filterStudents(students, searchCtrl.text);

            return Padding(
              padding: EdgeInsets.only(
                top: 16,
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.75,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.person_search_rounded, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Text(
                              'Select Student (${filtered.length})',
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: searchCtrl,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Search by name, room, phone, parent...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  searchCtrl.clear();
                                  setSheetState(() {});
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: isDark ? AppColors.surfaceDarkSecondary : AppColors.surfaceVariantLight,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                      ),
                      onChanged: (_) => setSheetState(() {}),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                searchCtrl.text.isNotEmpty
                                    ? 'No students found matching "${searchCtrl.text}"'
                                    : 'No students available in this category',
                                style: const TextStyle(color: Colors.grey),
                              ),
                            )
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, _) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final s = filtered[index];
                                final isSelected = s.id == _selectedStudentId;

                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  leading: StudentAvatar(student: s, radius: 20),
                                  title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text(
                                    s.isMessOnly
                                        ? 'Outside Mess • Phone: ${s.phone}'
                                        : 'Room ${s.roomNumber} (Bed ${s.bedNo}) • Phone: ${s.phone}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      if (_feeType == 'RENT' || _feeType == 'BOTH')
                                        Text(
                                          'Rent: ₹${s.rentBalanceDue.toStringAsFixed(0)} due',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: s.rentBalanceDue > 0 ? AppColors.danger : AppColors.success,
                                          ),
                                        ),
                                      if (_feeType == 'MESS' || _feeType == 'BOTH')
                                        Text(
                                          'Mess: ₹${s.messBalanceDue.toStringAsFixed(0)} due',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: s.messBalanceDue > 0 ? Colors.orange.shade800 : AppColors.success,
                                          ),
                                        ),
                                    ],
                                  ),
                                  selected: isSelected,
                                  selectedTileColor: AppColors.primary.withValues(alpha: 0.1),
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    _onStudentChanged(s.id, allStudents);
                                    formState.didChange(s.id);
                                  },
                                );
                              },
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

  void _onStudentChanged(String? studentId, List<Student> students) {
    if (studentId == null) {
      setState(() {
        _selectedStudentId = null;
        _currentStudent = null;
        _rentAmountCtrl.clear();
        _messAmountCtrl.clear();
        _totalAmountCtrl.clear();
      });
      return;
    }
    final s = students.firstWhere((st) => st.id == studentId, orElse: () => students.first);
    setState(() {
      _selectedStudentId = studentId;
      _currentStudent = s;
      _rentMonthsToAdd = s.rentTermMonths;
      // If selected student is Mess-Only, strictly lock feeType to MESS
      if (s.isMessOnly || !s.isHostelResident) {
        _feeType = 'MESS';
      } else if (!s.enrolledInMess && _feeType != 'RENT') {
        _feeType = 'RENT';
      }
    });
    _updateFeeFields(s);
  }

  void _onFeeTypeChanged(String? val, List<Student> allStudents) {
    if (val != null) {
      setState(() {
        _feeType = val;
        // Verify if currently selected student is compatible with the new fee type
        if (_currentStudent != null) {
          bool isCompatible = false;
          if (val == 'RENT') {
            isCompatible = _currentStudent!.isHostelResident;
          } else if (val == 'MESS') {
            isCompatible = _currentStudent!.isMessOnly || _currentStudent!.enrolledInMess;
          } else if (val == 'BOTH') {
            isCompatible = _currentStudent!.isHostelResident && _currentStudent!.enrolledInMess;
          }

          if (!isCompatible) {
            _selectedStudentId = null;
            _currentStudent = null;
            _rentAmountCtrl.clear();
            _messAmountCtrl.clear();
            _totalAmountCtrl.clear();
          } else {
            _updateFeeFields(_currentStudent!);
          }
        }
      });
    }
  }

  Future<void> _submitPayment() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedStudentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a resident')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final auth = context.read<AuthProvider>();
    final hostel = context.read<HostelProvider>();
    final dash = context.read<DashboardProvider>();

    final totalVal = double.tryParse(_totalAmountCtrl.text) ?? 0.0;
    double rAmount = 0.0;
    double mAmount = 0.0;

    if (_feeType == 'RENT') {
      rAmount = totalVal;
      mAmount = 0.0;
    } else if (_feeType == 'MESS') {
      mAmount = totalVal;
      rAmount = 0.0;
    } else {
      rAmount = double.tryParse(_rentAmountCtrl.text) ?? 0.0;
      mAmount = double.tryParse(_messAmountCtrl.text) ?? 0.0;
      if (rAmount == 0 && mAmount == 0) {
        mAmount = _currentStudent?.monthlyMessFee ?? 3500.0;
        rAmount = (totalVal - mAmount) > 0 ? (totalVal - mAmount) : 0.0;
      }
    }

    // 🛡️ Guard against exceeding Hostel Agreed Rent limit
    if (_currentStudent != null && _currentStudent!.isHostelResident && _currentStudent!.totalRentAgreed > 0 && rAmount > 0) {
      if (_currentStudent!.isRentFullyPaid) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hostel rent for ${_currentStudent!.name} is already fully paid (₹0 due). Cannot accept extra rent.'),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }
      if (rAmount > _currentStudent!.rentBalanceDue) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rent payment (₹${rAmount.toStringAsFixed(0)}) exceeds remaining balance due of ₹${_currentStudent!.rentBalanceDue.toStringAsFixed(0)}. Max allowed: ₹${_currentStudent!.rentBalanceDue.toStringAsFixed(0)}'),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }
    }

    final payload = {
      'studentId': _selectedStudentId,
      'amount': totalVal,
      'feeType': _feeType,
      'rentAmount': rAmount,
      'messAmount': mAmount,
      'paymentMode': _paymentMode,
      'targetMonth': _targetMonth,
      'transactionRef': _txnRefCtrl.text.trim(),
      'adminId': auth.currentAdmin?.id ?? 'admin-1',
      'adminName': auth.currentAdmin?.name ?? 'Admin',
      'messMonthsToAdd': _messMonthsToAdd,
      'rentMonthsToAdd': _rentMonthsToAdd,
      'notes': _notesCtrl.text.trim(),
    };

    final res = await hostel.recordPayment(payload);

    setState(() => _isSubmitting = false);

    if (mounted) {
      if (res != null && res['success'] == true) {
        final paymentData = Payment.fromJson(res['data']);
        final whatsappReceipt = res['whatsappReceipt'];

        dash.fetchDashboardStats();
        dash.fetchDuesAndExpiries();
        dash.fetchCashbook();

        _showSuccessDialog(paymentData, whatsappReceipt);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(hostel.error ?? 'Failed to record payment'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  void _showSuccessDialog(Payment payment, Map<String, dynamic>? whatsappReceipt) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: AppColors.success, size: 28),
              SizedBox(width: 8),
              Text('Payment Logged!'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Receipt No: ${payment.receiptNo}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 4),
              Text('Resident: ${payment.studentName} (Room ${payment.roomNumber})'),
              if (payment.targetMonth.isNotEmpty)
                Text('Billing Month: ${payment.targetMonth}', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary)),
              Text('Amount Collected: ${AppFormatters.formatCurrency(payment.amount)} via ${payment.paymentMode}'),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF064E3B).withValues(alpha: 0.6)
                      : const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '✅ ${payment.cycleEndDate}',
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF34D399)
                        : const Color(0xFF065F46),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              if (whatsappReceipt != null)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.chat, color: Colors.white, size: 16),
                    label: const Text('Send WhatsApp Receipt'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      final phone = _currentStudent?.phone ?? '';
                      UrlHelper.launchWhatsApp(phone: phone, message: whatsappReceipt['message'] ?? '');
                    },
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hostel = context.watch<HostelProvider>();
    final mess = context.watch<MessProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Combine all students from both providers (Hostel residents + Outside mess members)
    final studentMap = <String, Student>{};
    for (final s in hostel.students) {
      studentMap[s.id] = s;
    }
    for (final s in mess.messMembers) {
      studentMap[s.id] = s;
    }
    final allStudents = studentMap.values.toList();

    // 🎯 Filter residents strictly based on Payment Purpose:
    // 1. Hostel Rent ('RENT'): ONLY Hostel Room Residents
    // 2. Mess Fee Monthly ('MESS'): ONLY Mess Members (outside mess members & hostellers enrolled in mess)
    // 3. Both ('BOTH'): ONLY Hostel Room Residents who are enrolled in mess
    List<Student> filteredStudents;
    if (_feeType == 'RENT') {
      filteredStudents = allStudents.where((s) => s.isHostelResident).toList();
    } else if (_feeType == 'MESS') {
      filteredStudents = allStudents.where((s) => s.isMessOnly || s.enrolledInMess).toList();
    } else {
      filteredStudents = allStudents.where((s) => s.isHostelResident && s.enrolledInMess).toList();
    }
    filteredStudents.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final hasSelectedStudent = filteredStudents.any((s) => s.id == _selectedStudentId);
    final safeSelectedId = hasSelectedStudent ? _selectedStudentId : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Collect Fee Payment', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Resident Search & Picker
            FormField<String>(
              initialValue: safeSelectedId,
              validator: (v) => _selectedStudentId == null ? 'Resident selection required' : null,
              builder: (state) {
                final hasError = state.hasError;
                final isSelected = _currentStudent != null;
                final isDark = Theme.of(context).brightness == Brightness.dark;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () => _openStudentSearchSheet(filteredStudents, allStudents, state),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.surfaceDarkSecondary : AppColors.surfaceVariantLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: hasError
                                ? AppColors.danger
                                : (isSelected ? AppColors.primary : (isDark ? Colors.white24 : Colors.grey.shade400)),
                            width: isSelected || hasError ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            if (isSelected)
                              StudentAvatar(student: _currentStudent!, radius: 18)
                            else
                              Icon(
                                _feeType == 'RENT'
                                    ? Icons.apartment_outlined
                                    : (_feeType == 'MESS'
                                        ? Icons.restaurant_outlined
                                        : Icons.person_search_outlined),
                                color: AppColors.primary,
                              ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _feeType == 'RENT'
                                        ? 'Hostel Resident *'
                                        : (_feeType == 'MESS'
                                            ? 'Mess Member / Student *'
                                            : 'Resident (Hostel + Mess) *'),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected ? AppColors.primary : Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isSelected
                                        ? '${_currentStudent!.name} (${_currentStudent!.isMessOnly ? "Outside Mess • Phone: ${_currentStudent!.phone}" : "Room ${_currentStudent!.roomNumber}, Bed ${_currentStudent!.bedNo}"})'
                                        : 'Tap to search & select student...',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      color: isSelected
                                          ? null
                                          : (isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              IconButton(
                                icon: const Icon(Icons.clear, size: 20),
                                tooltip: 'Clear Selection',
                                onPressed: () {
                                  _onStudentChanged(null, allStudents);
                                  state.didChange(null);
                                },
                              )
                            else
                              const Icon(Icons.search_rounded, color: AppColors.primary),
                          ],
                        ),
                      ),
                    ),
                    if (hasError)
                      Padding(
                        padding: const EdgeInsets.only(left: 12, top: 6),
                        child: Text(
                          state.errorText ?? 'Resident selection required',
                          style: const TextStyle(color: AppColors.danger, fontSize: 12),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),

            // Fee Type Selector
            const Text('📌 Payment Purpose', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (_currentStudent == null || _currentStudent!.isHostelResident) ...[
                    _buildFeeTypeChip('🏨 Hostel Rent', 'RENT', allStudents),
                    const SizedBox(width: 8),
                  ],
                  if (_currentStudent == null || _currentStudent!.isMessOnly || _currentStudent!.enrolledInMess) ...[
                    _buildFeeTypeChip('🍽️ Mess Fee (Monthly)', 'MESS', allStudents),
                    const SizedBox(width: 8),
                  ],
                  if (_currentStudent == null || (_currentStudent!.isHostelResident && _currentStudent!.enrolledInMess)) ...[
                    _buildFeeTypeChip('Both', 'BOTH', allStudents),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 🗓️ Target Billing Month Selector
            DropdownButtonFormField<String>(
              value: _targetMonth,
              decoration: const InputDecoration(
                labelText: 'Collecting For Month *',
                prefixIcon: Icon(Icons.calendar_month_outlined),
                helperText: 'Select which month this fee is being collected for',
              ),
              items: _monthOptions.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _targetMonth = val);
              },
            ),
            const SizedBox(height: 16),

            // 🏨 Student Rent Ledger Summary (If RENT or BOTH)
            if (_currentStudent != null && (_feeType == 'RENT' || _feeType == 'BOTH') && _currentStudent!.isHostelResident) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDarkSecondary : const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _currentStudent!.rentBalanceDue > 0
                        ? (isDark ? Colors.amber.shade700 : Colors.amber.shade300)
                        : (isDark ? AppColors.borderDark : Colors.green.shade200),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('🏨 Hostel Rent Ledger', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _currentStudent!.rentBalanceDue <= 0
                                ? AppColors.success.withValues(alpha: 0.15)
                                : AppColors.warning.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _currentStudent!.rentBalanceDue <= 0 ? 'Fully Paid' : '₹${_currentStudent!.rentBalanceDue.toStringAsFixed(0)} Due',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _currentStudent!.rentBalanceDue <= 0 ? AppColors.success : AppColors.warning,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Agreed Rent: ${AppFormatters.formatCurrency(_currentStudent!.totalRentAgreed)}', style: const TextStyle(fontSize: 12)),
                        Text('Paid: ${AppFormatters.formatCurrency(_currentStudent!.totalRentPaid)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.success)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Remaining Due Balance: ${AppFormatters.formatCurrency(_currentStudent!.rentBalanceDue)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: _currentStudent!.rentBalanceDue > 0 ? AppColors.danger : AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // 🍽️ Monthly Mess Subscription Summary (If MESS or BOTH)
            if (_currentStudent != null && (_feeType == 'MESS' || _feeType == 'BOTH') && _currentStudent!.enrolledInMess) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDarkSecondary : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? AppColors.borderDark : Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('🍽️ Monthly Mess Subscription', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _currentStudent!.messBalanceDue <= 0
                                ? AppColors.success.withValues(alpha: 0.15)
                                : AppColors.warning.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _currentStudent!.messBalanceDue <= 0 ? 'Month Clear' : '₹${_currentStudent!.messBalanceDue.toStringAsFixed(0)} Due',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _currentStudent!.messBalanceDue <= 0 ? AppColors.success : AppColors.warning,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Monthly Rate: ${AppFormatters.formatCurrency(_currentStudent!.monthlyMessFee)} / month', style: const TextStyle(fontSize: 12)),
                        Text(
                          'Valid: ${AppFormatters.formatDate(_currentStudent!.messExpiryDate)}',
                          style: TextStyle(fontSize: 12, color: isDark ? AppColors.textMutedDark : AppColors.textSecondaryLight),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '• Student can pay in flexible partial installments anytime.\n• Due payment of 1st month clears balance without advancing validity.\n• Subsequent month payments extend meal plan validity by 1 month.',
                      style: TextStyle(fontSize: 11, color: isDark ? AppColors.textMutedDark : AppColors.textSecondaryLight, height: 1.3),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Quick Amount Suggestion Chips for Rent
            if (_feeType == 'RENT' && _currentStudent != null) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (_currentStudent!.rentBalanceDue > 0)
                    ActionChip(
                      avatar: const Icon(Icons.check_circle_outline, size: 14),
                      label: Text('Pay Full Due (₹${_currentStudent!.rentBalanceDue.toStringAsFixed(0)})'),
                      onPressed: () {
                        setState(() {
                          _rentAmountCtrl.text = _currentStudent!.rentBalanceDue.toStringAsFixed(0);
                          _totalAmountCtrl.text = _currentStudent!.rentBalanceDue.toStringAsFixed(0);
                        });
                      },
                    ),
                  ActionChip(
                    label: const Text('₹10,000'),
                    onPressed: () {
                      setState(() {
                        _rentAmountCtrl.text = '10000';
                        _totalAmountCtrl.text = '10000';
                      });
                    },
                  ),
                  ActionChip(
                    label: const Text('₹5,000'),
                    onPressed: () {
                      setState(() {
                        _rentAmountCtrl.text = '5000';
                        _totalAmountCtrl.text = '5000';
                      });
                    },
                  ),
                  ActionChip(
                    label: const Text('₹2,000'),
                    onPressed: () {
                      setState(() {
                        _rentAmountCtrl.text = '2000';
                        _totalAmountCtrl.text = '2000';
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Payment Mode
            DropdownButtonFormField<String>(
              value: _paymentMode,
              decoration: const InputDecoration(labelText: 'Payment Mode', prefixIcon: Icon(Icons.payment)),
              items: const [
                DropdownMenuItem(value: 'UPI', child: Text('📱 UPI (GPay / PhonePe / Paytm)')),
                DropdownMenuItem(value: 'CASH', child: Text('💵 Cash')),
                DropdownMenuItem(value: 'BANK_TRANSFER', child: Text('🏦 Bank Transfer / NEFT')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _paymentMode = v);
              },
            ),
            const SizedBox(height: 16),

            // Separate Amounts if Both
            if (_feeType == 'BOTH') ...[
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _rentAmountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Hostel Rent Part', prefixText: '₹ '),
                      onChanged: (v) {
                        final r = double.tryParse(v) ?? 0.0;
                        final m = double.tryParse(_messAmountCtrl.text) ?? 0.0;
                        _totalAmountCtrl.text = (r + m).toStringAsFixed(0);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _messAmountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Mess Fee Part', prefixText: '₹ '),
                      onChanged: (v) {
                        final m = double.tryParse(v) ?? 0.0;
                        final r = double.tryParse(_rentAmountCtrl.text) ?? 0.0;
                        _totalAmountCtrl.text = (r + m).toStringAsFixed(0);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            TextFormField(
              controller: _totalAmountCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Amount to Pay (₹) *',
                prefixText: '₹ ',
                helperText: _feeType == 'RENT'
                    ? 'Subtracted directly from total agreed rent'
                    : 'Submits payment and logs receipt into student history',
              ),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary),
              validator: (v) => v == null || v.trim().isEmpty ? 'Amount is required' : null,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _txnRefCtrl,
              decoration: const InputDecoration(
                labelText: 'Transaction Reference / UTR (Optional)',
                hintText: 'e.g., UPI Ref 9823481239',
                prefixIcon: Icon(Icons.tag),
              ),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Payment Remarks (Optional)',
                prefixIcon: Icon(Icons.notes),
              ),
            ),
            const SizedBox(height: 32),

            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.receipt_long),
                label: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Record Payment & Generate Receipt'),
                onPressed: _isSubmitting ? null : _submitPayment,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeeTypeChip(String label, String value, List<Student> allStudents) {
    final isSelected = _feeType == value;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: isSelected,
      selectedColor: AppColors.primary.withValues(alpha: 0.15),
      onSelected: (_) => _onFeeTypeChanged(value, allStudents),
    );
  }
}
