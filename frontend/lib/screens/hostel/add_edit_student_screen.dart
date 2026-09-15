import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/room.dart';
import '../../models/student.dart';
import '../../providers/auth_provider.dart';
import '../../providers/hostel_provider.dart';
import '../../widgets/student_avatar.dart';
import '../../services/image_service.dart';

class AddEditStudentScreen extends StatefulWidget {
  final Student? studentToEdit;

  const AddEditStudentScreen({super.key, this.studentToEdit});

  @override
  State<AddEditStudentScreen> createState() => _AddEditStudentScreenState();
}

class _AddEditStudentScreenState extends State<AddEditStudentScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _parentNameController;
  late TextEditingController _parentPhoneController;
  late TextEditingController _photoUrlController;
  late TextEditingController _messFeeController;
  late TextEditingController _rentTermAmountController;
  late TextEditingController _notesController;

  String? _selectedRoomId;
  String _selectedBedNo = 'A';
  int _cycleDay = 1;
  int _rentTermMonths = 6; // Default to 6 Months (Semester / 2x a year)
  bool _enrolledInMess = true;
  DateTime _admissionDate = DateTime.now();
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
    final s = widget.studentToEdit;
    _nameController = TextEditingController(text: s?.name ?? '');
    _phoneController = TextEditingController(text: s?.phone ?? '');
    _parentNameController = TextEditingController(text: s?.parentName ?? '');
    _parentPhoneController = TextEditingController(text: s?.parentPhone ?? '');
    _photoUrlController = TextEditingController(text: s?.photoUrl ?? '');
    _messFeeController = TextEditingController(text: s != null ? s.monthlyMessFee.toStringAsFixed(0) : '3500');
    _rentTermAmountController = TextEditingController(text: s != null ? s.rentAmountPerTerm.toStringAsFixed(0) : '27000');
    _notesController = TextEditingController(text: s?.notes ?? '');

    if (s != null) {
      _selectedRoomId = s.roomId;
      _selectedBedNo = s.bedNo;
      _cycleDay = s.cycleDay;
      _rentTermMonths = s.rentTermMonths;
      _enrolledInMess = s.enrolledInMess;
      if (s.admissionDate.isNotEmpty) {
        _admissionDate = DateTime.tryParse(s.admissionDate) ?? DateTime.now();
      }
    }

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
    _messFeeController.dispose();
    _rentTermAmountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickImageFromDevice(ImageSource source, BuildContext modalCtx) async {
    // 1. Dismiss bottom sheet modal first to free memory before native camera launches
    if (modalCtx.mounted) {
      Navigator.of(modalCtx).pop();
    }

    try {
      await ImageService.setPendingPhotoContext('student');
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
          SnackBar(
            content: Text('Could not access image: $e'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
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
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('📸 Resident Student Photo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        if (_photoUrlController.text.isNotEmpty)
                          TextButton.icon(
                            icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 18),
                            label: const Text('Remove', style: TextStyle(color: AppColors.danger)),
                            onPressed: () {
                              setState(() {
                                _photoUrlController.clear();
                              });
                              Navigator.pop(ctx);
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Choose a photo from your device, camera, preset avatars, or paste an image URL:',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),

                    // 📱 Section A: Device Gallery & Camera (Primary Options)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.photo_library_outlined, size: 20),
                            label: const Text('Device Gallery', style: TextStyle(fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(color: isDark ? AppColors.primaryLight : AppColors.primary, width: 1.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => _pickImageFromDevice(ImageSource.gallery, ctx),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.camera_alt_outlined, size: 20),
                            label: const Text('Take Photo', style: TextStyle(fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(color: isDark ? AppColors.secondaryLight : AppColors.secondary, width: 1.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => _pickImageFromDevice(ImageSource.camera, ctx),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // 🎭 Section B: Preset Avatars Grid
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
                                color: isSelected ? AppColors.primary : Colors.transparent,
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

                    // 🌐 Section C: Custom URL Input
                    const Text('🌐 Or Paste Direct Image Link', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: tempCtrl,
                      decoration: InputDecoration(
                        hintText: 'https://example.com/student-photo.jpg',
                        prefixIcon: const Icon(Icons.link_rounded),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.check_circle_outline, color: AppColors.primary),
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
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _saveStudent() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRoomId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a room')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final auth = context.read<AuthProvider>();
    final hostel = context.read<HostelProvider>();

    final payload = {
      'name': _nameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'parentName': _parentNameController.text.trim(),
      'parentPhone': _parentPhoneController.text.trim(),
      'photoUrl': _photoUrlController.text.trim(),
      'roomId': _selectedRoomId,
      'bedNo': _selectedBedNo,
      'admissionDate': _admissionDate.toIso8601String().split('T')[0],
      'cycleDay': _cycleDay,
      'enrolledInMess': _enrolledInMess,
      'monthlyMessFee': _enrolledInMess ? (double.tryParse(_messFeeController.text) ?? 3500.0) : 0.0,
      'totalRentAgreed': double.tryParse(_rentTermAmountController.text) ?? 50000.0,
      'rentTermMonths': _rentTermMonths,
      'rentAmountPerTerm': double.tryParse(_rentTermAmountController.text) ?? 50000.0,
      'notes': _notesController.text.trim(),
      'adminName': auth.currentAdmin?.name ?? 'Admin',
    };

    bool success;
    if (widget.studentToEdit != null) {
      success = await hostel.updateStudent(widget.studentToEdit!.id, payload);
    } else {
      success = await hostel.createStudent(payload);
    }

    setState(() {
      _isSubmitting = false;
    });

    if (mounted) {
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.studentToEdit != null ? 'Resident profile updated' : 'New resident enrolled successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(hostel.error ?? 'Failed to save resident profile'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  List<String> _getAvailableBedSlots(HostelProvider hostel) {
    if (_selectedRoomId == null) {
      return ['A', 'B', 'C', 'D'];
    }

    final selectedRoom = hostel.rooms.firstWhere(
      (r) => r.id == _selectedRoomId,
      orElse: () => Room(id: '', roomNumber: '', floor: 1, totalBeds: 4, occupiedBeds: 0, vacantBeds: 4, status: 'AVAILABLE', occupants: []),
    );

    // Bed labels up to total beds in room (e.g. 2 -> ['A', 'B'])
    final allBedLabels = ['A', 'B', 'C', 'D', 'E', 'F'].take(selectedRoom.totalBeds > 0 ? selectedRoom.totalBeds : 2).toList();

    // Occupied beds in this room by active residents (excluding current student if editing)
    final occupiedBeds = hostel.students
        .where((s) => s.roomId == _selectedRoomId && s.status != 'ARCHIVED' && (widget.studentToEdit == null || s.id != widget.studentToEdit!.id))
        .map((s) => s.bedNo.toUpperCase().trim())
        .toSet();

    final freeBeds = allBedLabels.where((bed) => !occupiedBeds.contains(bed)).toList();

    // If editing and student already holds a bed in this room, preserve it
    if (widget.studentToEdit != null && widget.studentToEdit!.roomId == _selectedRoomId) {
      final currentBed = widget.studentToEdit!.bedNo.toUpperCase().trim();
      if (!freeBeds.contains(currentBed) && currentBed.isNotEmpty) {
        freeBeds.add(currentBed);
        freeBeds.sort();
      }
    }

    return freeBeds;
  }

  @override
  Widget build(BuildContext context) {
    final hostel = context.watch<HostelProvider>();
    final isEditing = widget.studentToEdit != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final availableBeds = _getAvailableBedSlots(hostel);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Resident Profile' : 'New Resident Onboarding', style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 📸 Section 0: Resident Photo Header (Hostel Resident Exclusive)
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
                        name: _nameController.text.isNotEmpty ? _nameController.text : 'New Student',
                        photoUrl: _photoUrlController.text.isNotEmpty ? _photoUrlController.text : null,
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
                              color: isDark ? AppColors.primaryLight : AppColors.primary,
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
                      _photoUrlController.text.isNotEmpty ? 'Change Resident Photo' : '+ Add Resident Photo',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Section 1: Personal Details
            const Text('👤 Personal Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),

            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Full Name *', prefixIcon: Icon(Icons.person_outline)),
              onChanged: (_) => setState(() {}),
              validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Resident Phone Number *', prefixIcon: Icon(Icons.phone_outlined)),
              validator: (v) => v == null || v.trim().isEmpty ? 'Phone is required' : null,
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _parentNameController,
                    decoration: const InputDecoration(labelText: 'Parent / Guardian Name', prefixIcon: Icon(Icons.people_outline)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _parentPhoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Parent Phone Number', prefixIcon: Icon(Icons.phone_outlined)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Section 2: Room & Bed Allocation
            const Text('🛏️ Room & Bed Allocation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: _selectedRoomId,
              decoration: const InputDecoration(labelText: 'Select Room *', prefixIcon: Icon(Icons.meeting_room_outlined)),
              items: hostel.rooms.map((room) {
                return DropdownMenuItem<String>(
                  value: room.id,
                  child: Text('Room ${room.roomNumber} (Floor ${room.floor}) • ${room.vacantBeds} beds vacant'),
                );
              }).toList(),
              onChanged: (val) {
                setState(() {
                  _selectedRoomId = val;
                  final available = _getAvailableBedSlots(hostel);
                  if (!available.contains(_selectedBedNo)) {
                    _selectedBedNo = available.isNotEmpty ? available.first : 'A';
                  }
                });
              },
              validator: (v) => v == null ? 'Please select a room' : null,
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: availableBeds.contains(_selectedBedNo)
                        ? _selectedBedNo
                        : (availableBeds.isNotEmpty ? availableBeds.first : null),
                    decoration: InputDecoration(
                      labelText: 'Bed Slot *',
                      prefixIcon: const Icon(Icons.bed_outlined),
                      helperText: availableBeds.isEmpty
                          ? '⚠️ Room full'
                          : '${availableBeds.length} free slot(s)',
                    ),
                    items: availableBeds.map((bed) {
                      return DropdownMenuItem<String>(
                        value: bed,
                        child: Text('Bed $bed (Free)'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedBedNo = val;
                        });
                      }
                    },
                    validator: (v) => v == null || v.isEmpty ? 'Select a free bed' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _cycleDay,
                    decoration: const InputDecoration(labelText: 'Fee Cycle Day', prefixIcon: Icon(Icons.calendar_today_outlined)),
                    items: List.generate(28, (i) => i + 1).map((day) {
                      return DropdownMenuItem<int>(
                        value: day,
                        child: Text('Day $day of Month'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _cycleDay = val;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Section 3: Total Hostel Rent to Pay
            const Text('🏨 Total Hostel Rent to Pay', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              'Enter the total agreed rent to be paid by the student. The student can make flexible partial payments anytime, which will subtract from this balance:',
              style: TextStyle(fontSize: 12, color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _rentTermAmountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Total Rent to Pay (₹) *',
                prefixIcon: Icon(Icons.currency_rupee),
                helperText: 'e.g. ₹50,000 (Student can pay in any installments anytime)',
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Total rent amount is required' : null,
            ),
            const SizedBox(height: 20),

            // Section 4: Mess Enrollment Option
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('🍽️ Enrolled in Hostel Mess', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Student will take meals from the hostel mess (monthly cycle)'),
                    value: _enrolledInMess,
                    activeColor: AppColors.secondary,
                    onChanged: (val) {
                      setState(() {
                        _enrolledInMess = val;
                      });
                    },
                  ),
                  if (_enrolledInMess) ...[
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _messFeeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Monthly Mess Fee (₹) *',
                        prefixIcon: Icon(Icons.restaurant_outlined),
                      ),
                      validator: (v) {
                        if (_enrolledInMess && (v == null || v.trim().isEmpty)) {
                          return 'Mess fee is required';
                        }
                        return null;
                      },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Section 5: Admission Date & Notes
            const Text('📝 Notes & Admission Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),

            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: const Text('Admission Date'),
              subtitle: Text('${_admissionDate.day}/${_admissionDate.month}/${_admissionDate.year}'),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _admissionDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (picked != null) {
                  setState(() {
                    _admissionDate = picked;
                  });
                }
              },
            ),
            const SizedBox(height: 8),

            TextFormField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notes / Branch / College / Remarks',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _isSubmitting ? null : _saveStudent,
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? AppColors.primaryLight : AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSubmitting
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(isEditing ? 'Save Changes' : 'Enroll Resident', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
