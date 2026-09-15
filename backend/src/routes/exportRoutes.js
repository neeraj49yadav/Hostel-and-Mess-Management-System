const express = require('express');
const router = express.Router();
const exportController = require('../controllers/exportController');

// All export and reset routes are protected by JWT auth (verifyToken mounted at app.use in server.js)
router.get('/backup', exportController.exportFullBackup);
router.get('/master-data', exportController.exportMasterData);
router.get('/cashbook-pnl', exportController.exportCashbookAndPnL);
router.post('/reset-master-data', exportController.resetMasterData);
router.post('/reset-financials', exportController.resetFinancials);

module.exports = router;
