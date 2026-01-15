// utils/firestore_helper.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreHelper {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Update user data in both collections
  static Future<void> updateUserData(
    String userId, 
    Map<String, dynamic> data
  ) async {
    final batch = _firestore.batch();
    
    // Private collection
    batch.update(_firestore.collection('users_private').doc(userId), {
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    
    // Public collection (filter out private fields)
    final publicData = Map<String, dynamic>.from(data)
      ..removeWhere((key, value) => 
        key == 'email' || 
        key == 'friendRequests' || 
        key == 'sentFriendRequests'
      );
    
    batch.update(_firestore.collection('users').doc(userId), {
      ...publicData,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    
    await batch.commit();
  }
}