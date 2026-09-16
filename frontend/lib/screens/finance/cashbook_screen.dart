import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../providers/auth_provider.dart';
import '../../providers/hostel_provider.dart';
import '../../providers/dashboard_provider.dart';

class CashbookScreen extends StatefulWidget {
  const CashbookScreen({super.key});

  @override
  State<CashbookScreen> createState() => _CashbookScreenState();
}

class _CashbookScreenState extends State<CashbookScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().fetchCashbook();
    });
  }

  Future<void> _confirmReversePayment(Map<String, dynamic> t) async {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final paymentId = t['id']?.toString() ?? '';
    final receiptNo = t['receiptNo'] ?? '';
    final amount = (t['amount'] as num?)?.toDouble() ?? 0.0;

    if (paymentId.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 28),
            SizedBox(width: 8),
            Text('Reverse Inflow Payment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to reverse & delete payment receipt #$receiptNo of ${AppFormatters.formatCurrency(amount)}?',
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
                  '⚠️ This rolls back the student\'s paid balance and recalculates validity. An immutable audit log entry will be created.',
                  style: TextStyle(fontSize: 12, color: AppColors.danger, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason for Reversal *',
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
      final dash = context.read<DashboardProvider>();
      final adminName = auth.currentAdmin?.name ?? 'Admin';

      final success = await hostel.deletePayment(
        paymentId,
        reason: reasonController.text.trim(),
        adminName: adminName,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Inflow payment reversed successfully. Audit record created.'),
              backgroundColor: AppColors.success,
            ),
          );
          dash.fetchCashbook();
          dash.fetchDashboardStats();
          dash.fetchDuesAndExpiries();
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

  @override
  Widget build(BuildContext context) {
    final dash = context.watch<DashboardProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cashData = dash.cashbookData;

    final totalInflow = (cashData?['totalInflow'] as num?)?.toDouble() ?? 0.0;
    final totalOutflow = (cashData?['totalOutflow'] as num?)?.toDouble() ?? 0.0;
    final netCashflow = (cashData?['netCashflow'] as num?)?.toDouble() ?? 0.0;
    final rawTransactions = cashData?['transactions'] as List? ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Combined Cashbook & P&L', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // P&L Summary Dashboard Banner
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Inflow (Rent + Mess)',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            AppFormatters.formatCurrency(totalInflow),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.successLight : AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      height: 36,
                      width: 1,
                      color: isDark ? AppColors.borderDark : AppColors.borderLight,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Outflow (Kitchen)',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              AppFormatters.formatCurrency(totalOutflow),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.dangerLight : AppColors.danger,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Net In-Hand Balance:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      ),
                    ),
                    Text(
                      AppFormatters.formatCurrency(netCashflow),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: netCashflow >= 0
                            ? (isDark ? AppColors.successLight : AppColors.success)
                            : (isDark ? AppColors.dangerLight : AppColors.danger),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Transactions Timeline
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Recent Inflow & Outflow Timeline',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),

          Expanded(
            child: RefreshIndicator(
              onRefresh: () => dash.fetchCashbook(),
              child: rawTransactions.isEmpty
                  ? Center(
                      child: Text(
                        'No transactions recorded yet',
                        style: TextStyle(
                          color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: rawTransactions.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final t = rawTransactions[index];
                        final isInflow = t['type'] == 'INFLOW';
                        final inColor = isDark ? AppColors.successLight : AppColors.success;
                        final outColor = isDark ? AppColors.dangerLight : AppColors.danger;

                        return Card(
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: (isInflow ? inColor : outColor).withValues(alpha: isDark ? 0.25 : 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isInflow ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                                color: isInflow ? inColor : outColor,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              t['title'] ?? '',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 2),
                                Text(
                                  '${t["category"]} via ${t["paymentMode"]} on ${AppFormatters.formatDate(t["date"])}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? AppColors.textMutedDark : AppColors.textSecondaryLight,
                                  ),
                                ),
                                if (isInflow && t['targetMonth'] != null && t['targetMonth'].toString().isNotEmpty)
                                  Text(
                                    'Billing Month: ${t["targetMonth"]}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? AppColors.primaryLight : AppColors.primary,
                                    ),
                                  ),
                                Text(
                                  'By: ${t["recordedBy"]}${t["receiptNo"] != null ? " • Receipt #${t["receiptNo"]}" : ""}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? AppColors.textMutedDark : AppColors.textSecondaryLight,
                                  ),
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${isInflow ? "+" : "-"}${AppFormatters.formatCurrency(t["amount"])}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: isInflow ? inColor : outColor,
                                  ),
                                ),
                                if (isInflow) ...[
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 20),
                                    tooltip: 'Reverse Payment',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => _confirmReversePayment(t),
                                  ),
                                ],
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
}
