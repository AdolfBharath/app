enum ProjectStatus { pending, reviewed, inReview, rejected }

class Project {
  final String id;
  final String title;
  final String description;
  final String studentId;
  final String studentName;
  final String batchId;
  final String batchName;
  final DateTime submissionDate;
  final ProjectStatus status;
  final List<String> fileUrls;
  final String? reviewNotes;
  final String? reviewedBy;
  final DateTime? reviewedDate;

  const Project({
    required this.id,
    required this.title,
    required this.description,
    required this.studentId,
    required this.studentName,
    required this.batchId,
    required this.batchName,
    required this.submissionDate,
    required this.status,
    this.fileUrls = const [],
    this.reviewNotes,
    this.reviewedBy,
    this.reviewedDate,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    ProjectStatus parseStatus(String? statusStr) {
      switch (statusStr?.toLowerCase()) {
        case 'reviewed':
          return ProjectStatus.reviewed;
        case 'in_review':
        case 'inreview':
          return ProjectStatus.inReview;
        case 'rejected':
          return ProjectStatus.rejected;
        case 'pending':
        default:
          return ProjectStatus.pending;
      }
    }

    DateTime parseDate(dynamic date) {
      if (date is String && date.isNotEmpty) {
        return DateTime.tryParse(date) ?? DateTime.now();
      }
      return DateTime.now();
    }

    return Project(
      id: json['id'].toString(),
      title: json['title'] as String? ?? 'Untitled Project',
      description: json['description'] as String? ?? '',
      studentId: json['student_id']?.toString() ?? '',
      studentName: json['student_name'] as String? ?? 'Unknown Student',
      batchId: json['batch_id']?.toString() ?? '',
      batchName: json['batch_name'] as String? ?? 'Unknown Batch',
      submissionDate: parseDate(json['submission_date']),
      status: parseStatus(json['status'] as String?),
      fileUrls:
          (json['file_urls'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      reviewNotes: json['review_notes'] as String?,
      reviewedBy: json['reviewed_by'] as String?,
      reviewedDate: json['reviewed_date'] != null
          ? parseDate(json['reviewed_date'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'student_id': studentId,
      'student_name': studentName,
      'batch_id': batchId,
      'batch_name': batchName,
      'submission_date': submissionDate.toIso8601String(),
      'status': status.name,
      'file_urls': fileUrls,
      'review_notes': reviewNotes,
      'reviewed_by': reviewedBy,
      'reviewed_date': reviewedDate?.toIso8601String(),
    };
  }

  Project copyWith({
    String? id,
    String? title,
    String? description,
    String? studentId,
    String? studentName,
    String? batchId,
    String? batchName,
    DateTime? submissionDate,
    ProjectStatus? status,
    List<String>? fileUrls,
    String? reviewNotes,
    String? reviewedBy,
    DateTime? reviewedDate,
  }) {
    return Project(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      batchId: batchId ?? this.batchId,
      batchName: batchName ?? this.batchName,
      submissionDate: submissionDate ?? this.submissionDate,
      status: status ?? this.status,
      fileUrls: fileUrls ?? this.fileUrls,
      reviewNotes: reviewNotes ?? this.reviewNotes,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedDate: reviewedDate ?? this.reviewedDate,
    );
  }
}
