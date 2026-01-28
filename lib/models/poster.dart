import 'package:cloud_firestore/cloud_firestore.dart';

class Poster {
  final String id;
  final String userId;
  final String userName;
  final String? userProfilePic;
  final String title;
  final String description;
  final List<String> requiredHobbies;
  final String? imageUrl;
  final String? city;
  final DateTime createdAt;
  final DateTime updatedAt;

  Poster({
    required this.id,
    required this.userId,
    required this.userName,
    this.userProfilePic,
    required this.title,
    required this.description,
    required this.requiredHobbies,
    this.imageUrl,
    this.city,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Poster.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Poster(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userProfilePic: data['userProfilePic'],
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      requiredHobbies: List<String>.from(data['requiredHobbies'] ?? []),
      imageUrl: data['imageUrl'],
      city: data['city'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'userProfilePic': userProfilePic,
      'title': title,
      'description': description,
      'requiredHobbies': requiredHobbies,
      'imageUrl': imageUrl,
      'city': city,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}