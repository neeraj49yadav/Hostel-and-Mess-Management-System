/**
 * Expiry & Dues Service
 * Handles independent cycles for:
 * 1. Mess Subscription:
 *    - Regular Monthly Renewal (warnings 1-5 days before expiry)
 *    - Custom Validity / Manual Days (e.g. 5, 10, 15 days)
 *    - Plan Change Rollover (accurate cycle-based billing without wiping previous history)
 *    - False Overdue Elimination (students who paid all dues never show overdue)
 *    - 60-Day Auto-Removal (auto-removes members overdue > 60 days without continuous payment)
 * 2. Hostel Room Rent:
 *    - Total Agreed Rent balance tracking (installments anytime)
 */

/**
 * Calculate dynamic cycle status and days remaining
 */
function calculateCycleStatus(expiryDateStr, thresholdDays = 5) {
  if (!expiryDateStr) {
    return { status: 'EXPIRED', daysDiff: -999, label: 'Not Set / Due' };
  }

  const today = new Date();
  today.setHours(0, 0, 0, 0);

  const expiry = new Date(expiryDateStr);
  expiry.setHours(0, 0, 0, 0);

  const diffTime = expiry.getTime() - today.getTime();
  const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));

  if (diffDays < 0) {
    return { status: 'EXPIRED', daysDiff: diffDays, label: `${Math.abs(diffDays)}d overdue` };
  } else if (diffDays <= thresholdDays) {
    return {
      status: 'EXPIRING_SOON',
      daysDiff: diffDays,
      label: diffDays === 0 ? 'Expires today' : `Due in ${diffDays} day${diffDays > 1 ? 's' : ''}`
    };
  } else {
    return { status: 'ACTIVE', daysDiff: diffDays, label: `${diffDays} days remaining` };
  }
}

/**
 * Calculate billing cycles and current cycle boundaries from messStartDate and cycleDay
 */
function getMessCycleBoundaries(messStartDateStr, cycleDay, asOfDate = new Date()) {
  const today = new Date(asOfDate);
  today.setHours(0, 0, 0, 0);

  const start = new Date(messStartDateStr || today);
  start.setHours(0, 0, 0, 0);

  // If start is in the future, 1st cycle is [start, start + 1 month]
  if (today < start) {
    const end = new Date(start);
    end.setMonth(end.getMonth() + 1);
    return {
      cycleCount: 1,
      currentCycleStart: start.toISOString().split('T')[0],
      currentCycleEnd: end.toISOString().split('T')[0]
    };
  }

  // Iterate month by month from start to find current cycle
  let cycleCount = 1;
  let curStart = new Date(start);
  let nextCycle = new Date(start);
  nextCycle.setMonth(nextCycle.getMonth() + 1);

  while (nextCycle <= today) {
    cycleCount++;
    curStart = new Date(nextCycle);
    nextCycle.setMonth(nextCycle.getMonth() + 1);
  }

  return {
    cycleCount,
    currentCycleStart: curStart.toISOString().split('T')[0],
    currentCycleEnd: nextCycle.toISOString().split('T')[0]
  };
}

/**
 * Comprehensive Mess Ledger Calculation
 * Supports:
 * - Regular Monthly plans
 * - Custom Validity (Manual Days)
 * - Historical Plan Changes (Rollover)
 * - False Overdue Fix
 * - 60-Day Overdue Detection
 */
function calculateMessLedger(student, studentPayments = [], asOfDate = new Date()) {
  if (!student.enrolledInMess && student.memberType !== 'MESS_ONLY') {
    return {
      enrolledInMess: false,
      monthlyMessFee: 0,
      totalMessPaid: 0,
      messBalanceDue: 0,
      messExpiryDate: student.messExpiryDate || '',
      messDynamicStatus: 'ACTIVE',
      messStatusLabel: 'Not Enrolled',
      messDaysRemaining: 999,
      isOverdue: false,
      isUpcoming: false,
      isEligibleForAutoRemove: false
    };
  }

  const messPayments = studentPayments
    .filter(p => p.feeType === 'MESS' || (p.feeType === 'BOTH' && p.messAmount > 0))
    .sort((a, b) => new Date(a.paymentDate || a.createdAt) - new Date(b.paymentDate || b.createdAt));

  const totalMessPaid = messPayments
    .reduce((sum, p) => sum + (parseFloat(p.messAmount) || (p.feeType === 'MESS' ? parseFloat(p.amount) : 0)), 0);

  const currentFee = parseFloat(student.monthlyMessFee) || 3500;
  const isCustomValidity = student.planValidityType === 'CUSTOM_DAYS';

  // 1. CASE: MANUAL / CUSTOM PLAN VALIDITY (e.g. 5 days, 10 days, 15 days)
  if (isCustomValidity) {
    const messStartDate = student.messStartDate || student.admissionDate || new Date().toISOString().split('T')[0];
    let expiryDateStr = student.messExpiryDate;

    if (!expiryDateStr && student.planValidityDays) {
      const expDate = new Date(messStartDate);
      expDate.setDate(expDate.getDate() + parseInt(student.planValidityDays));
      expiryDateStr = expDate.toISOString().split('T')[0];
    } else if (!expiryDateStr) {
      const expDate = new Date(messStartDate);
      expDate.setDate(expDate.getDate() + 30);
      expiryDateStr = expDate.toISOString().split('T')[0];
    }

    const planAmount = currentFee;
    const balanceDue = Math.max(0, planAmount - totalMessPaid);
    const cycleStatus = calculateCycleStatus(expiryDateStr, 5);

    let dynamicStatus = 'ACTIVE';
    let statusLabel = '';

    if (balanceDue <= 0) {
      if (cycleStatus.daysDiff < 0) {
        dynamicStatus = 'EXPIRING_SOON';
        statusLabel = 'Plan Completed (Renewal Due)';
      } else {
        dynamicStatus = 'ACTIVE';
        statusLabel = `Paid (Valid till ${formatShortDate(expiryDateStr)})`;
      }
    } else {
      if (cycleStatus.daysDiff < 0) {
        dynamicStatus = 'EXPIRED';
        statusLabel = `₹${balanceDue.toFixed(0)} Due (Overdue)`;
      } else {
        dynamicStatus = 'EXPIRING_SOON';
        statusLabel = `₹${balanceDue.toFixed(0)} Due (${cycleStatus.daysDiff}d left)`;
      }
    }

    const isOverdue = dynamicStatus === 'EXPIRED' && balanceDue > 0;
    const isUpcoming = (dynamicStatus === 'EXPIRING_SOON' && cycleStatus.daysDiff >= 0) || (balanceDue <= 0 && cycleStatus.daysDiff >= 0 && cycleStatus.daysDiff <= 5);
    const isEligibleForAutoRemove = isOverdue && cycleStatus.daysDiff < -60;

    return {
      enrolledInMess: true,
      monthlyMessFee: currentFee,
      totalMessPaid,
      messBalanceDue: balanceDue,
      messExpiryDate: expiryDateStr,
      messDynamicStatus: dynamicStatus,
      messStatusLabel: statusLabel,
      messDaysRemaining: cycleStatus.daysDiff,
      isOverdue,
      isUpcoming,
      isEligibleForAutoRemove
    };
  }

  // 2. CASE: REGULAR MONTHLY SUBSCRIPTION (With Plan Change Rollover Support)
  const messStartDate = student.messStartDate || student.admissionDate || student.createdAt || new Date().toISOString().split('T')[0];
  const cycleInfo = getMessCycleBoundaries(messStartDate, student.cycleDay || 1, asOfDate);

  // Calculate Total Mess Billed taking into account plan change history
  // If plan changed (e.g. student.messPlanHistory), each cycle used the fee in effect at that time.
  let totalMessBilled = 0;
  const history = student.messPlanHistory || [];

  if (history.length > 0) {
    // Multi-plan calculation
    let cycleStart = new Date(messStartDate);
    for (let c = 0; c < cycleInfo.cycleCount; c++) {
      const cycleEnd = new Date(cycleStart);
      cycleEnd.setMonth(cycleEnd.getMonth() + 1);

      // Find plan active for this cycle
      let cycleFee = currentFee;
      for (const h of history) {
        if (h.fee && h.changedAt && cycleStart < new Date(h.changedAt)) {
          cycleFee = parseFloat(h.fee) || currentFee;
          break;
        }
      }

      totalMessBilled += cycleFee;
      cycleStart = cycleEnd;
    }
  } else {
    // If no history array yet, check if previousMessFee is stored
    if (student.previousMessFee && student.planChangedAt) {
      const changedDate = new Date(student.planChangedAt);
      let cycleStart = new Date(messStartDate);
      for (let c = 0; c < cycleInfo.cycleCount; c++) {
        const cycleEnd = new Date(cycleStart);
        cycleEnd.setMonth(cycleEnd.getMonth() + 1);
        if (cycleStart < changedDate) {
          totalMessBilled += parseFloat(student.previousMessFee) || currentFee;
        } else {
          totalMessBilled += currentFee;
        }
        cycleStart = cycleEnd;
      }
    } else {
      // Single plan default: N cycles * current fee
      totalMessBilled = cycleInfo.cycleCount * currentFee;
    }
  }

  // Determine Balance Due: Billed - Paid
  const messBalanceDue = Math.max(0, totalMessBilled - totalMessPaid);

  // Compute Expiry Date deterministically from payments & cycle
  let messExpiryDate = student.messExpiryDate;
  if (!messExpiryDate || messExpiryDate.trim() === '') {
    messExpiryDate = cycleInfo.currentCycleEnd;
  }

  // If student has paid for future cycles, extend expiry date accordingly
  if (totalMessPaid > totalMessBilled) {
    const extraPaid = totalMessPaid - totalMessBilled;
    const extraMonths = Math.floor(extraPaid / currentFee);
    if (extraMonths > 0) {
      const advancedExp = new Date(cycleInfo.currentCycleEnd);
      advancedExp.setMonth(advancedExp.getMonth() + extraMonths);
      messExpiryDate = advancedExp.toISOString().split('T')[0];
    }
  } else if (messBalanceDue === 0 && messExpiryDate < cycleInfo.currentCycleEnd) {
    // Fully paid up to current cycle end
    messExpiryDate = cycleInfo.currentCycleEnd;
  }

  const cycleStatus = calculateCycleStatus(messExpiryDate, 5);

  // Dynamic Status & Label Resolution
  let dynamicStatus = 'ACTIVE';
  let statusLabel = '';

  if (messBalanceDue <= 0) {
    // 🛡️ FIX FOR REQUIREMENT 5: If student paid all dues (0 balance), NEVER SHOW OVERDUE!
    if (cycleStatus.daysDiff < 0) {
      // Cycle date reached with 0 due -> Waiting for next monthly cycle
      dynamicStatus = 'EXPIRING_SOON';
      statusLabel = `Fully Paid (Cycle Renewal Due)`;
    } else if (cycleStatus.daysDiff <= 5) {
      dynamicStatus = 'EXPIRING_SOON';
      statusLabel = `Paid (${cycleStatus.daysDiff === 0 ? 'Renews today' : 'Renews in ' + cycleStatus.daysDiff + 'd'})`;
    } else {
      dynamicStatus = 'ACTIVE';
      statusLabel = `Paid (Valid till ${formatShortDate(messExpiryDate)})`;
    }
  } else {
    // Student owes money (messBalanceDue > 0)
    // 🛡️ FIX FOR REQUIREMENT 8: Shows exact pending due (e.g. ₹500 Due)
    if (cycleStatus.daysDiff < 0) {
      dynamicStatus = 'EXPIRED';
      statusLabel = `₹${messBalanceDue.toFixed(0)} Due (${Math.abs(cycleStatus.daysDiff)}d Overdue)`;
    } else {
      dynamicStatus = 'EXPIRING_SOON';
      statusLabel = `₹${messBalanceDue.toFixed(0)} Due (Due in ${cycleStatus.daysDiff}d)`;
    }
  }

  const isOverdue = dynamicStatus === 'EXPIRED' && messBalanceDue > 0;
  const isUpcoming = (dynamicStatus === 'EXPIRING_SOON' && cycleStatus.daysDiff >= 0) || (messBalanceDue <= 0 && cycleStatus.daysDiff >= 0 && cycleStatus.daysDiff <= 5);

  // 🛡️ REQUIREMENT 4: Auto-remove check (Overdue > 60 days without continuous payment)
  const isEligibleForAutoRemove = isOverdue && cycleStatus.daysDiff < -60;

  return {
    enrolledInMess: true,
    monthlyMessFee: currentFee,
    totalMessPaid,
    totalMessBilled,
    messBalanceDue,
    messExpiryDate,
    messDynamicStatus: dynamicStatus,
    messStatusLabel: statusLabel,
    messDaysRemaining: cycleStatus.daysDiff,
    currentCycleStart: cycleInfo.currentCycleStart,
    currentCycleEnd: cycleInfo.currentCycleEnd,
    isOverdue,
    isUpcoming,
    isEligibleForAutoRemove
  };
}

function formatShortDate(dateStr) {
  if (!dateStr) return '';
  try {
    const d = new Date(dateStr);
    return d.toLocaleDateString('en-IN', { day: 'numeric', month: 'short' });
  } catch (_) {
    return dateStr;
  }
}

/**
 * Calculate the number of mess billing cycles that have started from messStartDate up to asOfDate.
 */
function calculateElapsedMessCycles(messStartDateStr, asOfDate = new Date()) {
  if (!messStartDateStr) return 1;
  const start = new Date(messStartDateStr);
  start.setHours(0, 0, 0, 0);
  const now = new Date(asOfDate);
  now.setHours(0, 0, 0, 0);

  if (now <= start) return 1;

  let cycles = 1;
  const check = new Date(start);
  while (true) {
    check.setMonth(check.getMonth() + 1);
    if (check <= now) {
      cycles++;
    } else {
      break;
    }
  }
  return cycles;
}

/**
 * Calculate mess expiry date deterministically
 */
function calculateMessExpiryDate(messStartDateStr, totalMessPaid, monthlyMessFee) {
  const baseStartStr = messStartDateStr || new Date().toISOString().split('T')[0];
  const fee = parseFloat(monthlyMessFee) || 3500;
  const paid = parseFloat(totalMessPaid) || 0;
  const monthsPaid = Math.floor(paid / fee);
  const validityMonths = Math.max(1, monthsPaid);

  const exp = new Date(baseStartStr);
  exp.setMonth(exp.getMonth() + validityMonths);
  return exp.toISOString().split('T')[0];
}

/**
 * Generate a pre-formatted WhatsApp payment reminder text
 */
function generateWhatsAppReminder(student, feeType = 'BOTH', hostelName = 'My Hostel & Mess') {
  const {
    name,
    roomNumber,
    totalRentAgreed = 0,
    totalRentPaid = 0,
    rentBalanceDue = 0,
    monthlyMessFee = 3500,
    messExpiryDate,
    messBalanceDue = 0,
    parentPhone,
    phone,
    enrolledInMess,
    memberType
  } = student;

  const isResident = memberType === 'HOSTEL_RESIDENT';
  const messStatus = calculateCycleStatus(messExpiryDate, 5);

  const greetingIdentifier = isResident && roomNumber ? `Room No: ${roomNumber}` : 'Day Scholar';

  let message = `🔔 *Payment Reminder - ${hostelName}*\n\n` +
    `Dear ${name} (${greetingIdentifier}),\n` +
    `We are notifying you regarding your pending ${isResident ? 'Hostel / Mess' : 'Mess subscription'} dues.\n\n` +
    `📋 *Current Status:*\n`;

  if (isResident) {
    message += `• *Hostel Rent*: Total: ₹${totalRentAgreed} | Paid: ₹${totalRentPaid} | *Remaining Due: ₹${rentBalanceDue.toFixed(0)}*\n`;
  }

  if (enrolledInMess !== false) {
    const messDueText = messBalanceDue > 0 ? `• *Pending Mess Due: ₹${messBalanceDue.toFixed(0)}*` : '• *Mess Status: Fully Paid*';
    message += `• *Mess Plan (Monthly)*: ₹${monthlyMessFee}/mo (Valid till: ${messExpiryDate || 'Due'} • ${messStatus.label})\n${messDueText}\n`;
  }

  message += `\n`;

  if (isResident && rentBalanceDue > 0) {
    message += `👉 *Pending Rent Balance*: ₹${rentBalanceDue.toFixed(0)}\n`;
  }
  if (enrolledInMess !== false && messBalanceDue > 0) {
    message += `👉 *Pending Monthly Mess Fee*: ₹${messBalanceDue.toFixed(0)}\n`;
  } else if (enrolledInMess !== false && messStatus.status !== 'ACTIVE') {
    message += `👉 *Pending Monthly Mess Renewal*: ₹${monthlyMessFee}\n`;
  }

  message += `\nKindly pay at the admin office or via UPI to keep your records clear.\n\n` +
    `Thank you,\n*Hostel & Mess Management*`;

  // Encode for WhatsApp URI
  const encodedText = encodeURIComponent(message);
  let targetPhone = phone || parentPhone || '';
  targetPhone = targetPhone.replace(/[^0-9]/g, '');
  if (targetPhone.startsWith('0')) targetPhone = targetPhone.replace(/^0+/, '');
  const formattedPhone = targetPhone.startsWith('91') ? targetPhone : `91${targetPhone}`;
  const whatsappUrl = `https://wa.me/${formattedPhone}?text=${encodedText}`;

  return {
    message,
    whatsappUrl,
    targetPhone: formattedPhone,
    messStatus
  };
}

/**
 * Generate a pre-formatted WhatsApp payment confirmation receipt
 */
function generateWhatsAppReceipt(payment, student, hostelName = 'City Pride Hostel & Mess') {
  let message = `✅ *Payment Receipt - ${hostelName}*\n\n` +
    `Receipt No: *${payment.receiptNo}*\n` +
    `Date: ${new Date(payment.paymentDate).toLocaleDateString('en-IN')}\n\n` +
    `👤 Student: ${student.name} (Room: ${student.roomNumber})\n` +
    `💵 Amount Paid: *₹${payment.amount}* via ${payment.paymentMode}\n` +
    `📌 Fee Type: ${payment.feeType}\n`;

  if (payment.targetMonth) {
    message += `🗓️ For Month: *${payment.targetMonth}*\n`;
  }

  if (payment.rentAmount > 0) {
    const remaining = payment.remainingRentBalanceAfterPayment !== undefined
      ? payment.remainingRentBalanceAfterPayment
      : (student.rentBalanceDue !== undefined ? student.rentBalanceDue : 0);
    message += `🏨 Hostel Rent Paid: ₹${payment.rentAmount} (Remaining Due: ₹${remaining.toFixed(0)})\n`;
  }

  if (payment.messAmount > 0) {
    message += `🍽️ Mess Subscription Paid: ₹${payment.messAmount} (Valid till: ${student.messExpiryDate || 'Next month'})\n`;
  }

  message += `🗓️ Details: *${payment.cycleEndDate}*\n` +
    `✍️ Received By: ${payment.collectedByAdminName}\n\n` +
    `Thank you for your prompt payment!`;

  const encodedText = encodeURIComponent(message);
  const targetPhone = student.phone || student.parentPhone || '';
  const formattedPhone = targetPhone.startsWith('91') ? targetPhone : `91${targetPhone.replace(/[^0-9]/g, '')}`;
  const whatsappUrl = `https://wa.me/${formattedPhone}?text=${encodedText}`;

  return {
    message,
    whatsappUrl
  };
}

module.exports = {
  calculateCycleStatus,
  calculateElapsedMessCycles,
  calculateMessExpiryDate,
  calculateMessLedger,
  getMessCycleBoundaries,
  generateWhatsAppReminder,
  generateWhatsAppReceipt
};

