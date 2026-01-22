import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/friends_service.dart';
import '../services/messaging_service.dart';
import 'chat_screen.dart';
import 'group_chat_screen.dart'; // ADD THIS IMPORT
import 'other_user_profile.dart';
import 'create_group_screen.dart'; // ADD THIS IMPORT

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
      length: 2, // Changed to 2 tabs: Conversations and Contacts
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.orange.shade700,
          foregroundColor: Colors.white,
          title: const Text('Poruke'),
          actions: [
            // Add group creation button
            IconButton(
              icon: const Icon(Icons.group_add),
              tooltip: 'Kreiraj grupu',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreateGroupScreen(),
                  ),
                );
              },
            ),
          ],
          bottom: TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withOpacity(0.7),
            tabs: const [
              Tab(text: 'RAZGOVORI'),
              Tab(text: 'KONTAKTI'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _CombinedConversationsTab(), // NEW: Combined tab
            _ContactsAndRequestsTab(), // Contacts + Requests in one tab
          ],
        ),
      ),
    );
  }
}

/// COMBINED CONVERSATIONS TAB (Private + Groups)
class _CombinedConversationsTab extends StatelessWidget {
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: MessagingService.getCombinedConversationsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: Colors.orange,
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.orange, size: 60),
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

        final conversations = snapshot.data ?? [];

        if (conversations.isEmpty) {
          return _buildEmptyConversationsState();
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

  Widget _buildEmptyConversationsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 80, color: Colors.orange.shade300),
          const SizedBox(height: 20),
          Text(
            'Nema razgovora',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Pokrenite razgovor sa prijateljem ili kreirajte grupu',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            icon: const Icon(Icons.group_add),
            label: const Text('Kreiraj grupu'),
          ),
        ],
      ),
    );
  }
}

/// COMBINED CONTACTS AND REQUESTS TAB
class _ContactsAndRequestsTab extends StatefulWidget {
  @override
  State<_ContactsAndRequestsTab> createState() => _ContactsAndRequestsTabState();
}

class _ContactsAndRequestsTabState extends State<_ContactsAndRequestsTab> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: Colors.grey.shade50,
            child: TabBar(
              indicatorColor: Colors.orange.shade700,
              labelColor: Colors.orange.shade700,
              unselectedLabelColor: Colors.grey.shade600,
              tabs: const [
                Tab(text: 'PRIJATELJI'),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications, size: 16),
                      SizedBox(width: 4),
                      Text('ZAHTEVI'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _ContactsList(),
                _FriendRequestsList(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// CONTACTS LIST
class _ContactsList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FriendsService.getFriendsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: Colors.orange,
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Greška: ${snapshot.error}'),
          );
        }

        final friends = snapshot.data ?? [];

        if (friends.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 80, color: Colors.orange.shade300),
                const SizedBox(height: 20),
                Text(
                  'Nema prijatelja',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'Dodajte prijatelje da biste započeli razgovor',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
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
}

/// FRIEND REQUESTS LIST
class _FriendRequestsList extends StatelessWidget {
  void _handleAcceptRequest(BuildContext context, String requestId) async {
    try {
      await FriendsService.acceptFriendRequest(requestId);
      _showSnackBar(context, 'Zahtev prihvaćen!', Colors.green);
    } catch (e) {
      _showSnackBar(context, 'Greška: $e', Colors.red);
    }
  }

  void _handleDeclineRequest(BuildContext context, String requestId) async {
    try {
      await FriendsService.cancelFriendRequest(requestId);
      _showSnackBar(context, 'Zahtev odbijen', Colors.orange);
    } catch (e) {
      _showSnackBar(context, 'Greška: $e', Colors.red);
    }
  }

  void _showSnackBar(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FriendsService.getFriendRequestsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: Colors.orange,
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Greška: ${snapshot.error}'),
          );
        }

        final requests = snapshot.data ?? [];

        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.notifications_none, size: 80, color: Colors.orange.shade300),
                const SizedBox(height: 20),
                Text(
                  'Nema zahteva',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'Kada neko pošalje zahtev, pojaviće se ovde',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 14,
                    ),
                  ),
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

/// CONVERSATION TILE WIDGET (Supports both private and group)
class _ConversationTile extends StatelessWidget {
  final Map<String, dynamic> conversation;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  _ConversationTile({required this.conversation});

  @override
  Widget build(BuildContext context) {
    final type = conversation['type']; // 'private' or 'group'
    final isGroup = type == 'group';
    final unreadCount = conversation['unreadCount'] ?? 0;
    final lastMessage = conversation['lastMessage'] ?? '';
    final lastMessageTime = conversation['lastMessageTime'];

    return ListTile(
      onTap: () {
        if (isGroup) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GroupChatScreen(
                groupId: conversation['id'],
                groupName: conversation['name'],
              ),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                otherUserId: conversation['otherUserId'],
                otherUserName: conversation['name'],
              ),
            ),
          );
        }
      },
      leading: Stack(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isGroup ? Colors.orange.shade100 : Colors.blue.shade100,
            ),
            child: Icon(
              isGroup ? Icons.group : Icons.person,
              color: isGroup ? Colors.orange.shade700 : Colors.blue.shade700,
              size: 30,
            ),
          ),
          if (unreadCount > 0)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(6),
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
      title: Row(
        children: [
          Expanded(
            child: Text(
              conversation['name'],
              style: TextStyle(
                fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                color: Colors.grey.shade800,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isGroup)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Grupa',
                style: TextStyle(
                  color: Colors.orange.shade700,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      subtitle: Text(
        lastMessage,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.grey.shade600,
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
                color: Colors.grey.shade500,
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
        backgroundColor: Colors.orange.shade100,
        child: friend['profilePic'] != null && friend['profilePic'].isNotEmpty
            ? ClipOval(
                child: Image.network(
                  friend['profilePic'],
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                ),
              )
            : Icon(
                Icons.person,
                color: Colors.orange.shade700,
                size: 30,
              ),
      ),
      title: Text(
        friend['name'],
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        friend['city']?.isNotEmpty == true ? friend['city'] : 'Nije naveden grad',
        style: TextStyle(color: Colors.grey.shade600),
      ),
      trailing: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.orange.shade700,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
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
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: Colors.orange.shade100,
                  child: request['profilePic'] != null && request['profilePic'].isNotEmpty
                      ? ClipOval(
                          child: Image.network(
                            request['profilePic'],
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Icon(
                          Icons.person,
                          color: Colors.orange.shade700,
                          size: 30,
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request['name'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (request['city'] != null && request['city'].isNotEmpty)
                        Text(
                          request['city'],
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Želi da vas doda za prijatelja',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onAccept,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.check, size: 20),
                    label: const Text('Prihvati'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onDecline,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.close, size: 20),
                    label: const Text('Odbij'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}