import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/event_model.dart';
import 'event_service.dart';
import '../services/friends_service.dart';
import '../data/hobbies.dart';

class EventInvitesScreen extends StatefulWidget {
  final Event event;

  const EventInvitesScreen({
    super.key,
    required this.event,
  });

  @override
  State<EventInvitesScreen> createState() => _EventInvitesScreenState();
}

class _EventInvitesScreenState extends State<EventInvitesScreen> {
  final EventService _eventService = EventService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _allFriends = [];
  List<Map<String, dynamic>> _filteredFriends = [];
  bool _isLoadingFriends = true;
  
  String? _selectedCategory;
  String? _selectedSubcategory;

  @override
  void initState() {
    super.initState();
    _loadFriends();
    _searchController.addListener(_filterFriends);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    try {
      setState(() => _isLoadingFriends = true);
      
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return;

      // Get friends using FriendsService
      final friendsStream = FriendsService.getFriendsStream();
      final friendsSnapshot = await friendsStream.first;
      
      setState(() {
        _allFriends.clear();
        _allFriends.addAll(friendsSnapshot);
        _filterFriends();
      });
      
    } catch (e) {
      print('Error loading friends: $e');
      _loadFriendsFallback();
    } finally {
      if (mounted) {
        setState(() => _isLoadingFriends = false);
      }
    }
  }

  Future<void> _loadFriendsFallback() async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return;

      final friendships = await _firestore
          .collection('friendships')
          .where('userId', isEqualTo: currentUserId)
          .limit(50)
          .get();

      if (friendships.docs.isEmpty) return;

      final friendIds = friendships.docs
          .map((doc) => doc.data()['friendId'] as String)
          .where((id) => id.isNotEmpty)
          .toList();

      if (friendIds.isEmpty) return;

      final List<Map<String, dynamic>> friends = [];
      
      for (int i = 0; i < friendIds.length; i += 10) {
        final batchIds = friendIds.sublist(
          i,
          i + 10 < friendIds.length ? i + 10 : friendIds.length,
        );
        
        final usersSnapshot = await _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: batchIds)
            .get();

        for (final doc in usersSnapshot.docs) {
          friends.add({
            'id': doc.id,
            ...doc.data(),
          });
        }
      }

      setState(() {
        _allFriends.clear();
        _allFriends.addAll(friends);
        _filterFriends();
      });
    } catch (e) {
      print('Error in fallback: $e');
    }
  }

  void _filterFriends() {
    final query = _searchController.text.trim().toLowerCase();
    
    setState(() {
      _filteredFriends = _allFriends.where((friend) {
        final name = (friend['name'] ?? '').toLowerCase();
        final hobbies = friend['hobbies'] ?? [];
        
        // Filter by search query (name)
        final matchesName = query.isEmpty || name.contains(query);
        
        // Filter by selected category/subcategory
        bool matchesCategory = true;
        if (_selectedCategory != null && _selectedSubcategory != null) {
          // Both category and subcategory selected
          final selectedHobby = '$_selectedCategory > $_selectedSubcategory';
          matchesCategory = hobbies.contains(selectedHobby);
        } else if (_selectedCategory != null) {
          // Only category selected - match any hobby that starts with this category
          matchesCategory = hobbies.any((hobby) {
            final parts = hobby.split('>');
            if (parts.length >= 2) {
              return parts[0].trim() == _selectedCategory;
            }
            return false;
          });
        }
        
        return matchesName && matchesCategory;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pozivnice'),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search and filter section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pozovi prijatelja',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700,
                  ),
                ),
                const SizedBox(height: 12),
                
                // Search by name
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Pretrazi po imenu...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Filter by category - FIXED DROPDOWNS
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Kategorija',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Sve kategorije'),
                          ),
                          ...hobbyCategories.keys.map((category) {
                            return DropdownMenuItem(
                              value: category,
                              child: Text(
                                category,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            );
                          }).toList(),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedCategory = value;
                            _selectedSubcategory = null; // Reset subcategory when category changes
                            _filterFriends();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedSubcategory,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Podkategorija',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: _selectedCategory != null
                            ? [
                                const DropdownMenuItem(
                                  value: null,
                                  child: Text('Sve'),
                                ),
                                ...hobbyCategories[_selectedCategory]!.map((sub) {
                                  return DropdownMenuItem(
                                    value: sub,
                                    child: Text(
                                      sub,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  );
                                }).toList(),
                              ]
                            : [
                                const DropdownMenuItem(
                                  value: null,
                                  child: Text('Izaberite kategoriju'),
                                ),
                              ],
                        onChanged: (value) {
                          setState(() {
                            _selectedSubcategory = value;
                            _filterFriends();
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Friends list
          Expanded(
            child: _isLoadingFriends
                ? const Center(child: CircularProgressIndicator())
                : _allFriends.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 50,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Nemate prijatelja',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : _filteredFriends.isEmpty
                        ? Center(
                            child: Text(
                              'Nema prijatelja koji odgovaraju kriterijumima',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _filteredFriends.length,
                            itemBuilder: (context, index) {
                              final friend = _filteredFriends[index];
                              return _buildFriendTile(friend);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendTile(Map<String, dynamic> friend) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: friend['profilePic'] != null &&
                friend['profilePic'].isNotEmpty
            ? NetworkImage(friend['profilePic'])
            : null,
        child: friend['profilePic'] == null || friend['profilePic'].isEmpty
            ? const Icon(Icons.person)
            : null,
      ),
      title: Text(friend['name'] ?? 'Nepoznato'),
      subtitle: Text(
        (friend['hobbies'] ?? []).take(2).join(', '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: Colors.grey[600]),
      ),
      trailing: ElevatedButton(
        onPressed: () => _sendInvite(friend),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange.shade700,
          foregroundColor: Colors.white,
        ),
        child: const Text('Pozovi'),
      ),
    );
  }
  
  Future<void> _sendInvite(Map<String, dynamic> friend) async {
    try {
      await _eventService.sendInvite(
        widget.event.id!,
        friend['id'],
        friend['name'] ?? 'Nepoznato',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Pozivnica poslata korisniku ${friend['name']}')),
        );
        _searchController.clear();
        _selectedCategory = null;
        _selectedSubcategory = null;
        _filterFriends();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Greska: $e')),
        );
      }
    }
  }
}