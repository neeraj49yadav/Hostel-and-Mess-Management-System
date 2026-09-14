import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/room.dart';
import '../../providers/auth_provider.dart';
import '../../providers/hostel_provider.dart';

class RoomMatrixScreen extends StatefulWidget {
  const RoomMatrixScreen({super.key});

  @override
  State<RoomMatrixScreen> createState() => _RoomMatrixScreenState();
}

class _RoomMatrixScreenState extends State<RoomMatrixScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HostelProvider>().fetchRooms();
    });
  }

  void _showAddRoomDialog() {
    final roomNumberCtrl = TextEditingController();
    final floorCtrl = TextEditingController(text: '1');
    final totalBedsCtrl = TextEditingController(text: '2');
    final hostel = context.read<HostelProvider>();
    final auth = context.read<AuthProvider>();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Add New Room'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: roomNumberCtrl, decoration: const InputDecoration(labelText: 'Room Number (e.g. 104)')),
              const SizedBox(height: 10),
              TextField(controller: floorCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Floor (1, 2, 3...)')),
              const SizedBox(height: 10),
              TextField(controller: totalBedsCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Total Bed Capacity (2, 3, 4)')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (roomNumberCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                final success = await hostel.createRoom({
                  'roomNumber': roomNumberCtrl.text.trim(),
                  'floor': int.tryParse(floorCtrl.text) ?? 1,
                  'totalBeds': int.tryParse(totalBedsCtrl.text) ?? 2,
                  'adminName': auth.currentAdmin?.name ?? 'Admin',
                });
                if (mounted) {
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Room registered!'), backgroundColor: AppColors.success),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(hostel.error ?? 'Failed to register room'), backgroundColor: AppColors.danger),
                    );
                  }
                }
              },
              child: const Text('Add Room'),
            ),
          ],
        );
      },
    );
  }

  void _showEditRoomDialog(Room room) {
    final roomNumberCtrl = TextEditingController(text: room.roomNumber);
    final floorCtrl = TextEditingController(text: room.floor.toString());
    final totalBedsCtrl = TextEditingController(text: room.totalBeds.toString());
    final hostel = context.read<HostelProvider>();
    final auth = context.read<AuthProvider>();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Edit Room ${room.roomNumber}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: roomNumberCtrl,
                decoration: const InputDecoration(labelText: 'Room Number (e.g. 104)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: floorCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Floor (1, 2, 3...)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: totalBedsCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Total Bed Capacity',
                  helperText: 'Min ${room.occupiedBeds} beds (currently occupied)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (roomNumberCtrl.text.trim().isEmpty) return;
                final newBeds = int.tryParse(totalBedsCtrl.text) ?? room.totalBeds;
                if (newBeds < room.occupiedBeds) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Cannot reduce capacity below ${room.occupiedBeds} occupied beds'),
                      backgroundColor: AppColors.danger,
                    ),
                  );
                  return;
                }
                Navigator.pop(ctx);
                final success = await hostel.updateRoom(room.id, {
                  'roomNumber': roomNumberCtrl.text.trim(),
                  'floor': int.tryParse(floorCtrl.text) ?? room.floor,
                  'totalBeds': newBeds,
                  'adminName': auth.currentAdmin?.name ?? 'Admin',
                });
                if (mounted) {
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Room ${roomNumberCtrl.text} updated!'), backgroundColor: AppColors.success),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(hostel.error ?? 'Failed to update room'), backgroundColor: AppColors.danger),
                    );
                  }
                }
              },
              child: const Text('Save Changes'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hostel = context.watch<HostelProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rooms = hostel.rooms;

    // Group rooms by floor
    final Map<int, List<Room>> floorMap = {};
    for (var r in rooms) {
      if (!floorMap.containsKey(r.floor)) floorMap[r.floor] = [];
      floorMap[r.floor]!.add(r);
    }

    final sortedFloors = floorMap.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Visual Room & Bed Grid', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_home_outlined),
            tooltip: 'Add Room',
            onPressed: _showAddRoomDialog,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => hostel.fetchRooms(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Legend
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildLegendItem(const Color(0xFF10B981), 'Vacant Bed', isDark),
                  _buildLegendItem(isDark ? AppColors.primaryLight : AppColors.primary, 'Occupied Bed', isDark),
                  _buildLegendItem(AppColors.danger, 'Room Full', isDark),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (sortedFloors.isEmpty)
              const Center(child: Text('No rooms configured'))
            else
              ...sortedFloors.map((floor) {
                final floorRooms = floorMap[floor]!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        '🏢 Floor $floor (${floorRooms.length} Rooms)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                        ),
                      ),
                    ),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.15,
                      ),
                      itemCount: floorRooms.length,
                      itemBuilder: (context, index) {
                        final room = floorRooms[index];
                        final isFull = room.occupiedBeds >= room.totalBeds;

                        return InkWell(
                          onTap: () => _showEditRoomDialog(room),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.surfaceDark : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isFull
                                    ? AppColors.danger.withValues(alpha: isDark ? 0.8 : 0.4)
                                    : (isDark ? AppColors.borderDark : AppColors.borderLight),
                                width: isFull ? 1.5 : 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              'Room ${room.roomNumber}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Icon(Icons.edit_outlined, size: 14, color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isFull
                                            ? (isDark
                                                ? const Color(0xFF7F1D1D).withValues(alpha: 0.6)
                                                : const Color(0xFFFEE2E2))
                                            : (isDark
                                                ? const Color(0xFF064E3B).withValues(alpha: 0.6)
                                                : const Color(0xFFD1FAE5)),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '${room.occupiedBeds}/${room.totalBeds}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isFull
                                              ? (isDark ? const Color(0xFFF87171) : AppColors.danger)
                                              : (isDark ? const Color(0xFF34D399) : const Color(0xFF065F46)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                              // Bed Indicators
                              Row(
                                children: List.generate(room.totalBeds, (bIdx) {
                                  final isOccupied = bIdx < room.occupiedBeds;
                                  final occupant = isOccupied && bIdx < room.occupants.length ? room.occupants[bIdx] : null;

                                  final occColor = isDark ? AppColors.primaryLight : AppColors.primary;
                                  final vacColor = isDark ? const Color(0xFF34D399) : const Color(0xFF10B981);

                                  return Expanded(
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 2),
                                      padding: const EdgeInsets.symmetric(vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isOccupied
                                            ? occColor.withValues(alpha: isDark ? 0.25 : 0.12)
                                            : vacColor.withValues(alpha: isDark ? 0.2 : 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: isOccupied
                                              ? occColor.withValues(alpha: isDark ? 0.5 : 0.3)
                                              : vacColor.withValues(alpha: isDark ? 0.4 : 0.3),
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          Icon(
                                            Icons.single_bed,
                                            size: 16,
                                            color: isOccupied ? occColor : vacColor,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            occupant != null
                                                ? (occupant.name.split(' ').first)
                                                : 'Vacant',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w600,
                                              color: isOccupied ? occColor : vacColor,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                              ),

                              Text(
                                '${room.vacantBeds} Bed${room.vacantBeds != 1 ? 's' : ''} Available',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label, bool isDark) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          ),
        ),
      ],
    );
  }
}
