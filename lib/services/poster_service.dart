// Modify PosterService methods
import 'package:cloud_firestore/cloud_firestore.dart';

class PosterService {
  // Existing code... 

  Future<void> createPoster(String title, String description, String hobbies, String image, String city) async {
    // Existing code to save poster...
    await FirebaseFirestore.instance.collection('posters').add({
      'title': title,
      'description': description,
      'hobbies': hobbies,
      'image': image,
      'city': city, // Save city
    });
  }

  Future<void> updatePoster(String id, String title, String description, String hobbies, String image, String city) async {
    // Existing code to update poster...
    await FirebaseFirestore.instance.collection('posters').doc(id).update({
      'title': title,
      'description': description,
      'hobbies': hobbies,
      'image': image,
      'city': city, // Update city
    });
  }
}