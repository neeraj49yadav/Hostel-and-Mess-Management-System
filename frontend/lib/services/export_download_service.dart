import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_colors.dart';
import 'api_service.dart';

class ExportDownloadService {
  static final ApiService _api = ApiService();

  /// Saves or shares any export file (CSV, JSON, PDF) using native Android/iOS share sheet
  static Future<void> saveOrShareFile({
    required Uint8List bytes,
    required String filename,
  }) async {
    await Printing.sharePdf(
      bytes: bytes,
      filename: filename,
    );
  }

  static bool _hasPromptedThisSession = false;

  /// Checks if the current year's 25th May annual backup has been saved to this device
  static Future<void> checkAndPromptAnnualBackup(BuildContext context) async {
    if (_hasPromptedThisSession) return;
    try {
      final now = DateTime.now();
      final currentYear = now.year;

      // Only check if we are on or after 25th May of the year
      final may25 = DateTime(currentYear, 5, 25);
      if (now.isBefore(may25)) return;

      final prefs = await SharedPreferences.getInstance();
      final lastSavedYear = prefs.getInt('saved_annual_backup_year') ?? 0;

      if (lastSavedYear == currentYear) {
        // Already saved on this device for the current year
        return;
      }

      _hasPromptedThisSession = true;
      if (!context.mounted) return;

      // Show the Annual Backup Auto-Save Dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
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

  /// Downloads both Master Data and Cashbook P&L CSVs and opens the save/share sheet
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
      await saveOrShareFile(
        bytes: masterBytes,
        filename: 'annual_master_data_$year.csv',
      );

      // 2. Download Cashbook & P&L CSV
      final cashbookCsv = await _api.downloadCashbookPnlCsv(year: year);
      final cashbookBytes = Uint8List.fromList(utf8.encode(cashbookCsv));
      await saveOrShareFile(
        bytes: cashbookBytes,
        filename: 'annual_cashbook_pnl_$year.csv',
      );

      // 3. Mark year as successfully saved on device
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('saved_annual_backup_year', year);

      messenger.showSnackBar(
        SnackBar(
          content: Text('✅ Annual Backup for $year saved to your device successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to download annual reports: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  /// Displays an on-demand modal bottom sheet to save Master Data CSV, Cashbook P&L CSV, or JSON backup
  static void showBackupOptionsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.cloud_download_rounded, color: AppColors.primary, size: 26),
                    SizedBox(width: 10),
                    Text(
                      'Save Backups to Device',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Download offline CSV reports or full JSON backups directly to this device.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const Divider(height: 24),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.table_chart_rounded, color: Color(0xFF10B981)),
                  ),
                  title: const Text('Export Master Register (CSV)', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Students, mess members, rooms, dues & fees'),
                  onTap: () async {
                    Navigator.pop(sheetCtx);
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      messenger.showSnackBar(const SnackBar(content: Text('Downloading Master Data CSV...')));
                      final csv = await _api.downloadMasterDataCsv();
                      await saveOrShareFile(
                        bytes: Uint8List.fromList(utf8.encode(csv)),
                        filename: 'master_data_${DateTime.now().year}_${DateTime.now().month}_${DateTime.now().day}.csv',
                      );
                    } catch (e) {
                      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e'), backgroundColor: AppColors.danger));
                    }
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF3B82F6)),
                  ),
                  title: const Text('Export Cashbook & P&L (CSV)', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Income, mess expenses, net profit/loss'),
                  onTap: () async {
                    Navigator.pop(sheetCtx);
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      final yr = DateTime.now().year;
                      messenger.showSnackBar(SnackBar(content: Text('Downloading Cashbook & P&L for $yr...')));
                      final csv = await _api.downloadCashbookPnlCsv(year: yr);
                      await saveOrShareFile(
                        bytes: Uint8List.fromList(utf8.encode(csv)),
                        filename: 'cashbook_pnl_$yr.csv',
                      );
                    } catch (e) {
                      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e'), backgroundColor: AppColors.danger));
                    }
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.data_object_rounded, color: Color(0xFF8B5CF6)),
                  ),
                  title: const Text('Export Full Database Snapshot (JSON)', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Complete offline database snapshot'),
                  onTap: () async {
                    Navigator.pop(sheetCtx);
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      messenger.showSnackBar(const SnackBar(content: Text('Generating full JSON database backup...')));
                      final jsonStr = await _api.downloadFullBackupJson();
                      await saveOrShareFile(
                        bytes: Uint8List.fromList(utf8.encode(jsonStr)),
                        filename: 'database_backup_${DateTime.now().toIso8601String().replaceAll(':', '-')}.json',
                      );
                    } catch (e) {
                      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e'), backgroundColor: AppColors.danger));
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
