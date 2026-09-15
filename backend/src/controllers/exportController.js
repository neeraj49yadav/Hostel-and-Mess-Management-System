const fs = require('fs');
const path = require('path');
const db = require('../config/db');
const { extractOrgId } = require('../middleware/authMiddleware');
const { logAudit } = require('../services/auditService');

const BACKUP_DIR = path.join(__dirname, '../../data/backups');
if (!fs.existsSync(BACKUP_DIR)) {
  try {
    fs.mkdirSync(BACKUP_DIR, { recursive: true });
  } catch (_) {}
}

/**
 * Helper to escape CSV cell contents
 */
function escapeCsvCell(val) {
  if (val === null || val === undefined) return '""';
  const str = String(val).replace(/"/g, '""');
  return `"${str}"`;
}

/**
 * 1. Full Offline System Backup (JSON Export)
 */
exports.exportFullBackup = (req, res) => {
  try {
    const orgId = extractOrgId(req);
    const dbData = db.read();
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const filename = `hostel_full_backup_${timestamp}.json`;

    logAudit({
      req,
      action: 'EXPORT_FULL_BACKUP',
      details: `Admin exported complete offline system backup archive (${filename})`,
      adminName: req.admin ? req.admin.name : 'Admin'
    });

    res.setHeader('Content-Type', 'application/json');
    res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
    return res.send(JSON.stringify(dbData, null, 2));
  } catch (err) {
    console.error('Error generating full backup:', err);
    return res.status(500).json({ success: false, message: err.message });
  }
};

/**
 * 2. Export Master Data (On-Demand CSV or JSON)
 */
exports.exportMasterData = (req, res) => {
  try {
    const orgId = extractOrgId(req);
    const { format = 'csv' } = req.query; // 'csv' or 'json'
    const masterList = db.getCollectionForOrg('master_register', orgId);
    const timestamp = new Date().toISOString().split('T')[0];

    logAudit({
      req,
      action: 'EXPORT_MASTER_DATA',
      details: `Admin exported master register (${masterList.length} records, format: ${format.toUpperCase()})`,
      adminName: req.admin ? req.admin.name : 'Admin'
    });

    if (format.toLowerCase() === 'json') {
      const filename = `master_register_${timestamp}.json`;
      res.setHeader('Content-Type', 'application/json');
      res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
      return res.send(JSON.stringify(masterList, null, 2));
    }

    // CSV format with UTF-8 BOM for Microsoft Excel compatibility
    const headers = [
      'Record ID',
      'Original Student ID',
      'Full Name',
      'Mobile Phone',
      'Parent Name',
      'Parent Phone',
      'Member Type',
      'Mess Enrolled',
      'Room Number',
      'Bed No',
      'Admission Date',
      'Status',
      'Left Date',
      'Exit Reason',
      'Monthly Mess Fee (Rs)',
      'Total Agreed Rent (Rs)',
      'Rent Term (Months)',
      'Notes',
      'Created At',
      'Photo URL'
    ];

    const rows = masterList.map(m => [
      escapeCsvCell(m.id || ''),
      escapeCsvCell(m.originalId || ''),
      escapeCsvCell(m.name || ''),
      escapeCsvCell(m.phone || ''),
      escapeCsvCell(m.parentName || ''),
      escapeCsvCell(m.parentPhone || ''),
      escapeCsvCell(m.memberType || ''),
      escapeCsvCell(m.enrolledInMess ? 'YES' : 'NO'),
      escapeCsvCell(m.roomNumber || ''),
      escapeCsvCell(m.bedNo || ''),
      escapeCsvCell(m.admissionDate || ''),
      escapeCsvCell(m.status || 'ACTIVE'),
      escapeCsvCell(m.leftDate || ''),
      escapeCsvCell(m.exitReason || ''),
      escapeCsvCell(m.monthlyMessFee || 0),
      escapeCsvCell(m.totalRentAgreed || 0),
      escapeCsvCell(m.rentTermMonths || 0),
      escapeCsvCell(m.notes || ''),
      escapeCsvCell(m.createdAt || ''),
      escapeCsvCell(m.photoUrl || '')
    ]);

    const csvContent = '\uFEFF' + [headers.join(','), ...rows.map(r => r.join(','))].join('\r\n');
    const filename = `master_register_${timestamp}.csv`;

    res.setHeader('Content-Type', 'text/csv; charset=utf-8');
    res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
    return res.send(csvContent);
  } catch (err) {
    console.error('Error exporting master data:', err);
    return res.status(500).json({ success: false, message: err.message });
  }
};

/**
 * 3. Export Combined Cashbook & P&L Statement (On-Demand CSV or JSON)
 */
exports.exportCashbookAndPnL = (req, res) => {
  try {
    const orgId = extractOrgId(req);
    const { format = 'csv', year } = req.query; // optional ?year=2026

    const payments = db.getCollectionForOrg('payments', orgId);
    const expenses = db.getCollectionForOrg('mess_expenses', orgId);

    // Filter by year if specified
    const filteredPayments = year ? payments.filter(p => p.paymentDate && p.paymentDate.startsWith(String(year))) : payments;
    const filteredExpenses = year ? expenses.filter(e => e.date && e.date.startsWith(String(year))) : expenses;

    // Financial Inflows
    const rentInflow = filteredPayments.reduce((acc, p) => acc + (parseFloat(p.rentAmount) || (p.feeType === 'RENT' ? parseFloat(p.amount) : 0)), 0);
    const messInflow = filteredPayments.reduce((acc, p) => acc + (parseFloat(p.messAmount) || (p.feeType === 'MESS' ? parseFloat(p.amount) : 0)), 0);
    const depositInflow = filteredPayments.reduce((acc, p) => acc + (p.feeType === 'DEPOSIT' ? (parseFloat(p.amount) || 0) : 0), 0);
    const otherInflow = filteredPayments.reduce((acc, p) => {
      const isHandled = ['RENT', 'MESS', 'DEPOSIT'].includes(p.feeType) || p.rentAmount > 0 || p.messAmount > 0;
      return isHandled ? acc : acc + (parseFloat(p.amount) || 0);
    }, 0);
    const totalInflow = rentInflow + messInflow + depositInflow + otherInflow;

    // Financial Outflows by Category
    const categoryTotals = {};
    filteredExpenses.forEach(e => {
      const cat = (e.category || 'MISC').toUpperCase();
      categoryTotals[cat] = (categoryTotals[cat] || 0) + (parseFloat(e.amount) || 0);
    });
    const totalOutflow = filteredExpenses.reduce((acc, e) => acc + (parseFloat(e.amount) || 0), 0);
    const netProfitOrLoss = totalInflow - totalOutflow;

    // Combined Unified Transactions Ledger
    const inflows = filteredPayments.map(p => ({
      id: p.id,
      date: p.paymentDate || p.createdAt,
      type: 'INFLOW',
      category: p.feeType || 'FEE_PAYMENT',
      party: `${p.studentName || 'Student'} (Room ${p.roomNumber || 'N/A'})`,
      reference: p.receiptNo || p.id,
      paymentMode: p.paymentMode || 'CASH',
      amount: parseFloat(p.amount) || 0,
      recordedBy: p.collectedByAdminName || 'Admin In-Charge',
      notes: p.notes || ''
    }));

    const outflows = filteredExpenses.map(e => ({
      id: e.id,
      date: e.date || e.createdAt,
      type: 'OUTFLOW',
      category: e.category || 'EXPENSE',
      party: e.vendorName ? `${e.title} - Vendor: ${e.vendorName}` : e.title,
      reference: e.id,
      paymentMode: e.paymentMode || 'CASH',
      amount: parseFloat(e.amount) || 0,
      recordedBy: e.recordedByAdminName || 'Admin In-Charge',
      notes: e.notes || ''
    }));

    const allTransactions = [...inflows, ...outflows];
    allTransactions.sort((a, b) => new Date(b.date || 0) - new Date(a.date || 0));

    const timestamp = new Date().toISOString().split('T')[0];

    logAudit({
      req,
      action: 'EXPORT_CASHBOOK_PNL',
      details: `Admin exported Combined Cashbook & P&L (Total Inflow: ₹${totalInflow.toFixed(2)}, Total Outflow: ₹${totalOutflow.toFixed(2)}, Net: ₹${netProfitOrLoss.toFixed(2)})`,
      adminName: req.admin ? req.admin.name : 'Admin'
    });

    if (format.toLowerCase() === 'json') {
      const filename = `cashbook_pnl_${year || timestamp}.json`;
      res.setHeader('Content-Type', 'application/json');
      res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
      return res.json({
        success: true,
        reportDate: timestamp,
        reportingYear: year || 'ALL_TIME',
        profitAndLossSummary: {
          totalInflow,
          rentInflow,
          messInflow,
          depositInflow,
          otherInflow,
          totalOutflow,
          categoryBreakdown: categoryTotals,
          netProfitOrLoss,
          isProfitable: netProfitOrLoss >= 0
        },
        transactionCount: allTransactions.length,
        transactions: allTransactions
      });
    }

    // CSV format with P&L Financial Summary + Full Cashbook Ledger
    const csvLines = [];
    csvLines.push('========================================================================');
    csvLines.push(`ANNUAL PROFIT & LOSS STATEMENT AND COMBINED CASHBOOK REPORT`);
    csvLines.push(`Generated: ${new Date().toLocaleString('en-IN')} | Period: ${year || 'All-Time Lifetime'}`);
    csvLines.push('========================================================================');
    csvLines.push('');
    csvLines.push('--- REVENUE & INFLOW SUMMARY ---');
    csvLines.push(`Hostel Room Rent Inflow,Rs. ${rentInflow.toFixed(2)}`);
    csvLines.push(`Mess Subscription Inflow,Rs. ${messInflow.toFixed(2)}`);
    csvLines.push(`Security Deposit Inflow,Rs. ${depositInflow.toFixed(2)}`);
    csvLines.push(`Other Fee Inflow,Rs. ${otherInflow.toFixed(2)}`);
    csvLines.push(`TOTAL GROSS REVENUE / INFLOW,Rs. ${totalInflow.toFixed(2)}`);
    csvLines.push('');
    csvLines.push('--- EXPENDITURE & OUTFLOW SUMMARY ---');
    for (const [cat, amt] of Object.entries(categoryTotals)) {
      csvLines.push(`Mess & Operational (${cat}),Rs. ${amt.toFixed(2)}`);
    }
    csvLines.push(`TOTAL EXPENDITURE / OUTFLOW,Rs. ${totalOutflow.toFixed(2)}`);
    csvLines.push('');
    csvLines.push('--- NET FINANCIAL PERFORMANCE ---');
    csvLines.push(`NET PROFIT / (LOSS),Rs. ${netProfitOrLoss.toFixed(2)},${netProfitOrLoss >= 0 ? 'NET PROFIT' : 'DEFICIT/LOSS'}`);
    csvLines.push('');
    csvLines.push('========================================================================');
    csvLines.push('DETAILED TRANSACTION-BY-TRANSACTION COMBINED CASHBOOK LEDGER');
    csvLines.push('========================================================================');

    const ledgerHeaders = [
      'Date',
      'Cash Flow Type',
      'Category',
      'Particulars / Member / Vendor',
      'Receipt / Bill No',
      'Payment Mode',
      'Amount (Rs.)',
      'Recorded By',
      'Notes'
    ];
    csvLines.push(ledgerHeaders.join(','));

    allTransactions.forEach(t => {
      const row = [
        escapeCsvCell(t.date ? String(t.date).split('T')[0] : ''),
        escapeCsvCell(t.type),
        escapeCsvCell(t.category),
        escapeCsvCell(t.party),
        escapeCsvCell(t.reference),
        escapeCsvCell(t.paymentMode),
        escapeCsvCell(t.amount.toFixed(2)),
        escapeCsvCell(t.recordedBy),
        escapeCsvCell(t.notes)
      ];
      csvLines.push(row.join(','));
    });

    const csvContent = '\uFEFF' + csvLines.join('\r\n');
    const filename = `cashbook_pnl_${year || timestamp}.csv`;

    res.setHeader('Content-Type', 'text/csv; charset=utf-8');
    res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
    return res.send(csvContent);
  } catch (err) {
    console.error('Error exporting cashbook & P&L:', err);
    return res.status(500).json({ success: false, message: err.message });
  }
};

/**
 * 4. On-Demand / Annual Reset Master Data (with Pre-Reset Safety Snapshot)
 */
exports.resetMasterData = (req, res) => {
  try {
    const orgId = extractOrgId(req);
    const { adminPin, confirmReset } = req.body;

    if (!confirmReset) {
      return res.status(400).json({
        success: false,
        message: 'Explicit confirmReset confirmation flag is required.'
      });
    }

    // Verify Admin PIN
    const admins = db.getCollection('admins') || [];
    const validAdmin = admins.find(a => (a.orgId || 'org-default') === orgId && a.pin === String(adminPin).trim());
    if (!validAdmin) {
      return res.status(403).json({ success: false, message: 'Invalid Admin PIN. Session reset cancelled.' });
    }

    // 1. Mandatory Pre-Reset Safety Snapshot
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const safetySnapshotPath = path.join(BACKUP_DIR, `pre_reset_master_${timestamp}.json`);
    const currentMaster = db.getCollectionForOrg('master_register', orgId);
    fs.writeFileSync(safetySnapshotPath, JSON.stringify(currentMaster, null, 2), 'utf8');

    // 2. Perform Master Data Reset for the new academic session
    // Resets master register collection for the org to an empty array
    db.saveCollectionForOrg('master_register', orgId, []);

    logAudit({
      req,
      action: 'RESET_MASTER_DATA',
      details: `🔄 Master Register reset for new academic year by ${validAdmin.name}. Pre-reset safety snapshot saved: pre_reset_master_${timestamp}.json`,
      adminName: validAdmin.name,
      adminId: validAdmin.id,
      metadata: {
        isHighPriority: true,
        notificationType: 'MASTER_RESET_CONFIRMATION',
        snapshotFile: `pre_reset_master_${timestamp}.json`
      }
    });

    return res.json({
      success: true,
      message: 'Master Data successfully reset for new session. Pre-reset safety snapshot archived safely.',
      safetySnapshotFile: `pre_reset_master_${timestamp}.json`
    });
  } catch (err) {
    console.error('Error resetting master data:', err);
    return res.status(500).json({ success: false, message: err.message });
  }
};

/**
 * 5. On-Demand / Annual Reset Financials (with Pre-Reset Safety Snapshot)
 */
exports.resetFinancials = (req, res) => {
  try {
    const orgId = extractOrgId(req);
    const { adminPin, confirmReset } = req.body;

    if (!confirmReset) {
      return res.status(400).json({
        success: false,
        message: 'Explicit confirmReset confirmation flag is required.'
      });
    }

    // Verify Admin PIN
    const admins = db.getCollection('admins') || [];
    const validAdmin = admins.find(a => (a.orgId || 'org-default') === orgId && a.pin === String(adminPin).trim());
    if (!validAdmin) {
      return res.status(403).json({ success: false, message: 'Invalid Admin PIN. Financial reset cancelled.' });
    }

    // 1. Mandatory Pre-Reset Safety Snapshot
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const safetySnapshotPath = path.join(BACKUP_DIR, `pre_reset_financials_${timestamp}.json`);
    const currentPayments = db.getCollectionForOrg('payments', orgId);
    const currentExpenses = db.getCollectionForOrg('mess_expenses', orgId);
    fs.writeFileSync(safetySnapshotPath, JSON.stringify({ payments: currentPayments, mess_expenses: currentExpenses }, null, 2), 'utf8');

    // 2. Perform Financial Ledger Reset for the new fiscal year
    db.saveCollectionForOrg('payments', orgId, []);
    db.saveCollectionForOrg('mess_expenses', orgId, []);

    logAudit({
      req,
      action: 'RESET_FINANCIALS',
      details: `🔄 Financial cashbook & mess expense ledgers reset for new fiscal year by ${validAdmin.name}. Pre-reset safety snapshot saved: pre_reset_financials_${timestamp}.json`,
      adminName: validAdmin.name,
      adminId: validAdmin.id,
      metadata: {
        isHighPriority: true,
        notificationType: 'FINANCIAL_RESET_CONFIRMATION',
        snapshotFile: `pre_reset_financials_${timestamp}.json`
      }
    });

    return res.json({
      success: true,
      message: 'Financial ledgers reset for new financial year. Pre-reset safety snapshot archived safely.',
      safetySnapshotFile: `pre_reset_financials_${timestamp}.json`
    });
  } catch (err) {
    console.error('Error resetting financials:', err);
    return res.status(500).json({ success: false, message: err.message });
  }
};
