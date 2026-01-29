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
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.shade100.withOpacity(0.3),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.orange.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Filtriraj po gradu',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF333333),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      title: const Text('Svi gradovi'),
                      onTap: () {
                        setState(() => _selectedCityFilter = null);
                        Navigator.pop(context);
                      },
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _selectedCityFilter == null
                              ? Colors.orange.shade100
                              : Colors.grey.shade100,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _selectedCityFilter == null
                                ? Colors.orange.shade300
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.location_city,
                          color: _selectedCityFilter == null
                              ? Colors.orange.shade700
                              : Colors.grey.shade400,
                          size: 20,
                        ),
                      ),
                      tileColor: _selectedCityFilter == null
                          ? Colors.orange.shade50
                          : null,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...serbiaCities.map((city) {
                      final isSelected = _selectedCityFilter == city;
                      return ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        title: Text(city),
                        onTap: () {
                          setState(() => _selectedCityFilter = city);
                          Navigator.pop(context);
                        },
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.orange.shade100
                                : Colors.grey.shade100,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? Colors.orange.shade300
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            Icons.location_on,
                            color: isSelected
                                ? Colors.orange.shade700
                                : Colors.grey.shade400,
                            size: 20,
                          ),
                        ),
                        tileColor:
                            isSelected ? Colors.orange.shade50 : null,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Container(
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Pretraži oglase...',
              hintStyle: const TextStyle(color: Colors.white70),
              border: InputBorder.none,
              prefixIcon: const Icon(Icons.search, color: Colors.white70),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white70),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    )
                  : null,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
        actions: [
          // City filter icon button
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: _selectedCityFilter != null
                  ? Colors.white.withOpacity(0.2)
                  : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: Icon(
                Icons.location_city,
                color: _selectedCityFilter != null
                    ? Colors.amber.shade200
                    : Colors.white,
              ),
              onPressed: _showCityFilterDialog,
              tooltip: 'Filtriraj po gradu',
            ),
          ),
          // Filter button
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: _showMatchingOnly ? Colors.white.withOpacity(0.2) : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: Icon(
                _showMatchingOnly
                    ? Icons.filter_alt
                    : Icons.filter_alt_outlined,
                color: _showMatchingOnly ? Colors.amber.shade200 : Colors.white,
              ),
              onPressed: () {
                setState(() => _showMatchingOnly = !_showMatchingOnly);
              },
              tooltip: _showMatchingOnly
                  ? 'Prikaži sve'
                  : 'Prikaži samo za mene',
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.orange.shade50,
              Colors.white,
            ],
            stops: const [0.0, 0.3],
          ),
        ),
        child: _showMatchingOnly ? _buildMatchingPosters() : _buildAllPosters(),
      ),
      floatingActionButton: Container(
        margin: const EdgeInsets.only(bottom: 16, right: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.orange.shade400,
              Colors.orange.shade600,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.shade400.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const CreateOglasScreen()),
            );
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
      ),
    );
  }

  Widget _buildAllPosters() {
    return StreamBuilder<List<Poster>>(
      stream: PosterService.getPostersStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              color: Colors.orange.shade700,
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error,
                  color: Colors.orange.shade700,
                  size: 60,
                ),
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

        var posters = snapshot.data ?? [];

        // Filter by search query
        final searchQuery = _searchController.text.toLowerCase();
        if (searchQuery.isNotEmpty) {
          posters = posters.where((p) {
            final matchesTitle = p.title.toLowerCase().contains(searchQuery);
            final matchesDescription =
                p.description.toLowerCase().contains(searchQuery);
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
              future: PosterService.posterMatchesUserHobbies(
                  posters[index], PosterService.currentUserId),
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
          return Center(
            child: CircularProgressIndicator(
              color: Colors.orange.shade700,
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error,
                  color: Colors.orange.shade700,
                  size: 60,
                ),
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

        var posters = snapshot.data ?? [];

        // Filter by search query
        final searchQuery = _searchController.text.toLowerCase();
        if (searchQuery.isNotEmpty) {
          posters = posters.where((p) {
            final matchesTitle = p.title.toLowerCase().contains(searchQuery);
            final matchesDescription =
                p.description.toLowerCase().contains(searchQuery);
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
                Icon(
                  Icons.search_off,
                  size: 80,
                  color: Colors.orange.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  'Nema oglasa za vas',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Promenite hobije u svom profilu\nili dodajte novi oglas',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const CreateOglasScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade600,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Dodaj oglas'),
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
          Icon(
            Icons.campaign_outlined,
            size: 80,
            color: Colors.orange.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'Nema oglasa',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Budite prvi koji će objaviti oglas!',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const CreateOglasScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Dodaj oglas'),
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

  Widget _buildDefaultAvatar(String userName) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.orange.shade200,
            Colors.orange.shade400,
          ],
        ),
      ),
      child: Center(
        child: Text(
          userName.isNotEmpty ? userName[0].toUpperCase() : '?',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.shade100.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
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
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.orange.shade300,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.shade100.withOpacity(0.5),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: poster.userProfilePic != null &&
                                  poster.userProfilePic!.isNotEmpty
                              ? Image.network(
                                  poster.userProfilePic!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      _buildDefaultAvatar(poster.userName),
                                )
                              : _buildDefaultAvatar(poster.userName),
                        ),
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
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: Color(0xFF333333),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 12,
                                color: Colors.grey.shade500,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatDate(poster.createdAt),
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (isMatching)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.orange.shade100,
                              Colors.orange.shade200,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.orange.shade300,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.star,
                              size: 12,
                              color: Colors.orange.shade700,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Za vas',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.orange.shade800,
                                fontWeight: FontWeight.w600,
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
                    color: Color(0xFF333333),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                // Description (truncated)
                Text(
                  poster.description,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                // City
                if (poster.city != null)
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 16,
                        color: Colors.orange.shade600,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        poster.city!,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
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
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.blue.shade100,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          hobby,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                ],
                // Image thumbnail (if exists)
                if (poster.imageUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      height: 140,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Image.network(
                        poster.imageUrl!,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            height: 140,
                            width: double.infinity,
                            color: Colors.grey.shade100,
                            child: Center(
                              child: CircularProgressIndicator(
                                color: Colors.orange.shade700,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) =>
                            Container(
                          color: Colors.grey.shade200,
                          child: Center(
                            child: Icon(
                              Icons.broken_image,
                              color: Colors.grey.shade400,
                              size: 40,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
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