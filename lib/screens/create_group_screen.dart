// screens/create_group_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/messaging_service.dart';
import '../services/friends_service.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  final List<String> _selectedParticipants = [];
  final List<Map<String, dynamic>> _availableFriends = [];
  bool _isLoading = false;
  bool _isLoadingFriends = true;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    try {
      setState(() => _isLoadingFriends = true);
      
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return;

      // Get friends using the optimized FriendsService
      // First, get the stream of friends
      final friendsStream = FriendsService.getFriendsStream();
      
      // Take the first snapshot
      final friendsSnapshot = await friendsStream.first;
      
      setState(() {
        _availableFriends.clear();
        _availableFriends.addAll(friendsSnapshot);
      });
      
    } catch (e) {
      print('Error loading friends: $e');
      // Fallback: try direct Firestore query
      _loadFriendsFallback();
    } finally {
      if (mounted) {
        setState(() => _isLoadingFriends = false);
      }
    }
  }

  // Fallback method if FriendsService fails
  Future<void> _loadFriendsFallback() async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return;

      // Query friendships where current user is the userId
      final friendships = await FirebaseFirestore.instance
          .collection('friendships')
          .where('userId', isEqualTo: currentUserId)
          .limit(50)
          .get();

      if (friendships.docs.isEmpty) return;

      // Get friend IDs
      final friendIds = friendships.docs
          .map((doc) => doc.data()['friendId'] as String)
          .where((id) => id.isNotEmpty)
          .toList();

      if (friendIds.isEmpty) return;

      // Get user data for friends (in batches of 10 for Firestore)
      final List<Map<String, dynamic>> friends = [];
      
      // Process in batches of 10 due to Firestore's 'in' query limit
      for (int i = 0; i < friendIds.length; i += 10) {
        final batchIds = friendIds.sublist(
          i,
          i + 10 < friendIds.length ? i + 10 : friendIds.length,
        );
        
        final usersSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where(FieldPath.documentId, whereIn: batchIds)
            .get();

        for (final doc in usersSnapshot.docs) {
          friends.add({
            'id': doc.id,
            'name': doc['name'] ?? 'Nepoznato',
            'profilePic': doc['profilePic'],
          });
        }
      }

      setState(() {
        _availableFriends.clear();
        _availableFriends.addAll(friends);
      });
    } catch (e) {
      print('Error in friends fallback: $e');
    }
  }

  Future<void> _createGroup() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedParticipants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Izaberite bar jednog prijatelja')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Create group - always private since public option removed
      final groupId = await MessagingService.createGroup(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        participantIds: _selectedParticipants,
        isPublic: false, // Always false - groups are now private/friends-only
      );

      if (!mounted) return;

      Navigator.pop(context, groupId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Grupa je kreirana')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Greška: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kreiraj grupu'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _isLoading ? null : _createGroup,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    // Group name field
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Naziv grupe',
                        prefixIcon: Icon(Icons.group),
                        hintText: 'Unesite naziv grupe',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Unesite naziv grupe';
                        }
                        if (value.trim().length < 2) {
                          return 'Naziv mora imati bar 2 karaktera';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Group description field
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Opis (opciono)',
                        prefixIcon: Icon(Icons.description),
                        hintText: 'Dodajte opis grupe...',
                      ),
                      maxLines: 3,
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Friends selection header
                    Row(
                      children: [
                        const Text(
                          'Izaberi prijatelje:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        if (_selectedParticipants.isNotEmpty)
                          Text(
                            '${_selectedParticipants.length} izabrano',
                            style: const TextStyle(
                              color: Colors.orange,
                              fontSize: 14,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    // Loading indicator for friends
                    if (_isLoadingFriends)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(
                          child: Column(
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 8),
                              Text('Učitavanje prijatelja...'),
                            ],
                          ),
                        ),
                      ),
                    
                    // No friends message
                    if (!_isLoadingFriends && _availableFriends.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Center(
                          child: Column(
                            children: [
                              const Icon(
                                Icons.people_outline,
                                size: 50,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Nemate prijatelja',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Dodajte prijatelje da biste kreirali grupu',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    
                    // Friends list
                    if (!_isLoadingFriends && _availableFriends.isNotEmpty)
                      Column(
                        children: _availableFriends.map((friend) {
                          final isSelected = _selectedParticipants.contains(friend['id']);
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            elevation: isSelected ? 2 : 0,
                            color: isSelected ? Colors.blue[50] : null,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                color: isSelected ? Colors.blue : Colors.grey[300]!,
                                width: isSelected ? 1 : 0.5,
                              ),
                            ),
                            child: CheckboxListTile(
                              title: Text(
                                friend['name'],
                                style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              subtitle: friend['profilePic'] != null 
                                  ? Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundImage: NetworkImage(friend['profilePic']),
                                          radius: 16,
                                        ),
                                        const SizedBox(width: 8),
                                        if (isSelected)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.blue,
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: const Text(
                                              'Izabran',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                      ],
                                    )
                                  : null,
                              value: isSelected,
                              onChanged: (value) {
                                setState(() {
                                  if (value == true) {
                                    _selectedParticipants.add(friend['id']);
                                  } else {
                                    _selectedParticipants.remove(friend['id']);
                                  }
                                });
                              },
                              secondary: friend['profilePic'] == null 
                                  ? CircleAvatar(
                                      backgroundColor: Colors.blue[100],
                                      child: Text(
                                        friend['name'].substring(0, 1).toUpperCase(),
                                        style: const TextStyle(color: Colors.blue),
                                      ),
                                    )
                                  : null,
                              controlAffinity: ListTileControlAffinity.leading,
                            ),
                          );
                        }).toList(),
                      ),
                    
                    // Selected participants summary
                    if (_selectedParticipants.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Izabrani prijatelji:',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: _selectedParticipants.map((participantId) {
                                final friend = _availableFriends.firstWhere(
                                  (f) => f['id'] == participantId,
                                  orElse: () => {'name': 'Nepoznato'},
                                );
                                return Chip(
                                  label: Text(friend['name']),
                                  avatar: friend['profilePic'] != null
                                      ? CircleAvatar(
                                          backgroundImage: NetworkImage(friend['profilePic']),
                                          radius: 12,
                                        )
                                      : CircleAvatar(
                                          backgroundColor: Colors.blue[100],
                                          radius: 12,
                                          child: Text(
                                            friend['name'].substring(0, 1).toUpperCase(),
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                        ),
                                  deleteIcon: const Icon(Icons.close, size: 16),
                                  onDeleted: () {
                                    setState(() {
                                      _selectedParticipants.remove(participantId);
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    
                    // Create button at bottom
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _createGroup,
                        icon: const Icon(Icons.group_add),
                        label: const Text('Kreiraj grupu'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.orange,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }
}