import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';
import '../domain/chat_room_model.dart';
import '../domain/message_model.dart';
import '../../auth/data/auth_model.dart';

class ChatRepository {
  final DioClient _dioClient;

  ChatRepository(this._dioClient);

  /// Builds the chat inbox by:
  /// 1. Fetching all users the current user has chatted with (via last-messages)
  /// 2. Fetching all groups the user is in
  Future<List<ChatRoom>> fetchChats(AuthUser currentUser) async {
    try {
      final List<ChatRoom> rooms = [];

      // --- Private chats: get last messages to know who we've talked to ---
      final lastMsgResponse = await _dioClient.dio
          .get('/messages/last-messages/${currentUser.id}');

      if (lastMsgResponse.data is Map) {
        final Map<String, dynamic> lastMessages =
            Map<String, dynamic>.from(lastMsgResponse.data);

        // For each conversation partner, get their user info
        for (final partnerId in lastMessages.keys) {
          try {
            final userRes =
                await _dioClient.dio.get('/users/$partnerId');
            final userData = userRes.data;

            final lastMsg = lastMessages[partnerId];
            rooms.add(ChatRoom(
              id: partnerId,
              name: userData['displayName'] ?? userData['username'] ?? 'User',
              avatar: userData['profilePicture'],
              isGroup: false,
              lastMessage: _formatLastMessage(lastMsg),
              lastMessageTime: lastMsg['createdAt'] != null
                  ? DateTime.tryParse(lastMsg['createdAt'])
                  : null,
              unreadCount: (lastMsg['isRead'] == false &&
                      lastMsg['senderId'] != currentUser.id)
                  ? 1
                  : 0,
            ));
          } catch (_) {
            // Skip if user not found
          }
        }
      }

      // --- Group chats ---
      try {
        final groupRes = await _dioClient.dio
            .get('/groups/user/${currentUser.id}');

        if (groupRes.data is List) {
          for (final g in groupRes.data as List) {
            rooms.add(ChatRoom(
              id: g['_id'] ?? '',
              name: g['name'] ?? 'Group',
              avatar: g['avatar'],
              isGroup: true,
              lastMessage: g['lastMessage']?['content'],
              lastMessageTime: g['updatedAt'] != null
                  ? DateTime.tryParse(g['updatedAt'])
                  : null,
              unreadCount: 0,
            ));
          }
        }
      } catch (_) {
        // Groups fetch failed — continue with private chats only
      }

      // Sort by last message time, newest first
      rooms.sort((a, b) {
        if (a.lastMessageTime == null) return 1;
        if (b.lastMessageTime == null) return -1;
        return b.lastMessageTime!.compareTo(a.lastMessageTime!);
      });

      return rooms;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Fetch messages between current user and a recipient (private chat)
  Future<List<ChatMessage>> fetchMessages(
      String currentUserId, String recipientId) async {
    try {
      final response = await _dioClient.dio
          .get('/messages/$currentUserId/$recipientId');

      if (response.data is List) {
        return (response.data as List)
            .map((json) => ChatMessage.fromJson(json))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Fetch messages for a group chat
  Future<List<ChatMessage>> fetchGroupMessages(String groupId) async {
    try {
      final response =
          await _dioClient.dio.get('/groups/$groupId/messages');

      if (response.data is List) {
        return (response.data as List)
            .map((json) => ChatMessage.fromJson(json))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  String _formatLastMessage(Map<String, dynamic> msg) {
    final type = msg['messageType'] ?? 'text';
    if (type == 'image') return '📷 Photo';
    if (type == 'file') return '📎 ${msg['fileName'] ?? 'File'}';
    return msg['content'] ?? '';
  }

  String _handleError(DioException e) {
    if (e.response != null && e.response?.data != null) {
      final data = e.response?.data;
      if (data is Map && data.containsKey('message')) {
        return data['message'];
      }
    }
    return 'Failed to load chats. Please pull to refresh to try again.';
  }
}
