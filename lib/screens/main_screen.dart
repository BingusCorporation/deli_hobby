import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/hobbies.dart';
import '../data/city.dart';
import 'profile.dart';
import '../auth/login_screen.dart'; // Add this import

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
  final List<String> _selectedCategories = [];
  final List<String> _selectedSubcategories = [];
  
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
  }

  void _setupAuthListener() {
    // Listen for auth state changes
    _auth.authStateChanges().listen((User? user) {
      if (user == null && mounted) {
        // User logged out - navigate to login
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
    // Check if user is authenticated
    if (_auth.currentUser == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Deli Hobby'),
        actions: [
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
          // COMPACT SEARCH FILTERS SECTION
          _buildCompactSearchFilters(),
          
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

  /// Build compact search filters section
  Widget _buildCompactSearchFilters() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.grey[50],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // CITY DROPDOWN (similar to profile)
          const Text(
            'Grad:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 4),
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
                  child: Text('Izaberi grad (opciono)'),
                ),
                value: _selectedCity,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                items: serbiaCities.map((city) {
                  return DropdownMenuItem(
                    value: city,
                    child: Text(city),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCity = value;
                  });
                },
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // CATEGORY AND SUBCATEGORY ROW
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Kategorija:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
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
                            child: Text('Izaberi kategoriju'),
                          ),
                          value: _selectedCategory,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          items: hobbyCategories.keys.map((category) {
                            return DropdownMenuItem(
                              value: category,
                              child: Text(category),
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
                  ],
                ),
              ),
              
              const SizedBox(width: 8),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Podkategorija:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
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
                            child: Text('Izaberi podkategoriju'),
                          ),
                          value: _selectedSubcategory,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          items: _selectedCategory != null
                              ? hobbyCategories[_selectedCategory]!
                                  .map((sub) => DropdownMenuItem(
                                    value: sub,
                                    child: Text(sub),
                                  ))
                                  .toList()
                              : [],
                          onChanged: (value) {
                            setState(() {
                              _selectedSubcategory = value;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // ADD BUTTON
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: ElevatedButton(
              onPressed: _selectedCategory != null && _selectedSubcategory != null
                  ? _addSearchFilter
                  : null,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 36),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: const Text('Dodaj u pretragu'),
            ),
          ),
          
          // SELECTED FILTERS CHIPS (only if any)
          if (_selectedCategories.isNotEmpty || _selectedSubcategories.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Tražim:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                // City chip if selected
                if (_selectedCity != null)
                  Chip(
                    label: Text(_selectedCity!),
                    deleteIcon: const Icon(Icons.close, size: 14),
                    onDeleted: () {
                      setState(() {
                        _selectedCity = null;
                      });
                    },
                  ),
                
                // Category chips
                ..._selectedCategories.map((category) {
                  return Chip(
                    label: Text(category),
                    deleteIcon: const Icon(Icons.close, size: 14),
                    onDeleted: () {
                      setState(() {
                        _selectedCategories.remove(category);
                        // Remove all subcategories from this category
                        _selectedSubcategories.removeWhere(
                          (sub) => hobbyCategories[category]?.contains(sub) ?? false
                        );
                      });
                    },
                  );
                }).toList(),
                
                // Subcategory chips
                ..._selectedSubcategories.map((subcategory) {
                  return Chip(
                    label: Text(subcategory),
                    deleteIcon: const Icon(Icons.close, size: 14),
                    onDeleted: () {
                      setState(() {
                        _selectedSubcategories.remove(subcategory);
                      });
                    },
                  );
                }).toList(),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Add current category/subcategory to search filters
  void _addSearchFilter() {
    if (_selectedCategory != null && _selectedSubcategory != null) {
      setState(() {
        if (!_selectedCategories.contains(_selectedCategory!)) {
          _selectedCategories.add(_selectedCategory!);
        }
        if (!_selectedSubcategories.contains(_selectedSubcategory!)) {
          _selectedSubcategories.add(_selectedSubcategory!);
        }
        // Reset dropdowns for next selection
        _selectedCategory = null;
        _selectedSubcategory = null;
      });
    }
  }

  /// Build the search results section
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
              'Izaberi kategorije i pritisni "Pronađi ljude"',
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

  /// Build a user card for search results
  Widget _buildUserCard(Map<String, dynamic> user) {
    // ✅ FIX: Handle missing 'matchingHobbies' field
    final List<dynamic> matchingHobbies = 
        (user['matchingHobbies'] is List<dynamic>)
            ? user['matchingHobbies'] as List<dynamic>
            : [];
    
    // ✅ FIX: Handle missing 'bio' field
    final String? bio = (user['bio'] is String) ? user['bio'] as String? : null;
    
    // ✅ FIX: Handle missing 'city' field
    final String? city = (user['city'] is String) ? user['city'] as String? : null;
    
    // ✅ FIX: Handle missing 'profilePic' field
    final String? profilePic = (user['profilePic'] is String) ? user['profilePic'] as String? : null;
    
    // ✅ FIX: Handle missing 'matchScore' field
    final int matchScore = (user['matchScore'] is int) ? user['matchScore'] as int : 0;
    
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
                CircleAvatar(
                  radius: 25,
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
                        user['name'] ?? 'Nepoznato',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
            
            // Bio
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
                      hobby.toString().replaceAll(' > ', ' >\n'),
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
            
            // View profile button
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  // Navigate to user profile
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfileScreen(),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Pogledaj profil',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Main search algorithm
  Future<void> _searchForMatches() async {
    // First check if user is still authenticated
    if (_auth.currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sesija je istekla. Molimo prijavite se ponovo.'),
          ),
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
      return;
    }

    if (_selectedCategories.isEmpty && _selectedSubcategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Izaberi bar jednu kategoriju ili podkategoriju'),
        ),
      );
      return;
    }

    setState(() {
      _isSearching = true;
      _searchResults = [];
      _searchStatus = '';
    });

    try {
      // Build full search strings (Category > Subcategory)
      final List<String> fullSearchStrings = [];
      
      for (final category in _selectedCategories) {
        for (final subcategory in _selectedSubcategories) {
          if (hobbyCategories[category]?.contains(subcategory) ?? false) {
            fullSearchStrings.add('$category > $subcategory');
          }
        }
      }

      // Build category-only search strings
      final List<String> categoryOnlyStrings = [];
      for (final category in _selectedCategories) {
        categoryOnlyStrings.add(category);
      }

      // QUERY 1: Exact match on all selected categories AND subcategories
      if (fullSearchStrings.isNotEmpty) {
        _searchStatus = 'Tražim tačno poklapanje...';
        setState(() {});
        
        final exactMatches = await _searchUsers(
          searchStrings: fullSearchStrings,
          requireAll: true,
          city: _selectedCity,
        );
        
        if (exactMatches.isNotEmpty) {
          _processAndDisplayResults(exactMatches, fullSearchStrings, 100);
          return;
        }
      }

      // QUERY 2: Match at least one category AND subcategory
      if (fullSearchStrings.isNotEmpty) {
        _searchStatus = 'Tražim delimično poklapanje...';
        setState(() {});
        
        final partialMatches = await _searchUsers(
          searchStrings: fullSearchStrings,
          requireAll: false,
          city: _selectedCity,
        );
        
        if (partialMatches.isNotEmpty) {
          _processAndDisplayResults(partialMatches, fullSearchStrings, 70);
          return;
        }
      }

      // QUERY 3: Match at least one category (ignoring subcategories)
      if (categoryOnlyStrings.isNotEmpty) {
        _searchStatus = 'Tražim po kategorijama...';
        setState(() {});
        
        final categoryMatches = await _searchUsersByCategory(
          categories: categoryOnlyStrings,
          city: _selectedCity,
        );
        
        if (categoryMatches.isNotEmpty) {
          _processAndDisplayResults(categoryMatches, categoryOnlyStrings, 50);
          return;
        }
      }

      // No matches found
      setState(() {
        _searchStatus = 'Nema pronađenih ljudi sa traženim kriterijumima';
        _searchResults = [];
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Greška pri pretrazi: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  /// Search users with specific criteria
  Future<List<QueryDocumentSnapshot>> _searchUsers({
    required List<String> searchStrings,
    required bool requireAll,
    String? city,
  }) async {
    Query query = _firestore.collection('users');
    
    query = query.where(FieldPath.documentId, isNotEqualTo: _currentUserId);
    
    if (city != null && city.isNotEmpty) {
      query = query.where('city', isEqualTo: city);
    }
    
    if (requireAll) {
      for (final searchString in searchStrings) {
        query = query.where('hobbies', arrayContains: searchString);
      }
    } else {
      query = query.where('hobbies', arrayContainsAny: searchStrings);
    }
    
    final snapshot = await query.get();
    return snapshot.docs;
  }

  /// Search users by category only
  Future<List<QueryDocumentSnapshot>> _searchUsersByCategory({
    required List<String> categories,
    String? city,
  }) async {
    Query query = _firestore.collection('users');
    
    query = query.where(FieldPath.documentId, isNotEqualTo: _currentUserId);
    
    if (city != null && city.isNotEmpty) {
      query = query.where('city', isEqualTo: city);
    }
    
    final snapshot = await query.get();
    
    return snapshot.docs.where((doc) {
      final userData = doc.data() as Map<String, dynamic>;
      
      final List<String> userHobbies = 
          (userData['hobbies'] is List<dynamic>)
              ? List<String>.from(userData['hobbies'] as List<dynamic>)
              : [];
      
      for (final hobby in userHobbies) {
        for (final category in categories) {
          if (hobby.startsWith('$category >')) {
            return true;
          }
        }
      }
      return false;
    }).toList();
  }

  /// Process and display search results with match scoring
  void _processAndDisplayResults(
    List<QueryDocumentSnapshot> docs,
    List<String> searchStrings,
    int baseScore,
  ) {
    final List<Map<String, dynamic>> results = [];
    
    for (final doc in docs) {
      final userData = doc.data() as Map<String, dynamic>;
      
      final List<String> userHobbies = 
          (userData['hobbies'] is List<dynamic>)
              ? List<String>.from(userData['hobbies'] as List<dynamic>)
              : [];
      
      final List<String> matchingHobbies = [];
      int matchCount = 0;
      
      for (final hobby in userHobbies) {
        for (final searchString in searchStrings) {
          if (searchString.contains('>')) {
            if (hobby == searchString) {
              matchingHobbies.add(hobby);
              matchCount++;
            }
          } else {
            if (hobby.startsWith('$searchString >')) {
              matchingHobbies.add(hobby);
              matchCount++;
            }
          }
        }
      }
      
      final matchScore = (baseScore + (matchCount * 5)).clamp(0, 100);
      
      results.add({
        'id': doc.id,
        ...userData,
        'matchScore': matchScore,
        'matchingHobbies': matchingHobbies,
      });
    }
    
    results.sort((a, b) => b['matchScore'].compareTo(a['matchScore']));
    
    setState(() {
      _searchResults = results;
      _searchStatus = 'Pronađeno ${results.length} ljudi';
    });
  }

  /// Get color based on match score
  Color _getMatchColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.blue;
    if (score >= 40) return Colors.orange;
    return Colors.red;
  }
}