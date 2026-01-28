import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/hobbies.dart';
import '../data/city.dart';
import '../models/event_model.dart';
import 'event_service.dart';
import 'event_ranking_service.dart';
import 'event_card.dart';
import 'event_details_screen.dart';
import 'event_create_screen.dart';
import 'my_events_screen.dart';

class EventsBrowseScreen extends StatefulWidget {
  const EventsBrowseScreen({super.key});

  @override
  State<EventsBrowseScreen> createState() => _EventsBrowseScreenState();
}

class _EventsBrowseScreenState extends State<EventsBrowseScreen> {
  final EventService _eventService = EventService();
  final EventRankingService _rankingService = EventRankingService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _searchController = TextEditingController();

  // Filter state
  String? _selectedCity;
  String? _selectedCategory;
  String? _selectedSubcategory;
  String? _selectedSkillLevel;
  bool? _wheelchairAccessible;
  bool? _hearingAssistance;
  bool? _visualAssistance;
  bool? _onlyWithFriends;

  // User data for ranking
  List<String> _userHobbies = [];
  String? _userCity;
  Set<String> _userFriends = {};

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      final doc = await _firestore.collection('users_private').doc(uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _userHobbies = data['hobbies'] != null
              ? List<String>.from(data['hobbies'])
              : [];
          _userCity = data['city'];
        });
      }

      // Load user's friends
      final friendships = await _firestore
          .collection('friendships')
          .where('userId', isEqualTo: uid)
          .get();
      
      final friendIds = <String>{};
      for (var doc in friendships.docs) {
        final friendId = doc['friendId'] as String?;
        if (friendId != null) {
          friendIds.add(friendId);
        }
      }

      setState(() {
        _userFriends = friendIds;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Pretrazi dogadjaje...',
            hintStyle: TextStyle(color: Colors.white70),
            border: InputBorder.none,
            prefixIcon: Icon(Icons.search, color: Colors.white70),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white70),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                  )
                : null,
          ),
          onChanged: (_) => setState(() {}),
        ),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_library_books),
            tooltip: 'Moji dogadjaji',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MyEventsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildEventsList(),
      floatingActionButton: FloatingActionButton(
        heroTag: 'events_browse_fab',
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

  Widget _buildEventsList() {
    return StreamBuilder<List<Event>>(
      stream: _eventService.getPublicEvents(
        city: _selectedCity,
        category: _selectedCategory,
        startAfter: DateTime.now(),
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Greska: ${snapshot.error}'),
          );
        }

        final events = snapshot.data ?? [];

        // Apply client-side filters
        final filteredEvents = events.where((event) {
          // Search filter
          final searchQuery = _searchController.text.toLowerCase();
          if (searchQuery.isNotEmpty) {
            final matchesTitle = event.title.toLowerCase().contains(searchQuery);
            final matchesDescription = event.description.toLowerCase().contains(searchQuery);
            if (!matchesTitle && !matchesDescription) {
              return false;
            }
          }

          // Subcategory filter
          if (_selectedSubcategory != null) {
            final selectedHobby = '$_selectedCategory > $_selectedSubcategory';
            if (!event.hobbies.contains(selectedHobby)) {
              return false;
            }
          }

          // Skill level filter
          if (_selectedSkillLevel != null && _selectedSkillLevel != 'any') {
            if (event.requiredSkillLevel != _selectedSkillLevel) {
              return false;
            }
          }

          // Accessibility filters
          if (_wheelchairAccessible == true &&
              !event.accessibility.wheelchairAccessible) {
            return false;
          }
          if (_hearingAssistance == true && !event.accessibility.hearingAssistance) {
            return false;
          }
          if (_visualAssistance == true && !event.accessibility.visualAssistance) {
            return false;
          }

          // Friends filter
          if (_onlyWithFriends == true) {
            final hasFriends =
                event.participants.any((p) => _userFriends.contains(p));
            if (!hasFriends) {
              return false;
            }
          }

          return true;
        }).toList();

        if (filteredEvents.isEmpty) {
          return _buildEmptyState();
        }

        // Rank events based on user profile
        final rankedEvents = _rankingService.rankEvents(
          events: filteredEvents,
          userHobbies: _userHobbies,
          userCity: _userCity,
        );

        return RefreshIndicator(
          onRefresh: _loadUserData,
          child: _EventsListWithFriendPriority(
            rankedEvents: rankedEvents,
            eventService: _eventService,
            onEventTap: _navigateToDetails,
            userFriends: _userFriends,
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy, size: 60, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Nema dogadjaja',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedCity != null || _selectedCategory != null
                ? 'Pokusaj sa drugim filterima'
                : 'Budi prvi koji ce kreirati dogadjaj!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          if (_selectedCity != null || _selectedCategory != null) ...[
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedCity = null;
                  _selectedCategory = null;
                });
              },
              child: const Text('Ukloni filtere'),
            ),
          ],
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

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        String? tempCity = _selectedCity;
        String? tempCategory = _selectedCategory;
        String? tempSubcategory = _selectedSubcategory;
        String? tempSkillLevel = _selectedSkillLevel;
        bool? tempWheelchair = _wheelchairAccessible;
        bool? tempHearing = _hearingAssistance;
        bool? tempVisual = _visualAssistance;
        bool? tempOnlyWithFriends = _onlyWithFriends;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  left: 16,
                  right: 16,
                  top: 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Filteri',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () {
                                setModalState(() {
                                  tempCity = null;
                                  tempCategory = null;
                                  tempSubcategory = null;
                                  tempSkillLevel = null;
                                  tempWheelchair = null;
                                  tempHearing = null;
                                  tempVisual = null;
                                  tempOnlyWithFriends = null;
                                });
                              },
                              child: const Text('Obriši sve'),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Location filter
                    const Text(
                      'Lokacija:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    _buildDropdown(
                      value: tempCity,
                      hint: 'Svi gradovi',
                      items: serbiaCities,
                      onChanged: (value) {
                        setModalState(() => tempCity = value);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Hobby category filter
                    const Text(
                      'Kategorija hobija:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    _buildDropdown(
                      value: tempCategory,
                      hint: 'Sve kategorije',
                      items: hobbyCategories.keys.toList(),
                      onChanged: (value) {
                        setModalState(() {
                          tempCategory = value;
                          tempSubcategory = null; // Reset subcategory
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Hobby subcategory filter
                    if (tempCategory != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Podkategorija hobija:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          _buildDropdown(
                            value: tempSubcategory,
                            hint: 'Sve podkategorije',
                            items: hobbyCategories[tempCategory] ?? [],
                            onChanged: (value) {
                              setModalState(() => tempSubcategory = value);
                            },
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),

                    // Skill level filter
                    const Text(
                      'Nivo veštine:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    _buildDropdown(
                      value: tempSkillLevel,
                      hint: 'Svi nivoi',
                      items: const ['beginner', 'intermediate', 'advanced', 'any'],
                      onChanged: (value) {
                        setModalState(() => tempSkillLevel = value);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Accessibility filters
                    const Text(
                      'Dostupnost:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    _buildCheckbox(
                      label: 'Dostupno za invalidska kolica',
                      value: tempWheelchair,
                      onChanged: (value) {
                        setModalState(() => tempWheelchair = value);
                      },
                    ),
                    _buildCheckbox(
                      label: 'Pomoć za čujuće',
                      value: tempHearing,
                      onChanged: (value) {
                        setModalState(() => tempHearing = value);
                      },
                    ),
                    _buildCheckbox(
                      label: 'Pomoć za vidne',
                      value: tempVisual,
                      onChanged: (value) {
                        setModalState(() => tempVisual = value);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Friends filter
                    _buildCheckbox(
                      label: 'Samo dogadjaji sa prijateljima',
                      value: tempOnlyWithFriends,
                      onChanged: (value) {
                        setModalState(() => tempOnlyWithFriends = value);
                      },
                    ),
                    const SizedBox(height: 24),

                    // Apply button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _selectedCity = tempCity;
                            _selectedCategory = tempCategory;
                            _selectedSubcategory = tempSubcategory;
                            _selectedSkillLevel = tempSkillLevel;
                            _wheelchairAccessible = tempWheelchair;
                            _hearingAssistance = tempHearing;
                            _visualAssistance = tempVisual;
                            _onlyWithFriends = tempOnlyWithFriends;
                          });
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Primeni filtere'),
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDropdown({
    required String? value,
    required String hint,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          hint: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(hint),
          ),
          value: value,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Text(hint),
            ),
            ...items.map((item) {
              return DropdownMenuItem(
                value: item,
                child: Text(item),
              );
            }),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildCheckbox({
    required String label,
    required bool? value,
    required ValueChanged<bool?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () {
          // Cycle through null -> true -> false -> null
          bool? newValue;
          if (value == null) {
            newValue = true;
          } else if (value == true) {
            newValue = false;
          } else {
            newValue = null;
          }
          onChanged(newValue);
        },
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                border: Border.all(
                  color: value == null ? Colors.grey : Colors.orange.shade700,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(4),
                color: value == true ? Colors.orange.shade700 : null,
              ),
              child: value == true
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : value == false
                      ? Icon(Icons.close, size: 16, color: Colors.orange.shade700)
                      : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget that loads friend counts for all events and applies friend-based sorting
class _EventsListWithFriendPriority extends StatefulWidget {
  final List<RankedEvent> rankedEvents;
  final EventService eventService;
  final Function(Event) onEventTap;
  final Set<String> userFriends;

  const _EventsListWithFriendPriority({
    required this.rankedEvents,
    required this.eventService,
    required this.onEventTap,
    required this.userFriends,
  });

  @override
  State<_EventsListWithFriendPriority> createState() =>
      _EventsListWithFriendPriorityState();
}

class _EventsListWithFriendPriorityState
    extends State<_EventsListWithFriendPriority> {
  late Future<List<RankedEvent>> _eventsFuture;
  final Map<String, int> _friendCountCache = {};

  @override
  void initState() {
    super.initState();
    _eventsFuture = _loadFriendCountsAndSort();
  }

  Future<List<RankedEvent>> _loadFriendCountsAndSort() async {
    try {
      final friendCounts = <String, int>{};
      
      // Load friend counts in parallel for efficiency
      await Future.wait(
        widget.rankedEvents.map((rankedEvent) async {
          try {
            final count =
                await widget.eventService.getMyFriendsParticipatingCount(
              rankedEvent.event.id!,
            );
            friendCounts[rankedEvent.event.id!] = count;
          } catch (e) {
            print('Error loading friend count: $e');
            friendCounts[rankedEvent.event.id!] = 0;
          }
        }),
        eagerError: false, // Continue even if some fail
      );

      _friendCountCache.addAll(friendCounts);

      // Apply friend-based sorting
      final rankingService = EventRankingService();
      final sorted = rankingService.rankEventsWithFriends(
        rankedEvents: widget.rankedEvents,
        friendCountsByEventId: friendCounts,
      );

      return sorted;
    } catch (e) {
      print('Error in _loadFriendCountsAndSort: $e');
      return widget.rankedEvents;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<RankedEvent>>(
      future: _eventsFuture,
      builder: (context, snapshot) {
        final events = snapshot.data ?? widget.rankedEvents;

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: events.length,
          itemBuilder: (context, index) {
            final rankedEvent = events[index];
            return EventCard(
              event: rankedEvent.event,
              matchScore: rankedEvent.scorePercent,
              onTap: () => widget.onEventTap(rankedEvent.event),
              friendsParticipating:
                  rankedEvent.friendsParticipating > 0
                      ? rankedEvent.friendsParticipating
                      : null,
            );
          },
        );
      },
    );
  }
}
