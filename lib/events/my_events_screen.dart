import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/event_model.dart';
import 'event_service.dart';
import 'event_card.dart';
import 'event_details_screen.dart';
import 'event_create_screen.dart';

class MyEventsScreen extends StatefulWidget {
  const MyEventsScreen({super.key});

  @override
  State<MyEventsScreen> createState() => _MyEventsScreenState();
}

class _MyEventsScreenState extends State<MyEventsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final EventService _eventService = EventService();
  
  // Calendar state
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  final Map<DateTime, List<Event>> _allEventsByDate = {};
  List<Event> _selectedDayEvents = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _focusedDay = DateTime.now();
    _selectedDay = DateTime.now();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Moji dogadjaji'),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Organizujem'),
            Tab(text: 'Ucestvujem'),
            Tab(text: 'Kalendar'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOrganizedEvents(),
          _buildParticipatingEvents(),
          _buildCalendarView(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'my_events_fab',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const EventCreateScreen(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildOrganizedEvents() {
    return StreamBuilder<List<Event>>(
      stream: _eventService.getMyOrganizedEvents(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Greska: ${snapshot.error}'));
        }

        final events = snapshot.data ?? [];

        if (events.isEmpty) {
          return _buildEmptyState(
            icon: Icons.event_available,
            title: 'Nemas organizovanih dogadjaja',
            subtitle: 'Kreiraj svoj prvi dogadjaj!',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: events.length,
          itemBuilder: (context, index) {
            final event = events[index];
            return EventCard(
              event: event,
              showOrganizer: false,
              onTap: () => _navigateToDetails(event),
            );
          },
        );
      },
    );
  }

  Widget _buildParticipatingEvents() {
    return StreamBuilder<List<Event>>(
      stream: _eventService.getMyParticipatingEvents(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Greska: ${snapshot.error}'));
        }

        final events = snapshot.data ?? [];

        if (events.isEmpty) {
          return _buildEmptyState(
            icon: Icons.people_outline,
            title: 'Nisi prijavljen ni na jedan dogadjaj',
            subtitle: 'Pretrazi dogadjaje i pridruzi se!',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: events.length,
          itemBuilder: (context, index) {
            final event = events[index];
            return EventCard(
              event: event,
              onTap: () => _navigateToDetails(event),
            );
          },
        );
      },
    );
  }

  Widget _buildCalendarView() {
  return StreamBuilder<List<Event>>(
    stream: _eventService.getMyParticipatingEvents(),
    builder: (context, participatingSnapshot) {
      if (participatingSnapshot.connectionState == ConnectionState.waiting) {
        return Center(
          child: CircularProgressIndicator(
            color: Colors.orange.shade700,
          ),
        );
      }

      final participatingEvents = participatingSnapshot.data ?? [];

      // Also stream organizing events
      return StreamBuilder<List<Event>>(
        stream: _eventService.getMyOrganizedEvents(),
        builder: (context, organizingSnapshot) {
          if (organizingSnapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                color: Colors.orange.shade700,
              ),
            );
          }

          final organizingEvents = organizingSnapshot.data ?? [];
          final allEvents = [...participatingEvents, ...organizingEvents];

          if (allEvents.isEmpty) {
            return _buildEmptyState(
              icon: Icons.calendar_today,
              title: 'Nema dogadjaja',
              subtitle: 'Organizuj ili se pridruži dogadjajima!',
            );
          }

          // Build map of all events by date - FIXED: Use a clean date without time
          final eventsByDate = <DateTime, List<Event>>{};

          for (final event in allEvents) {
            // Create a clean date without time for grouping
            final cleanDate = DateTime(
              event.startDateTime.year,
              event.startDateTime.month,
              event.startDateTime.day,
            );
            
            // Use the same DateTime object for key and lookup
            eventsByDate[cleanDate] = [
              ...eventsByDate[cleanDate] ?? [],
              event
            ];
          }

          // Get events for selected day
          final selectedDateKey = DateTime(
            _selectedDay.year,
            _selectedDay.month,
            _selectedDay.day,
          );
          final selectedDayEvents = eventsByDate[selectedDateKey] ?? [];

          return Column(
            children: [
              // Calendar
              Card(
                margin: const EdgeInsets.all(12),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.orange.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: TableCalendar<Event>(
                    firstDay: DateTime.now().subtract(const Duration(days: 365)),
                    lastDay: DateTime.now().add(const Duration(days: 365)),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                    },
                    onPageChanged: (focusedDay) {
                      setState(() {
                        _focusedDay = focusedDay;
                      });
                    },
                    eventLoader: (day) {
                      // Create clean date for lookup
                      final cleanDay = DateTime(day.year, day.month, day.day);
                      return eventsByDate[cleanDay] ?? [];
                    },
                    calendarBuilders: CalendarBuilders(
                      markerBuilder: (context, day, events) {
                        if (events.isEmpty) return null;
                        
                        final cleanDay = DateTime(day.year, day.month, day.day);
                        final dayEvents = eventsByDate[cleanDay] ?? [];
                        
                        if (dayEvents.isEmpty) return null;

                        // Check if there are participating or organizing events
                        final hasParticipating = dayEvents.any((event) =>
                          participatingEvents.any((e) => e.id == event.id)
                        );
                        final hasOrganizing = dayEvents.any((event) =>
                          organizingEvents.any((e) => e.id == event.id)
                        );

                        return Positioned(
                          right: 1,
                          bottom: 1,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (hasParticipating)
                                Container(
                                  width: 6,
                                  height: 6,
                                  margin: const EdgeInsets.symmetric(horizontal: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade600,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              if (hasOrganizing)
                                Container(
                                  width: 6,
                                  height: 6,
                                  margin: const EdgeInsets.symmetric(horizontal: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade600,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                    calendarStyle: CalendarStyle(
                      outsideDaysVisible: false,
                      selectedDecoration: BoxDecoration(
                        color: Colors.orange.shade700,
                        shape: BoxShape.circle,
                      ),
                      todayDecoration: BoxDecoration(
                        color: Colors.orange.shade300,
                        shape: BoxShape.circle,
                      ),
                      markerDecoration: BoxDecoration(
                        color: Colors.orange.shade700,
                        shape: BoxShape.circle,
                      ),
                      markersAlignment: Alignment.bottomCenter,
                      markersMaxCount: 2,
                      markerSize: 6,
                      markerMargin: const EdgeInsets.symmetric(horizontal: 1),
                    ),
                    headerStyle: HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                      titleTextStyle: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade800,
                      ),
                      leftChevronIcon: Icon(
                        Icons.chevron_left,
                        color: Colors.orange.shade700,
                        size: 28,
                      ),
                      rightChevronIcon: Icon(
                        Icons.chevron_right,
                        color: Colors.orange.shade700,
                        size: 28,
                      ),
                      headerPadding: const EdgeInsets.symmetric(vertical: 8),
                      leftChevronMargin: const EdgeInsets.only(left: 8),
                      rightChevronMargin: const EdgeInsets.only(right: 8),
                    ),
                    daysOfWeekStyle: DaysOfWeekStyle(
                      weekdayStyle: TextStyle(
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                      weekendStyle: TextStyle(
                        color: Colors.red.shade600,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    startingDayOfWeek: StartingDayOfWeek.monday,
                  ),
                ),
              ),

              // Legend
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.blue.shade600,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Učestvujem',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.green.shade600,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Organizujem',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Selected day info
              if (selectedDayEvents.isNotEmpty)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.event, size: 18, color: Colors.orange.shade700),
                      const SizedBox(width: 8),
                      Text(
                        '${selectedDayEvents.length} dogadjaj${selectedDayEvents.length != 1 ? 'a' : ''} na ovaj dan',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.orange.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

              // Events list for selected day
              Expanded(
                child: selectedDayEvents.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.event_note,
                                size: 50,
                                color: Colors.orange.shade300,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Nema dogadjaja na ovaj dan',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.orange.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        itemCount: selectedDayEvents.length,
                        itemBuilder: (context, index) {
                          final event = selectedDayEvents[index];
                          return EventCard(
                            event: event,
                            onTap: () => _navigateToDetails(event),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      );
    },
  );
}

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 60, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToDetails(Event event) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EventDetailsScreen(eventId: event.id!),
      ),
    );
  }
}
