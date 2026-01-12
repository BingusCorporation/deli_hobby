import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/friends_service.dart';
import 'chat_screen.dart';

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
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
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
        setState(() {
          _userData = doc.data() as Map<String, dynamic>;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadFriendshipStatus() async {
    final status = await FriendsService.getFriendshipStatus(widget.userId);
    setState(() => _friendshipStatus = status);
  }

  Future<void> _sendFriendRequest() async {
    try {
      await FriendsService.sendFriendRequest(widget.userId);
      await _loadFriendshipStatus();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zahtev za prijateljstvo poslat!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Greška: $e')),
      );
    }
  }

  Future<void> _acceptFriendRequest() async {
    try {
      await FriendsService.acceptFriendRequest(widget.userId);
      await _loadFriendshipStatus();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sada ste prijatelji!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Greška: $e')),
      );
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
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Prijatelj uklonjen')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Greška: $e')),
        );
      }
    }
  }

  Future<void> _cancelFriendRequest() async {
    try {
      await FriendsService.cancelFriendRequest(widget.userId);
      await _loadFriendshipStatus();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zahtev za prijateljstvo otkazan')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Greška: $e')),
      );
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.userName),
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
    final String? profilePic = data['profilePic'] as String?;
    final String? city = data['city'] as String?;
    final String? bio = data['bio'] as String?;
    final List<dynamic> hobbies = data['hobbies'] as List<dynamic>? ?? [];
    final List<dynamic> friends = data['friends'] as List<dynamic>? ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile header
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundImage: profilePic != null && profilePic.isNotEmpty
                      ? NetworkImage(profilePic)
                      : const AssetImage('assets/default_avatar.png')
                          as ImageProvider,
                ),
                const SizedBox(height: 16),
                Text(
                  data['name'] as String? ?? 'Nepoznato',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
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
          ),
          
          const SizedBox(height: 24),
          
          // Friendship status indicator
          _buildFriendshipStatusWidget(),
          
          const SizedBox(height: 16),
          
          // Bio section
          if (bio != null && bio.isNotEmpty) ...[
            const Text(
              'O korisniku',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              bio,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
          ],
          
          // Friends count
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.people, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Prijatelja: ${friends.length}',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Hobbies section
          const Text(
            'Hobiji',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (hobbies.isEmpty)
            const Text('Korisnik nije dodao hobije', style: TextStyle(color: Colors.grey))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: hobbies.map<Widget>((hobby) {
                return Chip(
                  label: Text(hobby.toString()),
                  backgroundColor: Colors.blue[50],
                );
              }).toList(),
            ),
          
          const SizedBox(height: 32),
          
          // Action buttons - FIXED: Removed duplicate message button
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(
                          otherUserId: widget.userId,
                          otherUserName: widget.userName,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.message),
                  label: const Text('Poruka'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildFriendActionButton(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFriendshipStatusWidget() {
    switch (_friendshipStatus) {
      case FriendshipStatus.friends:
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Prijatelji', style: TextStyle(color: Colors.green)),
            ],
          ),
        );
      case FriendshipStatus.pendingIncoming:
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.orange[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.pending, color: Colors.orange),
              SizedBox(width: 8),
              Text('Čeka potvrdu', style: TextStyle(color: Colors.orange)),
            ],
          ),
        );
      case FriendshipStatus.pendingOutgoing:
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.schedule, color: Colors.blue),
              SizedBox(width: 8),
              Text('Zahtev poslat', style: TextStyle(color: Colors.blue)),
            ],
          ),
        );
      case FriendshipStatus.self:
        return Container();
      case FriendshipStatus.none:
        return Container();
    }
  }

  Widget _buildFriendActionButton() {
    switch (_friendshipStatus) {
      case FriendshipStatus.friends:
        return ElevatedButton.icon(
          onPressed: _removeFriend,
          icon: const Icon(Icons.person_remove),
          label: const Text('Ukloni'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 15),
            backgroundColor: Colors.grey,
          ),
        );
      case FriendshipStatus.pendingIncoming:
        return ElevatedButton.icon(
          onPressed: _acceptFriendRequest,
          icon: const Icon(Icons.person_add),
          label: const Text('Prihvati'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 15),
          ),
        );
      case FriendshipStatus.pendingOutgoing:
        return ElevatedButton.icon(
          onPressed: _cancelFriendRequest,
          icon: const Icon(Icons.cancel),
          label: const Text('Otkaži'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 15),
            backgroundColor: Colors.grey,
          ),
        );
      case FriendshipStatus.none:
        return ElevatedButton.icon(
          onPressed: _sendFriendRequest,
          icon: const Icon(Icons.person_add),
          label: const Text('Dodaj'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 15),
          ),
        );
      case FriendshipStatus.self:
        return ElevatedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.person),
          label: const Text('Vi ste'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 15),
          ),
        );
    }
  }
}