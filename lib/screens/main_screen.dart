import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/hobbies.dart';
import '../data/city.dart';
import 'profile.dart';
import 'messages_screen.dart'; // ADD THIS
import 'chat_screen.dart'; // ADD THIS
import '../auth/login_screen.dart';
import 'other_user_profile.dart';
import '../services/init.dart';

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
  final List<String> _selectedFilters = [];
  
  // For dropdowns
  String? _selectedCategory;
  String? _selectedSubcategory;
  
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
        actions: [
          // Messages icon button
          StreamBuilder<int>(
            stream: _getUnreadCountStream(),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.message),
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
          // Profile icon button
          IconButton(
            icon: const Icon(Icons.person),
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
          _buildSearchFilters(),
          
          // SEARCH BUTTON
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ElevatedButton.icon(
              onPressed: _searchForMatches,
              icon: const Icon(Icons.search),
              label: const Text('Pronađi ljude'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 45),
              ),
            ),
          ),
          
          // SEARCH STATUS
          if (_searchStatus.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                _searchStatus,
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontStyle: FontStyle.italic,
                  fontSize: 14,
                ),
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
            final data = doc.data() as Map<String, dynamic>;
            final unread = (data['unreadCount'] as Map<String, dynamic>?)?[_currentUserId] as int? ?? 0;
            total += unread;
          }
          return total;
        });
  }

  /// Build compact search filters
  Widget _buildSearchFilters() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.grey[50],
      child: Column(
        children: [
          // City dropdown
          Row(
            children: [
              const Icon(Icons.location_city, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    hint: const Text('Grad (opciono)'),
                    value: _selectedCity,
                    items: serbiaCities.map((city) {
                      return DropdownMenuItem(
                        value: city,
                        child: Text(city, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => _selectedCity = value),
                  ),
                ),
              ),
              if (_selectedCity != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() => _selectedCity = null),
                ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Category and subcategory in a row
          Row(
            children: [
              // Category dropdown
              Expanded(
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Kategorija',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      hint: const Text('Izaberi'),
                      value: _selectedCategory,
                      items: hobbyCategories.keys.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(category, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
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
              
              const SizedBox(width: 8),
              
              // Subcategory dropdown
              Expanded(
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Podkategorija',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      hint: const Text('Izaberi (opciono)'),
                      value: _selectedSubcategory,
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Sva podkategorija'),
                        ),
                        if (_selectedCategory != null)
                          ...hobbyCategories[_selectedCategory]!.map((sub) {
                            return DropdownMenuItem(
                              value: sub,
                              child: Text(sub, overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                      ],
                      onChanged: (value) => setState(() => _selectedSubcategory = value),
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Add filter button
          ElevatedButton(
            onPressed: _selectedCategory != null ? _addSearchFilter : null,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 36),
            ),
            child: const Text('Dodaj filter'),
          ),
          
          const SizedBox(height: 8),
          
          // Selected filters chips
          if (_selectedFilters.isNotEmpty || _selectedCity != null) ...[
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                // City chip
                if (_selectedCity != null)
                  Chip(
                    label: Text(_selectedCity!),
                    deleteIcon: const Icon(Icons.close, size: 14),
                    onDeleted: () => setState(() => _selectedCity = null),
                  ),
                
                // Filter chips
                ..._selectedFilters.map((filter) {
                  return Chip(
                    label: Text(filter),
                    deleteIcon: const Icon(Icons.close, size: 14),
                    onDeleted: () => setState(() => _selectedFilters.remove(filter)),
                  );
                }).toList(),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Add current selection to search filters
  void _addSearchFilter() {
    if (_selectedCategory != null) {
      String filter;
      if (_selectedSubcategory != null) {
        filter = '$_selectedCategory > $_selectedSubcategory';
      } else {
        filter = _selectedCategory!;
      }
      
      if (!_selectedFilters.contains(filter)) {
        setState(() {
          _selectedFilters.add(filter);
          _selectedCategory = null;
          _selectedSubcategory = null;
        });
      }
    }
  }

  /// Build search results
  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Tražim ljude sa sličnim hobijima...'),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people, size: 60, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'Dodajte filtere i pritisnite "Pronađi ljude"',
              style: TextStyle(color: Colors.grey, fontSize: 14),
              textAlign: TextAlign.center,
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
    final String? bio = user['bio'] as String?;
    final List<dynamic> matchingHobbies = user['matchingHobbies'] as List<dynamic>? ?? [];
    final int matchScore = user['matchScore'] as int? ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User info row
            Row(
              children: [
                // Profile picture
                GestureDetector(
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
                  child: CircleAvatar(
                    radius: 20,
                    backgroundImage: profilePic != null && profilePic.isNotEmpty
                        ? NetworkImage(profilePic)
                        : const AssetImage('assets/default_avatar.png')
                            as ImageProvider,
                  ),
                ),
                const SizedBox(width: 12),
                
                // Name and city
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
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
                        child: Text(
                          user['name'] as String? ?? 'Nepoznato',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (city != null && city.isNotEmpty)
                        Text(
                          city,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                
                // Match score
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getMatchColor(matchScore),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '$matchScore%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Bio preview
            if (bio != null && bio.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  bio,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 12,
                  ),
                ),
              ),
            
            // Matching hobbies
            if (matchingHobbies.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: matchingHobbies
                    .take(3)
                    .map<Widget>((hobby) {
                      return Chip(
                        label: Text(
                          hobby.toString(),
                          style: const TextStyle(fontSize: 10),
                        ),
                        backgroundColor: Colors.green[50],
                        side: BorderSide(color: Colors.green.shade200),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                      );
                    }).toList(),
              ),
            
            const SizedBox(height: 8),
            
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
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
                  icon: const Icon(Icons.message, size: 14),
                  label: const Text('Poruka', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () {
                    // Navigate to user profile
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
                  icon: const Icon(Icons.person, size: 14),
                  label: const Text('Profil', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
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

    if (_selectedFilters.isEmpty && _selectedCity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Izaberi bar jedan filter za pretragu')),
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
      
      // Prepare search patterns
      final List<String> exactPatterns = [];
      final List<String> categoryPatterns = [];
      
      for (final filter in _selectedFilters) {
        if (filter.contains('>')) {
          exactPatterns.add(filter);
        } else {
          categoryPatterns.add(filter);
        }
      }
      
      // Execute query
      final snapshot = await query.get();
      
      // Filter and score results
      final List<Map<String, dynamic>> results = [];
      
      for (final doc in snapshot.docs) {
        final userData = doc.data() as Map<String, dynamic>;
        final List<dynamic> userHobbies = userData['hobbies'] as List<dynamic>? ?? [];
        
        // Calculate matches
        final List<String> matchingHobbies = [];
        int matchScore = 0;
        
        // Check exact matches
        for (final pattern in exactPatterns) {
          if (userHobbies.contains(pattern)) {
            matchingHobbies.add(pattern);
            matchScore += 30;
          }
        }
        
        // Check category matches
        for (final category in categoryPatterns) {
          bool hasCategoryMatch = false;
          for (final hobby in userHobbies) {
            final hobbyStr = hobby.toString();
            if (hobbyStr.startsWith('$category >')) {
              matchingHobbies.add(hobbyStr);
              hasCategoryMatch = true;
            }
          }
          if (hasCategoryMatch) {
            matchScore += 15;
          }
        }
        
        // Apply city bonus
        if (_selectedCity != null && userData['city'] == _selectedCity) {
          matchScore += 10;
        }
        
        // Cap score at 100
        matchScore = matchScore.clamp(0, 100);
        
        if (matchScore > 0 || _selectedFilters.isEmpty) {
          results.add({
            'id': doc.id,
            ...userData,
            'matchScore': matchScore,
            'matchingHobbies': matchingHobbies,
          });
        }
      }
      
      // Sort by match score
      results.sort((a, b) => b['matchScore'].compareTo(a['matchScore']));
      
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

  /// Get color based on match score
  Color _getMatchColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.blue;
    if (score >= 40) return Colors.orange;
    return Colors.red;
  }
}

