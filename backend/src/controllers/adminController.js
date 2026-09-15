const db = require('../config/db');
const { v4: uuidv4 } = require('uuid');
const { generateToken, extractOrgId } = require('../middleware/authMiddleware');
const { logAudit } = require('../services/auditService');
const storageService = require('../services/storageService');

// Get all active organizations for switcher / discovery
exports.getOrganizations = (req, res) => {
  try {
    const organizations = db.getCollection('organizations') || [];
    res.json({
      success: true,
      count: organizations.length,
      data: organizations
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// Register a New Organization / Hostel + Primary Admin + Starter Default Rooms
exports.registerOrganization = (req, res) => {
  try {
    const {
      orgName,
      orgCode,
      city,
      contactPhone,
      adminName,
      adminPhone,
      adminPin,
      adminRole
    } = req.body;

    if (!orgName || !adminName || !adminPin) {
      return res.status(400).json({
        success: false,
        message: 'Organization Name, Admin Name, and 4-Digit Admin PIN are required'
      });
    }

    if (adminPin.toString().trim().length !== 4) {
      return res.status(400).json({
        success: false,
        message: 'Admin PIN must be exactly 4 digits'
      });
    }

    const organizations = db.getCollection('organizations') || [];
    
    // Generate clean unique Organization Code
    let formattedCode = (orgCode || orgName.replace(/[^A-Za-z0-9]/g, '').substring(0, 8)).toUpperCase();
    if (!formattedCode) formattedCode = `HOSTEL${Math.floor(1000 + Math.random() * 9000)}`;

    // Ensure code is unique
    const codeExists = organizations.some(o => (o.code || '').toUpperCase() === formattedCode);
    if (codeExists) {
      if (orgCode) {
        return res.status(400).json({
          success: false,
          message: `Organization code "${formattedCode}" is already taken. Please pick another code.`
        });
      } else {
        formattedCode = `${formattedCode}${Math.floor(10 + Math.random() * 90)}`;
      }
    }

    const newOrgId = `org-${uuidv4().substring(0, 8)}`;
    const newOrg = {
      id: newOrgId,
      name: orgName.trim(),
      code: formattedCode,
      city: city ? city.trim() : 'Main Campus',
      contactPhone: (contactPhone || adminPhone || '').trim(),
      createdAt: new Date().toISOString()
    };

    organizations.push(newOrg);
    db.saveCollection('organizations', organizations);

    // Create Primary Admin for this Organization
    const admins = db.getCollection('admins') || [];
    const newAdmin = {
      id: `admin-${uuidv4().substring(0, 8)}`,
      orgId: newOrgId,
      name: adminName.trim(),
      role: (adminRole || 'Chief Warden / Owner').trim(),
      phone: (adminPhone || contactPhone || '').trim(),
      pin: adminPin.toString().trim(),
      createdAt: new Date().toISOString()
    };
    admins.push(newAdmin);
    db.saveCollection('admins', admins);

    // Seed starter default rooms for the new organization
    const starterRooms = [
      { id: `room-${uuidv4().substring(0, 8)}`, orgId: newOrgId, roomNumber: '101', floor: 1, totalBeds: 2, occupiedBeds: 0, status: 'AVAILABLE' },
      { id: `room-${uuidv4().substring(0, 8)}`, orgId: newOrgId, roomNumber: '102', floor: 1, totalBeds: 2, occupiedBeds: 0, status: 'AVAILABLE' },
      { id: `room-${uuidv4().substring(0, 8)}`, orgId: newOrgId, roomNumber: '201', floor: 2, totalBeds: 2, occupiedBeds: 0, status: 'AVAILABLE' }
    ];
    db.saveCollectionForOrg('rooms', newOrgId, starterRooms);

    // Issue JWT Token with complete Org context
    const adminData = {
      id: newAdmin.id,
      orgId: newOrg.id,
      orgCode: newOrg.code,
      orgName: newOrg.name,
      name: newAdmin.name,
      role: newAdmin.role,
      phone: newAdmin.phone
    };

    const token = generateToken(adminData);

    // Log Audit Trail
    logAudit({
      req,
      action: 'ORG_REGISTERED',
      details: `Registered new organization "${newOrg.name}" (${newOrg.code}) with Primary Admin ${newAdmin.name}`,
      adminName: newAdmin.name,
      adminId: newAdmin.id,
      metadata: { orgId: newOrg.id, orgCode: newOrg.code }
    });

    res.status(201).json({
      success: true,
      message: `Organization "${newOrg.name}" registered successfully!`,
      organization: newOrg,
      admin: adminData,
      token: token
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// Get admins scoped to current organization (includes PIN for Org Admin view and profilePhoto)
exports.getAdmins = (req, res) => {
  try {
    const orgId = extractOrgId(req);
    const admins = db.getCollectionForOrg('admins', orgId);
    res.json({ success: true, count: admins.length, data: admins });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// Verify 4-digit Admin PIN & Issue Cryptographically Signed JWT Token
exports.verifyPin = (req, res) => {
  try {
    const { pin, orgId, orgCode } = req.body;
    if (!pin) {
      return res.status(400).json({ success: false, message: 'PIN is required' });
    }

    const organizations = db.getCollection('organizations') || [];
    const allAdmins = db.getCollection('admins') || [];

    // 1. Identify Target Organization if provided via body or headers
    let targetOrg = null;
    const headerOrgId = req.headers['x-org-id'];
    const searchOrgCode = (orgCode || '').toUpperCase();
    const searchOrgId = orgId || headerOrgId;

    if (searchOrgId) {
      targetOrg = organizations.find(o => o.id === searchOrgId);
    } else if (searchOrgCode) {
      targetOrg = organizations.find(o => (o.code || '').toUpperCase() === searchOrgCode);
    }

    // 🚫 If an Organization Code or ID was specified but does not exist, REJECT! Do NOT auto-connect or fall back.
    if ((searchOrgId || searchOrgCode) && !targetOrg) {
      return res.status(404).json({
        success: false,
        message: `Organization with code "${searchOrgCode || searchOrgId}" not found. Please check your Organization Code or register your hostel first.`
      });
    }

    let matchedAdmin = null;

    if (targetOrg) {
      // Find admin in target org with matching PIN
      matchedAdmin = allAdmins.find(a => (a.orgId || 'org-default') === targetOrg.id && a.pin === pin.trim());
    } else {
      // Search all admins across orgs
      const matchingAdmins = allAdmins.filter(a => a.pin === pin.trim());
      if (matchingAdmins.length === 1) {
        matchedAdmin = matchingAdmins[0];
        targetOrg = organizations.find(o => o.id === (matchedAdmin.orgId || 'org-default'));
      } else if (matchingAdmins.length > 1) {
        // Multiple admins have same PIN across different orgs - pick the first
        matchedAdmin = matchingAdmins[0];
        targetOrg = organizations.find(o => o.id === (matchedAdmin.orgId || 'org-default'));
      }
    }

    if (!matchedAdmin) {
      return res.status(401).json({
        success: false,
        message: targetOrg 
          ? `Invalid PIN for organization "${targetOrg.name}"`
          : 'Invalid Admin PIN. Please check your PIN or select your Organization.'
      });
    }

    if (!targetOrg) {
      targetOrg = organizations.find(o => o.id === (matchedAdmin.orgId || 'org-default')) || {
        id: 'org-default',
        name: 'City Pride Hostel & Mess',
        code: 'CITYPRIDE'
      };
    }

    const adminData = {
      id: matchedAdmin.id,
      orgId: targetOrg.id,
      orgCode: targetOrg.code,
      orgName: targetOrg.name,
      name: matchedAdmin.name,
      role: matchedAdmin.role,
      phone: matchedAdmin.phone,
      pin: matchedAdmin.pin,
      profilePhoto: matchedAdmin.profilePhoto || ''
    };

    // Issue Secure JWT Bearer Token
    const token = generateToken(adminData);

    // Record login in audit log
    logAudit({
      req,
      action: 'ADMIN_LOGIN',
      details: `${matchedAdmin.name} logged into "${targetOrg.name}" via verified PIN`,
      adminName: matchedAdmin.name,
      adminId: matchedAdmin.id,
      metadata: { orgId: targetOrg.id, orgCode: targetOrg.code }
    });

    res.json({
      success: true,
      message: `Welcome, ${matchedAdmin.name}`,
      admin: adminData,
      organization: targetOrg,
      token: token
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// Forgot / Reset PIN via Registered Mobile Number
exports.forgotPin = (req, res) => {
  try {
    const { phone, newPin, orgId, orgCode } = req.body;
    if (!phone || !newPin) {
      return res.status(400).json({ success: false, message: 'Registered mobile number and new 4-digit PIN are required' });
    }

    if (newPin.toString().trim().length !== 4) {
      return res.status(400).json({ success: false, message: 'New PIN must be exactly 4 digits' });
    }

    const organizations = db.getCollection('organizations') || [];
    const allAdmins = db.getCollection('admins') || [];

    // Find target org if supplied
    let targetOrgId = orgId || req.headers['x-org-id'];
    if (!targetOrgId && orgCode) {
      const foundOrg = organizations.find(o => (o.code || '').toUpperCase() === orgCode.toUpperCase());
      if (foundOrg) targetOrgId = foundOrg.id;
    }

    const cleanPhone = phone.toString().replace(/\D/g, '');

    // Match admin/staff by phone
    let adminIndex = -1;
    if (targetOrgId) {
      adminIndex = allAdmins.findIndex(a => 
        (a.orgId || 'org-default') === targetOrgId && 
        (a.phone || '').toString().replace(/\D/g, '') === cleanPhone
      );
    }
    
    // Fallback: search all organizations if not found with specific orgId
    if (adminIndex === -1) {
      adminIndex = allAdmins.findIndex(a => 
        (a.phone || '').toString().replace(/\D/g, '') === cleanPhone
      );
    }

    if (adminIndex === -1) {
      return res.status(404).json({
        success: false,
        message: 'No account found matching this registered mobile number in this hostel.'
      });
    }

    const matchedAdmin = allAdmins[adminIndex];
    const roleLower = (matchedAdmin.role || '').toLowerCase();
    const isPrimaryAdmin = roleLower.includes('chief') || 
                           roleLower.includes('owner') || 
                           roleLower.includes('super') || 
                           roleLower.includes('primary') ||
                           roleLower === 'admin' ||
                           matchedAdmin.isPrimaryAdmin === true ||
                           matchedAdmin.id === 'admin-1';

    if (!isPrimaryAdmin) {
      return res.status(403).json({
        success: false,
        message: 'Only the Primary Admin / Chief Warden can reset their PIN from the login screen. Staff members can change their PIN from their Profile once logged in, or ask the Chief Warden to reset it.'
      });
    }

    matchedAdmin.pin = newPin.toString().trim();
    matchedAdmin.updatedAt = new Date().toISOString();
    allAdmins[adminIndex] = matchedAdmin;
    db.saveCollection('admins', allAdmins);

    // Audit trail
    logAudit({
      req,
      action: 'ADMIN_PIN_RESET',
      details: `🛡️ [Primary Admin PIN Reset] ${matchedAdmin.name} (${matchedAdmin.role}, Phone: ${matchedAdmin.phone || 'N/A'}) reset their login PIN via phone recovery`,
      adminName: matchedAdmin.name,
      adminId: matchedAdmin.id,
      metadata: {
        phone: matchedAdmin.phone,
        orgId: matchedAdmin.orgId,
        adminId: matchedAdmin.id,
        newPin: newPin.toString().trim(),
        notificationType: 'ADMIN_PIN_RESET'
      }
    });

    res.json({
      success: true,
      message: `Primary Admin PIN for "${matchedAdmin.name}" has been reset successfully! You can now log in with your new PIN.`,
      userName: matchedAdmin.name
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// Update Admin / Staff PIN (Notifies Admin with New PIN in Details)
exports.updatePin = (req, res) => {
  try {
    const { adminId, currentPin, newPin } = req.body;
    if (!adminId || !currentPin || !newPin) {
      return res.status(400).json({ success: false, message: 'All fields are required' });
    }

    if (newPin.toString().trim().length !== 4) {
      return res.status(400).json({ success: false, message: 'New PIN must be exactly 4 digits' });
    }

    const orgId = extractOrgId(req);
    const admins = db.getCollection('admins') || [];
    const index = admins.findIndex(a => a.id === adminId && (a.orgId || 'org-default') === orgId);

    if (index === -1) {
      return res.status(404).json({ success: false, message: 'User not found in current organization' });
    }

    if (admins[index].pin !== currentPin.trim()) {
      return res.status(401).json({ success: false, message: 'Incorrect current PIN' });
    }

    admins[index].pin = newPin.toString().trim();
    db.saveCollection('admins', admins);

    // 🔔 Notify Org Admin via High-Priority Audit Log & Notification Entry containing the new PIN
    const notificationMessage = `⚠️ [PIN Changed] Staff member "${admins[index].name}" (${admins[index].role}, Phone: ${admins[index].phone || 'N/A'}) updated their login PIN to: ${newPin.toString().trim()}`;

    logAudit({
      req,
      action: 'STAFF_PIN_CHANGED',
      details: notificationMessage,
      adminName: admins[index].name,
      adminId: admins[index].id,
      metadata: {
        orgId: orgId,
        staffId: admins[index].id,
        staffName: admins[index].name,
        staffRole: admins[index].role,
        newPin: newPin.toString().trim(),
        notificationType: 'PIN_CHANGE_ALERT',
        isHighPriority: true
      }
    });

    res.json({
      success: true,
      message: 'PIN updated successfully! Your Organization Admin has been notified of the new PIN.',
      newPin: newPin.toString().trim()
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// Add New Staff / User to Organization (Org Admin decides initial PIN)
exports.addUser = async (req, res) => {
  try {
    const orgId = extractOrgId(req);
    const { name, role, phone, pin, profilePhoto } = req.body;

    if (!name || !pin) {
      return res.status(400).json({ success: false, message: 'Name and 4-Digit PIN are required' });
    }

    if (pin.toString().trim().length !== 4) {
      return res.status(400).json({ success: false, message: 'PIN must be exactly 4 digits' });
    }

    const admins = db.getCollection('admins') || [];
    const orgAdmins = admins.filter(a => (a.orgId || 'org-default') === orgId);

    if (phone && phone.trim().length > 0 && orgAdmins.some(a => a.phone === phone.trim())) {
      return res.status(400).json({ success: false, message: `A user with phone "${phone}" already exists in this organization` });
    }

    // ☁️ Offload photo to Supabase Storage
    const storedPhotoUrl = await storageService.processImage(profilePhoto, 'admins');

    const newAdmin = {
      id: `admin-${uuidv4().substring(0, 8)}`,
      orgId: orgId,
      name: name.trim(),
      role: (role || 'Staff / Warden').trim(),
      phone: (phone || '').trim(),
      pin: pin.toString().trim(),
      profilePhoto: storedPhotoUrl || '',
      createdAt: new Date().toISOString()
    };

    admins.push(newAdmin);
    db.saveCollection('admins', admins);

    const actorName = req.admin ? req.admin.name : 'Organization Admin';
    logAudit({
      req,
      action: 'USER_ADDED',
      details: `${actorName} added staff member "${newAdmin.name}" (${newAdmin.role}, Phone: ${newAdmin.phone || 'N/A'})`,
      adminName: actorName,
      adminId: req.admin ? req.admin.id : null,
      metadata: { newUserId: newAdmin.id, newUserName: newAdmin.name, role: newAdmin.role }
    });

    res.status(201).json({
      success: true,
      message: `User "${newAdmin.name}" added successfully with PIN ${newAdmin.pin}!`,
      data: newAdmin
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// Update Staff / User Details
exports.updateUser = async (req, res) => {
  try {
    const orgId = extractOrgId(req);
    const { id } = req.params;
    const { name, role, phone, profilePhoto } = req.body;

    const admins = db.getCollection('admins') || [];
    const index = admins.findIndex(a => a.id === id && (a.orgId || 'org-default') === orgId);

    if (index === -1) {
      return res.status(404).json({ success: false, message: 'User not found in current organization' });
    }

    if (name) admins[index].name = name.trim();
    if (role) admins[index].role = role.trim();
    if (phone !== undefined) admins[index].phone = phone.trim();
    if (profilePhoto !== undefined) {
      admins[index].profilePhoto = await storageService.processImage(profilePhoto, 'admins');
    }

    db.saveCollection('admins', admins);

    const actorName = req.admin ? req.admin.name : 'Organization Admin';
    logAudit({
      req,
      action: 'USER_UPDATED',
      details: `${actorName} updated profile for staff member "${admins[index].name}" (${admins[index].role})`,
      adminName: actorName,
      adminId: req.admin ? req.admin.id : null,
      metadata: { targetUserId: id }
    });

    res.json({ success: true, message: 'User updated successfully', data: admins[index] });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// Remove Staff Member from Organization
exports.deleteUser = (req, res) => {
  try {
    const orgId = extractOrgId(req);
    const { id } = req.params;

    const admins = db.getCollection('admins') || [];
    const orgAdmins = admins.filter(a => (a.orgId || 'org-default') === orgId);

    if (orgAdmins.length <= 1) {
      return res.status(400).json({ success: false, message: 'Cannot delete the only administrator in the organization' });
    }

    const targetUser = orgAdmins.find(a => a.id === id);
    if (!targetUser) {
      return res.status(404).json({ success: false, message: 'User not found in current organization' });
    }

    const updatedAdmins = admins.filter(a => !(a.id === id && (a.orgId || 'org-default') === orgId));
    db.saveCollection('admins', updatedAdmins);

    const actorName = req.admin ? req.admin.name : 'Organization Admin';
    logAudit({
      req,
      action: 'USER_DELETED',
      details: `${actorName} removed staff member "${targetUser.name}" (${targetUser.role})`,
      adminName: actorName,
      adminId: req.admin ? req.admin.id : null,
      metadata: { deletedUserId: id, deletedUserName: targetUser.name }
    });

    res.json({ success: true, message: `Staff member "${targetUser.name}" removed successfully` });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// Organization Admin Directly Resets Staff PIN
exports.resetUserPin = (req, res) => {
  try {
    const orgId = extractOrgId(req);
    const { targetAdminId, newPin } = req.body;

    if (!targetAdminId || !newPin) {
      return res.status(400).json({ success: false, message: 'Target User ID and New 4-Digit PIN are required' });
    }

    if (newPin.toString().trim().length !== 4) {
      return res.status(400).json({ success: false, message: 'New PIN must be exactly 4 digits' });
    }

    const admins = db.getCollection('admins') || [];
    const index = admins.findIndex(a => a.id === targetAdminId && (a.orgId || 'org-default') === orgId);

    if (index === -1) {
      return res.status(404).json({ success: false, message: 'User not found in current organization' });
    }

    admins[index].pin = newPin.toString().trim();
    db.saveCollection('admins', admins);

    const actorName = req.admin ? req.admin.name : 'Organization Admin';
    logAudit({
      req,
      action: 'PIN_RESET_BY_ADMIN',
      details: `${actorName} reset the 4-digit login PIN for "${admins[index].name}" (${admins[index].role}) to "${newPin.toString().trim()}"`,
      adminName: actorName,
      adminId: req.admin ? req.admin.id : null,
      metadata: { targetUserId: targetAdminId, targetUserName: admins[index].name, newPin: newPin.toString().trim() }
    });

    res.json({
      success: true,
      message: `PIN for "${admins[index].name}" has been reset to ${newPin.toString().trim()}`
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// Update Logged-in User's Profile
exports.updateProfile = async (req, res) => {
  try {
    const orgId = extractOrgId(req);
    const adminId = req.admin ? req.admin.id : req.body.adminId;
    const { name, phone, profilePhoto } = req.body;

    if (!adminId) {
      return res.status(400).json({ success: false, message: 'Admin ID is required' });
    }

    const admins = db.getCollection('admins') || [];
    const index = admins.findIndex(a => a.id === adminId && (a.orgId || 'org-default') === orgId);

    if (index === -1) {
      return res.status(404).json({ success: false, message: 'User not found in current organization' });
    }

    if (name) admins[index].name = name.trim();
    if (phone !== undefined) admins[index].phone = phone.trim();
    if (profilePhoto !== undefined) {
      admins[index].profilePhoto = await storageService.processImage(profilePhoto, 'admins');
    }

    db.saveCollection('admins', admins);

    logAudit({
      req,
      action: 'PROFILE_UPDATED',
      details: `${admins[index].name} updated their profile details`,
      adminName: admins[index].name,
      adminId: admins[index].id
    });

    res.json({ success: true, message: 'Profile updated successfully', data: admins[index] });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// Update Organization / Hostel Details (Name, Logo, City, Phone)
exports.updateOrganization = async (req, res) => {
  try {
    const orgId = extractOrgId(req);
    const { name, logo, city, contactPhone } = req.body;

    if (!name || !name.trim()) {
      return res.status(400).json({ success: false, message: 'Hostel / Organization name is required' });
    }

    const organizations = db.getCollection('organizations') || [];
    let index = organizations.findIndex(o => o.id === orgId);

    let processedLogo = logo;
    if (logo !== undefined) {
      processedLogo = await storageService.processImage(logo, 'logos');
    }

    if (index === -1) {
      // If default org doesn't exist in array yet, create it
      const newOrg = {
        id: orgId || 'org-default',
        name: name.trim(),
        code: (req.admin?.orgCode || 'CITYPRIDE').toUpperCase(),
        city: (city || 'Main Campus').trim(),
        contactPhone: (contactPhone || '').trim(),
        logo: processedLogo || '',
        createdAt: new Date().toISOString()
      };
      organizations.push(newOrg);
      db.saveCollection('organizations', organizations);
      index = organizations.length - 1;
    } else {
      organizations[index].name = name.trim();
      if (city !== undefined) organizations[index].city = city.trim();
      if (contactPhone !== undefined) organizations[index].contactPhone = contactPhone.trim();
      if (logo !== undefined) organizations[index].logo = processedLogo || '';
      organizations[index].updatedAt = new Date().toISOString();
      db.saveCollection('organizations', organizations);
    }

    const actorName = req.admin ? req.admin.name : 'Organization Admin';
    logAudit({
      req,
      action: 'ORG_DETAILS_UPDATED',
      details: `${actorName} updated hostel details: Name -> "${organizations[index].name}"`,
      adminName: actorName,
      adminId: req.admin ? req.admin.id : null,
      metadata: { orgId: organizations[index].id, name: organizations[index].name, hasLogo: !!organizations[index].logo }
    });

    res.json({
      success: true,
      message: `Hostel details for "${organizations[index].name}" updated successfully!`,
      data: organizations[index]
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// Get PIN Change & System Notifications
exports.getNotifications = (req, res) => {
  try {
    const orgId = extractOrgId(req);
    const logs = db.getCollectionForOrg('audit_logs', orgId) || [];
    
    const notifications = logs.filter(l => 
      l.action === 'STAFF_PIN_CHANGED' || 
      l.action === 'PIN_RESET_BY_ADMIN' || 
      l.action === 'PIN_RESET_SELF' ||
      l.action === 'USER_ADDED' ||
      l.action === 'USER_DELETED' ||
      (l.metadata && (l.metadata.isHighPriority || l.metadata.notificationType === 'PIN_CHANGE_ALERT'))
    );
    
    notifications.sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));
    res.json({ success: true, count: notifications.length, data: notifications });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// Get Audit Logs scoped to current organization (Excludes PIN change logs)
exports.getAuditLogs = (req, res) => {
  try {
    const orgId = extractOrgId(req);
    const logs = db.getCollectionForOrg('audit_logs', orgId);
    
    // Explicitly filter out any PIN change actions from the general audit log
    const auditLogs = logs.filter(l => {
      const action = (l.action || '').toUpperCase();
      const type = (l.metadata && l.metadata.notificationType) || '';
      return (
        action !== 'STAFF_PIN_CHANGED' &&
        action !== 'PIN_RESET_BY_ADMIN' &&
        action !== 'PIN_RESET_SELF' &&
        action !== 'PIN_CHANGE' &&
        !action.includes('PIN') &&
        type !== 'PIN_CHANGE_ALERT'
      );
    });

    auditLogs.sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));
    res.json({ success: true, count: auditLogs.length, data: auditLogs });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// 📜 Get Permanent Master Register (Hostel & Mess Archive)
exports.getMasterRegister = (req, res) => {
  try {
    const orgId = extractOrgId(req);
    const { search, status, type } = req.query;
    const result = db.getMasterRegisterForOrg(orgId, { search, status, type });
    res.json({
      success: true,
      stats: result.stats,
      count: result.records.length,
      data: result.records
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

