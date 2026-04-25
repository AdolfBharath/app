enum QuestionStatus { pending, replied }

class Question {
  final String id;
  final String studentId;
  final String? studentName;
  final String mentorId;
  final String courseId;
  final String? courseTitle;
  final String moduleId;
  final String? moduleTitle;
  final String lessonId;
  final String? lessonTitle;
  final String title;
  final String description;
  final String? attachmentUrl;
  final QuestionStatus status;
  final String? reply;
  final DateTime createdAt;

  Question({
    required this.id,
    required this.studentId,
    this.studentName,
    required this.mentorId,
    required this.courseId,
    this.courseTitle,
    required this.moduleId,
    this.moduleTitle,
    required this.lessonId,
    this.lessonTitle,
    required this.title,
    required this.description,
    this.attachmentUrl,
    this.status = QuestionStatus.pending,
    this.reply,
    required this.createdAt,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id']?.toString() ?? '',
      studentId: json['student_id']?.toString() ?? '',
      studentName: json['student_name']?.toString(),
      mentorId: json['mentor_id']?.toString() ?? '',
      courseId: json['course_id']?.toString() ?? '',
      courseTitle: json['course_title']?.toString(),
      moduleId: json['module_id']?.toString() ?? '',
      moduleTitle: json['module_title']?.toString(),
      lessonId: json['lesson_id']?.toString() ?? '',
      lessonTitle: json['lesson_title']?.toString(),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      attachmentUrl: json['attachment_url']?.toString(),
      status: (json['status']?.toString().toLowerCase() == 'replied')
          ? QuestionStatus.replied
          : QuestionStatus.pending,
      reply: json['reply']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'student_id': studentId,
      'mentor_id': mentorId,
      'course_id': courseId,
      'module_id': moduleId,
      'lesson_id': lessonId,
      'title': title,
      'description': description,
      'attachment_url': attachmentUrl,
      'status': status.name,
      'reply': reply,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
