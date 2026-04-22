class TaskSubmission {
  const TaskSubmission({
    required this.id,
    required this.taskId,
    required this.studentId,
    this.studentName,
    this.studentEmail,
    this.fileUrl,
    this.fileType,
    this.driveLink,
    required this.submittedAt,
    required this.status,
    this.feedback,
    this.isLate = false,
    this.studentDone = false,
    this.doneAt,
  });

  final String id;
  final String taskId;
  final String studentId;
  final String? studentName;
  final String? studentEmail;
  final String? fileUrl;
  final String? fileType;
  final String? driveLink;
  final DateTime submittedAt;
  final String status;
  final String? feedback;
  final bool isLate;
  final bool studentDone;
  final DateTime? doneAt;

  factory TaskSubmission.fromJson(Map<String, dynamic> json) {
    final submittedAt = DateTime.tryParse((json['submitted_at'] ?? '').toString()) ?? DateTime.now();
    return TaskSubmission(
      id: (json['id'] ?? '').toString(),
      taskId: (json['task_id'] ?? json['taskId'] ?? '').toString(),
      studentId: (json['student_id'] ?? json['studentId'] ?? '').toString(),
      studentName: json['student_name']?.toString(),
      studentEmail: json['student_email']?.toString(),
      fileUrl: json['file_url']?.toString() ?? json['fileUrl']?.toString(),
      fileType: json['file_type']?.toString() ?? json['fileType']?.toString(),
      driveLink: json['drive_link']?.toString() ?? json['driveLink']?.toString(),
      submittedAt: submittedAt,
      status: (json['status'] ?? 'pending').toString(),
      feedback: json['feedback']?.toString(),
      isLate: (json['is_late'] as bool?) ?? false,
      studentDone: (json['student_done'] as bool?) ?? false,
      doneAt: DateTime.tryParse((json['done_at'] ?? '').toString()),
    );
  }
}
