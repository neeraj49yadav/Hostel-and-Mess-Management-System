import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/url_helper.dart';
import '../../models/student.dart';
import '../../models/payment.dart';
import '../../providers/auth_provider.dart';
import '../../providers/hostel_provider.dart';
import '../../providers/mess_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../services/pdf_service.dart';

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

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf, size: 16),
                  label: const Text('View & Print PDF Receipt'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.primaryLight
                        : AppColors.primary,
                  ),
                  onPressed: () => PdfService.printReceipt(
                    payment,
                    hostelName: context.read<AuthProvider>().currentOrganization?.name,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              if (whatsappReceipt != null)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.chat, color: Color(0xFF25D366), size: 16),
                    label: const Text('Send WhatsApp Receipt'),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF25D366))),
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
            // Resident Picker
            DropdownButtonFormField<String>(
              value: safeSelectedId,
              decoration: InputDecoration(
                labelText: _feeType == 'RENT'
                    ? 'Select Hostel Resident *'
                    : (_feeType == 'MESS'
                        ? 'Select Mess Member / Student *'
                        : 'Select Resident (Hostel + Mess) *'),
                prefixIcon: Icon(_feeType == 'RENT'
                    ? Icons.apartment_outlined
                    : (_feeType == 'MESS' ? Icons.restaurant_outlined : Icons.person_search_outlined)),
                helperText: _feeType == 'RENT'
                    ? 'Showing only hostel room residents'
                    : (_feeType == 'MESS'
                        ? 'Showing outside mess members & enrolled hostellers'
                        : 'Showing hostellers enrolled in mess'),
              ),
              items: filteredStudents.map((s) {
                final String detail;
                if (s.isMessOnly) {
                  detail = 'Outside Mess • ₹${s.monthlyMessFee.toStringAsFixed(0)}/mo (Due: ₹${s.messBalanceDue.toStringAsFixed(0)})';
                } else if (_feeType == 'RENT') {
                  detail = 'Room ${s.roomNumber} • Rent Due: ₹${s.rentBalanceDue.toStringAsFixed(0)}';
                } else if (_feeType == 'MESS') {
                  detail = 'Room ${s.roomNumber} • Mess Due: ₹${s.messBalanceDue.toStringAsFixed(0)}';
                } else {
                  detail = 'Room ${s.roomNumber} • Rent: ₹${s.rentBalanceDue.toStringAsFixed(0)}, Mess: ₹${s.messBalanceDue.toStringAsFixed(0)}';
                }
                return DropdownMenuItem<String>(
                  value: s.id,
                  child: Text(
                    '${s.name} ($detail)',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                );
              }).toList(),
              onChanged: (val) => _onStudentChanged(val, allStudents),
              validator: (v) => v == null ? 'Resident selection required' : null,
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
