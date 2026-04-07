class ContactModel {
  final String id;
  final String username;
  final String? displayName;
  final String? profilePicture;
  final bool isOnline;
  final bool isVerified;
  final String? status;
  final DateTime? lastSeen;

  ContactModel({
    required this.id,
    required this.username,
    this.displayName,
    this.profilePicture,
    this.isOnline = false,
    this.isVerified = false,
    this.status,
    this.lastSeen,
  });

  factory ContactModel.fromJson(Map<String, dynamic> json) {
    return ContactModel(
      id: json['_id'] ?? json['id'] ?? '',
      username: json['username'] ?? '',
      displayName: json['displayName'],
      profilePicture: json['profilePicture'] ?? json['avatarUrl'], // Node backend might send either
      isOnline: json['isOnline'] ?? false,
      isVerified: json['isVerified'] ?? false,
      status: json['status'],
      lastSeen: json['lastSeen'] != null ? DateTime.tryParse(json['lastSeen']) : null,
    );
  }
}
