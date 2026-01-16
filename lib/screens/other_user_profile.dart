import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/friends_service.dart';
import 'chat_screen.dart';

enum FriendshipStatus { self, friends, pendingIncoming, pendingOutgoing, none }

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

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadFriendshipStatus();
  }

  Future<void> _loadUserData() async {
    try {
      final doc = await _firestore.collection('users').doc(widget.userId).get();
      if (doc.exists) {
        setState(() => _userData = doc.data() as Map<String, dynamic>);
      }
    } catch (e) {
      print('Error loading user data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadFriendshipStatus() async {
    final status = await FriendsService.getFriendshipStatus(widget.userId);
    if (mounted) setState(() => _friendshipStatus = status);
  }

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
      final requestId = await _getFriendRequestId();
      if (requestId.isEmpty) {
        _showSnackBar('Friend request not found!');
        return;
      }

      await FriendsService.acceptFriendRequest(requestId);
      await _loadFriendshipStatus();
      _showSnackBar('Sada ste prijatelji!');
    } catch (e) {
      _showSnackBar('Greška: $e');
    }
  }

  Future<void> _cancelFriendRequest() async {
    try {
      final requestId = await _getFriendRequestId();
      if (requestId.isEmpty) {
        _showSnackBar('Friend request not found!');
        return;
      }

      await FriendsService.cancelFriendRequest(requestId);
      await _loadFriendshipStatus();
      _showSnackBar('Zahtev za prijateljstvo otkazan');
    } catch (e) {
      _showSnackBar('Greška: $e');
    }
  }

  Future<String> _getFriendRequestId() async {
    try {
      // Check for incoming request
      final incomingQuery = await _firestore
          .collection('friend_requests')
          .where('senderId', isEqualTo: widget.userId)
          .where('receiverId', isEqualTo: _currentUser!.uid)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (incomingQuery.docs.isNotEmpty) return incomingQuery.docs.first.id;

      // Check for outgoing request
      final outgoingQuery = await _firestore
          .collection('friend_requests')
          .where('senderId', isEqualTo: _currentUser!.uid)
          .where('receiverId', isEqualTo: widget.userId)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (outgoingQuery.docs.isNotEmpty) return outgoingQuery.docs.first.id;

      return '';
    } catch (e) {
      print('Error getting request ID: $e');
      return '';
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
        _showSnackBar('Prijatelj uklonjen');
      } catch (e) {
        _showSnackBar('Greška: $e');
      }
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
      appBar: AppBar(title: Text(widget.userName)),
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
    final List<dynamic> friends = data['friends'] ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileHeader(profilePic, data['name'], city),
          const SizedBox(height: 24),
          _buildFriendshipStatus(),
          const SizedBox(height: 16),
          if (bio != null && bio.isNotEmpty) _buildBioSection(bio),
          _buildFriendsCount(friends.length),
          const SizedBox(height: 24),
          _buildHobbiesSection(hobbies),
          const SizedBox(height: 32),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(String? profilePic, String? name, String? city) {
    return Center(
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundImage: profilePic != null && profilePic.isNotEmpty
                ? NetworkImage(profilePic)
                : const AssetImage('assets/default_avatar.png') as ImageProvider,
          ),
          const SizedBox(height: 16),
          Text(name ?? 'Nepoznato', style: Theme.of(context).textTheme.headlineSmall),
          if (city != null && city.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.location_on, size: 16),
                  const SizedBox(width: 4),
                  Text(city),
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
      case FriendshipStatus.self:
      case FriendshipStatus.none:
        return const SizedBox();
    }
  }

  Widget _buildBioSection(String bio) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('O korisniku', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(bio, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildFriendsCount(int count) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.people, color: Colors.blue),
          const SizedBox(width: 8),
          Text('Prijatelja: $count', style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildHobbiesSection(List<dynamic> hobbies) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Hobiji', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (hobbies.isEmpty)
          const Text('Korisnik nije dodao hobije', style: TextStyle(color: Colors.grey))
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: hobbies.map<Widget>((hobby) {
              return Chip(label: Text(hobby.toString()), backgroundColor: Colors.blue[50]);
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _navigateToChat,
            icon: const Icon(Icons.message),
            label: const Text('Poruka'),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(child: _buildFriendActionButton()),
      ],
    );
  }

  Widget _buildFriendActionButton() {
    switch (_friendshipStatus) {
      case FriendshipStatus.friends:
        return _ActionButton(
          onPressed: _removeFriend,
          icon: Icons.person_remove,
          label: 'Ukloni',
          color: Colors.grey,
        );
      case FriendshipStatus.pendingIncoming:
        return _ActionButton(
          onPressed: _acceptFriendRequest,
          icon: Icons.person_add,
          label: 'Prihvati',
        );
      case FriendshipStatus.pendingOutgoing:
        return _ActionButton(
          onPressed: _cancelFriendRequest,
          icon: Icons.cancel,
          label: 'Otkaži',
          color: Colors.grey,
        );
      case FriendshipStatus.none:
        return _ActionButton(
          onPressed: _sendFriendRequest,
          icon: Icons.person_add,
          label: 'Dodaj',
        );
      case FriendshipStatus.self:
        return _ActionButton(
          onPressed: null,
          icon: Icons.person,
          label: 'Vi ste',
        );
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
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

/// REUSABLE ACTION BUTTON WIDGET
class _ActionButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  final Color? color;

  const _ActionButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 15),
        backgroundColor: color,
      ),
    );
  }
}