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


  String? _selectedCity;
  String? _selectedCategory;
  String? _selectedSubcategory;
  String? _selectedSkillLevel;
  bool? _wheelchairAccessible;
  bool? _hearingAssistance;
  bool? _visualAssistance;
  bool? _onlyWithFriends;


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
        title: Container(
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Pretraži događaje...',
              hintStyle: const TextStyle(color: Colors.white70),
              border: InputBorder.none,
              prefixIcon: const Icon(Icons.search, color: Colors.white70),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white70),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    )
                  : null,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(Icons.my_library_books),
              color: Colors.white,
              tooltip: 'Moji događaji',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MyEventsScreen()),
                );
              },
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(Icons.filter_list),
              color: Colors.white,
              onPressed: _showFilterDialog,
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.orange.shade50,
              Colors.white,
            ],
            stops: const [0.0, 0.3],
          ),
        ),
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: Colors.orange.shade700,
                ),
              )
            : _buildEventsList(),
      ),
      floatingActionButton: Container(
        margin: const EdgeInsets.only(bottom: 16, right: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.orange.shade400,
              Colors.orange.shade600,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.shade400.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton(
          heroTag: 'events_browse_fab',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const EventCreateScreen(),
              ),
            );
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
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
          return Center(
            child: CircularProgressIndicator(
              color: Colors.orange.shade700,
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error,
                  color: Colors.orange.shade700,
                  size: 60,
                ),
                const SizedBox(height: 16),
                Text(
                  'Greška: ${snapshot.error}',
                  style: const TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final events = snapshot.data ?? [];


        final filteredEvents = events.where((event) {

          final searchQuery = _searchController.text.toLowerCase();
          if (searchQuery.isNotEmpty) {
            final matchesTitle = event.title.toLowerCase().contains(searchQuery);
            final matchesDescription = event.description.toLowerCase().contains(searchQuery);
            if (!matchesTitle && !matchesDescription) {
              return false;
            }
          }


          if (_selectedSubcategory != null) {
            final selectedHobby = '$_selectedCategory > $_selectedSubcategory';
            if (!event.hobbies.contains(selectedHobby)) {
              return false;
            }
          }


          if (_selectedSkillLevel != null && _selectedSkillLevel != 'any') {
            if (event.requiredSkillLevel != _selectedSkillLevel) {
              return false;
            }
          }


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

        final rankedEvents = _rankingService.rankEvents(
          events: filteredEvents,
          userHobbies: _userHobbies,
          userCity: _userCity,
        );

        return RefreshIndicator(
          onRefresh: _loadUserData,
          color: Colors.orange.shade700,
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
          Icon(
            Icons.event_busy,
            size: 60,
            color: Colors.orange.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'Nema događaja',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedCity != null || _selectedCategory != null
                ? 'Pokušaj sa drugim filterima'
                : 'Budi prvi koji će kreirati događaj!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          if (_selectedCity != null || _selectedCategory != null) ...[
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedCity = null;
                  _selectedCategory = null;
                  _selectedSubcategory = null;
                  _selectedSkillLevel = null;
                  _wheelchairAccessible = null;
                  _hearingAssistance = null;
                  _visualAssistance = null;
                  _onlyWithFriends = null;
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
      backgroundColor: Colors.transparent,
      builder: (context) {
        String? tempCity = _selectedCity;
        String? tempCategory = _selectedCategory;
        String? tempSubcategory = _selectedSubcategory;
        String? tempSkillLevel = _selectedSkillLevel;
        bool? tempWheelchair = _wheelchairAccessible;
        bool? tempHearing = _hearingAssistance;
        bool? tempVisual = _visualAssistance;
        bool? tempOnlyWithFriends = _onlyWithFriends;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(25),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.shade200.withOpacity(0.5),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: StatefulBuilder(
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
                      Center(
                        child: Container(
                          width: 40,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.orange.shade300,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Filteri',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade800,
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
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.orange.shade600,
                                ),
                                child: const Text('Obriši sve'),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.close,
                                  color: Colors.orange.shade600,
                                ),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      Text(
                        'Lokacija:',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade800,
                        ),
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

                      Text(
                        'Kategorija hobija:',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildDropdown(
                        value: tempCategory,
                        hint: 'Sve kategorije',
                        items: hobbyCategories.keys.toList(),
                        onChanged: (value) {
                          setModalState(() {
                            tempCategory = value;
                            tempSubcategory = null;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      if (tempCategory != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Podkategorija hobija:',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.orange.shade800,
                              ),
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

                      Text(
                        'Nivo veštine:',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildDropdown(
                        value: tempSkillLevel,
                        hint: 'Svi nivoi',
                        items: const ['beginner', 'intermediate', 'advanced', 'any'],
                        displayNames: const ['Početnik', 'Srednji', 'Napredni', 'Svi nivoi'],
                        onChanged: (value) {
                          setModalState(() => tempSkillLevel = value);
                        },
                      ),
                      const SizedBox(height: 16),

                      Text(
                        'Dostupnost:',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade800,
                        ),
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
                        label: 'Pomoć za ljude sa oštećenjem sluha',
                        value: tempHearing,
                        onChanged: (value) {
                          setModalState(() => tempHearing = value);
                        },
                      ),
                      _buildCheckbox(
                        label: 'Pomoć za ljude sa oštećenjem vida',
                        value: tempVisual,
                        onChanged: (value) {
                          setModalState(() => tempVisual = value);
                        },
                      ),
                      const SizedBox(height: 16),

                      _buildCheckbox(
                        label: 'Samo događaji sa prijateljima',
                        value: tempOnlyWithFriends,
                        onChanged: (value) {
                          setModalState(() => tempOnlyWithFriends = value);
                        },
                      ),
                      const SizedBox(height: 24),

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
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 3,
                            shadowColor: Colors.orange.shade400,
                          ),
                          child: const Text(
                            'Primeni filtere',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildDropdown({
    required String? value,
    required String hint,
    required List<String> items,
    List<String>? displayNames,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.orange.shade200,
          width: 2,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          hint: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              hint,
              style: TextStyle(color: Colors.orange.shade600),
            ),
          ),
          value: value,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          dropdownColor: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          icon: Icon(
            Icons.arrow_drop_down,
            color: Colors.orange.shade600,
          ),
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Text(
                hint,
                style: TextStyle(color: Colors.orange.shade600),
              ),
            ),
            ...items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final displayName = displayNames != null && index < displayNames.length
                  ? displayNames[index]
                  : item;
              
              return DropdownMenuItem(
                value: item,
                child: Text(
                  displayName,
                  style: TextStyle(
                    color: Colors.orange.shade800,
                  ),
                ),
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
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.orange.shade200,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: value == null 
                        ? Colors.orange.shade300 
                        : Colors.orange.shade700,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(6),
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
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.orange.shade800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
        eagerError: false,
      );

      _friendCountCache.addAll(friendCounts);

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
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              color: Colors.orange.shade700,
            ),
          );
        }

        final events = snapshot.data ?? widget.rankedEvents;

        if (events.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off,
                  size: 60,
                  color: Colors.orange.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  'Nema rezultata',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: events.length,
          itemBuilder: (context, index) {
            final rankedEvent = events[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: EventCard(
                event: rankedEvent.event,
                matchScore: rankedEvent.scorePercent,
                onTap: () => widget.onEventTap(rankedEvent.event),
                friendsParticipating:
                    rankedEvent.friendsParticipating > 0
                        ? rankedEvent.friendsParticipating
                        : null,
              ),
            );
          },
        );
      },
    );
  }
}