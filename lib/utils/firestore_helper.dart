
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreHelper {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> updateUserData(
    String userId, 
    Map<String, dynamic> data
  ) async {
    final batch = _firestore.batch();
    
    batch.update(_firestore.collection('users_private').doc(userId), {
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    
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