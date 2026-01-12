import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Poruke'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.chat), text: 'RAZGOVORI'),
              Tab(icon: Icon(Icons.people), text: 'KONTAKTI'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // MESSAGES TAB
            _buildConversationsTab(),
            
            // CONTACTS TAB
            _buildContactsTab(),
          ],
        ),
      ),
    );
  }

  /// Build conversations tab
  Widget _buildConversationsTab() {
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
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'Nema razgovora',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  'Pokrenite razgovor sa prijateljem',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }
        
        return ListView.builder(
          padding: const EdgeInsets.only(top: 8),
          itemCount: conversations.length,
          itemBuilder: (context, index) {
            final conversation = conversations[index];
            final data = conversation.data() as Map<String, dynamic>;
            final participants = List<String>.from(data['participants'] ?? []);
            final otherUserId = participants.firstWhere(
              (id) => id != _auth.currentUser!.uid,
              orElse: () => '',
            );
            
            return FutureBuilder<DocumentSnapshot>(
              future: _firestore.collection('users').doc(otherUserId).get(),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData) {
                  return const ListTile(
                    title: Text('Učitavanje...'),
                  );
                }
                
                final userData = userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
                final userName = userData['name'] ?? 'Nepoznato';
                final userProfilePic = userData['profilePic'] ?? '';
                final lastMessage = data['lastMessage'] ?? '';
                final lastMessageTime = data['lastMessageTime'] as Timestamp?;
                final unreadCount = (data['unreadCount'] as Map<String, dynamic>?)?[_auth.currentUser!.uid] as int? ?? 0;
                
                return ConversationTile(
                  userId: otherUserId,
                  userName: userName,
                  profilePic: userProfilePic,
                  lastMessage: lastMessage,
                  lastMessageTime: lastMessageTime,
                  unreadCount: unreadCount,
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
                );
              },
            );
          },
        );
      },
    );
  }

  /// Build contacts tab
  Widget _buildContactsTab() {
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
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 80, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'Nema prijatelja',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  'Dodajte prijatelje da biste započeli razgovor',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }
        
        return ListView.builder(
          padding: const EdgeInsets.only(top: 8),
          itemCount: friends.length,
          itemBuilder: (context, index) {
            final friend = friends[index];
            
            return ContactTile(
              userId: friend['id'],
              userName: friend['name'],
              profilePic: friend['profilePic'],
              city: friend['city'],
              onTapProfile: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OtherUserProfileScreen(
                      userId: friend['id'],
                      userName: friend['name'],
                    ),
                  ),
                );
              },
              onTapMessage: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(
                      otherUserId: friend['id'],
                      otherUserName: friend['name'],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

/// Conversation tile widget
class ConversationTile extends StatelessWidget {
  final String userId;
  final String userName;
  final String profilePic;
  final String lastMessage;
  final Timestamp? lastMessageTime;
  final int unreadCount;
  final VoidCallback onTap;

  const ConversationTile({
    super.key,
    required this.userId,
    required this.userName,
    required this.profilePic,
    required this.lastMessage,
    this.lastMessageTime,
    this.unreadCount = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    String timeText = '';
    if (lastMessageTime != null) {
      final now = DateTime.now();
      final messageTime = lastMessageTime!.toDate();
      final difference = now.difference(messageTime);
      
      if (difference.inDays == 0) {
        timeText = '${messageTime.hour}:${messageTime.minute.toString().padLeft(2, '0')}';
      } else if (difference.inDays == 1) {
        timeText = 'Juče';
      } else if (difference.inDays < 7) {
        timeText = '${difference.inDays} dana';
      } else {
        timeText = '${messageTime.day}.${messageTime.month}.';
      }
    }

    return ListTile(
      onTap: onTap,
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundImage: profilePic.isNotEmpty
                ? NetworkImage(profilePic)
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
          if (timeText.isNotEmpty)
            Text(
              timeText,
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
              child: Text(
                'NOVO',
                style: const TextStyle(
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
}

/// Contact tile widget
class ContactTile extends StatelessWidget {
  final String userId;
  final String userName;
  final String profilePic;
  final String city;
  final VoidCallback onTapProfile;
  final VoidCallback onTapMessage;

  const ContactTile({
    super.key,
    required this.userId,
    required this.userName,
    required this.profilePic,
    required this.city,
    required this.onTapProfile,
    required this.onTapMessage,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTapProfile,
      leading: CircleAvatar(
        radius: 25,
        backgroundImage: profilePic.isNotEmpty
            ? NetworkImage(profilePic)
            : const AssetImage('assets/default_avatar.png') as ImageProvider,
      ),
      title: Text(userName),
      subtitle: Text(city.isNotEmpty ? city : 'Nije naveden grad'),
      trailing: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.message,
            color: Colors.white,
            size: 20,
          ),
        ),
        onPressed: onTapMessage,
      ),
    );
  }
}