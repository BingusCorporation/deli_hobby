import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../services/poster_service.dart';
import '../services/friends_service.dart';
import '../models/poster.dart';
import './other_user_profile.dart';
import './chat_screen.dart';
import './create_oglas_screen.dart';
import '../data/hobbies.dart';

class OglasScreen extends StatefulWidget {
  final String posterId;

  const OglasScreen({super.key, required this.posterId});

  @override
  State<OglasScreen> createState() => _OglasScreenState();
}

class _OglasScreenState extends State<OglasScreen> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  late Future<Poster> _posterFuture;
  late Future<bool> _isMatchingFuture;

  @override
  void initState() {
    super.initState();
    _posterFuture = _loadPoster();
    _isMatchingFuture = _checkIfMatching();
  }

  Future<Poster> _loadPoster() async {
    final doc = await FirebaseFirestore.instance.collection('posters').doc(widget.posterId).get();
    if (!doc.exists) throw Exception('Oglas nije pronađen');
    return Poster.fromFirestore(doc);
  }

  Future<bool> _checkIfMatching() async {
    try {
      final poster = await _posterFuture;
      return await PosterService.posterMatchesUserHobbies(poster, _currentUser!.uid);
    } catch (e) {
      return false;
    }
  }

  void _viewUserProfile(String userId, String userName) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => OtherUserProfileScreen(userId: userId, userName: userName)));
  }

  void _sendMessage(String receiverId, String receiverName) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(otherUserId: receiverId, otherUserName: receiverName)));
  }

  void _editPoster(Poster poster) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => CreateOglasScreen(posterToEdit: poster)));
  }

  void _showDeleteDialog(Poster poster) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Obriši oglas'),
        content: const Text('Da li si siguran da želiš da obrišeš ovaj oglas? Ova akcija se ne može poništiti.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Odustani')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deletePoster(poster);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Obriši'),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePoster(Poster poster) async {
    try {
      if (poster.imageUrl != null && poster.imageUrl!.isNotEmpty) {
        try {
          final ref = FirebaseStorage.instance.refFromURL(poster.imageUrl!);
          await ref.delete();
        } catch (e) {
          print('Error deleting image: $e');
        }
      }

      await PosterService.deletePoster(widget.posterId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Oglas obrisan')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Greška: $e')));
    }
  }

  void _navigateToShare(Poster poster) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => SharePosterScreen(poster: poster)));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Poster>(
      future: _posterFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Oglas'),
              backgroundColor: Colors.orange.shade700,
              foregroundColor: Colors.white,
            ),
            body: Center(
              child: CircularProgressIndicator(
                color: Colors.orange.shade700,
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Oglas'),
              backgroundColor: Colors.orange.shade700,
              foregroundColor: Colors.white,
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, color: Colors.orange.shade700, size: 60),
                  const SizedBox(height: 16),
                  Text(
                    'Greška: ${snapshot.error}',
                    style: TextStyle(color: Colors.orange.shade700),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        final poster = snapshot.data!;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Oglas'),
            backgroundColor: Colors.orange.shade700,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () => _navigateToShare(poster),
                tooltip: 'Podeli sa prijateljem',
              ),
              if (_currentUser != null && _currentUser.uid == poster.userId) ...[
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _editPoster(poster),
                  tooltip: 'Izmeni',
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _showDeleteDialog(poster),
                  tooltip: 'Obriši',
                ),
              ],
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image
                if (poster.imageUrl != null)
                  Container(
                    height: 250,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.grey.shade200,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.network(
                      poster.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey.shade300,
                        child: Icon(
                          Icons.broken_image,
                          color: Colors.grey.shade600,
                          size: 60,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),

                // Title
                Text(
                  poster.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                // Description
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Opis',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          poster.description,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // City
                if (poster.city != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(Icons.location_on, color: Colors.red.shade600),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Lokacija',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  poster.city!,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),

                // Required Hobbies
                if (poster.requiredHobbies.isNotEmpty) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Traženi hobiji',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: poster.requiredHobbies.map((h) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  h,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Creator info
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => _viewUserProfile(poster.userId, poster.userName),
                          child: CircleAvatar(
                            radius: 28,
                            backgroundImage: poster.userProfilePic != null
                                ? NetworkImage(poster.userProfilePic!)
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: () =>
                                    _viewUserProfile(poster.userId, poster.userName),
                                child: Text(
                                  poster.userName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatDate(poster.createdAt),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        FutureBuilder<bool>(
                          future: _isMatchingFuture,
                          builder: (context, matchSnapshot) {
                            if (matchSnapshot.data == true) {
                              return Container(
                                padding:
                                    const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade100,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.star,
                                        size: 14,
                                        color: Colors.amber.shade700),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Za vas',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.amber.shade800,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Action buttons
                if (_currentUser != null && _currentUser.uid != poster.userId)
                  Column(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () =>
                            _viewUserProfile(poster.userId, poster.userName),
                        icon: const Icon(Icons.person, size: 18),
                        label: const Text('Pogledaj profil'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: Colors.orange.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: () =>
                            _sendMessage(poster.userId, poster.userName),
                        icon: const Icon(Icons.message, size: 18),
                        label: const Text('Pošalji poruku'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) => '${date.day}.${date.month}.${date.year}. ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
}

// ============ SHARE POSTER SCREEN ============

class SharePosterScreen extends StatefulWidget {
  final Poster poster;
  const SharePosterScreen({super.key, required this.poster});

  @override
  State<SharePosterScreen> createState() => _SharePosterScreenState();
}

class _SharePosterScreenState extends State<SharePosterScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _searchController = TextEditingController();

  final List<Map<String, dynamic>> _allFriends = [];
  List<Map<String, dynamic>> _filteredFriends = [];
  bool _isLoadingFriends = true;
  bool _isSendingShare = false;
  final Set<String> _selectedFriendIds = {};
  final Set<String> _pendingShares = {};
  
  String? _selectedCategory;
  String? _selectedSubcategory;

  @override
  void initState() {
    super.initState();
    _loadFriends();
    _loadPendingShares();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    try {
      setState(() => _isLoadingFriends = true);
      final friendsStream = FriendsService.getFriendsStream();
      final friendsSnapshot = await friendsStream.first;
      setState(() {
        _allFriends.clear();
        _allFriends.addAll(friendsSnapshot);
        _applyFilters();
      });
    } catch (e) {
      print('Error loading friends: $e');
      _loadFriendsFallback();
    } finally {
      if (mounted) setState(() => _isLoadingFriends = false);
    }
  }

  Future<void> _loadFriendsFallback() async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return;

      final friendships = await _firestore.collection('friendships').where('userId', isEqualTo: currentUserId).limit(50).get();
      if (friendships.docs.isEmpty) return;

      final friendIds = friendships.docs.map((doc) => doc.data()['friendId'] as String).where((id) => id.isNotEmpty).toList();
      if (friendIds.isEmpty) return;

      final List<Map<String, dynamic>> friends = [];
      for (int i = 0; i < friendIds.length; i += 10) {
        final batchIds = friendIds.sublist(i, i + 10 < friendIds.length ? i + 10 : friendIds.length);
        final usersSnapshot = await _firestore.collection('users').where(FieldPath.documentId, whereIn: batchIds).get();
        for (final doc in usersSnapshot.docs) {
          friends.add({'id': doc.id, ...doc.data()});
        }
      }

      setState(() {
        _allFriends.clear();
        _allFriends.addAll(friends);
        _applyFilters();
      });
    } catch (e) {
      print('Error in fallback: $e');
    }
  }

  Future<void> _loadPendingShares() async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return;

      // Get shares that exist in the poster's shares collection
      final sharesSnapshot = await _firestore
          .collection('posters')
          .doc(widget.poster.id)
          .collection('shares')
          .where('status', isEqualTo: 'pending')
          .get();
      
      final pendingSet = <String>{};
      
      // For each pending share, check if it still exists in the recipient's poster_shares
      for (final doc in sharesSnapshot.docs) {
        final recipientId = doc['recipientId'] as String?;
        if (recipientId != null) {
          // Check if the share still exists in user's collection
          final userShare = await _firestore
              .collection('users')
              .doc(recipientId)
              .collection('poster_shares')
              .doc(doc.id)
              .get();
          
          // Only mark as pending if it still exists in the user's collection
          if (userShare.exists) {
            pendingSet.add(recipientId);
          } else {
            // If user deleted it, mark status as 'deleted' in the poster shares
            await doc.reference.update({'status': 'deleted'});
          }
        }
      }
      
      setState(() {
        _pendingShares.clear();
        _pendingShares.addAll(pendingSet);
      });
    } catch (e) {
      print('Error loading pending shares: $e');
    }
  }

  void _applyFilters() {
    final searchQuery = _searchController.text.toLowerCase();
    
    setState(() {
      _filteredFriends = _allFriends.where((friend) {
        final nameMatch = friend['name'].toString().toLowerCase().contains(searchQuery);
        
        if (_selectedCategory != null) {
          final hobbies = List<String>.from(friend['hobbies'] ?? []);
          bool hobbyMatch = false;
          
          if (_selectedSubcategory != null) {
            hobbyMatch = hobbies.contains('$_selectedCategory > $_selectedSubcategory');
          } else {
            hobbyMatch = hobbies.any((hobby) => hobby.startsWith('$_selectedCategory >'));
          }
          
          return nameMatch && hobbyMatch;
        }
        
        return nameMatch;
      }).toList();
    });
  }

  Future<void> _sendShareNotifications() async {
    setState(() => _isSendingShare = true);
    try {
      final currentUserId = _auth.currentUser!.uid;
      final currentUserDoc = await _firestore.collection('users').doc(currentUserId).get();
      final currentUserName = currentUserDoc['name'] ?? 'Nepoznato';

      final failed = <String>[];
      for (final friendId in _selectedFriendIds) {
        try {
          await _firestore.collection('posters').doc(widget.poster.id).collection('shares').add({
            'recipientId': friendId,
            'sharerId': currentUserId,
            'sharerName': currentUserName,
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
          });

          await _firestore.collection('users').doc(friendId).collection('poster_shares').add({
            'posterId': widget.poster.id,
            'posterTitle': widget.poster.title,
            'posterCity': widget.poster.city,
            'sharerName': currentUserName,
            'sharerId': currentUserId,
            'message': '$currentUserName preporučuje ovaj oglas',
            'createdAt': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          print('Error sharing to $friendId: $e');
          failed.add(friendId);
        }
      }

      if (mounted) {
        if (failed.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Podeljeno sa ${_selectedFriendIds.length} prijatelja!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Podeljeno ${_selectedFriendIds.length - failed.length}, ${failed.length} greške'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Greška: $e')));
    } finally {
      if (mounted) setState(() => _isSendingShare = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Podeli oglas'),
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
          // Search bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Pretraži prijatelje...',
                prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.orange.shade700, width: 2),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              ),
            ),
          ),

          // Filter button
          if (_selectedCategory != null || _selectedSubcategory != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
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
                        _applyFilters();
                      });
                    },
                    icon: Icon(Icons.close, size: 18, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),

          // Friends list
          Expanded(
            child: _isLoadingFriends
                ? Center(
                    child: CircularProgressIndicator(
                      color: Colors.orange.shade700,
                    ),
                  )
                : _allFriends.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 60,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Nemate prijatelja',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : _filteredFriends.isEmpty
                        ? Center(
                            child: Text(
                              'Nema prijatelja koji odgovaraju',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            itemCount: _filteredFriends.length,
                            itemBuilder: (context, index) {
                              final friend = _filteredFriends[index];
                              final isSelected = _selectedFriendIds.contains(friend['id']);
                              final isPending = _pendingShares.contains(friend['id']);
                              
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.orange.shade400
                                        : Colors.grey.shade200,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: CheckboxListTile(
                                  value: isSelected,
                                  onChanged: isPending
                                      ? null
                                      : (v) {
                                          setState(() {
                                            if (v == true) {
                                              _selectedFriendIds.add(friend['id']);
                                            } else {
                                              _selectedFriendIds.remove(friend['id']);
                                            }
                                          });
                                        },
                                  title: Text(
                                    friend['name'] ?? 'Nepoznato',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                  ),
                                  subtitle: isPending
                                      ? Text(
                                          'Već preporučeno',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        )
                                      : null,
                                  secondary: isPending
                                      ? Icon(
                                          Icons.hourglass_top,
                                          color: Colors.grey.shade500,
                                          size: 20,
                                        )
                                      : null,
                                  controlAffinity: ListTileControlAffinity.leading,
                                  activeColor: Colors.orange.shade700,
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBottomBar() {
    if (_selectedFriendIds.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: ElevatedButton(
        onPressed: _isSendingShare ? null : _sendShareNotifications,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange.shade700,
          disabledBackgroundColor: Colors.grey.shade400,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
          elevation: 0,
        ),
        child: _isSendingShare
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : Text(
                'Podeli sa ${_selectedFriendIds.length} ${_selectedFriendIds.length == 1 ? 'prijateljem' : 'prijatelja'}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
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
                            _applyFilters();
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
}
