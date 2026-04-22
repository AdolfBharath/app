enum CourseDifficulty { beginner, intermediate, advanced }

class CourseStudyMaterial {
  final String title;
  final String description;
  final String driveLink;
  final String fileName;
  final String fileType;

  const CourseStudyMaterial({
    required this.title,
    this.description = '',
    this.driveLink = '',
    this.fileName = '',
    this.fileType = '',
  });
}

class CourseQuizQuestion {
  final String question;
  final String optionA;
  final String optionB;
  final String optionC;
  final String optionD;
  final String correctAnswer;

  const CourseQuizQuestion({
    required this.question,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.optionD,
    required this.correctAnswer,
  });
}

class CourseModule {
  final String id;
  final String? courseId;
  final int moduleNumber;
  final String title;
  final String moduleDescription;
  final String lessonTitle;
  final String videoDriveLink;
  final String transcript;
  final String duration;
  final String description;
  final int order;
  final List<CourseStudyMaterial> studyMaterials;
  final List<CourseQuizQuestion> quizQuestions;

  const CourseModule({
    required this.id,
    this.courseId,
    this.moduleNumber = 1,
    required this.title,
    this.moduleDescription = '',
    this.lessonTitle = '',
    this.videoDriveLink = '',
    this.transcript = '',
    this.duration = '',
    required this.description,
    required this.order,
    this.studyMaterials = const [],
    this.quizQuestions = const [],
  });
}

class Course {
  final String id;
  final String title;
  final String description;
  final String category;
  final String duration;
  final String moduleType;
  final String instructorName;
  final String thumbnailUrl;
  final double rating;
  final double price;
  final CourseDifficulty difficulty;
  final List<CourseModule> modules;
  final bool isFeatured;
  final bool isMyCourse;
  final String status;
  final bool createdByAdmin;

  const Course({
    required this.id,
    required this.title,
    required this.description,
    required this.instructorName,
    required this.thumbnailUrl,
    required this.rating,
    required this.difficulty,
    required this.modules,
    this.category = '',
    this.duration = '',
    this.moduleType = 'Self-paced',
    this.price = 0.0,
    this.isFeatured = false,
    this.isMyCourse = false,
    this.status = 'Published',
    this.createdByAdmin = false,
  });
}
