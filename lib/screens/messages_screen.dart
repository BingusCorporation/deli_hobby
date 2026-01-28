import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/friends_service.dart';
import '../services/messaging_service.dart';
import 'chat_screen.dart';
import 'group_chat_screen.dart';
import 'other_user_profile.dart';
import 'create_group_screen.dart';
import 'oglas_screen.dart';
import '../data/hobbies.dart';
import '../events/event_service.dart';
import '../events/event_details_screen.dart';
import '../events/event_invite_model.dart';

class MessagesScreen extends StatefulWidget {
  final int initialTab;
  
  const MessagesScreen({
    super.key,
    this.initialTab = 0,
  });

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      initialIndex: widget.initialTab,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Force rebuild of the tab view when screen comes back into focus
    // This triggers a refresh of the streams
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
        title: const Text('Poruke'),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add),
            tooltip: 'Kreiraj grupu',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CreateGroupScreen(),
                ),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.7),
          tabs: const [
            Tab(text: 'RAZGOVORI'),
            Tab(text: 'KONTAKTI'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _CombinedConversationsTab(),
          _ContactsAndRequestsTab(),
        ],
      ),
    );
  }
}

/// COMBINED CONVERSATIONS TAB (Private + Groups)
class _CombinedConversationsTab extends StatefulWidget {
  const _CombinedConversationsTab();

  @override
  State<_CombinedConversationsTab> createState() => _CombinedConversationsTabState();
}

class _CombinedConversationsTabState extends State<_CombinedConversationsTab> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Trigger refresh when app comes to foreground
    if (state == AppLifecycleState.resumed) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: MessagingService.getCombinedConversationsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: Colors.orange,
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.orange, size: 60),
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

        final conversations = snapshot.data ?? [];

        if (conversations.isEmpty) {
          return _buildEmptyConversationsState();
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 8),
          itemCount: conversations.length,
          itemBuilder: (context, index) {
            return _ConversationTile(conversation: conversations[index]);
          },
        );
      },
    );
  }

  Widget _buildEmptyConversationsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 80, color: Colors.orange.shade300),
          const SizedBox(height: 20),
          Text(
            'Nema razgovora',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Pokrenite razgovor sa prijateljem ili kreirajte grupu',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            icon: const Icon(Icons.group_add),
            label: const Text('Kreiraj grupu'),
          ),
        ],
      ),
    );
  }
}

/// COMBINED CONTACTS AND REQUESTS TAB
class _ContactsAndRequestsTab extends StatefulWidget {
  @override
  State<_ContactsAndRequestsTab> createState() => _ContactsAndRequestsTabState();
}

class _ContactsAndRequestsTabState extends State<_ContactsAndRequestsTab> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: Colors.grey.shade50,
            child: TabBar(
              indicatorColor: Colors.orange.shade700,
              labelColor: Colors.orange.shade700,
              unselectedLabelColor: Colors.grey.shade600,
              tabs: const [
                Tab(text: 'PRIJATELJI'),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications, size: 16),
                      SizedBox(width: 4),
                      Text('ZAHTEVI I POZIVNICE'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _ContactsListWithSearch(),
                _FriendRequestsList(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// CONTACTS LIST WITH SEARCH AND FILTERS
/// CONTACTS LIST WITH SEARCH AND FILTERS
/// CONTACTS LIST WITH SEARCH AND FILTERS
class _ContactsListWithSearch extends StatefulWidget {
  @override
  State<_ContactsListWithSearch> createState() => _ContactsListWithSearchState();
}

class _ContactsListWithSearchState extends State<_ContactsListWithSearch> with WidgetsBindingObserver {
  String _searchQuery = '';
  String? _selectedCategory;
  String? _selectedSubcategory;
  final List<String> _activeFilters = [];
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _allFriendsWithData = [];
  List<Map<String, dynamic>> _filteredFriends = [];
  bool _isLoading = true;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
        _applyFilters();
      });
    });
    _loadFriendsWithData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadFriendsWithData();
    }
  }

  Future<void> _loadFriendsWithData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // First, get all friend IDs from friendships collection
      final friendshipsSnapshot = await FirebaseFirestore.instance
          .collection('friendships')
          .where('userId', isEqualTo: _currentUser!.uid)
          .get();

      final friendIds = friendshipsSnapshot.docs
          .map((doc) => doc['friendId'] as String)
          .toList();

      if (friendIds.isEmpty) {
        setState(() {
          _allFriendsWithData = [];
          _filteredFriends = [];
          _isLoading = false;
        });
        return;
      }

      // Get user data for each friend
      final friendsWithData = <Map<String, dynamic>>[];

      for (final friendId in friendIds) {
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(friendId)
              .get();

          if (userDoc.exists) {
            final userData = userDoc.data()!;
            friendsWithData.add({
              'id': friendId,
              'name': userData['name'] ?? 'Nepoznato',
              'email': userData['email'] ?? '',
              'city': userData['city'] ?? '',
              'profilePic': userData['profilePic'] ?? '',
              'hobbies': List<String>.from(userData['hobbies'] ?? []),
              'bio': userData['bio'] ?? '',
            });
          }
        } catch (e) {
          print('Error loading user data for $friendId: $e');
        }
      }

      setState(() {
        _allFriendsWithData = friendsWithData;
        _applyFilters();
        _isLoading = false;
      });

    } catch (e) {
      print('Error loading friends: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    // Start with all friends
    List<Map<String, dynamic>> result = List.from(_allFriendsWithData);

    // Apply name search
    if (_searchQuery.isNotEmpty) {
      result = result.where((friend) {
        final name = friend['name']?.toString().toLowerCase() ?? '';
        return name.contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // Apply hobby filters (only if a category is selected)
    if (_selectedCategory != null) {
      result = result.where((friend) {
        final List<String> hobbies = List<String>.from(friend['hobbies'] ?? []);
        if (hobbies.isEmpty) return false;

        if (_selectedSubcategory != null) {
          // Looking for exact subcategory
          final targetHobby = '$_selectedCategory > $_selectedSubcategory';
          return hobbies.contains(targetHobby);
        } else {
          // Looking for any hobby in the category
          return hobbies.any((hobby) => hobby.startsWith('$_selectedCategory >'));
        }
      }).toList();
    }

    setState(() {
      _filteredFriends = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // SEARCH AND FILTER BAR
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.white,
          child: Column(
            children: [
              // Search bar
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    Icon(Icons.search, color: Colors.grey.shade500, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Pretraži prijatelje po imenu...',
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          hintStyle: TextStyle(color: Colors.grey.shade500),
                        ),
                      ),
                    ),
                    if (_searchQuery.isNotEmpty || _activeFilters.isNotEmpty)
                      IconButton(
                        icon: Icon(Icons.clear, size: 18, color: Colors.grey.shade500),
                        onPressed: _clearAllFilters,
                        tooltip: 'Obriši sve filtere',
                      ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Filter button and active filters
              Row(
                children: [
                  // Filter button
                  ElevatedButton.icon(
                    onPressed: () {
                      _showFilterDialog(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade50,
                      foregroundColor: Colors.orange.shade700,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: Colors.orange.shade300),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    icon: Icon(
                      Icons.filter_list, 
                      size: 18,
                      color: _activeFilters.isNotEmpty ? Colors.orange.shade700 : Colors.grey.shade600,
                    ),
                    label: Text(
                      'Filter',
                      style: TextStyle(
                        color: _activeFilters.isNotEmpty ? Colors.orange.shade700 : Colors.grey.shade600,
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 8),
                  
                  // Active filters chips with clear all
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          // Clear all button (only when there are filters)
                          if (_activeFilters.isNotEmpty)
                            InkWell(
                              onTap: _clearAllFilters,
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.clear_all, size: 14, color: Colors.grey.shade600),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Obriši sve',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          
                          // Active filter chips
                          ..._activeFilters.map((filter) {
                            return Container(
                              margin: const EdgeInsets.only(right: 6),
                              child: Chip(
                                label: Text(filter),
                                deleteIcon: const Icon(Icons.close, size: 14),
                                onDeleted: () {
                                  _removeFilter(filter);
                                },
                                backgroundColor: Colors.orange.shade50,
                                side: BorderSide(color: Colors.orange.shade200),
                                labelStyle: TextStyle(
                                  color: Colors.orange.shade700,
                                  fontSize: 12,
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 8),
        
        // Contacts list
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Colors.orange,
                  ),
                )
              : _filteredFriends.isEmpty
                  ? _buildEmptyOrNoResultsState()
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: 8),
                      itemCount: _filteredFriends.length,
                      itemBuilder: (context, index) {
                        return _ContactTile(friend: _filteredFriends[index]);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildEmptyOrNoResultsState() {
    final hasActiveFilters = _searchQuery.isNotEmpty || _activeFilters.isNotEmpty;
    final hasFriends = _allFriendsWithData.isNotEmpty;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasActiveFilters ? Icons.search_off : 
            hasFriends ? Icons.filter_list : Icons.people_outline, 
            size: 80, 
            color: Colors.orange.shade300
          ),
          const SizedBox(height: 20),
          Text(
            hasActiveFilters ? 'Nema rezultata' : 
            hasFriends ? 'Nema prijatelja sa tim filterima' : 'Nema prijatelja',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              hasActiveFilters 
                ? 'Pokušajte sa drugim filterima ili obrišite trenutne'
                : hasFriends
                  ? 'Promenite filtere da biste videli prijatelje'
                  : 'Dodajte prijatelje da biste započeli razgovor',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (hasActiveFilters)
            ElevatedButton.icon(
              onPressed: _clearAllFilters,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              icon: const Icon(Icons.clear_all),
              label: const Text('Obriši sve filtere'),
            ),
          if (!hasFriends && !hasActiveFilters)
            ElevatedButton.icon(
              onPressed: () {
                // You might want to navigate to search users screen
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Idite na pretragu da dodate prijatelje'),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              icon: const Icon(Icons.person_add),
              label: const Text('Pronađi prijatelje'),
            ),
        ],
      ),
    );
  }

  void _showFilterDialog(BuildContext context) {
    String? tempCategory = _selectedCategory;
    String? tempSubcategory = _selectedSubcategory;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Filter hobijima'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Clear filters button (only when there's a selection)
                      if (tempCategory != null || tempSubcategory != null)
                        Column(
                          children: [
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    tempCategory = null;
                                    tempSubcategory = null;
                                  });
                                },
                                icon: const Icon(Icons.clear, size: 16),
                                label: const Text('Obriši filter'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      
                      // Category dropdown
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
                            tempSubcategory = null; // Reset subcategory when category changes
                          });
                        },
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Subcategory dropdown (only if category is selected and has subcategories)
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
                      
                      // Current filter display
                      if (tempCategory != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Trenutni filter:',
                                style: TextStyle(
                                  color: Colors.orange.shade700,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                tempSubcategory != null
                                    ? '$tempCategory > $tempSubcategory'
                                    : tempCategory!,
                                style: TextStyle(
                                  color: Colors.orange.shade800,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Otkaži'),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Update the state with new filter values
                    setState(() {
                      _selectedCategory = tempCategory;
                      _selectedSubcategory = tempSubcategory;
                      
                      // Update active filters display
                      _activeFilters.clear();
                      if (_selectedCategory != null) {
                        if (_selectedSubcategory != null) {
                          _activeFilters.add('$_selectedCategory > $_selectedSubcategory');
                        } else {
                          _activeFilters.add(_selectedCategory!);
                        }
                      }
                    });
                    
                    // Apply the filters
                    _applyFilters();
                    
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade700,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Primeni filter'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _clearAllFilters() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
      _selectedCategory = null;
      _selectedSubcategory = null;
      _activeFilters.clear();
      _applyFilters();
    });
  }

  void _removeFilter(String filter) {
    setState(() {
      _activeFilters.remove(filter);
      
      // Update the underlying filter variables
      if (filter.contains(' > ')) {
        // This was a category > subcategory filter
        final parts = filter.split(' > ');
        if (parts[0] == _selectedCategory && parts[1] == _selectedSubcategory) {
          _selectedCategory = null;
          _selectedSubcategory = null;
        }
      } else {
        // This was just a category filter
        if (filter == _selectedCategory) {
          _selectedCategory = null;
          _selectedSubcategory = null;
        }
      }
      
      _applyFilters();
    });
  }
}
/// FRIEND REQUESTS AND EVENT INVITES LIST
class _FriendRequestsList extends StatefulWidget {
  const _FriendRequestsList();

  @override
  State<_FriendRequestsList> createState() => _FriendRequestsListState();
}

class _FriendRequestsListState extends State<_FriendRequestsList> with WidgetsBindingObserver {
  final EventService _eventService = EventService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() {});
    }
  }

  Future<List<Map<String, dynamic>>> _loadInvitesWithDetails(List<EventInvite> invites) async {
    final List<Map<String, dynamic>> invitesWithEventDetails = [];

    for (final invite in invites) {
      try {
        final eventSnap = await FirebaseFirestore.instance
            .collection('events')
            .doc(invite.eventId)
            .get();

        if (eventSnap.exists) {
          // Get inviter's name
          String inviterName = 'Nepoznato';
          try {
            final inviterSnap = await FirebaseFirestore.instance
                .collection('users_private')
                .doc(invite.inviterId)
                .get();
            if (inviterSnap.exists) {
              inviterName = inviterSnap.data()?['name'] ?? 'Nepoznato';
            }
          } catch (e) {
            print('Error loading inviter name: $e');
          }

          invitesWithEventDetails.add({
            'inviteId': invite.id,
            'eventId': invite.eventId,
            'eventTitle': eventSnap.data()?['title'] ?? 'Event',
            'inviterName': inviterName,
            'status': invite.status,
          });
        }
      } catch (e) {
        print('Error loading event details: $e');
      }
    }

    return invitesWithEventDetails;
  }

  void _handleAcceptRequest(BuildContext context, String requestId) async {
    try {
      await FriendsService.acceptFriendRequest(requestId);
      _showSnackBar(context, 'Zahtev prihvaćen!', Colors.green);
    } catch (e) {
      _showSnackBar(context, 'Greška: $e', Colors.red);
    }
  }

  void _handleDeclineRequest(BuildContext context, String requestId) async {
    try {
      await FriendsService.cancelFriendRequest(requestId);
      _showSnackBar(context, 'Zahtev odbijen', Colors.orange);
    } catch (e) {
      _showSnackBar(context, 'Greška: $e', Colors.red);
    }
  }

  void _handleAcceptEventInvite(BuildContext context, String eventId, String inviteId) async {
    try {
      await _eventService.respondToInvite(eventId, inviteId, true);
      _showSnackBar(context, 'Pozivnica prihvaćena!', Colors.green);
      // Refresh the screen by rebuilding
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      _showSnackBar(context, 'Greška: $e', Colors.red);
    }
  }

  void _handleDeclineEventInvite(BuildContext context, String eventId, String inviteId) async {
    try {
      await _eventService.respondToInvite(eventId, inviteId, false);
      _showSnackBar(context, 'Pozivnica odbijena', Colors.orange);
      // Refresh the screen by rebuilding
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      _showSnackBar(context, 'Greška: $e', Colors.red);
    }
  }

  void _showSnackBar(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Friend Requests Section
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: FriendsService.getFriendRequestsStream(),
            builder: (context, friendRequestsSnapshot) {
              final friendRequests = friendRequestsSnapshot.data ?? [];

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (friendRequests.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        'Zahtevi za prijateljstvo',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: friendRequests.length,
                      itemBuilder: (context, index) {
                        final request = friendRequests[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _FriendRequestTile(
                            request: request,
                            onAccept: () => _handleAcceptRequest(context, request['requestId']),
                            onDecline: () => _handleDeclineRequest(context, request['requestId']),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              );
            },
          ),

          // Event Invites Section
          FutureBuilder<List<EventInvite>>(
            future: _eventService.getMyPendingInvitesFallback(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                print('Error fetching invites: ${snapshot.error}');
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final invites = snapshot.data ?? [];
              print('DEBUG: Got ${invites.length} pending invites from fallback');

              return FutureBuilder<List<Map<String, dynamic>>>(
                future: _loadInvitesWithDetails(invites),
                builder: (context, detailsSnapshot) {
                  if (detailsSnapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox.shrink();
                  }

                  final invitesWithDetails = detailsSnapshot.data ?? [];

                  if (invitesWithDetails.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          'Pozivnice za dogadjaje',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: invitesWithDetails.length,
                        itemBuilder: (context, index) {
                          final invite = invitesWithDetails[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _EventInviteTile(
                              invite: invite,
                              onAccept: () => _handleAcceptEventInvite(
                                context,
                                invite['eventId'],
                                invite['inviteId'],
                              ),
                              onDecline: () => _handleDeclineEventInvite(
                                context,
                                invite['eventId'],
                                invite['inviteId'],
                              ),
                              onViewEvent: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => EventDetailsScreen(
                                      eventId: invite['eventId'],
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ],
                  );
                },
              );
            },
          ),

          // Poster Shares (Recommendations) Section
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(FirebaseAuth.instance.currentUser?.uid)
                .collection('poster_shares')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, posterSharesSnapshot) {
              final posterShares = posterSharesSnapshot.data?.docs ?? [];

              if (posterShares.isEmpty) {
                return const SizedBox.shrink();
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'Preporučeni oglasi',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: posterShares.length,
                    itemBuilder: (context, index) {
                      final shareDoc = posterShares[index];
                      final shareData = shareDoc.data() as Map<String, dynamic>;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _PosterShareTile(
                          shareId: shareDoc.id,
                          posterId: shareData['posterId'] ?? '',
                          posterTitle: shareData['posterTitle'] ?? 'Oglas',
                          posterCity: shareData['posterCity'],
                          sharerName: shareData['sharerName'] ?? 'Nepoznato',
                          message: shareData['message'] ?? '',
                          onView: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => OglasScreen(
                                  posterId: shareData['posterId'] ?? '',
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),

          // Empty state
          FutureBuilder<List<EventInvite>>(
            future: _eventService.getMyPendingInvitesFallback(),
            builder: (context, invitesSnapshot) {
              return StreamBuilder<List<Map<String, dynamic>>>(
                stream: FriendsService.getFriendRequestsStream(),
                builder: (context, friendRequestsSnapshot) {
                  final friendRequests = friendRequestsSnapshot.data ?? [];
                  final eventInvites = invitesSnapshot.data ?? [];

                  if (friendRequests.isEmpty && eventInvites.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 40),
                          Icon(Icons.notifications_none, size: 80, color: Colors.orange.shade300),
                          const SizedBox(height: 20),
                          Text(
                            'Nema zahteva ili pozivnica',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40),
                            child: Text(
                              'Kada neko pošalje zahtev ili pozivnicu, pojaviće se ovde',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    );
                  }

                  return const SizedBox.shrink();
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

/// CONVERSATION TILE WIDGET (Supports both private and group)
class _ConversationTile extends StatelessWidget {
  final Map<String, dynamic> conversation;

  const _ConversationTile({required this.conversation});

  @override
  Widget build(BuildContext context) {
    final type = conversation['type']; // 'private' or 'group'
    final isGroup = type == 'group';
    final unreadCount = conversation['unreadCount'] ?? 0;
    final lastMessage = conversation['lastMessage'] ?? '';
    final lastMessageTime = conversation['lastMessageTime'];

    return ListTile(
      onTap: () {
        if (isGroup) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GroupChatScreen(
                groupId: conversation['id'],
                groupName: conversation['name'],
              ),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                otherUserId: conversation['otherUserId'],
                otherUserName: conversation['name'],
              ),
            ),
          );
        }
      },
      leading: Stack(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isGroup ? Colors.orange.shade100 : Colors.blue.shade100,
            ),
            child: Icon(
              isGroup ? Icons.group : Icons.person,
              color: isGroup ? Colors.orange.shade700 : Colors.blue.shade700,
              size: 30,
            ),
          ),
          if (unreadCount > 0)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Text(
                  unreadCount > 9 ? '9+' : unreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              conversation['name'],
              style: TextStyle(
                fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                color: Colors.grey.shade800,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isGroup)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Grupa',
                style: TextStyle(
                  color: Colors.orange.shade700,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      subtitle: Text(
        lastMessage,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.grey.shade600,
          fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (lastMessageTime != null)
            Text(
              _formatTime(lastMessageTime),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
          const SizedBox(height: 4),
          if (unreadCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'NOVO',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatTime(Timestamp timestamp) {
    final now = DateTime.now();
    final messageTime = timestamp.toDate();
    final difference = now.difference(messageTime);

    if (difference.inDays == 0) {
      return '${messageTime.hour}:${messageTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Juče';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} dana';
    } else {
      return '${messageTime.day}.${messageTime.month}.';
    }
  }
}

/// CONTACT TILE WIDGET (Updated to show hobbies)
class _ContactTile extends StatelessWidget {
  final Map<String, dynamic> friend;

  const _ContactTile({required this.friend});

  void _showProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OtherUserProfileScreen(
          userId: friend['id'],
          userName: friend['name'],
        ),
      ),
    );
  }

  void _startChat(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          otherUserId: friend['id'],
          otherUserName: friend['name'],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<dynamic> hobbies = friend['hobbies'] ?? [];
    final List<String> hobbyStrings = hobbies.take(2).map((hobby) {
      final parts = hobby.toString().split(' > ');
      return parts.length > 1 ? parts[1] : hobby.toString();
    }).toList();

    return ListTile(
      onTap: () => _showProfile(context),
      leading: CircleAvatar(
        radius: 25,
        backgroundColor: Colors.orange.shade100,
        backgroundImage: friend['profilePic'] != null && friend['profilePic'].isNotEmpty
            ? NetworkImage(friend['profilePic'])
            : null,
        child: friend['profilePic'] == null || friend['profilePic'].isEmpty
            ? Icon(
                Icons.person,
                color: Colors.orange.shade700,
                size: 30,
              )
            : null,
      ),
      title: Text(
        friend['name'],
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (friend['city']?.isNotEmpty == true)
            Text(
              friend['city'],
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          if (hobbyStrings.isNotEmpty)
            Wrap(
              spacing: 4,
              runSpacing: 2,
              children: hobbyStrings.map((hobby) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    hobby,
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
      trailing: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.orange.shade700,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(Icons.message, color: Colors.white, size: 20),
        ),
        onPressed: () => _startChat(context),
      ),
    );
  }
}

/// FRIEND REQUEST TILE WIDGET
class _FriendRequestTile extends StatelessWidget {
  final Map<String, dynamic> request;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _FriendRequestTile({
    required this.request,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 25,
                      backgroundColor: Colors.orange.shade100,
                      backgroundImage: request['profilePic'] != null && request['profilePic'].isNotEmpty
                          ? NetworkImage(request['profilePic'])
                          : null,
                      child: request['profilePic'] == null || request['profilePic'].isEmpty
                          ? Icon(
                              Icons.person,
                              color: Colors.orange.shade700,
                              size: 30,
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            request['name'],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (request['city'] != null && request['city'].isNotEmpty)
                            Text(
                              request['city'],
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Želi da vas doda za prijatelja',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onAccept,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.check, size: 20),
                        label: const Text('Prihvati'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onDecline,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.close, size: 20),
                        label: const Text('Odbij'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Red NEW badge
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'NOVO',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// EVENT INVITE TILE WIDGET
class _EventInviteTile extends StatelessWidget {
  final Map<String, dynamic> invite;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onViewEvent;

  const _EventInviteTile({
    required this.invite,
    required this.onAccept,
    required this.onDecline,
    required this.onViewEvent,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      color: Colors.blue.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blue.shade200, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.event,
                  size: 30,
                  color: Colors.blue.shade700,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invite['eventTitle'] ?? 'Event',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Od: ${invite['inviterName'] ?? 'Nepoznato'}',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Pozvani ste na dogadjaj',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: onAccept,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.check, size: 20),
                    label: const Text('Prihvati'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onDecline,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Odbij'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onViewEvent,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue.shade700,
                      side: BorderSide(color: Colors.blue.shade700),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.info, size: 18),
                    label: const Text('Info'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
/// POSTER SHARE TILE WIDGET
class _PosterShareTile extends StatefulWidget {
  final String shareId;
  final String posterId;
  final String posterTitle;
  final String? posterCity;
  final String sharerName;
  final String message;
  final VoidCallback onView;

  const _PosterShareTile({
    required this.shareId,
    required this.posterId,
    required this.posterTitle,
    this.posterCity,
    required this.sharerName,
    required this.message,
    required this.onView,
  });

  @override
  State<_PosterShareTile> createState() => _PosterShareTileState();
}

class _PosterShareTileState extends State<_PosterShareTile> {

  Future<void> _deleteShare() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Obriši preporuku'),
        content: const Text('Da li želiš da obrišeš ovu preporuku oglasa?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Odustani'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final currentUser = FirebaseAuth.instance.currentUser;
                if (currentUser != null) {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(currentUser.uid)
                      .collection('poster_shares')
                      .doc(widget.shareId)
                      .delete();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Preporuka obrisana'),
                        backgroundColor: Colors.green,
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
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Obriši'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      color: Colors.orange.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.orange.shade200, width: 1),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.campaign,
                    size: 28,
                    color: Colors.orange.shade700,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.posterTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      if (widget.posterCity != null)
                        Row(
                          children: [
                            Icon(Icons.location_on,
                                size: 12, color: Colors.grey.shade600),
                            const SizedBox(width: 3),
                            Text(
                              widget.posterCity!,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              widget.message,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: widget.onView,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.visibility, size: 20),
                    label: const Text('Pogledaj oglas'),
                  ),
                ),
              ],
            ),
            ],
            ),
          ),
          // NOVO badge
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'NOVO',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: Colors.transparent,
              child: IconButton(
                icon: const Icon(Icons.close, size: 20),
                color: Colors.orange.shade700,
                onPressed: _deleteShare,
                tooltip: 'Obriši preporuku',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
