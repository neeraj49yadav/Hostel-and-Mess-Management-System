const db = require('../config/db');
const { v4: uuidv4 } = require('uuid');

/**
 * Log any administrative or system action into the Admin Audit Trail.
 * Automatically attributes the action to the authenticated admin (JWT) or provided admin name.
 */
exports.logAudit = ({ req, action, details, adminName, adminId, metadata }) => {
  try {
    const auditLogs = db.getCollection('audit_logs');

    // Extract admin name, role, and id from JWT decoded token or fallback to request body
    const performingAdminName =
      adminName ||
      (req && req.admin && req.admin.name) ||
      (req && req.body && (req.body.adminName || req.body.recordedByAdminName || req.body.collectedByAdminName)) ||
      'Admin In-Charge';

    const performingAdminId =
      adminId ||
      (req && req.admin && req.admin.id) ||
      (req && req.body && (req.body.adminId || req.body.recordedByAdminId || req.body.collectedByAdminId)) ||
      'admin-1';

    const performingAdminRole =
      (req && req.admin && req.admin.role) ||
      'Admin';

    const targetOrgId =
      (req && req.admin && req.admin.orgId) ||
      (req && req.headers && req.headers['x-org-id']) ||
      (req && req.body && req.body.orgId) ||
      (metadata && metadata.orgId) ||
      'org-default';

    const entry = {
      id: `audit-${uuidv4().substring(0, 8)}`,
      orgId: targetOrgId,
      action: action.toUpperCase(),
      details: details || '',
      adminName: performingAdminName,
      adminId: performingAdminId,
      adminRole: performingAdminRole,
      timestamp: new Date().toISOString(),
      metadata: metadata || null
    };

    auditLogs.push(entry);

    // 🛡️ Cap audit logs to latest 2,000 entries to prevent 500MB DB bloat on Supabase Free Tier
    const trimmedLogs = auditLogs.length > 2000 ? auditLogs.slice(-2000) : auditLogs;
    db.saveCollection('audit_logs', trimmedLogs);
    return entry;
  } catch (err) {
    console.error('Failed to record audit log:', err);
  }
};
