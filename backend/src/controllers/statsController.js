const db = require('../config/db');
const { calculateCycleStatus, calculateMessLedger, generateWhatsAppReminder } = require('../services/expiryService');
const { extractOrgId } = require('../middleware/authMiddleware');

exports.getDashboardStats = (req, res) => {
  try {
    const orgId = extractOrgId(req);
    const students = db.getCollectionForOrg('students', orgId).filter(s => s.status !== 'ARCHIVED' && s.status !== 'MESS_AUTO_REMOVED' && s.status !== 'REMOVED_AUTO');
    const rooms = db.getCollectionForOrg('rooms', orgId);
    const payments = db.getCollectionForOrg('payments', orgId);
    const expenses = db.getCollectionForOrg('mess_expenses', orgId);
    const leaveLogs = db.getCollectionForOrg('leave_logs', orgId);

    const currentMonth = new Date().toISOString().substring(0, 7);
    const org = (db.getCollection('organizations') || []).find(o => o.id === orgId) || {};

    // Bed metrics: Only count students staying in the hostel rooms
    const hostelResidents = students.filter(s => s.memberType === 'HOSTEL_RESIDENT');
    const totalBeds = rooms.reduce((acc, r) => acc + (r.totalBeds || 0), 0);
    const occupiedBeds = hostelResidents.length;
    const vacantBeds = Math.max(0, totalBeds - occupiedBeds);

    const messPendingDues = [];
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

      // 🍽️ Accurate Mess Ledger Calculation
      const messLedger = calculateMessLedger(student, studentPayments);

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
        messStartDate: student.messStartDate,
        messExpiryDate: messLedger.messExpiryDate,
        totalRentAgreed,
        totalRentPaid,
        rentBalanceDue,
        totalMessPaid: messLedger.totalMessPaid,
        totalMessBilled: messLedger.totalMessBilled || (messLedger.totalMessPaid + messLedger.messBalanceDue),
        messBalanceDue: messLedger.messBalanceDue,

        mealsPerDay: student.mealsPerDay || 3,
        mealPlanType: student.mealPlanType || (student.mealsPerDay === 1 ? '1 Meal / Day' : (student.mealsPerDay === 2 ? '2 Meals / Day' : '3 Meals / Day (Full)')),
        mealSlots: student.mealSlots || ['Morning', 'Noon', 'Evening'],
        planValidityType: student.planValidityType || 'MONTHLY',
        planValidityDays: student.planValidityDays,

        messDynamicStatus: messLedger.messDynamicStatus,
        messStatusLabel: messLedger.messStatusLabel,
        messDaysRemaining: messLedger.messDaysRemaining,
        isOverdueMess: messLedger.isOverdue,
        isUpcomingMess: messLedger.isUpcoming,

        rentDynamicStatus,
        rentStatusLabel,
        rentDaysRemaining: rentBalanceDue > 0 ? -1 : 999,

        whatsappReminder: generateWhatsAppReminder({
          ...student,
          messStartDate: student.messStartDate,
          messExpiryDate: messLedger.messExpiryDate,
          messBalanceDue: messLedger.messBalanceDue,
          totalRentAgreed,
          totalRentPaid,
          rentBalanceDue
        }, 'BOTH', org),
        messWhatsAppReminder: generateWhatsAppReminder({
          ...student,
          messStartDate: student.messStartDate,
          messExpiryDate: messLedger.messExpiryDate,
          messBalanceDue: messLedger.messBalanceDue,
          totalRentAgreed,
          totalRentPaid,
          rentBalanceDue
        }, 'MESS', org),
        rentWhatsAppReminder: generateWhatsAppReminder({
          ...student,
          messStartDate: student.messStartDate,
          messExpiryDate: messLedger.messExpiryDate,
          messBalanceDue: messLedger.messBalanceDue,
          totalRentAgreed,
          totalRentPaid,
          rentBalanceDue
        }, 'RENT', org)
      };

      if (student.enrolledInMess || student.memberType === 'MESS_ONLY') {
        if (messLedger.isOverdue) {
          messOverdue.push(enriched);
        } else if (messLedger.messBalanceDue > 0) {
          messPendingDues.push(enriched);
        }

        if (!messLedger.isOverdue && messLedger.isUpcoming && messLedger.messBalanceDue <= 0) {
          messExpiringSoon.push(enriched);
        }
      }

      if (student.memberType === 'HOSTEL_RESIDENT') {
        if (rentDynamicStatus === 'EXPIRING_SOON') rentExpiringSoon.push(enriched);
        if (rentDynamicStatus === 'EXPIRED') rentOverdue.push(enriched);
      }
    });

    messPendingDues.sort((a, b) => {
      if (a.messDaysRemaining !== b.messDaysRemaining) {
        return a.messDaysRemaining - b.messDaysRemaining;
      }
      return b.messBalanceDue - a.messBalanceDue;
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

    // Total Mess Pending Dues (including overdues)
    const totalCurrentMessDuesAmount = messPendingDues.reduce((acc, s) => acc + (s.messBalanceDue || 0), 0);
    const totalOverdueMessDuesAmount = messOverdue.reduce((acc, s) => acc + (s.messBalanceDue || 0), 0);
    const totalPendingMessDuesAmount = totalCurrentMessDuesAmount + totalOverdueMessDuesAmount;
    const totalPendingMessStudentsCount = messPendingDues.length + messOverdue.length;

    res.json({
      success: true,
      data: {
        students: {
          total: students.length,
          messPendingDuesCount: messPendingDues.length,
          messExpiringSoonCount: messExpiringSoon.length,
          messOverdueCount: messOverdue.length,
          totalPendingMessDuesCount: totalPendingMessStudentsCount,
          totalPendingMessDuesAmount,
          totalCurrentMessDuesAmount,
          totalOverdueMessDuesAmount,
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
          isProfitable: netProfitBalance >= 0,
          totalPendingMessDuesAmount,
          totalCurrentMessDuesAmount,
          totalOverdueMessDuesAmount,
          totalPendingMessStudentsCount
        },
        leaves: {
          currentlyOutCount
        },
        alerts: {
          messPendingDues,
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
    const org = (db.getCollection('organizations') || []).find(o => o.id === orgId) || {};
    const students = db.getCollectionForOrg('students', orgId).filter(s => s.status !== 'ARCHIVED');

    const messPendingDues = [];
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

      // 🍽️ Accurate Mess Ledger Calculation
      const messLedger = calculateMessLedger(student, studentPayments);

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
        messStartDate: student.messStartDate,
        messExpiryDate: messLedger.messExpiryDate,
        totalRentAgreed,
        totalRentPaid,
        rentBalanceDue,
        totalMessPaid: messLedger.totalMessPaid,
        totalMessBilled: messLedger.totalMessBilled || (messLedger.totalMessPaid + messLedger.messBalanceDue),
        messBalanceDue: messLedger.messBalanceDue,

        mealsPerDay: student.mealsPerDay || 3,
        mealPlanType: student.mealPlanType || (student.mealsPerDay === 1 ? '1 Meal / Day' : (student.mealsPerDay === 2 ? '2 Meals / Day' : '3 Meals / Day (Full)')),
        mealSlots: student.mealSlots || ['Morning', 'Noon', 'Evening'],
        planValidityType: student.planValidityType || 'MONTHLY',
        planValidityDays: student.planValidityDays,

        messDynamicStatus: messLedger.messDynamicStatus,
        messStatusLabel: messLedger.messStatusLabel,
        messDaysRemaining: messLedger.messDaysRemaining,
        isOverdueMess: messLedger.isOverdue,
        isUpcomingMess: messLedger.isUpcoming,

        rentDynamicStatus,
        rentStatusLabel,
        rentDaysRemaining: rentBalanceDue > 0 ? -1 : 999,

        whatsappReminder: generateWhatsAppReminder({
          ...student,
          messStartDate: student.messStartDate,
          messExpiryDate: messLedger.messExpiryDate,
          messBalanceDue: messLedger.messBalanceDue,
          totalRentAgreed,
          totalRentPaid,
          rentBalanceDue
        }, 'BOTH', org),
        messWhatsAppReminder: generateWhatsAppReminder({
          ...student,
          messStartDate: student.messStartDate,
          messExpiryDate: messLedger.messExpiryDate,
          messBalanceDue: messLedger.messBalanceDue,
          totalRentAgreed,
          totalRentPaid,
          rentBalanceDue
        }, 'MESS', org),
        rentWhatsAppReminder: generateWhatsAppReminder({
          ...student,
          messStartDate: student.messStartDate,
          messExpiryDate: messLedger.messExpiryDate,
          messBalanceDue: messLedger.messBalanceDue,
          totalRentAgreed,
          totalRentPaid,
          rentBalanceDue
        }, 'RENT', org)
      };

      if (student.enrolledInMess || student.memberType === 'MESS_ONLY') {
        if (messLedger.isOverdue) {
          messOverdue.push(enriched);
        } else if (messLedger.messBalanceDue > 0) {
          messPendingDues.push(enriched);
        }

        if (!messLedger.isOverdue && messLedger.isUpcoming && messLedger.messBalanceDue <= 0) {
          messExpiringSoon.push(enriched);
        }
      }

      if (student.memberType === 'HOSTEL_RESIDENT') {
        if (rentDynamicStatus === 'EXPIRING_SOON') rentExpiringSoon.push(enriched);
        if (rentDynamicStatus === 'EXPIRED') rentOverdue.push(enriched);
      }

      const isMessClear = (!student.enrolledInMess && student.memberType !== 'MESS_ONLY') || (messLedger.messDynamicStatus === 'ACTIVE' && messLedger.messBalanceDue <= 0);
      const isRentClear = student.memberType !== 'HOSTEL_RESIDENT' || rentDynamicStatus === 'ACTIVE';

      if (isMessClear && isRentClear) {
        active.push(enriched);
      }
    });

    messPendingDues.sort((a, b) => {
      if (a.messDaysRemaining !== b.messDaysRemaining) {
        return a.messDaysRemaining - b.messDaysRemaining;
      }
      return b.messBalanceDue - a.messBalanceDue;
    });
    messExpiringSoon.sort((a, b) => a.messDaysRemaining - b.messDaysRemaining);
    messOverdue.sort((a, b) => a.messDaysRemaining - b.messDaysRemaining);
    rentExpiringSoon.sort((a, b) => a.rentDaysRemaining - b.rentDaysRemaining);
    rentOverdue.sort((a, b) => a.rentDaysRemaining - b.rentDaysRemaining);

    const totalCurrentMessDuesAmount = messPendingDues.reduce((acc, s) => acc + (s.messBalanceDue || 0), 0);
    const totalOverdueMessDuesAmount = messOverdue.reduce((acc, s) => acc + (s.messBalanceDue || 0), 0);
    const totalPendingMessDuesAmount = totalCurrentMessDuesAmount + totalOverdueMessDuesAmount;
    const totalPendingMessStudentsCount = messPendingDues.length + messOverdue.length;

    res.json({
      success: true,
      messPendingDues,
      messExpiringSoon,
      messOverdue,
      rentExpiringSoon,
      rentOverdue,
      active,
      totalPendingMessDuesAmount,
      totalCurrentMessDuesAmount,
      totalOverdueMessDuesAmount,
      totalPendingMessStudentsCount
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

