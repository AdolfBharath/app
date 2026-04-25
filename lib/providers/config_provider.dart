import 'package:flutter/material.dart';
import '../services/app_config_service.dart';

class ConfigProvider with ChangeNotifier {
  String _registrationFormUrl = '';
  bool _isLoading = false;

  String get registrationFormUrl => _registrationFormUrl;
  bool get isLoading => _isLoading;

  Future<void> loadConfig() async {
    _isLoading = true;
    notifyListeners();
    try {
      final config = await AppConfigService.instance.getConfig();
      _registrationFormUrl = (config['registration_form_url'] ?? config['registrationFormUrl'] ?? '').toString();
    } catch (e) {
      debugPrint('Error loading config: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateRegistrationFormUrl(String url) async {
    _isLoading = true;
    notifyListeners();
    try {
      final ok = await AppConfigService.instance.updateConfig({
        'registrationFormUrl': url,
      });
      if (ok) {
        _registrationFormUrl = url;
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
