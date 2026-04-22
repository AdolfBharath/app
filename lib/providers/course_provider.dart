import 'package:flutter/foundation.dart';

import '../models/course.dart';
import '../services/api_service.dart' as admin_api;

class CourseProvider extends ChangeNotifier {
  final List<Course> _courses = [];

  List<Course> get courses => List.unmodifiable(_courses);

  Course? getById(String id) {
    try {
      return _courses.firstWhere((course) => course.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> loadCourses() async {
    try {
      final list = await admin_api.ApiService.instance.getCourses();
      _courses
        ..clear()
        ..addAll(list);
      notifyListeners();
    } on admin_api.ApiException catch (e) {
      if (kDebugMode) {
        print('Load courses failed: ${e.message}');
      }
    }
  }

  Future<bool> addCourse(Course course) async {
    try {
      await admin_api.ApiService.instance.createCourse(
        course.title,
        course.description,
        thumbnailUrl: course.thumbnailUrl,
      );

      await loadCourses();
      return true;
    } on admin_api.ApiException catch (e) {
      if (kDebugMode) {
        print('Add course failed: ${e.message}');
      }
      return false;
    }
  }

  Future<bool> updateCourse({
    required String id,
    required String title,
    required String description,
    required String category,
    required String duration,
    required String instructorName,
    required String thumbnailUrl,
    required String difficulty,
    required double rating,
    String? mentorId,
  }) async {
    try {
      await admin_api.ApiService.instance.updateCourseDetails(
        id,
        title: title,
        description: description,
        category: category,
        duration: duration,
        instructorName: instructorName,
        thumbnailUrl: thumbnailUrl,
        difficulty: difficulty,
        rating: rating,
        mentorId: mentorId,
      );

      await loadCourses();
      return true;
    } on admin_api.ApiException catch (e) {
      if (kDebugMode) {
        print('Update course failed: ${e.message}');
      }
      return false;
    }
  }
}
