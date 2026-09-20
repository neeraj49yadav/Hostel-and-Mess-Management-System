import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_colors.dart';
import '../providers/auth_provider.dart';
import 'api_service.dart';
import 'pdf_service.dart';

class ExportDownloadService {
  static final ApiService _api = ApiService();

  /// Saves file directly to the device's public Download folder (on Android)
  /// and opens the print/preview or share sheet.
  static Future<String?> saveFileToDevice({
    required Uint8List bytes,
    required String filename,
    required BuildContext context,
    bool isPdf = false,
  }) async {
    String? savedPath;

    // 1. Save directly to Android storage if running natively
    if (!kIsWeb) {
      try {
        final downloadDirs = [
          Directory('/storage/emulated/0/Download'),
          Directory('/storage/emulated/0/Downloads'),
          Directory('/storage/emulated/0/Documents'),
        ];

        for (final dir in downloadDirs) {
          try {
            if (!dir.existsSync()) {
              dir.createSync(recursive: true);
            }
            if (dir.existsSync()) {
              final file = File('${dir.path}/$filename');
              await file.writeAsBytes(bytes, flush: true);
              savedPath = file.path;
              break;
            }
          } catch (e) {
            debugPrint('[ExportDownloadService] Error writing to ${dir.path}: $e');
          }
        }
      } catch (e) {
        debugPrint('[ExportDownloadService] Direct storage write failed: $e');
      }
    }

    // 2. Open layout preview (if PDF) or native share sheet
    try {
      if (isPdf) {
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => bytes,
          name: filename.replaceAll('.pdf', ''),
        );
      } else {
        await Printing.sharePdf(
          bytes: bytes,
          filename: filename,
        );
      }
    } catch (_) {}

    // 3. Show confirmation feedback
    if (context.mounted) {
      final messenger = ScaffoldMessenger.of(context);
      if (savedPath != null) {
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Saved to Device: $filename', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text('Path: $savedPath', style: const TextStyle(fontSize: 11, color: Colors.white70), overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text('✅ $filename generated successfully!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }

    return savedPath;
  }

  static bool _hasPromptedThisSession = false;

  /// Checks if the current year's 25th May annual backup has been saved to this device
  static Future<void> checkAndPromptAnnualBackup(BuildContext context) async {
    if (_hasPromptedThisSession) return;
    try {
      final now = DateTime.now();
      final currentYear = now.year;

      final may25 = DateTime(currentYear, 5, 25);
      if (now.isBefore(may25)) return;

      final prefs = await SharedPreferences.getInstance();
      final lastSavedYear = prefs.getInt('saved_annual_backup_year') ?? 0;

      if (lastSavedYear == currentYear) return;

      _hasPromptedThisSession = true;
      if (!context.mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.cloud_download_rounded, color: AppColors.primary, size: 28),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Annual Cloud Backup Ready',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'The annual cloud backup for year $currentYear (25th May) is ready.\n\nWould you like to save the Master Register and Combined Cashbook & P&L directly onto your device now?',
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('📁 Includes: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('• annual_master_data_$currentYear.csv (Excel Format)', style: const TextStyle(fontSize: 12)),
                    Text('• annual_cashbook_pnl_$currentYear.csv (Excel Format)', style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Later', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Save to Device'),
              onPressed: () async {
                Navigator.pop(ctx);
                await downloadAndSaveAnnualReports(context, currentYear);
              },
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('[ExportDownloadService] Check error: $e');
    }
  }

  /// Downloads both Master Data and Cashbook P&L and saves directly to local storage
  static Future<void> downloadAndSaveAnnualReports(BuildContext context, int year) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      messenger.showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
              SizedBox(width: 12),
              Text('Downloading annual reports from cloud...'),
            ],
          ),
          duration: Duration(seconds: 3),
        ),
      );

      // 1. Download Master Data CSV
      final masterCsv = await _api.downloadMasterDataCsv();
      final masterBytes = Uint8List.fromList(utf8.encode(masterCsv));
      if (!context.mounted) return;
      await saveFileToDevice(
        bytes: masterBytes,
        filename: 'annual_master_data_$year.csv',
        context: context,
        isPdf: false,
      );

      // 2. Download Cashbook & P&L CSV
      final cashbookCsv = await _api.downloadCashbookPnlCsv(year: year);
      final cashbookBytes = Uint8List.fromList(utf8.encode(cashbookCsv));
      if (!context.mounted) return;
      await saveFileToDevice(
        bytes: cashbookBytes,
        filename: 'annual_cashbook_pnl_$year.csv',
        context: context,
        isPdf: false,
      );

      // 3. Mark year as successfully saved on device
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('saved_annual_backup_year', year);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to download annual reports: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  /// Displays an on-demand modal bottom sheet to save Master Register, Cashbook & P&L,
  /// or Full Database Snapshot in both PDF and CSV/JSON formats directly to device.
  static void showBackupOptionsSheet(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final currentOrg = auth.currentOrganization;
    final hostelName = currentOrg?.name ?? 'Hostel & Mess';
    final orgCode = currentOrg?.code ?? 'HOSTEL';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.cloud_download_rounded, color: AppColors.primary, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Save Backups to Device',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Logged in: $hostelName ($orgCode)',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Files will be saved directly into your device\'s local storage (Downloads folder).',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),

                  // 1. MASTER REGISTER CARD
                  _buildExportCard(
                    context: sheetCtx,
                    isDark: isDark,
                    title: '1. Master Student Register',
                    subtitle: 'Lifetime roster of students, rooms, dues & fees',
                    icon: Icons.table_chart_rounded,
                    accentColor: const Color(0xFF10B981),
                    onPdfPressed: () async {
                      Navigator.pop(sheetCtx);
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        messenger.showSnackBar(const SnackBar(content: Text('Generating Master Register PDF...')));
                        final masterList = await _api.downloadMasterDataJson();
                        final totalCount = masterList.length;
                        final activeCount = masterList.where((r) => (r['status'] ?? 'ACTIVE') != 'LEFT').length;
                        final leftCount = totalCount - activeCount;
                        final hostelCount = masterList.where((r) => (r['memberType'] ?? '') == 'HOSTEL_RESIDENT').length;
                        final messCount = masterList.where((r) => r['isMessMember'] == true || r['enrolledInMess'] == true).length;

                        final pdfBytes = await PdfService.generateMasterRegisterPdf(
                          records: masterList,
                          stats: {
                            'total': totalCount,
                            'active': activeCount,
                            'left': leftCount,
                            'hostelResidents': hostelCount,
                            'messMembers': messCount,
                          },
                          hostelName: hostelName,
                        );

                        final dateTag = DateTime.now().toIso8601String().split('T')[0];
                        if (!context.mounted) return;
                        await saveFileToDevice(
                          bytes: pdfBytes,
                          filename: 'Master_Register_${orgCode}_$dateTag.pdf',
                          context: context,
                          isPdf: true,
                        );
                      } catch (e) {
                        if (context.mounted) {
                          messenger.showSnackBar(SnackBar(content: Text('Export failed: $e'), backgroundColor: AppColors.danger));
                        }
                      }
                    },
                    onDataPressed: () async {
                      Navigator.pop(sheetCtx);
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        messenger.showSnackBar(const SnackBar(content: Text('Downloading Master Register CSV...')));
                        final csv = await _api.downloadMasterDataCsv();
                        final dateTag = DateTime.now().toIso8601String().split('T')[0];
                        if (!context.mounted) return;
                        await saveFileToDevice(
                          bytes: Uint8List.fromList(utf8.encode(csv)),
                          filename: 'master_register_${orgCode}_$dateTag.csv',
                          context: context,
                          isPdf: false,
                        );
                      } catch (e) {
                        if (context.mounted) {
                          messenger.showSnackBar(SnackBar(content: Text('Export failed: $e'), backgroundColor: AppColors.danger));
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  // 2. CASHBOOK & P&L CARD
                  _buildExportCard(
                    context: sheetCtx,
                    isDark: isDark,
                    title: '2. Cashbook & Profit / Loss Statement',
                    subtitle: 'Clean summary of fees collected, mess expenses & net surplus',
                    icon: Icons.account_balance_wallet_rounded,
                    accentColor: const Color(0xFF3B82F6),
                    onPdfPressed: () async {
                      Navigator.pop(sheetCtx);
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        final yr = DateTime.now().year;
                        messenger.showSnackBar(SnackBar(content: Text('Generating Cashbook & P&L PDF for $yr...')));
                        final data = await _api.downloadCashbookPnlJson(year: yr);
                        final pdfBytes = await PdfService.generateCashbookPnlPdf(
                          data: data,
                          hostelName: hostelName,
                        );
                        if (!context.mounted) return;
                        await saveFileToDevice(
                          bytes: pdfBytes,
                          filename: 'Cashbook_PnL_${orgCode}_$yr.pdf',
                          context: context,
                          isPdf: true,
                        );
                      } catch (e) {
                        if (context.mounted) {
                          messenger.showSnackBar(SnackBar(content: Text('Export failed: $e'), backgroundColor: AppColors.danger));
                        }
                      }
                    },
                    onDataPressed: () async {
                      Navigator.pop(sheetCtx);
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        final yr = DateTime.now().year;
                        messenger.showSnackBar(SnackBar(content: Text('Downloading Cashbook & P&L CSV for $yr...')));
                        final csv = await _api.downloadCashbookPnlCsv(year: yr);
                        final bytes = Uint8List.fromList(utf8.encode(csv));
                        if (!context.mounted) return;
                        await saveFileToDevice(
                          bytes: bytes,
                          filename: 'cashbook_pnl_${orgCode}_$yr.csv',
                          context: context,
                          isPdf: false,
                        );
                      } catch (e) {
                        if (context.mounted) {
                          messenger.showSnackBar(SnackBar(content: Text('Export failed: $e'), backgroundColor: AppColors.danger));
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  // 3. FULL DATABASE SNAPSHOT CARD (SCOPED TO CURRENT HOSTEL)
                  _buildExportCard(
                    context: sheetCtx,
                    isDark: isDark,
                    title: '3. Full Database Snapshot',
                    subtitle: 'Complete backup strictly for $hostelName ($orgCode)',
                    icon: Icons.data_object_rounded,
                    accentColor: const Color(0xFF8B5CF6),
                    dataButtonLabel: 'Export JSON',
                    onPdfPressed: () async {
                      Navigator.pop(sheetCtx);
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        messenger.showSnackBar(const SnackBar(content: Text('Generating Database Snapshot PDF...')));
                        final jsonStr = await _api.downloadFullBackupJson();
                        final snapshot = jsonDecode(jsonStr) as Map<String, dynamic>;
                        final pdfBytes = await PdfService.generateDatabaseSnapshotPdf(
                          snapshot: snapshot,
                          hostelName: hostelName,
                        );
                        final dateTag = DateTime.now().toIso8601String().split('T')[0];
                        if (!context.mounted) return;
                        await saveFileToDevice(
                          bytes: pdfBytes,
                          filename: 'Database_Snapshot_${orgCode}_$dateTag.pdf',
                          context: context,
                          isPdf: true,
                        );
                      } catch (e) {
                        if (context.mounted) {
                          messenger.showSnackBar(SnackBar(content: Text('Export failed: $e'), backgroundColor: AppColors.danger));
                        }
                      }
                    },
                    onDataPressed: () async {
                      Navigator.pop(sheetCtx);
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        messenger.showSnackBar(const SnackBar(content: Text('Generating JSON database backup...')));
                        final jsonStr = await _api.downloadFullBackupJson();
                        final dateTag = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
                        final bytes = Uint8List.fromList(utf8.encode(jsonStr));
                        if (!context.mounted) return;
                        await saveFileToDevice(
                          bytes: bytes,
                          filename: 'database_backup_${orgCode}_$dateTag.json',
                          context: context,
                          isPdf: false,
                        );
                      } catch (e) {
                        if (context.mounted) {
                          messenger.showSnackBar(SnackBar(content: Text('Export failed: $e'), backgroundColor: AppColors.danger));
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static Widget _buildExportCard({
    required BuildContext context,
    required bool isDark,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onPdfPressed,
    required VoidCallback onDataPressed,
    String dataButtonLabel = 'Export Excel (CSV)',
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDarkSecondary : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onPdfPressed,
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                  label: const Text('Export PDF', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onDataPressed,
                  icon: Icon(dataButtonLabel.contains('JSON') ? Icons.data_object_rounded : Icons.table_chart_rounded, size: 16),
                  label: Text(dataButtonLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
