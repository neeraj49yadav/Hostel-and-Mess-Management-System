const db = require('../config/db');
const { calculateCycleStatus, calculateElapsedMessCycles, calculateMessExpiryDate, generateWhatsAppReminder } = require('../services/expiryService');
const { extractOrgId } = require('../middleware/authMiddleware');

exports.getDashboardStats = (req, res) => {
  try {
    const orgId = extractOrgId(req);
    const students = db.getCollectionForOrg('students', orgId).filter(s => s.status !== 'ARCHIVED');
    const rooms = db.getCollectionForOrg('rooms', orgId);
    const payments = db.getCollectionForOrg('payments', orgId);
    const expenses = db.getCollectionForOrg('mess_expenses', orgId);
    const leaveLogs = db.getCollectionForOrg('leave_logs', orgId);

    const currentMonth = new Date().toISOString().substring(0, 7);

    // Bed metrics: Only count students staying in the hostel rooms
    const hostelResidents = students.filter(s => s.memberType === 'HOSTEL_RESIDENT');
    const totalBeds = rooms.reduce((acc, r) => acc + (r.totalBeds || 0), 0);
    const occupiedBeds = hostelResidents.length;
    const vacantBeds = Math.max(0, totalBeds - occupiedBeds);

    const messExpiringSoon = [];
    const messOverdue = [];
    const rentExpiringSoon = [];
    const rentOverdue = [];

    students.forEach(student => {
      const studentPayments = payments.filter(p => p.studentId === student.id);
      const totalRentAgreed = parseFloat(student.totalRentAgreed !== undefined ? student.totalRentAgreed : (student.rentAmountPerTerm || 0));
      const totalRentPaid = studentPayments
        .filter(p => p.feeType === 'RENT' || (p.feeType === 'BOTH' && p.rentAmount > 0))
        .reduce((sum, p) => sum + (parseFloat(p.rentAmount) || (p.feeType === 'RENT' ? parseFloat(p.amount) : 0)), 0);
      const rentBalanceDue = Math.max(0, totalRentAgreed - totalRentPaid);

      const totalMessPaid = studentPayments
        .filter(p => p.feeType === 'MESS' || (p.feeType === 'BOTH' && p.messAmount > 0))
        .reduce((sum, p) => sum + (parseFloat(p.messAmount) || (p.feeType === 'MESS' ? parseFloat(p.amount) : 0)), 0);

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
        rentStatusLabel = 'N/A';
      }

      const enriched = {
        ...student,
        orgId,
        admissionDate: student.admissionDate || '',
        messStartDate: messStartDate,
        messExpiryDate: computedMessExpiry,
        totalRentAgreed,
        totalRentPaid,
        rentBalanceDue,
        totalMessPaid,
        messBalanceDue,

        messDynamicStatus,
        messStatusLabel,
        messDaysRemaining: student.enrolledInMess ? messCycleStatus.daysDiff : 999,

        rentDynamicStatus,
        rentStatusLabel,
        rentDaysRemaining: rentBalanceDue > 0 ? -1 : 999,

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

      if (student.enrolledInMess) {
        if (messDynamicStatus === 'EXPIRING_SOON') messExpiringSoon.push(enriched);
        if (messDynamicStatus === 'EXPIRED') messOverdue.push(enriched);
      }

      if (student.memberType === 'HOSTEL_RESIDENT') {
        if (rentDynamicStatus === 'EXPIRING_SOON') rentExpiringSoon.push(enriched);
        if (rentDynamicStatus === 'EXPIRED') rentOverdue.push(enriched);
      }
    });

    messExpiringSoon.sort((a, b) => a.messDaysRemaining - b.messDaysRemaining);
    messOverdue.sort((a, b) => a.messDaysRemaining - b.messDaysRemaining);
    rentExpiringSoon.sort((a, b) => a.rentDaysRemaining - b.rentDaysRemaining);
    rentOverdue.sort((a, b) => a.rentDaysRemaining - b.rentDaysRemaining);

    // Financials this month
    const monthPayments = payments.filter(p => p.paymentDate && p.paymentDate.startsWith(currentMonth));
    const monthRentInflow = monthPayments.reduce((acc, p) => acc + (p.rentAmount || 0), 0);
    const monthMessInflow = monthPayments.reduce((acc, p) => acc + (p.messAmount || 0), 0);
    const totalInflow = monthRentInflow + monthMessInflow;

    const monthExpenses = expenses.filter(e => e.date && e.date.startsWith(currentMonth));
    const totalMessExpense = monthExpenses.reduce((acc, e) => acc + (e.amount || 0), 0);

    const netProfitBalance = totalInflow - totalMessExpense;
    const currentlyOutCount = leaveLogs.filter(l => l.status === 'OUT').length;

    res.json({
      success: true,
      data: {
        students: {
          total: students.length,
          messExpiringSoonCount: messExpiringSoon.length,
          messOverdueCount: messOverdue.length,
          rentExpiringSoonCount: rentExpiringSoon.length,
          rentOverdueCount: rentOverdue.length,
          totalOverdueCount: messOverdue.length + rentOverdue.length
        },
        rooms: {
          totalRooms: rooms.length,
          totalBeds,
          occupiedBeds,
          vacantBeds,
          occupancyPercentage: totalBeds > 0 ? Math.round((occupiedBeds / totalBeds) * 100) : 0
        },
        financials: {
          currentMonth,
          monthRentInflow,
          monthMessInflow,
          totalInflow,
          totalMessExpense,
          netProfitBalance,
          isProfitable: netProfitBalance >= 0
        },
        leaves: {
          currentlyOutCount
        },
        alerts: {
          messExpiringSoon,
          messOverdue,
          rentExpiringSoon,
          rentOverdue
        }
      }
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// Dues & Expiries Tab Hub
exports.getDuesAndExpiries = (req, res) => {
  try {
    const orgId = extractOrgId(req);
    const students = db.getCollectionForOrg('students', orgId).filter(s => s.status !== 'ARCHIVED');

    const messExpiringSoon = [];
    const messOverdue = [];
    const rentExpiringSoon = [];
    const rentOverdue = [];
    const active = [];

    const payments = db.getCollectionForOrg('payments', orgId);

    students.forEach(student => {
      const studentPayments = payments.filter(p => p.studentId === student.id);
      const totalRentAgreed = parseFloat(student.totalRentAgreed !== undefined ? student.totalRentAgreed : (student.rentAmountPerTerm || 0));
      const totalRentPaid = studentPayments
        .filter(p => p.feeType === 'RENT' || (p.feeType === 'BOTH' && p.rentAmount > 0))
        .reduce((sum, p) => sum + (parseFloat(p.rentAmount) || (p.feeType === 'RENT' ? parseFloat(p.amount) : 0)), 0);
      const rentBalanceDue = Math.max(0, totalRentAgreed - totalRentPaid);

      const totalMessPaid = studentPayments
        .filter(p => p.feeType === 'MESS' || (p.feeType === 'BOTH' && p.messAmount > 0))
        .reduce((sum, p) => sum + (parseFloat(p.messAmount) || (p.feeType === 'MESS' ? parseFloat(p.amount) : 0)), 0);

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
        rentStatusLabel = 'N/A';
      }

      const enriched = {
        ...student,
        orgId,
        admissionDate: student.admissionDate || '',
        messStartDate: messStartDate,
        messExpiryDate: computedMessExpiry,
        totalRentAgreed,
        totalRentPaid,
        rentBalanceDue,
        totalMessPaid,
        messBalanceDue,

        messDynamicStatus,
        messStatusLabel,
        messDaysRemaining: student.enrolledInMess ? messCycleStatus.daysDiff : 999,

        rentDynamicStatus,
        rentStatusLabel,
        rentDaysRemaining: rentBalanceDue > 0 ? -1 : 999,

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

      if (student.enrolledInMess) {
        if (messDynamicStatus === 'EXPIRING_SOON') messExpiringSoon.push(enriched);
        if (messDynamicStatus === 'EXPIRED') messOverdue.push(enriched);
      }

      if (student.memberType === 'HOSTEL_RESIDENT') {
        if (rentDynamicStatus === 'EXPIRING_SOON') rentExpiringSoon.push(enriched);
        if (rentDynamicStatus === 'EXPIRED') rentOverdue.push(enriched);
      }

      const isMessClear = !student.enrolledInMess || (messDynamicStatus === 'ACTIVE' && messBalanceDue <= 0);
      const isRentClear = student.memberType !== 'HOSTEL_RESIDENT' || rentDynamicStatus === 'ACTIVE';

      if (isMessClear && isRentClear) {
        active.push(enriched);
      }
    });

    res.json({
      success: true,
      messExpiringSoon,
      messOverdue,
      rentExpiringSoon,
      rentOverdue,
      active
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// Cashbook Statement
exports.getCashbook = (req, res) => {
  try {
    const orgId = extractOrgId(req);
    const { month } = req.query;
    const currentMonth = month || new Date().toISOString().substring(0, 7);

    const payments = db.getCollectionForOrg('payments', orgId);
    const expenses = db.getCollectionForOrg('mess_expenses', orgId);

    const inflows = payments
      .filter(p => !currentMonth || (p.paymentDate && p.paymentDate.startsWith(currentMonth)))
      .map(p => ({
        id: p.id,
        orgId,
        type: 'INFLOW',
        title: `Fee: ${p.studentName} (Room ${p.roomNumber})`,
        category: p.feeType,
        amount: p.amount,
        date: p.paymentDate,
        paymentMode: p.paymentMode,
        recordedBy: p.collectedByAdminName,
        receiptNo: p.receiptNo,
        targetMonth: p.targetMonth || null,
        studentId: p.studentId
      }));

    const outflows = expenses
      .filter(e => !currentMonth || (e.date && e.date.startsWith(currentMonth)))
      .map(e => ({
        id: e.id,
        orgId,
        type: 'OUTFLOW',
        title: e.title,
        category: e.category,
        amount: e.amount,
        date: e.date,
        paymentMode: e.paymentMode,
        recordedBy: e.recordedByAdminName,
        vendor: e.vendorName
      }));

    const transactions = [...inflows, ...outflows];
    transactions.sort((a, b) => new Date(b.date) - new Date(a.date));

    const totalInflow = inflows.reduce((acc, i) => acc + i.amount, 0);
    const totalOutflow = outflows.reduce((acc, o) => acc + o.amount, 0);
    const netCashflow = totalInflow - totalOutflow;

    res.json({
      success: true,
      month: currentMonth,
      totalInflow,
      totalOutflow,
      netCashflow,
      transactions
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

