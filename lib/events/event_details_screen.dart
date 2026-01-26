import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/event_model.dart';
import 'event_service.dart';
import 'event_invites_screen.dart';
import 'event_create_screen.dart';
import 'skill_badge.dart';

class EventDetailsScreen extends StatefulWidget {
  final String eventId;

  const EventDetailsScreen({
    super.key,
    required this.eventId,
  });

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  final EventService _eventService = EventService();

  bool _isJoining = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Event?>(
      stream: _eventService.getEventStream(widget.eventId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(
              child: Text('Dogadjaj nije pronadjen'),
            ),
          );
        }

        final event = snapshot.data!;
        final isOrganizer = _eventService.isOrganizer(event);
        final isParticipant = _eventService.isParticipant(event);
        final canJoin = _eventService.canJoin(event);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Detalji dogadjaja'),
            backgroundColor: Colors.orange.shade700,
            foregroundColor: Colors.white,
            actions: [
              if (isOrganizer) ...[
                IconButton(
                  icon: const Icon(Icons.people),
                  onPressed: () => _navigateToInvites(event),
                  tooltip: 'Pozivnice',
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _navigateToEdit(event),
                  tooltip: 'Izmeni',
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'cancel') {
                      _showCancelDialog(event);
                    } else if (value == 'delete') {
                      _showDeleteDialog(event);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'cancel',
                      child: Text('Otkazi dogadjaj'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Obrisi dogadjaj'),
                    ),
                  ],
                ),
              ],
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and status
                _buildHeader(event),
                const SizedBox(height: 16),

                // Date and time
                _buildDateTimeSection(event),
                const SizedBox(height: 16),

                // Location
                _buildLocationSection(event),
                const SizedBox(height: 16),

                // Category and skill
                _buildCategorySection(event),
                const SizedBox(height: 16),

                // Description
                _buildDescriptionSection(event),

                // Schedule
                if (event.schedule.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildScheduleSection(event),
                ],

                // Accessibility
                if (_hasAccessibilityInfo(event)) ...[
                  const SizedBox(height: 16),
                  _buildAccessibilitySection(event),
                ],

                // Participants
                const SizedBox(height: 16),
                _buildParticipantsSection(event),

                // Organizer
                const SizedBox(height: 16),
                _buildOrganizerSection(event),

                const SizedBox(height: 80), // Space for FAB
              ],
            ),
          ),
          floatingActionButton: _buildActionButton(event, isOrganizer, isParticipant, canJoin),
        );
      },
    );
  }

  Widget _buildHeader(Event event) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                event.title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (event.isPrivate)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock, size: 14, color: Colors.purple.shade700),
                    const SizedBox(width: 4),
                    Text(
                      'Privatno',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.purple.shade700,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        if (event.status == 'cancelled') ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.red.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'OTKAZANO',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDateTimeSection(Event event) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.calendar_today, color: Colors.blue),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('EEEE, dd. MMMM yyyy.', 'sr')
                            .format(event.startDateTime),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${DateFormat('HH:mm').format(event.startDateTime)} - ${DateFormat('HH:mm').format(event.endDateTime)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        'Trajanje: ${event.duration} minuta',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (event.isRecurring && event.recurrenceRule != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.repeat, size: 14, color: Colors.blue.shade700),
                    const SizedBox(width: 4),
                    Text(
                      event.recurrenceRule!.getDisplayText(),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSection(Event event) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.location_on, color: Colors.red),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.city,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    event.address,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  if (event.locationDetails != null &&
                      event.locationDetails!.isNotEmpty)
                    Text(
                      event.locationDetails!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[500],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySection(Event event) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Kategorija',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      event.hobby,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Potreban nivo',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                event.requiredSkillLevel == 'any'
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Svi nivoi',
                          style: TextStyle(fontSize: 14),
                        ),
                      )
                    : SkillBadge(
                        skillLevel: event.requiredSkillLevel,
                        showLabel: true,
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionSection(Event event) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Opis',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              event.description,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleSection(Event event) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Raspored aktivnosti',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...event.schedule.map((item) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item.time,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(item.activity),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  bool _hasAccessibilityInfo(Event event) {
    return event.accessibility.wheelchairAccessible ||
        event.accessibility.hearingAssistance ||
        event.accessibility.visualAssistance ||
        (event.accessibility.notes != null &&
            event.accessibility.notes!.isNotEmpty);
  }

  Widget _buildAccessibilitySection(Event event) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.accessible, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  'Pristupacnost',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (event.accessibility.wheelchairAccessible)
                  _buildAccessibilityChip('Pristup za kolica', Icons.accessible),
                if (event.accessibility.hearingAssistance)
                  _buildAccessibilityChip('Pomoc za sluh', Icons.hearing),
                if (event.accessibility.visualAssistance)
                  _buildAccessibilityChip('Pomoc za vid', Icons.visibility),
              ],
            ),
            if (event.accessibility.notes != null &&
                event.accessibility.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                event.accessibility.notes!,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAccessibilityChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.green.shade700),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.green.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantsSection(Event event) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.people, color: Colors.orange),
                const SizedBox(width: 8),
                const Text(
                  'Ucesnici',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: event.isFull
                        ? Colors.red.shade100
                        : Colors.green.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${event.currentParticipants}/${event.maxParticipants}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: event.isFull ? Colors.red : Colors.green,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (event.isFull)
              Text(
                'Sva mesta su popunjena',
                style: TextStyle(color: Colors.red[700]),
              )
            else
              Text(
                'Preostalo mesta: ${event.spotsLeft}',
                style: TextStyle(color: Colors.grey[600]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrganizerSection(Event event) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.grey[300],
              child: const Icon(Icons.person),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Organizator',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  Text(
                    event.organizerName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _buildActionButton(
    Event event,
    bool isOrganizer,
    bool isParticipant,
    bool canJoin,
  ) {
    if (event.status == 'cancelled') return null;
    if (isOrganizer) return null;

    if (isParticipant) {
      return FloatingActionButton.extended(
        onPressed: () => _showLeaveDialog(event),
        backgroundColor: Colors.red,
        icon: const Icon(Icons.exit_to_app),
        label: const Text('Napusti'),
      );
    }

    if (canJoin) {
      return FloatingActionButton.extended(
        onPressed: _isJoining ? null : () => _joinEvent(event),
        icon: _isJoining
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.add),
        label: Text(_isJoining ? 'Prijavljivanje...' : 'Pridruzi se'),
      );
    }

    if (event.isFull) {
      return FloatingActionButton.extended(
        onPressed: null,
        backgroundColor: Colors.grey,
        icon: const Icon(Icons.block),
        label: const Text('Popunjeno'),
      );
    }

    return null;
  }

  Future<void> _joinEvent(Event event) async {
    setState(() {
      _isJoining = true;
    });

    try {
      await _eventService.joinEvent(event.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Uspesno si se prijavio!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Greska: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isJoining = false;
        });
      }
    }
  }

  void _showLeaveDialog(Event event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Napusti dogadjaj'),
        content: const Text('Da li si siguran da zelis da napustis ovaj dogadjaj?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Odustani'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _eventService.leaveEvent(event.id!);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Napustio si dogadjaj')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Greska: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Napusti'),
          ),
        ],
      ),
    );
  }

  void _showCancelDialog(Event event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Otkazi dogadjaj'),
        content: const Text(
          'Da li si siguran da zelis da otkazis ovaj dogadjaj? Svi ucesnici ce biti obavesteni.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Odustani'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _eventService.cancelEvent(event.id!);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Dogadjaj je otkazan')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Greska: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Otkazi'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(Event event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Obrisi dogadjaj'),
        content: const Text(
          'Da li si siguran da zelis da obrises ovaj dogadjaj? Ova akcija se ne moze ponistiti.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Odustani'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _eventService.deleteEvent(event.id!);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Dogadjaj je obrisan')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Greska: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Obrisi'),
          ),
        ],
      ),
    );
  }

  void _navigateToEdit(Event event) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EventCreateScreen(eventToEdit: event),
      ),
    );
  }

  void _navigateToInvites(Event event) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EventInvitesScreen(event: event),
      ),
    );
  }
}
