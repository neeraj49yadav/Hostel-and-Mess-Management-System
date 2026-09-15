const fs = require('fs');
const path = require('path');
const db = require('../config/db');
const { logAudit } = require('./auditService');
const { uploadBuffer } = require('./storageService');

const STATE_FILE = path.join(__dirname, '../../data/annual_schedule_state.json');
const BACKUP_DIR = path.join(__dirname, '../../data/backups');

if (!fs.existsSync(BACKUP_DIR)) {
  try {
    fs.mkdirSync(BACKUP_DIR, { recursive: true });
  } catch (_) {}
}

function loadState() {
  try {
    if (fs.existsSync(STATE_FILE)) {
      return JSON.parse(fs.readFileSync(STATE_FILE, 'utf8'));
    }
  } catch (_) {}
  return { lastExportYear: 0, lastResetYear: 0 };
}

function saveState(state) {
  try {
    fs.writeFileSync(STATE_FILE, JSON.stringify(state, null, 2), 'utf8');
  } catch (err) {
    console.error('Failed to save annual schedule state:', err);
  }
}

function escapeCsvCell(val) {
  if (val === null || val === undefined) return '""';
  const str = String(val).replace(/"/g, '""');
  return `"${str}"`;
}

/**
 * Executes the 25th May Annual Export of Master Data and Cashbook & P&L
 */
async function executeAnnualExport(year) {
  const currentYear = year || new Date().getFullYear();
  console.log(`[ANNUAL SCHEDULER] 🚀 Running Annual 25th May Auto-Export for Year ${currentYear}...`);

  const organizations = db.getCollection('organizations') || [{ id: 'org-default' }];

  for (const org of organizations) {
    const orgId = org.id || 'org-default';
    const orgName = org.name || 'Hostel and Mess';

    // 1. Export Master Data
    const masterList = db.getCollectionForOrg('master_register', orgId);
    const masterJsonPath = path.join(BACKUP_DIR, `annual_master_data_${currentYear}_${orgId}.json`);
    fs.writeFileSync(masterJsonPath, JSON.stringify(masterList, null, 2), 'utf8');

    const masterHeaders = [
      'Record ID', 'Original ID', 'Full Name', 'Phone', 'Parent Name', 'Parent Phone',
      'Member Type', 'Mess Enrolled', 'Room', 'Bed No', 'Admission Date', 'Status',
      'Left Date', 'Exit Reason', 'Monthly Mess Fee', 'Total Agreed Rent', 'Notes'
    ];
    const masterRows = masterList.map(m => [
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
      escapeCsvCell(m.notes || '')
    ]);
    const masterCsvContent = '\uFEFF' + [masterHeaders.join(','), ...masterRows.map(r => r.join(','))].join('\r\n');
    const masterCsvPath = path.join(BACKUP_DIR, `annual_master_data_${currentYear}_${orgId}.csv`);
    fs.writeFileSync(masterCsvPath, masterCsvContent, 'utf8');

    // 2. Export Combined Cashbook & P&L
    const payments = db.getCollectionForOrg('payments', orgId);
    const expenses = db.getCollectionForOrg('mess_expenses', orgId);

    const totalInflow = payments.reduce((acc, p) => acc + (parseFloat(p.amount) || 0), 0);
    const totalOutflow = expenses.reduce((acc, e) => acc + (parseFloat(e.amount) || 0), 0);
    const netProfit = totalInflow - totalOutflow;

    const pnlJsonPath = path.join(BACKUP_DIR, `annual_cashbook_pnl_${currentYear}_${orgId}.json`);
    fs.writeFileSync(pnlJsonPath, JSON.stringify({
      orgId,
      year: currentYear,
      totalInflow,
      totalOutflow,
      netProfit,
      payments,
      expenses
    }, null, 2), 'utf8');

    const pnlCsvLines = [
      '========================================================================',
      `ANNUAL 25TH MAY AUTOMATED FINANCIAL STATEMENTS & P&L - ${orgName.toUpperCase()}`,
      `Financial Year: ${currentYear} | Exported: ${new Date().toLocaleString('en-IN')}`,
      '========================================================================',
      `TOTAL CASH INFLOW (Rent + Mess + Fees),Rs. ${totalInflow.toFixed(2)}`,
      `TOTAL EXPENSES (Groceries + Milk + Gas + Maintenance),Rs. ${totalOutflow.toFixed(2)}`,
      `NET PROFIT / SURPLUS,Rs. ${netProfit.toFixed(2)},${netProfit >= 0 ? 'NET PROFIT' : 'DEFICIT'}`,
      '========================================================================'
    ];
    const pnlCsvPath = path.join(BACKUP_DIR, `annual_cashbook_pnl_${currentYear}_${orgId}.csv`);
    fs.writeFileSync(pnlCsvPath, '\uFEFF' + pnlCsvLines.join('\r\n'), 'utf8');

    // 3. Upload Backup Files to Supabase Storage if configured
    try {
      await uploadBuffer(Buffer.from(masterCsvContent, 'utf8'), 'text/csv', 'csv', 'backups', `annual-master-${currentYear}`);
    } catch (_) {}

    // 4. Post High-Priority Admin Notification
    logAudit({
      action: 'ANNUAL_BACKUP_COMPLETED',
      details: `📢 ANNUAL AUTOMATIC BACKUP (25th May ${currentYear}): Complete Master Register (${masterList.length} records) and Combined Cashbook & P&L (Total Inflow: ₹${totalInflow.toFixed(2)}, Expenses: ₹${totalOutflow.toFixed(2)}) have been exported and archived safely. Annual session rollover and data reset is scheduled for 28th May.`,
      adminName: 'System Automation',
      adminRole: 'System',
      metadata: {
        isHighPriority: true,
        notificationType: 'ANNUAL_BACKUP_ALERT',
        year: currentYear,
        masterRecordsCount: masterList.length,
        totalInflow,
        totalOutflow,
        netProfit,
        files: [
          `annual_master_data_${currentYear}_${orgId}.csv`,
          `annual_cashbook_pnl_${currentYear}_${orgId}.csv`
        ]
      }
    });
  }

  const state = loadState();
  state.lastExportYear = currentYear;
  saveState(state);
  console.log(`[ANNUAL SCHEDULER] ✅ Annual 25th May Auto-Export completed for ${currentYear}.`);
}

/**
 * Executes the 28th May Annual Session Reset (with Safety Snapshot)
 */
async function executeAnnualReset(year) {
  const currentYear = year || new Date().getFullYear();
  console.log(`[ANNUAL SCHEDULER] 🔄 Running Annual 28th May Session Reset for Year ${currentYear}...`);

  const organizations = db.getCollection('organizations') || [{ id: 'org-default' }];

  for (const org of organizations) {
    const orgId = org.id || 'org-default';

    // 1. Mandatory Pre-Reset Safety Snapshot
    const preResetFile = path.join(BACKUP_DIR, `pre_reset_snapshot_${currentYear}_${orgId}.json`);
    const masterData = db.getCollectionForOrg('master_register', orgId);
    const payments = db.getCollectionForOrg('payments', orgId);
    const expenses = db.getCollectionForOrg('mess_expenses', orgId);

    fs.writeFileSync(preResetFile, JSON.stringify({
      year: currentYear,
      timestamp: new Date().toISOString(),
      masterData,
      payments,
      expenses
    }, null, 2), 'utf8');

    // 2. Perform Safe Annual Session Reset
    // Reset Master Register & Financials for the fresh academic year
    db.saveCollectionForOrg('master_register', orgId, []);
    db.saveCollectionForOrg('payments', orgId, []);
    db.saveCollectionForOrg('mess_expenses', orgId, []);

    // 3. Post High-Priority Admin Notification
    logAudit({
      action: 'ANNUAL_SESSION_RESET_COMPLETED',
      details: `🔄 ANNUAL ACADEMIC SESSION RESET (28th May ${currentYear}): Master Register and Financial Ledgers have been reset for the new academic year. Pre-reset safety snapshot archived in pre_reset_snapshot_${currentYear}_${orgId}.json.`,
      adminName: 'System Automation',
      adminRole: 'System',
      metadata: {
        isHighPriority: true,
        notificationType: 'ANNUAL_RESET_ALERT',
        year: currentYear,
        snapshotFile: `pre_reset_snapshot_${currentYear}_${orgId}.json`
      }
    });
  }

  const state = loadState();
  state.lastResetYear = currentYear;
  saveState(state);
  console.log(`[ANNUAL SCHEDULER] ✅ Annual 28th May Session Reset completed for ${currentYear}.`);
}

/**
 * Daily Schedule Checker
 */
async function checkSchedule() {
  try {
    const now = new Date();
    const month = now.getMonth(); // 4 = May (0-indexed)
    const date = now.getDate();
    const currentYear = now.getFullYear();
    const state = loadState();

    // 1. Check 25th May Export
    if (month === 4 && date === 25 && state.lastExportYear !== currentYear) {
      await executeAnnualExport(currentYear);
    }

    // 2. Check 28th May Reset
    if (month === 4 && date === 28 && state.lastResetYear !== currentYear) {
      await executeAnnualReset(currentYear);
    }
  } catch (err) {
    console.error('[ANNUAL SCHEDULER ERROR]:', err);
  }
}

/**
 * Initializes the Annual Scheduler
 */
function initAnnualScheduler() {
  // Run initial check on server boot
  checkSchedule();

  // Run check every 6 hours
  setInterval(checkSchedule, 6 * 60 * 60 * 1000);
  console.log('📅 Annual 25th May Auto-Export & 28th May Session Reset Scheduler Initialized.');
}

module.exports = {
  initAnnualScheduler,
  executeAnnualExport,
  executeAnnualReset,
  checkSchedule
};
