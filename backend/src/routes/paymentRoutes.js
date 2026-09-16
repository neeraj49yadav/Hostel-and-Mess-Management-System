const express = require('express');
const router = express.Router();
const paymentController = require('../controllers/paymentController');

router.get('/', paymentController.getPayments);
router.post('/', paymentController.recordPayment);
router.delete('/:id', paymentController.deletePayment);

module.exports = router;
