import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/hobbies.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../auth/login_screen.dart';

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

  /// Upload image to Firebase Storage
/// Upload image to Firebase Storage
Future<void> _uploadImage() async {
  if (_pickedImage == null) return;

  setState(() {
    _isUploading = true;
  });

  try {
    final storageRef = storage.ref().child('profile_pictures/$uid.jpg');
    await storageRef.putFile(_pickedImage!);
    final imageUrl = await storageRef.getDownloadURL();
    
    // Update both collections
    await firestore.collection('users_private').doc(uid).update({
      'profilePic': imageUrl,
    });
    
    await firestore.collection('users').doc(uid).update({
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Profil"),
        actions: [
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

  /// Save profile
Future<void> saveProfile() async {
  try {
    final updates = {
      'bio': bioController.text.trim(),
      'city': cityController.text.trim(),
    };
    
    // Update both collections
    await firestore.collection('users_private').doc(uid).update(updates);
    await firestore.collection('users').doc(uid).update(updates);

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

Future<void> addHobby() async {
  final hobby = "$selectedCategory > $selectedSubcategory";

  try {
    // Update both collections
    await firestore.collection('users_private').doc(uid).update({
      'hobbies': FieldValue.arrayUnion([hobby]),
    });
    
    await firestore.collection('users').doc(uid).update({
      'hobbies': FieldValue.arrayUnion([hobby]),
    });

    setState(() {
      selectedSubcategory = null;
    });
    
    _showSnackBar('Hobi uspešno dodat!');
  } catch (e) {
    _showSnackBar('Greška pri dodavanju hobija: $e');
  }
}

Future<void> removeHobby(String hobby) async {
  try {
    // Update both collections
    await firestore.collection('users_private').doc(uid).update({
      'hobbies': FieldValue.arrayRemove([hobby]),
    });
    
    await firestore.collection('users').doc(uid).update({
      'hobbies': FieldValue.arrayRemove([hobby]),
    });
    
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