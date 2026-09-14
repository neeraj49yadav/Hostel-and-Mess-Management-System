import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/url_helper.dart';
import '../../models/vendor.dart';
import '../../providers/mess_provider.dart';

class VendorKhataScreen extends StatelessWidget {
  const VendorKhataScreen({super.key});

  void _showAddVendorDialog(BuildContext context, [Vendor? vendorToEdit]) {
    final nameCtrl = TextEditingController(text: vendorToEdit?.name ?? '');
    final phoneCtrl = TextEditingController(text: vendorToEdit?.phone ?? '');
    final addressCtrl = TextEditingController(text: vendorToEdit?.address ?? '');
    final balanceCtrl = TextEditingController(text: vendorToEdit != null ? vendorToEdit.pendingBalance.toStringAsFixed(0) : '0');
    String category = vendorToEdit?.category ?? 'MILK';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text(vendorToEdit != null ? 'Edit Vendor' : 'Add New Supplier / Vendor'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Supplier Name *')),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: category,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: const [
                        DropdownMenuItem(value: 'MILK', child: Text('🥛 Dairy / Milk')),
                        DropdownMenuItem(value: 'VEGETABLES', child: Text('🥬 Vegetables')),
                        DropdownMenuItem(value: 'RATION', child: Text('🌾 Ration & Grocery')),
                        DropdownMenuItem(value: 'GAS', child: Text('🔥 LPG Gas Agency')),
                        DropdownMenuItem(value: 'SPICES', child: Text('🧂 Spices')),
                        DropdownMenuItem(value: 'OTHER', child: Text('📦 Other')),
                      ],
                      onChanged: (v) {
                        if (v != null) setModalState(() => category = v);
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone Number')),
                    const SizedBox(height: 10),
                    TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Shop / Market Address')),
                    const SizedBox(height: 10),
                    TextField(controller: balanceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Pending Khata / Due Balance (₹)')),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    if (nameCtrl.text.isEmpty) return;
                    Navigator.pop(ctx);
                    final mess = context.read<MessProvider>();
                    await mess.saveVendor({
                      if (vendorToEdit != null) 'id': vendorToEdit.id,
                      'name': nameCtrl.text.trim(),
                      'category': category,
                      'phone': phoneCtrl.text.trim(),
                      'address': addressCtrl.text.trim(),
                      'pendingBalance': double.tryParse(balanceCtrl.text) ?? 0.0,
                    });
                  },
                  child: const Text('Save Supplier'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final mess = context.watch<MessProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final vendors = mess.vendors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendor Khata & Directory', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: isDark ? AppColors.secondaryLight : AppColors.secondary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_business_outlined),
        label: const Text('Add Supplier'),
        onPressed: () => _showAddVendorDialog(context),
      ),
      body: RefreshIndicator(
        onRefresh: () => mess.fetchVendors(),
        child: vendors.isEmpty
            ? Center(
                child: Text(
                  'No suppliers recorded',
                  style: TextStyle(color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: vendors.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final vendor = vendors[index];
                  final hasDues = vendor.pendingBalance > 0;

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    vendor.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                    ),
                                  ),
                                  Text(
                                    '${vendor.category} • ${vendor.address}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? AppColors.textMutedDark : AppColors.textSecondaryLight,
                                    ),
                                  ),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 20),
                                onPressed: () => _showAddVendorDialog(context, vendor),
                              ),
                            ],
                          ),
                          const Divider(height: 16),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Khata Balance (Owed to Vendor)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                                    ),
                                  ),
                                  Text(
                                    AppFormatters.formatCurrency(vendor.pendingBalance),
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: hasDues
                                          ? (isDark ? AppColors.dangerLight : AppColors.danger)
                                          : (isDark ? AppColors.successLight : AppColors.success),
                                    ),
                                  ),
                                ],
                              ),
                              if (vendor.phone.isNotEmpty)
                                Row(
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.call, color: isDark ? AppColors.primaryLight : AppColors.primary),
                                      onPressed: () => UrlHelper.launchPhoneCall(vendor.phone),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.chat, color: Color(0xFF25D366)),
                                      onPressed: () => UrlHelper.launchWhatsApp(
                                        phone: vendor.phone,
                                        message: 'Hello ${vendor.name}, regarding payment for mess supplies.',
                                      ),
                                    ),
                                  ],
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
    );
  }
}
