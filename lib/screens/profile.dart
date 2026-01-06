import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import'../data/hobbies.dart';
/// TEMPORARY hobby data

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

  /// Are we editing the profile?
  bool isEditing = false;

  /// Controller for bio text input
  final TextEditingController bioController = TextEditingController();

  /// Currently selected category in dropdown
  String? selectedCategory;

  /// Currently selected subcategory in dropdown
  String? selectedSubcategory;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Profil"),

        /// Edit / Save button
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

      /// Live connection to Firestore
      body: StreamBuilder<DocumentSnapshot>(
        stream: firestore.collection('users').doc(uid).snapshots(),//uzima kolekciju users i trazi po id
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

                /// USER NAME
                Text(
                  name,
                  style: Theme.of(context).textTheme.headlineSmall,
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
}
