enum UserRole { admin, student, mentor }

class AppUser {
  final String id;
  final String name;
  final String email;
  final String password;
  final UserRole role;
  final String? username;
  final String? adminNo;
  final String? phone;
  final String? batchId;
  final List<String> expertise;
  final List<String> courseIds;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.password,
    required this.role,
    this.username,
    this.adminNo,
    this.phone,
    this.batchId,
    this.expertise = const [],
    this.courseIds = const [],
  });
}
