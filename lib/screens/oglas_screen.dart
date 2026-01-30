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
    Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (context) => OtherUserProfileScreen(userId: userId, userName: userName)
      )
    );
  }

  void _sendMessage(String receiverId, String receiverName) {
    Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (context) => ChatScreen(otherUserId: receiverId, otherUserName: receiverName)
      )
    );
  }

  void _editPoster(Poster poster) {
    Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (context) => CreateOglasScreen(posterToEdit: poster)
      )
    );
  }

  void _showDeleteDialog(Poster poster) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Obriši oglas'),
        content: const Text('Da li si siguran da želiš da obrišeš ovaj oglas? Ova akcija se ne može poništiti.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text('Odustani')
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deletePoster(poster);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
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
    Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (context) => SharePosterScreen(poster: poster)
      )
    );
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
            body: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFFF8F0),  
                    Color(0xFFFFF3E0), 
                    Colors.white,
                  ],
                ),
              ),
              child: Center(
                child: CircularProgressIndicator(
                  color: Colors.orange.shade700,
                ),
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
            body: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFFF8F0),
                    Color(0xFFFFF3E0),
                    Colors.white,
                  ],
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error, color: Colors.orange.shade700, size: 60),
                    const SizedBox(height: 16),
                    Text(
                      'Greška: ${snapshot.error}',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
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
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFFFF8F0),  
                  Color(0xFFFFF3E0),  
                  Colors.white,      
                ],
                stops: [0.0, 0.3, 1.0],
              ),
            ),
            child: SingleChildScrollView(
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
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey.shade100,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.network(
                        poster.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey.shade200,
                          child: Icon(
                            Icons.broken_image,
                            color: Colors.grey.shade400,
                            size: 60,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),

                  Text(
                    poster.title,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),  
                    ),
                  ),
                  const SizedBox(height: 16),


                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: Colors.grey.shade200,
                        width: 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Opis',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            poster.description,
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey.shade800,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

            
                  if (poster.city != null)
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: Colors.grey.shade200,
                          width: 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              color: Colors.orange.shade600,
                              size: 24,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Lokacija',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    poster.city!,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF333333),
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

                  if (poster.requiredHobbies.isNotEmpty) ...[
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: Colors.grey.shade200,
                          width: 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Traženi hobiji',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF333333),
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
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.blue.shade100,
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    h,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.blue.shade700,
                                      fontWeight: FontWeight.w500,
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

                  Card(
  elevation: 1,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
    side: BorderSide(
      color: Colors.grey.shade200,
      width: 1,
    ),
  ),
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: Row(
      children: [
        GestureDetector(
          onTap: () => _viewUserProfile(poster.userId, poster.userName),
          child: CircleAvatar(
            radius: 28,
            backgroundColor: Colors.orange.shade100,
            backgroundImage: poster.userProfilePic != null && poster.userProfilePic!.isNotEmpty
                ? NetworkImage(poster.userProfilePic!)
                : null,
            child: poster.userProfilePic == null || poster.userProfilePic!.isEmpty
                ? Text(
                    poster.userName.isNotEmpty ? poster.userName[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade700,
                    ),
                  )
                : null,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => _viewUserProfile(poster.userId, poster.userName),
                child: Text(
                  poster.userName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Color(0xFF333333),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 14,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formatDate(poster.createdAt),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        FutureBuilder<bool>(
          future: _isMatchingFuture,
          builder: (context, matchSnapshot) {
            if (matchSnapshot.data == true) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.orange.shade200,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.star,
                      size: 14,
                      color: Colors.orange.shade700,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Za vas',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade700,
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
const SizedBox(height: 32),
                  if (_currentUser != null && _currentUser.uid != poster.userId)
                    Column(
                      children: [
                        ElevatedButton(
                          onPressed: () =>
                              _viewUserProfile(poster.userId, poster.userName),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 1,
                            shadowColor: Colors.blue.shade200,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.person, size: 20),
                              const SizedBox(width: 10),
                              const Text(
                                'Pogledaj profil',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        
                        ElevatedButton(
                          onPressed: () =>
                              _sendMessage(poster.userId, poster.userName),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 1,
                            shadowColor: Colors.green.shade200,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.message, size: 20),
                              const SizedBox(width: 10),
                              const Text(
                                'Pošalji poruku',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 24),
                ],
              ),
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

      final sharesSnapshot = await _firestore
          .collection('posters')
          .doc(widget.poster.id)
          .collection('shares')
          .where('status', isEqualTo: 'pending')
          .get();
      
      final pendingSet = <String>{};
      
      for (final doc in sharesSnapshot.docs) {
        final recipientId = doc['recipientId'] as String?;
        if (recipientId != null) {
          final userShare = await _firestore
              .collection('users')
              .doc(recipientId)
              .collection('poster_shares')
              .doc(doc.id)
              .get();
          
          if (userShare.exists) {
            pendingSet.add(recipientId);
          } else {
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
            const SnackBar(
              content: Text('Podeljeno sa prijateljima!'),
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFF8F0),
              Color(0xFFFFF3E0),
              Colors.white,
            ],
            stops: [0.0, 0.2, 1.0],
          ),
        ),
        child: Column(
          children: [
            // Search 
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Pretraži prijatelje...',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.orange.shade600, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                ),
              ),
            ),


            if (_selectedCategory != null || _selectedSubcategory != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.filter_alt,
                            size: 16,
                            color: Colors.blue.shade700,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _selectedSubcategory != null 
                                ? '$_selectedCategory > $_selectedSubcategory'
                                : _selectedCategory!,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.blue.shade700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedCategory = null;
                                _selectedSubcategory = null;
                                _applyFilters();
                              });
                            },
                            child: Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),


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
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemCount: _filteredFriends.length,
                              itemBuilder: (context, index) {
                                final friend = _filteredFriends[index];
                                final isSelected = _selectedFriendIds.contains(friend['id']);
                                final isPending = _pendingShares.contains(friend['id']);
                                
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  elevation: 1,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: isSelected 
                                          ? Colors.orange.shade400
                                          : Colors.grey.shade200,
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 22,
                                          backgroundColor: Colors.grey.shade100,
                                          child: Text(
                                            friend['name']?[0] ?? '?',
                                            style: const TextStyle(
                                              color: Colors.grey,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                friend['name'] ?? 'Nepoznato',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 15,
                                                  color: Color(0xFF333333),
                                                ),
                                              ),
                                              if (isPending)
                                                Text(
                                                  'Već preporučeno',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        if (isPending)
                                          Icon(
                                            Icons.check_circle,
                                            color: Colors.green.shade600,
                                            size: 20,
                                          )
                                        else
                                          Checkbox(
                                            value: isSelected,
                                            onChanged: (v) {
                                              setState(() {
                                                if (v == true) {
                                                  _selectedFriendIds.add(friend['id']);
                                                } else {
                                                  _selectedFriendIds.remove(friend['id']);
                                                }
                                              });
                                            },
                                            activeColor: Colors.orange.shade700,
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBottomBar() {
    if (_selectedFriendIds.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
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
          padding: const EdgeInsets.symmetric(vertical: 16),
          elevation: 1,
          shadowColor: Colors.orange.shade200,
        ),
        child: _isSendingShare
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.send, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'Podeli sa ${_selectedFriendIds.length} ${_selectedFriendIds.length == 1 ? 'prijateljem' : 'prijatelja'}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
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
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF333333),
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
                    value: tempCategory,
                    decoration: InputDecoration(
                      labelText: 'Kategorija',
                      labelStyle: const TextStyle(color: Colors.grey),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.orange.shade600),
                      ),
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
                      value: tempSubcategory,
                      decoration: InputDecoration(
                        labelText: 'Podkategorija (opciono)',
                        labelStyle: const TextStyle(color: Colors.grey),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.orange.shade600),
                        ),
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
                  const SizedBox(height: 24),
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
                        child: const Text(
                          'Obriši filter',
                          style: TextStyle(color: Colors.grey),
                        ),
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
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }
}