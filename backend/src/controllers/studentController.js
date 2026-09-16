const db = require('../config/db');
const { v4: uuidv4 } = require('uuid');
const { calculateCycleStatus, calculateElapsedMessCycles, calculateMessExpiryDate, generateWhatsAppReminder } = require('../services/expiryService');
const { logAudit } = require('../services/auditService');
const { extractOrgId } = require('../middleware/authMiddleware');
const storageService = require('../services/storageService');

// Enrich student with distinct Mess & Rent statuses and payment balances
function enrichStudent(student, preloadedPayments) {
  const targetOrgId = student.orgId || 'org-default';

  // Calculate total agreed rent and total payments from payments collection
  const payments = preloadedPayments || db.getCollectionForOrg('payments', targetOrgId).filter(p => p.studentId === student.id);
  const totalRentAgreed = parseFloat(student.totalRentAgreed !== undefined ? student.totalRentAgreed : (student.rentAmountPerTerm || 0));

  const totalRentPaid = payments
    .filter(p => p.feeType === 'RENT' || (p.feeType === 'BOTH' && p.rentAmount > 0))
    .reduce((sum, p) => sum + (parseFloat(p.rentAmount) || (p.feeType === 'RENT' ? parseFloat(p.amount) : 0)), 0);

  const rentBalanceDue = Math.max(0, totalRentAgreed - totalRentPaid);

  const totalMessPaid = payments
    .filter(p => p.feeType === 'MESS' || (p.feeType === 'BOTH' && p.messAmount > 0))
    .reduce((sum, p) => sum + (parseFloat(p.messAmount) || (p.feeType === 'MESS' ? parseFloat(p.amount) : 0)), 0);

  // Mess Dues & Expiry Deterministic Calculation
  const monthlyMessFee = parseFloat(student.monthlyMessFee) || 3500;
  let messBalanceDue = 0;
  let computedMessExpiry = student.messExpiryDate;
  const messStartDate = student.messStartDate || (student.enrolledInMess ? (student.admissionDate || student.createdAt || new Date().toISOString().split('T')[0]) : null);

  if (student.enrolledInMess && messStartDate) {
    computedMessExpiry = calculateMessExpiryDate(messStartDate, totalMessPaid, monthlyMessFee);
    const elapsedCycles = calculateElapsedMessCycles(messStartDate);
    const totalMessBilled = elapsedCycles * monthlyMessFee;
    messBalanceDue = Math.max(0, totalMessBilled - totalMessPaid);
  }

  const messCycleStatus = calculateCycleStatus(computedMessExpiry, 5);
  let messDynamicStatus = 'ACTIVE';
  let messStatusLabel = '';

  if (!student.enrolledInMess) {
    messDynamicStatus = 'ACTIVE';
    messStatusLabel = 'Not Enrolled';
  } else if (messBalanceDue > 0) {
    if (messCycleStatus.status === 'EXPIRED') {
      messDynamicStatus = 'EXPIRED';
      messStatusLabel = `₹${messBalanceDue.toFixed(0)} Due (Overdue)`;
    } else {
      messDynamicStatus = 'EXPIRING_SOON';
      messStatusLabel = `₹${messBalanceDue.toFixed(0)} Due (Month Due)`;
    }
  } else {
    messDynamicStatus = messCycleStatus.status;
    messStatusLabel = messCycleStatus.label;
  }

  let rentDynamicStatus = 'ACTIVE';
  let rentStatusLabel = '';

  if (student.memberType === 'HOSTEL_RESIDENT') {
    if (totalRentAgreed <= 0) {
      rentDynamicStatus = 'ACTIVE';
      rentStatusLabel = 'No Rent Set';
    } else if (rentBalanceDue <= 0) {
      rentDynamicStatus = 'ACTIVE';
      rentStatusLabel = 'Full Paid';
    } else if (totalRentPaid > 0) {
      rentDynamicStatus = 'EXPIRING_SOON';
      rentStatusLabel = `₹${rentBalanceDue.toFixed(0)} Due`;
    } else {
      rentDynamicStatus = 'EXPIRED';
      rentStatusLabel = `₹${rentBalanceDue.toFixed(0)} Due (Unpaid)`;
    }
  } else {
    rentDynamicStatus = 'ACTIVE';
    rentStatusLabel = 'N/A (Day Scholar)';
  }

  const rentDaysRemaining = rentBalanceDue > 0 ? -1 : 999;

  // Overall status: if mess overdue or rent unpaid -> EXPIRED / EXPIRING_SOON
  let dynamicStatus = 'ACTIVE';
  if ((student.enrolledInMess && (messDynamicStatus === 'EXPIRED' || messBalanceDue > 0)) || (student.memberType === 'HOSTEL_RESIDENT' && rentDynamicStatus === 'EXPIRED')) {
    dynamicStatus = (messDynamicStatus === 'EXPIRED' || rentDynamicStatus === 'EXPIRED') ? 'EXPIRED' : 'EXPIRING_SOON';
  } else if ((student.enrolledInMess && messDynamicStatus === 'EXPIRING_SOON') || (student.memberType === 'HOSTEL_RESIDENT' && rentDynamicStatus === 'EXPIRING_SOON')) {
    dynamicStatus = 'EXPIRING_SOON';
  }

  return {
    ...student,
    orgId: targetOrgId,
    admissionDate: student.admissionDate || '',
    messStartDate: messStartDate,
    messExpiryDate: computedMessExpiry,
    totalRentAgreed,
    totalRentPaid,
    rentBalanceDue,
    totalMessPaid,
    messBalanceDue,
    totalPaidAll: totalRentPaid + totalMessPaid,

    messDynamicStatus,
    messStatusLabel,
    messDaysRemaining: student.enrolledInMess ? messCycleStatus.daysDiff : 999,

    rentDynamicStatus,
    rentStatusLabel,
    rentDaysRemaining,

    dynamicStatus,
    statusLabel: student.enrolledInMess
      ? `Mess: ${messStatusLabel} | Rent: ${rentStatusLabel}`
      : `Hostel Rent: ${rentStatusLabel}`,
    whatsappReminder: generateWhatsAppReminder({
      ...student,
      messStartDate,
      messExpiryDate: computedMessExpiry,
      messBalanceDue,
      totalRentAgreed,
      totalRentPaid,
      rentBalanceDue
    })
  };
}

// Get all students
exports.getStudents = (req, res) => {
  try {
    const orgId = extractOrgId(req);
    const { search, status, roomId, duesType } = req.query;
    const orgPayments = db.getCollectionForOrg('payments', orgId);
    let students = db.getCollectionForOrg('students', orgId).filter(s => s.status !== 'ARCHIVED');

    let enriched = students.map(s => {
      const studentPayments = orgPayments.filter(p => p.studentId === s.id);
      return enrichStudent(s, studentPayments);
    });

    if (search) {
      const q = search.toLowerCase();
      enriched = enriched.filter(s =>
        s.name.toLowerCase().includes(q) ||
        s.phone.includes(q) ||
        (s.roomNumber && s.roomNumber.toLowerCase().includes(q)) ||
        (s.parentName && s.parentName.toLowerCase().includes(q))
      );
    }

    if (status) {
      enriched = enriched.filter(s => s.dynamicStatus === status.toUpperCase());
    }

    if (duesType === 'MESS') {
      enriched = enriched.filter(s => s.messDynamicStatus !== 'ACTIVE');
    } else if (duesType === 'RENT') {
      enriched = enriched.filter(s => s.rentDynamicStatus !== 'ACTIVE');
    }

    if (roomId) {
      enriched = enriched.filter(s => s.roomId === roomId);
    }

    res.json({
      success: true,
      count: enriched.length,
      data: enriched
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// Get single student by ID
exports.getStudentById = (req, res) => {
  try {
    const orgId = extractOrgId(req);
    const { id } = req.params;
    const students = db.getCollectionForOrg('students', orgId);
    let student = students.find(s => s.id === id);

    if (!student) {
      // Check if it's a mess-only member or archived student
      const messMembers = db.getCollectionForOrg('mess_members', orgId);
      const messMem = messMembers.find(m => m.id === id || m.studentId === id);
      if (messMem) {
        student = {
          id: messMem.id,
          name: messMem.name,
          phone: messMem.phone,
          memberType: 'MESS_ONLY',
          enrolledInMess: true,
          messPlan: messMem.plan || 'MONTHLY',
          messStartDate: messMem.startDate || messMem.createdAt,
          messExpiryDate: messMem.expiryDate,
          messDietType: messMem.dietType || 'VEG',
          roomNumber: 'N/A (Day Scholar)',
          totalRentAgreed: 0,
          orgId: messMem.orgId || orgId,
          status: messMem.status || 'ACTIVE'
        };
      } else {
        const master = db.getCollectionForOrg('master_register', orgId);
        const masterRec = master.find(m => m.id === id || m.originalId === id);
        if (masterRec) {
          student = { ...masterRec, orgId };
        }
      }
    }

    if (!student) {
      return res.status(404).json({ success: false, message: 'Student / Member not found' });
    }

    const payments = db.getCollectionForOrg('payments', orgId).filter(p => p.studentId === id || (student.originalId && p.studentId === student.originalId));
    payments.sort((a, b) => new Date(b.paymentDate) - new Date(a.paymentDate));

    const leaveLogs = db.getCollectionForOrg('leave_logs', orgId).filter(l => l.studentId === id);
    leaveLogs.sort((a, b) => new Date(b.departureDate) - new Date(a.departureDate));

    res.json({
      success: true,
      data: {
        ...enrichStudent(student, payments),
        payments,
        leaveLogs
      }
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// Register new student
exports.createStudent = async (req, res) => {
  try {
    const orgId = extractOrgId(req);
    const {
      name,
      phone,
      parentPhone,
      parentName,
      photoUrl,
      roomId,
      bedNo,
      admissionDate,
      messStartDate,
      cycleDay,
      monthlyMessFee,
      totalRentAgreed,
      rentTermMonths,
      rentAmountPerTerm,
      enrolledInMess = true,
      notes,
      adminName
    } = req.body;

    if (!name || !phone || !roomId || !bedNo) {
      return res.status(400).json({ success: false, message: 'Name, phone, room and bedNo are required' });
    }

    const rooms = db.getCollectionForOrg('rooms', orgId);
    const room = rooms.find(r => r.id === roomId);
    if (!room) {
      return res.status(404).json({ success: false, message: 'Selected room does not exist' });
    }

    const students = db.getCollectionForOrg('students', orgId);
    const bedTaken = students.some(s => s.roomId === roomId && s.bedNo === bedNo && s.status !== 'ARCHIVED');
    if (bedTaken) {
      return res.status(400).json({ success: false, message: `Bed ${bedNo} in Room ${room.roomNumber} is already occupied` });
    }

    const admDate = admissionDate || new Date().toISOString().split('T')[0];
    const isMessEnrolled = enrolledInMess !== false;
    const mStartDate = isMessEnrolled ? (messStartDate || admDate) : null;
    const mFee = parseFloat(monthlyMessFee) || 3500;
    const cDay = cycleDay ? parseInt(cycleDay) : new Date(admDate).getDate();

    // 1 Month initial Mess expiry granted at enrollment even if not paid upfront
    const messExpiryDateStr = isMessEnrolled ? calculateMessExpiryDate(mStartDate, 0, mFee) : null;

    // Term/Semester initial Rent expiry (e.g. 6 or 4 months)
    const termMonths = parseInt(rentTermMonths) || 6;
    const rentExp = new Date(admDate);
    rentExp.setMonth(rentExp.getMonth() + termMonths);

    const agreedRent = totalRentAgreed !== undefined ? parseFloat(totalRentAgreed) : (parseFloat(rentAmountPerTerm) || 27000);

    // ☁️ Offload photo to Supabase Storage (prevents Base64 database bloat)
    const storedPhotoUrl = await storageService.processImage(photoUrl, 'students');

    const newStudent = {
      id: `stud-${uuidv4().substring(0, 8)}`,
      orgId: orgId,
      memberType: 'HOSTEL_RESIDENT',
      enrolledInMess: isMessEnrolled,
      photoUrl: storedPhotoUrl || '',
      name: name.trim(),
      phone: phone.trim(),
      parentPhone: (parentPhone || '').trim(),
      parentName: (parentName || '').trim(),
      roomId,
      roomNumber: room.roomNumber,
      bedNo: bedNo.toUpperCase().trim(),
      admissionDate: admDate,
      messStartDate: mStartDate,
      cycleDay: cDay,
      monthlyMessFee: mFee,
      messExpiryDate: messExpiryDateStr,
      totalRentAgreed: agreedRent,
      rentTermMonths: termMonths,
      rentAmountPerTerm: agreedRent,
      rentExpiryDate: rentExp.toISOString().split('T')[0],
      status: 'ACTIVE',
      notes: notes || '',
      createdAt: new Date().toISOString()
    };

    students.push(newStudent);
    db.saveCollectionForOrg('students', orgId, students);

    // 📜 Upsert into non-deletable Master Register
    db.upsertMasterRegister(newStudent, orgId, { status: 'ACTIVE' });

    // Update room occupancy
    room.occupiedBeds = students.filter(s => s.roomId === roomId && s.status !== 'ARCHIVED').length;
    room.status = room.occupiedBeds >= room.totalBeds ? 'FULL' : 'AVAILABLE';
    db.saveCollectionForOrg('rooms', orgId, rooms);

    // 🛡️ Comprehensive Audit Log
    logAudit({
      req,
      action: 'ADD_STUDENT',
      details: `Enrolled new resident ${newStudent.name} (Phone: ${newStudent.phone}) in Room ${room.roomNumber} (Bed ${newStudent.bedNo}). Hostel Adm: ${newStudent.admissionDate}, Mess Start: ${newStudent.messStartDate || 'N/A'}. Total Agreed Rent: ₹${newStudent.totalRentAgreed}, Mess: ₹${newStudent.monthlyMessFee}/mo (${newStudent.enrolledInMess ? "Enrolled" : "Hostel Only"})`,
      adminName
    });

    res.status(201).json({ success: true, data: enrichStudent(newStudent) });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// Update existing student details
exports.updateStudent = async (req, res) => {
  try {
    const orgId = extractOrgId(req);
    const { id } = req.params;
    const students = db.getCollectionForOrg('students', orgId);
    const index = students.findIndex(s => s.id === id);

    if (index === -1) {
      return res.status(404).json({ success: false, message: 'Student not found' });
    }

    const {
      name,
      phone,
      parentPhone,
      parentName,
      photoUrl,
      admissionDate,
      messStartDate,
      enrolledInMess,
      monthlyMessFee,
      messExpiryDate,
      totalRentAgreed,
      rentTermMonths,
      rentAmountPerTerm,
      rentExpiryDate,
      notes,
      adminName
    } = req.body;

    const updatedRentAgreed = totalRentAgreed !== undefined
      ? parseFloat(totalRentAgreed)
      : (rentAmountPerTerm !== undefined ? parseFloat(rentAmountPerTerm) : students[index].totalRentAgreed);

    // ☁️ Offload updated photo to Supabase Storage if Base64
    let storedPhotoUrl = students[index].photoUrl || '';
    if (photoUrl !== undefined) {
      storedPhotoUrl = await storageService.processImage(photoUrl, 'students');
    }

    const updatedAdmissionDate = admissionDate !== undefined ? admissionDate : students[index].admissionDate;
    const isMess = enrolledInMess !== undefined ? enrolledInMess : students[index].enrolledInMess;
    const updatedMessStartDate = isMess
      ? (messStartDate !== undefined ? messStartDate : (students[index].messStartDate || updatedAdmissionDate))
      : null;

    let updatedMessExpiry = messExpiryDate !== undefined ? messExpiryDate : students[index].messExpiryDate;
    if (isMess && (!updatedMessExpiry || updatedMessExpiry === '')) {
      const fee = monthlyMessFee !== undefined ? parseFloat(monthlyMessFee) : (students[index].monthlyMessFee || 3500);
      updatedMessExpiry = calculateMessExpiryDate(updatedMessStartDate, 0, fee);
    }

    students[index] = {
      ...students[index],
      name: name !== undefined ? name.trim() : students[index].name,
      phone: phone !== undefined ? phone.trim() : students[index].phone,
      parentPhone: parentPhone !== undefined ? parentPhone.trim() : students[index].parentPhone,
      parentName: parentName !== undefined ? parentName.trim() : students[index].parentName,
      photoUrl: storedPhotoUrl,
      admissionDate: updatedAdmissionDate,
      messStartDate: updatedMessStartDate,
      enrolledInMess: isMess,
      monthlyMessFee: monthlyMessFee !== undefined ? parseFloat(monthlyMessFee) : students[index].monthlyMessFee,
      messExpiryDate: updatedMessExpiry,
      totalRentAgreed: updatedRentAgreed !== undefined ? updatedRentAgreed : (students[index].rentAmountPerTerm || 0),
      rentTermMonths: rentTermMonths !== undefined ? parseInt(rentTermMonths) : students[index].rentTermMonths,
      rentAmountPerTerm: updatedRentAgreed !== undefined ? updatedRentAgreed : students[index].rentAmountPerTerm,
      rentExpiryDate: rentExpiryDate !== undefined ? rentExpiryDate : students[index].rentExpiryDate,
      notes: notes !== undefined ? notes : students[index].notes,
      updatedAt: new Date().toISOString()
    };

    db.saveCollectionForOrg('students', orgId, students);

    // 📜 Upsert into non-deletable Master Register
    db.upsertMasterRegister(students[index], orgId);

    // 🛡️ Audit Log for Student Profile Updates
    logAudit({
      req,
      action: 'UPDATE_STUDENT',
      details: `Updated details for resident ${students[index].name} (Room ${students[index].roomNumber}, Bed ${students[index].bedNo})`,
      adminName
    });

    res.json({ success: true, data: enrichStudent(students[index]) });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// Shift Bed
exports.shiftBed = (req, res) => {
  try {
    const orgId = extractOrgId(req);
    const { id } = req.params;
    const { targetRoomId, targetBedNo, adminName } = req.body;

    const students = db.getCollectionForOrg('students', orgId);
    const student = students.find(s => s.id === id);
    if (!student) return res.status(404).json({ success: false, message: 'Student not found' });

    const rooms = db.getCollectionForOrg('rooms', orgId);
    const newRoom = rooms.find(r => r.id === targetRoomId);
    if (!newRoom) return res.status(404).json({ success: false, message: 'Target room not found' });

    const oldRoomNumber = student.roomNumber;
    const oldBedNo = student.bedNo;

    student.roomId = targetRoomId;
    student.roomNumber = newRoom.roomNumber;
    student.bedNo = targetBedNo.toUpperCase().trim();
    student.updatedAt = new Date().toISOString();

    db.saveCollectionForOrg('students', orgId, students);

    // 📜 Upsert into non-deletable Master Register
    db.upsertMasterRegister(student, orgId);

    rooms.forEach(r => {
      r.occupiedBeds = students.filter(s => s.roomId === r.id && s.status !== 'ARCHIVED').length;
      r.status = r.occupiedBeds >= r.totalBeds ? 'FULL' : 'AVAILABLE';
    });
    db.saveCollectionForOrg('rooms', orgId, rooms);

    // 🛡️ Audit Log for Bed Shift
    logAudit({
      req,
      action: 'SHIFT_BED',
      details: `Shifted resident ${student.name} from Room ${oldRoomNumber} (Bed ${oldBedNo}) to Room ${newRoom.roomNumber} (Bed ${student.bedNo})`,
      adminName
    });

    res.json({ success: true, message: 'Bed shifted successfully', data: enrichStudent(student) });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// Checkout Student
exports.checkoutStudent = (req, res) => {
  try {
    const orgId = extractOrgId(req);
    const { id } = req.params;
    const { adminName, reason, removeFromMess } = req.body || {};

    const students = db.getCollectionForOrg('students', orgId);
    const student = students.find(s => s.id === id);
    if (!student) return res.status(404).json({ success: false, message: 'Student not found' });

    student.status = 'ARCHIVED';
    student.checkoutDate = new Date().toISOString();
    student.checkoutReason = reason || 'Left Hostel';

    if (removeFromMess === true) {
      student.enrolledInMess = false;
      student.monthlyMessFee = 0;
    }

    db.saveCollectionForOrg('students', orgId, students);

    // 📜 Upsert into non-deletable Master Register (Marks as LEFT with exit reason, NEVER DELETES)
    db.upsertMasterRegister(student, orgId, {
      status: 'LEFT',
      leftDate: student.checkoutDate,
      exitReason: student.checkoutReason
    });

    const rooms = db.getCollectionForOrg('rooms', orgId);
    rooms.forEach(r => {
      r.occupiedBeds = students.filter(s => s.roomId === r.id && s.status !== 'ARCHIVED').length;
      r.status = r.occupiedBeds >= r.totalBeds ? 'FULL' : 'AVAILABLE';
    });
    db.saveCollectionForOrg('rooms', orgId, rooms);

    // 🛡️ Audit Log for Resident Checkout
    logAudit({
      req,
      action: removeFromMess ? 'CHECKOUT_HOSTEL_AND_MESS' : 'CHECKOUT_STUDENT',
      details: `Checked out resident ${student.name} from Room ${student.roomNumber} (Bed ${student.bedNo})${removeFromMess ? ' and unenrolled from Mess' : ''}. Reason: ${student.checkoutReason}. Bed is now vacant.`,
      adminName: adminName || (req.admin && req.admin.name) || 'Admin'
    });

    res.json({ success: true, message: 'Student checked out successfully' });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// Delete Student Record Permanently from active list (Retained permanently in Master Register)
exports.deleteStudent = (req, res) => {
  try {
    const orgId = extractOrgId(req);
    const { id } = req.params;
    const adminName = (req.body && req.body.adminName) || req.query.adminName || (req.admin && req.admin.name) || 'Admin';

    let students = db.getCollectionForOrg('students', orgId);
    const student = students.find(s => s.id === id);
    if (!student) return res.status(404).json({ success: false, message: 'Student record not found' });

    // 📜 Preserve in non-deletable Master Register before removing from active table
    db.upsertMasterRegister(student, orgId, {
      status: 'LEFT',
      leftDate: student.checkoutDate || new Date().toISOString(),
      exitReason: student.checkoutReason || 'Deleted from active resident list'
    });

    students = students.filter(s => s.id !== id);
    db.saveCollectionForOrg('students', orgId, students);

    // Refresh room counts
    const rooms = db.getCollectionForOrg('rooms', orgId);
    rooms.forEach(r => {
      r.occupiedBeds = students.filter(s => s.roomId === r.id && s.status !== 'ARCHIVED').length;
      r.status = r.occupiedBeds >= r.totalBeds ? 'FULL' : 'AVAILABLE';
    });
    db.saveCollectionForOrg('rooms', orgId, rooms);

    // 🛡️ Audit Log for Student Deletion
    logAudit({
      req,
      action: 'DELETE_STUDENT',
      details: `Deleted active record for ${student.name} (Room ${student.roomNumber}, Phone: ${student.phone}). Archived permanently in Master Register.`,
      adminName
    });

    res.json({ success: true, message: 'Student record removed from active list and preserved in Master Register' });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

