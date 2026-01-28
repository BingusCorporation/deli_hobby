import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/poster_service.dart';
import '../models/poster.dart';
import './other_user_profile.dart';
import './chat_screen.dart';

class OglasScreen extends StatefulWidget {
  final String posterId;

  const OglasScreen({super.key, required this.posterId});

  @override
  State<OglasScreen> createState() => _OglasScreenState();
}

class _OglasScreenState extends State<OglasScreen> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  late Future<Poster> _posterFuture;
  late Future<bool> _isMatchingFuture;

  @override
  void initState() {
    super.initState();
    _posterFuture = _loadPoster();
    _isMatchingFuture = _checkIfMatching();
  }

  Future<Poster> _loadPoster() async {
    final doc = await FirebaseFirestore.instance
        .collection('posters')
        .doc(widget.posterId)
        .get();
    
    if (!doc.exists) {
      throw Exception('Oglas nije pronađen');
    }
    
    return Poster.fromFirestore(doc);
  }

  Future<bool> _checkIfMatching() async {
    try {
      final poster = await _posterFuture;
      return await PosterService.posterMatchesUserHobbies(poster, _currentUser!.uid);
    } catch (e) {
      return false;
    }
  }

  void _viewUserProfile(String userId, String userName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OtherUserProfileScreen(
          userId: userId,
          userName: userName,
        ),
      ),
    );
  }

  void _sendMessage(String receiverId, String receiverName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          otherUserId: receiverId,
          otherUserName: receiverName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Oglas'),
      ),
      body: FutureBuilder<Poster>(
        future: _posterFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final poster = snapshot.data!;

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image (full width)
                if (poster.imageUrl != null)
                  Image.network(
                    poster.imageUrl!,
                    height: 250,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // User info
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => _viewUserProfile(poster.userId, poster.userName),
                            child: CircleAvatar(
                              radius: 25,
                              backgroundImage: poster.userProfilePic != null
                                  ? NetworkImage(poster.userProfilePic!)
                                  : const NetworkImage('https://ui-avatars.com/api/?name=User&background=random') as ImageProvider,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                GestureDetector(
                                  onTap: () => _viewUserProfile(poster.userId, poster.userName),
                                  child: Text(
                                    poster.userName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                                Text(
                                  _formatDate(poster.createdAt),
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                          FutureBuilder<bool>(
                            future: _isMatchingFuture,
                            builder: (context, matchSnapshot) {
                              if (matchSnapshot.data == true) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.amber),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.star, size: 16, color: Colors.amber),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Odnosi se na vas',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.amber[800],
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              return const SizedBox();
                            },
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Title
                      Text(
                        poster.title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Description
                      Text(
                        poster.description,
                        style: TextStyle(fontSize: 16, height: 1.5),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // City
                      if (poster.city != null)
                        Row(
                          children: [
                            Icon(Icons.location_on, size: 18, color: Colors.grey[600]),
                            const SizedBox(width: 8),
                            Text(
                              poster.city!,
                              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      if (poster.city != null) const SizedBox(height: 24),
                      
                      // Required Hobbies
                      const Text(
                        'Traženi hobiji:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: poster.requiredHobbies.map((hobby) {
                          return Chip(
                            label: Text(hobby),
                            backgroundColor: Colors.blue[50],
                          );
                        }).toList(),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Action buttons
                      if (_currentUser!.uid != poster.userId)
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _viewUserProfile(poster.userId, poster.userName),
                                icon: Icon(Icons.person),
                                label: Text('Profil'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 15),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _sendMessage(poster.userId, poster.userName),
                                icon: Icon(Icons.message),
                                label: Text('Poruka'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 15),
                                  backgroundColor: Colors.blue,
                                ),
                              ),
                            ),
                          ],
                        ),
                      
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year}. ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}