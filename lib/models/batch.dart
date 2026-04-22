class Batch {
  final String id;
  final String name;
  final String courseId;
  final String? mentorId;
  final int? capacity;
  final int? enrollLimit;
  final bool smartWaitlist;
  final String status;
  final DateTime? startDate;
  final double progress;
  final int enrolledCount; // Number of students currently enrolled

  const Batch({
    required this.id,
    required this.name,
    required this.courseId,
    this.mentorId,
    this.capacity,
    this.enrollLimit,
    this.smartWaitlist = false,
    this.status = 'draft',
    this.startDate,
    this.progress = 0.0,
    this.enrolledCount = 0,
  });

  factory Batch.fromJson(Map<String, dynamic> json) {
    DateTime? parsedStartDate;
    final rawStart = json['start_date'];
    if (rawStart is String && rawStart.isNotEmpty) {
      parsedStartDate = DateTime.tryParse(rawStart);
    }

    return Batch(
      id: json['id'].toString(),
      name: json['name'] as String,
      courseId: json['course_id'].toString(),
      mentorId: json['mentor_id']?.toString(),
      capacity: json['capacity'] as int?,
      enrollLimit: json['enroll_limit'] as int?,
      smartWaitlist: (json['smart_waitlist'] as bool?) ?? false,
      status: (json['status'] as String?) ?? 'draft',
      startDate: parsedStartDate,
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      enrolledCount:
          (json['enrolled_count'] as int?) ??
          (json['enrolledCount'] as int?) ??
          (json['student_count'] as int?) ??
          0,
    );
  }
}
