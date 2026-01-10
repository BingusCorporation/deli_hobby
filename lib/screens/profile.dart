import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/hobbies.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

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

  /// Controller for bio text input
  final TextEditingController bioController = TextEditingController();

  /// Currently selected category in dropdown
  String? selectedCategory;

  /// Currently selected subcategory in dropdown
  String? selectedSubcategory;

  /// For picking a new image
  File? _pickedImage;
  bool _isUploading = false;

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
  Future<void> _uploadImage() async {
    if (_pickedImage == null) return;

    setState(() {
      _isUploading = true;
    });

    try {
      // Create reference to Firebase Storage location
      final storageRef = storage.ref().child('profile_pictures/$uid.jpg');
      
      // Upload the file
      await storageRef.putFile(_pickedImage!);
      
      // Get download URL
      final imageUrl = await storageRef.getDownloadURL();
      
      // Update Firestore with new image URL
      await firestore.collection('users').doc(uid).update({
        'profilePic': imageUrl,
      });

      _showSnackBar('Profilna slika uspešno ažurirana!');
      
      // Reset picked image
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
      body: StreamBuilder<DocumentSnapshot>(
        stream: firestore.collection('users').doc(uid).snapshots(),
        builder: (context, snapshot) {
          /// While loading data
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          /// Convert Firestore document to Dart map
          final data = snapshot.data!.data() as Map<String, dynamic>;

          /// Read fields (with defaults)
          final String name = data['name'] ?? 'No name';
          final String bio = data['bio'] ?? '';
          final String? profilePicUrl = data['profilePic'];
          final List hobbies = data['hobbies'] ?? [];

          /// Prevent cursor jumping
          if (!isEditing) {
            bioController.text = bio;
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// PROFILE PICTURE SECTION
                Center(
                  child: Stack(
                    children: [
                      /// Profile image
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
                              ? const Center(
                                  child: CircularProgressIndicator(),
                                )
                              : _pickedImage != null
                                  ? Image.file(
                                      _pickedImage!,
                                      fit: BoxFit.cover,
                                    )
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

                      /// Edit button (only when in edit mode)
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

                /// USER NAME
                Center(
                  child: Text(
                    name,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),

                const SizedBox(height: 20),

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
                    : Text(bio.isEmpty ? 'Bio nije dodat.' : bio),

                const SizedBox(height: 20),

                /// HOBBIES TITLE
                const Text('Hobiji', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),

                /// LIST OF HOBBIES
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

                /// ADD HOBBY UI (only when editing)
                if (isEditing) ...[
                  const SizedBox(height: 16),

                  /// CATEGORY DROPDOWN
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

                  /// SUBCATEGORY DROPDOWN
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

                  /// ADD BUTTON
                  ElevatedButton(
                    onPressed: selectedCategory != null &&
                            selectedSubcategory != null
                        ? addHobby
                        : null,
                    child: const Text("Dodaj hobi"),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  /// SAVE BIO TO FIRESTORE
  Future<void> saveProfile() async {
    await firestore.collection('users').doc(uid).update({
      'bio': bioController.text.trim(),
    });

    setState(() {
      isEditing = false;
      selectedCategory = null;
      selectedSubcategory = null;
    });
  }

  /// ADD A HOBBY
  Future<void> addHobby() async {
    final hobby = "$selectedCategory > $selectedSubcategory";

    await firestore.collection('users').doc(uid).update({
      'hobbies': FieldValue.arrayUnion([hobby]),
    });

    setState(() {
      selectedSubcategory = null;
    });
  }

  /// REMOVE A HOBBY
  Future<void> removeHobby(String hobby) async {
    await firestore.collection('users').doc(uid).update({
      'hobbies': FieldValue.arrayRemove([hobby]),
    });
  }

  @override
  void dispose() {
    bioController.dispose();
    super.dispose();
  }
}