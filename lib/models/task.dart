class BatchTask {
  const BatchTask({
    required this.id,
    required this.batchId,
    required this.title,
    required this.description,
    this.fileUrl,
    this.driveLink,
    this.deadline,
    required this.createdBy,
    required this.createdAt,
    this.submissionCount = 0,
    this.attemptCount = 0,
    this.mySubmissionStatus,
    this.mySubmissionFeedback,
    this.mySubmissionIsLate,
    this.mySubmissionFileUrl,
    this.mySubmissionDriveLink,
    this.mySubmissionSubmittedAt,
    this.mySubmissionStudentDone,
    this.mySubmissionDoneAt,
  });

  final String id;
  final String batchId;
  final String title;
  final String description;
  final String? fileUrl;
  final String? driveLink;
  final DateTime? deadline;
  final String createdBy;
  final DateTime createdAt;

  final int submissionCount;
  final int attemptCount;
  final String? mySubmissionStatus;
  final String? mySubmissionFeedback;
  final bool? mySubmissionIsLate;
  final String? mySubmissionFileUrl;
  final String? mySubmissionDriveLink;
  final DateTime? mySubmissionSubmittedAt;
  final bool? mySubmissionStudentDone;
  final DateTime? mySubmissionDoneAt;

  bool get isOverdue {
    if (deadline == null) return false;
    return DateTime.now().isAfter(deadline!);
  }

  factory BatchTask.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      final s = v.toString().trim();
      if (s.isEmpty) return null;
      return DateTime.tryParse(s);
    }

    return BatchTask(
      id: (json['id'] ?? '').toString(),
      batchId: (json['batch_id'] ?? json['batchId'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      fileUrl: json['file_url']?.toString() ?? json['fileUrl']?.toString(),
      driveLink: json['drive_link']?.toString() ?? json['driveLink']?.toString(),
      deadline: parseDate(json['deadline']),
      createdBy: (json['created_by'] ?? json['createdBy'] ?? '').toString(),
      createdAt: parseDate(json['created_at']) ?? DateTime.now(),
      submissionCount: (json['submission_count'] as int?) ??
          (json['submissionCount'] as int?) ??
          0,
      attemptCount: (json['attempt_count'] as int?) ??
          (json['attemptCount'] as int?) ??
          0,
      mySubmissionStatus: json['my_submission_status']?.toString(),
      mySubmissionFeedback: json['my_submission_feedback']?.toString(),
      mySubmissionIsLate: json['my_submission_is_late'] as bool?,
      mySubmissionFileUrl: json['my_submission_file_url']?.toString(),
      mySubmissionDriveLink: json['my_submission_drive_link']?.toString(),
      mySubmissionSubmittedAt: parseDate(json['my_submission_submitted_at']),
      mySubmissionStudentDone: json['my_submission_student_done'] as bool?,
      mySubmissionDoneAt: parseDate(json['my_submission_done_at']),
    );
  }
}
