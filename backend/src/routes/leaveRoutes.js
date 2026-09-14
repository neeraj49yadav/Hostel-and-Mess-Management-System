const express = require('express');
const router = express.Router();
const leaveController = require('../controllers/leaveController');

router.get('/', leaveController.getLeaveLogs);
router.post('/', leaveController.recordDeparture);
router.post('/departure', leaveController.recordDeparture);
router.post('/:id/return', leaveController.recordReturn);
router.put('/:id/return', leaveController.recordReturn);

module.exports = router;
