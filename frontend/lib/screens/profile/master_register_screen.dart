import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/pdf_service.dart';
import '../../widgets/app_avatar_image.dart';

class MasterRegisterScreen extends StatefulWidget {
  const MasterRegisterScreen({super.key});

  @override
  State<MasterRegisterScreen> createState() => _MasterRegisterScreenState();
}

class _MasterRegisterScreenState extends State<MasterRegisterScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _searchCtrl = TextEditingController();

  bool _isLoading = true;
  String? _error;

  List<dynamic> _records = [];
  Map<String, dynamic> _stats = {
    'totalLifetimeCount': 0,
    'activeCount': 0,
    'leftCount': 0,
    'hostelCount': 0,
    'messCount': 0,
  };

  String _statusFilter = 'ALL'; // ALL, ACTIVE, LEFT
  String _typeFilter = 'ALL'; // ALL, HOSTEL_RESIDENT, MESS_ONLY

  @override
  void initState() {
    super.initState();
    _fetchMasterRegister();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchMasterRegister() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final res = await _api.getMasterRegister(
        search: _searchCtrl.text.trim(),
        status: _statusFilter,
        type: _typeFilter,
      );

      if (mounted) {
        setState(() {
          _records = res['data'] as List? ?? [];
          if (res['stats'] != null) {
            _stats = Map<String, dynamic>.from(res['stats']);
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _makePhoneCall(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openWhatsApp(String phone, String name) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final formatted = clean.length == 10 ? '91$clean' : clean;
    final orgName = context.read<AuthProvider>().currentOrganization?.name ?? 'Hostel';
    final message = Uri.encodeComponent('Namaste $name ji, regarding your record at $orgName:');
    final uri = Uri.parse('https://wa.me/$formatted?text=$message');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _printMasterRegister() async {
    if (_records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No student records to print'), backgroundColor: AppColors.warning),
      );
      return;
    }

    try {
      final orgName = context.read<AuthProvider>().currentOrganization?.name ?? 'Hostel and Mess Management System';
      await PdfService.printMasterRegister(
        records: _records,
        stats: _stats,
        hostelName: orgName,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate PDF: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final orgName = context.watch<AuthProvider>().currentOrganization?.name ?? 'Hostel & Mess';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Master Student Register',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            Text(
              'Permanent Lifetime Archive • $orgName',
              style: const TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_rounded),
            tooltip: 'Print Master Register PDF',
            onPressed: _records.isEmpty ? null : _printMasterRegister,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _fetchMasterRegister,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'master_pdf_btn',
        onPressed: _records.isEmpty ? null : _printMasterRegister,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.picture_as_pdf_rounded),
        label: const Text('Print Register PDF', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // 📊 Lifetime Aggregate Stats Header
          _buildStatsHeader(isDark),

          // 🔍 Search & Filters Bar
          _buildSearchAndFilters(isDark),

          // 📋 Records List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildErrorView()
                    : _records.isEmpty
                        ? _buildEmptyView()
                        : _buildRecordsList(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsHeader(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.menu_book_rounded, size: 16, color: AppColors.primary),
              ),
              const SizedBox(width: 8),
              const Text(
                'LIFETIME REGISTER ARCHIVE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppColors.primary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield_rounded, size: 12, color: AppColors.success),
                    SizedBox(width: 4),
                    Text(
                      'Non-Deletable',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.success),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStatBadge(
                  label: 'Total Enrolled',
                  value: '${_stats['totalLifetimeCount'] ?? 0}',
                  color: AppColors.primary,
                  icon: Icons.people_alt_rounded,
                ),
                const SizedBox(width: 8),
                _buildStatBadge(
                  label: 'Active',
                  value: '${_stats['activeCount'] ?? 0}',
                  color: AppColors.success,
                  icon: Icons.check_circle_outline_rounded,
                ),
                const SizedBox(width: 8),
                _buildStatBadge(
                  label: 'Left / Alumni',
                  value: '${_stats['leftCount'] ?? 0}',
                  color: AppColors.warning,
                  icon: Icons.history_rounded,
                ),
                const SizedBox(width: 8),
                _buildStatBadge(
                  label: 'Hostelites',
                  value: '${_stats['hostelCount'] ?? 0}',
                  color: Colors.indigo,
                  icon: Icons.hotel_rounded,
                ),
                const SizedBox(width: 8),
                _buildStatBadge(
                  label: 'Mess Members',
                  value: '${_stats['messCount'] ?? 0}',
                  color: Colors.amber.shade800,
                  icon: Icons.restaurant_rounded,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBadge({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
              Text(label, style: TextStyle(fontSize: 9, color: Colors.grey.shade600)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      color: isDark ? AppColors.surfaceDark.withValues(alpha: 0.5) : Colors.grey.shade50,
      child: Column(
        children: [
          // Search Input
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search by student name, phone, room, parent...',
              hintStyle: const TextStyle(fontSize: 13),
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        _fetchMasterRegister();
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
              filled: true,
              fillColor: isDark ? AppColors.surfaceDark : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300),
              ),
            ),
            onChanged: (val) {
              setState(() {});
              _fetchMasterRegister();
            },
          ),
          const SizedBox(height: 8),

          // Filters Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Status Filter Chips
                _buildFilterChip('All Status', _statusFilter == 'ALL', () {
                  setState(() => _statusFilter = 'ALL');
                  _fetchMasterRegister();
                }),
                const SizedBox(width: 6),
                _buildFilterChip('Active Only', _statusFilter == 'ACTIVE', () {
                  setState(() => _statusFilter = 'ACTIVE');
                  _fetchMasterRegister();
                }, activeColor: AppColors.success),
                const SizedBox(width: 6),
                _buildFilterChip('Left / Alumni', _statusFilter == 'LEFT', () {
                  setState(() => _statusFilter = 'LEFT');
                  _fetchMasterRegister();
                }, activeColor: AppColors.warning),
                const SizedBox(width: 12),
                Container(height: 18, width: 1, color: Colors.grey.shade300),
                const SizedBox(width: 12),

                // Category Filter Chips
                _buildFilterChip('All Types', _typeFilter == 'ALL', () {
                  setState(() => _typeFilter = 'ALL');
                  _fetchMasterRegister();
                }),
                const SizedBox(width: 6),
                _buildFilterChip('Hostelites', _typeFilter == 'HOSTEL_RESIDENT', () {
                  setState(() => _typeFilter = 'HOSTEL_RESIDENT');
                  _fetchMasterRegister();
                }, activeColor: Colors.indigo),
                const SizedBox(width: 6),
                _buildFilterChip('Mess Only', _typeFilter == 'MESS_ONLY', () {
                  setState(() => _typeFilter = 'MESS_ONLY');
                  _fetchMasterRegister();
                }, activeColor: Colors.amber.shade800),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    bool isSelected,
    VoidCallback onTap, {
    Color? activeColor,
  }) {
    final color = activeColor ?? AppColors.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade400,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? color : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  Widget _buildRecordsList(bool isDark) {
    return RefreshIndicator(
      onRefresh: _fetchMasterRegister,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        itemCount: _records.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (ctx, idx) {
          final r = _records[idx] as Map<String, dynamic>;
          return _buildStudentRecordCard(r, isDark);
        },
      ),
    );
  }

  Widget _buildStudentRecordCard(Map<String, dynamic> r, bool isDark) {
    final isLeft = (r['status'] ?? '').toString().toUpperCase() == 'LEFT';
    final isHostel = (r['memberType'] ?? '') == 'HOSTEL_RESIDENT';
    final name = r['name']?.toString() ?? 'Unknown';
    final phone = r['phone']?.toString() ?? '-';
    final parentPhone = r['parentPhone']?.toString() ?? '';
    final parentName = r['parentName']?.toString() ?? '';
    final roomNo = r['roomNumber']?.toString() ?? '-';
    final bedNo = r['bedNo']?.toString() ?? '-';
    final admDate = AppFormatters.formatDate(r['admissionDate']?.toString());
    final leftDate = r['leftDate'] != null ? AppFormatters.formatDate(r['leftDate'].toString()) : null;
    final exitReason = r['exitReason']?.toString() ?? '';
    final photoUrl = r['photoUrl']?.toString() ?? '';

    final monthlyMess = PdfService.parseFloatSafe(r['monthlyMessFee']);
    final totalRent = PdfService.parseFloatSafe(r['totalRentAgreed'] ?? r['rentAmountPerTerm']);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isLeft
              ? Colors.grey.shade300
              : (isDark ? Colors.white12 : Colors.grey.shade200),
          width: 1,
        ),
      ),
      color: isDark
          ? (isLeft ? AppColors.surfaceDark.withValues(alpha: 0.6) : AppColors.surfaceDark)
          : (isLeft ? Colors.grey.shade50 : Colors.white),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Avatar, Name, Status & Category Badges
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAvatar(photoUrl, name, isLeft),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: isLeft ? Colors.grey.shade700 : null,
                              ),
                            ),
                          ),
                          // Status Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isLeft ? Colors.grey.shade200 : AppColors.success.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isLeft ? 'LEFT' : 'ACTIVE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isLeft ? Colors.grey.shade700 : AppColors.success,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          // Category Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isHostel ? Colors.indigo.withValues(alpha: 0.1) : Colors.amber.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isHostel ? Icons.hotel_rounded : Icons.restaurant_rounded,
                                  size: 11,
                                  color: isHostel ? Colors.indigo : Colors.amber.shade800,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isHostel ? 'Hostel Resident' : 'Outside Mess',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isHostel ? Colors.indigo : Colors.amber.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (isHostel)
                            Text(
                              'Room $roomNo • Bed $bedNo',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : Colors.grey.shade700,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // Middle Grid: Admission Date, Exit Date, Contacts, Fees
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow(Icons.calendar_today_rounded, 'Admitted: $admDate'),
                      if (isLeft && leftDate != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: _buildInfoRow(
                            Icons.exit_to_app_rounded,
                            'Left: $leftDate',
                            color: AppColors.warning,
                          ),
                        ),
                      if (isLeft && exitReason.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'Reason: $exitReason',
                            style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.grey),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isHostel && totalRent > 0)
                        _buildInfoRow(Icons.account_balance_wallet_outlined, 'Rent: ${AppFormatters.formatCurrency(totalRent)}'),
                      if ((!isHostel || r['enrolledInMess'] != false) && monthlyMess > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: _buildInfoRow(Icons.flatware_rounded, 'Mess: ${AppFormatters.formatCurrency(monthlyMess)}/mo'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Bottom Actions: Contact numbers with direct Call and WhatsApp
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _makePhoneCall(phone),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.phone_outlined, size: 14, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              phone,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (parentPhone.isNotEmpty)
                  Expanded(
                    child: InkWell(
                      onTap: () => _makePhoneCall(parentPhone),
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.family_restroom_rounded, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                parentName.isNotEmpty ? '$parentName ($parentPhone)' : 'Parent: $parentPhone',
                                style: TextStyle(fontSize: 10, color: isDark ? Colors.white70 : Colors.grey.shade700),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18, color: AppColors.success),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'WhatsApp Student',
                  onPressed: () => _openWhatsApp(phone, name),
                ),
                IconButton(
                  icon: const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.textSecondary),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'View Full Master Details',
                  onPressed: () => _showRecordDetailsModal(r),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String photoUrl, String name, bool isLeft) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final fallback = CircleAvatar(
      radius: 22,
      backgroundColor: isLeft ? Colors.grey.shade400 : AppColors.primary,
      child: Text(
        initial,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
      ),
    );

    return AppAvatarImage(
      photoUrl: photoUrl,
      width: 44,
      height: 44,
      isCircle: true,
      fit: BoxFit.cover,
      fallback: fallback,
    );
  }

  Widget _buildInfoRow(IconData icon, String text, {Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color ?? Colors.grey.shade600),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: TextStyle(fontSize: 11, color: color ?? Colors.grey.shade700),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  void _showRecordDetailsModal(Map<String, dynamic> r) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final isLeft = (r['status'] ?? '').toString().toUpperCase() == 'LEFT';
        final isHostel = (r['memberType'] ?? '') == 'HOSTEL_RESIDENT';

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('📜 Permanent Master Record', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),
              _buildDetailItem('Full Name', r['name']?.toString() ?? '-'),
              _buildDetailItem('Category', isHostel ? 'Hostel Resident' : 'Outside Mess Only Member'),
              _buildDetailItem('Status', isLeft ? 'LEFT / ARCHIVED' : 'ACTIVE CURRENTLY'),
              _buildDetailItem('Phone Number', r['phone']?.toString() ?? '-'),
              _buildDetailItem('Parent Name', r['parentName']?.toString() ?? '-'),
              _buildDetailItem('Parent Phone', r['parentPhone']?.toString() ?? '-'),
              if (isHostel) _buildDetailItem('Assigned Room & Bed', 'Room ${r['roomNumber'] ?? '-'}, Bed ${r['bedNo'] ?? '-'}'),
              _buildDetailItem('Admission Date', AppFormatters.formatDate(r['admissionDate']?.toString())),
              if (isLeft) _buildDetailItem('Departure / Left Date', AppFormatters.formatDate(r['leftDate']?.toString())),
              if (isLeft && (r['exitReason']?.toString() ?? '').isNotEmpty)
                _buildDetailItem('Exit Reason', r['exitReason'].toString()),
              if (isHostel) _buildDetailItem('Total Agreed Rent', AppFormatters.formatCurrency(r['totalRentAgreed'] ?? r['rentAmountPerTerm'] ?? 0)),
              _buildDetailItem('Monthly Mess Fee', AppFormatters.formatCurrency(r['monthlyMessFee'] ?? 0)),
              if ((r['notes']?.toString() ?? '').isNotEmpty)
                _buildDetailItem('Notes / History', r['notes'].toString()),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.close),
                  label: const Text('Close'),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_search_rounded, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text('No Master Student Records Found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(
            _searchCtrl.text.isNotEmpty || _statusFilter != 'ALL' || _typeFilter != 'ALL'
                ? 'Try resetting search query or filter chips'
                : 'Enrolled hostel residents and outside mess members will automatically appear here permanently.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.danger),
            const SizedBox(height: 12),
            Text('Error: $_error', textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: AppColors.danger)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              onPressed: _fetchMasterRegister,
            ),
          ],
        ),
      ),
    );
  }
}
