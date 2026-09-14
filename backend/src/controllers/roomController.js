const db = require('../config/db');
const { v4: uuidv4 } = require('uuid');
const { logAudit } = require('../services/auditService');
const { extractOrgId } = require('../middleware/authMiddleware');

// Helper to recalculate occupied beds in rooms based on active students
function refreshRoomOccupancy(orgId) {
  const rooms = db.getCollectionForOrg('rooms', orgId);
  const students = db.getCollectionForOrg('students', orgId);

  rooms.forEach(room => {
    const activeInRoom = students.filter(s => s.roomId === room.id && s.status !== 'ARCHIVED');
    room.occupiedBeds = activeInRoom.length;
    room.status = room.occupiedBeds >= room.totalBeds ? 'FULL' : 'AVAILABLE';
  });

  db.saveCollectionForOrg('rooms', orgId, rooms);
  return rooms;
}

// Get all rooms (with floors grouped)
exports.getRooms = (req, res) => {
  try {
    const orgId = extractOrgId(req);
    const rooms = refreshRoomOccupancy(orgId);
    const students = db.getCollectionForOrg('students', orgId);

    // Attach student summary to each room
    const enrichedRooms = rooms.map(room => {
      const occupants = students
        .filter(s => s.roomId === room.id && s.status !== 'ARCHIVED')
        .map(s => ({
          id: s.id,
          name: s.name,
          phone: s.phone,
          bedNo: s.bedNo,
          photoUrl: s.photoUrl || '',
          messExpiryDate: s.messExpiryDate,
          rentExpiryDate: s.rentExpiryDate,
          status: s.status
        }));

      return {
        ...room,
        orgId,
        occupants,
        vacantBeds: Math.max(0, room.totalBeds - room.occupiedBeds)
      };
    });

    // Group by floor
    const floors = {};
    enrichedRooms.forEach(room => {
      if (!floors[room.floor]) floors[room.floor] = [];
      floors[room.floor].push(room);
    });

    res.json({
      success: true,
      totalRooms: enrichedRooms.length,
      totalBeds: enrichedRooms.reduce((acc, r) => acc + r.totalBeds, 0),
      totalOccupied: enrichedRooms.reduce((acc, r) => acc + r.occupiedBeds, 0),
      totalVacant: enrichedRooms.reduce((acc, r) => acc + r.vacantBeds, 0),
      rooms: enrichedRooms,
      data: enrichedRooms,
      floors
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// Create new room
exports.createRoom = (req, res) => {
  try {
    const orgId = extractOrgId(req);
    const { roomNumber, floor, totalBeds, adminName } = req.body;
    if (!roomNumber || !floor || !totalBeds) {
      return res.status(400).json({ success: false, message: 'roomNumber, floor and totalBeds are required' });
    }

    const rooms = db.getCollectionForOrg('rooms', orgId);
    if (rooms.find(r => r.roomNumber === roomNumber.toString())) {
      return res.status(400).json({ success: false, message: 'Room number already exists' });
    }

    const newRoom = {
      id: `room-${uuidv4().substring(0, 8)}`,
      orgId,
      roomNumber: roomNumber.toString(),
      floor: parseInt(floor),
      totalBeds: parseInt(totalBeds),
      occupiedBeds: 0,
      status: 'AVAILABLE'
    };

    rooms.push(newRoom);
    db.saveCollectionForOrg('rooms', orgId, rooms);

    // 🛡️ Log Room Creation into Audit Log
    logAudit({
      req,
      action: 'CREATE_ROOM',
      details: `Created new Room ${newRoom.roomNumber} on Floor ${newRoom.floor} with capacity of ${newRoom.totalBeds} beds`,
      adminName
    });

    res.status(201).json({ success: true, data: newRoom });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// Update existing room
exports.updateRoom = (req, res) => {
  try {
    const orgId = extractOrgId(req);
    const { id } = req.params;
    const { roomNumber, floor, totalBeds, adminName } = req.body;

    const rooms = db.getCollectionForOrg('rooms', orgId);
    const index = rooms.findIndex(r => r.id === id);
    if (index === -1) {
      return res.status(404).json({ success: false, message: 'Room not found' });
    }

    const students = db.getCollectionForOrg('students', orgId);
    const activeOccupants = students.filter(s => s.roomId === id && s.status !== 'ARCHIVED');

    const newTotalBeds = totalBeds !== undefined ? parseInt(totalBeds) : rooms[index].totalBeds;
    if (newTotalBeds < activeOccupants.length) {
      return res.status(400).json({
        success: false,
        message: `Cannot reduce capacity to ${newTotalBeds} beds. Room currently has ${activeOccupants.length} active occupants.`
      });
    }

    // Check if new roomNumber conflicts with another room
    if (roomNumber && roomNumber.toString() !== rooms[index].roomNumber) {
      const conflict = rooms.find(r => r.id !== id && r.roomNumber === roomNumber.toString());
      if (conflict) {
        return res.status(400).json({ success: false, message: `Room number ${roomNumber} already exists` });
      }
    }

    const oldRoomNumber = rooms[index].roomNumber;
    const oldFloor = rooms[index].floor;
    const oldBeds = rooms[index].totalBeds;

    rooms[index].roomNumber = roomNumber !== undefined ? roomNumber.toString().trim() : rooms[index].roomNumber;
    rooms[index].floor = floor !== undefined ? parseInt(floor) : rooms[index].floor;
    rooms[index].totalBeds = newTotalBeds;
    rooms[index].occupiedBeds = activeOccupants.length;
    rooms[index].status = rooms[index].occupiedBeds >= rooms[index].totalBeds ? 'FULL' : 'AVAILABLE';

    // If room number changed, update roomNumber in students collection
    if (roomNumber && roomNumber.toString() !== oldRoomNumber) {
      students.forEach(s => {
        if (s.roomId === id) {
          s.roomNumber = rooms[index].roomNumber;
        }
      });
      db.saveCollectionForOrg('students', orgId, students);
    }

    db.saveCollectionForOrg('rooms', orgId, rooms);

    // 🛡️ Log Room Update into Audit Log
    logAudit({
      req,
      action: 'UPDATE_ROOM',
      details: `Updated Room ${oldRoomNumber} (Floor ${oldFloor}, ${oldBeds} beds) -> Room ${rooms[index].roomNumber} (Floor ${rooms[index].floor}, ${rooms[index].totalBeds} beds)`,
      adminName: adminName || (req.admin && req.admin.name) || 'Admin'
    });

    res.json({ success: true, message: 'Room updated successfully', data: rooms[index] });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

