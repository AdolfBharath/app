/// api_service.dart
///
/// Backward-compatible facade that preserves the `ApiService.instance.X()`
/// call pattern used throughout the app while delegating all work to the
/// focused domain services introduced in the service split.
///
/// Re-export the shared exception types so existing `import 'api_service.dart'`
/// imports continue to resolve [ApiException], [UnauthorizedApiException], and
/// [DuplicateEmailException] without any screen-level changes.
library api_service;

export 'api_base.dart'
    show ApiException, UnauthorizedApiException, DuplicateEmailException;

import '../models/batch.dart';
import '../models/batch_detail.dart';
import '../models/course.dart';
import '../models/project.dart';
import '../models/task.dart';
import '../models/task_submission.dart';
import '../models/user.dart';
import 'dart:typed_data';

import 'auth_service.dart';
import 'batch_service.dart';
import 'course_service.dart';
import 'notification_service.dart';
import 'project_service.dart';
import 'support_service.dart';
import 'task_service.dart';
import 'user_service.dart';

/// Singleton facade that delegates to domain-specific services.
///
/// All existing call sites such as `ApiService.instance.getCourses()` continue
/// to work without modification — each method is a one-liner that forwards to
/// the correct service singleton.
class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  // ---------------------------------------------------------------------------
  // Auth
  // ---------------------------------------------------------------------------

  Future<bool> changeAdminPassword({
    required String currentPassword,
    required String newPassword,
  }) =>
      AuthService.instance.changeAdminPassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

  // ---------------------------------------------------------------------------
  // Courses
  // ---------------------------------------------------------------------------

  Future<List<Course>> getCourses() => CourseService.instance.getCourses();

  Future<List<Course>> getMentorCourses() =>
      CourseService.instance.getMentorCourses();

  Future<List<Course>> getCoursesWithStatus() =>
      CourseService.instance.getCoursesWithStatus();

  Future<bool> createCourse(
    String title,
    String description, {
    String? category,
    String? duration,
    String? thumbnailUrl,
    String? mentorId,
    double price = 0.0,
    bool isFeatured = false,
    bool isMyCourse = false,
  }) =>
      CourseService.instance.createCourse(
        title,
        description,
        category: category,
        duration: duration,
        thumbnailUrl: thumbnailUrl,
        mentorId: mentorId,
        price: price,
        isFeatured: isFeatured,
        isMyCourse: isMyCourse,
      );

  Future<bool> updateCourseFlags(
    String id, {
    bool? isFeatured,
    bool? isMyCourse,
  }) =>
      CourseService.instance.updateCourseFlags(
        id,
        isFeatured: isFeatured,
        isMyCourse: isMyCourse,
      );

  Future<bool> updateCourseDetails(
    String id, {
    required String title,
    required String description,
    required String category,
    required String duration,
    String moduleType = 'Self-paced',
    required String instructorName,
    required String thumbnailUrl,
    required String difficulty,
    required double rating,
    List<Map<String, dynamic>> modules = const [],
    double price = 0.0,
    String? mentorId,
  }) =>
      CourseService.instance.updateCourseDetails(
        id,
        title: title,
        description: description,
        category: category,
        duration: duration,
        moduleType: moduleType,
        instructorName: instructorName,
        thumbnailUrl: thumbnailUrl,
        difficulty: difficulty,
        rating: rating,
        modules: modules,
        price: price,
        mentorId: mentorId,
      );

  Future<bool> deleteCourse(String id) => CourseService.instance.deleteCourse(id);

  Future<void> enrollInCourse(String courseId) =>
      CourseService.instance.enrollInCourse(courseId);

  // ---------------------------------------------------------------------------
  // Batches
  // ---------------------------------------------------------------------------

  Future<List<Batch>> getBatches() => BatchService.instance.getBatches();

  Future<List<Batch>> getMentorBatches() =>
      BatchService.instance.getMentorBatches();

  Future<BatchDetail> getBatchDetails(String batchId) =>
      BatchService.instance.getBatchDetails(batchId);

  Future<List<AppUser>> getTopPerformers(
    String batchId, {
    int limit = 10,
  }) =>
      BatchService.instance.getTopPerformers(batchId, limit: limit);

  Future<bool> createBatch({
    required String name,
    required String courseId,
    String? mentorId,
    int? capacity,
    int? enrollLimit,
    bool smartWaitlist = false,
    DateTime? startDate,
  }) =>
      BatchService.instance.createBatch(
        name: name,
        courseId: courseId,
        mentorId: mentorId,
        capacity: capacity,
        enrollLimit: enrollLimit,
        smartWaitlist: smartWaitlist,
        startDate: startDate,
      );

  Future<bool> updateBatch({
    required String batchId,
    String? name,
    String? courseId,
    String? mentorId,
    int? capacity,
    int? enrollLimit,
    bool? smartWaitlist,
    DateTime? startDate,
    DateTime? endDate,
  }) =>
      BatchService.instance.updateBatch(
        batchId: batchId,
        name: name,
        courseId: courseId,
        mentorId: mentorId,
        capacity: capacity,
        enrollLimit: enrollLimit,
        smartWaitlist: smartWaitlist,
        startDate: startDate,
        endDate: endDate,
      );

  Future<bool> deleteBatch(String id) => BatchService.instance.deleteBatch(id);

  // ---------------------------------------------------------------------------
  // Users
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getUsers({String? role}) =>
      UserService.instance.getUsers(role: role);

    Future<List<Map<String, dynamic>>> getStudentsForCourse(String courseId) =>
      UserService.instance.getStudentsForCourse(courseId);

  Future<bool> createUser({
    required String name,
    required String email,
    required String password,
    required String role,
    String? phone,
  }) =>
      UserService.instance.createUser(
        name: name,
        email: email,
        password: password,
        role: role,
        phone: phone,
      );

  Future<bool> updateUser(
    String userId, {
    String? name,
    String? email,
    String? username,
    String? role,
    List<String>? expertise,
    String? batchId,
    bool includeBatchId = false,
    List<String>? courseIds,
    bool includeCourseIds = false,
  }) =>
      UserService.instance.updateUser(
        userId,
        name: name,
        email: email,
        username: username,
        role: role,
        expertise: expertise,
        batchId: batchId,
        includeBatchId: includeBatchId,
        courseIds: courseIds,
        includeCourseIds: includeCourseIds,
      );

  Future<bool> deleteUser(String userId) =>
      UserService.instance.deleteUser(userId);

  Future<bool> assignCourseToUser(String userId, String courseId) =>
      UserService.instance.assignCourseToUser(userId, courseId);

  // ---------------------------------------------------------------------------
  // Projects
  // ---------------------------------------------------------------------------

  Future<List<Project>> getProjects() => ProjectService.instance.getProjects();

  Future<List<Map<String, dynamic>>> getMentorProjects() =>
      ProjectService.instance.getMentorProjects();

  Future<Project> getProjectDetails(String projectId) =>
      ProjectService.instance.getProjectDetails(projectId);

  Future<bool> updateProjectStatus(
    String projectId, {
    required String status,
    String? reviewNotes,
  }) =>
      ProjectService.instance.updateProjectStatus(
        projectId,
        status: status,
        reviewNotes: reviewNotes,
      );

  // ---------------------------------------------------------------------------
  // Notifications
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getMentorNotifications() =>
      NotificationService.instance.getMentorNotifications();

  Future<List<Map<String, dynamic>>> getAdminInboxNotifications() =>
      NotificationService.instance.getAdminInboxNotifications();

  Future<bool> sendAnnouncement({
    required String title,
    required String message,
    required String targetGroup,
  }) =>
      NotificationService.instance.sendAnnouncement(
        title: title,
        message: message,
        targetGroup: targetGroup,
      );

  Future<bool> sendBatchAnnouncement({
    required String batchId,
    required String title,
    required String message,
  }) =>
      NotificationService.instance.sendBatchAnnouncement(
        batchId: batchId,
        title: title,
        message: message,
      );

  // ---------------------------------------------------------------------------
  // Support
  // ---------------------------------------------------------------------------

  Future<void> sendSupportMessage({required String message}) =>
      SupportService.instance.sendSupportMessage(message: message);

  // ---------------------------------------------------------------------------
  // Tasks / Submissions
  // ---------------------------------------------------------------------------

  Future<List<BatchTask>> getBatchTasks(String batchId) =>
      TaskService.instance.getBatchTasks(batchId);

  Future<BatchTask> createTask({
    required String batchId,
    required String title,
    required String description,
    String? fileUrl,
    String? driveLink,
    DateTime? deadline,
  }) =>
      TaskService.instance.createTask(
        batchId: batchId,
        title: title,
        description: description,
        fileUrl: fileUrl,
        driveLink: driveLink,
        deadline: deadline,
      );

  Future<BatchTask> updateTask({
    required String taskId,
    required String batchId,
    required String title,
    required String description,
    String? fileUrl,
    String? driveLink,
    DateTime? deadline,
  }) =>
      TaskService.instance.updateTask(
        taskId: taskId,
        batchId: batchId,
        title: title,
        description: description,
        fileUrl: fileUrl,
        driveLink: driveLink,
        deadline: deadline,
      );

  Future<TaskSubmission> submitTask({
    required String taskId,
    String? fileUrl,
    String? fileType,
    String? driveLink,
    bool? markDone,
  }) =>
      TaskService.instance.submitTask(
        taskId: taskId,
        fileUrl: fileUrl,
        fileType: fileType,
        driveLink: driveLink,
        markDone: markDone,
      );

  Future<Map<String, dynamic>> uploadSubmissionToDrive({
    required String taskId,
    required String fileName,
    Uint8List? fileBytes,
    String? filePath,
    String? mimeType,
  }) =>
      TaskService.instance.uploadSubmissionToDrive(
        taskId: taskId,
        fileName: fileName,
        fileBytes: fileBytes,
        filePath: filePath,
        mimeType: mimeType,
      );

  Future<List<TaskSubmission>> getTaskSubmissions(String taskId) =>
      TaskService.instance.getTaskSubmissions(taskId);

  Future<TaskSubmission> reviewSubmission({
    required String submissionId,
    required String status,
    String? feedback,
  }) =>
      TaskService.instance.reviewSubmission(
        submissionId: submissionId,
        status: status,
        feedback: feedback,
      );
}
