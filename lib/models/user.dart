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
  final int streakCount;
  final DateTime? lastActiveDate;
  final int coins;
  final List<bool> weeklyLogins;

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
    this.streakCount = 0,
    this.lastActiveDate,
    this.coins = 0,
    this.weeklyLogins = const [false, false, false, false, false, false, false],
  });
}
