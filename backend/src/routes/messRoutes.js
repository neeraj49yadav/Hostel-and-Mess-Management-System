const express = require('express');
const router = express.Router();
const messController = require('../controllers/messController');

// Mess Members (Outside + Hostelites)
router.get('/members', messController.getMessMembers);
router.post('/members', messController.createMessMember);
router.delete('/members/:id', messController.unenrollMessMember);
router.post('/members/:id/unenroll', messController.unenrollMessMember);
router.post('/bulk-extend-validity', messController.bulkExtendMessValidity);

// Daily Kitchen Grocery Expenses
router.get('/expenses', messController.getExpenses);
router.post('/expenses', messController.addExpense);
router.delete('/expenses/:id', messController.deleteExpense);

// Suppliers & Khata
router.get('/vendors', messController.getVendors);
router.post('/vendors', messController.saveVendor);

module.exports = router;
