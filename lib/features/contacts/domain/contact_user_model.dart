class ContactUser {
  final String id;
  final String username;
  final String displayName;
  final String? profilePicture;
  final bool isOnline;

  ContactUser({
    required this.id,
    required this.username,
    required this.displayName,
    this.profilePicture,
    this.isOnline = false,
  });

  factory ContactUser.fromJson(Map<String, dynamic> json) {
    return ContactUser(
      id: json['_id'] ?? json['id'] ?? '',
      username: json['username'] ?? '',
      displayName: json['displayName'] ?? json['username'] ?? '',
      profilePicture: json['profilePicture'] ?? json['avatar'],
      isOnline: json['isOnline'] ?? false,
    );
  }
}
