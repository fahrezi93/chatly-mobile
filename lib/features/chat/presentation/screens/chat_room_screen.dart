import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../domain/chat_room_model.dart';
import '../../domain/message_model.dart';
import '../providers/inbox_provider.dart'; // We can borrow chatRepository from here
import '../../../auth/presentation/auth_provider.dart';
import '../../../../core/network/socket_service.dart';
import '../../../../core/network/upload_service.dart';
import '../../../call/presentation/providers/call_provider.dart';

class ChatRoomScreen extends ConsumerStatefulWidget {
  final String roomId;
  final ChatRoom? chatData; // Passed via go_router extra

  const ChatRoomScreen({super.key, required this.roomId, this.chatData});

  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final SocketService _socketService = SocketService();

  List<ChatMessage> _messages = [];
  bool _isLoading = true;
  String _currentUserId = '';

  // Realtime flags
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    // 1. Get current user ID
    final authState = ref.read(authProvider);
    if (authState is AuthSuccess) {
      _currentUserId = authState.user.id;
    }

    // 2. Fetch history
    try {
      final repo = ref.read(chatRepositoryProvider);
      final messages = widget.chatData?.isGroup == true
          ? await repo.fetchGroupMessages(widget.roomId)
          : await repo.fetchMessages(_currentUserId, widget.roomId);
      if (mounted) {
        setState(() {
          _messages = messages;
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }

    // 3. Connect Sockets!
    await _socketService.connect();
    _socketService.emit('setup', {
      '_id': _currentUserId,
    }); // Emulating React logic setup
    _socketService.emit('join chat', widget.roomId);

    _socketService.on('receive-message', _onMessageReceived);
    _socketService.on('group-message-received', _onMessageReceived);
    _socketService.on(
      'message-sent',
      _onMessageReceived,
    ); // if we want to confirm
    _socketService.on('typing', (_) {
      if (mounted) setState(() => _isTyping = true);
    });
    _socketService.on('stop typing', (_) {
      if (mounted) setState(() => _isTyping = false);
    });
  }

  void _onMessageReceived(dynamic data) {
    if (data == null) return;

    // Parse new message
    final newMessage = ChatMessage.fromJson(data);

    // Make sure it belongs to the current room.
    // In Chatly backend, a message object usually has 'chat' property tying it to the room.
    // For safety, we just append it if we are currently active on this screen.
    if (mounted) {
      setState(() {
        _messages.add(newMessage);
      });
      _scrollToBottom();
    }
  }

  Future<void> _sendMessage({
    String content = '',
    String messageType = 'text',
    String? fileUrl,
    String? fileName,
  }) async {
    if (content.isEmpty && fileUrl == null) return;
    _messageController.clear();

    final Map<String, dynamic> payload = {
      'content': content,
      'messageType': messageType,
      if (fileUrl != null) 'fileUrl': fileUrl,
      if (fileName != null) 'fileName': fileName,
    };

    if (widget.chatData?.isGroup == true) {
      payload['groupId'] = widget.chatData?.id ?? widget.roomId;
      _socketService.emit('group-message', payload);
    } else {
      payload['receiverId'] =
          widget.chatData?.id ??
          widget.roomId; // usually roomId maps to receiverId in private chats
      _socketService.emit('private-message', payload);
    }

    // Optimistic UI for text
    if (messageType == 'text') {
      setState(() {
        _messages.add(
          ChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            senderId: _currentUserId,
            content: content,
            messageType: messageType,
            createdAt: DateTime.now(),
          ),
        );
      });
      _scrollToBottom();
    }
  }

  Future<void> _pickAndUploadMedia(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile == null) return;

    // Show loading
    setState(() => _isLoading = true);

    try {
      final uploadService = ref.read(uploadServiceProvider);
      final result = await uploadService.uploadFile(pickedFile.path);

      await _sendMessage(
        content: '',
        messageType: 'image',
        fileUrl: result.fileUrl,
        fileName: result.filename,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Photo Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadMedia(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadMedia(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 300, // extra padding
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _socketService.emit('leave chat', widget.roomId);
    _socketService.off('message received');
    _socketService.off('typing');
    _socketService.off('stop typing');
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    final isMe = msg.senderId == _currentUserId;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          color: isMe
              ? Theme.of(context).colorScheme.primary
              : Colors.grey[200],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe
                ? const Radius.circular(16)
                : const Radius.circular(0),
            bottomRight: isMe
                ? const Radius.circular(0)
                : const Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (msg.messageType == 'image' && msg.fileUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: msg.fileUrl!,
                  width: 200,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const SizedBox(
                    width: 200,
                    height: 150,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, err) =>
                      const Icon(Icons.broken_image, size: 50),
                ),
              ),
              const SizedBox(height: 6),
            ],
            if (msg.content.isNotEmpty)
              Text(
                msg.content,
                style: TextStyle(
                  color: isMe ? Colors.white : Colors.black87,
                  fontSize: 15,
                ),
              ),
            const SizedBox(height: 4),
            Text(
              DateFormat('HH:mm').format(msg.createdAt),
              style: TextStyle(
                color: isMe ? Colors.white70 : Colors.black54,
                fontSize: 10,
              ),
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
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.grey[300],
              backgroundImage: widget.chatData?.avatar != null
                  ? NetworkImage(widget.chatData!.avatar!)
                  : null,
              child: widget.chatData?.avatar == null
                  ? const Icon(Icons.person, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.chatData?.name ?? 'Chat',
                    style: const TextStyle(fontSize: 16),
                  ),
                  if (_isTyping)
                    const Text(
                      'typing...',
                      style: TextStyle(fontSize: 12, color: Colors.greenAccent),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (widget.chatData?.isGroup ==
              false) // Only show call button for non-group chats
            IconButton(
              icon: const Icon(Icons.call),
              onPressed: () {
                // Assuming widget.chatData contains the correct receiver ID in one of its properties, or we can use the chat name for now.
                ref
                    .read(callProvider.notifier)
                    .startCall(
                      widget.chatData?.id ?? widget.roomId,
                      widget.chatData?.name ?? 'Calling',
                    );
                context.push('/call');
              },
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        return _buildMessageBubble(_messages[index]);
                      },
                    ),
            ),
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.attach_file),
              onPressed: _showAttachmentOptions,
              color: Colors.grey[600],
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (val) {
                  // Emit typing indicator logic
                  if (val.isNotEmpty) {
                    _socketService.emit('typing', widget.roomId);
                  }
                },
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  filled: true,
                  fillColor: Colors.grey[200],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white, size: 20),
                onPressed: () =>
                    _sendMessage(content: _messageController.text.trim()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
