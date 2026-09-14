const db = require('../config/db');
const { v4: uuidv4 } = require('uuid');
const { logAudit } = require('../services/auditService');
const { extractOrgId } = require('../middleware/authMiddleware');

// Get all leave logs (with filters: status = OUT / RETURNED)
exports.getLeaveLogs = (req, res) => {
  try {
    const orgId = extractOrgId(req);
    const { status, studentId } = req.query;
    let logs = db.getCollectionForOrg('leave_logs', orgId);

    if (status) {
      logs = logs.filter(l => l.status === status.toUpperCase());
    }
    if (studentId) {
      logs = logs.filter(l => l.studentId === studentId);
    }

    // Sort newest departure first
    logs.sort((a, b) => new Date(b.departureDate) - new Date(a.departureDate));

    const currentlyOutCount = logs.filter(l => l.status === 'OUT').length;

    res.json({
      success: true,
      count: logs.length,
      currentlyOutCount,
      data: logs
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// Log Student Departure (Going Out)
exports.recordDeparture = (req, res) => {
  try {
    const orgId = extractOrgId(req);
    const {
      studentId,
      leaveType, // 'HOME_VISIT', 'NIGHT_OUT', 'EMERGENCY', 'MARKET'
      expectedReturnDate,
      reason,
      parentApproved,
      adminName
    } = req.body;

    if (!studentId || !leaveType) {
      return res.status(400).json({ success: false, message: 'Student and leaveType are required' });
    }

    const students = db.getCollectionForOrg('students', orgId);
    const student = students.find(s => s.id === studentId);
    if (!student) {
      return res.status(404).json({ success: false, message: 'Student not found' });
    }

    const leaveLogs = db.getCollectionForOrg('leave_logs', orgId);

    // Check if student is already marked OUT
    const alreadyOut = leaveLogs.some(l => l.studentId === studentId && l.status === 'OUT');
    if (alreadyOut) {
      return res.status(400).json({ success: false, message: 'Student is already marked as OUT' });
    }

    const newLog = {
      id: `leave-${uuidv4().substring(0, 8)}`,
      orgId,
      studentId,
      studentName: student.name,
      roomNumber: student.roomNumber,
      leaveType: leaveType.toUpperCase(),
      departureDate: new Date().toISOString(),
      expectedReturnDate: expectedReturnDate || new Date().toISOString(),
      actualReturnDate: null,
      status: 'OUT',
      reason: reason || '',
      parentApproved: parentApproved !== undefined ? parentApproved : true,
      loggedByAdminName: adminName || (req.admin && req.admin.name) || 'Admin'
    };

    leaveLogs.push(newLog);
    db.saveCollectionForOrg('leave_logs', orgId, leaveLogs);

    // 🛡️ Log Student Departure to Audit Log
    logAudit({
      req,
      action: 'RECORD_DEPARTURE',
      details: `Logged departure for ${student.name} (Room ${student.roomNumber}). Type: ${newLog.leaveType}, Reason: "${newLog.reason || 'Personal'}"`,
      adminName: newLog.loggedByAdminName
    });

    res.status(201).json({ success: true, data: newLog });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// Mark Student Return (Checked In)
exports.recordReturn = (req, res) => {
  try {
    const orgId = extractOrgId(req);
    const { id } = req.params;
    const { adminName } = req.body;

    const leaveLogs = db.getCollectionForOrg('leave_logs', orgId);
    const index = leaveLogs.findIndex(l => l.id === id);

    if (index === -1) {
      return res.status(404).json({ success: false, message: 'Leave log record not found' });
    }

    leaveLogs[index].status = 'RETURNED';
    leaveLogs[index].actualReturnDate = new Date().toISOString();
    leaveLogs[index].receivedByAdminName = adminName || (req.admin && req.admin.name) || 'Admin';

    db.saveCollectionForOrg('leave_logs', orgId, leaveLogs);

    // 🛡️ Log Student Return to Audit Log
    logAudit({
      req,
      action: 'RECORD_RETURN',
      details: `Marked resident ${leaveLogs[index].studentName} (Room ${leaveLogs[index].roomNumber}) returned to hostel`,
      adminName: leaveLogs[index].receivedByAdminName
    });

    res.json({ success: true, message: 'Student marked returned', data: leaveLogs[index] });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

