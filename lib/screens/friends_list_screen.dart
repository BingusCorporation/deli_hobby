import 'package:flutter/material.dart';
import '../services/friends_service.dart';
import 'other_user_profile.dart';

class FriendsListScreen extends StatefulWidget {
  final String userId;

  const FriendsListScreen({
    super.key,
    required this.userId,
  });

  @override
  State<FriendsListScreen> createState() => _FriendsListScreenState();
}

class _FriendsListScreenState extends State<FriendsListScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _allFriends = [];
  List<Map<String, dynamic>> _filteredFriends = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterFriends);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterFriends() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredFriends = _allFriends;
      } else {
        _filteredFriends = _allFriends
            .where((friend) =>
                (friend['name'] as String? ?? '').toLowerCase().contains(query))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prijatelji'),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Colors.orange.shade50,
              Colors.amber.shade50,
            ],
          ),
        ),
        child: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Pretraži prijatelje...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ),
            // Friends list
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: FriendsService.getFriendsStreamForUser(widget.userId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Greška: ${snapshot.error}'),
                    );
                  }

                  _allFriends = snapshot.data ?? [];
                  _filterFriends();

                  if (_filteredFriends.isEmpty) {
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
                            _searchController.text.isEmpty
                                ? 'Nemate prijatelja'
                                : 'Nema rezultata',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _filteredFriends.length,
                    itemBuilder: (context, index) {
                      final friend = _filteredFriends[index];
                      return _buildFriendCard(friend);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendCard(Map<String, dynamic> friend) {
    final String? profilePic = friend['profilePic'] as String?;
    final String name = friend['name'] as String? ?? 'Nepoznato';
    final String? city = friend['city'] as String?;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OtherUserProfileScreen(
              userId: friend['id'],
              userName: name,
            ),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 2,
        shadowColor: Colors.orange.withValues(alpha: 0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Colors.orange.shade50.withValues(alpha: 0.3),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Profile picture
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.orange.shade100,
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
                        name,
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
                              size: 13,
                              color: Colors.orange.shade600,
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

                // Arrow
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.orange.shade600,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
