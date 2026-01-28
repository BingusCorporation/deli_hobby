import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/messaging_service.dart';

class ChatScreen extends StatefulWidget {
  final String otherUserId;
  final String otherUserName;
  
  const ChatScreen({
    super.key,
    required this.otherUserId,
    required this.otherUserName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  bool _isSending = false;
  bool _showInfoPanel = false;
  Map<String, dynamic>? _userInfo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
      _markMessagesAsRead();
      _loadUserInfo();
    });
  }

  Future<void> _loadUserInfo() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.otherUserId)
          .get();
      
      if (userDoc.exists) {
        setState(() {
          _userInfo = userDoc.data();
        });
      }
    } catch (e) {
      print('Error loading user info: $e');
    }
  }

  Future<void> _markMessagesAsRead() async {
    try {
      final conversationId = MessagingService.getConversationId(
        _auth.currentUser!.uid,
        widget.otherUserId,
      );
      await MessagingService.markAsRead(conversationId, widget.otherUserId);
    } catch (e) {
      print('Could not mark messages as read: $e');
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      });
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isSending) return;
    
    setState(() => _isSending = true);
    
    try {
      await MessagingService.sendMessage(widget.otherUserId, message);
      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Greška pri slanju poruke: $e')),
      );
    } finally {
      setState(() => _isSending = false);
    }
  }

  String _formatTime(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime timestamp) {
    return '${timestamp.day}.${timestamp.month}.${timestamp.year}.';
  }

  Widget _buildInfoPanel() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      right: _showInfoPanel ? 0 : -MediaQuery.of(context).size.width * 0.8,
      top: 0,
      bottom: 0,
      width: MediaQuery.of(context).size.width * 0.8,
      child: Material(
        elevation: 8,
        color: Colors.white,
        child: Column(
          children: [
            // Panel header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              color: Colors.blue,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () {
                      setState(() {
                        _showInfoPanel = false;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Informacije o korisniku',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // User avatar
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.blue.shade100,
                      child: Text(
                        widget.otherUserName[0].toUpperCase(),
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // User name
                    Text(
                      widget.otherUserName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    
                    // User email
                    if (_userInfo?['email'] != null)
                      Text(
                        _userInfo!['email'],
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    
                    const SizedBox(height: 24),
                    
                    // User info sections
                    _buildInfoSection(
                      title: 'Status',
                      content: _userInfo?['status'] ?? 'Aktivan',
                      icon: Icons.circle,
                      iconColor: Colors.green,
                    ),
                    
                    _buildInfoSection(
                      title: 'Učlanjen',
                      content: _userInfo?['createdAt'] != null
                          ? _formatDate((_userInfo!['createdAt'] as Timestamp).toDate())
                          : 'Nepoznato',
                      icon: Icons.calendar_today,
                      iconColor: Colors.blue,
                    ),
                    
                    if (_userInfo?['phone'] != null)
                      _buildInfoSection(
                        title: 'Telefon',
                        content: _userInfo!['phone'],
                        icon: Icons.phone,
                        iconColor: Colors.green,
                      ),
                    
                    if (_userInfo?['location'] != null)
                      _buildInfoSection(
                        title: 'Lokacija',
                        content: _userInfo!['location'],
                        icon: Icons.location_on,
                        iconColor: Colors.red,
                      ),
                    
                    const SizedBox(height: 24),
                    
                    // Actions
                    _buildActionButton(
                      icon: Icons.block,
                      label: 'Blokiraj korisnika',
                      color: Colors.red,
                      onTap: () {
                        _showBlockUserDialog();
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildActionButton(
                      icon: Icons.report,
                      label: 'Prijavi korisnika',
                      color: Colors.orange,
                      onTap: () {
                        _showReportDialog();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection({
    required String title,
    required String content,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: iconColor,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: color,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBlockUserDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Blokiraj korisnika'),
        content: Text('Da li ste sigurni da želite blokirati ${widget.otherUserName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Otkaži'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              // TODO: Implement block user functionality
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${widget.otherUserName} je blokiran'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            child: const Text(
              'Blokiraj',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Prijavi korisnika'),
        content: const Text('Molimo vas da opišete problem sa ovim korisnikom.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Otkaži'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              // TODO: Implement report user functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Prijava je poslata administratorima'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Prijavi'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.otherUserName),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              setState(() {
                _showInfoPanel = true;
              });
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Colors.orange.shade50,
              Colors.amber.shade50,
            ],
          ),
        ),
        child: Stack(
          children: [
            Column(
              children: [
                // Messages list
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: MessagingService.getConversationStream(widget.otherUserId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }
                      
                      final messages = snapshot.data?.docs ?? [];
                      
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _scrollToBottom();
                      });
                      
                      if (messages.isEmpty) {
                        return SingleChildScrollView(
                          child: SizedBox(
                            height: MediaQuery.of(context).size.height * 0.8,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.chat_bubble_outline, size: 60, color: Colors.grey.shade400),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Nema poruka',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Pošaljite prvu poruku!',
                                    style: TextStyle(color: Colors.grey, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }
                      
                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index].data() as Map<String, dynamic>;
                          final isMe = message['senderId'] == _auth.currentUser!.uid;
                          final messageText = message['message'] ?? '';
                          final timestamp = message['timestamp'] as Timestamp?;
                          final read = message['read'] as bool? ?? false;
                          
                          return Row(
                            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                            children: [
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                                ),
                                child: Container(
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  child: Column(
                                    crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isMe ? Colors.blue : Colors.grey[200],
                                          borderRadius: BorderRadius.circular(18),
                                        ),
                                        child: Text(
                                          messageText,
                                          style: TextStyle(
                                            color: isMe ? Colors.white : Colors.black,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (timestamp != null)
                                            Text(
                                              _formatTime(timestamp.toDate()),
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 12,
                                              ),
                                            ),
                                          if (isMe && read)
                                            Padding(
                                              padding: const EdgeInsets.only(left: 4),
                                              child: Icon(
                                                Icons.check_circle,
                                                size: 14,
                                                color: Colors.blue,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
                
                // Message input
                _buildMessageInput(),
              ],
            ),
            
            // Overlay when panel is open
            if (_showInfoPanel)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _showInfoPanel = false;
                  });
                },
                child: Container(
                  color: Colors.black54,
                ),
              ),
            
            // Info panel
            _buildInfoPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              focusNode: _focusNode,
              maxLines: null,
              decoration: InputDecoration(
                hintText: 'Unesite poruku...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.attach_file),
                  onPressed: () {
                    // TODO: Add file attachment
                  },
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: _isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send, color: Colors.white),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}