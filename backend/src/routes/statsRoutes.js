const express = require('express');
const router = express.Router();
const statsController = require('../controllers/statsController');

router.get('/dashboard', statsController.getDashboardStats);
router.get('/dues-expiries', statsController.getDuesAndExpiries);
router.get('/cashbook', statsController.getCashbook);

module.exports = router;
