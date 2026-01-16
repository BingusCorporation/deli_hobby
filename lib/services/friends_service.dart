// services/friends_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/other_user_profile.dart';
class FriendsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static String get currentUserId => _auth.currentUser?.uid ?? '';

  /// Send friend request
  static Future<void> sendFriendRequest(String targetUserId) async {
    try {
      // Create friend request document
      await _firestore.collection('friend_requests').add({
        'senderId': currentUserId,
        'receiverId': targetUserId,
        'status': 'pending', // pending, accepted, declined
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('Friend request sent successfully');
    } catch (e) {
      print('Error sending friend request: $e');
      rethrow;
    }
  }

  /// Accept friend request
  /// In FriendsService - Make sure it matches the new structure
static Future<void> acceptFriendRequest(String requestId) async {
  try {
    final requestRef = _firestore.collection('friend_requests').doc(requestId);
    final requestDoc = await requestRef.get();
    
    if (!requestDoc.exists) {
      throw Exception('Friend request not found');
    }
    
    final data = requestDoc.data()!;
    final senderId = data['senderId'] as String;
    final receiverId = data['receiverId'] as String;
    
    // Make sure current user is the receiver
    if (receiverId != currentUserId) {
      throw Exception('You cannot accept this friend request');
    }
    
    final batch = _firestore.batch();
    
    // 1. Update request status to accepted
    batch.update(requestRef, {
      'status': 'accepted',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    
    // 2. Create friendship document (sorted IDs)
    final List<String> userIds = [senderId, receiverId]..sort();
    final friendshipId = '${userIds[0]}_${userIds[1]}';
    final friendshipRef = _firestore.collection('friendships').doc(friendshipId);
    
    // Check if friendship already exists
    final existingFriendship = await friendshipRef.get();
    if (!existingFriendship.exists) {
      batch.set(friendshipRef, {
        'userId1': userIds[0],
        'userId2': userIds[1],
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    
    await batch.commit();
    print('Friend request accepted successfully');
  } catch (e) {
    print('Error accepting friend request: $e');
    rethrow;
  }
}
  /// Helper to get sender ID from request
  static Future<String> getSenderIdFromRequest(String requestId) async {
    final doc = await _firestore.collection('friend_requests').doc(requestId).get();
    return doc.data()?['senderId'] ?? '';
  }

  /// Remove friend
  static Future<void> removeFriend(String friendId) async {
    try {
      // Find and delete the friendship document
      final List<String> userIds = [currentUserId, friendId];
      userIds.sort();
      final friendshipId = '${userIds[0]}_${userIds[1]}';
      
      await _firestore.collection('friendships').doc(friendshipId).delete();
    } catch (e) {
      print('Error removing friend: $e');
      rethrow;
    }
  }

  /// Cancel friend request
  static Future<void> cancelFriendRequest(String requestId) async {
    await _firestore.collection('friend_requests').doc(requestId).delete();
  }

  /// Get friendship status
  static Future<FriendshipStatus> getFriendshipStatus(String otherUserId) async {
    if (currentUserId == otherUserId) return FriendshipStatus.self;
    
    // Check if friends
    final List<String> userIds = [currentUserId, otherUserId];
    userIds.sort();
    final friendshipId = '${userIds[0]}_${userIds[1]}';
    
    final friendshipDoc = await _firestore.collection('friendships').doc(friendshipId).get();
    if (friendshipDoc.exists) return FriendshipStatus.friends;
    
    // Check for pending requests
    final requests = await _firestore
        .collection('friend_requests')
        .where('senderId', isEqualTo: currentUserId)
        .where('receiverId', isEqualTo: otherUserId)
        .where('status', isEqualTo: 'pending')
        .get();
    
    if (requests.docs.isNotEmpty) return FriendshipStatus.pendingOutgoing;
    
    final incomingRequests = await _firestore
        .collection('friend_requests')
        .where('senderId', isEqualTo: otherUserId)
        .where('receiverId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'pending')
        .get();
    
    if (incomingRequests.docs.isNotEmpty) return FriendshipStatus.pendingIncoming;
    
    return FriendshipStatus.none;
  }

  /// Get friends stream
  static Stream<List<Map<String, dynamic>>> getFriendsStream() {
    return _firestore
        .collection('friendships')
        .where('userId1', isEqualTo: currentUserId)
        .snapshots()
        .asyncMap((snapshot) async {
          final friends = <Map<String, dynamic>>[];
          
          for (final doc in snapshot.docs) {
            final friendId = doc.data()['userId2'];
            final userDoc = await _firestore.collection('users').doc(friendId).get();
            if (userDoc.exists) {
              friends.add({
                'id': friendId,
                ...userDoc.data()!,
              });
            }
          }
          
          return friends;
        });
  }

  /// Get friend requests stream
  static Stream<List<Map<String, dynamic>>> getFriendRequestsStream() {
    return _firestore
        .collection('friend_requests')
        .where('receiverId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .asyncMap((snapshot) async {
          final requests = <Map<String, dynamic>>[];
          
          for (final doc in snapshot.docs) {
            final senderId = doc.data()['senderId'];
            final userDoc = await _firestore.collection('users').doc(senderId).get();
            if (userDoc.exists) {
              requests.add({
                'requestId': doc.id,
                'id': senderId,
                ...userDoc.data()!,
                'createdAt': doc.data()['createdAt'],
              });
            }
          }
          
          return requests;
        });
  }
}