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

class CourseLesson {
  final String id;
  final String title;
  final String videoDriveLink;
  final String transcript;
  final String duration;
  final int orderIndex;
  final bool isCompleted;

  const CourseLesson({
    required this.id,
    required this.title,
    this.videoDriveLink = '',
    this.transcript = '',
    this.duration = '',
    required this.orderIndex,
    this.isCompleted = false,
  });

  CourseLesson copyWith({
    String? id,
    String? title,
    String? videoDriveLink,
    String? transcript,
    String? duration,
    int? orderIndex,
    bool? isCompleted,
  }) {
    return CourseLesson(
      id: id ?? this.id,
      title: title ?? this.title,
      videoDriveLink: videoDriveLink ?? this.videoDriveLink,
      transcript: transcript ?? this.transcript,
      duration: duration ?? this.duration,
      orderIndex: orderIndex ?? this.orderIndex,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

class CourseModule {
  final String id;
  final String title;
  final String description;
  final int orderIndex;
  final List<CourseLesson> lessons;
  final List<CourseStudyMaterial> studyMaterials;
  final List<CourseQuizQuestion> quizQuestions;
  final int coinReward;

  const CourseModule({
    required this.id,
    required this.title,
    this.description = '',
    required this.orderIndex,
    this.lessons = const [],
    this.studyMaterials = const [],
    this.quizQuestions = const [],
    this.coinReward = 0,
  });

  CourseModule copyWith({
    String? id,
    String? title,
    String? description,
    int? orderIndex,
    List<CourseLesson>? lessons,
    List<CourseStudyMaterial>? studyMaterials,
    List<CourseQuizQuestion>? quizQuestions,
    int? coinReward,
  }) {
    return CourseModule(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      orderIndex: orderIndex ?? this.orderIndex,
      lessons: lessons ?? this.lessons,
      studyMaterials: studyMaterials ?? this.studyMaterials,
      quizQuestions: quizQuestions ?? this.quizQuestions,
      coinReward: coinReward ?? this.coinReward,
    );
  }
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
  final int quizCoinReward;
  final int quizPassScore;
  final String? mentorId;

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
    this.quizCoinReward = 0,
    this.quizPassScore = 0,
    this.mentorId,
  });

  Course copyWith({
    String? id,
    String? title,
    String? description,
    String? instructorName,
    String? thumbnailUrl,
    double? rating,
    CourseDifficulty? difficulty,
    List<CourseModule>? modules,
    String? category,
    String? duration,
    String? moduleType,
    double? price,
    bool? isFeatured,
    bool? isMyCourse,
    String? status,
    bool? createdByAdmin,
    int? quizCoinReward,
    int? quizPassScore,
    String? mentorId,
  }) {
    return Course(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      instructorName: instructorName ?? this.instructorName,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      rating: rating ?? this.rating,
      difficulty: difficulty ?? this.difficulty,
      modules: modules ?? this.modules,
      category: category ?? this.category,
      duration: duration ?? this.duration,
      moduleType: moduleType ?? this.moduleType,
      price: price ?? this.price,
      isFeatured: isFeatured ?? this.isFeatured,
      isMyCourse: isMyCourse ?? this.isMyCourse,
      status: status ?? this.status,
      createdByAdmin: createdByAdmin ?? this.createdByAdmin,
      quizCoinReward: quizCoinReward ?? this.quizCoinReward,
      quizPassScore: quizPassScore ?? this.quizPassScore,
      mentorId: mentorId ?? this.mentorId,
    );
  }
}
