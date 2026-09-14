const express = require('express');
const router = express.Router();
const adminController = require('../controllers/adminController');
const { authLimiter } = require('../middleware/securityMiddleware');
const { verifyToken } = require('../middleware/authMiddleware');

router.get('/organizations', adminController.getOrganizations);
router.post('/register-organization', authLimiter, adminController.registerOrganization);
router.get('/', adminController.getAdmins);
router.get('/list', adminController.getAdmins);
router.post('/verify-pin', authLimiter, adminController.verifyPin);
router.post('/forgot-pin', authLimiter, adminController.forgotPin);
router.post('/update-pin', verifyToken, adminController.updatePin);
router.post('/reset-user-pin', verifyToken, adminController.resetUserPin);
router.post('/add-user', verifyToken, adminController.addUser);
router.put('/users/:id', verifyToken, adminController.updateUser);
router.delete('/users/:id', verifyToken, adminController.deleteUser);
router.put('/profile', verifyToken, adminController.updateProfile);
router.put('/organization', verifyToken, adminController.updateOrganization);
router.get('/notifications', verifyToken, adminController.getNotifications);
router.get('/audit-logs', verifyToken, adminController.getAuditLogs);
router.get('/master-register', verifyToken, adminController.getMasterRegister);

module.exports = router;

