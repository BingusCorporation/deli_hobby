// screens/other_user_profile.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/friends_service.dart';
import 'chat_screen.dart';
import 'friends_list_screen.dart';

class OtherUserProfileScreen extends StatefulWidget {
  final String userId;
  final String userName;

  const OtherUserProfileScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<OtherUserProfileScreen> createState() => _OtherUserProfileScreenState();
}

class _OtherUserProfileScreenState extends State<OtherUserProfileScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  FriendshipStatus _friendshipStatus = FriendshipStatus.none;
  String? _friendRequestId;
  int _friendCount = 0;
  
  // Flag to prevent multiple simultaneous friend count queries
  bool _isCountingFriends = false;

  @override
  void initState() {
    super.initState();
    _loadUserDataAndStatus();
    // Load friend count after a short delay to prioritize UI
    Future.delayed(const Duration(milliseconds: 500), _loadFriendCount);
  }

  // Combined loading function to reduce Firestore calls
  Future<void> _loadUserDataAndStatus() async {
    try {
      setState(() => _isLoading = true);
      
      // Load user data using FriendsService cache
      if (widget.userId.isNotEmpty) {
        // Precache this user for future use
        await FriendsService.precacheUsers([widget.userId]);
        
        // Get user data from cache or Firestore
        final userData = await _getUserData(widget.userId);
        if (userData != null) {
          setState(() => _userData = userData);
        }
      }
      
      // Load friendship status in parallel with user data
      await _loadFriendshipStatus();
    } catch (e) {
      print('Error loading user data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Helper to get user data with caching
  Future<Map<String, dynamic>?> _getUserData(String userId) async {
    try {
      // First check if we need to fetch user data
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
    } catch (e) {
      print('Error getting user data: $e');
    }
    return null;
  }

  // Optimized friendship status loading using FriendsService
  Future<void> _loadFriendshipStatus() async {
    try {
      if (_currentUser == null || widget.userId.isEmpty) return;
      
      // Use the optimized FriendsService method
      final status = await FriendsService.getFriendshipStatus(widget.userId);
      
      // Get request ID if there's a pending request
      if (status == FriendshipStatus.pendingIncoming || 
          status == FriendshipStatus.pendingOutgoing) {
        await _loadFriendRequestId();
      }
      
      if (mounted) {
        setState(() => _friendshipStatus = status);
      }
    } catch (e) {
      print('Error loading friendship status: $e');
    }
  }

  // Load friend request ID only when needed
  Future<void> _loadFriendRequestId() async {
    try {
      if (_currentUser == null) return;
      
      // Query for pending request
      final querySnapshot = await _firestore
          .collection('friend_requests')
          .where('status', isEqualTo: 'pending')
          .where(Filter.or(
            Filter.and(
              Filter('senderId', isEqualTo: _currentUser.uid),
              Filter('receiverId', isEqualTo: widget.userId),
            ),
            Filter.and(
              Filter('senderId', isEqualTo: widget.userId),
              Filter('receiverId', isEqualTo: _currentUser.uid),
            ),
          ))
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isNotEmpty && mounted) {
        setState(() => _friendRequestId = querySnapshot.docs.first.id);
      }
    } catch (e) {
      print('Error loading friend request ID: $e');
    }
  }

  // Optimized friend count with caching
  Future<void> _loadFriendCount() async {
    if (_isCountingFriends || widget.userId.isEmpty) return;
    
    try {
      _isCountingFriends = true;
      
      // Use count query for efficiency
      final snapshot = await _firestore
          .collection('friendships')
          .where('userId', isEqualTo: widget.userId)
          .count()
          .get();

      if (mounted) {
        setState(() => _friendCount = snapshot.count ?? 0);
      }
    } catch (e) {
      debugPrint('Greška pri učitavanju broja prijatelja: $e');
    } finally {
      _isCountingFriends = false;
    }
  }

  // Friend request actions
  Future<void> _sendFriendRequest() async {
    try {
      await FriendsService.sendFriendRequest(widget.userId);
      await _loadFriendshipStatus();
      _showSnackBar('Zahtev za prijateljstvo poslat!');
    } catch (e) {
      _showSnackBar('Greška: $e');
    }
  }

  Future<void> _acceptFriendRequest() async {
    try {
      if (_friendRequestId == null || _friendRequestId!.isEmpty) {
        await _loadFriendRequestId();
      }
      
      if (_friendRequestId == null || _friendRequestId!.isEmpty) {
        _showSnackBar('Friend request not found!');
        return;
      }

      await FriendsService.acceptFriendRequest(_friendRequestId!);
      await _loadFriendshipStatus();
      await _loadFriendCount(); // Refresh friend count
      _showSnackBar('Sada ste prijatelji!');
    } catch (e) {
      _showSnackBar('Greška: $e');
    }
  }

  Future<void> _cancelFriendRequest() async {
    try {
      if (_friendRequestId == null || _friendRequestId!.isEmpty) {
        await _loadFriendRequestId();
      }
      
      if (_friendRequestId == null || _friendRequestId!.isEmpty) {
        _showSnackBar('Friend request not found!');
        return;
      }

      await FriendsService.cancelFriendRequest(_friendRequestId!);
      await _loadFriendshipStatus();
      _showSnackBar('Zahtev za prijateljstvo otkazan');
    } catch (e) {
      _showSnackBar('Greška: $e');
    }
  }

  Future<void> _declineFriendRequest() async {
    try {
      if (_friendRequestId == null || _friendRequestId!.isEmpty) {
        await _loadFriendRequestId();
      }
      
      if (_friendRequestId == null || _friendRequestId!.isEmpty) {
        _showSnackBar('Friend request not found!');
        return;
      }

      await FriendsService.declineFriendRequest(_friendRequestId!);
      await _loadFriendshipStatus();
      _showSnackBar('Zahtev odbijen');
    } catch (e) {
      _showSnackBar('Greška: $e');
    }
  }

  Future<void> _removeFriend() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ukloni prijatelja'),
        content: const Text('Da li ste sigurni da želite da uklonite ovog prijatelja?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Otkaži'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ukloni', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FriendsService.removeFriend(widget.userId);
        await _loadFriendshipStatus();
        await _loadFriendCount(); // Refresh friend count
        _showSnackBar('Prijatelj uklonjen');
      } catch (e) {
        _showSnackBar('Greška: $e');
      }
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
        )
      );
    }
  }

  void _navigateToChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          otherUserId: widget.userId,
          otherUserName: widget.userName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.userName),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          if (_friendshipStatus == FriendshipStatus.pendingIncoming)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'accept') {
                  _acceptFriendRequest();
                } else if (value == 'decline') {
                  _declineFriendRequest();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'accept',
                  child: Row(
                    children: [
                      Icon(Icons.check, color: Colors.green),
                      SizedBox(width: 8),
                      Text('Prihvati zahtev'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'decline',
                  child: Row(
                    children: [
                      Icon(Icons.close, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Odbij zahtev'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _userData == null
              ? const Center(child: Text('Korisnik nije pronađen'))
              : _buildProfile(),
    );
  }

  Widget _buildProfile() {
    final data = _userData!;
    final String? profilePic = data['profilePic'];
    final String? city = data['city'];
    final String? bio = data['bio'];
    final List<dynamic> hobbies = data['hobbies'] ?? [];

    return Container(
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
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileHeader(profilePic, data['name'], city),
            const SizedBox(height: 24),
            _buildFriendshipStatus(),
            const SizedBox(height: 16),
            if (bio != null && bio.isNotEmpty) _buildBioSection(bio),
            _buildFriendsCount(),
            const SizedBox(height: 24),
            _buildHobbiesSection(hobbies),
            const SizedBox(height: 32),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(String? profilePic, String? name, String? city) {
    return Center(
      child: Column(
        children: [
          CircleAvatar(
            radius: 55,
            backgroundColor: Colors.orange.shade100,
            backgroundImage: profilePic != null && profilePic.isNotEmpty
                ? NetworkImage(profilePic)
                : null,
            child: profilePic == null || profilePic.isEmpty
                ? Icon(
                    Icons.person,
                    size: 45,
                    color: Colors.orange.shade400,
                  )
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            name ?? 'Nepoznato',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.orange.shade900,
            ),
            textAlign: TextAlign.center,
          ),
          if (city != null && city.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(city, style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFriendshipStatus() {
    switch (_friendshipStatus) {
      case FriendshipStatus.friends:
        return _StatusChip(
          icon: Icons.check_circle,
          text: 'Prijatelji',
          color: Colors.green,
        );
      case FriendshipStatus.pendingIncoming:
        return _StatusChip(
          icon: Icons.pending,
          text: 'Čeka potvrdu',
          color: Colors.orange,
        );
      case FriendshipStatus.pendingOutgoing:
        return _StatusChip(
          icon: Icons.schedule,
          text: 'Zahtev poslat',
          color: Colors.blue,
        );
      case FriendshipStatus.none:
        return const SizedBox();
      case FriendshipStatus.self:
        return const SizedBox(); // Should not happen in OtherUserProfileScreen
    }
  }

  Widget _buildBioSection(String bio) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'O korisniku',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(bio, style: const TextStyle(fontSize: 16)),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildFriendsCount() {
    return GestureDetector(
      onTap: _friendCount > 0
          ? () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FriendsListScreen(userId: widget.userId),
                ),
              )
          : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.orange.shade50,
              Colors.amber.shade50,
            ],
          ),
          border: Border.all(color: Colors.orange.shade200),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$_friendCount Prijatelji',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.orange.shade900,
              ),
            ),
            if (_friendCount > 0)
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.orange.shade700,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHobbiesSection(List<dynamic> hobbies) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Hobiji',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (hobbies.isEmpty)
          const Text(
            'Korisnik nije dodao hobije',
            style: TextStyle(color: Colors.grey),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: hobbies.map<Widget>((hobby) {
              return Chip(
                label: Text(hobby.toString()),
                backgroundColor: Colors.orange[50],
                side: BorderSide(color: Colors.orange[200] ?? Colors.orange),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _navigateToChat,
            icon: const Icon(Icons.message),
            label: const Text('Pošalji poruku'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
              backgroundColor: Colors.blue,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildFriendActionButton(),
      ],
    );
  }

  Widget _buildFriendActionButton() {
    switch (_friendshipStatus) {
      case FriendshipStatus.friends:
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _removeFriend,
            icon: const Icon(Icons.person_remove, color: Colors.red),
            label: const Text(
              'Ukloni prijatelja',
              style: TextStyle(color: Colors.red),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
              side: const BorderSide(color: Colors.red),
            ),
          ),
        );
      case FriendshipStatus.pendingIncoming:
        return Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _acceptFriendRequest,
                icon: const Icon(Icons.check),
                label: const Text('Prihvati'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  backgroundColor: Colors.green,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _declineFriendRequest,
                icon: const Icon(Icons.close),
                label: const Text('Odbij'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  side: const BorderSide(color: Colors.red),
                ),
              ),
            ),
          ],
        );
      case FriendshipStatus.pendingOutgoing:
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _cancelFriendRequest,
            icon: const Icon(Icons.cancel),
            label: const Text('Otkaži zahtev'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
              side: BorderSide(color: Colors.grey[600] ?? Colors.grey),
            ),
          ),
        );
      case FriendshipStatus.none:
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _sendFriendRequest,
            icon: const Icon(Icons.person_add),
            label: const Text('Dodaj za prijatelja'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
              backgroundColor: Colors.orange,
            ),
          ),
        );
      case FriendshipStatus.self:
        return const SizedBox(); // Should not happen
    }
  }
}

/// REUSABLE STATUS CHIP WIDGET
class _StatusChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _StatusChip({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}