class AuthUser {
  final String id;
  final String name; // mapped from displayName or username
  final String email;
  final String? avatar; // mapped from profilePicture
  final String? bio;
  final String? status;
  final String? token;

  AuthUser({
    required this.id,
    required this.name,
    required this.email,
    this.avatar,
    this.bio,
    this.status,
    this.token,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['displayName'] ?? json['username'] ?? json['name'] ?? '',
      email: json['email'] ?? '',
      avatar: json['profilePicture'] ?? json['avatarUrl'] ?? json['avatar'],
      bio: json['bio'] ?? '',
      status: json['status'] ?? '',
      token: json['token'], 
    );
  }

  AuthUser copyWith({
    String? name,
    String? email,
    String? avatar,
    String? bio,
    String? status,
    String? token,
  }) {
    return AuthUser(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      avatar: avatar ?? this.avatar,
      bio: bio ?? this.bio,
      status: status ?? this.status,
      token: token ?? this.token,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'displayName': name,
      'email': email,
      'profilePicture': avatar,
      'bio': bio,
      'status': status,
      'token': token,
    };
  }
}
