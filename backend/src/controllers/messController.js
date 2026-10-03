const db = require('../config/db');
const { v4: uuidv4 } = require('uuid');
const { calculateCycleStatus, calculateMessLedger, generateWhatsAppReminder } = require('../services/expiryService');
const { logAudit } = require('../services/auditService');
const { extractOrgId } = require('../middleware/authMiddleware');
const storageService = require('../services/storageService');

// Get all mess members (Hostelites enrolled in mess + Outside Day Scholars)
exports.getMessMembers = (req, res) => {
  try {
    const orgId = extractOrgId(req);
    const { type, status, search } = req.query; // type: 'ALL', 'OUTSIDE_ONLY', 'HOSTEL_ONLY', 'REMOVED', 'OVERDUE', 'UPCOMING'
    let allStudents = db.getCollectionForOrg('students', orgId).filter(s => s.status !== 'ARCHIVED');
    const payments = db.getCollectionForOrg('payments', orgId);

    const isOutsider = s => s.memberType === 'MESS_ONLY' || s.isMessOnly === true || !s.roomId;
    const isHostelite = s => (s.memberType === 'HOSTEL_RESIDENT' || !!s.roomId) && (s.enrolledInMess !== false || s.status === 'MESS_AUTO_REMOVED');

    // Filter to students associated with mess
    const messCandidates = allStudents.filter(s => isOutsider(s) || isHostelite(s));

    // 🛡️ Auto-remove check after 60 days of non-payment (Requirement 4)
    let dbChanged = false;
    messCandidates.forEach(s => {
      if (s.status !== 'MESS_AUTO_REMOVED' && s.status !== 'REMOVED_AUTO') {
        const studentPayments = payments.filter(p => p.studentId === s.id);
        const ledger = calculateMessLedger(s, studentPayments);
        if (ledger.isEligibleForAutoRemove) {
          s.status = 'MESS_AUTO_REMOVED';
          s.autoRemovedAt = new Date().toISOString();
          s.autoRemoveReason = `Auto-removed: Overdue by ${Math.abs(ledger.messDaysRemaining)} days without continuous payment`;
          if (s.memberType === 'HOSTEL_RESIDENT') {
            s.enrolledInMess = false;
          }
          dbChanged = true;
          db.upsertMasterRegister(s, orgId, { status: 'MESS_AUTO_REMOVED', exitReason: s.autoRemoveReason });
        }
      }
    });

    if (dbChanged) {
      db.saveCollectionForOrg('students', orgId, allStudents);
    }

    // Split active vs removed members
    const removedMembers = messCandidates.filter(s => s.status === 'MESS_AUTO_REMOVED' || s.status === 'REMOVED_AUTO' || s.autoRemovedAt != null);
    const activeMessStudents = messCandidates.filter(s => s.status !== 'MESS_AUTO_REMOVED' && s.status !== 'REMOVED_AUTO' && !s.autoRemovedAt);

    // True total counts computed before query filter is applied
    const totalAllCount = activeMessStudents.length;
    const totalOutsideCount = activeMessStudents.filter(isOutsider).length;
    const totalHostelCount = activeMessStudents.filter(s => !isOutsider(s)).length;
    const removedCount = removedMembers.length;

    let targetList = [...activeMessStudents];

    if (type === 'REMOVED') {
      targetList = [...removedMembers];
    } else if (type === 'OUTSIDE_ONLY') {
      targetList = targetList.filter(isOutsider);
    } else if (type === 'HOSTEL_ONLY') {
      targetList = targetList.filter(s => !isOutsider(s));
    }

    // Enrich each student with accurate Mess Ledger
    const enriched = targetList.map(s => {
      const studentPayments = payments.filter(p => p.studentId === s.id);
      const ledger = calculateMessLedger(s, studentPayments);
      return {
        ...s,
        monthlyMessFee: ledger.monthlyMessFee,
        totalMessPaid: ledger.totalMessPaid,
        totalMessBilled: ledger.totalMessBilled || (ledger.totalMessPaid + ledger.messBalanceDue),
        messBalanceDue: ledger.messBalanceDue,
        messExpiryDate: ledger.messExpiryDate,
        messDynamicStatus: ledger.messDynamicStatus,
        statusLabel: ledger.messStatusLabel,
        daysRemaining: ledger.messDaysRemaining,
        isOverdueMess: ledger.isOverdue,
        isUpcomingMess: ledger.isUpcoming,
        isAutoRemoved: s.status === 'MESS_AUTO_REMOVED' || s.status === 'REMOVED_AUTO' || !!s.autoRemovedAt,
        autoRemovedAt: s.autoRemovedAt,
        autoRemoveReason: s.autoRemoveReason,
        mealsPerDay: s.mealsPerDay || 3,
        mealPlanType: s.mealPlanType || (s.mealsPerDay === 1 ? '1 Meal / Day' : (s.mealsPerDay === 2 ? '2 Meals / Day' : '3 Meals / Day (Full)')),
        mealSlots: s.mealSlots || ['Morning', 'Noon', 'Evening'],
        planValidityType: s.planValidityType || 'MONTHLY',
        planValidityDays: s.planValidityDays
      };
    });

    // Counts for Overdue and Upcoming
    const overdueCount = activeMessStudents.map(s => calculateMessLedger(s, payments.filter(p => p.studentId === s.id))).filter(l => l.isOverdue).length;
    const upcomingCount = activeMessStudents.map(s => calculateMessLedger(s, payments.filter(p => p.studentId === s.id))).filter(l => l.isUpcoming).length;

    let result = enriched;

    // Filter by OVERDUE / UPCOMING if requested
    if (type === 'OVERDUE') {
      result = result.filter(s => s.isOverdueMess);
    } else if (type === 'UPCOMING') {
      result = result.filter(s => s.isUpcomingMess);
    }

    // Status filter
    if (status && status !== 'ALL') {
      result = result.filter(s => s.messDynamicStatus === status);
    }

    // Search filter
    if (search && search.trim()) {
      const q = search.trim().toLowerCase();
      result = result.filter(s =>
        (s.name && s.name.toLowerCase().includes(q)) ||
        (s.phone && s.phone.includes(q)) ||
        (s.roomNumber && s.roomNumber.toLowerCase().includes(q)) ||
        (s.mealPlanType && s.mealPlanType.toLowerCase().includes(q))
      );
    }

    res.json({
      success: true,
      count: result.length,
      totalCount: totalAllCount,
      totalAllCount: totalAllCount,
      outsideCount: totalOutsideCount,
      totalOutsideCount: totalOutsideCount,
      hostelCount: totalHostelCount,
      totalHostelCount: totalHostelCount,
      removedCount: removedCount,
      overdueCount: overdueCount,
      upcomingCount: upcomingCount,
      data: result
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// Add Member to Mess: Handles both (1) Existing Hostel Resident and (2) Outside Student
exports.createMessMember = async (req, res) => {
  try {
    const orgId = extractOrgId(req);
    const {
      isHostelResident,
      studentId,
      name,
      phone,
      parentPhone,
      parentName,
      photoUrl,
      monthlyMessFee,
      admissionDate,
      messStartDate,
      cycleDay,
      mealsPerDay = 3,
      mealPlanType,
      mealSlots = ['Morning', 'Noon', 'Evening'],
      planValidityType = 'MONTHLY',
      planValidityDays,
      notes,
      adminName
    } = req.body;

    const students = db.getCollectionForOrg('students', orgId);
    const fee = parseFloat(monthlyMessFee) || 3500;
    const admDate = admissionDate || new Date().toISOString().split('T')[0];
    const mStartDate = messStartDate || admDate;
    const cDay = cycleDay ? parseInt(cycleDay) : new Date(mStartDate).getDate();

    // Validity calculation
    let messExpiryDateStr;
    if (planValidityType === 'CUSTOM_DAYS' && planValidityDays) {
      const expDate = new Date(mStartDate);
      expDate.setDate(expDate.getDate() + parseInt(planValidityDays));
      messExpiryDateStr = expDate.toISOString().split('T')[0];
    } else {
      const expDate = new Date(mStartDate);
      expDate.setMonth(expDate.getMonth() + 1);
      messExpiryDateStr = expDate.toISOString().split('T')[0];
    }

    // ☁️ Offload photo to Supabase Storage if Base64
    const storedPhotoUrl = await storageService.processImage(photoUrl, 'members');

    // CASE A: Enrolling an existing Hostel Resident
    if (isHostelResident === true && studentId) {
      const index = students.findIndex(s => s.id === studentId);
      if (index === -1) {
        return res.status(404).json({ success: false, message: 'Hostel resident not found' });
      }

      students[index].enrolledInMess = true;
      students[index].monthlyMessFee = fee;
      students[index].messStartDate = mStartDate;
      students[index].mealsPerDay = parseInt(mealsPerDay) || 3;
      students[index].mealPlanType = mealPlanType || (parseInt(mealsPerDay) === 1 ? '1 Meal / Day' : (parseInt(mealsPerDay) === 2 ? '2 Meals / Day' : '3 Meals / Day (Full)'));
      students[index].mealSlots = Array.isArray(mealSlots) ? mealSlots : ['Morning', 'Noon', 'Evening'];
      students[index].planValidityType = planValidityType || 'MONTHLY';
      students[index].planValidityDays = planValidityDays ? parseInt(planValidityDays) : null;
      students[index].status = students[index].status === 'MESS_AUTO_REMOVED' ? 'ACTIVE' : students[index].status;
      students[index].autoRemovedAt = null;
      students[index].autoRemoveReason = null;

      if (storedPhotoUrl && storedPhotoUrl.trim()) {
        students[index].photoUrl = storedPhotoUrl.trim();
      }
      if (!students[index].messExpiryDate || students[index].messExpiryDate === '') {
        students[index].messExpiryDate = messExpiryDateStr;
      }
      if (notes) {
        students[index].notes = `${students[index].notes ? students[index].notes + ' | ' : ''}${notes}`;
      }
      students[index].updatedAt = new Date().toISOString();

      db.saveCollectionForOrg('students', orgId, students);

      // 📜 Upsert into non-deletable Master Register
      db.upsertMasterRegister(students[index], orgId);

      logAudit({
        req,
        action: 'ENROLL_MESS_HOSTELITE',
        details: `Enrolled resident ${students[index].name} (Room ${students[index].roomNumber}) into Mess at ₹${fee}/mo starting ${mStartDate} (${students[index].mealPlanType})`,
        adminName
      });

      return res.status(201).json({
        success: true,
        message: `Resident ${students[index].name} enrolled in Mess successfully`,
        data: students[index]
      });
    }

    // CASE B: Enrolling an Outside / Day Scholar Member
    if (!name || !phone) {
      return res.status(400).json({ success: false, message: 'Name and phone number are required for outside members' });
    }

    const newMember = {
      id: `mess-mem-${uuidv4().substring(0, 8)}`,
      orgId,
      memberType: 'MESS_ONLY',
      enrolledInMess: true,
      name: name.trim(),
      phone: phone.trim(),
      parentPhone: (parentPhone || '').trim(),
      parentName: (parentName || '').trim(),
      photoUrl: (storedPhotoUrl || '').trim(),
      roomId: null,
      roomNumber: 'External / Day Scholar',
      bedNo: '-',
      admissionDate: admDate,
      messStartDate: mStartDate,
      cycleDay: cDay,
      monthlyMessFee: fee,
      messExpiryDate: messExpiryDateStr,
      mealsPerDay: parseInt(mealsPerDay) || 3,
      mealPlanType: mealPlanType || (parseInt(mealsPerDay) === 1 ? '1 Meal / Day' : (parseInt(mealsPerDay) === 2 ? '2 Meals / Day' : '3 Meals / Day (Full)')),
      mealSlots: Array.isArray(mealSlots) ? mealSlots : ['Morning', 'Noon', 'Evening'],
      planValidityType: planValidityType || 'MONTHLY',
      planValidityDays: planValidityDays ? parseInt(planValidityDays) : null,
      rentTermMonths: 0,
      rentAmountPerTerm: 0,
      rentExpiryDate: null,
      status: 'ACTIVE',
      notes: notes || '',
      createdAt: new Date().toISOString()
    };

    students.push(newMember);
    db.saveCollectionForOrg('students', orgId, students);

    // 📜 Upsert into non-deletable Master Register
    db.upsertMasterRegister(newMember, orgId, { status: 'ACTIVE' });

    logAudit({
      req,
      action: 'ADD_MESS_MEMBER',
      details: `Enrolled outside mess member ${newMember.name} (Phone: ${newMember.phone}) at ₹${newMember.monthlyMessFee}/mo (${newMember.mealPlanType}) starting ${newMember.messStartDate}`,
      adminName
    });

    res.status(201).json({
      success: true,
      message: 'Outside mess member added successfully',
      data: newMember
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// Unenroll / Remove student from Mess (Handles Outside Day Scholars and Hostel Residents)
exports.unenrollMessMember = (req, res) => {
  try {
    const orgId = extractOrgId(req);
    const { id } = req.params;
    const adminName = (req.body && req.body.adminName) || req.query.adminName || (req.admin && req.admin.name) || 'Admin';
    const { removeFromHostel, reason } = req.body || {};

    let students = db.getCollectionForOrg('students', orgId);
    const index = students.findIndex(s => s.id === id);
    if (index === -1) {
      return res.status(404).json({ success: false, message: 'Student / Mess member not found' });
    }

    const student = students[index];

    // CASE 1: Outside Day Scholar (MESS_ONLY)
    if (student.memberType === 'MESS_ONLY') {
      // 📜 Mark as LEFT in Master Register before deleting from active list (Never lost!)
      db.upsertMasterRegister(student, orgId, {
        status: 'LEFT',
        leftDate: new Date().toISOString(),
        exitReason: reason || 'Subscription cancelled'
      });

      students = students.filter(s => s.id !== id);
      db.saveCollectionForOrg('students', orgId, students);

      logAudit({
        req,
        action: 'REMOVE_MESS_MEMBER',
        details: `Removed outside mess member ${student.name} (Phone: ${student.phone}). Reason: ${reason || 'Subscription cancelled'}`,
        adminName
      });

      return res.json({
        success: true,
        message: `Mess member ${student.name} removed successfully`,
        data: { id, status: 'REMOVED' }
      });
    }

    // CASE 2: Hostel Resident (HOSTEL_RESIDENT)
    // If removeFromHostel is true as well: Checkout resident from hostel too!
    if (removeFromHostel === true) {
      student.status = 'ARCHIVED';
      student.checkoutDate = new Date().toISOString();
      student.checkoutReason = reason || 'Left Hostel & Mess';
      student.enrolledInMess = false;
      student.monthlyMessFee = 0;
      student.updatedAt = new Date().toISOString();

      // 📜 Preserve in Master Register as LEFT with exit reason
      db.upsertMasterRegister(student, orgId, {
        status: 'LEFT',
        leftDate: student.checkoutDate,
        exitReason: student.checkoutReason
      });

      // Refresh room counts
      const rooms = db.getCollectionForOrg('rooms', orgId);
      rooms.forEach(r => {
        r.occupiedBeds = students.filter(s => s.roomId === r.id && s.status !== 'ARCHIVED').length;
        r.status = r.occupiedBeds >= r.totalBeds ? 'FULL' : 'AVAILABLE';
      });
      db.saveCollectionForOrg('rooms', orgId, rooms);
      db.saveCollectionForOrg('students', orgId, students);

      logAudit({
        req,
        action: 'REMOVE_FROM_HOSTEL_AND_MESS',
        details: `Checked out resident ${student.name} from Room ${student.roomNumber} (Bed ${student.bedNo}) and cancelled mess subscription. Reason: ${student.checkoutReason}`,
        adminName
      });

      return res.json({
        success: true,
        message: `Resident ${student.name} checked out from Hostel and unenrolled from Mess`,
        data: student
      });
    }

    // Unenroll from Mess only, remain in hostel
    student.enrolledInMess = false;
    student.monthlyMessFee = 0;
    student.updatedAt = new Date().toISOString();
    db.saveCollectionForOrg('students', orgId, students);

    // 📜 Update Master Register record
    db.upsertMasterRegister(student, orgId);

    logAudit({
      req,
      action: 'UNENROLL_MESS_HOSTELITE',
      details: `Unenrolled resident ${student.name} (Room ${student.roomNumber}) from Mess. Resident stays in hostel room. Reason: ${reason || 'Opted out of mess'}`,
      adminName
    });

    res.json({
      success: true,
      message: `Resident ${student.name} unenrolled from Mess successfully (stays in hostel room)`,
      data: student
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// Restore / Recover Removed Mess Member (Requirement 4)
exports.restoreMessMember = (req, res) => {
  try {
    const orgId = extractOrgId(req);
    const { id } = req.params;
    const adminName = (req.body && req.body.adminName) || (req.admin && req.admin.name) || 'Admin';

    let students = db.getCollectionForOrg('students', orgId);
    let index = students.findIndex(s => s.id === id);
    let student = index !== -1 ? students[index] : null;

    // If not found in active students array, check master register
    if (!student) {
      const master = db.getCollectionForOrg('master_register', orgId);
      const mRecord = master.find(m => m.id === id);
      if (mRecord) {
        student = { ...mRecord, status: 'ACTIVE', enrolledInMess: true };
        students.push(student);
        index = students.length - 1;
      }
    }

    if (!student) {
      return res.status(404).json({ success: false, message: 'Removed mess member not found to restore' });
    }

    const todayStr = new Date().toISOString().split('T')[0];
    const nextMonth = new Date();
    nextMonth.setMonth(nextMonth.getMonth() + 1);

    student.status = 'ACTIVE';
    student.enrolledInMess = true;
    student.autoRemovedAt = null;
    student.autoRemoveReason = null;
    student.messStartDate = todayStr;
    student.messExpiryDate = nextMonth.toISOString().split('T')[0];
    student.updatedAt = new Date().toISOString();

    db.saveCollectionForOrg('students', orgId, students);
    db.upsertMasterRegister(student, orgId, { status: 'ACTIVE' });

    logAudit({
      req,
      action: 'RESTORE_MESS_MEMBER',
      details: `Restored mess member ${student.name} (Phone: ${student.phone}) back to active status starting ${todayStr}`,
      adminName
    });

    res.json({
      success: true,
      message: `Member ${student.name} restored to active mess subscription successfully!`,
      data: student
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// Get all mess expenses
exports.getExpenses = (req, res) => {
  try {
    const orgId = extractOrgId(req);
    const { category, month, startDate, endDate } = req.query;
    let expenses = db.getCollectionForOrg('mess_expenses', orgId);

    if (category) expenses = expenses.filter(e => e.category === category.toUpperCase());
    if (month) expenses = expenses.filter(e => e.date && e.date.startsWith(month));
    if (startDate && endDate) expenses = expenses.filter(e => e.date >= startDate && e.date <= endDate);

    expenses.sort((a, b) => new Date(b.date) - new Date(a.date));
    const totalExpense = expenses.reduce((acc, e) => acc + (e.amount || 0), 0);

    const categoryTotals = {};
    expenses.forEach(e => {
      categoryTotals[e.category] = (categoryTotals[e.category] || 0) + e.amount;
    });

    res.json({
      success: true,
      count: expenses.length,
      totalExpense,
      categoryTotals,
      data: expenses
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// Add new mess expense
exports.addExpense = (req, res) => {
  try {
    const orgId = extractOrgId(req);
    const {
      title,
      category,
      amount,
      date,
      vendorName,
      vendorPhone,
      paymentMode,
      billImageUrl,
      adminId,
      adminName,
      notes
    } = req.body;

    if (!title || !category || !amount) {
      return res.status(400).json({ success: false, message: 'Title, category, and amount are required' });
    }

    const expenses = db.getCollectionForOrg('mess_expenses', orgId);
    const newExpense = {
      id: `exp-${uuidv4().substring(0, 8)}`,
      orgId,
      title: title.trim(),
      category: category.toUpperCase(),
      amount: parseFloat(amount),
      date: date || new Date().toISOString().split('T')[0],
      vendorName: vendorName || '',
      vendorPhone: vendorPhone || '',
      paymentMode: paymentMode || 'CASH',
      billImageUrl: billImageUrl || '',
      recordedByAdminId: adminId || (req.admin && req.admin.id) || 'admin-3',
      recordedByAdminName: adminName || (req.admin && req.admin.name) || 'Warden 3 (Mess In-charge)',
      notes: notes || '',
      createdAt: new Date().toISOString()
    };

    expenses.push(newExpense);
    db.saveCollectionForOrg('mess_expenses', orgId, expenses);

    logAudit({
      req,
      action: 'ADD_MESS_EXPENSE',
      details: `Added Grocery Expense: ₹${newExpense.amount} under ${newExpense.category} for "${newExpense.title}" (Vendor: ${newExpense.vendorName || "Direct / Cash"}, Payment: ${newExpense.paymentMode})`,
      adminName: newExpense.recordedByAdminName,
      adminId: newExpense.recordedByAdminId
    });

    res.status(201).json({ success: true, data: newExpense });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// Delete expense (Logged to Admin Audit Log)
exports.deleteExpense = (req, res) => {
  try {
    const orgId = extractOrgId(req);
    const { id } = req.params;
    const adminName = (req.body && req.body.adminName) || req.query.adminName || (req.admin && req.admin.name) || 'Admin';

    let expenses = db.getCollectionForOrg('mess_expenses', orgId);
    const item = expenses.find(e => e.id === id);

    if (!item) return res.status(404).json({ success: false, message: 'Expense record not found' });

    expenses = expenses.filter(e => e.id !== id);
    db.saveCollectionForOrg('mess_expenses', orgId, expenses);

    // 🛡️ Comprehensive Audit Trail for deleted grocery expense
    logAudit({
      req,
      action: 'DELETE_MESS_EXPENSE',
      details: `Deleted Grocery Cashbook entry: ₹${item.amount} under ${item.category} for "${item.title}" (Vendor: ${item.vendorName || "Direct / Cash"}, Date: ${item.date})`,
      adminName
    });

    res.json({ success: true, message: 'Expense record deleted and logged to Admin Audit Log' });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// Vendors & Khata
exports.getVendors = (req, res) => {
  try {
    const orgId = extractOrgId(req);
    const vendors = db.getCollectionForOrg('vendors', orgId);
    res.json({ success: true, count: vendors.length, data: vendors });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// Save Vendor
exports.saveVendor = (req, res) => {
  try {
    const orgId = extractOrgId(req);
    const { id, name, category, phone, address, pendingBalance, adminName } = req.body;
    if (!name || !category) {
      return res.status(400).json({ success: false, message: 'Name and category are required' });
    }

    const vendors = db.getCollectionForOrg('vendors', orgId);

    if (id) {
      const index = vendors.findIndex(v => v.id === id);
      if (index !== -1) {
        vendors[index] = {
          ...vendors[index],
          name: name.trim(),
          category: category.toUpperCase(),
          phone: phone || vendors[index].phone,
          address: address || vendors[index].address,
          pendingBalance: pendingBalance !== undefined ? parseFloat(pendingBalance) : vendors[index].pendingBalance
        };
        db.saveCollectionForOrg('vendors', orgId, vendors);

        logAudit({
          req,
          action: 'UPDATE_VENDOR',
          details: `Updated Supplier "${vendors[index].name}" (${vendors[index].category}). Pending Khata: ₹${vendors[index].pendingBalance}`,
          adminName
        });

        return res.json({ success: true, data: vendors[index] });
      }
    }

    const newVendor = {
      id: `ven-${uuidv4().substring(0, 8)}`,
      orgId,
      name: name.trim(),
      category: category.toUpperCase(),
      phone: phone || '',
      address: address || '',
      pendingBalance: parseFloat(pendingBalance) || 0,
      createdAt: new Date().toISOString()
    };

    vendors.push(newVendor);
    db.saveCollectionForOrg('vendors', orgId, vendors);

    logAudit({
      req,
      action: 'CREATE_VENDOR',
      details: `Added new Supplier "${newVendor.name}" (${newVendor.category}, Phone: ${newVendor.phone}). Opening Balance: ₹${newVendor.pendingBalance}`,
      adminName
    });

    res.status(201).json({ success: true, data: newVendor });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// Bulk Extend Mess Validity for All Mess Students (Admin Only)
exports.bulkExtendMessValidity = (req, res) => {
  try {
    const orgId = extractOrgId(req);
    const { days, reason, targetMemberType = 'ALL' } = req.body;
    const adminUser = req.admin;

    const extensionDays = parseInt(days);
    if (isNaN(extensionDays) || extensionDays <= 0) {
      return res.status(400).json({
        success: false,
        message: 'Please provide a valid number of days to extend (must be greater than 0).'
      });
    }

    const adminName = adminUser?.name || req.body.adminName || 'Admin';

    let allStudents = db.getCollectionForOrg('students', orgId);
    let updatedCount = 0;
    const updatedStudentsList = [];

    allStudents = allStudents.map(student => {
      if (student.status === 'ARCHIVED') return student;

      const isMessMember = student.memberType === 'MESS_ONLY' || student.enrolledInMess !== false;
      if (!isMessMember) return student;

      // Filter by target member type if specified
      if (targetMemberType === 'OUTSIDE_ONLY' && student.memberType !== 'MESS_ONLY') return student;
      if (targetMemberType === 'HOSTEL_ONLY' && student.memberType !== 'HOSTEL_RESIDENT') return student;

      // Current expiry date (fallback to today if missing/invalid)
      let currentExpiry;
      if (student.messExpiryDate && !isNaN(new Date(student.messExpiryDate).getTime())) {
        currentExpiry = new Date(student.messExpiryDate);
      } else {
        currentExpiry = new Date();
      }

      // Add extension days
      currentExpiry.setDate(currentExpiry.getDate() + extensionDays);
      const newExpiryDateStr = currentExpiry.toISOString().split('T')[0];

      // Update cycleDay according to the new expiry date day of month
      const newCycleDay = currentExpiry.getDate();

      // Recalculate dynamic status
      const messStatus = calculateCycleStatus(newExpiryDateStr, 5);

      const updatedStudent = {
        ...student,
        messExpiryDate: newExpiryDateStr,
        cycleDay: newCycleDay,
        status: (student.status === 'EXPIRED' && messStatus.status !== 'EXPIRED') ? 'ACTIVE' : student.status,
        updatedAt: new Date().toISOString()
      };

      // Also keep non-deletable Master Register synchronized
      db.upsertMasterRegister(updatedStudent, orgId);

      updatedCount++;
      updatedStudentsList.push({
        id: updatedStudent.id,
        name: updatedStudent.name,
        memberType: updatedStudent.memberType,
        roomNumber: updatedStudent.roomNumber,
        previousExpiry: student.messExpiryDate,
        newExpiryDate: newExpiryDateStr,
        newCycleDay: newCycleDay
      });

      return updatedStudent;
    });

    db.saveCollectionForOrg('students', orgId, allStudents);

    // Record audit trail
    const extensionReason = reason?.trim() ? `Reason: "${reason.trim()}"` : 'Administrative Extension';
    logAudit({
      req,
      action: 'BULK_EXTEND_MESS_VALIDITY',
      details: `${adminName} extended mess validity by +${extensionDays} days for ${updatedCount} mess students (${targetMemberType}). ${extensionReason}`,
      adminName: adminName,
      adminId: adminUser?.id
    });

    res.json({
      success: true,
      message: `Successfully extended mess validity by +${extensionDays} days for ${updatedCount} students.`,
      data: {
        extendedDays: extensionDays,
        updatedCount,
        reason: reason || 'Admin Extension',
        targetMemberType,
        students: updatedStudentsList
      }
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

