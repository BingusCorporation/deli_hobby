// services/friends_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FriendsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Local cache for user data to reduce Firestore reads
  static final Map<String, Map<String, dynamic>> _userCache = {};
  // Set to track users currently being fetched to prevent duplicate requests
  static final Set<String> _fetchingUsers = {};

  static String get currentUserId => _auth.currentUser?.uid ?? '';

  /// Send friend request
  static Future<void> sendFriendRequest(String targetUserId) async {
    try {
      // Create friend request document
      await _firestore.collection('friend_requests').add({
        'senderId': currentUserId,
        'receiverId': targetUserId,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('Friend request sent successfully');
    } catch (e) {
      print('Error sending friend request: $e');
      rethrow;
    }
  }

  /// Accept friend request - Optimized with parallel reads
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
      
      if (receiverId != currentUserId) {
        throw Exception('You cannot accept this friend request');
      }
      
      final batch = _firestore.batch();
      
      // 1. DELETE the friend request after acceptance
      batch.delete(requestRef);
      
      // 2. Create friendship documents
      final friendshipId1 = '${senderId}_$receiverId';
      final friendshipId2 = '${receiverId}_$senderId';
      final friendshipRef1 = _firestore.collection('friendships').doc(friendshipId1);
      final friendshipRef2 = _firestore.collection('friendships').doc(friendshipId2);
      
      // Parallel existence checks
      final [existing1, existing2] = await Future.wait([
        friendshipRef1.get(),
        friendshipRef2.get(),
      ]);
      
      if (!existing1.exists) {
        batch.set(friendshipRef1, {
          'userId': senderId,
          'friendId': receiverId,
          'createdAt': FieldValue.serverTimestamp(),
          'direction': 'sender_to_receiver',
        });
      }
      
      if (!existing2.exists) {
        batch.set(friendshipRef2, {
          'userId': receiverId,
          'friendId': senderId,
          'createdAt': FieldValue.serverTimestamp(),
          'direction': 'receiver_to_sender',
        });
      }
      
      await batch.commit();
      
      // Update cache for both users
      await _fetchAndCacheUsers([senderId, receiverId]);
      
      print('Friend request accepted and friendships created successfully');
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

  static Future<void> declineFriendRequest(String requestId) async {
    try {
      final requestDoc = await _firestore.collection('friend_requests').doc(requestId).get();
      if (!requestDoc.exists) {
        throw Exception('Friend request not found');
      }
      
      final data = requestDoc.data()!;
      if (data['receiverId'] != currentUserId) {
        throw Exception('You cannot decline this friend request');
      }
      
      await _firestore.collection('friend_requests').doc(requestId).update({
        'status': 'declined',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('Friend request declined');
    } catch (e) {
      print('Error declining friend request: $e');
      rethrow;
    }
  }

  /// Remove friend - optimized with batch
  static Future<void> removeFriend(String friendId) async {
    try {
      final batch = _firestore.batch();
      
      batch.delete(_firestore.collection('friendships').doc('${currentUserId}_$friendId'));
      batch.delete(_firestore.collection('friendships').doc('${friendId}_$currentUserId'));
      
      await batch.commit();
      
      // Remove from cache
      _userCache.remove(friendId);
      
      print('Both friendship documents deleted successfully');
    } catch (e) {
      print('Error removing friend: $e');
      rethrow;
    }
  }

  /// Cancel friend request
  static Future<void> cancelFriendRequest(String requestId) async {
    await _firestore.collection('friend_requests').doc(requestId).delete();
  }

  /// Get friendship status - Optimized with parallel queries
static Future<FriendshipStatus> getFriendshipStatus(String otherUserId) async {
  if (currentUserId == otherUserId) return FriendshipStatus.self;

  final List<String> userIds = [currentUserId, otherUserId];
  userIds.sort();
  final friendshipId = '${userIds[0]}_${userIds[1]}';

  // Pokretanje paralelnih upita
  final friendshipFuture = _firestore.collection('friendships').doc(friendshipId).get();
  
  final pendingRequestsFuture = _firestore
      .collection('friend_requests')
      .where('status', isEqualTo: 'pending')
      .where(Filter.or(
        Filter.and(
          Filter('senderId', isEqualTo: currentUserId),
          Filter('receiverId', isEqualTo: otherUserId),
        ),
        Filter.and(
          Filter('senderId', isEqualTo: otherUserId),
          Filter('receiverId', isEqualTo: currentUserId),
        ),
      ))
      .limit(1)
      .get();

  // Destrukturizacija uz eksplicitno kastovanje tipova
  final results = await Future.wait([friendshipFuture, pendingRequestsFuture]);
  
  final friendshipDoc = results[0] as DocumentSnapshot<Map<String, dynamic>>;
  final requestsSnapshot = results[1] as QuerySnapshot<Map<String, dynamic>>;

  // 1. Provera da li su već prijatelji
  if (friendshipDoc.exists) {
    return FriendshipStatus.friends;
  }

  // 2. Provera da li postoji zahtev na čekanju
  if (requestsSnapshot.docs.isNotEmpty) {
    final request = requestsSnapshot.docs.first.data();
    return request['senderId'] == currentUserId 
        ? FriendshipStatus.pendingOutgoing 
        : FriendshipStatus.pendingIncoming;
  }

  // 3. Nema nikakve veze
  return FriendshipStatus.none;
}

  /// Get friends stream - Optimized with batch user fetching
  static Stream<List<Map<String, dynamic>>> getFriendsStream() {
    return _firestore
        .collection('friendships')
        .where('userId', isEqualTo: currentUserId)
        .snapshots()
        .asyncMap((snapshot) async {
          if (snapshot.docs.isEmpty) return [];
          
          final friendIds = snapshot.docs
              .map((doc) => doc.data()['friendId'] as String)
              .where((id) => id.isNotEmpty)
              .toSet()
              .toList();
          
          if (friendIds.isEmpty) return [];
          
          // Get missing users from cache or Firestore
          await _fetchAndCacheUsers(friendIds);
          
          final friends = <Map<String, dynamic>>[];
          
          for (final doc in snapshot.docs) {
            final friendId = doc.data()['friendId'] as String;
            final userData = _userCache[friendId];
            
            if (userData != null) {
              friends.add({
                'id': friendId,
                ...userData,
                'friendshipId': doc.id,
              });
            }
          }
          
          return friends;
        });
  }

  /// Get friend requests stream - Optimized with batch user fetching
  static Stream<List<Map<String, dynamic>>> getFriendRequestsStream() {
    return _firestore
        .collection('friend_requests')
        .where('receiverId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'pending')
        .limit(20) // Limit results to prevent over-fetching
        .snapshots()
        .asyncMap((snapshot) async {
          if (snapshot.docs.isEmpty) return [];
          
          final senderIds = snapshot.docs
              .map((doc) => doc.data()['senderId'] as String)
              .where((id) => id.isNotEmpty)
              .toSet()
              .toList();
          
          if (senderIds.isEmpty) return [];
          
          // Get missing users from cache or Firestore
          await _fetchAndCacheUsers(senderIds);
          
          final requests = <Map<String, dynamic>>[];
          
          for (final doc in snapshot.docs) {
            final senderId = doc.data()['senderId'] as String;
            final userData = _userCache[senderId];
            
            if (userData != null) {
              requests.add({
                'requestId': doc.id,
                'id': senderId,
                ...userData,
                'createdAt': doc.data()['createdAt'],
              });
            }
          }
          
          return requests;
        });
  }

  // Helper method to fetch and cache multiple users efficiently
  static Future<void> _fetchAndCacheUsers(List<String> userIds) async {
    if (userIds.isEmpty) return;
    
    // Filter out users already in cache or currently being fetched
    final missingUserIds = userIds
        .where((id) => !_userCache.containsKey(id) && !_fetchingUsers.contains(id))
        .toList();
    
    if (missingUserIds.isEmpty) return;
    
    // Mark as being fetched
    for (final userId in missingUserIds) {
      _fetchingUsers.add(userId);
    }
    
    try {
      // Batch fetch users in groups of 10 (Firestore limit)
      const batchSize = 10;
      for (int i = 0; i < missingUserIds.length; i += batchSize) {
        final batchIds = missingUserIds.sublist(
          i,
          i + batchSize > missingUserIds.length ? missingUserIds.length : i + batchSize,
        );
        
        if (batchIds.isEmpty) continue;
        
        final usersSnapshot = await _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: batchIds)
            .get();
        
        // Cache the results
        for (final doc in usersSnapshot.docs) {
          _userCache[doc.id] = doc.data();
        }
        
        // Cache null for users not found (to prevent repeated fetches)
        for (final userId in batchIds) {
          if (!_userCache.containsKey(userId)) {
            _userCache[userId] = {};
          }
        }
      }
    } finally {
      // Clear fetching status
      for (final userId in missingUserIds) {
        _fetchingUsers.remove(userId);
      }
    }
  }

  /// Clear user cache (call on logout or when needed)
  static void clearCache() {
    _userCache.clear();
    _fetchingUsers.clear();
  }

  /// Pre-cache specific users (call when you know you'll need them)
  static Future<void> precacheUsers(List<String> userIds) async {
    await _fetchAndCacheUsers(userIds);
  }
}

// Keep the same enum for compatibility
enum FriendshipStatus {
  self,
  friends,
  pendingOutgoing,
  pendingIncoming,
  none,
}