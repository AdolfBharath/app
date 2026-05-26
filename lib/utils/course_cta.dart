enum CourseCtaState {
  login,
  studentsOnly,
  enroll,
  buy,
  start,
  continueLearning,
  review,
}

class CourseCta {
  const CourseCta(
    this.state,
    this.label, {
    this.isEnabled = true,
  });

  final CourseCtaState state;
  final String label;
  final bool isEnabled;
}

CourseCta resolveCourseCta({
  required bool isLoggedIn,
  required bool isStudent,
  required bool isEnrolled,
  required double price,
  required double progress,
}) {
  if (!isLoggedIn) {
    return const CourseCta(CourseCtaState.buy, 'Buy Now');
  }
  if (!isStudent) {
    return const CourseCta(
      CourseCtaState.studentsOnly,
      'Students Only',
      isEnabled: false,
    );
  }
  if (!isEnrolled) {
    return const CourseCta(CourseCtaState.buy, 'Buy Now');
  }
  if (progress >= 0.999) {
    return const CourseCta(CourseCtaState.review, 'Review Course');
  }
  if (progress > 0.01) {
    return const CourseCta(CourseCtaState.continueLearning, 'Continue Learning');
  }
  return const CourseCta(CourseCtaState.start, 'Start Learning');
}
