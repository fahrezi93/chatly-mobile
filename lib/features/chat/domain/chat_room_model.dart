class ChatRoom {
  final String id;
  final String name; // Computed from participants or group name
  final String? avatar;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int unreadCount;
  final bool isGroup;

  ChatRoom({
    required this.id,
    required this.name,
    this.avatar,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCount = 0,
    this.isGroup = false,
  });

  factory ChatRoom.fromJson(Map<String, dynamic> json, String currentUserId) {
    // Determine the name based on whether it's a group or direct message
    bool isGroupChat = json['isGroupChat'] ?? false;
    String roomName = "Unknown";
    String? avatarUrl;

    if (isGroupChat) {
      roomName = json['chatName'] ?? "Group";
      avatarUrl = json['groupAdmin']?['avatar']; // Simplification
    } else {
      // Find the other user
      if (json['users'] != null) {
        List users = json['users'];
        final otherUser = users.firstWhere(
          (u) => (u['_id'] ?? u['id']) != currentUserId,
          orElse: () => null,
        );
        if (otherUser != null) {
          roomName = otherUser['name'] ?? "User";
          avatarUrl = otherUser['avatar'];
        }
      }
    }

    final latestMsg = json['latestMessage'];

    return ChatRoom(
      id: json['_id'] ?? '',
      name: roomName,
      avatar: avatarUrl,
      isGroup: isGroupChat,
      lastMessage: latestMsg?['content'],
      lastMessageTime: latestMsg?['createdAt'] != null 
          ? DateTime.parse(latestMsg['createdAt']) 
          : null,
      unreadCount: 0, // Compute based on read receipts if available
    );
  }
}
