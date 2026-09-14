const express = require('express');
const router = express.Router();
const roomController = require('../controllers/roomController');

router.get('/', roomController.getRooms);
router.post('/', roomController.createRoom);
router.put('/:id', roomController.updateRoom);

module.exports = router;
