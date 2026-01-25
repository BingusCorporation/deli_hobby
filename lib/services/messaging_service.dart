// services/messaging_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MessagingService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static String get currentUserId => _auth.currentUser?.uid ?? '';

  // ============ 1-ON-1 MESSAGES (EXISTING) ============
  
  /// Create or get conversation ID between two users
  static String getConversationId(String userId1, String userId2) {
    final sortedIds = [userId1, userId2]..sort();
    return '${sortedIds[0]}_${sortedIds[1]}';
  }

  /// Send a message to another user - SIMPLIFIED VERSION
  static Future<void> sendMessage(String receiverId, String message) async {
    if (message.trim().isEmpty) return;
    
    try {
      final conversationId = getConversationId(currentUserId, receiverId);
      final now = FieldValue.serverTimestamp();
      
      // Create message document
      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .add({
        'senderId': currentUserId,
        'receiverId': receiverId,
        'message': message.trim(),
        'timestamp': now,
        'read': false,
      });
      
      // Try to create/update conversation document
      try {
        await _firestore.collection('conversations').doc(conversationId).set({
          'participants': [currentUserId, receiverId],
          'lastMessage': message.trim(),
          'lastMessageTime': now,
          'lastMessageSender': currentUserId,
          'createdAt': now,
          'updatedAt': now,
        }, SetOptions(merge: true));
      } catch (e) {
        print('Note: Conversation update failed (might be permission issue): $e');
      }
    } catch (e) {
      print('❌ Error sending message: $e');
      rethrow;
    }
  }

  /// Get conversation stream for 1-on-1 chat
  static Stream<QuerySnapshot> getConversationStream(String otherUserId) {
    final conversationId = getConversationId(currentUserId, otherUserId);
    
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .handleError((error) {
          print('Error in conversation stream: $error');
        });
  }

  /// Get list of conversations for current user
  static Stream<QuerySnapshot> getConversationsStream() {
    return _firestore
        .collection('conversations')
        .where('participants', arrayContains: currentUserId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .handleError((error) {
          print('Error in conversations stream: $error');
        });
  }

  /// Mark messages as read
  static Future<void> markAsRead(String conversationId, String otherUserId) async {
    try {
      // Just mark individual messages as read
      final messagesSnapshot = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .where('receiverId', isEqualTo: currentUserId)
          .where('read', isEqualTo: false)
          .get();
      
      final batch = _firestore.batch();
      for (final doc in messagesSnapshot.docs) {
        batch.update(doc.reference, {'read': true});
      }
      
      if (messagesSnapshot.docs.isNotEmpty) {
        await batch.commit();
      }
    } catch (e) {
      print('Note: Could not mark messages as read: $e');
    }
  }

  // ============ GROUP CHAT FUNCTIONS ============

  /// Create a new group
  static Future<String> createGroup({
    required String name,
    String description = '',
    required List<String> participantIds,
    bool isPublic = false,
    String? imageUrl,
  }) async {
    try {
      final groupRef = _firestore.collection('groups').doc();
      
      await groupRef.set({
        'id': groupRef.id,
        'name': name,
        'description': description,
        'adminId': currentUserId,
        'participants': [...participantIds, currentUserId],
        'isPublic': isPublic,
        'imageUrl': imageUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'messageCount': 0,
      });

      // Create user_group entries for all participants
      final batch = _firestore.batch();
      for (final userId in [...participantIds, currentUserId]) {
        final userGroupRef = _firestore
          .collection('user_groups')
          .doc('${userId}_${groupRef.id}');
        
        batch.set(userGroupRef, {
          'userId': userId,
          'groupId': groupRef.id,
          'joinedAt': FieldValue.serverTimestamp(),
          'role': userId == currentUserId ? 'admin' : 'member',
          'unreadCount': 0,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();

      return groupRef.id;
    } catch (e) {
      print('Error creating group: $e');
      rethrow;
    }
  }

  /// Send message to group
  static Future<void> sendGroupMessage({
    required String groupId,
    required String message,
  }) async {
    if (message.trim().isEmpty) return;

    try {
      // Get current user name for the message
      final userDoc = await _firestore.collection('users').doc(currentUserId).get();
      final userName = userDoc['name'] as String? ?? 'Korisnik';
      
      // Add message to group_messages subcollection
      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('messages')
          .add({
        'senderId': currentUserId,
        'senderName': userName,
        'message': message.trim(),
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'text',
        'readBy': [currentUserId],
      });

      // Update group metadata
      await _firestore.collection('groups').doc(groupId).update({
        'lastMessage': message.trim(),
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSender': currentUserId,
        'updatedAt': FieldValue.serverTimestamp(),
        'messageCount': FieldValue.increment(1),
      });

      // Update unread counts and lastUpdated for all participants except sender
      final groupDoc = await _firestore.collection('groups').doc(groupId).get();
      final participants = List<String>.from(groupDoc['participants'] ?? []);
      
      final batch = _firestore.batch();
      for (final userId in participants) {
        final userGroupRef = _firestore
            .collection('user_groups')
            .doc('${userId}_${groupId}');
        
        if (userId != currentUserId) {
          // Increment unread count for others
          batch.set(userGroupRef, {
            'unreadCount': FieldValue.increment(1),
            'lastUpdated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } else {
          // Just update lastUpdated for sender
          batch.set(userGroupRef, {
            'lastUpdated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }
      await batch.commit();
      
    } catch (e) {
      print('Error sending group message: $e');
      rethrow;
    }
  }

  /// Get group message stream
  static Stream<QuerySnapshot> getGroupMessagesStream(String groupId) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .handleError((error) {
          print('Error in group messages stream: $error');
        });
  }

  /// Get groups for current user
  static Stream<QuerySnapshot> getUserGroupsStream() {
    return _firestore
        .collection('user_groups')
        .where('userId', isEqualTo: currentUserId)
        .orderBy('lastUpdated', descending: true)
        .snapshots()
        .handleError((error) {
          print('Error in user groups stream: $error');
        });
  }

  /// Get group details
  static Future<DocumentSnapshot> getGroupDetails(String groupId) {
    return _firestore.collection('groups').doc(groupId).get();
  }

  /// Add participant to group
  static Future<void> addParticipantToGroup({
    required String groupId,
    required String userId,
  }) async {
    final batch = _firestore.batch();
    
    // Add to group participants
    final groupRef = _firestore.collection('groups').doc(groupId);
    batch.update(groupRef, {
      'participants': FieldValue.arrayUnion([userId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Create user_group entry
    final userGroupRef = _firestore
        .collection('user_groups')
        .doc('${userId}_${groupId}');
    
    batch.set(userGroupRef, {
      'userId': userId,
      'groupId': groupId,
      'joinedAt': FieldValue.serverTimestamp(),
      'role': 'member',
      'unreadCount': 0,
      'lastUpdated': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Mark group messages as read
  static Future<void> markGroupMessagesAsRead(String groupId) async {
    try {
      await _firestore
          .collection('user_groups')
          .doc('${currentUserId}_${groupId}')
          .update({
        'unreadCount': 0,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error marking group messages as read: $e');
    }
  }

  // ============ COMBINED STREAMS ============

  /// Get combined conversations (private + groups) stream
  static Stream<List<Map<String, dynamic>>> getCombinedConversationsStream() {
    // Get private conversations
    final privateStream = getConversationsStream().asyncMap((snapshot) async {
      final privateConversations = <Map<String, dynamic>>[];
      
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final participants = List<String>.from(data['participants'] ?? []);
        final otherUserId = participants.firstWhere(
          (id) => id != currentUserId,
          orElse: () => '',
        );
        
        if (otherUserId.isEmpty) continue;
        
        // Get user info
        try {
          final userDoc = await _firestore
              .collection('users')
              .doc(otherUserId)
              .get();
          
          final userData = userDoc.data() ?? <String, dynamic>{};
          
          privateConversations.add({
            'type': 'private',
            'id': doc.id,
            'otherUserId': otherUserId,
            'name': userData['name'] ?? 'Nepoznato',
            'lastMessage': data['lastMessage'] ?? '',
            'lastMessageTime': data['lastMessageTime'],
            'unreadCount': (data['unreadCount'] as Map<String, dynamic>?)?[currentUserId] as int? ?? 0,
          });
        } catch (e) {
          print('Error getting user info: $e');
        }
      }
      
      return privateConversations;
    });
    
    // Get group conversations
    final groupStream = _firestore
        .collection('user_groups')
        .where('userId', isEqualTo: currentUserId)
        .orderBy('lastUpdated', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          final groupConversations = <Map<String, dynamic>>[];
          
          for (final doc in snapshot.docs) {
            final data = doc.data();
            final groupId = data['groupId'] as String? ?? '';
            final unreadCount = data['unreadCount'] as int? ?? 0;
            
            if (groupId.isEmpty) continue;
            
            try {
              final groupDoc = await _firestore
                  .collection('groups')
                  .doc(groupId)
                  .get();
              
              if (groupDoc.exists) {
                final groupData = groupDoc.data() as Map<String, dynamic>;
                
                groupConversations.add({
                  'type': 'group',
                  'id': groupId,
                  'name': groupData['name'] ?? 'Grupa',
                  'lastMessage': groupData['lastMessage'] ?? '',
                  'lastMessageTime': groupData['lastMessageTime'],
                  'unreadCount': unreadCount,
                });
              }
            } catch (e) {
              print('Error getting group info: $e');
            }
          }
          
          return groupConversations;
        });
    
    // Combine both streams
    return privateStream.asyncMap((privateList) async {
      final groupsSnapshot = await groupStream.first;
      final combined = [...privateList, ...groupsSnapshot];
      
      // Sort by last message time (newest first)
      combined.sort((a, b) {
        final timeA = a['lastMessageTime'] as Timestamp?;
        final timeB = b['lastMessageTime'] as Timestamp?;
        
        if (timeA == null && timeB == null) return 0;
        if (timeA == null) return 1;
        if (timeB == null) return -1;
        
        return timeB.compareTo(timeA);
      });
      
      return combined;
    });
  }

  /// Get total unread count (both 1-on-1 and group)
  static Stream<int> getTotalUnreadCountStream() {
    return _firestore
        .collection('user_groups')
        .where('userId', isEqualTo: currentUserId)
        .snapshots()
        .map((snapshot) {
          int total = 0;
          for (final doc in snapshot.docs) {
            total += (doc['unreadCount'] as int? ?? 0);
          }
          return total;
        })
        .handleError((error) {
          print('Error in total unread count stream: $error');
          return 0;
        });
  }

  /// Get unread message count for main screen
  static Stream<int> getUnreadCountStream() {
    return _firestore
        .collection('conversations')
        .where('participants', arrayContains: currentUserId)
        .snapshots()
        .map((snapshot) {
          int total = 0;
          for (final doc in snapshot.docs) {
            final data = doc.data();
            final unread = (data['unreadCount'] as Map<String, dynamic>?)?[currentUserId] as int? ?? 0;
            total += unread;
          }
          return total;
        })
        .handleError((error) {
          print('Error in unread count stream: $error');
          return 0;
        });
  }

  /// Get combined unread count (1-on-1 + groups) for main screen
  static Stream<int> getCombinedUnreadCountStream() {
    // Combine 1-on-1 unread count with group unread count
    final privateStream = getUnreadCountStream();
    final groupStream = _firestore
        .collection('user_groups')
        .where('userId', isEqualTo: currentUserId)
        .snapshots()
        .map((snapshot) {
          int total = 0;
          for (final doc in snapshot.docs) {
            total += (doc['unreadCount'] as int? ?? 0);
          }
          return total;
        });

    // Combine both streams
    return privateStream.asyncMap((privateCount) async {
      final groupCount = await groupStream.first;
      return privateCount + groupCount;
    });
  }
}