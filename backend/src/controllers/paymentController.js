const db = require('../config/db');
const { v4: uuidv4 } = require('uuid');
const { generateWhatsAppReceipt, calculateMessExpiryDate } = require('../services/expiryService');
const { logAudit } = require('../services/auditService');
const { extractOrgId } = require('../middleware/authMiddleware');

// Get all payments
exports.getPayments = (req, res) => {
  try {
    const orgId = extractOrgId(req);
    const { studentId, feeType, month } = req.query;
    let payments = db.getCollectionForOrg('payments', orgId);

    if (studentId) payments = payments.filter(p => p.studentId === studentId);
    if (feeType) payments = payments.filter(p => p.feeType === feeType.toUpperCase());
    if (month) payments = payments.filter(p => p.paymentDate && p.paymentDate.startsWith(month));

    payments.sort((a, b) => new Date(b.paymentDate) - new Date(a.paymentDate));
    const totalCollected = payments.reduce((acc, p) => acc + (p.amount || 0), 0);

    res.json({
      success: true,
      count: payments.length,
      totalCollected,
      data: payments
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// Record fee payment
exports.recordPayment = (req, res) => {
  try {
    const orgId = extractOrgId(req);
    const {
      studentId,
      amount,
      feeType, // 'RENT', 'MESS', 'BOTH'
      rentAmount = 0,
      messAmount = 0,
      paymentMode, // 'CASH', 'UPI', 'BANK_TRANSFER'
      transactionRef,
      adminId,
      adminName,
      targetMonth, // e.g. "September 2026"
      messMonthsToAdd = 1,
      rentMonthsToAdd = 6, // 6 months for semester, 4 for termly
      notes
    } = req.body;

    if (!studentId || !amount) {
      return res.status(400).json({ success: false, message: 'Student and amount are required' });
    }

    const students = db.getCollectionForOrg('students', orgId);
    const student = students.find(s => s.id === studentId);
    if (!student) {
      return res.status(404).json({ success: false, message: 'Student not found' });
    }

    const payments = db.getCollectionForOrg('payments', orgId);
    const receiptCount = payments.length + 1;
    const receiptNo = `REC-${new Date().getFullYear()}-${String(receiptCount).padStart(4, '0')}`;
    const paymentDate = new Date().toISOString();
    const cycleSummary = [];

    // 1. Calculate Rent and Mess Split
    const totalPaid = parseFloat(amount);
    let finalRentAmount = 0;
    let finalMessAmount = 0;

    if (feeType === 'MESS') {
      finalMessAmount = totalPaid;
      finalRentAmount = 0;
    } else if (feeType === 'RENT') {
      finalRentAmount = totalPaid;
      finalMessAmount = 0;
    } else {
      // feeType === 'BOTH'
      const parsedRent = parseFloat(rentAmount) || 0;
      const parsedMess = parseFloat(messAmount) || 0;
      if (parsedRent > 0 && parsedMess > 0) {
        finalRentAmount = parsedRent;
        finalMessAmount = parsedMess;
      } else if (parsedRent > 0) {
        finalRentAmount = parsedRent;
        finalMessAmount = Math.max(0, totalPaid - parsedRent);
      } else if (parsedMess > 0) {
        finalMessAmount = parsedMess;
        finalRentAmount = Math.max(0, totalPaid - parsedMess);
      } else {
        finalMessAmount = student.monthlyMessFee ? Math.min(totalPaid, student.monthlyMessFee) : 3500;
        finalRentAmount = Math.max(0, totalPaid - finalMessAmount);
      }
    }

    // 2. Advance Mess Expiry deterministically
    if (finalMessAmount > 0 || feeType === 'MESS') {
      const previousMessPayments = payments
        .filter(p => p.studentId === studentId && (p.feeType === 'MESS' || (p.feeType === 'BOTH' && p.messAmount > 0)))
        .reduce((sum, p) => sum + (parseFloat(p.messAmount) || (p.feeType === 'MESS' ? parseFloat(p.amount) : 0)), 0);

      const updatedTotalMessPaid = previousMessPayments + finalMessAmount;
      const messStartDate = student.messStartDate || student.admissionDate || student.createdAt || new Date().toISOString().split('T')[0];
      student.messExpiryDate = calculateMessExpiryDate(messStartDate, updatedTotalMessPaid, student.monthlyMessFee || 3500);

      const monthLabel = targetMonth ? ` for ${targetMonth}` : '';
      cycleSummary.push(`Mess: ₹${finalMessAmount} paid${monthLabel} (Valid till ${student.messExpiryDate})`);
    }

    // 3. Update Rent Ledger & Overpayment Guard
    const totalRentAgreed = parseFloat(student.totalRentAgreed !== undefined ? student.totalRentAgreed : (student.rentAmountPerTerm || 0));
    const previousRentPayments = payments
      .filter(p => p.studentId === studentId && (p.feeType === 'RENT' || (p.feeType === 'BOTH' && p.rentAmount > 0)))
      .reduce((sum, p) => sum + (parseFloat(p.rentAmount) || (p.feeType === 'RENT' ? parseFloat(p.amount) : 0)), 0);

    const remainingRentBalanceBefore = Math.max(0, totalRentAgreed - previousRentPayments);

    if (finalRentAmount > 0 && totalRentAgreed > 0) {
      if (remainingRentBalanceBefore <= 0) {
        return res.status(400).json({
          success: false,
          message: `Hostel rent for ${student.name} is already fully paid (₹0 due). Overpayment is not allowed.`
        });
      }
      if (finalRentAmount > remainingRentBalanceBefore) {
        return res.status(400).json({
          success: false,
          message: `Hostel rent payment (₹${finalRentAmount}) exceeds remaining balance due of ₹${remainingRentBalanceBefore.toFixed(0)}. Maximum allowed: ₹${remainingRentBalanceBefore.toFixed(0)}.`
        });
      }
    }

    const updatedTotalRentPaid = previousRentPayments + finalRentAmount;
    const remainingRentBalance = Math.max(0, totalRentAgreed - updatedTotalRentPaid);

    if (finalRentAmount > 0 || feeType === 'RENT') {
      if (remainingRentBalance <= 0) {
        cycleSummary.push(`Hostel Rent: Fully Paid (₹${finalRentAmount} received, ₹0 due)`);
      } else {
        cycleSummary.push(`Hostel Rent: ₹${finalRentAmount} paid (Remaining Due: ₹${remainingRentBalance.toFixed(0)})`);
      }
    }

    student.status = 'ACTIVE';
    db.saveCollectionForOrg('students', orgId, students);

    const defaultMonth = new Date().toLocaleDateString('en-US', { month: 'long', year: 'numeric' });
    const chosenTargetMonth = targetMonth || defaultMonth;

    const newPayment = {
      id: `pay-${uuidv4().substring(0, 8)}`,
      orgId,
      receiptNo,
      studentId,
      studentName: student.name,
      roomNumber: student.roomNumber,
      amount: totalPaid,
      feeType: feeType || 'BOTH',
      rentAmount: finalRentAmount,
      messAmount: finalMessAmount,
      targetMonth: chosenTargetMonth,
      paymentMode: paymentMode || 'CASH',
      transactionRef: transactionRef || '',
      paymentDate,
      cycleStartDate: new Date().toISOString().split('T')[0],
      cycleEndDate: cycleSummary.join(' | ') || `Paid ₹${totalPaid}`,
      totalRentAgreed,
      totalRentPaidAfterPayment: updatedTotalRentPaid,
      remainingRentBalanceAfterPayment: remainingRentBalance,
      collectedByAdminId: adminId || (req.admin && req.admin.id) || 'admin-1',
      collectedByAdminName: adminName || (req.admin && req.admin.name) || 'Admin',
      notes: notes || ''
    };

    payments.push(newPayment);
    db.saveCollectionForOrg('payments', orgId, payments);

    // 🛡️ Comprehensive Audit Trail for Fee Payment Collection
    logAudit({
      req,
      action: 'RECORD_PAYMENT',
      details: `Collected ₹${newPayment.amount} (${newPayment.feeType}) for ${newPayment.targetMonth} from ${student.name} (Room ${student.roomNumber}) via ${newPayment.paymentMode}. Receipt: ${newPayment.receiptNo}. Details: ${cycleSummary.join(', ')}`,
      adminName: newPayment.collectedByAdminName,
      adminId: newPayment.collectedByAdminId
    });

    const whatsappReceipt = generateWhatsAppReceipt(newPayment, {
      ...student,
      totalRentAgreed,
      totalRentPaid: updatedTotalRentPaid,
      rentBalanceDue: remainingRentBalance
    });

    res.status(201).json({
      success: true,
      message: 'Payment recorded successfully',
      data: newPayment,
      whatsappReceipt
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// Delete / Reverse Payment Record
exports.deletePayment = (req, res) => {
  try {
    const orgId = extractOrgId(req);
    const { id } = req.params;
    const { reason, adminName, adminId } = req.body || {};

    const payments = db.getCollectionForOrg('payments', orgId);
    const paymentIndex = payments.findIndex(p => p.id === id);
    if (paymentIndex === -1) {
      return res.status(404).json({ success: false, message: 'Payment record not found' });
    }

    const deletedPayment = payments[paymentIndex];
    payments.splice(paymentIndex, 1);
    db.saveCollectionForOrg('payments', orgId, payments);

    // If student exists and payment had mess fees, recalculate messExpiryDate
    const students = db.getCollectionForOrg('students', orgId);
    const student = students.find(s => s.id === deletedPayment.studentId);
    if (student && student.enrolledInMess && (deletedPayment.messAmount > 0 || deletedPayment.feeType === 'MESS' || deletedPayment.feeType === 'BOTH')) {
      const remainingMessPayments = payments
        .filter(p => p.studentId === student.id && (p.feeType === 'MESS' || (p.feeType === 'BOTH' && p.messAmount > 0)))
        .reduce((sum, p) => sum + (parseFloat(p.messAmount) || (p.feeType === 'MESS' ? parseFloat(p.amount) : 0)), 0);

      const messStartDate = student.messStartDate || student.admissionDate || student.createdAt || new Date().toISOString().split('T')[0];
      student.messExpiryDate = calculateMessExpiryDate(messStartDate, remainingMessPayments, student.monthlyMessFee || 3500);
      db.saveCollectionForOrg('students', orgId, students);
    }

    // 🛡️ Permanent Immutable Audit Log (Audit records are strictly non-deletable)
    logAudit({
      req,
      action: 'PAYMENT_DELETED',
      details: `Reversed/Deleted payment receipt ${deletedPayment.receiptNo} of ₹${deletedPayment.amount} (${deletedPayment.feeType}) for student ${deletedPayment.studentName} (Room ${deletedPayment.roomNumber}). Payment Mode: ${deletedPayment.paymentMode}, Date: ${deletedPayment.paymentDate}. Reason: ${reason || 'Administrative correction'}`,
      adminName: adminName || (req.admin && req.admin.name) || 'Admin',
      adminId: adminId || (req.admin && req.admin.id) || 'admin-1',
      metadata: {
        deletedPaymentId: deletedPayment.id,
        receiptNo: deletedPayment.receiptNo,
        amount: deletedPayment.amount,
        studentId: deletedPayment.studentId,
        studentName: deletedPayment.studentName,
        feeType: deletedPayment.feeType,
        reason: reason || 'Administrative correction'
      }
    });

    res.json({
      success: true,
      message: `Payment receipt ${deletedPayment.receiptNo} reversed and deleted successfully`,
      data: deletedPayment
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

