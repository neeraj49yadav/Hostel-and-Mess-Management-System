import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/mess_provider.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _vendorNameController = TextEditingController();
  final _notesController = TextEditingController();

  String _category = 'MILK';
  String _paymentMode = 'CASH';
  DateTime _date = DateTime.now();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _vendorNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _quickFillTitle(String title, String category) {
    setState(() {
      _titleController.text = title;
      _category = category;
    });
  }

  Future<void> _submitExpense() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final auth = context.read<AuthProvider>();
    final mess = context.read<MessProvider>();

    final payload = {
      'title': _titleController.text.trim(),
      'category': _category,
      'amount': double.tryParse(_amountController.text) ?? 0.0,
      'date': _date.toIso8601String().split('T')[0],
      'vendorName': _vendorNameController.text.trim(),
      'paymentMode': _paymentMode,
      'notes': _notesController.text.trim(),
      'adminId': auth.currentAdmin?.id ?? 'admin-3',
      'adminName': auth.currentAdmin?.name ?? 'Mess In-charge',
    };

    final success = await mess.addExpense(payload);

    setState(() => _isSubmitting = false);

    if (mounted) {
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kitchen expense logged!'), backgroundColor: AppColors.success),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mess.error ?? 'Failed to log expense'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Kitchen / Grocery Expense', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Quick suggestions
            const Text('⚡ Quick Templates', style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildQuickTag('🥛 Daily Milk (40L)', 'MILK'),
                  const SizedBox(width: 8),
                  _buildQuickTag('🥬 Weekly Vegetables', 'VEGETABLES'),
                  const SizedBox(width: 8),
                  _buildQuickTag('🔥 Gas Cylinder (19kg)', 'GAS'),
                  const SizedBox(width: 8),
                  _buildQuickTag('🌾 Monthly Ration Rice/Atta', 'RATION'),
                  const SizedBox(width: 8),
                  _buildQuickTag('🧂 Spices & Cooking Oil', 'SPICES'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Expense Item Description *',
                hintText: 'e.g., 40 Litres Full Cream Milk',
                prefixIcon: Icon(Icons.description_outlined),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Description is required' : null,
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _category,
                    decoration: const InputDecoration(labelText: 'Category *', prefixIcon: Icon(Icons.category_outlined)),
                    items: const [
                      DropdownMenuItem(value: 'MILK', child: Text('🥛 Milk / Dairy')),
                      DropdownMenuItem(value: 'VEGETABLES', child: Text('🥬 Vegetables & Fruits')),
                      DropdownMenuItem(value: 'RATION', child: Text('🌾 Ration, Grains & Atta')),
                      DropdownMenuItem(value: 'GAS', child: Text('🔥 LPG Gas Cylinders')),
                      DropdownMenuItem(value: 'SPICES', child: Text('🧂 Spices, Oil & Salt')),
                      DropdownMenuItem(value: 'MAINTENANCE', child: Text('🛠️ Kitchen Maintenance')),
                      DropdownMenuItem(value: 'OTHER', child: Text('📦 Other Purchases')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _category = val);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Amount (₹) *',
                      prefixText: '₹ ',
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Amount required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _paymentMode,
                    decoration: const InputDecoration(labelText: 'Payment Mode', prefixIcon: Icon(Icons.payment_outlined)),
                    items: const [
                      DropdownMenuItem(value: 'CASH', child: Text('💵 Cash')),
                      DropdownMenuItem(value: 'UPI', child: Text('📱 UPI (GPay/PhonePe)')),
                      DropdownMenuItem(value: 'BANK_TRANSFER', child: Text('🏦 Bank Transfer')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _paymentMode = val);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    readOnly: true,
                    controller: TextEditingController(
                      text: '${_date.day}/${_date.month}/${_date.year}',
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Purchase Date',
                      prefixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime(2025),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) setState(() => _date = picked);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _vendorNameController,
              decoration: const InputDecoration(
                labelText: 'Vendor / Supplier Name',
                hintText: 'e.g., Shree Krishna Dairy / Wholesale Mandi',
                prefixIcon: Icon(Icons.storefront_outlined),
              ),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notes / Quantity (Optional)',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
            ),
            const SizedBox(height: 32),

            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitExpense,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Save Expense Entry'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickTag(String title, String category) {
    return ActionChip(
      label: Text(title, style: const TextStyle(fontSize: 12)),
      onPressed: () => _quickFillTitle(title, category),
    );
  }
}
