import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../models/poster.dart';

class PosterService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  static String get currentUserId => _auth.currentUser?.uid ?? '';

  /// Get all posters stream
  static Stream<List<Poster>> getPostersStream() {
    return _firestore
        .collection('posters')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map<Poster>(Poster.fromFirestore).toList());
  }

  /// Get user's own posters
  static Stream<List<Poster>> getUserPostersStream(String userId) {
    return _firestore
        .collection('posters')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map<Poster>(Poster.fromFirestore).toList());
  }

  /// Create a new poster
  static Future<String> createPoster({
    required String title,
    required String description,
    required List<String> requiredHobbies,
    File? imageFile,
    String? city,
  }) async {
    try {
      String? imageUrl;
      
      // Upload image if provided
      if (imageFile != null) {
        final imageRef = _storage
            .ref()
            .child('poster_images/${DateTime.now().millisecondsSinceEpoch}_$currentUserId.jpg');
        
        await imageRef.putFile(imageFile);
        imageUrl = await imageRef.getDownloadURL();
      }
      
      // Get current user data
      final userDoc = await _firestore.collection('users').doc(currentUserId).get();
      final userData = userDoc.data() ?? <String, dynamic>{};
      
      // Create poster document
      final posterRef = await _firestore.collection('posters').add({
        'userId': currentUserId,
        'userName': userData['name'] ?? 'Nepoznato',
        'userProfilePic': userData['profilePic'],
        'title': title,
        'description': description,
        'requiredHobbies': requiredHobbies,
        'imageUrl': imageUrl,
        'city': city,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      return posterRef.id;
    } catch (e) {
      print('Error creating poster: $e');
      rethrow;
    }
  }

  /// Update a poster
  static Future<void> updatePoster({
    required String posterId,
    String? title,
    String? description,
    List<String>? requiredHobbies,
    File? imageFile,
    String? city,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      if (title != null) updates['title'] = title;
      if (description != null) updates['description'] = description;
      if (requiredHobbies != null) updates['requiredHobbies'] = requiredHobbies;
      if (city != null) updates['city'] = city;
      
      // Upload new image if provided
      if (imageFile != null) {
        final imageRef = _storage
            .ref()
            .child('poster_images/${DateTime.now().millisecondsSinceEpoch}_$currentUserId.jpg');
        
        await imageRef.putFile(imageFile);
        updates['imageUrl'] = await imageRef.getDownloadURL();
      }
      
      await _firestore.collection('posters').doc(posterId).update(updates);
    } catch (e) {
      print('Error updating poster: $e');
      rethrow;
    }
  }

  /// Delete a poster
  static Future<void> deletePoster(String posterId) async {
    try {
      // Optionally delete image from storage too
      await _firestore.collection('posters').doc(posterId).delete();
    } catch (e) {
      print('Error deleting poster: $e');
      rethrow;
    }
  }

  /// Check if poster matches user's hobbies
  static Future<bool> posterMatchesUserHobbies(Poster poster, String userId) async {
    try {
      final userDoc = await _firestore.collection('users_private').doc(userId).get();
      if (!userDoc.exists) return false;
      
      final userData = userDoc.data() ?? <String, dynamic>{};
      final userHobbies = List<String>.from(userData['hobbies'] ?? []);
      
      // Check if any of poster's required hobbies match user's hobbies
      for (final hobby in poster.requiredHobbies) {
        if (userHobbies.contains(hobby)) {
          return true;
        }
      }
      
      return false;
    } catch (e) {
      print('Error checking hobby match: $e');
      return false;
    }
  }

  /// Get matching posters stream (for current user)
  static Stream<List<Poster>> getMatchingPostersStream() {
    return _firestore
        .collection('posters')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          final posters = snapshot.docs.map(Poster.fromFirestore).toList();
          final matchingPosters = <Poster>[];
          
          for (final poster in posters) {
            if (await posterMatchesUserHobbies(poster, currentUserId)) {
              matchingPosters.add(poster);
            }
          }
          
          return matchingPosters;
        });
  }
}