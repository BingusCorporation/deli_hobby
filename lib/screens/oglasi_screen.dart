import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/poster_service.dart';
import '../models/poster.dart';
import './oglas_screen.dart';
import './other_user_profile.dart';
import './create_oglas_screen.dart';
import '../data/city.dart';

class OglasiScreen extends StatefulWidget {
  const OglasiScreen({super.key});

  @override
  State<OglasiScreen> createState() => _OglasiScreenState();
}

class _OglasiScreenState extends State<OglasiScreen> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  bool _showMatchingOnly = false;
  String? _selectedCityFilter;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showCityFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filtriraj po gradu'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            children: [
              ListTile(
                title: const Text('Svi gradovi'),
                onTap: () {
                  setState(() => _selectedCityFilter = null);
                  Navigator.pop(context);
                },
                selected: _selectedCityFilter == null,
              ),
              ...serbiaCities.map((city) {
                return ListTile(
                  title: Text(city),
                  onTap: () {
                    setState(() => _selectedCityFilter = city);
                    Navigator.pop(context);
                  },
                  selected: _selectedCityFilter == city,
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Pretrazi oglase...',
            hintStyle: TextStyle(color: Colors.white70),
            border: InputBorder.none,
            prefixIcon: Icon(Icons.search, color: Colors.white70),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white70),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                  )
                : null,
          ),
          onChanged: (_) => setState(() {}),
        ),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
        actions: [
          // City filter icon button
          IconButton(
            icon: Icon(
              Icons.location_city,
              color: _selectedCityFilter != null ? Colors.amber : Colors.white,
            ),
            onPressed: _showCityFilterDialog,
            tooltip: 'Filtriraj po gradu',
          ),
          // Filter button
          IconButton(
            icon: Icon(
              _showMatchingOnly ? Icons.filter_alt : Icons.filter_alt_outlined,
              color: _showMatchingOnly ? Colors.amber : null,
            ),
            onPressed: () {
              setState(() => _showMatchingOnly = !_showMatchingOnly);
            },
            tooltip: _showMatchingOnly ? 'Prikaži sve' : 'Prikaži samo za mene',
          ),
        ],
      ),
      body: _showMatchingOnly ? _buildMatchingPosters() : _buildAllPosters(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateOglasScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildAllPosters() {
    return StreamBuilder<List<Poster>>(
      stream: PosterService.getPostersStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        var posters = snapshot.data ?? [];

        // Filter by search query
        final searchQuery = _searchController.text.toLowerCase();
        if (searchQuery.isNotEmpty) {
          posters = posters.where((p) {
            final matchesTitle = p.title.toLowerCase().contains(searchQuery);
            final matchesDescription = p.description.toLowerCase().contains(searchQuery);
            return matchesTitle || matchesDescription;
          }).toList();
        }

        // Filter by city if selected
        if (_selectedCityFilter != null) {
          posters = posters.where((p) => p.city == _selectedCityFilter).toList();
        }

        if (posters.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: posters.length,
          itemBuilder: (context, index) {
            return FutureBuilder<bool>(
              future: PosterService.posterMatchesUserHobbies(posters[index], PosterService.currentUserId),
              builder: (context, matchSnapshot) {
                final isMatching = matchSnapshot.data ?? false;
                return _PosterCard(
                  poster: posters[index],
                  isMatching: isMatching,
                  onTap: () => _viewPoster(posters[index]),
                  onUserTap: () => _viewUserProfile(posters[index]),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildMatchingPosters() {
    return StreamBuilder<List<Poster>>(
      stream: PosterService.getMatchingPostersStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        var posters = snapshot.data ?? [];

        // Filter by search query
        final searchQuery = _searchController.text.toLowerCase();
        if (searchQuery.isNotEmpty) {
          posters = posters.where((p) {
            final matchesTitle = p.title.toLowerCase().contains(searchQuery);
            final matchesDescription = p.description.toLowerCase().contains(searchQuery);
            return matchesTitle || matchesDescription;
          }).toList();
        }

        // Filter by city if selected
        if (_selectedCityFilter != null) {
          posters = posters.where((p) => p.city == _selectedCityFilter).toList();
        }

        if (posters.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 80, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'Nema oglasa za vas',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  'Promenite hobije u svom profilu\nili dodajte novi oglas',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: posters.length,
          itemBuilder: (context, index) {
            return _PosterCard(
              poster: posters[index],
              isMatching: true, // All are matching in this view
              onTap: () => _viewPoster(posters[index]),
              onUserTap: () => _viewUserProfile(posters[index]),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.campaign_outlined, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'Nema oglasa',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Budite prvi koji će objaviti oglas!',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CreateOglasScreen()),
              );
            },
            icon: Icon(Icons.add),
            label: Text('Dodaj oglas'),
          ),
        ],
      ),
    );
  }

  void _viewPoster(Poster poster) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OglasScreen(posterId: poster.id),
      ),
    );
  }

  void _viewUserProfile(Poster poster) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OtherUserProfileScreen(
          userId: poster.userId,
          userName: poster.userName,
        ),
      ),
    );
  }
}

class _PosterCard extends StatelessWidget {
  final Poster poster;
  final bool isMatching;
  final VoidCallback onTap;
  final VoidCallback onUserTap;

  const _PosterCard({
    required this.poster,
    required this.isMatching,
    required this.onTap,
    required this.onUserTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isMatching ? Colors.amber : Colors.grey.shade300,
          width: isMatching ? 2 : 1,
        ),
      ),
      elevation: isMatching ? 4 : 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User info row
              Row(
                children: [
                  GestureDetector(
                    onTap: onUserTap,
                    child: CircleAvatar(
                      radius: 20,
                      backgroundImage: poster.userProfilePic != null
                          ? NetworkImage(poster.userProfilePic!)
                          : NetworkImage('https://ui-avatars.com/api/?name=User&background=random'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: onUserTap,
                          child: Text(
                            poster.userName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Text(
                          _formatDate(poster.createdAt),
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (isMatching)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star, size: 14, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            'Za vas',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.amber[800],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              // Title
              Text(
                poster.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              // Description (truncated)
              Text(
                poster.description,
                style: TextStyle(color: Colors.grey[700]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              // City
              if (poster.city != null)
                Row(
                  children: [
                    Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      poster.city!,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              if (poster.city != null) const SizedBox(height: 12),
              // Hobbies
              if (poster.requiredHobbies.isNotEmpty) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: poster.requiredHobbies.map((hobby) {
                    return Chip(
                      label: Text(
                        hobby,
                        style: const TextStyle(fontSize: 12),
                      ),
                      backgroundColor: isMatching ? Colors.amber[50] : Colors.blue[50],
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
              ],
              // Image thumbnail (if exists)
              if (poster.imageUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    poster.imageUrl!,
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 120,
                        width: double.infinity,
                        color: Colors.grey[200],
                        child: Center(child: CircularProgressIndicator()),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Danas';
    } else if (difference.inDays == 1) {
      return 'Juče';
    } else if (difference.inDays < 7) {
      return 'Pre ${difference.inDays} dana';
    } else {
      return '${date.day}.${date.month}.${date.year}';
    }
  }
}