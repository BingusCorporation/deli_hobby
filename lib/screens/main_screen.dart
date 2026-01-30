import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/hobbies.dart';
import '../data/city.dart';
import 'profile.dart';
import 'messages_screen.dart';
import 'chat_screen.dart';
import '../auth/login_screen.dart';
import 'other_user_profile.dart';
import '../services/init.dart';
import 'oglasi_screen.dart';
import '../events/events_browse_screen.dart';
import '../services/friends_service.dart';
import '../events/event_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  String? _selectedCity;
  String? _selectedCategory;
  String? _selectedSubcategory;
  final TextEditingController _nameSearchController = TextEditingController();
  
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  String _searchStatus = '';

  @override
  void initState() {
    super.initState();
    _setupAuthListener();
    initializeFirestoreStructure();
  }

  @override
  void dispose() {
    _nameSearchController.dispose();
    super.dispose();
  }

  void _setupAuthListener() {
    _auth.authStateChanges().listen((User? user) {
      if (user == null && mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    });
  }

  String get _currentUserId => _auth.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    if (_auth.currentUser == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Deli Hobby'),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
        actions: [
          StreamBuilder<int>(
            stream: EventService().getMyPendingInvitesCountStream(),
            builder: (context, snapshot) {
              final inviteCount = snapshot.data ?? 0;
              return Container(
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.event),
                      tooltip: 'Događaji',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const EventsBrowseScreen()),
                        );
                      },
                    ),
                    if (inviteCount > 0)
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
                            inviteCount > 9 ? '9+' : inviteCount.toString(),
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
                ),
              );
            },
          ),
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(Icons.list_alt),
              tooltip: 'Oglasi',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const OglasiScreen()),
                );
              },
            ),
          ),
          StreamBuilder<int>(
            stream: _getUnreadCountStream(),
            builder: (context, unreadSnapshot) {
              return StreamBuilder<int>(
                stream: FriendsService.getFriendRequestsCountStream(),
                builder: (context, friendsSnapshot) {
                  return StreamBuilder<int>(
                    stream: EventService().getMyPendingInvitesCountStream(),
                    builder: (context, invitesSnapshot) {
                      final unreadCount = unreadSnapshot.data ?? 0;
                      final friendRequestCount = friendsSnapshot.data ?? 0;
                      final inviteCount = invitesSnapshot.data ?? 0;
                      final totalCount = unreadCount + friendRequestCount + inviteCount;
                      
                      return Container(
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Stack(
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
                            if (totalCount > 0)
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
                                    totalCount > 9 ? '9+' : totalCount.toString(),
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
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(Icons.person),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfileScreen(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.orange.shade50,
              Colors.white,
            ],
            stops: const [0.0, 0.3],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.orange.shade100,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _nameSearchController,
                        decoration: InputDecoration(
                          hintText: 'Pretraži po imenu...',
                          prefixIcon: Icon(Icons.search, color: Colors.orange.shade700),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.orange.shade600, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        onChanged: (value) => setState(() {}),
                        maxLines: 1,
                      ),
                      
                      const SizedBox(height: 16),
                      
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  hint: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Text(
                                      'Hobi',
                                      style: TextStyle(color: Colors.grey.shade600),
                                    ),
                                  ),
                                  value: _selectedCategory,
                                  items: [
                                    DropdownMenuItem(
                                      value: null,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                        child: Text(
                                          'Svi hobiji',
                                          style: TextStyle(color: Colors.grey.shade600),
                                        ),
                                      ),
                                    ),
                                    ...hobbyCategories.keys.map((category) {
                                      return DropdownMenuItem(
                                        value: category,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 16),
                                          child: Text(
                                            category,
                                            style: TextStyle(color: Colors.grey.shade800),
                                          ),
                                        ),
                                      );
                                    }),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedCategory = value;
                                      _selectedSubcategory = null;
                                    });
                                  },
                                ),
                              ),
                            ),
                          ),
                          
                          const SizedBox(width: 12),
                          
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  hint: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Text(
                                      'Grad',
                                      style: TextStyle(color: Colors.grey.shade600),
                                    ),
                                  ),
                                  value: _selectedCity,
                                  items: [
                                    DropdownMenuItem(
                                      value: null,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                        child: Text(
                                          'Svi gradovi',
                                          style: TextStyle(color: Colors.grey.shade600),
                                        ),
                                      ),
                                    ),
                                    ...serbiaCities.map((city) {
                                      return DropdownMenuItem(
                                        value: city,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 16),
                                          child: Text(
                                            city,
                                            style: TextStyle(color: Colors.grey.shade800),
                                          ),
                                        ),
                                      );
                                    }),
                                  ],
                                  onChanged: (value) => setState(() => _selectedCity = value),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      if (_selectedCategory != null && hobbyCategories[_selectedCategory]!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              hint: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  'Podkategorija (opciono)',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              ),
                              value: _selectedSubcategory,
                              items: [
                                DropdownMenuItem(
                                  value: null,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Text(
                                      'Sve podkategorije',
                                      style: TextStyle(color: Colors.grey.shade600),
                                    ),
                                  ),
                                ),
                                ...hobbyCategories[_selectedCategory]!.map((sub) {
                                  return DropdownMenuItem(
                                    value: sub,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      child: Text(
                                        sub,
                                        style: TextStyle(color: Colors.grey.shade800),
                                      ),
                                    ),
                                  );
                                }),
                              ],
                              onChanged: (value) => setState(() => _selectedSubcategory = value),
                            ),
                          ),
                        ),
                      ],
                      
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.orange.shade400,
                                Colors.orange.shade600,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.orange.shade400.withOpacity(0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: _searchForMatches,
                            icon: const Icon(Icons.search),
                            label: const Text('Pronađi ljude'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ),
                      
                      if (_selectedCategory != null || _selectedCity != null) ...[
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.start,
                          children: [
                            if (_selectedCategory != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade600,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _selectedSubcategory != null 
                                          ? '$_selectedCategory > $_selectedSubcategory'
                                          : _selectedCategory!,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    GestureDetector(
                                      onTap: () => setState(() {
                                        _selectedCategory = null;
                                        _selectedSubcategory = null;
                                      }),
                                      child: Icon(
                                        Icons.close,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (_selectedCity != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade600,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _selectedCity!,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    GestureDetector(
                                      onTap: () => setState(() => _selectedCity = null),
                                      child: Icon(
                                        Icons.close,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              
              if (_searchStatus.isNotEmpty)
                SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.orange.shade100,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _searchResults.isEmpty ? Icons.info_outline : Icons.check_circle,
                          color: _searchResults.isEmpty ? Colors.orange.shade600 : Colors.green.shade600,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _searchStatus,
                            style: TextStyle(
                              color: _searchResults.isEmpty ? Colors.orange.shade700 : Colors.green.shade700,
                              fontSize: 13,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_searchResults.isNotEmpty && _selectedCategory != null)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedCategory = null;
                                _selectedSubcategory = null;
                                _selectedCity = null;
                                _searchResults = [];
                                _searchStatus = '';
                              });
                            },
                            style: TextButton.styleFrom(
                              minimumSize: Size.zero,
                              padding: EdgeInsets.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Obriši filtere',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              
              if (_isSearching)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          color: Colors.orange.shade700,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Tražim ljude sa sličnim hobijima...',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_searchResults.isEmpty && _searchStatus.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 80,
                          color: Colors.orange.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Izaberite hobi i grad\nza pretragu',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            'Pronađite ljude sa sličnim interesovanjima',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_searchResults.isEmpty && _searchStatus.isNotEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 80,
                          color: Colors.orange.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Nema rezultata',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            'Promenite filtere i pokušajte ponovo',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final user = _searchResults[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: _buildUserCard(user),
                      );
                    },
                    childCount: _searchResults.length,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Stream<int> _getUnreadCountStream() {
    return _firestore
        .collection('conversations')
        .where('participants', arrayContains: _currentUserId)
        .snapshots()
        .map((snapshot) {
          int total = 0;
          for (final doc in snapshot.docs) {
            final data = doc.data();
            final unread = (data['unreadCount'] as Map<String, dynamic>?)?[_currentUserId] as int? ?? 0;
            total += unread;
          }
          return total;
        });
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final String? profilePic = user['profilePic'] as String?;
    final String? city = user['city'] as String?;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OtherUserProfileScreen(
              userId: user['id'] as String,
              userName: user['name'] as String? ?? 'Nepoznato',
            ),
          ),
        );
      },
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.shade100.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.orange.shade300,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.shade100.withOpacity(0.5),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: profilePic != null && profilePic.isNotEmpty
                        ? Image.network(
                            profilePic,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => _buildDefaultAvatar(user['name'] as String?),
                          )
                        : _buildDefaultAvatar(user['name'] as String?),
                  ),
                ),
                const SizedBox(width: 12),
                
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user['name'] as String? ?? 'Nepoznato',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF333333),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (city != null && city.isNotEmpty)
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 14,
                              color: Colors.orange.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              city,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(
                          otherUserId: user['id'] as String,
                          otherUserName: user['name'] as String? ?? 'Nepoznato',
                        ),
                      ),
                    );
                  },
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Icon(
                      Icons.message,
                      color: Colors.orange.shade700,
                      size: 18,
                    ),
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  tooltip: 'Pošalji poruku',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar(String? userName) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.orange.shade200,
            Colors.orange.shade400,
          ],
        ),
      ),
      child: Center(
        child: Text(
          userName != null && userName.isNotEmpty 
              ? userName[0].toUpperCase() 
              : '?',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Future<void> _searchForMatches() async {
    if (_auth.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sesija je istekla. Molimo prijavite se ponovo.')),
      );
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
      return;
    }

    if (_selectedCategory == null && _selectedCity == null && _nameSearchController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Izaberite bar jedan filter za pretragu'),
          backgroundColor: Colors.orange.shade600,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSearching = true;
      _searchResults = [];
      _searchStatus = '';
    });

    try {

      Query query = _firestore.collection('users');
      query = query.where(FieldPath.documentId, isNotEqualTo: _currentUserId);
      
      if (_selectedCity != null && _selectedCity!.isNotEmpty) {
        query = query.where('city', isEqualTo: _selectedCity);
      }
      

      final snapshot = await query.get();

      final List<Map<String, dynamic>> results = [];
      final String nameFilter = _nameSearchController.text.trim().toLowerCase();
      
      for (final doc in snapshot.docs) {
        final userData = doc.data() as Map<String, dynamic>;
        final String userName = (userData['name'] as String? ?? '').toLowerCase();
        final List<dynamic> userHobbies = userData['hobbies'] as List<dynamic>? ?? [];
        

        if (nameFilter.isNotEmpty && !userName.contains(nameFilter)) {
          continue;
        }
        
 
        bool hasMatchingHobby = false;
        List<String> matchingHobbies = [];
        
        if (_selectedCategory != null) {
          for (final hobby in userHobbies) {
            final hobbyStr = hobby.toString();
            if (_selectedSubcategory != null) {
              if (hobbyStr == '$_selectedCategory > $_selectedSubcategory') {
                hasMatchingHobby = true;
                matchingHobbies.add(hobbyStr);
              }
            } else {
              if (hobbyStr.startsWith('$_selectedCategory >')) {
                hasMatchingHobby = true;
                matchingHobbies.add(hobbyStr);
              }
            }
          }
        } else {
          hasMatchingHobby = true;
        }
        
        if (hasMatchingHobby) {
          results.add({
            'id': doc.id,
            ...userData,
            'matchingHobbies': matchingHobbies,
          });
        }
      }
      
      setState(() {
        _searchResults = results;
        _searchStatus = results.isEmpty 
            ? 'Nema pronađenih ljudi sa traženim kriterijumima'
            : 'Pronađeno ${results.length} ljudi';
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Greška pri pretrazi: $e'),
            backgroundColor: Colors.red.shade600,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }
}