import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../services/api_service.dart';

class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _allLogs = [];
  List<Map<String, dynamic>> _filteredLogs = [];
  bool _isLoading = true;
  String _selectedFilter = 'ALL';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    try {
      final data = await _api.getAuditLogs();
      final nonPinLogs = data.where((log) {
        final action = (log['action'] ?? '').toString().toUpperCase();
        final type = (log['metadata']?['notificationType'] ?? '').toString();
        return !action.contains('PIN') && action != 'STAFF_PIN_CHANGED' && type != 'PIN_CHANGE_ALERT';
      }).toList();
      setState(() {
        _allLogs = nonPinLogs;
        _applyFilters();
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    final query = _searchCtrl.text.toLowerCase().trim();
    _filteredLogs = _allLogs.where((log) {
      final action = (log['action'] ?? '').toString().toUpperCase();
      final admin = (log['adminName'] ?? '').toString().toLowerCase();
      final details = (log['details'] ?? '').toString().toLowerCase();

      // Exclude PIN changes from audit log
      if (action.contains('PIN') || action == 'STAFF_PIN_CHANGED') {
        return false;
      }

      bool matchesType = true;
      if (_selectedFilter == 'DELETES') {
        matchesType = action.contains('DELETE') || action.contains('CHECKOUT');
      } else if (_selectedFilter == 'MESS') {
        matchesType = action.contains('MESS') || action.contains('VENDOR');
      } else if (_selectedFilter == 'FINANCE') {
        matchesType = action.contains('PAYMENT') || action.contains('FEE');
      } else if (_selectedFilter == 'STUDENTS') {
        matchesType = action.contains('STUDENT') || action.contains('BED') || action.contains('DEPARTURE') || action.contains('RETURN');
      }

      bool matchesSearch = query.isEmpty ||
          admin.contains(query) ||
          details.contains(query) ||
          action.toLowerCase().contains(query);

      return matchesType && matchesSearch;
    }).toList();
  }

  ActionStyle _getActionStyle(String? action, bool isDark) {
    switch (action?.toUpperCase()) {
      case 'DELETE_MESS_EXPENSE':
      case 'DELETE_STUDENT':
        return ActionStyle(
          label: 'DELETED',
          icon: Icons.delete_forever_rounded,
          color: isDark ? AppColors.dangerLight : AppColors.danger,
          bgColor: isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2),
        );
      case 'ADD_MESS_EXPENSE':
      case 'CREATE_VENDOR':
      case 'UPDATE_VENDOR':
      case 'ADD_MESS_MEMBER':
      case 'ENROLL_MESS_HOSTELITE':
        return ActionStyle(
          label: 'GROCERY / MESS',
          icon: Icons.restaurant_rounded,
          color: isDark ? AppColors.secondaryLight : AppColors.secondary,
          bgColor: isDark ? const Color(0xFF064E3B) : const Color(0xFFCCFBF1),
        );
      case 'RECORD_PAYMENT':
        return ActionStyle(
          label: 'PAYMENT',
          icon: Icons.payments_rounded,
          color: isDark ? AppColors.successLight : AppColors.success,
          bgColor: isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5),
        );
      case 'ADD_STUDENT':
      case 'UPDATE_STUDENT':
        return ActionStyle(
          label: 'RESIDENT',
          icon: Icons.person_rounded,
          color: isDark ? const Color(0xFF818CF8) : AppColors.primary,
          bgColor: isDark ? const Color(0xFF1E1B4B) : const Color(0xFFEEF2FF),
        );
      case 'SHIFT_BED':
        return ActionStyle(
          label: 'BED SHIFT',
          icon: Icons.swap_horiz_rounded,
          color: const Color(0xFFA78BFA),
          bgColor: isDark ? const Color(0xFF2E1065) : const Color(0xFFF3E8FF),
        );
      case 'CHECKOUT_STUDENT':
        return ActionStyle(
          label: 'CHECKOUT',
          icon: Icons.exit_to_app_rounded,
          color: const Color(0xFFFB923C),
          bgColor: isDark ? const Color(0xFF431407) : const Color(0xFFFFEDD5),
        );
      case 'RECORD_DEPARTURE':
      case 'RECORD_RETURN':
        return ActionStyle(
          label: 'IN / OUT',
          icon: Icons.door_front_door_rounded,
          color: const Color(0xFF38BDF8),
          bgColor: isDark ? const Color(0xFF082F49) : const Color(0xFFE0F2FE),
        );
      case 'ADMIN_LOGIN':
      case 'PIN_CHANGE':
        return ActionStyle(
          label: 'SECURITY',
          icon: Icons.shield_rounded,
          color: const Color(0xFFFBBF24),
          bgColor: isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7),
        );
      default:
        return ActionStyle(
          label: action ?? 'ACTION',
          icon: Icons.info_outline_rounded,
          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          bgColor: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Admin Audit Log', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Badge(
              label: Text('${_filteredLogs.length}'),
              backgroundColor: isDark ? AppColors.primaryLight : AppColors.primary,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Filter & Search Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: isDark ? AppColors.surfaceDark : Colors.white,
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search audit trail by admin, action, student...',
                    prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(_applyFilters);
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: isDark ? AppColors.surfaceDarkSecondary : AppColors.surfaceVariantLight,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  onChanged: (_) => setState(_applyFilters),
                ),
                const SizedBox(height: 10),

                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All Activities', 'ALL', isDark),
                      const SizedBox(width: 8),
                      _buildFilterChip('🗑️ Deletions', 'DELETES', isDark),
                      const SizedBox(width: 8),
                      _buildFilterChip('🍽️ Mess & Groceries', 'MESS', isDark),
                      const SizedBox(width: 8),
                      _buildFilterChip('💳 Payments', 'FINANCE', isDark),
                      const SizedBox(width: 8),
                      _buildFilterChip('👥 Residents & In/Out', 'STUDENTS', isDark),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadLogs,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredLogs.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.history_toggle_off_rounded, size: 64, color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
                              const SizedBox(height: 12),
                              Text(
                                'No matching audit records found',
                                style: TextStyle(color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredLogs.length,
                          separatorBuilder: (c, i) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final log = _filteredLogs[index];
                            final style = _getActionStyle(log['action']?.toString(), isDark);
                            final adminName = log['adminName'] ?? 'Admin';
                            final timestamp = AppFormatters.formatDateTime(log['timestamp']);

                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        // Action Badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: style.bgColor,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: style.color.withValues(alpha: 0.3)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(style.icon, size: 14, color: style.color),
                                              const SizedBox(width: 4),
                                              Text(
                                                style.label,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: style.color,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Timestamp
                                        Text(
                                          timestamp,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),

                                    // Action Details Text
                                    Text(
                                      log['details'] ?? '',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        height: 1.35,
                                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                      ),
                                    ),
                                    const SizedBox(height: 10),

                                    // Done By Whom (Admin Attribution Footer)
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: (isDark ? AppColors.primaryLight : AppColors.primary).withValues(alpha: 0.15),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.shield_outlined,
                                            size: 12,
                                            color: isDark ? AppColors.primaryLight : AppColors.primary,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Done By: ',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                                          ),
                                        ),
                                        Text(
                                          adminName,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? AppColors.primaryLight : AppColors.primary,
                                          ),
                                        ),
                                      ],
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
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, bool isDark) {
    final isSelected = _selectedFilter == value;
    final primaryColor = isDark ? AppColors.primaryLight : AppColors.primary;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: primaryColor.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected
            ? primaryColor
            : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
      ),
      onSelected: (_) {
        setState(() {
          _selectedFilter = value;
          _applyFilters();
        });
      },
    );
  }
}

class ActionStyle {
  final String label;
  final IconData icon;
  final Color color;
  final Color bgColor;

  ActionStyle({
    required this.label,
    required this.icon,
    required this.color,
    required this.bgColor,
  });
}

extension ListFilterExt<T> on List<T> {
  List<T> filter(bool Function(T item) test) => where(test).toList();
}
