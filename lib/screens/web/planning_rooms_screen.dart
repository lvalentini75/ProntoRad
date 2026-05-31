import 'package:flutter/material.dart';
import 'package:xraynow/auth/supabase_auth_manager.dart';
import 'package:xraynow/models/booking.dart';
import 'package:xraynow/models/organization.dart';
import 'package:xraynow/models/room.dart';
import 'package:xraynow/services/booking_service.dart';
import 'package:xraynow/services/organization_service.dart';
import 'package:xraynow/services/room_service.dart';
import 'package:xraynow/theme.dart';

/// Vista calendario giornaliera multi-sala (Planning Sale).
/// Le colonne sono le "sale" / macchinari dell'ospedale e le righe sono
/// fasce orarie configurabili (default 15 minuti).
class PlanningRoomsScreen extends StatefulWidget {
  const PlanningRoomsScreen({super.key});

  @override
  State<PlanningRoomsScreen> createState() => _PlanningRoomsScreenState();
}

class _PlanningRoomsScreenState extends State<PlanningRoomsScreen> {
  final RoomService _roomService = RoomService();
  final BookingService _bookingService = BookingService();
  final OrganizationService _orgService = OrganizationService();

  bool _loading = true;
  Organization? _organization;
  List<Room> _rooms = [];
  List<Booking> _bookings = [];
  DateTime _selectedDate = DateTime.now();

  // Layout config (derived from organization)
  int get _startHour => _organization?.planningStartHour ?? 7;
  int get _endHour => _organization?.planningEndHour ?? 20;
  int get _slotMinutes => _organization?.planningSlotMinutes ?? 15;

  static const double _rowHeight = 22.0; // px per slot row
  static const double _timeColWidth = 70.0;
  static const double _columnMinWidth = 140.0;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final profile = SupabaseAuthManager.instance.cachedProfile;
      final orgId = profile?.organizationId;
      if (orgId == null || orgId.isEmpty) {
        setState(() => _loading = false);
        return;
      }
      final org = await _orgService.getOrganizationById(orgId);
      final rooms = await _roomService.getRoomsForOrganization(orgId);
      final bookings = await _bookingService.getBookingsForOrganization(orgId);
      if (!mounted) return;
      setState(() {
        _organization = org;
        _rooms = rooms;
        _bookings = bookings;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[PlanningRoomsScreen] Error loading: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reloadBookings() async {
    final orgId = _organization?.id;
    if (orgId == null) return;
    final bookings = await _bookingService.getBookingsForOrganization(orgId);
    if (mounted) setState(() => _bookings = bookings);
  }

  List<DateTime> get _timeSlots {
    final result = <DateTime>[];
    final base = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _startHour);
    final end = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _endHour);
    var cursor = base;
    while (cursor.isBefore(end)) {
      result.add(cursor);
      cursor = cursor.add(Duration(minutes: _slotMinutes));
    }
    return result;
  }

  List<Booking> _bookingsForRoom(String? roomId) {
    return _bookings.where((b) {
      final sameDay = b.bookingTime.year == _selectedDate.year &&
          b.bookingTime.month == _selectedDate.month &&
          b.bookingTime.day == _selectedDate.day;
      return sameDay && b.roomId == roomId;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_organization == null) {
      return const Scaffold(body: Center(child: Text('Organizzazione non trovata')));
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1419) : const Color(0xFFF8FAFC),
      body: Column(
        children: [
          _buildHeader(context, colorScheme, isDark),
          Expanded(
            child: _rooms.isEmpty
                ? _buildEmptyState(context)
                : _buildCalendar(context, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ColorScheme cs, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1F26) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF2A3340) : const Color(0xFFE8EDF2),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_view_day_rounded, color: cs.primary, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Planning Sale',
                    style: context.textStyles.headlineMedium?.bold),
                Text('Vista giornaliera multi-sala — orari ${_startHour.toString().padLeft(2, '0')}:00 - ${_endHour.toString().padLeft(2, '0')}:00 • slot ${_slotMinutes}min',
                    style: context.textStyles.bodyMedium
                        ?.withColor(cs.onSurfaceVariant)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Giorno precedente',
            onPressed: () => setState(() => _selectedDate =
                _selectedDate.subtract(const Duration(days: 1))),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.event_rounded, size: 18),
            label: Text(_formatDate(_selectedDate)),
          ),
          IconButton(
            tooltip: 'Giorno successivo',
            onPressed: () => setState(() =>
                _selectedDate = _selectedDate.add(const Duration(days: 1))),
            icon: const Icon(Icons.chevron_right_rounded),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: () => setState(() => _selectedDate = DateTime(
                DateTime.now().year, DateTime.now().month, DateTime.now().day)),
            icon: const Icon(Icons.today_rounded, size: 18),
            label: const Text('Oggi'),
          ),
          const SizedBox(width: 12),
          FilledButton.tonalIcon(
            onPressed: _openConfigDialog,
            icon: const Icon(Icons.settings_rounded, size: 18),
            label: const Text('Configura'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _openRoomDialog,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Nuova Sala'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.meeting_room_outlined,
              size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text('Nessuna sala configurata',
              style: context.textStyles.titleLarge?.bold),
          const SizedBox(height: 8),
          Text('Aggiungi le sale/macchinari per iniziare a usare il planning.',
              style: context.textStyles.bodyMedium?.withColor(
                  Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _openRoomDialog,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Aggiungi prima sala'),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar(BuildContext context, bool isDark) {
    final slots = _timeSlots;
    final totalHeight = slots.length * _rowHeight;
    final timeCellBg = isDark ? const Color(0xFF12181F) : const Color(0xFFF1F5F9);
    final borderColor = isDark ? const Color(0xFF2A3340) : const Color(0xFFE2E8F0);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Time column
            Column(
              children: [
                Container(
                  width: _timeColWidth,
                  height: 56,
                  decoration: BoxDecoration(
                    color: timeCellBg,
                    border: Border(
                      right: BorderSide(color: borderColor),
                      bottom: BorderSide(color: borderColor),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text('Ora',
                      style: context.textStyles.labelMedium?.semiBold),
                ),
                SizedBox(
                  width: _timeColWidth,
                  height: totalHeight,
                  child: Column(
                    children: [
                      for (final s in slots)
                        Container(
                          height: _rowHeight,
                          decoration: BoxDecoration(
                            border: Border(
                              right: BorderSide(color: borderColor),
                              bottom: BorderSide(
                                color: s.minute == 0
                                    ? borderColor
                                    : borderColor.withValues(alpha: 0.4),
                              ),
                            ),
                          ),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 6),
                          child: s.minute == 0
                              ? Text(_formatTime(s),
                                  style: context.textStyles.labelSmall?.bold)
                              : Text(_formatTime(s),
                                  style: context.textStyles.labelSmall
                                      ?.withColor(Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            // Room columns (reorderable horizontally)
            ReorderableListView(
              shrinkWrap: true,
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              onReorder: (oldIdx, newIdx) async {
                setState(() {
                  if (newIdx > oldIdx) newIdx -= 1;
                  final r = _rooms.removeAt(oldIdx);
                  _rooms.insert(newIdx, r);
                });
                await _roomService.reorderRooms(_rooms);
              },
              children: [
                for (int i = 0; i < _rooms.length; i++)
                  SizedBox(
                    key: ValueKey('room-${_rooms[i].id}'),
                    width: _columnMinWidth,
                    child: _buildRoomColumn(_rooms[i], i, slots, totalHeight, isDark, borderColor),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomColumn(Room room, int index, List<DateTime> slots,
      double totalHeight, bool isDark, Color borderColor) {
    final roomColor = _parseColor(room.color) ??
        Theme.of(context).colorScheme.primary;
    final bookings = _bookingsForRoom(room.id);

    return Column(
      children: [
        // Header
        ReorderableDragStartListener(
          index: index,
          child: GestureDetector(
            onLongPress: () => _openRoomDialog(room: room),
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                color: roomColor.withValues(alpha: 0.12),
                border: Border(
                  right: BorderSide(color: borderColor),
                  bottom: BorderSide(color: roomColor, width: 2),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      color: roomColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(room.name,
                            style: context.textStyles.labelMedium?.bold,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        if (room.code != null && room.code!.isNotEmpty)
                          Text(room.code!,
                              style: context.textStyles.labelSmall?.withColor(
                                  Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Opzioni sala',
                    iconSize: 18,
                    onSelected: (v) {
                      if (v == 'edit') _openRoomDialog(room: room);
                      if (v == 'delete') _confirmDeleteRoom(room);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Modifica')),
                      PopupMenuItem(
                          value: 'delete', child: Text('Elimina')),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        // Body with bookings
        SizedBox(
          width: _columnMinWidth,
          height: totalHeight,
          child: DragTarget<Booking>(
            onAcceptWithDetails: (details) async {
              final booking = details.data;
              final localY = _calculateLocalY(details.offset, room);
              if (localY != null) {
                await _moveBooking(booking, room, localY);
              }
            },
            builder: (context, candidate, rejected) {
              return Stack(
                children: [
                  // Background rows
                  Column(
                    children: [
                      for (final s in slots)
                        Container(
                          height: _rowHeight,
                          decoration: BoxDecoration(
                            border: Border(
                              right: BorderSide(color: borderColor),
                              bottom: BorderSide(
                                color: s.minute == 0
                                    ? borderColor
                                    : borderColor.withValues(alpha: 0.3),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  // Bookings
                  for (final b in bookings)
                    _buildBookingCard(b, room, roomColor),
                  // Highlight when dragging
                  if (candidate.isNotEmpty)
                    Positioned.fill(
                      child: Container(
                        color: roomColor.withValues(alpha: 0.08),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBookingCard(Booking booking, Room room, Color roomColor) {
    final startMins = booking.bookingTime.hour * 60 + booking.bookingTime.minute;
    final dayStartMins = _startHour * 60;
    final offsetMinutes = startMins - dayStartMins;
    if (offsetMinutes < 0) return const SizedBox.shrink();

    // Default duration: 30 min (ExamType has no duration field yet)
    final durationMin = 30;
    final top = (offsetMinutes / _slotMinutes) * _rowHeight;
    final height = (durationMin / _slotMinutes) * _rowHeight;

    final statusColor = _statusColor(booking.status);

    return Positioned(
      top: top,
      left: 2,
      right: 2,
      height: height.clamp(_rowHeight, double.infinity),
      child: LongPressDraggable<Booking>(
        data: booking,
        feedback: Material(
          color: Colors.transparent,
          child: Container(
            width: _columnMinWidth - 4,
            height: height.clamp(_rowHeight, 80),
            decoration: BoxDecoration(
              color: roomColor.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(6),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
              ],
            ),
            padding: const EdgeInsets.all(6),
            child: Text(
              booking.examType?.name ?? 'Prenotazione',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        childWhenDragging: Opacity(
          opacity: 0.3,
          child: _bookingBox(booking, roomColor, statusColor, height, room),
        ),
        child: GestureDetector(
          onTap: () => _showBookingActions(booking, room),
          child: _bookingBox(booking, roomColor, statusColor, height, room),
        ),
      ),
    );
  }

  Widget _bookingBox(Booking b, Color roomColor, Color statusColor,
      double height, Room room) {
    return Container(
      decoration: BoxDecoration(
        color: roomColor.withValues(alpha: 0.18),
        border: Border.all(color: roomColor, width: 1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 6, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 6, height: 6,
                        decoration: BoxDecoration(
                            color: statusColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _formatTime(b.bookingTime),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (height > 30)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        b.examType?.name ?? '—',
                        style: const TextStyle(fontSize: 10),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (height > 50 && b.user != null)
                    Text(
                      '${b.user!.firstName} ${b.user!.lastName}',
                      style: TextStyle(
                          fontSize: 9,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ),
          // Resize handle (bottom)
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragUpdate: (details) => _onResizeDrag(b, details),
              onVerticalDragEnd: (_) => _onResizeEnd(b),
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeRow,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: roomColor.withValues(alpha: 0.4),
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(6)),
                  ),
                  child: Center(
                    child: Container(
                      width: 24, height: 2,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------- Drag / Resize logic -------------
  final Map<String, double> _resizeAccum = {};

  void _onResizeDrag(Booking b, DragUpdateDetails details) {
    _resizeAccum[b.id] = (_resizeAccum[b.id] ?? 0) + details.delta.dy;
    setState(() {}); // visual feedback minimal (we don't change height inline)
  }

  Future<void> _onResizeEnd(Booking b) async {
    final dy = _resizeAccum.remove(b.id) ?? 0;
    if (dy.abs() < _rowHeight / 2) return;
    final deltaSlots = (dy / _rowHeight).round();
    final addedMinutes = deltaSlots * _slotMinutes;
    final currentDur = 30;
    final newDur = (currentDur + addedMinutes).clamp(_slotMinutes, 480);
    debugPrint('[Planning] Resize booking ${b.id} new duration: $newDur min');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
          'La durata dell\'esame è $currentDur min (configurata sul tipo esame). '
          'Nuova durata richiesta: $newDur min.')),
      );
    }
  }

  double? _calculateLocalY(Offset globalOffset, Room room) {
    // Find render box of the column body to compute local Y
    final ctx = context.findRenderObject() as RenderBox?;
    if (ctx == null) return null;
    final local = ctx.globalToLocal(globalOffset);
    return local.dy;
  }

  Future<void> _moveBooking(Booking booking, Room targetRoom, double localY) async {
    // Snap to nearest slot
    final slotsFromTop = (localY / _rowHeight).round().clamp(0, _timeSlots.length - 1);
    final target = _timeSlots[slotsFromTop];
    debugPrint('[Planning] Move ${booking.id} → room ${targetRoom.name} at ${_formatTime(target)}');

    try {
      final updated = booking.copyWith(
        roomId: targetRoom.id,
        bookingTime: target,
        bookingDate: target,
        updatedAt: DateTime.now(),
      );
      await _bookingService.updateBooking(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
            'Prenotazione spostata in ${targetRoom.name} alle ${_formatTime(target)}')),
        );
      }
      await _reloadBookings();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore spostamento: $e')),
        );
      }
    }
  }

  // ------------- Booking actions -------------
  void _showBookingActions(Booking b, Room room) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(b.examType?.name ?? 'Prenotazione'),
                subtitle: Text(
                    '${_formatDate(b.bookingDate)} ${_formatTime(b.bookingTime)} • ${room.name}'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.swap_horiz_rounded),
                title: const Text('Cambia sala'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _showRoomPicker(b);
                },
              ),
              ListTile(
                leading: const Icon(Icons.close_rounded),
                title: const Text('Chiudi'),
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showRoomPicker(Booking b) async {
    final picked = await showDialog<Room>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Sposta in...'),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final r in _rooms)
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          _parseColor(r.color) ?? Colors.grey,
                    ),
                    title: Text(r.name),
                    subtitle: r.code != null ? Text(r.code!) : null,
                    onTap: () => Navigator.pop(ctx, r),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (picked != null) {
      final updated = b.copyWith(roomId: picked.id, updatedAt: DateTime.now());
      await _bookingService.updateBooking(updated);
      await _reloadBookings();
    }
  }

  // ------------- Room CRUD dialog -------------
  Future<void> _openRoomDialog({Room? room}) async {
    final nameCtrl = TextEditingController(text: room?.name ?? '');
    final codeCtrl = TextEditingController(text: room?.code ?? '');
    final descCtrl = TextEditingController(text: room?.description ?? '');
    String color = room?.color ?? '#3B82F6';

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSt) {
          return AlertDialog(
            title: Text(room == null ? 'Nuova Sala' : 'Modifica Sala'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Nome *', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: codeCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Codice', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Descrizione',
                        border: OutlineInputBorder()),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('Colore: '),
                      const SizedBox(width: 8),
                      for (final c in const [
                        '#3B82F6', '#10B981', '#F59E0B',
                        '#EF4444', '#8B5CF6', '#EC4899', '#14B8A6',
                      ])
                        GestureDetector(
                          onTap: () => setSt(() => color = c),
                          child: Container(
                            width: 28, height: 28,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: _parseColor(c),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: color == c
                                    ? Colors.black
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annulla'),
              ),
              FilledButton(
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty) return;
                  final now = DateTime.now();
                  try {
                    if (room == null) {
                      await _roomService.createRoom(Room(
                        id: '',
                        organizationId: _organization!.id,
                        name: nameCtrl.text.trim(),
                        code: codeCtrl.text.trim().isEmpty
                            ? null
                            : codeCtrl.text.trim(),
                        description: descCtrl.text.trim().isEmpty
                            ? null
                            : descCtrl.text.trim(),
                        color: color,
                        displayOrder: _rooms.length,
                        createdAt: now,
                        updatedAt: now,
                      ));
                    } else {
                      await _roomService.updateRoom(room.copyWith(
                        name: nameCtrl.text.trim(),
                        code: codeCtrl.text.trim().isEmpty
                            ? null
                            : codeCtrl.text.trim(),
                        description: descCtrl.text.trim().isEmpty
                            ? null
                            : descCtrl.text.trim(),
                        color: color,
                        updatedAt: now,
                      ));
                    }
                    if (ctx.mounted) Navigator.pop(ctx, true);
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('Errore: $e')),
                      );
                    }
                  }
                },
                child: const Text('Salva'),
              ),
            ],
          );
        });
      },
    );

    if (saved == true) {
      await _load();
    }
  }

  Future<void> _confirmDeleteRoom(Room room) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminare sala?'),
        content: Text(
            'Vuoi eliminare "${room.name}"? Le prenotazioni e gli slot collegati perderanno il riferimento.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annulla')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await _roomService.deleteRoom(room.id);
        await _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Errore eliminazione: $e')),
          );
        }
      }
    }
  }

  // ------------- Planning configuration dialog -------------
  Future<void> _openConfigDialog() async {
    int startH = _startHour;
    int endH = _endHour;
    int slotM = _slotMinutes;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSt) {
          return AlertDialog(
            title: const Text('Configurazione Planning'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Text('Ora inizio:'),
                      const Spacer(),
                      DropdownButton<int>(
                        value: startH,
                        items: [
                          for (int h = 0; h < 24; h++)
                            DropdownMenuItem(
                              value: h,
                              child: Text('${h.toString().padLeft(2, '0')}:00'),
                            ),
                        ],
                        onChanged: (v) => setSt(() => startH = v ?? startH),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Text('Ora fine:'),
                      const Spacer(),
                      DropdownButton<int>(
                        value: endH,
                        items: [
                          for (int h = 1; h <= 24; h++)
                            DropdownMenuItem(
                              value: h,
                              child: Text('${h.toString().padLeft(2, '0')}:00'),
                            ),
                        ],
                        onChanged: (v) => setSt(() => endH = v ?? endH),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Text('Slot (minuti):'),
                      const Spacer(),
                      DropdownButton<int>(
                        value: slotM,
                        items: const [
                          DropdownMenuItem(value: 5, child: Text('5')),
                          DropdownMenuItem(value: 10, child: Text('10')),
                          DropdownMenuItem(value: 15, child: Text('15')),
                          DropdownMenuItem(value: 20, child: Text('20')),
                          DropdownMenuItem(value: 30, child: Text('30')),
                          DropdownMenuItem(value: 60, child: Text('60')),
                        ],
                        onChanged: (v) => setSt(() => slotM = v ?? slotM),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Annulla')),
              FilledButton(
                onPressed: () async {
                  if (endH <= startH) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text(
                          'L\'ora di fine deve essere maggiore dell\'inizio')),
                    );
                    return;
                  }
                  try {
                    final updated = _organization!.copyWith(
                      planningStartHour: startH,
                      planningEndHour: endH,
                      planningSlotMinutes: slotM,
                      updatedAt: DateTime.now(),
                    );
                    final result = await _orgService.updateOrganization(updated);
                    SupabaseAuthManager.instance
                        .updateCachedOrganization(result.toJson());
                    if (ctx.mounted) Navigator.pop(ctx, true);
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('Errore: $e')),
                      );
                    }
                  }
                },
                child: const Text('Salva'),
              ),
            ],
          );
        });
      },
    );

    if (saved == true) {
      await _load();
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _selectedDate = DateTime(picked.year, picked.month, picked.day));
      await _reloadBookings();
    }
  }

  // ------------- Helpers -------------
  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  String _formatDate(DateTime dt) {
    const months = [
      'Gen', 'Feb', 'Mar', 'Apr', 'Mag', 'Giu',
      'Lug', 'Ago', 'Set', 'Ott', 'Nov', 'Dic'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  Color? _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    var v = hex.replaceAll('#', '');
    if (v.length == 6) v = 'FF$v';
    final n = int.tryParse(v, radix: 16);
    return n == null ? null : Color(n);
  }

  Color _statusColor(BookingStatus s) {
    switch (s) {
      case BookingStatus.confirmed: return const Color(0xFF10B981);
      case BookingStatus.requested: return const Color(0xFFF59E0B);
      case BookingStatus.rejected: return const Color(0xFFEF4444);
      case BookingStatus.cancelled: return Colors.grey;
      case BookingStatus.completed: return const Color(0xFF3B82F6);
    }
  }
}
