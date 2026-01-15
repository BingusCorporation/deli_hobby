// services/friends_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FriendsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static String get currentUserId => _auth.currentUser?.uid ?? '';

// Update sendFriendRequest method in friends_service.dart
static Future<void> sendFriendRequest(String targetUserId) async {
  try {
    final batch = _firestore.batch();
    
    // Get references
    final targetPrivateRef = _firestore.collection('users_private').doc(targetUserId);
    final currentPrivateRef = _firestore.collection('users_private').doc(currentUserId);
    
    // Add to target user's friendRequests
    batch.update(targetPrivateRef, {
      'friendRequests': FieldValue.arrayUnion([currentUserId])
    });
    
    // Add to current user's sentFriendRequests
    batch.update(currentPrivateRef, {
      'sentFriendRequests': FieldValue.arrayUnion([targetUserId])
    });
    
    await batch.commit();
    print('Friend request sent successfully');
  } catch (e) {
    print('Error sending friend request: $e');
    
    // Fallback: Try individual updates if batch fails
    try {
      await _firestore.collection('users_private').doc(targetUserId).update({
        'friendRequests': FieldValue.arrayUnion([currentUserId])
      });
      
      await _firestore.collection('users_private').doc(currentUserId).update({
        'sentFriendRequests': FieldValue.arrayUnion([targetUserId])
      });
    } catch (fallbackError) {
      print('Fallback also failed: $fallbackError');
      rethrow;
    }
  }
}

  /// Accept friend request
  static Future<void> acceptFriendRequest(String requesterId) async {
    final batch = _firestore.batch();
    
    // Remove from current user's friendRequests
    final currentPrivateRef = _firestore.collection('users_private').doc(currentUserId);
    batch.update(currentPrivateRef, {
      'friendRequests': FieldValue.arrayRemove([requesterId])
    });
    
    // Remove from requester's sentFriendRequests
    final requesterPrivateRef = _firestore.collection('users_private').doc(requesterId);
    batch.update(requesterPrivateRef, {
      'sentFriendRequests': FieldValue.arrayRemove([currentUserId])
    });
    
    // Add to both users' friends in private collection
    batch.update(currentPrivateRef, {
      'friends': FieldValue.arrayUnion([requesterId])
    });
    batch.update(requesterPrivateRef, {
      'friends': FieldValue.arrayUnion([currentUserId])
    });
    
    // Add to both users' friends in public collection
    final currentPublicRef = _firestore.collection('users').doc(currentUserId);
    final requesterPublicRef = _firestore.collection('users').doc(requesterId);
    
    batch.update(currentPublicRef, {
      'friends': FieldValue.arrayUnion([requesterId])
    });
    batch.update(requesterPublicRef, {
      'friends': FieldValue.arrayUnion([currentUserId])
    });
    
    await batch.commit();
  }

  /// Remove friend
  static Future<void> removeFriend(String friendId) async {
    final batch = _firestore.batch();
    
    // Remove from both users' friends in private collection
    final currentPrivateRef = _firestore.collection('users_private').doc(currentUserId);
    final friendPrivateRef = _firestore.collection('users_private').doc(friendId);
    
    batch.update(currentPrivateRef, {
      'friends': FieldValue.arrayRemove([friendId])
    });
    batch.update(friendPrivateRef, {
      'friends': FieldValue.arrayRemove([currentUserId])
    });
    
    // Remove from both users' friends in public collection
    final currentPublicRef = _firestore.collection('users').doc(currentUserId);
    final friendPublicRef = _firestore.collection('users').doc(friendId);
    
    batch.update(currentPublicRef, {
      'friends': FieldValue.arrayRemove([friendId])
    });
    batch.update(friendPublicRef, {
      'friends': FieldValue.arrayRemove([currentUserId])
    });
    
    await batch.commit();
  }

  /// Cancel sent friend request
  static Future<void> cancelFriendRequest(String targetUserId) async {
    final batch = _firestore.batch();
    
    final currentPrivateRef = _firestore.collection('users_private').doc(currentUserId);
    final targetPrivateRef = _firestore.collection('users_private').doc(targetUserId);
    
    batch.update(currentPrivateRef, {
      'sentFriendRequests': FieldValue.arrayRemove([targetUserId])
    });
    batch.update(targetPrivateRef, {
      'friendRequests': FieldValue.arrayRemove([currentUserId])
    });
    
    await batch.commit();
  }

  /// Get friendship status between current user and another user
  static Future<FriendshipStatus> getFriendshipStatus(String otherUserId) async {
    if (currentUserId == otherUserId) return FriendshipStatus.self;
    
    final currentUserDoc = await _firestore.collection('users_private').doc(currentUserId).get();
    final currentData = currentUserDoc.data() as Map<String, dynamic>? ?? {};
    
    final otherUserDoc = await _firestore.collection('users_private').doc(otherUserId).get();
    final otherData = otherUserDoc.data() as Map<String, dynamic>? ?? {};
    
    final List<dynamic> currentFriends = currentData['friends'] ?? [];
    final List<dynamic> currentFriendRequests = currentData['friendRequests'] ?? [];
    final List<dynamic> currentSentRequests = currentData['sentFriendRequests'] ?? [];
    
    if (currentFriends.contains(otherUserId)) {
      return FriendshipStatus.friends;
    } else if (currentFriendRequests.contains(otherUserId)) {
      return FriendshipStatus.pendingIncoming;
    } else if (currentSentRequests.contains(otherUserId)) {
      return FriendshipStatus.pendingOutgoing;
    } else {
      return FriendshipStatus.none;
    }
  }

  /// Get friends list with user data
  static Stream<List<Map<String, dynamic>>> getFriendsStream() {
    return _firestore.collection('users_private').doc(currentUserId).snapshots().asyncMap((snapshot) async {
      final data = snapshot.data() as Map<String, dynamic>? ?? {};
      final List<dynamic> friendIds = data['friends'] ?? [];
      
      if (friendIds.isEmpty) return [];
      
      // Get friend details from public collection
      final friendsSnapshot = await _firestore.collection('users')
          .where(FieldPath.documentId, whereIn: friendIds)
          .get();
      
      return friendsSnapshot.docs.map((doc) {
        final userData = doc.data();
        return {
          'id': doc.id,
          'name': userData['name'] ?? 'Unknown',
          'profilePic': userData['profilePic'] ?? '',
          'city': userData['city'] ?? '',
        };
      }).toList();
    });
  }

  /// Get pending friend requests
  static Stream<List<Map<String, dynamic>>> getFriendRequestsStream() {
    return _firestore.collection('users_private').doc(currentUserId).snapshots().asyncMap((snapshot) async {
      final data = snapshot.data() as Map<String, dynamic>? ?? {};
      final List<dynamic> requestIds = data['friendRequests'] ?? [];
      
      if (requestIds.isEmpty) return [];
      
      final requestsSnapshot = await _firestore.collection('users')
          .where(FieldPath.documentId, whereIn: requestIds)
          .get();
      
      return requestsSnapshot.docs.map((doc) {
        final userData = doc.data();
        return {
          'id': doc.id,
          'name': userData['name'] ?? 'Unknown',
          'profilePic': userData['profilePic'] ?? '',
          'city': userData['city'] ?? '',
        };
      }).toList();
    });
  }
}

enum FriendshipStatus {
  self,
  friends,
  pendingIncoming,
  pendingOutgoing,
  none,
}