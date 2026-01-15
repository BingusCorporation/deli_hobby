import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/hobbies.dart';
import '../data/city.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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

  String get _currentUserId => _auth.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Deli Hobby'),
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
              label: const Text('Pronadji ljude'),
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

  Widget _buildCompactSearchFilters() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.grey[50],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // CITY DROPDOWN
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

          // SELECTED FILTERS CHIPS
          if (_selectedCategories.isNotEmpty || _selectedSubcategories.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Trazim:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
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

                ..._selectedCategories.map((category) {
                  return Chip(
                    label: Text(category),
                    deleteIcon: const Icon(Icons.close, size: 14),
                    onDeleted: () {
                      setState(() {
                        _selectedCategories.remove(category);
                        _selectedSubcategories.removeWhere(
                          (sub) => hobbyCategories[category]?.contains(sub) ?? false
                        );
                      });
                    },
                  );
                }),

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
                }),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _addSearchFilter() {
    if (_selectedCategory != null && _selectedSubcategory != null) {
      setState(() {
        if (!_selectedCategories.contains(_selectedCategory!)) {
          _selectedCategories.add(_selectedCategory!);
        }
        if (!_selectedSubcategories.contains(_selectedSubcategory!)) {
          _selectedSubcategories.add(_selectedSubcategory!);
        }
        _selectedCategory = null;
        _selectedSubcategory = null;
      });
    }
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Trazim ljude sa slicnim hobijima...'),
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
              'Izaberi kategorije i pritisni "Pronadji ljude"',
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

  Widget _buildUserCard(Map<String, dynamic> user) {
    final List<dynamic> matchingHobbies =
        (user['matchingHobbies'] is List<dynamic>)
            ? user['matchingHobbies'] as List<dynamic>
            : [];

    final String? bio = (user['bio'] is String) ? user['bio'] as String? : null;
    final String? city = (user['city'] is String) ? user['city'] as String? : null;
    final String? profilePic = (user['profilePic'] is String) ? user['profilePic'] as String? : null;
    final int matchScore = (user['matchScore'] is int) ? user['matchScore'] as int : 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundImage: profilePic != null && profilePic.isNotEmpty
                      ? NetworkImage(profilePic)
                      : null,
                  child: profilePic == null || profilePic.isEmpty
                      ? const Icon(Icons.person)
                      : null,
                ),
                const SizedBox(width: 12),

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
          ],
        ),
      ),
    );
  }

  Future<void> _searchForMatches() async {
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
      final List<String> fullSearchStrings = [];

      for (final category in _selectedCategories) {
        for (final subcategory in _selectedSubcategories) {
          if (hobbyCategories[category]?.contains(subcategory) ?? false) {
            fullSearchStrings.add('$category > $subcategory');
          }
        }
      }

      final List<String> categoryOnlyStrings = [];
      for (final category in _selectedCategories) {
        categoryOnlyStrings.add(category);
      }

      if (fullSearchStrings.isNotEmpty) {
        _searchStatus = 'Trazim tacno poklapanje...';
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

      if (fullSearchStrings.isNotEmpty) {
        _searchStatus = 'Trazim delimicno poklapanje...';
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

      if (categoryOnlyStrings.isNotEmpty) {
        _searchStatus = 'Trazim po kategorijama...';
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

      setState(() {
        _searchStatus = 'Nema pronadjenih ljudi sa trazenim kriterijumima';
        _searchResults = [];
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Greska pri pretrazi: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

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
      _searchStatus = 'Pronadjeno ${results.length} ljudi';
    });
  }

  Color _getMatchColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.blue;
    if (score >= 40) return Colors.orange;
    return Colors.red;
  }
}
