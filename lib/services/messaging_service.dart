// services/messaging_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MessagingService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static String get currentUserId => _auth.currentUser?.uid ?? '';

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
      
      print('Sending message to: $receiverId');
      print('Conversation ID: $conversationId');
      
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
      
      print('Message document created');
      
      // Try to create/update conversation document
      try {
        await _firestore.collection('conversations').doc(conversationId).set({
          'participants': [currentUserId, receiverId],
          'lastMessage': message.trim(),
          'lastMessageTime': now,
          'lastMessageSender': currentUserId,
          'createdAt': now,
          'updatedAt': now,
        }, SetOptions(merge: true)); // merge: true updates if exists, creates if not
        
        print('Conversation document updated');
      } catch (e) {
        print('Note: Conversation update failed (might be permission issue): $e');
        // Continue anyway - message was sent
      }
      
      print('✅ Message sent successfully');
    } catch (e) {
      print('❌ Error sending message: $e');
      print('Error type: ${e.runtimeType}');
      rethrow;
    }
  }

  /// Get conversation stream - SIMPLIFIED
  static Stream<QuerySnapshot> getConversationStream(String otherUserId) {
    final conversationId = getConversationId(currentUserId, otherUserId);
    
    print('Getting conversation stream for: $conversationId');
    
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
    print('Getting conversations for user: $currentUserId');
    
    return _firestore
        .collection('conversations')
        .where('participants', arrayContains: currentUserId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .handleError((error) {
          print('Error in conversations stream: $error');
        });
  }

  /// Mark messages as read - SIMPLIFIED (remove if causing issues)
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
        print('✅ Messages marked as read');
      }
    } catch (e) {
      print('Note: Could not mark messages as read: $e');
      // Don't rethrow - this is non-critical
    }
  }

  /// Get unread message count - SIMPLIFIED
  static Stream<int> getUnreadCountStream() {
    return _firestore
        .collection('conversations')
        .where('participants', arrayContains: currentUserId)
        .snapshots()
        .map((snapshot) {
          return 0; // Simplified for now
        })
        .handleError((error) {
          print('Error in unread count stream: $error');
          return 0;
        });
  }
}