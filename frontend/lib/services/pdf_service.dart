import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/payment.dart';
import '../core/utils/formatters.dart';

class PdfService {
  static String _cleanPdfText(String? text) {
    if (text == null) return '';
    return text.replaceAll('₹', 'Rs. ').trim();
  }

  static String _formatPdfCurrency(num? amount) {
    if (amount == null) return 'Rs. 0';
    final intVal = amount.toInt();
    final formatted = intVal.toString().replaceAllMapped(
      RegExp(r'(\d+?)(?=(\d\d)+(\d)(?!\d))(\.\d+)?'),
      (Match m) => '${m[1]},',
    );
    return 'Rs. $formatted';
  }

  static String _formatBillingCycle(Payment payment, {bool isRent = true}) {
    final start = payment.cycleStartDate.trim();
    final rawEnd = _cleanPdfText(payment.cycleEndDate);
    final targetMonth = payment.targetMonth.trim();
    final monthPrefix = targetMonth.isNotEmpty ? 'Billing Month: $targetMonth\n' : '';

    if (rawEnd.isEmpty) {
      return '$monthPrefix${start.isNotEmpty ? 'Date: $start' : '-'}';
    }

    // If rawEnd is a plain ISO date like 2026-10-12
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(rawEnd)) {
      return '$monthPrefix${start.isNotEmpty ? '$start to $rawEnd' : 'Valid till: $rawEnd'}';
    }

    // If rawEnd is a descriptive summary (e.g. "Hostel Rent: Fully Paid (Rs. 27000 received, Rs. 0 due)")
    if (start.isNotEmpty && !rawEnd.contains(start)) {
      return '$monthPrefix${start.isNotEmpty ? 'Payment Date: $start\n' : ''}$rawEnd';
    }
    return '$monthPrefix$rawEnd';
  }

  static Future<Uint8List> generateReceiptPdf(
    Payment payment, {
    String hostelName = 'Hostel & Mess',
  }) async {
    final pdf = pw.Document();
    final cleanHostelName = _cleanPdfText(hostelName);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Container(
                padding: const pw.EdgeInsets.only(bottom: 12),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 1)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          cleanHostelName,
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900,
                          ),
                        ),
                        pw.Text(
                          'Hostel & Mess Fee Receipt',
                          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          _cleanPdfText(payment.receiptNo),
                          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(
                          AppFormatters.formatDate(payment.paymentDate),
                          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),

              // Student Info Card
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Student / Member Name', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                        pw.Text(_cleanPdfText(payment.studentName), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Room / Member Type', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                        pw.Text(
                          payment.roomNumber.isNotEmpty ? 'Room ${_cleanPdfText(payment.roomNumber)}' : 'Outside Day Scholar',
                          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                        ),
                        if (payment.targetMonth.trim().isNotEmpty) ...[
                          pw.SizedBox(height: 2),
                          pw.Text('Billing Month: ${_cleanPdfText(payment.targetMonth)}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),

              // Fee Breakdown Table
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('Description', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('Billing Cycle & Details', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('Amount (Rs.)', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      ),
                    ],
                  ),
                  if (payment.rentAmount > 0)
                    pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Hostel Room Rent', style: const pw.TextStyle(fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(_formatBillingCycle(payment, isRent: true), style: const pw.TextStyle(fontSize: 8))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(_formatPdfCurrency(payment.rentAmount), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 9))),
                      ],
                    ),
                  if (payment.messAmount > 0)
                    pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Fixed Monthly Mess Subscription', style: const pw.TextStyle(fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(_formatBillingCycle(payment, isRent: false), style: const pw.TextStyle(fontSize: 8))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(_formatPdfCurrency(payment.messAmount), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 9))),
                      ],
                    ),
                  if (payment.rentAmount <= 0 && payment.messAmount <= 0)
                    pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Hostel / Mess Payment', style: const pw.TextStyle(fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(_formatBillingCycle(payment), style: const pw.TextStyle(fontSize: 8))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(_formatPdfCurrency(payment.amount), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 9))),
                      ],
                    ),
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Total Paid', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Mode: ${_cleanPdfText(payment.paymentMode)}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(_formatPdfCurrency(payment.amount), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900))),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // Footer & Signatures
              pw.Spacer(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Collected By: ${_cleanPdfText(payment.collectedByAdminName)}', style: const pw.TextStyle(fontSize: 9)),
                      pw.Text('Status: Verified & Confirmed', style: pw.TextStyle(fontSize: 8, color: PdfColors.green800, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.blue900, width: 1),
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Text('AUTHORIZED ADMIN SEAL', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text('Authorized Signature', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static Future<void> printReceipt(Payment payment, {String? hostelName}) async {
    final pdfBytes = await generateReceiptPdf(payment, hostelName: hostelName ?? 'Hostel & Mess');
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: '${payment.receiptNo}_${payment.studentName}',
    );
  }

  static Future<void> shareReceipt(Payment payment, {String? hostelName}) async {
    final pdfBytes = await generateReceiptPdf(payment, hostelName: hostelName ?? 'Hostel & Mess');
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: '${payment.receiptNo}.pdf',
    );
  }

  // 📜 Generate Master Register PDF (Hostel & Mess Historical Archive)
  static Future<Uint8List> generateMasterRegisterPdf({
    required List<dynamic> records,
    required Map<String, dynamic> stats,
    String hostelName = 'Hostel & Mess',
  }) async {
    final pdf = pw.Document();
    final cleanHostelName = _cleanPdfText(hostelName);
    final nowStr = AppFormatters.formatDate(DateTime.now().toIso8601String());

    final totalCount = stats['totalLifetimeCount'] ?? records.length;
    final activeCount = stats['activeCount'] ?? 0;
    final leftCount = stats['leftCount'] ?? 0;
    final hostelCount = stats['hostelCount'] ?? 0;
    final messCount = stats['messCount'] ?? 0;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        header: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 12),
            padding: const pw.EdgeInsets.only(bottom: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.blue900, width: 1.5)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      cleanHostelName,
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                    pw.Text(
                      'PERMANENT MASTER STUDENT & MEMBER REGISTER (HOSTEL & MESS ARCHIVE)',
                      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Report Date: $nowStr', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                    pw.Text('Lifetime Total: $totalCount records', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                  ],
                ),
              ],
            ),
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(top: 10),
            padding: const pw.EdgeInsets.only(top: 6),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Confidential Permanent Record • Non-Deletable Master Archive',
                  style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
                ),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          return [
            // KPI Summary Statistics Row
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 12),
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColors.blue200, width: 0.5),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _buildKpiPdfItem('Total Lifetime', '$totalCount', PdfColors.blue900),
                  _buildKpiPdfItem('Currently Active', '$activeCount', PdfColors.green800),
                  _buildKpiPdfItem('Left / Alumni', '$leftCount', PdfColors.grey700),
                  _buildKpiPdfItem('Hostel Residents', '$hostelCount', PdfColors.indigo800),
                  _buildKpiPdfItem('Mess Enrolled', '$messCount', PdfColors.amber900),
                ],
              ),
            ),

            // Master Register Table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: const {
                0: pw.FixedColumnWidth(26), // S.No
                1: pw.FlexColumnWidth(2.2), // Name
                2: pw.FlexColumnWidth(1.6), // Category
                3: pw.FlexColumnWidth(2.0), // Phone / Parent Phone
                4: pw.FlexColumnWidth(1.4), // Room & Bed
                5: pw.FlexColumnWidth(1.4), // Admission Date
                6: pw.FlexColumnWidth(2.2), // Status & Exit Info
                7: pw.FlexColumnWidth(1.8), // Fees / Agreed Rent
              },
              children: [
                // Table Header
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.blue900),
                  children: [
                    _buildTableHeaderCell('#'),
                    _buildTableHeaderCell('Student / Member Name'),
                    _buildTableHeaderCell('Category'),
                    _buildTableHeaderCell('Contact Info'),
                    _buildTableHeaderCell('Room / Bed'),
                    _buildTableHeaderCell('Admission'),
                    _buildTableHeaderCell('Status / Exit Record'),
                    _buildTableHeaderCell('Rent / Fee Plan'),
                  ],
                ),
                // Table Rows
                ...records.asMap().entries.map((entry) {
                  final idx = entry.key + 1;
                  final r = entry.value as Map<String, dynamic>;
                  final isEven = idx % 2 == 0;
                  final isLeft = (r['status'] ?? '').toString().toUpperCase() == 'LEFT';
                  final isHostel = (r['memberType'] ?? '') == 'HOSTEL_RESIDENT';

                  final name = _cleanPdfText(r['name']?.toString() ?? 'Unknown');
                  final phone = _cleanPdfText(r['phone']?.toString() ?? '-');
                  final parentPhone = _cleanPdfText(r['parentPhone']?.toString() ?? '');
                  final roomNo = _cleanPdfText(r['roomNumber']?.toString() ?? '-');
                  final bed = _cleanPdfText(r['bedNo']?.toString() ?? '-');
                  final admDate = AppFormatters.formatDate(r['admissionDate']?.toString());
                  final leftDate = r['leftDate'] != null ? AppFormatters.formatDate(r['leftDate'].toString()) : null;
                  final exitReason = _cleanPdfText(r['exitReason']?.toString() ?? '');

                  final monthlyMess = parseFloatSafe(r['monthlyMessFee']);
                  final totalRent = parseFloatSafe(r['totalRentAgreed'] ?? r['rentAmountPerTerm']);

                  String feeText = '';
                  if (isHostel) {
                    feeText = 'Rent: ${_formatPdfCurrency(totalRent)}';
                    if (r['enrolledInMess'] != false && monthlyMess > 0) {
                      feeText += '\nMess: ${_formatPdfCurrency(monthlyMess)}/mo';
                    }
                  } else {
                    feeText = 'Mess: ${_formatPdfCurrency(monthlyMess)}/mo';
                  }

                  return pw.TableRow(
                    decoration: pw.BoxDecoration(color: isEven ? PdfColors.grey100 : PdfColors.white),
                    children: [
                      _buildTableCell('$idx', align: pw.TextAlign.center),
                      _buildTableCell(
                        name,
                        bold: true,
                        color: isLeft ? PdfColors.grey700 : PdfColors.black,
                        subtext: r['notes'] != null && r['notes'].toString().isNotEmpty ? 'Note: ${_cleanPdfText(r['notes'].toString())}' : null,
                      ),
                      _buildTableCell(
                        isHostel ? 'Hostel Resident' : 'Outside Mess',
                        color: isHostel ? PdfColors.blue800 : PdfColors.amber900,
                        bold: true,
                      ),
                      _buildTableCell(
                        'P: $phone${parentPhone.isNotEmpty ? '\nGuard: $parentPhone' : ''}',
                      ),
                      _buildTableCell(
                        isHostel ? 'Room $roomNo\nBed $bed' : 'External\n(Day Scholar)',
                      ),
                      _buildTableCell(admDate),
                      _buildTableCell(
                        isLeft ? 'LEFT (${leftDate ?? '-'})' : 'ACTIVE',
                        bold: true,
                        color: isLeft ? PdfColors.red800 : PdfColors.green800,
                        subtext: isLeft && exitReason.isNotEmpty ? 'Reason: $exitReason' : null,
                      ),
                      _buildTableCell(feeText),
                    ],
                  );
                }),
              ],
            ),

            pw.SizedBox(height: 18),
            // Signatures block
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Generated by: Administrator / Chief Warden', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                    pw.Text('Official System Record', style: pw.TextStyle(fontSize: 8, color: PdfColors.blue900, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.blue900, width: 1),
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text('HOSTEL & MESS AUTHORIZED SEAL', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text('Authorized Warden Signature', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildKpiPdfItem(String title, String value, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(value, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: color)),
        pw.SizedBox(height: 2),
        pw.Text(title, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
      ],
    );
  }

  static pw.Widget _buildTableHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      ),
    );
  }

  static pw.Widget _buildTableCell(
    String text, {
    pw.TextAlign align = pw.TextAlign.left,
    bool bold = false,
    PdfColor color = PdfColors.black,
    String? subtext,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      child: pw.Column(
        crossAxisAlignment: align == pw.TextAlign.center ? pw.CrossAxisAlignment.center : pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            text,
            textAlign: align,
            style: pw.TextStyle(
              fontSize: 7.5,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: color,
            ),
          ),
          if (subtext != null && subtext.isNotEmpty)
            pw.Text(
              subtext,
              style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600),
            ),
        ],
      ),
    );
  }

  static num parseFloatSafe(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value;
    return num.tryParse(value.toString()) ?? 0;
  }

  static Future<void> printMasterRegister({
    required List<dynamic> records,
    required Map<String, dynamic> stats,
    String? hostelName,
  }) async {
    final pdfBytes = await generateMasterRegisterPdf(
      records: records,
      stats: stats,
      hostelName: hostelName ?? 'Hostel & Mess',
    );
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Master_Student_Register_${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  static Future<void> shareMasterRegister({
    required List<dynamic> records,
    required Map<String, dynamic> stats,
    String? hostelName,
  }) async {
    final pdfBytes = await generateMasterRegisterPdf(
      records: records,
      stats: stats,
      hostelName: hostelName ?? 'Hostel & Mess',
    );
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'Master_Register_${DateTime.now().toIso8601String().split('T')[0]}.pdf',
    );
  }

  // 💰 Generate Clean Cashbook & Profit & Loss Statement PDF
  static Future<Uint8List> generateCashbookPnlPdf({
    required Map<String, dynamic> data,
    String hostelName = 'Hostel & Mess',
  }) async {
    final pdf = pw.Document();
    final cleanHostelName = _cleanPdfText(hostelName);
    final summary = data['profitAndLossSummary'] as Map<String, dynamic>? ?? {};
    final transactions = (data['transactions'] as List<dynamic>? ?? []);
    final year = data['reportingYear']?.toString() ?? 'ALL_TIME';
    final reportDate = data['reportDate']?.toString() ?? DateTime.now().toIso8601String().split('T')[0];

    final totalInflow = parseFloatSafe(summary['totalInflow']);
    final totalOutflow = parseFloatSafe(summary['totalOutflow']);
    final netProfit = parseFloatSafe(summary['netProfitOrLoss']);
    final rentInflow = parseFloatSafe(summary['rentInflow']);
    final messInflow = parseFloatSafe(summary['messInflow']);
    final depositInflow = parseFloatSafe(summary['depositInflow']);
    final otherInflow = parseFloatSafe(summary['otherInflow']);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        header: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 12),
            padding: const pw.EdgeInsets.only(bottom: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.blue800, width: 1.5)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      cleanHostelName,
                      style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Combined Cashbook & Profit & Loss Statement (Period: $year)',
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Report Date: $reportDate', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                    pw.Text(
                      'Total Txns: ${transactions.length}',
                      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(top: 10),
            padding: const pw.EdgeInsets.only(top: 6),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Financial Statement • $cleanHostelName',
                  style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
                ),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          return [
            // KPI Summary Cards
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 12),
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _buildKpiPdfItem('Total Inflow', _formatPdfCurrency(totalInflow), PdfColors.green800),
                  _buildKpiPdfItem('Total Outflow', _formatPdfCurrency(totalOutflow), PdfColors.red800),
                  _buildKpiPdfItem(
                    netProfit >= 0 ? 'Net Surplus (Profit)' : 'Net Deficit (Loss)',
                    _formatPdfCurrency(netProfit.abs()),
                    netProfit >= 0 ? PdfColors.green900 : PdfColors.red900,
                  ),
                ],
              ),
            ),

            // Inflow breakdown
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 12),
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColors.blue100, width: 0.5),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  pw.Text('Rent: ${_formatPdfCurrency(rentInflow)}', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text('Mess: ${_formatPdfCurrency(messInflow)}', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text('Deposits: ${_formatPdfCurrency(depositInflow)}', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text('Other: ${_formatPdfCurrency(otherInflow)}', style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
            ),

            // Transactions Table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: const {
                0: pw.FixedColumnWidth(24),  // #
                1: pw.FixedColumnWidth(55),  // Date
                2: pw.FixedColumnWidth(48),  // Type
                3: pw.FlexColumnWidth(2.5),  // Particulars
                4: pw.FixedColumnWidth(44),  // Mode
                5: pw.FixedColumnWidth(60),  // Inflow
                6: pw.FixedColumnWidth(60),  // Outflow
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.blue900),
                  children: [
                    _buildTableHeaderCell('#'),
                    _buildTableHeaderCell('Date'),
                    _buildTableHeaderCell('Flow'),
                    _buildTableHeaderCell('Particulars / Resident / Vendor'),
                    _buildTableHeaderCell('Mode'),
                    _buildTableHeaderCell('Inflow'),
                    _buildTableHeaderCell('Outflow'),
                  ],
                ),
                ...transactions.asMap().entries.map((entry) {
                  final idx = entry.key + 1;
                  final t = entry.value as Map<String, dynamic>;
                  final date = (t['date'] ?? '').toString().split('T')[0];
                  final type = (t['type'] ?? '').toString().toUpperCase();
                  final party = _cleanPdfText(t['party']?.toString() ?? '');
                  final mode = (t['paymentMode'] ?? 'CASH').toString();
                  final inflow = parseFloatSafe(t['inflow'] ?? (type == 'INFLOW' ? t['amount'] : 0));
                  final outflow = parseFloatSafe(t['outflow'] ?? (type == 'OUTFLOW' ? t['amount'] : 0));
                  final isEven = idx % 2 == 0;

                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: isEven ? PdfColors.grey100 : PdfColors.white,
                    ),
                    children: [
                      _buildTableCell('$idx', align: pw.TextAlign.center),
                      _buildTableCell(date),
                      _buildTableCell(
                        type,
                        bold: true,
                        color: type == 'INFLOW' ? PdfColors.green800 : PdfColors.red800,
                      ),
                      _buildTableCell(party),
                      _buildTableCell(mode, align: pw.TextAlign.center),
                      _buildTableCell(
                        inflow > 0 ? _formatPdfCurrency(inflow) : '-',
                        align: pw.TextAlign.right,
                        color: PdfColors.green800,
                      ),
                      _buildTableCell(
                        outflow > 0 ? _formatPdfCurrency(outflow) : '-',
                        align: pw.TextAlign.right,
                        color: PdfColors.red800,
                      ),
                    ],
                  );
                }),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  // 🗄️ Generate Full Database Snapshot PDF (Scoped to Logged-in Hostel)
  static Future<Uint8List> generateDatabaseSnapshotPdf({
    required Map<String, dynamic> snapshot,
    String hostelName = 'Hostel & Mess',
  }) async {
    final pdf = pw.Document();
    final org = snapshot['organization'] as Map<String, dynamic>? ?? {};
    final cleanHostelName = _cleanPdfText(org['name']?.toString() ?? hostelName);
    final orgCode = org['code']?.toString() ?? '';
    final city = org['city']?.toString() ?? '';
    final phone = org['contactPhone']?.toString() ?? '';
    final exportedAt = (snapshot['exportedAt'] ?? DateTime.now().toIso8601String()).toString().split('T')[0];

    final students = (snapshot['students'] as List<dynamic>? ?? []);
    final rooms = (snapshot['rooms'] as List<dynamic>? ?? []);
    final payments = (snapshot['payments'] as List<dynamic>? ?? []);
    final expenses = (snapshot['mess_expenses'] as List<dynamic>? ?? []);
    final admins = (snapshot['admins'] as List<dynamic>? ?? []);

    final activeCount = students.where((s) => (s['status'] ?? 'ACTIVE') != 'ARCHIVED').length;
    final totalPaymentsAmt = payments.fold<double>(0, (acc, p) => acc + (parseFloatSafe(p['amount'])).toDouble());
    final totalExpensesAmt = expenses.fold<double>(0, (acc, e) => acc + (parseFloatSafe(e['amount'])).toDouble());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        header: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 12),
            padding: const pw.EdgeInsets.only(bottom: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.indigo900, width: 1.5)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      cleanHostelName,
                      style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Complete Database Snapshot Report • Code: $orgCode • $city',
                      style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Export Date: $exportedAt', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                    if (phone.isNotEmpty)
                      pw.Text('Contact: $phone', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
                  ],
                ),
              ],
            ),
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(top: 10),
            padding: const pw.EdgeInsets.only(top: 6),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Confidential Database Snapshot • $cleanHostelName ($orgCode)',
                  style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
                ),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          return [
            // KPI Summary Row
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 12),
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: pw.BoxDecoration(
                color: PdfColors.indigo50,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColors.indigo200, width: 0.5),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _buildKpiPdfItem('Total Students', '${students.length}', PdfColors.indigo900),
                  _buildKpiPdfItem('Active Residents', '$activeCount', PdfColors.green800),
                  _buildKpiPdfItem('Rooms Configured', '${rooms.length}', PdfColors.blue800),
                  _buildKpiPdfItem('Total Collections', _formatPdfCurrency(totalPaymentsAmt), PdfColors.teal900),
                  _buildKpiPdfItem('Total Expenses', _formatPdfCurrency(totalExpensesAmt), PdfColors.red900),
                  _buildKpiPdfItem('Admins', '${admins.length}', PdfColors.purple900),
                ],
              ),
            ),

            // Section 1: Students Roster
            pw.Container(
              margin: const pw.EdgeInsets.only(top: 4, bottom: 6),
              child: pw.Text(
                'STUDENT & RESIDENT ROSTER (${students.length} Records)',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900),
              ),
            ),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: const {
                0: pw.FixedColumnWidth(24),
                1: pw.FlexColumnWidth(2.2),
                2: pw.FixedColumnWidth(65),
                3: pw.FixedColumnWidth(40),
                4: pw.FixedColumnWidth(30),
                5: pw.FixedColumnWidth(48),
                6: pw.FixedColumnWidth(55),
                7: pw.FixedColumnWidth(55),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.indigo900),
                  children: [
                    _buildTableHeaderCell('#'),
                    _buildTableHeaderCell('Name'),
                    _buildTableHeaderCell('Mobile'),
                    _buildTableHeaderCell('Room'),
                    _buildTableHeaderCell('Bed'),
                    _buildTableHeaderCell('Status'),
                    _buildTableHeaderCell('Joined'),
                    _buildTableHeaderCell('Rent/Fee'),
                  ],
                ),
                ...students.asMap().entries.map((entry) {
                  final idx = entry.key + 1;
                  final s = entry.value as Map<String, dynamic>;
                  final name = _cleanPdfText(s['name']?.toString() ?? '');
                  final phone = s['phone']?.toString() ?? '';
                  final room = s['roomNumber']?.toString() ?? '-';
                  final bed = s['bedNo']?.toString() ?? '-';
                  final status = (s['status'] ?? 'ACTIVE').toString().toUpperCase();
                  final joined = (s['admissionDate'] ?? s['createdAt'] ?? '').toString().split('T')[0];
                  final rent = parseFloatSafe(s['agreedRent'] ?? s['totalRentAgreed'] ?? s['monthlyMessFee'] ?? 0);
                  final isEven = idx % 2 == 0;

                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: isEven ? PdfColors.grey100 : PdfColors.white,
                    ),
                    children: [
                      _buildTableCell('$idx', align: pw.TextAlign.center),
                      _buildTableCell(name, bold: true),
                      _buildTableCell(phone),
                      _buildTableCell(room, align: pw.TextAlign.center),
                      _buildTableCell(bed, align: pw.TextAlign.center),
                      _buildTableCell(status, align: pw.TextAlign.center, color: status == 'ACTIVE' ? PdfColors.green800 : PdfColors.grey700),
                      _buildTableCell(joined),
                      _buildTableCell(_formatPdfCurrency(rent), align: pw.TextAlign.right),
                    ],
                  );
                }),
              ],
            ),

            // Section 2: Recent Payments Summary
            if (payments.isNotEmpty) ...[
              pw.SizedBox(height: 14),
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 6),
                child: pw.Text(
                  'RECENT PAYMENT TRANSACTIONS (${payments.length} Records)',
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900),
                ),
              ),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                columnWidths: const {
                  0: pw.FixedColumnWidth(24),
                  1: pw.FixedColumnWidth(55),
                  2: pw.FlexColumnWidth(2.2),
                  3: pw.FixedColumnWidth(55),
                  4: pw.FixedColumnWidth(50),
                  5: pw.FixedColumnWidth(60),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.teal800),
                    children: [
                      _buildTableHeaderCell('#'),
                      _buildTableHeaderCell('Date'),
                      _buildTableHeaderCell('Resident'),
                      _buildTableHeaderCell('Receipt'),
                      _buildTableHeaderCell('Mode'),
                      _buildTableHeaderCell('Amount'),
                    ],
                  ),
                  ...payments.take(50).toList().asMap().entries.map((entry) {
                    final idx = entry.key + 1;
                    final p = entry.value as Map<String, dynamic>;
                    final date = (p['paymentDate'] ?? p['createdAt'] ?? '').toString().split('T')[0];
                    final student = _cleanPdfText(p['studentName']?.toString() ?? 'Student');
                    final receipt = p['receiptNo']?.toString() ?? '-';
                    final mode = (p['paymentMode'] ?? 'CASH').toString();
                    final amt = parseFloatSafe(p['amount']);
                    final isEven = idx % 2 == 0;

                    return pw.TableRow(
                      decoration: pw.BoxDecoration(color: isEven ? PdfColors.grey100 : PdfColors.white),
                      children: [
                        _buildTableCell('$idx', align: pw.TextAlign.center),
                        _buildTableCell(date),
                        _buildTableCell(student),
                        _buildTableCell(receipt),
                        _buildTableCell(mode, align: pw.TextAlign.center),
                        _buildTableCell(_formatPdfCurrency(amt), align: pw.TextAlign.right, bold: true, color: PdfColors.teal900),
                      ],
                    );
                  }),
                ],
              ),
            ],
          ];
        },
      ),
    );

    return pdf.save();
  }
}

