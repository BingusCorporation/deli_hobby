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

  final List<Map<String, dynamic>> _allFriends = [];
  List<Map<String, dynamic>> _filteredFriends = [];
  bool _isLoadingFriends = true;
  bool _isSendingInvites = false;
  
  String? _selectedCategory;
  String? _selectedSubcategory;
  
  // Track selected friends across filter changes
  final Set<String> _selectedFriendIds = {};
  
  // Cache for pending invites
  final Set<String> _pendingInvites = {};

  @override
  void initState() {
    super.initState();
    _loadFriends();
    _loadPendingInvites();
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

  Future<void> _loadPendingInvites() async {
    try {
      final invitesSnapshot = await _firestore
          .collection('events')
          .doc(widget.event.id)
          .collection('invites')
          .where('status', isEqualTo: 'pending')
          .get();

      setState(() {
        _pendingInvites.clear();
        _pendingInvites.addAll(
          invitesSnapshot.docs.map((doc) => doc['inviteeId'] as String),
        );
      });
    } catch (e) {
      print('Error loading pending invites: $e');
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
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filtriraj po hobijima',
            onPressed: () => _showFilterDialog(),
          ),
        ],
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
                  'Odaberi prijatelje',
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
                
                // Filter display
                if (_selectedCategory != null || _selectedSubcategory != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Filter: ${_selectedSubcategory != null ? '$_selectedCategory > $_selectedSubcategory' : _selectedCategory}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _selectedCategory = null;
                              _selectedSubcategory = null;
                              _filterFriends();
                            });
                          },
                          icon: Icon(Icons.close, size: 18, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                
                // Show selection count
                if (_selectedFriendIds.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'Odabrano: ${_selectedFriendIds.length}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
      bottomNavigationBar: _selectedFriendIds.isNotEmpty
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSendingInvites ? null : _sendSelectedInvites,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade700,
                    disabledBackgroundColor: Colors.grey.shade400,
                  ),
                  child: _isSendingInvites
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : Text(
                          'Pošalji pozivnice (${_selectedFriendIds.length})',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            )
          : null,
    );
  }

  void _showFilterDialog() {
    String? tempCategory = _selectedCategory;
    String? tempSubcategory = _selectedSubcategory;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filtriraj po hobijima',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: tempCategory,
                    decoration: InputDecoration(
                      labelText: 'Kategorija',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    items: [
                      const DropdownMenuItem(
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
                      setState(() {
                        tempCategory = value;
                        tempSubcategory = null;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  if (tempCategory != null &&
                      hobbyCategories[tempCategory] != null &&
                      hobbyCategories[tempCategory]!.isNotEmpty)
                    DropdownButtonFormField<String>(
                      initialValue: tempSubcategory,
                      decoration: InputDecoration(
                        labelText: 'Podkategorija (opciono)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Sve podkategorije'),
                        ),
                        ...hobbyCategories[tempCategory]!.map((sub) {
                          return DropdownMenuItem(
                            value: sub,
                            child: Text(sub),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() {
                          tempSubcategory = value;
                        });
                      },
                    ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () {
                          setState(() {
                            tempCategory = null;
                            tempSubcategory = null;
                          });
                        },
                        child: const Text('Obriši filter'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          this.setState(() {
                            _selectedCategory = tempCategory;
                            _selectedSubcategory = tempSubcategory;
                            _filterFriends();
                          });
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade700,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Primeni'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFriendTile(Map<String, dynamic> friend) {
    final friendId = friend['id'];
    final isAlreadyInvited = _isUserAlreadyInvited(friendId);
    final isAlreadyParticipant = widget.event.participants.contains(friendId);
    final isDisabled = isAlreadyInvited || isAlreadyParticipant;
    final isSelected = _selectedFriendIds.contains(friendId) && !isDisabled;

    String statusLabel = '';
    if (isAlreadyParticipant) {
      statusLabel = 'Korisnik već prijavljen';
    } else if (isAlreadyInvited) {
      statusLabel = 'Korisnik već pozvan';
    }

    return ListTile(
      enabled: !isDisabled,
      leading: Checkbox(
        value: isSelected,
        onChanged: isDisabled
            ? null
            : (value) {
                setState(() {
                  if (value == true) {
                    _selectedFriendIds.add(friendId);
                  } else {
                    _selectedFriendIds.remove(friendId);
                  }
                });
              },
      ),
      title: Text(
        friend['name'] ?? 'Nepoznato',
        style: TextStyle(
          color: isDisabled ? Colors.grey : Colors.black,
        ),
      ),
      subtitle: isDisabled
          ? Text(
              statusLabel,
              style: TextStyle(
                color: Colors.orange.shade700,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            )
          : Text(
              (friend['hobbies'] ?? []).take(2).join(', '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey[600]),
            ),
      trailing: CircleAvatar(
        backgroundImage: friend['profilePic'] != null &&
                friend['profilePic'].isNotEmpty
            ? NetworkImage(friend['profilePic'])
            : null,
        child: friend['profilePic'] == null || friend['profilePic'].isEmpty
            ? const Icon(Icons.person)
            : null,
      ),
    );
  }

  bool _isUserAlreadyInvited(String userId) {
    return _pendingInvites.contains(userId);
  }

  Future<void> _sendSelectedInvites() async {
    if (_selectedFriendIds.isEmpty) return;

    setState(() => _isSendingInvites = true);

    try {
      final failedInvites = <String>[];
      
      for (final friendId in _selectedFriendIds.toList()) {
        try {
          final friend = _allFriends.firstWhere(
            (f) => f['id'] == friendId,
            orElse: () => {},
          );
          
          if (friend.isEmpty) continue;

          await _eventService.sendInvite(
            widget.event.id!,
            friendId,
            friend['name'] ?? 'Nepoznato',
          );
        } catch (e) {
          print('Error sending invite to $friendId: $e');
          failedInvites.add(friendId);
        }
      }

      if (mounted) {
        if (failedInvites.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Poslano ${_selectedFriendIds.length} pozivnica!'),
              backgroundColor: Colors.green,
            ),
          );
          _selectedFriendIds.clear();
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Poslano ${_selectedFriendIds.length - failedInvites.length}, ${failedInvites.length} greške',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Greška: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSendingInvites = false);
      }
    }
  }
}
