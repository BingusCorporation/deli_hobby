import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/hobbies.dart';
import '../data/city.dart';
import 'profile.dart';
import 'messages_screen.dart';
import 'chat_screen.dart';
import '../auth/login_screen.dart';
import 'other_user_profile.dart';
import '../services/init.dart';
import 'oglasi_screen.dart';
import '../events/events_browse_screen.dart';
import 'notifications_screen.dart';
import '../services/notification_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Search state
  String? _selectedCity;
  String? _selectedCategory;
  String? _selectedSubcategory;
  final TextEditingController _nameSearchController = TextEditingController();
  
  // Search results
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  String _searchStatus = '';

  @override
  void initState() {
    super.initState();
    _setupAuthListener();
    initializeFirestoreStructure();
  }

  @override
  void dispose() {
    _nameSearchController.dispose();
    super.dispose();
  }

  void _setupAuthListener() {
    _auth.authStateChanges().listen((User? user) {
      if (user == null && mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    });
  }

  String get _currentUserId => _auth.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    if (_auth.currentUser == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Deli Hobby'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.orange.shade700,
        elevation: 1,
        actions: [
          IconButton(
            icon: Icon(Icons.event, color: Colors.orange.shade700),
            tooltip: 'Dogadjaji',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EventsBrowseScreen()),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.list_alt, color: Colors.orange.shade700),
            tooltip: 'Oglasi',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OglasiScreen()),
              );
            },
          ),
          // Messages icon button
          StreamBuilder<int>(
            stream: _getUnreadCountStream(),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;
              return Stack(
                children: [
                  IconButton(
                    icon: Icon(Icons.message, color: Colors.orange.shade700),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const MessagesScreen()),
                      );
                    },
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          unreadCount > 9 ? '9+' : unreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          // Notifications icon button
          FutureBuilder<int>(
            future: NotificationService().getUnreadCount(),
            builder: (context, snapshot) {
              final unreadNotifications = snapshot.data ?? 0;
              return Stack(
                children: [
                  IconButton(
                    icon: Icon(Icons.notifications, color: Colors.orange.shade700),
                    tooltip: 'Obavesti',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                      );
                    },
                  ),
                  if (unreadNotifications > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          unreadNotifications > 9 ? '9+' : unreadNotifications.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.person, color: Colors.orange.shade700),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfileScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // COMPACT SEARCH SECTION
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[50],
            child: Column(
              children: [
                // Name search field
                TextField(
                  controller: _nameSearchController,
                  decoration: InputDecoration(
                    hintText: 'Pretraži po imenu...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  ),
                  onChanged: (value) => setState(() {}),
                ),
                
                const SizedBox(height: 12),
                
                // Hobby and City in one row
                Row(
                  children: [
                    // Hobby dropdown
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            hint: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text('Hobi'),
                            ),
                            value: _selectedCategory,
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12),
                                  child: Text('Svi hobiji'),
                                ),
                              ),
                              ...hobbyCategories.keys.map((category) {
                                return DropdownMenuItem(
                                  value: category,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    child: Text(category),
                                  ),
                                );
                              }),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedCategory = value;
                                _selectedSubcategory = null;
                              });
                            },
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 12),
                    
                    // City dropdown
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            hint: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text('Grad'),
                            ),
                            value: _selectedCity,
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12),
                                  child: Text('Svi gradovi'),
                                ),
                              ),
                              ...serbiaCities.map((city) {
                                return DropdownMenuItem(
                                  value: city,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    child: Text(city),
                                  ),
                                );
                              }),
                            ],
                            onChanged: (value) => setState(() => _selectedCity = value),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                
                // Subcategory dropdown (only shows when category is selected)
                if (_selectedCategory != null && hobbyCategories[_selectedCategory]!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        hint: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text('Podkategorija (opciono)'),
                        ),
                        value: _selectedSubcategory,
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text('Sve podkategorije'),
                            ),
                          ),
                          ...hobbyCategories[_selectedCategory]!.map((sub) {
                            return DropdownMenuItem(
                              value: sub,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(sub),
                              ),
                            );
                          }),
                        ],
                        onChanged: (value) => setState(() => _selectedSubcategory = value),
                      ),
                    ),
                  ),
                ],
                
                // Search button
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _searchForMatches,
                    icon: const Icon(Icons.search),
                    label: const Text('Pronađi ljude'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                
                // Selected filters chips
                if (_selectedCategory != null || _selectedCity != null) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    alignment: WrapAlignment.start,
                    children: [
                      if (_selectedCategory != null)
                        Chip(
                          label: Text(
                            _selectedSubcategory != null 
                                ? '$_selectedCategory > $_selectedSubcategory'
                                : _selectedCategory!,
                          ),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () => setState(() {
                            _selectedCategory = null;
                            _selectedSubcategory = null;
                          }),
                          backgroundColor: Colors.orange.shade50,
                        ),
                      if (_selectedCity != null)
                        Chip(
                          label: Text(_selectedCity!),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () => setState(() => _selectedCity = null),
                          backgroundColor: Colors.blue.shade50,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          
          // SEARCH STATUS
          if (_searchStatus.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.grey[50],
              child: Row(
                children: [
                  Icon(
                    _searchResults.isEmpty ? Icons.info_outline : Icons.check_circle,
                    color: _searchResults.isEmpty ? Colors.orange : Colors.green,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _searchStatus,
                      style: TextStyle(
                        color: _searchResults.isEmpty ? Colors.orange.shade700 : Colors.green.shade700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (_searchResults.isNotEmpty && _selectedCategory != null)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedCategory = null;
                          _selectedSubcategory = null;
                          _selectedCity = null;
                          _searchResults = [];
                          _searchStatus = '';
                        });
                      },
                      child: const Text(
                        'Obriši filtere',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                ],
              ),
            ),
          
          // SEARCH RESULTS
          Expanded(
            child: _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  /// Stream for unread messages count
  Stream<int> _getUnreadCountStream() {
    return _firestore
        .collection('conversations')
        .where('participants', arrayContains: _currentUserId)
        .snapshots()
        .map((snapshot) {
          int total = 0;
          for (final doc in snapshot.docs) {
            final data = doc.data();
            final unread = (data['unreadCount'] as Map<String, dynamic>?)?[_currentUserId] as int? ?? 0;
            total += unread;
          }
          return total;
        });
  }

  /// Build search results
  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: Colors.orange,
            ),
            SizedBox(height: 16),
            Text('Tražim ljude sa sličnim hobijima...'),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty && _searchStatus.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'Izaberite hobi i grad\nza pretragu',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pronađite ljude sa sličnim interesovanjima',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty && _searchStatus.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'Nema rezultata',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Promenite filtere i pokušajte ponovo',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        return _buildUserCard(user);
      },
    );
  }

  /// Build user card
  Widget _buildUserCard(Map<String, dynamic> user) {
    final String? profilePic = user['profilePic'] as String?;
    final String? city = user['city'] as String?;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OtherUserProfileScreen(
              userId: user['id'] as String,
              userName: user['name'] as String? ?? 'Nepoznato',
            ),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Profile picture
              CircleAvatar(
                radius: 20,
                backgroundImage: profilePic != null && profilePic.isNotEmpty
                    ? NetworkImage(profilePic)
                    : const AssetImage('assets/default_avatar.png')
                        as ImageProvider,
              ),
              const SizedBox(width: 12),
              
              // Name and city
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user['name'] as String? ?? 'Nepoznato',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (city != null && city.isNotEmpty)
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 12,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            city,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              
              // Message button
              IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(
                        otherUserId: user['id'] as String,
                        otherUserName: user['name'] as String? ?? 'Nepoznato',
                      ),
                    ),
                  );
                },
                icon: Icon(
                  Icons.message,
                  color: Colors.orange.shade700,
                  size: 18,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                tooltip: 'Pošalji poruku',
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Main search algorithm
  Future<void> _searchForMatches() async {
    if (_auth.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sesija je istekla. Molimo prijavite se ponovo.')),
      );
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
      return;
    }

    if (_selectedCategory == null && _selectedCity == null && _nameSearchController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Izaberite bar jedan filter za pretragu')),
      );
      return;
    }

    setState(() {
      _isSearching = true;
      _searchResults = [];
      _searchStatus = '';
    });

    try {
      // Build query
      Query query = _firestore.collection('users');
      query = query.where(FieldPath.documentId, isNotEqualTo: _currentUserId);
      
      if (_selectedCity != null && _selectedCity!.isNotEmpty) {
        query = query.where('city', isEqualTo: _selectedCity);
      }
      
      // Execute query
      final snapshot = await query.get();
      
      // Filter results
      final List<Map<String, dynamic>> results = [];
      final String nameFilter = _nameSearchController.text.trim().toLowerCase();
      
      for (final doc in snapshot.docs) {
        final userData = doc.data() as Map<String, dynamic>;
        final String userName = (userData['name'] as String? ?? '').toLowerCase();
        final List<dynamic> userHobbies = userData['hobbies'] as List<dynamic>? ?? [];
        
        // Check name filter
        if (nameFilter.isNotEmpty && !userName.contains(nameFilter)) {
          continue;
        }
        
        // Check if we have hobby filter
        bool hasMatchingHobby = false;
        List<String> matchingHobbies = [];
        
        if (_selectedCategory != null) {
          for (final hobby in userHobbies) {
            final hobbyStr = hobby.toString();
            if (_selectedSubcategory != null) {
              // Looking for specific subcategory
              if (hobbyStr == '$_selectedCategory > $_selectedSubcategory') {
                hasMatchingHobby = true;
                matchingHobbies.add(hobbyStr);
              }
            } else {
              // Looking for any subcategory in this category
              if (hobbyStr.startsWith('$_selectedCategory >')) {
                hasMatchingHobby = true;
                matchingHobbies.add(hobbyStr);
              }
            }
          }
        } else {
          // No hobby filter, show all users (only filtered by city/name if selected)
          hasMatchingHobby = true;
        }
        
        // Add user if they match criteria
        if (hasMatchingHobby) {
          results.add({
            'id': doc.id,
            ...userData,
            'matchingHobbies': matchingHobbies,
          });
        }
      }
      
      setState(() {
        _searchResults = results;
        _searchStatus = results.isEmpty 
            ? 'Nema pronađenih ljudi sa traženim kriterijumima'
            : 'Pronađeno ${results.length} ljudi';
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Greška pri pretrazi: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }
}