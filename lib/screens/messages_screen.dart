import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // ADD THIS IMPORT
import 'package:firebase_auth/firebase_auth.dart';
import '../services/friends_service.dart';
import '../services/messaging_service.dart';
import 'chat_screen.dart';
import 'other_user_profile.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Poruke'),
          bottom: TabBar(
            tabs: [
              const Tab(icon: Icon(Icons.chat), text: 'RAZGOVORI'),
              const Tab(icon: Icon(Icons.people), text: 'KONTAKTI'),
              Tab(
                icon: Badge(
                  label: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: FriendsService.getFriendRequestsStream(),
                    builder: (context, snapshot) {
                      final count = snapshot.data?.length ?? 0;
                      return Text(count > 0 ? count.toString() : '');
                    },
                  ),
                  child: const Icon(Icons.notifications),
                ),
                text: 'ZAHTEVI',
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ConversationsTab(),
            _ContactsTab(),
            _FriendRequestsTab(),
          ],
        ),
      ),
    );
  }
}

/// CONVERSATIONS TAB
class _ConversationsTab extends StatelessWidget {
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: MessagingService.getConversationsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final conversations = snapshot.data?.docs ?? [];

        if (conversations.isEmpty) {
          return _buildEmptyState(
            icon: Icons.chat_bubble_outline,
            title: 'Nema razgovora',
            subtitle: 'Pokrenite razgovor sa prijateljem',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 8),
          itemCount: conversations.length,
          itemBuilder: (context, index) {
            return _ConversationTile(conversation: conversations[index]);
          },
        );
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 16)),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              
            },
            child: const Text('Pronađi prijatelje'),
          ),
        ],
      ),
    );
  }
}

/// CONTACTS TAB
class _ContactsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FriendsService.getFriendsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final friends = snapshot.data ?? [];

        if (friends.isEmpty) {
          return _buildEmptyState(
            icon: Icons.people_outline,
            title: 'Nema prijatelja',
            subtitle: 'Dodajte prijatelje da biste započeli razgovor',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 8),
          itemCount: friends.length,
          itemBuilder: (context, index) {
            return _ContactTile(friend: friends[index]);
          },
        );
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 16)),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

/// FRIEND REQUESTS TAB
class _FriendRequestsTab extends StatelessWidget {
  void _handleAcceptRequest(BuildContext context, String requestId) async {
    try {
      await FriendsService.acceptFriendRequest(requestId);
      _showSnackBar(context, 'Zahtev prihvaćen!');
    } catch (e) {
      _showSnackBar(context, 'Greška: $e');
    }
  }

  void _handleDeclineRequest(BuildContext context, String requestId) async {
    try {
      await FriendsService.cancelFriendRequest(requestId);
      _showSnackBar(context, 'Zahtev odbijen');
    } catch (e) {
      _showSnackBar(context, 'Greška: $e');
    }
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FriendsService.getFriendRequestsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final requests = snapshot.data ?? [];

        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.notifications_none, size: 80, color: Colors.grey),
                const SizedBox(height: 16),
                Text('Nema zahteva', style: const TextStyle(color: Colors.grey, fontSize: 16)),
                const SizedBox(height: 8),
                Text(
                  'Kada neko pošalje zahtev, pojaviće se ovde',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            return _FriendRequestTile(
              request: request,
              onAccept: () => _handleAcceptRequest(context, request['requestId']),
              onDecline: () => _handleDeclineRequest(context, request['requestId']),
            );
          },
        );
      },
    );
  }
}

/// CONVERSATION TILE WIDGET
class _ConversationTile extends StatelessWidget {
  final QueryDocumentSnapshot conversation;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

_ConversationTile({required this.conversation});

  @override
  Widget build(BuildContext context) {
    final data = conversation.data() as Map<String, dynamic>;
    final participants = List<String>.from(data['participants'] ?? []);
    final otherUserId = participants.firstWhere(
      (id) => id != _currentUser!.uid,
      orElse: () => '',
    );

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(otherUserId).get(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) {
          return const ListTile(title: Text('Učitavanje...'));
        }

        final userData = userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
        final userName = userData['name'] ?? 'Nepoznato';
        final userProfilePic = userData['profilePic'] ?? '';
        final lastMessage = data['lastMessage'] ?? '';
        final lastMessageTime = data['lastMessageTime'] as Timestamp?;
        final unreadCount = (data['unreadCount'] as Map<String, dynamic>?)?[_currentUser!.uid] as int? ?? 0;

        return ListTile(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatScreen(
                  otherUserId: otherUserId,
                  otherUserName: userName,
                ),
              ),
            );
          },
          leading: Stack(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundImage: userProfilePic.isNotEmpty
                    ? NetworkImage(userProfilePic)
                    : const AssetImage('assets/default_avatar.png') as ImageProvider,
              ),
              if (unreadCount > 0)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Text(
                      unreadCount > 9 ? '9+' : unreadCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          title: Text(
            userName,
            style: TextStyle(
              fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          subtitle: Text(
            lastMessage,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (lastMessageTime != null)
                Text(
                  _formatTime(lastMessageTime),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              const SizedBox(height: 4),
              if (unreadCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'NOVO',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  String _formatTime(Timestamp timestamp) {
    final now = DateTime.now();
    final messageTime = timestamp.toDate();
    final difference = now.difference(messageTime);

    if (difference.inDays == 0) {
      return '${messageTime.hour}:${messageTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Juče';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} dana';
    } else {
      return '${messageTime.day}.${messageTime.month}.';
    }
  }
}

/// CONTACT TILE WIDGET
class _ContactTile extends StatelessWidget {
  final Map<String, dynamic> friend;

  const _ContactTile({required this.friend});

  void _showProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OtherUserProfileScreen(
          userId: friend['id'],
          userName: friend['name'],
        ),
      ),
    );
  }

  void _startChat(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          otherUserId: friend['id'],
          otherUserName: friend['name'],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () => _showProfile(context),
      leading: CircleAvatar(
        radius: 25,
        backgroundImage: friend['profilePic'] != null && friend['profilePic'].isNotEmpty
            ? NetworkImage(friend['profilePic'])
            : const AssetImage('assets/default_avatar.png') as ImageProvider,
      ),
      title: Text(friend['name']),
      subtitle: Text(friend['city']?.isNotEmpty == true ? friend['city'] : 'Nije naveden grad'),
      trailing: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.message, color: Colors.white, size: 20),
        ),
        onPressed: () => _startChat(context),
      ),
    );
  }
}

/// FRIEND REQUEST TILE WIDGET
class _FriendRequestTile extends StatelessWidget {
  final Map<String, dynamic> request;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _FriendRequestTile({
    required this.request,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          radius: 30,
          backgroundImage: request['profilePic'] != null && request['profilePic'].isNotEmpty
              ? NetworkImage(request['profilePic'])
              : const AssetImage('assets/default_avatar.png') as ImageProvider,
        ),
        title: Text(request['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(request['city'] ?? ''),
            const SizedBox(height: 8),
            Text(
              'Želi da vas doda za prijatelja',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ActionButton(
              icon: Icons.check,
              color: Colors.green,
              onPressed: onAccept,
            ),
            const SizedBox(width: 8),
            _ActionButton(
              icon: Icons.close,
              color: Colors.red,
              onPressed: onDecline,
            ),
          ],
        ),
      ),
    );
  }
}

/// REUSABLE ACTION BUTTON
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
      onPressed: onPressed,
    );
  }
}