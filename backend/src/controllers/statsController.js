const db = require('../config/db');
const { calculateCycleStatus, generateWhatsAppReminder } = require('../services/expiryService');
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
      const messStatus = calculateCycleStatus(student.messExpiryDate, 5);

      const studentPayments = payments.filter(p => p.studentId === student.id);
      const totalRentAgreed = parseFloat(student.totalRentAgreed !== undefined ? student.totalRentAgreed : (student.rentAmountPerTerm || 0));
      const totalRentPaid = studentPayments
        .filter(p => p.feeType === 'RENT' || (p.feeType === 'BOTH' && p.rentAmount > 0))
        .reduce((sum, p) => sum + (parseFloat(p.rentAmount) || (p.feeType === 'RENT' ? parseFloat(p.amount) : 0)), 0);
      const rentBalanceDue = Math.max(0, totalRentAgreed - totalRentPaid);

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
        totalRentAgreed,
        totalRentPaid,
        rentBalanceDue,

        messDynamicStatus: student.enrolledInMess ? messStatus.status : 'ACTIVE',
        messStatusLabel: student.enrolledInMess ? messStatus.label : 'Not Enrolled',
        messDaysRemaining: student.enrolledInMess ? messStatus.daysDiff : 999,

        rentDynamicStatus,
        rentStatusLabel,
        rentDaysRemaining: rentBalanceDue > 0 ? -1 : 999,

        whatsappReminder: generateWhatsAppReminder({
          ...student,
          totalRentAgreed,
          totalRentPaid,
          rentBalanceDue
        })
      };

      if (student.enrolledInMess) {
        if (messStatus.status === 'EXPIRING_SOON') messExpiringSoon.push(enriched);
        if (messStatus.status === 'EXPIRED') messOverdue.push(enriched);
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
      const messStatus = calculateCycleStatus(student.messExpiryDate, 5);

      const studentPayments = payments.filter(p => p.studentId === student.id);
      const totalRentAgreed = parseFloat(student.totalRentAgreed !== undefined ? student.totalRentAgreed : (student.rentAmountPerTerm || 0));
      const totalRentPaid = studentPayments
        .filter(p => p.feeType === 'RENT' || (p.feeType === 'BOTH' && p.rentAmount > 0))
        .reduce((sum, p) => sum + (parseFloat(p.rentAmount) || (p.feeType === 'RENT' ? parseFloat(p.amount) : 0)), 0);
      const rentBalanceDue = Math.max(0, totalRentAgreed - totalRentPaid);

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
        totalRentAgreed,
        totalRentPaid,
        rentBalanceDue,

        messDynamicStatus: student.enrolledInMess ? messStatus.status : 'ACTIVE',
        messStatusLabel: student.enrolledInMess ? messStatus.label : 'Not Enrolled',
        messDaysRemaining: student.enrolledInMess ? messStatus.daysDiff : 999,

        rentDynamicStatus,
        rentStatusLabel,
        rentDaysRemaining: rentBalanceDue > 0 ? -1 : 999,

        whatsappReminder: generateWhatsAppReminder({
          ...student,
          totalRentAgreed,
          totalRentPaid,
          rentBalanceDue
        })
      };

      if (student.enrolledInMess) {
        if (messStatus.status === 'EXPIRING_SOON') messExpiringSoon.push(enriched);
        if (messStatus.status === 'EXPIRED') messOverdue.push(enriched);
      }

      if (student.memberType === 'HOSTEL_RESIDENT') {
        if (rentDynamicStatus === 'EXPIRING_SOON') rentExpiringSoon.push(enriched);
        if (rentDynamicStatus === 'EXPIRED') rentOverdue.push(enriched);
      }

      const isMessClear = !student.enrolledInMess || messStatus.status === 'ACTIVE';
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
        receiptNo: p.receiptNo
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

