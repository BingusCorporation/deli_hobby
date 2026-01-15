import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/hobbies.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../auth/login_screen.dart';
import '../services/friends_service.dart';
import '../screens/other_user_profile.dart';
import 'messages_screen.dart';

// Add this helper function at the top (or create a separate file)
class UserDataHelper {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Update user data in both collections
  static Future<void> updateUserData(String userId, Map<String, dynamic> data) async {
    try {
      final batch = _firestore.batch();
      
      // Add updatedAt timestamp
      final updates = {
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      // Update private collection
      final privateRef = _firestore.collection('users_private').doc(userId);
      batch.update(privateRef, updates);
      
      // Update public collection - only with public fields
      final publicRef = _firestore.collection('users').doc(userId);
      
      // Filter out private fields (email, friendRequests, sentFriendRequests)
      final publicUpdates = Map<String, dynamic>.from(updates)
        ..removeWhere((key, value) => 
          key == 'email' || 
          key == 'friendRequests' || 
          key == 'sentFriendRequests'
        );
      
      batch.update(publicRef, publicUpdates);
      
      await batch.commit();
    } catch (e) {
      print('Error updating user data: $e');
      rethrow;
    }
  }

  /// Add item to array in both collections
  static Future<void> addToArray(String userId, String field, dynamic value) async {
    try {
      final batch = _firestore.batch();
      
      final privateRef = _firestore.collection('users_private').doc(userId);
      batch.update(privateRef, {
        field: FieldValue.arrayUnion([value]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Only update public collection if field is public
      if (_isPublicField(field)) {
        final publicRef = _firestore.collection('users').doc(userId);
        batch.update(publicRef, {
          field: FieldValue.arrayUnion([value]),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      
      await batch.commit();
    } catch (e) {
      print('Error adding to array: $e');
      rethrow;
    }
  }

  /// Remove item from array in both collections
  static Future<void> removeFromArray(String userId, String field, dynamic value) async {
    try {
      final batch = _firestore.batch();
      
      final privateRef = _firestore.collection('users_private').doc(userId);
      batch.update(privateRef, {
        field: FieldValue.arrayRemove([value]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Only update public collection if field is public
      if (_isPublicField(field)) {
        final publicRef = _firestore.collection('users').doc(userId);
        batch.update(publicRef, {
          field: FieldValue.arrayRemove([value]),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      
      await batch.commit();
    } catch (e) {
      print('Error removing from array: $e');
      rethrow;
    }
  }

  /// Check if a field should be in public collection
  static bool _isPublicField(String field) {
    const publicFields = [
      'name', 'city', 'bio', 'hobbies', 'profilePic', 'friends',
      'createdAt', 'updatedAt'
    ];
    const privateFields = ['email', 'friendRequests', 'sentFriendRequests'];
    
    return publicFields.contains(field) && !privateFields.contains(field);
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  /// ID of the currently logged-in user
  final String uid = FirebaseAuth.instance.currentUser!.uid;

  /// Firestore database reference
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseStorage storage = FirebaseStorage.instance;
  final ImagePicker imagePicker = ImagePicker();

  /// Are we editing the profile?
  bool isEditing = false;

  /// Controllers for text inputs
  final TextEditingController bioController = TextEditingController();
  final TextEditingController cityController = TextEditingController();

  /// Currently selected category in dropdown
  String? selectedCategory;

  /// Currently selected subcategory in dropdown
  String? selectedSubcategory;

  /// For picking a new image
  File? _pickedImage;
  bool _isUploading = false;

  /// Load user data when screen loads
  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final doc = await firestore.collection('users_private').doc(uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        bioController.text = data['bio'] ?? '';
        cityController.text = data['city'] ?? '';
      }
    } catch (e) {
      print('Error loading initial data: $e');
    }
  }

  Stream<int> _getUnreadCountStream() {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final String uid = FirebaseAuth.instance.currentUser!.uid;
    
    return firestore
        .collection('conversations')
        .where('participants', arrayContains: uid)
        .snapshots()
        .map((snapshot) {
          int total = 0;
          for (final doc in snapshot.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final unread = (data['unreadCount'] as Map<String, dynamic>?)?[uid] as int? ?? 0;
            total += unread;
          }
          return total;
        });
  }

  /// Pick image from gallery or camera
  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await imagePicker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _pickedImage = File(pickedFile.path);
        });
        await _uploadImage();
      }
    } catch (e) {
      _showSnackBar('Greška pri odabiru slike: $e');
    }
  }

  /// Upload image to Firebase Storage - UPDATED
  Future<void> _uploadImage() async {
    if (_pickedImage == null) return;

    setState(() {
      _isUploading = true;
    });

    try {
      final storageRef = storage.ref().child('profile_pictures/$uid.jpg');
      await storageRef.putFile(_pickedImage!);
      final imageUrl = await storageRef.getDownloadURL();
      
      // Use helper to update both collections
      await UserDataHelper.updateUserData(uid, {
        'profilePic': imageUrl,
      });

      _showSnackBar('Profilna slika uspešno ažurirana!');
      
      setState(() {
        _pickedImage = null;
      });
    } catch (e) {
      _showSnackBar('Greška pri upload-u slike: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  /// Show snackbar
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// Image picker dialog
  void _showImagePickerDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Odaberi sliku'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Uzmi sliku'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Izaberi iz galerije'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Accept friend request
  Future<void> _acceptFriendRequest(String requesterId) async {
    try {
      await FriendsService.acceptFriendRequest(requesterId);
      _showSnackBar('Prijateljstvo prihvaćeno!');
    } catch (e) {
      _showSnackBar('Greška pri prihvatanju zahteva: $e');
    }
  }

  /// Reject friend request
  Future<void> _rejectFriendRequest(String requesterId) async {
    try {
      await FriendsService.cancelFriendRequest(requesterId);
      _showSnackBar('Zahtev za prijateljstvo odbijen');
    } catch (e) {
      _showSnackBar('Greška pri odbijanju zahteva: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Profil"),
        actions: [
          // Message notification badge
          StreamBuilder<int>(
            stream: _getUnreadCountStream(),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.message),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const MessagesScreen()),
                      );
                    },
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          unreadCount > 9 ? '9+' : unreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: Icon(isEditing ? Icons.check : Icons.edit),
            onPressed: () {
              if (isEditing) {
                saveProfile();
              } else {
                setState(() {
                  isEditing = true;
                });
              }
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        child: StreamBuilder<DocumentSnapshot>(
          stream: firestore.collection('users_private').doc(uid).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final data = snapshot.data!.data() as Map<String, dynamic>;
            final String name = data['name'] ?? 'No name';
            final String? profilePicUrl = data['profilePic'];
            final List hobbies = data['hobbies'] ?? [];
            final email = FirebaseAuth.instance.currentUser!.email ?? '';

            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// PROFILE PICTURE
                  Center(
                    child: Stack(
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.grey.shade300,
                              width: 2,
                            ),
                          ),
                          child: ClipOval(
                            child: _isUploading
                                ? const Center(child: CircularProgressIndicator())
                                : _pickedImage != null
                                    ? Image.file(_pickedImage!, fit: BoxFit.cover)
                                    : profilePicUrl != null && profilePicUrl.isNotEmpty
                                        ? Image.network(
                                            profilePicUrl,
                                            fit: BoxFit.cover,
                                            loadingBuilder: (context, child, loadingProgress) {
                                              if (loadingProgress == null) return child;
                                              return Center(
                                                child: CircularProgressIndicator(
                                                  value: loadingProgress.expectedTotalBytes != null
                                                      ? loadingProgress.cumulativeBytesLoaded /
                                                          loadingProgress.expectedTotalBytes!
                                                      : null,
                                                ),
                                              );
                                            },
                                            errorBuilder: (context, error, stackTrace) {
                                              return const Icon(
                                                Icons.person,
                                                size: 60,
                                                color: Colors.grey,
                                              );
                                            },
                                          )
                                        : const Icon(
                                            Icons.person,
                                            size: 60,
                                            color: Colors.grey,
                                          ),
                          ),
                        ),
                        if (isEditing)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.camera_alt, size: 20),
                                color: Colors.white,
                                onPressed: _isUploading ? null : _showImagePickerDialog,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  /// USER INFO
                  Center(
                    child: Column(
                      children: [
                        Text(
                          name,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          email,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  /// CITY FIELD
                  const Text('Grad', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  isEditing
                      ? TextField(
                          controller: cityController,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'Unesi svoj grad...',
                          ),
                        )
                      : Text(
                          (data['city'] ?? '').isNotEmpty ? data['city']! : 'Grad nije dodat.',
                        ),

                  const SizedBox(height: 16),

                  /// BIO SECTION
                  const Text('O meni', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  isEditing
                      ? TextField(
                          controller: bioController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'Napiši nešto o sebi...',
                          ),
                        )
                      : Text(
                          (data['bio'] ?? '').isNotEmpty ? data['bio']! : 'Bio nije dodat.',
                        ),

                  const SizedBox(height: 20),

                  /// HOBBIES
                  const Text('Hobiji', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: hobbies.map<Widget>((hobby) {
                      return Chip(
                        label: Text(hobby),
                        deleteIcon: isEditing ? const Icon(Icons.close) : null,
                        onDeleted: isEditing
                            ? () => removeHobby(hobby)
                            : null,
                      );
                    }).toList(),
                  ),

                  /// ADD HOBBY UI
                  if (isEditing) ...[
                    const SizedBox(height: 16),
                    DropdownButton<String>(
                      hint: const Text("Izaberi kategoriju"),
                      value: selectedCategory,
                      isExpanded: true,
                      items: hobbyCategories.keys.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedCategory = value;
                          selectedSubcategory = null;
                        });
                      },
                    ),
                    if (selectedCategory != null)
                      DropdownButton<String>(
                        hint: const Text("Izaberi podkategoriju"),
                        value: selectedSubcategory,
                        isExpanded: true,
                        items: hobbyCategories[selectedCategory]!
                            .map((sub) => DropdownMenuItem(
                                  value: sub,
                                  child: Text(sub),
                                ))
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedSubcategory = value;
                          });
                        },
                      ),
                    ElevatedButton(
                      onPressed: selectedCategory != null && selectedSubcategory != null
                          ? addHobby
                          : null,
                      child: const Text("Dodaj hobi"),
                    ),
                  ],

                  /// FRIENDS SECTION
                  const SizedBox(height: 24),
                  const Text('Prijatelji', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  StreamBuilder<List<Map<String, dynamic>>>(
                    stream: FriendsService.getFriendsStream(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      
                      final friends = snapshot.data ?? [];
                      
                      if (friends.isEmpty) {
                        return const Text('Nemate prijatelja', style: TextStyle(color: Colors.grey));
                      }
                      
                      return SizedBox(
                        height: 100,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: friends.length,
                          itemBuilder: (context, index) {
                            final friend = friends[index];
                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => OtherUserProfileScreen(
                                      userId: friend['id'],
                                      userName: friend['name'],
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                width: 80,
                                margin: const EdgeInsets.only(right: 12),
                                child: Column(
                                  children: [
                                    CircleAvatar(
                                      radius: 30,
                                      backgroundImage: friend['profilePic'] != null && friend['profilePic'].isNotEmpty
                                          ? NetworkImage(friend['profilePic'])
                                          : const AssetImage('assets/default_avatar.png')
                                              as ImageProvider,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      friend['name'],
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),

                  /// FRIEND REQUESTS SECTION
                  const SizedBox(height: 24),
                  const Text('Zahtevi za prijateljstvo', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  StreamBuilder<List<Map<String, dynamic>>>(
                    stream: FriendsService.getFriendRequestsStream(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      
                      final requests = snapshot.data ?? [];
                      
                      if (requests.isEmpty) {
                        return const Text('Nemate zahteva za prijateljstvo', style: TextStyle(color: Colors.grey));
                      }
                      
                      return Column(
                        children: requests.map((request) {
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: request['profilePic'] != null && request['profilePic'].isNotEmpty
                                  ? NetworkImage(request['profilePic'])
                                  : const AssetImage('assets/default_avatar.png')
                                      as ImageProvider,
                            ),
                            title: Text(request['name']),
                            subtitle: Text(request['city'] ?? ''),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.check, color: Colors.green),
                                  onPressed: () => _acceptFriendRequest(request['id']),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, color: Colors.red),
                                  onPressed: () => _rejectFriendRequest(request['id']),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),

                  const SizedBox(height: 20),

                  /// ✅ UPDATED: SECURE LOGOUT BUTTON
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _secureLogout,
                      icon: const Icon(Icons.logout),
                      label: const Text("Logout"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// ✅ NEW: Secure logout method
  Future<void> _secureLogout() async {
    // Show confirmation dialog
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Potvrda'),
        content: const Text('Da li ste sigurni da želite da se izlogujete?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Otkaži'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Izloguj se', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldLogout != true) return;

    try {
      // Clear all navigation history and go to login
      await FirebaseAuth.instance.signOut();
      
      if (context.mounted) {
        // ✅ CRITICAL: Clear entire navigation stack
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false, // Remove all routes
        );
      }
    } catch (e) {
      _showSnackBar('Greška pri logout-u: $e');
    }
  }

  /// Save profile - UPDATED
  Future<void> saveProfile() async {
    try {
      await UserDataHelper.updateUserData(uid, {
        'bio': bioController.text.trim(),
        'city': cityController.text.trim(),
      });

      setState(() {
        isEditing = false;
        selectedCategory = null;
        selectedSubcategory = null;
      });
      
      _showSnackBar('Profil uspešno ažuriran!');
    } catch (e) {
      _showSnackBar('Greška pri čuvanju profila: $e');
    }
  }

  /// Add hobby - UPDATED
  Future<void> addHobby() async {
    final hobby = "$selectedCategory > $selectedSubcategory";

    try {
      await UserDataHelper.addToArray(uid, 'hobbies', hobby);

      setState(() {
        selectedSubcategory = null;
      });
      
      _showSnackBar('Hobi uspešno dodat!');
    } catch (e) {
      _showSnackBar('Greška pri dodavanju hobija: $e');
    }
  }

  /// Remove hobby - UPDATED
  Future<void> removeHobby(String hobby) async {
    try {
      await UserDataHelper.removeFromArray(uid, 'hobbies', hobby);
      _showSnackBar('Hobi uspešno uklonjen!');
    } catch (e) {
      _showSnackBar('Greška pri uklanjanju hobija: $e');
    }
  }

  @override
  void dispose() {
    bioController.dispose();
    cityController.dispose();
    super.dispose();
  }
}