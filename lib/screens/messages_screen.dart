import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/friends_service.dart';
import '../services/messaging_service.dart';
import 'chat_screen.dart';
import 'group_chat_screen.dart';
import 'other_user_profile.dart';
import 'create_group_screen.dart';
import '../data/hobbies.dart'; // ADD THIS IMPORT

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
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
          children: [
            _CombinedConversationsTab(),
            _ContactsAndRequestsTab(),
          ],
        ),
      ),
    );
  }
}

/// COMBINED CONVERSATIONS TAB (Private + Groups)
class _CombinedConversationsTab extends StatelessWidget {
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

class _ContactsAndRequestsTabState extends State<_ContactsAndRequestsTab> {
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
                      Text('ZAHTEVI'),
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

class _ContactsListWithSearchState extends State<_ContactsListWithSearch> {
  String _searchQuery = '';
  String? _selectedCategory;
  String? _selectedSubcategory;
  List<String> _activeFilters = [];
  TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _allFriendsWithData = [];
  List<Map<String, dynamic>> _filteredFriends = [];
  bool _isLoading = true;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
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
    _searchController.dispose();
    super.dispose();
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
                          }).toList(),
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
                        value: tempCategory,
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
                          value: tempSubcategory,
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
/// FRIEND REQUESTS LIST
class _FriendRequestsList extends StatelessWidget {
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
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FriendsService.getFriendRequestsStream(),
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
            child: Text('Greška: ${snapshot.error}'),
          );
        }

        final requests = snapshot.data ?? [];

        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.notifications_none, size: 80, color: Colors.orange.shade300),
                const SizedBox(height: 20),
                Text(
                  'Nema zahteva',
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
                    'Kada neko pošalje zahtev, pojaviće se ovde',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            return _FriendRequestTile(
              request: request,
              onAccept: () => _handleAcceptRequest(context, request['requestId']),
              onDecline: () => _handleDeclineRequest(context, request['requestId']),
            );
          },
        );
      },
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
      child: Padding(
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
    );
  }
}