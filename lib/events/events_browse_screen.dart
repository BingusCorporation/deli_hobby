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

  // Filter state
  String? _selectedCity;
  String? _selectedCategory;

  // User data for ranking
  List<String> _userHobbies = [];
  Map<String, String> _userSkills = {};
  String? _userCity;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
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
          _userSkills = data['hobbySkills'] != null
              ? Map<String, String>.from(data['hobbySkills'])
              : {};
          _userCity = data['city'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
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
        title: const Text('Dogadjaji'),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
        actions: [
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

        if (events.isEmpty) {
          return _buildEmptyState();
        }

        // Rank events based on user profile
        final rankedEvents = _rankingService.rankEvents(
          events: events,
          userHobbies: _userHobbies,
          userSkills: _userSkills,
          userCity: _userCity,
        );

        return RefreshIndicator(
          onRefresh: _loadUserData,
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: rankedEvents.length,
            itemBuilder: (context, index) {
              final rankedEvent = rankedEvents[index];
              return EventCard(
                event: rankedEvent.event,
                matchScore: rankedEvent.scorePercent,
                onTap: () => _navigateToDetails(rankedEvent.event),
              );
            },
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

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
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
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // City filter
                  const Text(
                    'Grad:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        hint: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text('Svi gradovi'),
                        ),
                        value: tempCity,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('Svi gradovi'),
                          ),
                          ...serbiaCities.map((city) {
                            return DropdownMenuItem(
                              value: city,
                              child: Text(city),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          setModalState(() {
                            tempCity = value;
                          });
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Category filter
                  const Text(
                    'Kategorija:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        hint: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text('Sve kategorije'),
                        ),
                        value: tempCategory,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('Sve kategorije'),
                          ),
                          ...hobbyCategories.keys.map((category) {
                            return DropdownMenuItem(
                              value: category,
                              child: Text(category),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          setModalState(() {
                            tempCategory = value;
                          });
                        },
                      ),
                    ),
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
                        });
                        Navigator.pop(context);
                      },
                      child: const Text('Primeni filtere'),
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
