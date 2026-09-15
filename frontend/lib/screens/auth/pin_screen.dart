import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/organization.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_service.dart';
import '../home_shell.dart';

class PinScreen extends StatefulWidget {
  const PinScreen({super.key});

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  String _enteredPin = '';
  final int _pinLength = 4;

  void _onDigitPressed(String digit) {
    if (_enteredPin.length < _pinLength) {
      setState(() {
        _enteredPin += digit;
      });

      if (_enteredPin.length == _pinLength) {
        _verifyPin();
      }
    }
  }

  void _onDeletePressed() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      });
    }
  }

  void _onClearPressed() {
    setState(() {
      _enteredPin = '';
    });
  }

  Future<void> _verifyPin([String? pinToVerify]) async {
    final pin = pinToVerify ?? _enteredPin;
    final auth = context.read<AuthProvider>();
    final success = await auth.loginWithPin(pin);

    if (mounted) {
      if (success) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeShell()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(auth.errorMessage ?? 'Invalid Admin PIN. Please try again.'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() {
          _enteredPin = '';
        });
      }
    }
  }

  void _showRegisterOrgModal() {
    final auth = context.read<AuthProvider>();
    final orgNameCtrl = TextEditingController();
    final orgCodeCtrl = TextEditingController();
    final cityCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final adminNameCtrl = TextEditingController();
    final adminPhoneCtrl = TextEditingController();
    final pinCtrl = TextEditingController();
    final confirmPinCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;

          return Container(
            margin: EdgeInsets.only(
              top: MediaQuery.of(ctx).padding.top + 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.black12,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.primary, AppColors.accent],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.domain_add_rounded, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Register New Organization',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                ),
                              ),
                              Text(
                                'Create an isolated hostel or PG tenant',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppColors.textMutedDark : AppColors.textSecondaryLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const Divider(height: 28),

                    // Section 1: Organization Details
                    const Text(
                      '🏢 HOSTEL / PG DETAILS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: orgNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Organization / Hostel Name *',
                        hintText: 'e.g. Yaduvanshi Hostel & Mess',
                        prefixIcon: Icon(Icons.business_rounded),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter organization name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: orgCodeCtrl,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText: 'Org Code (Unique) *',
                              hintText: 'e.g. YADUVANSHI',
                              prefixIcon: Icon(Icons.tag_rounded),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Code required';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 4,
                          child: TextFormField(
                            controller: cityCtrl,
                            decoration: const InputDecoration(
                              labelText: 'City / Campus *',
                              hintText: 'e.g. City / Campus',
                              prefixIcon: Icon(Icons.location_on_rounded),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'City / Campus required';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Hostel Contact Phone',
                        hintText: 'e.g. 9876543210',
                        prefixIcon: Icon(Icons.phone_rounded),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Section 2: Primary Admin Account
                    const Text(
                      '🛡️ PRIMARY ADMIN / OWNER ACCOUNT',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: adminNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Primary Admin Name *',
                        hintText: 'e.g. Neeraj Yadav',
                        prefixIcon: Icon(Icons.person_rounded),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter admin name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: adminPhoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Admin Mobile Number',
                        hintText: 'e.g. 9811122233',
                        prefixIcon: Icon(Icons.phone_android_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: pinCtrl,
                            keyboardType: TextInputType.number,
                            obscureText: true,
                            maxLength: 4,
                            decoration: const InputDecoration(
                              labelText: '4-Digit PIN *',
                              hintText: '4-digits',
                              prefixIcon: Icon(Icons.lock_rounded),
                              counterText: '',
                            ),
                            validator: (val) {
                              if (val == null || val.trim().length != 4 || int.tryParse(val.trim()) == null) {
                                return '4 digits required';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: confirmPinCtrl,
                            keyboardType: TextInputType.number,
                            obscureText: true,
                            maxLength: 4,
                            decoration: const InputDecoration(
                              labelText: 'Confirm PIN *',
                              hintText: '4-digits',
                              prefixIcon: Icon(Icons.check_circle_outline_rounded),
                              counterText: '',
                            ),
                            validator: (val) {
                              if (val != pinCtrl.text) {
                                return 'PINs do not match';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 3,
                        ),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                if (formKey.currentState!.validate()) {
                                  setModalState(() => isSubmitting = true);
                                  final messenger = ScaffoldMessenger.of(context);
                                  final nav = Navigator.of(context);
                                  final success = await auth.registerOrganization(
                                    orgName: orgNameCtrl.text,
                                    orgCode: orgCodeCtrl.text,
                                    city: cityCtrl.text,
                                    contactPhone: phoneCtrl.text,
                                    adminName: adminNameCtrl.text,
                                    adminPhone: adminPhoneCtrl.text,
                                    adminPin: pinCtrl.text,
                                    adminRole: 'Chief Warden / Owner',
                                  );

                                  if (mounted) {
                                    setModalState(() => isSubmitting = false);
                                    if (success) {
                                      if (ctx.mounted) Navigator.pop(ctx);
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text('🎉 Organization "${orgNameCtrl.text.trim()}" registered! Welcome.'),
                                          backgroundColor: AppColors.success,
                                        ),
                                      );
                                      nav.pushReplacement(
                                        MaterialPageRoute(builder: (_) => const HomeShell()),
                                      );
                                    } else {
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(auth.errorMessage ?? 'Registration failed'),
                                          backgroundColor: AppColors.danger,
                                        ),
                                      );
                                    }
                                  }
                                }
                              },
                        child: isSubmitting
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  ),
                                  SizedBox(width: 12),
                                  Text('Creating Organization & Setting Up Data...'),
                                ],
                              )
                            : const Text(
                                '✨ Register & Launch Organization',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showJoinOrgDialog() async {
    final auth = context.read<AuthProvider>();
    await auth.loadOrganizations();
    final joinCodeCtrl = TextEditingController();
    final currentOrg = auth.currentOrganization;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.vpn_key_rounded, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Join by Organization Code', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (currentOrg != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Current: ${currentOrg.name} (${currentOrg.code})',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  const Text(
                    'Enter your hostel or organization unique code to connect and sign in:',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: joinCodeCtrl,
                    textCapitalization: TextCapitalization.characters,
                    autofocus: true,
                    style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
                    decoration: InputDecoration(
                      labelText: 'Organization Code',
                      hintText: 'e.g. YADUVANSHI',
                      prefixIcon: const Icon(Icons.vpn_key_rounded, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final code = joinCodeCtrl.text.trim().toUpperCase();
                if (code.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter an organization code'),
                      backgroundColor: AppColors.warning,
                    ),
                  );
                  return;
                }
                final orgs = auth.availableOrganizations;
                final matched = orgs.firstWhere(
                  (o) => o.code.toUpperCase() == code,
                  orElse: () => Organization(
                    id: 'org-$code',
                    name: 'Hostel ($code)',
                    code: code,
                    city: 'Joined',
                    contactPhone: '',
                  ),
                );
                final messenger = ScaffoldMessenger.of(context);
                await auth.selectOrganization(matched);
                if (mounted) {
                  if (ctx.mounted) Navigator.pop(ctx);
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Connected to Organization Code: $code'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              },
              child: const Text('Connect'),
            ),
          ],
        );
      },
    );
  }

  void _showForgotPinDialog() {
    final auth = context.read<AuthProvider>();
    final currentOrg = auth.currentOrganization;
    final phoneCtrl = TextEditingController();
    final pinCtrl = TextEditingController();
    final confirmPinCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.shield_outlined, color: AppColors.primary),
                SizedBox(width: 8),
                Text('Admin PIN Recovery', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 380,
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Enter the registered Primary Admin / Chief Warden mobile number to set a new 4-digit PIN for ${currentOrg != null ? currentOrg.name : 'this hostel'}:',
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 16),

                      // Registered Phone
                      TextFormField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'Registered Admin Mobile Number *',
                          hintText: 'e.g. 9811122233',
                          prefixIcon: const Icon(Icons.phone_android_rounded, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Please enter registered admin mobile number';
                          }
                          if (v.trim().replaceAll(RegExp(r'\D'), '').length < 10) {
                            return 'Enter a valid 10-digit mobile number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // New PIN
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: pinCtrl,
                              keyboardType: TextInputType.number,
                              obscureText: true,
                              maxLength: 4,
                              decoration: InputDecoration(
                                labelText: 'New 4-Digit PIN *',
                                counterText: '',
                                prefixIcon: const Icon(Icons.lock_rounded, size: 20),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().length != 4 || int.tryParse(v.trim()) == null) {
                                  return '4 digits';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: confirmPinCtrl,
                              keyboardType: TextInputType.number,
                              obscureText: true,
                              maxLength: 4,
                              decoration: InputDecoration(
                                labelText: 'Confirm PIN *',
                                counterText: '',
                                prefixIcon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                              validator: (v) {
                                if (v != pinCtrl.text) {
                                  return 'Does not match';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline_rounded, size: 18, color: AppColors.primary),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '🛡️ Staff / Wardens: Only the Primary Admin can reset their PIN from this login screen.\n\nStaff members can change their PIN from their Profile once logged in, or ask the Chief Warden to reset it.',
                                style: TextStyle(fontSize: 12, height: 1.35, color: AppColors.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (formKey.currentState!.validate()) {
                          setDialogState(() => isSubmitting = true);
                          final messenger = ScaffoldMessenger.of(context);
                          final res = await auth.forgotPin(
                            phone: phoneCtrl.text.trim(),
                            newPin: pinCtrl.text.trim(),
                          );
                          setDialogState(() => isSubmitting = false);

                          if (mounted) {
                            if (res['success'] == true) {
                              if (ctx.mounted) Navigator.pop(ctx);
                              setState(() {
                                _enteredPin = '';
                              });
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(res['message'] ?? 'PIN has been reset successfully!'),
                                  backgroundColor: AppColors.success,
                                  duration: const Duration(seconds: 4),
                                ),
                              );
                            } else {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(res['message'] ?? 'Failed to reset PIN'),
                                  backgroundColor: AppColors.danger,
                                ),
                              );
                            }
                          }
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Reset PIN'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showServerConfigDialog() async {
    final api = ApiService();
    final currentUrl = await api.baseUrl;
    final urlCtrl = TextEditingController(text: currentUrl);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.wifi_tethering_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Server Connection'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Configure the backend API URL for this device:',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlCtrl,
              decoration: const InputDecoration(
                labelText: 'Backend API Base URL',
                hintText: 'http://10.74.11.194:5000/api/v1',
              ),
            ),
            const SizedBox(height: 14),
            const Text('⚡ Quick Presets:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ActionChip(
                  label: const Text('Hotspot (10.20.35.194)', style: TextStyle(fontSize: 11)),
                  onPressed: () => urlCtrl.text = 'http://10.20.35.194:5000/api/v1',
                ),
                ActionChip(
                  label: const Text('Wi-Fi (10.74.11.194)', style: TextStyle(fontSize: 11)),
                  onPressed: () => urlCtrl.text = 'http://10.74.11.194:5000/api/v1',
                ),
                ActionChip(
                  label: const Text('Android Emulator', style: TextStyle(fontSize: 11)),
                  onPressed: () => urlCtrl.text = 'http://10.0.2.2:5000/api/v1',
                ),
                ActionChip(
                  label: const Text('Localhost (PC)', style: TextStyle(fontSize: 11)),
                  onPressed: () => urlCtrl.text = 'http://localhost:5000/api/v1',
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (urlCtrl.text.isNotEmpty) {
                final messenger = ScaffoldMessenger.of(context);
                await api.setBaseUrl(urlCtrl.text.trim());
                if (mounted) {
                  if (ctx.mounted) Navigator.pop(ctx);
                  messenger.showSnackBar(
                    SnackBar(content: Text('Server URL set to ${urlCtrl.text.trim()}'), backgroundColor: AppColors.success),
                  );
                }
              }
            },
            child: const Text('Save & Connect'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = context.watch<ThemeProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentOrg = auth.currentOrganization;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: InkWell(
          onTap: _showJoinOrgDialog,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDarkSecondary : AppColors.surfaceVariantLight,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.business_rounded, size: 15, color: AppColors.primary),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    currentOrg != null ? '${currentOrg.name} (${currentOrg.code})' : 'My Hostel & Mess',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_drop_down_rounded, size: 18, color: AppColors.primary),
              ],
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.add_business_rounded, size: 15, color: AppColors.primary),
              label: const Text(
                'Register',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                side: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.5),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _showRegisterOrgModal,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.wifi_tethering_rounded),
            tooltip: 'Server Connection Settings',
            onPressed: _showServerConfigDialog,
          ),
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: isDark ? Colors.amber : AppColors.textPrimaryLight,
            ),
            tooltip: isDark ? 'Light Mode' : 'Dark Mode',
            onPressed: () {
              theme.toggleTheme();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          // 🌊 App Logo Background Watermark (Seamless Blended Watermark Touching Bezels)
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: SizedBox(
                  width: double.infinity,
                  child: Opacity(
                    opacity: isDark ? 0.13 : 0.08,
                    child: Image.asset(
                      'assets/images/app_watermark.png',
                      fit: BoxFit.fitWidth,
                      alignment: Alignment.center,
                      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 🏨 Hostel Brand Logo
                    _buildHostelLogo(currentOrg, isDark),
                    const SizedBox(height: 14),

                    // 🏨 Hostel Name in Bold
                    Text(
                      currentOrg != null && currentOrg.name.isNotEmpty
                          ? currentOrg.name
                          : 'Hostel & Mess',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'PIN Security Access',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.textMutedDark : AppColors.primary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),

                // PIN Indicator Dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_pinLength, (index) {
                    final isFilled = index < _enteredPin.length;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      width: isFilled ? 18 : 14,
                      height: isFilled ? 18 : 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isFilled ? AppColors.primaryLight : Colors.transparent,
                        border: Border.all(
                          color: isFilled
                              ? AppColors.primaryLight
                              : (isDark ? AppColors.borderDark : AppColors.borderLight),
                          width: 2,
                        ),
                        boxShadow: isFilled
                            ? [
                                BoxShadow(
                                  color: AppColors.primaryLight.withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 24),

                // Numeric Keypad
                if (auth.isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: CircularProgressIndicator(),
                  )
                else
                  _buildKeypad(isDark),

                const SizedBox(height: 20),

                // Forgot PIN Action (Compact & Elegant)
                TextButton(
                  onPressed: _showForgotPinDialog,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.help_outline_rounded, size: 14, color: AppColors.primary),
                      SizedBox(width: 6),
                      Text(
                        'Forgot PIN?',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    ],
  ),
);
}

  Widget _buildHostelLogo(Organization? org, bool isDark) {
    final logo = org?.logo;
    final initial = (org != null && org.name.isNotEmpty) ? org.name[0].toUpperCase() : 'H';

    if (logo != null && logo.trim().isNotEmpty) {
      try {
        final cleanBase64 = logo.contains(',') ? logo.split(',')[1] : logo;
        final bytes = base64Decode(cleanBase64);
        return Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16.5),
            child: Image.memory(
              bytes,
              width: 72,
              height: 72,
              fit: BoxFit.cover,
              errorBuilder: (c, e, s) => _buildFallbackHostelBadge(initial, isDark),
            ),
          ),
        );
      } catch (_) {
        if (logo.startsWith('http')) {
          return Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16.5),
              child: Image.network(
                logo,
                width: 72,
                height: 72,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => _buildFallbackHostelBadge(initial, isDark),
              ),
            ),
          );
        }
      }
    }
    return _buildFallbackHostelBadge(initial, isDark);
  }

  Widget _buildFallbackHostelBadge(String initial, bool isDark) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: isDark ? 0.4 : 0.25),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: const Center(
        child: Icon(
          Icons.apartment_rounded,
          color: Colors.white,
          size: 38,
        ),
      ),
    );
  }

  Widget _buildKeypad(bool isDark) {
    return Column(
      children: [
        _buildKeyRow(['1', '2', '3'], isDark),
        const SizedBox(height: 12),
        _buildKeyRow(['4', '5', '6'], isDark),
        const SizedBox(height: 12),
        _buildKeyRow(['7', '8', '9'], isDark),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildSpecialKey('C', _onClearPressed, isDark: isDark),
            _buildDigitKey('0', isDark),
            _buildSpecialKey('⌫', _onDeletePressed, isIcon: true, isDark: isDark),
          ],
        ),
      ],
    );
  }

  Widget _buildKeyRow(List<String> digits, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map((d) => _buildDigitKey(d, isDark)).toList(),
    );
  }

  Widget _buildDigitKey(String digit, bool isDark) {
    return InkWell(
      onTap: () => _onDigitPressed(digit),
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 66,
        height: 66,
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          digit,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
        ),
      ),
    );
  }

  Widget _buildSpecialKey(String label, VoidCallback onTap, {bool isIcon = false, required bool isDark}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 66,
        height: 66,
        alignment: Alignment.center,
        child: isIcon
            ? Icon(
                Icons.backspace_outlined,
                color: isDark ? AppColors.textMutedDark : AppColors.textSecondaryLight,
                size: 20,
              )
            : Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.textMutedDark : AppColors.textSecondaryLight,
                ),
              ),
      ),
    );
  }
}

