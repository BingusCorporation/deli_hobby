// services/messaging_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MessagingService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static String get currentUserId => _auth.currentUser?.uid ?? '';

  /// Create or get conversation ID between two users
  static String getConversationId(String userId1, String userId2) { // CHANGE: Added underscore
    final sortedIds = [userId1, userId2]..sort();
    return '${sortedIds[0]}_${sortedIds[1]}';
  }

  /// Send a message to another user
  static Future<void> sendMessage(String receiverId, String message) async {
    if (message.trim().isEmpty) return;
    
    final conversationId = getConversationId(currentUserId, receiverId); // CHANGE: Use private method
    
    final now = FieldValue.serverTimestamp();
    
    // Add message to messages subcollection
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
    
    // Update conversation metadata
    await _firestore.collection('conversations').doc(conversationId).set({
      'participants': [currentUserId, receiverId],
      'lastMessage': message.trim(),
      'lastMessageTime': now,
      'lastMessageSender': currentUserId,
      'unreadCount': {
        receiverId: FieldValue.increment(1),
      },
    }, SetOptions(merge: true));
  }

  /// Get conversation stream
  static Stream<QuerySnapshot> getConversationStream(String otherUserId) {
    final conversationId = getConversationId(currentUserId, otherUserId); // CHANGE: Use private method
    
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  /// Get list of conversations for current user
  static Stream<QuerySnapshot> getConversationsStream() {
    return _firestore
        .collection('conversations')
        .where('participants', arrayContains: currentUserId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots();
  }

  /// Mark messages as read
  static Future<void> markAsRead(String conversationId, String otherUserId) async {
    // Update unread count
    await _firestore.collection('conversations').doc(conversationId).update({
      'unreadCount.$currentUserId': 0,
    });
    
    // Mark individual messages as read
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
  }

  /// Get unread message count
  static Stream<int> getUnreadCountStream() {
    return _firestore
        .collection('conversations')
        .where('participants', arrayContains: currentUserId)
        .snapshots()
        .map((snapshot) {
          int total = 0;
          for (final doc in snapshot.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final unread = (data['unreadCount'] as Map<String, dynamic>?)?[currentUserId] as int? ?? 0;
            total += unread;
          }
          return total;
        });
  }

  // ADD THIS HELPER METHOD FOR EXTERNAL ACCESS
  static String getConversationIdForUsers(String userId1, String userId2) {
    return getConversationId(userId1, userId2);
  }
}