import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/event_model.dart';
import '../../models/event_invite_model.dart';
import '../../services/event_service.dart';

class EventInvitesScreen extends StatefulWidget {
  final Event event;

  const EventInvitesScreen({
    super.key,
    required this.event,
  });

  @override
  State<EventInvitesScreen> createState() => _EventInvitesScreenState();
}

class _EventInvitesScreenState extends State<EventInvitesScreen> {
  final EventService _eventService = EventService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pozivnice'),
      ),
      body: Column(
        children: [
          // Search section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pozovi korisnika',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: 'Pretrazi po imenu...',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.search),
                        ),
                        onSubmitted: (_) => _searchUsers(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _searchUsers,
                      child: const Text('Trazi'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Search results
          if (_isSearching)
            const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            )
          else if (_searchResults.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final user = _searchResults[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: user['profilePic'] != null &&
                              user['profilePic'].isNotEmpty
                          ? NetworkImage(user['profilePic'])
                          : null,
                      child: user['profilePic'] == null ||
                              user['profilePic'].isEmpty
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    title: Text(user['name'] ?? 'Nepoznato'),
                    subtitle: Text(user['city'] ?? ''),
                    trailing: IconButton(
                      icon: const Icon(Icons.person_add),
                      onPressed: () => _sendInvite(user),
                    ),
                  );
                },
              ),
            ),

          const Divider(),

          // Existing invites
          Expanded(
            child: _buildInvitesList(),
          ),
        ],
      ),
    );
  }

  Widget _buildInvitesList() {
    return StreamBuilder<List<EventInvite>>(
      stream: _eventService.getEventInvites(widget.event.id!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Greska: ${snapshot.error}'));
        }

        final invites = snapshot.data ?? [];

        if (invites.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.mail_outline, size: 60, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'Nema poslatih pozivnica',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: invites.length,
          itemBuilder: (context, index) {
            final invite = invites[index];
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _getStatusColor(invite.status),
                  child: Icon(
                    _getStatusIcon(invite.status),
                    color: Colors.white,
                  ),
                ),
                title: Text(invite.inviteeName),
                subtitle: Text(_getStatusText(invite.status)),
                trailing: invite.isPending
                    ? IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () => _cancelInvite(invite),
                      )
                    : null,
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _searchUsers() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchResults = [];
    });

    try {
      final snapshot = await _firestore
          .collection('users')
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThanOrEqualTo: '$query\uf8ff')
          .limit(10)
          .get();

      setState(() {
        _searchResults = snapshot.docs.map((doc) {
          return {
            'id': doc.id,
            ...doc.data(),
          };
        }).toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Greska pri pretrazi: $e')),
        );
      }
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  Future<void> _sendInvite(Map<String, dynamic> user) async {
    try {
      await _eventService.sendInvite(
        widget.event.id!,
        user['id'],
        user['name'] ?? 'Nepoznato',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Pozivnica poslata korisniku ${user['name']}')),
        );
        setState(() {
          _searchResults = [];
          _searchController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Greska: $e')),
        );
      }
    }
  }

  Future<void> _cancelInvite(EventInvite invite) async {
    // For now just show a message - we could add delete functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pozivnica je na cekanju')),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'accepted':
        return Colors.green;
      case 'declined':
        return Colors.red;
      case 'pending':
      default:
        return Colors.orange;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'accepted':
        return Icons.check;
      case 'declined':
        return Icons.close;
      case 'pending':
      default:
        return Icons.hourglass_empty;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'accepted':
        return 'Prihvaceno';
      case 'declined':
        return 'Odbijeno';
      case 'pending':
      default:
        return 'Na cekanju';
    }
  }
}
