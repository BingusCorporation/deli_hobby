// screens/create_group_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/messaging_service.dart';
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
  final List<Map<String, dynamic>> _availableUsers = [];
  bool _isLoading = false;
  bool _isPublic = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where(FieldPath.documentId, isNotEqualTo: currentUserId)
        .limit(50)
        .get();

    setState(() {
      _availableUsers.clear();
      for (final doc in snapshot.docs) {
        _availableUsers.add({
          'id': doc.id,
          'name': doc['name'] ?? 'Nepoznato',
          'profilePic': doc['profilePic'],
        });
      }
    });
  }

  Future<void> _createGroup() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedParticipants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Izaberite bar jednog učesnika')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final groupId = await MessagingService.createGroup(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        participantIds: _selectedParticipants,
        isPublic: _isPublic,
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
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Naziv grupe',
                        prefixIcon: Icon(Icons.group),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Unesite naziv grupe';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Opis (opciono)',
                        prefixIcon: Icon(Icons.description),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Javna grupa'),
                      subtitle: const Text('Svi mogu videti i pridružiti se'),
                      value: _isPublic,
                      onChanged: (value) => setState(() => _isPublic = value),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Izaberi učesnike:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._availableUsers.map((user) {
                      final isSelected = _selectedParticipants.contains(user['id']);
                      return CheckboxListTile(
                        title: Text(user['name']),
                        subtitle: user['profilePic'] != null 
                            ? CircleAvatar(
                                backgroundImage: NetworkImage(user['profilePic']),
                                radius: 16,
                              )
                            : null,
                        value: isSelected,
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              _selectedParticipants.add(user['id']);
                            } else {
                              _selectedParticipants.remove(user['id']);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
    );
  }
}