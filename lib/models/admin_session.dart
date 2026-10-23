class Admin {
  const Admin({required this.id, required this.email, this.name = ''});

  final int id;
  final String email;
  final String name;

  // The name if there is one, otherwise the email.
  String get displayName => name.trim().isEmpty ? email : name;

  factory Admin.fromJson(Map<String, dynamic> json) => Admin(
        id: (json['id'] as num).toInt(),
        email: json['email'] as String,
        name: json['name'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {'id': id, 'email': email, 'name': name};
}

// What POST /api/auth/login returns: the token to send as "Authorization: Bearer <token>",
// when it stops working, and who signed in.
class AdminSession {
  const AdminSession({
    required this.token,
    required this.expiresAt,
    required this.admin,
  });

  final String token;
  final DateTime expiresAt;
  final Admin admin;

  bool isExpiredAt(DateTime now) => !now.isBefore(expiresAt);

  factory AdminSession.fromJson(Map<String, dynamic> json) => AdminSession(
        token: json['token'] as String,
        expiresAt: DateTime.parse(json['expires_at'] as String),
        admin: Admin.fromJson(json['admin'] as Map<String, dynamic>),
      );

  // Same keys as the API, so a saved session is read back with fromJson.
  Map<String, dynamic> toJson() => {
        'token': token,
        'expires_at': expiresAt.toUtc().toIso8601String(),
        'admin': admin.toJson(),
      };
}
