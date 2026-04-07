// lib/features/chat/domain/message_model.dart

class ChatMessage {
  final String id;
  final String senderId;
  final String content;
  final String? fileUrl;
  final String? fileName;
  final String messageType; // 'text', 'image', 'file', etc.
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.content,
    this.fileUrl,
    this.fileName,
    this.messageType = 'text',
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['_id'] ?? json['id'] ?? '',
      senderId: (json['senderId'] is Map) 
          ? json['senderId']['_id'] 
          : (json['senderId'] ?? json['sender'] ?? ''),
      content: json['content'] ?? '',
      fileUrl: json['fileUrl'] ?? json['mediaUrl'],
      fileName: json['fileName'],
      messageType: json['messageType'] ?? json['mediaType'] ?? 'text',
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
    );
  }
}
