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
 * 1. Full Offline System Backup (JSON Export - Scoped to Logged-in Hostel)
 */
exports.exportFullBackup = (req, res) => {
  try {
    const orgId = extractOrgId(req);
    const dbData = db.read();
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');

    let exportData;
    let hostelTag = 'all';
    if (orgId && orgId !== 'all') {
      const org = (dbData.organizations || []).find(o => o.id === orgId || o.code === orgId);
      hostelTag = org ? (org.code || org.name).replace(/[^a-zA-Z0-9]/g, '_') : orgId;
      exportData = {
        exportedAt: new Date().toISOString(),
        organization: org || { id: orgId },
        admins: db.getCollectionForOrg('admins', orgId),
        rooms: db.getCollectionForOrg('rooms', orgId),
        students: db.getCollectionForOrg('students', orgId),
        payments: db.getCollectionForOrg('payments', orgId),
        master_register: db.getCollectionForOrg('master_register', orgId),
        mess_expenses: db.getCollectionForOrg('mess_expenses', orgId),
        vendors: db.getCollectionForOrg('vendors', orgId),
        leave_logs: db.getCollectionForOrg('leave_logs', orgId),
        audit_logs: db.getCollectionForOrg('audit_logs', orgId),
        notifications: db.getCollectionForOrg('notifications', orgId)
      };
    } else {
      exportData = dbData;
    }

    const filename = `hostel_database_backup_${hostelTag}_${timestamp}.json`;

    logAudit({
      req,
      action: 'EXPORT_FULL_BACKUP',
      details: `Admin exported complete offline system backup archive (${filename}) for org: ${hostelTag}`,
      adminName: req.admin ? req.admin.name : 'Admin'
    });

    res.setHeader('Content-Type', 'application/json');
    res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
    return res.send(JSON.stringify(exportData, null, 2));
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
      escapeCsvCell(m.memberType || 'HOSTEL_RESIDENT'),
      escapeCsvCell(m.isMessMember ? 'YES' : 'NO'),
      escapeCsvCell(m.roomNumber || ''),
      escapeCsvCell(m.bedNo || ''),
      escapeCsvCell(m.admissionDate || ''),
      escapeCsvCell(m.status || 'ACTIVE'),
      escapeCsvCell(m.leftDate || ''),
      escapeCsvCell(m.exitReason || ''),
      escapeCsvCell(m.monthlyMessFee || 0),
      escapeCsvCell(m.agreedRent || 0),
      escapeCsvCell(m.rentTermMonths || 1),
      escapeCsvCell(m.notes || ''),
      escapeCsvCell(m.createdAt || ''),
      escapeCsvCell(m.photo || '')
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
 * 3. Export Combined Cashbook & P&L (Clean CSV or JSON)
 */
exports.exportCashbookAndPnL = (req, res) => {
  try {
    const orgId = extractOrgId(req);
    const { year, format = 'csv' } = req.query;

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
      inflow: parseFloat(p.amount) || 0,
      outflow: 0,
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
      inflow: 0,
      outflow: parseFloat(e.amount) || 0,
      recordedBy: e.recordedByAdminName || 'Admin In-Charge',
      notes: e.notes || ''
    }));

    const allTransactions = [...inflows, ...outflows];
    allTransactions.sort((a, b) => new Date(b.date || 0) - new Date(a.date || 0));

    const timestamp = new Date().toISOString().split('T')[0];

    logAudit({
      req,
      action: 'EXPORT_CASHBOOK_PNL',
      details: `Admin exported Combined Cashbook & P&L (Total Inflow: Rs. ${totalInflow.toFixed(2)}, Outflow: Rs. ${totalOutflow.toFixed(2)}, Net: Rs. ${netProfitOrLoss.toFixed(2)})`,
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

    // Clean, readable CSV format
    const csvLines = [];
    csvLines.push(`"CASHBOOK & PROFIT/LOSS STATEMENT","Period: ${year || 'All-Time'}","Generated: ${timestamp}"`);
    csvLines.push('');
    csvLines.push('"--- FINANCIAL SUMMARY ---","AMOUNT (Rs.)"');
    csvLines.push(`"Total Inflow (Revenue)",${totalInflow.toFixed(2)}`);
    csvLines.push(`"  - Room Rent Inflow",${rentInflow.toFixed(2)}`);
    csvLines.push(`"  - Mess Fees Inflow",${messInflow.toFixed(2)}`);
    csvLines.push(`"  - Security Deposits",${depositInflow.toFixed(2)}`);
    csvLines.push(`"  - Other Fees",${otherInflow.toFixed(2)}`);
    csvLines.push(`"Total Outflow (Expenses)",${totalOutflow.toFixed(2)}`);
    for (const [cat, amt] of Object.entries(categoryTotals)) {
      csvLines.push(`"  - ${cat}",${amt.toFixed(2)}`);
    }
    csvLines.push(`"NET PROFIT / (LOSS)",${netProfitOrLoss.toFixed(2)}`);
    csvLines.push('');
    csvLines.push('"--- DETAILED CASHBOOK TRANSACTIONS ---"');

    const ledgerHeaders = [
      'Date',
      'Type',
      'Category',
      'Particulars',
      'Payment Mode',
      'Inflow (Rs.)',
      'Outflow (Rs.)',
      'Receipt / Bill Ref',
      'Recorded By',
      'Notes'
    ];
    csvLines.push(ledgerHeaders.map(escapeCsvCell).join(','));

    allTransactions.forEach(t => {
      const row = [
        escapeCsvCell(t.date ? String(t.date).split('T')[0] : ''),
        escapeCsvCell(t.type),
        escapeCsvCell(t.category),
        escapeCsvCell(t.party),
        escapeCsvCell(t.paymentMode),
        escapeCsvCell(t.inflow > 0 ? t.inflow.toFixed(2) : '-'),
        escapeCsvCell(t.outflow > 0 ? t.outflow.toFixed(2) : '-'),
        escapeCsvCell(t.reference),
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
