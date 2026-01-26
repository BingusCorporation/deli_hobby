// screens/group_chat_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/messaging_service.dart';
import '../services/friends_service.dart';

class GroupChatScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupChatScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ScrollController _scrollController = ScrollController();
  
  bool _isSending = false;
  bool _showInfoPanel = false;
  bool _isLoadingMembers = true;
  
  Map<String, String> _userNames = {};
  List<Map<String, dynamic>> _groupMembers = [];
  Map<String, dynamic>? _groupInfo;
  String? _currentUserRole;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _scrollToBottom();
    _loadGroupInfoAndMembers();
    _markGroupMessagesAsRead();
  }

  // Load group info and members in one go
  Future<void> _loadGroupInfoAndMembers() async {
    try {
      setState(() => _isLoadingMembers = true);
      
      // Load group information
      final groupDoc = await _firestore
          .collection('groups')
          .doc(widget.groupId)
          .get();
      
      if (!groupDoc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Grupa ne postoji')),
          );
          Navigator.pop(context);
        }
        return;
      }
      
      final groupData = groupDoc.data()!;
      setState(() => _groupInfo = groupData);
      
      // Check if current user is admin
      final currentUserId = _auth.currentUser!.uid;
      final adminId = groupData['adminId'] as String?;
      _isAdmin = adminId == currentUserId;
      
      // Load current user's role from user_groups
      final userGroupDoc = await _firestore
          .collection('user_groups')
          .doc('${currentUserId}_${widget.groupId}')
          .get();
      
      if (userGroupDoc.exists) {
        _currentUserRole = userGroupDoc['role'] as String?;
      }
      
      // Load participants
      final participants = List<String>.from(groupData['participants'] ?? []);
      
      // Verify current user is in the group
      if (!participants.contains(currentUserId)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Niste član ove grupe')),
          );
          Navigator.pop(context);
        }
        return;
      }
      
      await _loadGroupMembers(participants, adminId);
      
    } catch (e) {
      print('Error loading group info: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Greška: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingMembers = false);
      }
    }
  }

  // Load group members with their details
  Future<void> _loadGroupMembers(List<String> participantIds, String? adminId) async {
    final members = <Map<String, dynamic>>[];
    
    // Process in batches of 10 due to Firestore limits
    for (int i = 0; i < participantIds.length; i += 10) {
      final batchIds = participantIds.sublist(
        i,
        i + 10 < participantIds.length ? i + 10 : participantIds.length,
      );
      
      final usersSnapshot = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: batchIds)
          .get();
      
      for (final doc in usersSnapshot.docs) {
        final userId = doc.id;
        final userData = doc.data();
        final isAdmin = userId == adminId;
        
        // Get user's role from user_groups
        final userGroupDoc = await _firestore
            .collection('user_groups')
            .doc('${userId}_${widget.groupId}')
            .get();
        
        final role = userGroupDoc.exists 
            ? userGroupDoc['role'] as String? ?? 'member'
            : 'member';
        
        final member = {
          'id': userId,
          'name': userData['name'] ?? 'Nepoznato',
          'email': userData['email'] ?? '',
          'profilePic': userData['profilePic'],
          'isAdmin': isAdmin,
          'role': role,
          'joinedAt': userGroupDoc.exists 
              ? (userGroupDoc['joinedAt'] as Timestamp?)?.toDate()
              : null,
        };
        
        members.add(member);
        _userNames[userId] = member['name'];
      }
    }
    
    if (mounted) {
      setState(() => _groupMembers = members);
    }
  }

  Future<void> _markGroupMessagesAsRead() async {
    try {
      final currentUserId = _auth.currentUser!.uid;
      final userGroupDocRef = _firestore
          .collection('user_groups')
          .doc('${currentUserId}_${widget.groupId}');
      
      final userGroupDoc = await userGroupDocRef.get();
      
      if (userGroupDoc.exists && (userGroupDoc['unreadCount'] as int? ?? 0) > 0) {
        await userGroupDocRef.update({'unreadCount': 0});
      }
    } catch (e) {
      print('Error marking group messages as read: $e');
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      });
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isSending) return;
    
    setState(() => _isSending = true);
    
    try {
      await MessagingService.sendGroupMessage(
        groupId: widget.groupId,
        message: message,
      );
      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Greška pri slanju poruke: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSending = false);
    }
  }

  // Leave group functionality
  Future<void> _leaveGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Napusti grupu'),
        content: _isAdmin && _groupMembers.length > 1
            ? const Text(
                'Vi ste admin grupe. Ako napustite grupu, admin prava će biti preneta drugom članu. Da li ste sigurni?',
              )
            : const Text('Da li ste sigurni da želite napustiti ovu grupu?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Otkaži'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Napusti',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    try {
      final currentUserId = _auth.currentUser!.uid;
      
      // Start a batch write
      final batch = _firestore.batch();
      
      // Get group document reference
      final groupDocRef = _firestore.collection('groups').doc(widget.groupId);
      final groupDoc = await groupDocRef.get();
      
      if (!groupDoc.exists) {
        throw Exception('Grupa ne postoji');
      }
      
      final groupData = groupDoc.data()!;
      final participants = List<String>.from(groupData['participants'] ?? []);
      
      // Remove current user from participants
      participants.remove(currentUserId);
      
      // If user is admin and there are other participants, transfer admin
      if (_isAdmin && participants.isNotEmpty) {
        // Transfer admin to the first other participant
        batch.update(groupDocRef, {
          'adminId': participants[0],
          'participants': participants,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Just update participants
        batch.update(groupDocRef, {
          'participants': participants,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      
      // Delete user_groups document for current user
      final userGroupDocRef = _firestore
          .collection('user_groups')
          .doc('${currentUserId}_${widget.groupId}');
      batch.delete(userGroupDocRef);
      
      // If group is now empty, delete it
      if (participants.isEmpty) {
        batch.delete(groupDocRef);
        
        // Also delete all user_groups documents (cleanup)
        final userGroupsQuery = await _firestore
            .collection('user_groups')
            .where('groupId', isEqualTo: widget.groupId)
            .get();
        
        for (final doc in userGroupsQuery.docs) {
          batch.delete(doc.reference);
        }
      }
      
      await batch.commit();
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Napustili ste grupu')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Greška: $e')),
        );
      }
    }
  }

  // Kick member functionality (admin only)
  Future<void> _kickMember(String targetUserId, String targetUserName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ukloni člana'),
        content: Text('Da li ste sigurni da želite ukloniti $targetUserName iz grupe?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Otkaži'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Ukloni',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    try {
      final batch = _firestore.batch();
      
      // Get group document reference
      final groupDocRef = _firestore.collection('groups').doc(widget.groupId);
      final groupDoc = await groupDocRef.get();
      
      if (!groupDoc.exists) {
        throw Exception('Grupa ne postoji');
      }
      
      final groupData = groupDoc.data()!;
      final participants = List<String>.from(groupData['participants'] ?? []);
      
      // Remove target user from participants
      participants.remove(targetUserId);
      
      // If kicked user is admin, assign new admin
      if (targetUserId == groupData['adminId']) {
        if (participants.isNotEmpty) {
          batch.update(groupDocRef, {
            'adminId': participants[0],
            'participants': participants,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          // No participants left, delete group
          batch.delete(groupDocRef);
          
          // Delete all user_groups documents
          final userGroupsQuery = await _firestore
              .collection('user_groups')
              .where('groupId', isEqualTo: widget.groupId)
              .get();
          
          for (final doc in userGroupsQuery.docs) {
            batch.delete(doc.reference);
          }
        }
      } else {
        // Just update participants
        batch.update(groupDocRef, {
          'participants': participants,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      
      // Delete user_groups document for target user
      final targetUserGroupDocRef = _firestore
          .collection('user_groups')
          .doc('${targetUserId}_${widget.groupId}');
      batch.delete(targetUserGroupDocRef);
      
      await batch.commit();
      
      // Update local state
      setState(() {
        _groupMembers.removeWhere((member) => member['id'] == targetUserId);
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$targetUserName je uklonjen iz grupe')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Greška: $e')),
        );
      }
    }
  }

  // Add member functionality (admin only)
Future<void> _addMember() async {
  final List<Map<String, dynamic>> friends = [];

  try {
    final friendsStream = FriendsService.getFriendsStream();
    final friendsSnapshot = await friendsStream.first;
    friends.addAll(friendsSnapshot);
  } catch (e) {
    print('Error loading friends: $e');
  }

  final currentMemberIds = _groupMembers.map((m) => m['id']).toList();
  final availableFriends = friends.where(
    (friend) => !currentMemberIds.contains(friend['id'])
  ).toList();

  if (availableFriends.isEmpty) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nemate prijatelja koji nisu već u grupi')),
      );
    }
    return;
  }

  final selectedFriends = <String>[];

  await showDialog(
    context: context,
    builder: (context) => StatefulBuilder( // DODATO: StatefulBuilder
      builder: (context, setDialogState) { // DODATO: setDialogState
        return AlertDialog(
          title: const Text('Dodaj prijatelje'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: Column(
              children: [
                const Text('Izaberite prijatelje za dodavanje:'),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: availableFriends.length,
                    itemBuilder: (context, index) {
                      final friend = availableFriends[index];
                      final isSelected = selectedFriends.contains(friend['id']);
                      return CheckboxListTile(
                        title: Text(friend['name']),
                        value: isSelected,
                        onChanged: (value) {
                          // IZMENJENO: setDialogState umesto setState
                          setDialogState(() {
                            if (value == true) {
                              selectedFriends.add(friend['id']);
                            } else {
                              selectedFriends.remove(friend['id']);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Otkaži'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedFriends.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Izaberite bar jednog prijatelja')),
                  );
                  return;
                }
                
                try {
                  for (final friendId in selectedFriends) {
                    await MessagingService.addMemberToGroup(
                      groupId: widget.groupId,
                      userId: friendId,
                    );
                  }
                  
                  if (mounted) {
                    Navigator.pop(context);
                    await _loadGroupInfoAndMembers();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Dodano ${selectedFriends.length} prijatelja')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Greška: $e')),
                    );
                  }
                }
              },
              child: const Text('Dodaj'),
            ),
          ],
        );
      },
    ),
  );
}

  String _formatTime(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime timestamp) {
    return '${timestamp.day}.${timestamp.month}.${timestamp.year}.';
  }

  Widget _buildInfoPanel() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      right: _showInfoPanel ? 0 : -MediaQuery.of(context).size.width * 0.8,
      top: 0,
      bottom: 0,
      width: MediaQuery.of(context).size.width * 0.8,
      child: Material(
        elevation: 8,
        color: Colors.white,
        child: Column(
          children: [
            // Panel header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              color: Colors.orange.shade700,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () {
                      setState(() {
                        _showInfoPanel = false;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Informacije o grupi',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Group name
                    Text(
                      'Naziv grupe',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.groupName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Created info
                    if (_groupInfo?['createdAt'] != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kreirano',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatDate((_groupInfo!['createdAt'] as Timestamp).toDate()),
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    
                    // Members count with working count
                    Text(
                      'Članovi grupe (${_groupMembers.length})',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange.shade700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Members list
                    if (_isLoadingMembers)
                      const Center(child: CircularProgressIndicator())
                    else
                      ..._groupMembers.map((member) {
                        final isCurrentUser = member['id'] == _auth.currentUser!.uid;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.grey.shade200,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Avatar
                              CircleAvatar(
                                backgroundColor: isCurrentUser 
                                    ? Colors.orange.shade100 
                                    : Colors.blue.shade100,
                                child: Text(
                                  member['name'][0].toUpperCase(),
                                  style: TextStyle(
                                    color: isCurrentUser 
                                        ? Colors.orange.shade800 
                                        : Colors.blue.shade800,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              
                              // User info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            member['name'],
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 16,
                                              color: isCurrentUser 
                                                  ? Colors.orange.shade800 
                                                  : Colors.black,
                                            ),
                                          ),
                                        ),
                                        if (member['isAdmin'])
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.shade100,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              'Admin',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.orange.shade800,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (member['email'] != null && member['email'].isNotEmpty)
                                      Text(
                                        member['email'],
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey.shade600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    if (member['joinedAt'] != null)
                                      Text(
                                        'Pridružio se: ${_formatDate(member['joinedAt'])}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              
                              // Kick button (admin only, not self)
                              if (_isAdmin && !isCurrentUser)
                                IconButton(
                                  icon: const Icon(Icons.remove_circle, color: Colors.red),
                                  onPressed: () => _kickMember(member['id'], member['name']),
                                  tooltip: 'Ukloni člana',
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                    
                    const SizedBox(height: 20),
                    
                    // Group actions
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(),
                        const SizedBox(height: 12),
                        Text(
                          'Opcije',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        // Add member button (admin only)
                        if (_isAdmin)
                          _buildActionButton(
                            icon: Icons.person_add,
                            label: 'Dodaj člana',
                            onTap: _addMember,
                          ),
                        
                        // Leave group button for everyone
                        _buildActionButton(
                          icon: Icons.exit_to_app,
                          label: 'Napusti grupu',
                          color: Colors.red,
                          onTap: _leaveGroup,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    Color? color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: color ?? Colors.orange.shade700,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color ?? Colors.orange.shade700,
                      fontWeight: FontWeight.w500,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
        title: Text(widget.groupName),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              setState(() {
                _showInfoPanel = true;
              });
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Messages list
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('groups')
                      .doc(widget.groupId)
                      .collection('messages')
                      .orderBy('timestamp', descending: false)
                      .snapshots(),
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
                    
                    final messages = snapshot.data?.docs ?? [];
                    
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _scrollToBottom();
                    });
                    
                    if (messages.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline, size: 80, color: Colors.orange.shade300),
                            const SizedBox(height: 20),
                            Text(
                              'Nema poruka u grupi',
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
                                'Pošaljite prvu poruku!',
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
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index].data() as Map<String, dynamic>;
                        final isMe = message['senderId'] == _auth.currentUser!.uid;
                        final messageText = message['message'] ?? '';
                        final timestamp = message['timestamp'] as Timestamp?;
                        final senderName = _userNames[message['senderId']] ?? message['senderName'] ?? 'Nepoznato';
                        
                        return Row(
                          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                          children: [
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.75,
                              ),
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                child: Column(
                                  crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                  children: [
                                    if (!isMe)
                                      Container(
                                        margin: const EdgeInsets.only(bottom: 4),
                                        child: Text(
                                          senderName,
                                          style: TextStyle(
                                            color: Colors.orange.shade700,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isMe ? Colors.orange.shade700 : Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      child: Text(
                                        messageText,
                                        style: TextStyle(
                                          color: isMe ? Colors.white : Colors.black,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    if (timestamp != null)
                                      Text(
                                        _formatTime(timestamp.toDate()),
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
              
              // Message input
              _buildMessageInput(),
            ],
          ),
          
          // Overlay when panel is open
          if (_showInfoPanel)
            GestureDetector(
              onTap: () {
                setState(() {
                  _showInfoPanel = false;
                });
              },
              child: Container(
                color: Colors.black54,
              ),
            ),
          
          // Info panel
          _buildInfoPanel(),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              maxLines: null,
              decoration: InputDecoration(
                hintText: 'Poruka za grupu...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.orange.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.orange.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.orange.shade700, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          Container(
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
            child: IconButton(
              icon: _isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send, color: Colors.white),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}