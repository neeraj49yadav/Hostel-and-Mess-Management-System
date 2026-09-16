/**
 * Expiry & Dues Service
 * Handles independent cycles for:
 * 1. Mess Subscription: Fixed Monthly Renewal (warnings 1-5 days before expiry)
 * 2. Hostel Room Rent: 2-3 times a year (Semester 6-months / Term 4-months, warnings 15 days before expiry)
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
 * Calculate the number of mess billing cycles that have started from messStartDate up to asOfDate.
 * Month 1 is billed immediately on messStartDate.
 * Once 1 month elapses, Month 2 is billed, and so on.
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
 * Calculate mess expiry date deterministically from messStartDate and totalMessPaid.
 * Rule:
 * 1. Upon enrollment, student gets 1-month plan validity even if they pay or not (max(1, monthsPaid)).
 * 2. Paying the 1st month due fee clears the 1st month balance but does NOT upgrade validity (validity stays messStartDate + 1 month).
 * 3. Paying subsequent months extends validity (messStartDate + monthsPaid).
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
  generateWhatsAppReminder,
  generateWhatsAppReceipt
};
