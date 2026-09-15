import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/student.dart';
import '../../providers/auth_provider.dart';
import '../../providers/hostel_provider.dart';
import '../../providers/mess_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../widgets/student_avatar.dart';
import '../../services/image_service.dart';

class AddMessMemberScreen extends StatefulWidget {
  final Student? memberToEdit;
  const AddMessMemberScreen({super.key, this.memberToEdit});

  @override
  State<AddMessMemberScreen> createState() => _AddMessMemberScreenState();
}

class _AddMessMemberScreenState extends State<AddMessMemberScreen> {
  final _formKey = GlobalKey<FormState>();

  // Member Type toggle: true = Hostel Resident, false = Outside Day Scholar
  bool _isHostelResident = false;
  String? _selectedHostelStudentId;
  Student? _selectedHostelStudent;

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _parentNameController = TextEditingController();
  final _parentPhoneController = TextEditingController();
  final _photoUrlController = TextEditingController();
  final _feeController = TextEditingController(text: '3500');
  final _notesController = TextEditingController();

  DateTime _startDate = DateTime.now();
  int _cycleDay = 1;
  bool _isSubmitting = false;

  // Curated student avatar headshots for 1-tap selection
  final List<String> _avatarPresets = [
    'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=200&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=200&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=200&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=200&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200&auto=format&fit=crop&q=80',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.memberToEdit != null) {
      final m = widget.memberToEdit!;
      _isHostelResident = !m.isMessOnly;
      _nameController.text = m.name;
      _phoneController.text = m.phone;
      _parentNameController.text = m.parentName;
      _parentPhoneController.text = m.parentPhone;
      _photoUrlController.text = m.photoUrl ?? '';
      _feeController.text = m.monthlyMessFee > 0 ? m.monthlyMessFee.toStringAsFixed(0) : '3500';
      _notesController.text = m.notes;
      _startDate = DateTime.tryParse(m.admissionDate) ?? DateTime.now();
      _cycleDay = m.cycleDay > 0 ? m.cycleDay : 1;
      _selectedHostelStudentId = m.isHostelResident ? m.id : null;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HostelProvider>().fetchStudents();
    });
    _recoverLostCameraImage();
  }

  Future<void> _recoverLostCameraImage() async {
    try {
      final lostPhoto = await ImageService.retrieveLostData();
      if (lostPhoto != null && mounted) {
        setState(() {
          _photoUrlController.text = lostPhoto;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📸 Camera photo successfully recovered!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _parentNameController.dispose();
    _parentPhoneController.dispose();
    _photoUrlController.dispose();
    _feeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickImageFromDevice(ImageSource source, BuildContext modalCtx) async {
    // 1. Dismiss bottom sheet modal first to free memory before native camera launches
    if (modalCtx.mounted) {
      Navigator.of(modalCtx).pop();
    }

    try {
      await ImageService.setPendingPhotoContext('mess_member');
      final base64String = await ImageService.pickAndCompressImage(
        source: source,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 70,
      );
      await ImageService.clearPendingPhotoContext();

      if (base64String != null && mounted) {
        final sizeKb = ImageService.getApproximateSizeKb(base64String);
        setState(() {
          _photoUrlController.text = base64String;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📸 Photo compressed & attached (${sizeKb.toStringAsFixed(1)} KB)!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      await ImageService.clearPendingPhotoContext();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not pick photo: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  void _showPhotoDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tempCtrl = TextEditingController(text: _photoUrlController.text);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('📸 Member Photo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    if (_photoUrlController.text.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _photoUrlController.clear();
                          });
                          Navigator.pop(ctx);
                        },
                        child: const Text('Remove Photo', style: TextStyle(color: AppColors.danger, fontSize: 12)),
                      ),
                  ],
                ),
                const SizedBox(height: 14),

                // Section A: Pick from Device Gallery / Camera
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.photo_library_outlined, size: 18),
                        label: const Text('Gallery'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? AppColors.secondaryLight : AppColors.secondary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => _pickImageFromDevice(ImageSource.gallery, ctx),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.camera_alt_outlined, size: 18),
                        label: const Text('Camera'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? AppColors.surfaceDarkSecondary : Colors.grey.shade800,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => _pickImageFromDevice(ImageSource.camera, ctx),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Section B: Preset Avatars Grid
                const Text('⚡ Or Select Avatar Preset', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _avatarPresets.map((url) {
                    final isSelected = _photoUrlController.text == url;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _photoUrlController.text = url;
                        });
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? AppColors.secondary : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 28,
                          backgroundImage: NetworkImage(url),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Section C: Custom URL Input
                const Text('🌐 Or Paste Direct Image Link', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                TextField(
                  controller: tempCtrl,
                  decoration: InputDecoration(
                    hintText: 'https://example.com/student-photo.jpg',
                    prefixIcon: const Icon(Icons.link_rounded),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.check_circle_outline, color: AppColors.secondary),
                      onPressed: () {
                        if (tempCtrl.text.trim().isNotEmpty) {
                          setState(() {
                            _photoUrlController.text = tempCtrl.text.trim();
                          });
                          Navigator.pop(ctx);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  void _onHostelResidentSelected(String? studentId, List<Student> students) {
    if (studentId == null) return;
    final s = students.firstWhere((st) => st.id == studentId);
    setState(() {
      _selectedHostelStudentId = studentId;
      _selectedHostelStudent = s;
      _nameController.text = s.name;
      _phoneController.text = s.phone;
      _parentNameController.text = s.parentName;
      _parentPhoneController.text = s.parentPhone;
      _photoUrlController.text = s.photoUrl ?? '';
      _feeController.text = s.monthlyMessFee > 0 ? s.monthlyMessFee.toStringAsFixed(0) : '3500';
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isHostelResident && _selectedHostelStudentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a hostel resident')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final auth = context.read<AuthProvider>();
    final mess = context.read<MessProvider>();
    final dash = context.read<DashboardProvider>();
    final hostel = context.read<HostelProvider>();

    final payload = {
      'isHostelResident': _isHostelResident,
      'studentId': _isHostelResident ? _selectedHostelStudentId : null,
      'name': _nameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'parentName': _parentNameController.text.trim(),
      'parentPhone': _parentPhoneController.text.trim(),
      'photoUrl': _photoUrlController.text.trim(),
      'monthlyMessFee': double.tryParse(_feeController.text) ?? 3500.0,
      'admissionDate': _startDate.toIso8601String().split('T')[0],
      'cycleDay': _cycleDay,
      'notes': _notesController.text.trim(),
      'adminName': auth.currentAdmin?.name ?? 'Mess In-charge',
    };

    final bool success;
    if (widget.memberToEdit != null) {
      success = await mess.updateOutsideMessMember(widget.memberToEdit!.id, payload);
    } else {
      success = await mess.createOutsideMessMember(payload);
    }

    setState(() => _isSubmitting = false);

    if (mounted) {
      if (success) {
        hostel.fetchStudents();
        dash.fetchDashboardStats();
        dash.fetchDuesAndExpiries();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.memberToEdit != null
                ? 'Member "${_nameController.text}" updated successfully!'
                : (_isHostelResident
                    ? 'Resident "${_nameController.text}" enrolled in Mess successfully!'
                    : 'Mess member added successfully!')),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mess.error ?? (widget.memberToEdit != null ? 'Failed to update member' : 'Failed to add member')),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hostel = context.watch<HostelProvider>();
    final unenrolledHostelResidents = hostel.students
        .where((s) => s.isHostelResident && !s.enrolledInMess)
        .toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.memberToEdit != null ? 'Edit Mess Member' : 'Add Member', style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 📸 Section 0: Member Photo Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
              ),
              child: Column(
                children: [
                  Stack(
                    children: [
                      StudentAvatar(
                        name: _nameController.text.isNotEmpty ? _nameController.text : 'New Member',
                        photoUrl: _photoUrlController.text.isNotEmpty ? _photoUrlController.text : null,
                        roomNumber: _isHostelResident ? (_selectedHostelStudent?.roomNumber ?? '') : 'Mess Only',
                        radius: 46,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _showPhotoDialog,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.secondaryLight : AppColors.secondary,
                              shape: BoxShape.circle,
                              border: Border.all(color: isDark ? AppColors.surfaceDark : Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: _showPhotoDialog,
                    icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                    label: Text(
                      _photoUrlController.text.isNotEmpty ? 'Change Member Photo' : '+ Add Member Photo',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Selection: Is Student a Hosteler or Outside Student? (Only for new additions)
            if (widget.memberToEdit == null) ...[
              const Text(
                'Select Member Type',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _isHostelResident = true;
                        if (_selectedHostelStudent != null) {
                          _nameController.text = _selectedHostelStudent!.name;
                          _phoneController.text = _selectedHostelStudent!.phone;
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                      decoration: BoxDecoration(
                        color: _isHostelResident ? AppColors.primary.withValues(alpha: 0.1) : Colors.white,
                        border: Border.all(
                          color: _isHostelResident ? AppColors.primary : AppColors.border,
                          width: _isHostelResident ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.hotel_rounded,
                              color: _isHostelResident ? AppColors.primary : AppColors.textMuted, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Hostel Resident',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: _isHostelResident ? AppColors.primary : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _isHostelResident = false;
                        _selectedHostelStudentId = null;
                        _selectedHostelStudent = null;
                        _nameController.clear();
                        _phoneController.clear();
                        _parentNameController.clear();
                        _parentPhoneController.clear();
                      });
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                      decoration: BoxDecoration(
                        color: !_isHostelResident ? AppColors.secondary.withValues(alpha: 0.1) : Colors.white,
                        border: Border.all(
                          color: !_isHostelResident ? AppColors.secondary : AppColors.border,
                          width: !_isHostelResident ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person_pin_outlined,
                              color: !_isHostelResident ? AppColors.secondary : AppColors.textMuted, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Outside / Day Scholar',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: !_isHostelResident ? AppColors.secondary : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // IF HOSTEL RESIDENT: Show Dropdown to pick the resident (when creating new)
          if (_isHostelResident && widget.memberToEdit == null) ...[
            if (unenrolledHostelResidents.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle_outline, color: Colors.amber, size: 22),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'All current hostel residents are already enrolled in the Mess.',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  value: _selectedHostelStudentId,
                  decoration: const InputDecoration(
                    labelText: 'Select Hostel Resident *',
                    prefixIcon: Icon(Icons.person_search_outlined),
                    helperText: 'Select a resident living in the hostel to enroll in mess',
                  ),
                  items: unenrolledHostelResidents.map((s) {
                    return DropdownMenuItem(
                      value: s.id,
                      child: Text('${s.name} • Room ${s.roomNumber} (Bed ${s.bedNo})'),
                    );
                  }).toList(),
                  onChanged: (val) => _onHostelResidentSelected(val, unenrolledHostelResidents),
                  validator: (v) => _isHostelResident && v == null ? 'Resident selection required' : null,
                ),
              const SizedBox(height: 14),

              if (_selectedHostelStudent != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, color: Color(0xFF16A34A), size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Selected: ${_selectedHostelStudent!.name}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF15803D)),
                            ),
                            Text(
                              'Room ${_selectedHostelStudent!.roomNumber} (Bed ${_selectedHostelStudent!.bedNo}) • Phone: ${_selectedHostelStudent!.phone}',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF15803D)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
            ] else ...[
              // IF OUTSIDE STUDENT: Show Name & Phone Fields
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Member Full Name *',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) => !_isHostelResident && (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number (for WhatsApp Reminders) *',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: (v) => !_isHostelResident && (v == null || v.trim().isEmpty) ? 'Phone is required' : null,
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _parentNameController,
                      decoration: const InputDecoration(
                        labelText: 'Parent Name',
                        prefixIcon: Icon(Icons.people_outline),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _parentPhoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Parent Phone',
                        prefixIcon: Icon(Icons.phone_android),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
            ],

            const Text('💵 Monthly Mess Subscription', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _feeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Monthly Mess Fee (₹) *',
                      prefixText: '₹ ',
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Fee required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    readOnly: true,
                    controller: TextEditingController(
                      text: '${_startDate.day}/${_startDate.month}/${_startDate.year}',
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Joining Date',
                      prefixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _startDate,
                        firstDate: DateTime(2025),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setState(() {
                          _startDate = picked;
                          _cycleDay = picked.day;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField<int>(
              value: _cycleDay,
              decoration: const InputDecoration(
                labelText: 'Monthly Renewal Day',
                prefixIcon: Icon(Icons.event_repeat),
                helperText: 'e.g. Day 5 of every month',
              ),
              items: List.generate(28, (i) => i + 1).map((d) {
                return DropdownMenuItem(value: d, child: Text('Day $d of every month'));
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _cycleDay = val);
              },
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _notesController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: _isHostelResident
                    ? 'Diet / Food Preferences / Notes (Optional)'
                    : 'Address / PG Location / College Name / Notes',
                prefixIcon: const Icon(Icons.notes_outlined),
              ),
            ),
            const SizedBox(height: 32),

            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                icon: Icon(widget.memberToEdit != null ? Icons.save_rounded : Icons.person_add_alt_1_rounded),
                label: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(widget.memberToEdit != null
                        ? 'Save Changes'
                        : (_isHostelResident ? 'Enroll Resident in Mess' : 'Add Member')),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
                onPressed: _isSubmitting ? null : _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
