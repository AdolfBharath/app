import 'batch.dart';
import 'user.dart';

class StudentPerformance {
  final AppUser student;
  final double progress;
  final double score;
  final int rank;
  final int completedAssignments;
  final int totalAssignments;

  const StudentPerformance({
    required this.student,
    required this.progress,
    required this.score,
    required this.rank,
    required this.completedAssignments,
    required this.totalAssignments,
  });

  factory StudentPerformance.fromJson(Map<String, dynamic> json) {
    return StudentPerformance(
      student: AppUser(
        id: json['student_id']?.toString() ?? '',
        name: json['student_name'] as String? ?? 'Unknown',
        email: json['student_email'] as String? ?? '',
        password: '',
        role: UserRole.student,
        username: json['student_username'] as String?,
        batchId: json['batch_id']?.toString(),
      ),
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      rank: json['rank'] as int? ?? 0,
      completedAssignments: json['completed_assignments'] as int? ?? 0,
      totalAssignments: json['total_assignments'] as int? ?? 0,
    );
  }
}

class BatchDetail {
  final Batch batch;
  final String? courseName;
  final AppUser? mentor;
  final List<AppUser> students;
  final List<StudentPerformance> topPerformers;
  final int totalStudents;
  final double averageProgress;

  const BatchDetail({
    required this.batch,
    this.courseName,
    this.mentor,
    this.students = const [],
    this.topPerformers = const [],
    this.totalStudents = 0,
    this.averageProgress = 0.0,
  });

  factory BatchDetail.fromJson(Map<String, dynamic> json) {
    // Parse batch
    final batch = Batch.fromJson(json['batch'] ?? json);

    // Parse course name
    final courseName = json['course_name'] as String?;

    // Parse mentor
    AppUser? mentor;
    if (json['mentor'] != null) {
      final mentorData = json['mentor'] as Map<String, dynamic>;
      mentor = AppUser(
        id: mentorData['id']?.toString() ?? '',
        name: mentorData['name'] as String? ?? 'Unknown Mentor',
        email: mentorData['email'] as String? ?? '',
        password: '',
        role: UserRole.mentor,
        username: mentorData['username'] as String?,
      );
    }

    // Parse students
    final studentsList = <AppUser>[];
    if (json['students'] != null && json['students'] is List) {
      for (final studentData in json['students']) {
        if (studentData is Map<String, dynamic>) {
          studentsList.add(
            AppUser(
              id: studentData['id']?.toString() ?? '',
              name: studentData['name'] as String? ?? 'Unknown',
              email: studentData['email'] as String? ?? '',
              password: '',
              role: UserRole.student,
              username: studentData['username'] as String?,
              batchId: batch.id,
            ),
          );
        }
      }
    }

    // Parse top performers
    final performersList = <StudentPerformance>[];
    if (json['top_performers'] != null && json['top_performers'] is List) {
      for (final performerData in json['top_performers']) {
        if (performerData is Map<String, dynamic>) {
          performersList.add(StudentPerformance.fromJson(performerData));
        }
      }
    }

    return BatchDetail(
      batch: batch,
      courseName: courseName,
      mentor: mentor,
      students: studentsList,
      topPerformers: performersList,
      totalStudents: json['total_students'] as int? ?? studentsList.length,
      averageProgress: (json['average_progress'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
