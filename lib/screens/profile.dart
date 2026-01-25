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

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final String uid = FirebaseAuth.instance.currentUser!.uid;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();

  bool _isEditing = false;
  String? _selectedCategory;
  String? _selectedSubcategory;
  File? _pickedImage;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final doc = await _firestore.collection('users_private').doc(uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        _bioController.text = data['bio'] ?? '';
        _cityController.text = data['city'] ?? '';
      }
    } catch (e) {
      print('Error loading initial data: $e');
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() => _pickedImage = File(pickedFile.path));
        await _uploadImage();
      }
    } catch (e) {
      _showSnackBar('Greška pri odabiru slike: $e');
    }
  }

  Future<void> _uploadImage() async {
    if (_pickedImage == null) return;

    setState(() => _isUploading = true);

    try {
      final storageRef = _storage.ref().child('profile_pictures/$uid.jpg');
      await storageRef.putFile(_pickedImage!);
      final imageUrl = await storageRef.getDownloadURL();

      await _firestore.collection('users_private').doc(uid).update({
        'profilePic': imageUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _firestore.collection('users').doc(uid).update({
        'profilePic': imageUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _showSnackBar('Profilna slika uspešno ažurirana!');
      setState(() => _pickedImage = null);
    } catch (e) {
      _showSnackBar('Greška pri upload-u slike: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

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

  Future<void> _saveProfile() async {
    try {
      await _firestore.collection('users_private').doc(uid).update({
        'bio': _bioController.text.trim(),
        'city': _cityController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _firestore.collection('users').doc(uid).update({
        'bio': _bioController.text.trim(),
        'city': _cityController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _isEditing = false;
        _selectedCategory = null;
        _selectedSubcategory = null;
      });

      _showSnackBar('Profil uspešno ažuriran!');
    } catch (e) {
      _showSnackBar('Greška pri čuvanju profila: $e');
    }
  }

  Future<void> _addHobby() async {
    if (_selectedCategory == null || _selectedSubcategory == null) return;

    final hobby = "$_selectedCategory > $_selectedSubcategory";

    try {
      await _firestore.collection('users_private').doc(uid).update({
        'hobbies': FieldValue.arrayUnion([hobby]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _firestore.collection('users').doc(uid).update({
        'hobbies': FieldValue.arrayUnion([hobby]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      setState(() => _selectedSubcategory = null);
      _showSnackBar('Hobi uspešno dodat!');
    } catch (e) {
      _showSnackBar('Greška pri dodavanju hobija: $e');
    }
  }

  Future<void> _removeHobby(String hobby) async {
    try {
      await _firestore.collection('users_private').doc(uid).update({
        'hobbies': FieldValue.arrayRemove([hobby]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _firestore.collection('users').doc(uid).update({
        'hobbies': FieldValue.arrayRemove([hobby]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _showSnackBar('Hobi uspešno uklonjen!');
    } catch (e) {
      _showSnackBar('Greška pri uklanjanju hobija: $e');
    }
  }

  Stream<int> _getUnreadCountStream() {
    return _firestore
        .collection('conversations')
        .where('participants', arrayContains: uid)
        .snapshots()
        .map((snapshot) {
          int total = 0;
          for (final doc in snapshot.docs) {
            final data = doc.data();
            final unread = (data['unreadCount'] as Map<String, dynamic>?)?[uid] as int? ?? 0;
            total += unread;
          }
          return total;
        });
  }

  Future<void> _secureLogout() async {
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
      await FirebaseAuth.instance.signOut();
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      _showSnackBar('Greška pri logout-u: $e');
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  void dispose() {
    _bioController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Profil"),
        actions: [
          StreamBuilder<int>(
            stream: _getUnreadCountStream(),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.message),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MessagesScreen()),
                    ),
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
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
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
            icon: Icon(_isEditing ? Icons.check : Icons.edit),
            onPressed: () => _isEditing ? _saveProfile() : setState(() => _isEditing = true),
          ),
        ],
      ),
      body: _buildProfileContent(),
    );
  }

Widget _buildProfileContent() {
  return StreamBuilder<DocumentSnapshot>(
    stream: _firestore.collection('users_private').doc(uid).snapshots(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

      final data = snapshot.data!.data() as Map<String, dynamic>;
      
      return SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProfileHeader(data),
              const SizedBox(height: 20),
              _buildCityField(data),
              const SizedBox(height: 16),
              _buildBioSection(data),
              const SizedBox(height: 20),
              _buildHobbiesSection(data),
              const SizedBox(height: 24),
              _buildFriendsSection(),
              const SizedBox(height: 20),
              _buildLogoutButton(),
            ],
          ),
        ),
      );
    },
  );
}

  Widget _buildProfileHeader(Map<String, dynamic> data) {
    final String? profilePicUrl = data['profilePic'];
    final String name = data['name'] ?? 'No name';
    final String email = FirebaseAuth.instance.currentUser!.email ?? '';

    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade300, width: 2),
                ),
                child: ClipOval(
                  child: _buildProfileImage(profilePicUrl),
                ),
              ),
              if (_isEditing && !_isUploading)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.camera_alt, size: 20),
                      color: Colors.white,
                      onPressed: _showImagePickerDialog,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(name, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(email, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildProfileImage(String? profilePicUrl) {
    if (_isUploading) return const Center(child: CircularProgressIndicator());
    if (_pickedImage != null) return Image.file(_pickedImage!, fit: BoxFit.cover);
    if (profilePicUrl != null && profilePicUrl.isNotEmpty) {
      return Image.network(
        profilePicUrl,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, size: 60, color: Colors.grey),
      );
    }
    return const Icon(Icons.person, size: 60, color: Colors.grey);
  }

  Widget _buildCityField(Map<String, dynamic> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Grad', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _isEditing
            ? TextField(
                controller: _cityController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Unesi svoj grad...',
                ),
              )
            : Text((data['city'] ?? '').isNotEmpty ? data['city']! : 'Grad nije dodat.'),
      ],
    );
  }

  Widget _buildBioSection(Map<String, dynamic> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('O meni', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _isEditing
            ? TextField(
                controller: _bioController,
                maxLines: 3,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Napiši nešto o sebi...',
                ),
              )
            : Text((data['bio'] ?? '').isNotEmpty ? data['bio']! : 'Bio nije dodat.'),
      ],
    );
  }

  Widget _buildHobbiesSection(Map<String, dynamic> data) {
    final List hobbies = data['hobbies'] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Hobiji', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (hobbies.isEmpty)
          const Text('Niste dodali hobije', style: TextStyle(color: Colors.grey))
        else
          Wrap(
            spacing: 8,
            children: hobbies.map<Widget>((hobby) {
              return Chip(
                label: Text(hobby),
                deleteIcon: _isEditing ? const Icon(Icons.close) : null,
                onDeleted: _isEditing ? () => _removeHobby(hobby) : null,
              );
            }).toList(),
          ),
        if (_isEditing) ...[
          const SizedBox(height: 16),
          DropdownButton<String>(
            hint: const Text("Izaberi kategoriju"),
            value: _selectedCategory,
            isExpanded: true,
            items: hobbyCategories.keys.map((category) {
              return DropdownMenuItem(value: category, child: Text(category));
            }).toList(),
            onChanged: (value) => setState(() {
              _selectedCategory = value;
              _selectedSubcategory = null;
            }),
          ),
          if (_selectedCategory != null)
            DropdownButton<String>(
              hint: const Text("Izaberi podkategoriju"),
              value: _selectedSubcategory,
              isExpanded: true,
              items: hobbyCategories[_selectedCategory]!
                  .map((sub) => DropdownMenuItem(value: sub, child: Text(sub)))
                  .toList(),
              onChanged: (value) => setState(() => _selectedSubcategory = value),
            ),
          ElevatedButton(
            onPressed: _selectedCategory != null && _selectedSubcategory != null ? _addHobby : null,
            child: const Text("Dodaj hobi"),
          ),
        ],
      ],
    );
  }

  Widget _buildFriendsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => OtherUserProfileScreen(
                          userId: friend['id'],
                          userName: friend['name'],
                        ),
                      ),
                    ),
                    child: Container(
                      width: 80,
                      margin: const EdgeInsets.only(right: 12),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundImage: friend['profilePic'] != null && friend['profilePic'].isNotEmpty
                                ? NetworkImage(friend['profilePic'])
                                : const AssetImage('assets/default_avatar.png') as ImageProvider,
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
      ],
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
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
    );
  }
}