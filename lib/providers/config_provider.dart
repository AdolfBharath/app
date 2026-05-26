import 'package:flutter/material.dart';
import '../services/app_config_service.dart';

class ConfigProvider with ChangeNotifier {
  String _registrationFormUrl = '';
  String _studentReferenceFormUrl = '';
  String _courseReviewFormUrl = '';
  bool _isLoading = false;

  String get registrationFormUrl => _registrationFormUrl;
  String get studentReferenceFormUrl => _studentReferenceFormUrl;
  String get courseReviewFormUrl => _courseReviewFormUrl;
  bool get isLoading => _isLoading;

  Future<void> loadConfig() async {
    _isLoading = true;
    notifyListeners();
    try {
      final config = await AppConfigService.instance.getConfig();
      _registrationFormUrl =
          (config['registration_form_url'] ??
                  config['registrationFormUrl'] ??
                  '')
              .toString();
      _studentReferenceFormUrl =
          (config['student_reference_form_url'] ??
                  config['studentReferenceFormUrl'] ??
                  '')
              .toString();
      _courseReviewFormUrl =
          (config['course_review_form_url'] ??
                  config['courseReviewFormUrl'] ??
                  '')
              .toString();
    } catch (e) {
      debugPrint('Error loading config: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateRegistrationFormUrl(String url) async {
    return updateFormUrls(
      registrationFormUrl: url,
      studentReferenceFormUrl: _studentReferenceFormUrl,
      courseReviewFormUrl: _courseReviewFormUrl,
    );
  }

  Future<bool> updateFormUrls({
    required String registrationFormUrl,
    required String studentReferenceFormUrl,
    required String courseReviewFormUrl,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final ok = await AppConfigService.instance.updateConfig({
        'registrationFormUrl': registrationFormUrl,
        'studentReferenceFormUrl': studentReferenceFormUrl,
        'courseReviewFormUrl': courseReviewFormUrl,
      });
      if (ok) {
        _registrationFormUrl = registrationFormUrl;
        _studentReferenceFormUrl = studentReferenceFormUrl;
        _courseReviewFormUrl = courseReviewFormUrl;
        return true;
      }
    } catch (e) {
      debugPrint('Error updating config: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return false;
  }
}
